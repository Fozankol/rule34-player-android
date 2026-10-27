import 'package:video_player/video_player.dart';

/// Android devices can have only one usable hardware decoder. Serialize native
/// creation/disposal and never allocate a decoder for an off-screen page.
class PlaybackSession {
  static final instance = PlaybackSession();
  Future<void>? _queue;
  VideoPlayerController? _active;

  void reset() {
    _active = null;
    _queue = null;
  }

  Future<void> _dispose(VideoPlayerController controller) async {
    try {
      await controller.dispose();
    } catch (error) {
      print('Playback cleanup: $error');
    }
  }

  Future<T> _run<T>(Future<T> Function() operation) {
    final queue = _queue ?? Future<void>.value();
    final result = queue.then((_) => operation());
    _queue = result.then<void>((_) {}, onError: (Object _, StackTrace __) {});
    return result;
  }

  Future<VideoPlayerController?> open(
    VideoPlayerController Function() create, {
    required bool Function() isCurrent,
  }) => _run(() async {
    if (!isCurrent()) return null;
    final previous = _active;
    _active = null;
    if (previous != null) await _dispose(previous);
    if (!isCurrent()) return null;
    final controller = create();
    _active = controller;
    try {
      await controller.initialize();
      if (isCurrent()) return controller;
    } catch (_) {
      _active = null;
      await _dispose(controller);
      rethrow;
    }
    _active = null;
    await _dispose(controller);
    return null;
  });

  Future<void> release(VideoPlayerController controller) => _run(() async {
    if (_active != controller) return;
    _active = null;
    await _dispose(controller);
  });
}
