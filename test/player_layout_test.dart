import 'package:flutter/material.dart';
import 'dart:async';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:video_player_platform_interface/video_player_platform_interface.dart';
import '../lib/models/post_model.dart';
import '../lib/providers/downloads_provider.dart';
import '../lib/providers/favorites_provider.dart';
import '../lib/services/database_service.dart';
import '../lib/services/playback_session.dart';
import '../lib/theme/app_theme.dart';
import '../lib/widgets/reels_player_item.dart';

class SynchronousSubscription<T> implements StreamSubscription<T> {
  final void Function()? _onCancel;
  SynchronousSubscription(this._onCancel);

  @override
  Future<void> cancel() {
    _onCancel?.call();
    return Future.value();
  }

  @override
  void onData(void Function(T data)? handleData) {}
  @override
  void onError(Function? handleError) {}
  @override
  void onDone(void Function()? handleDone) {}
  @override
  void pause([Future<void>? resumeSignal]) {}
  @override
  void resume() {}
  @override
  bool get isPaused => false;
  @override
  Future<E> asFuture<E>([E? futureValue]) => Completer<E>().future;
}

class _FailingStream extends Stream<VideoEvent> {
  @override
  StreamSubscription<VideoEvent> listen(void Function(VideoEvent event)? onData,
      {Function? onError, void Function()? onDone, bool? cancelOnError}) {
    if (onError != null) {
      scheduleMicrotask(() {
        onError(PlatformException(
          code: 'VideoError',
          message: 'MediaCodecVideoRenderer error, index=0',
        ));
      });
    }
    return SynchronousSubscription<VideoEvent>(null);
  }
}

class FailingVideoPlatform extends VideoPlayerPlatform {
  int attempts = 0;
  int disposed = 0;

  @override
  Future<void> init() async {}

  @override
  Future<int?> createWithOptions(VideoCreationOptions options) async {
    attempts++;
    return attempts;
  }

  @override
  Stream<VideoEvent> videoEventsFor(int playerId) {
    return _FailingStream();
  }

  @override
  Future<void> dispose(int playerId) async {
    disposed++;
  }
}

void main() {
  late FailingVideoPlatform platform;
  setUp(() {
    PlaybackSession.instance.reset();
    DatabaseService().enableInMemoryTestMode();
    platform = FailingVideoPlatform();
    final previous = VideoPlayerPlatform.instance;
    VideoPlayerPlatform.instance = platform;
    addTearDown(() {
      PlaybackSession.instance.reset();
      VideoPlayerPlatform.instance = previous;
    });
  });

  Future<void> showPlayer(WidgetTester tester, Size size, {double textScale = 1}) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = size;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MultiProvider(providers: [
      ChangeNotifierProvider(create: (_) => FavoritesProvider()),
      ChangeNotifierProvider(create: (_) => DownloadsProvider()),
    ], child: MaterialApp(theme: AppTheme.dark, home: MediaQuery(
      data: MediaQueryData(size: size, textScaler: TextScaler.linear(textScale)),
      child: Scaffold(body: ReelsPlayerItem(
        post: PostModel(id: 18912704, score: 782, fileUrl: 'https://example.com/test.mp4',
          previewUrl: '', sampleUrl: '', tags: List.generate(100, (i) => 'tag_$i'),
          width: 1920, height: 1080, duration: 177),
        isCurrent: true,
      )),
    ))));
    await tester.pumpAndSettle();
  }

  testWidgets('Decoder error has a working retry and separate technical details', (tester) async {
    await showPlayer(tester, const Size(360, 800));
    expect(find.text('Не удалось воспроизвести'), findsOneWidget);
    expect(find.textContaining('MediaCodecVideoRenderer'), findsNothing);
    expect(platform.attempts, 2);
    expect(platform.disposed, 2);
    await tester.tap(find.text('Повторить загрузку'));
    await tester.pumpAndSettle();
    expect(platform.attempts, 4);
    await tester.tap(find.text('Подробности ошибки'));
    await tester.pumpAndSettle();
    expect(find.textContaining('MediaCodecVideoRenderer'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Compact landscape keeps error actions reachable without overflow', (tester) async {
    await showPlayer(tester, const Size(640, 360), textScale: 1.4);
    await tester.ensureVisible(find.text('Повторить загрузку'));
    await tester.tap(find.text('Повторить загрузку'));
    await tester.pumpAndSettle();
    expect(platform.attempts, 4);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Long tag lists scroll in a bounded sheet', (tester) async {
    await showPlayer(tester, const Size(320, 640));
    await tester.tap(find.text('Теги'));
    await tester.pumpAndSettle();
    expect(find.text('Теги · 100'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
