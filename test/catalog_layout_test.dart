import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../lib/providers/feed_provider.dart';
import '../lib/providers/settings_provider.dart';
import '../lib/providers/favorites_provider.dart';
import '../lib/providers/downloads_provider.dart';
import '../lib/screens/home_screen.dart';
import '../lib/services/database_service.dart';
import '../lib/theme/app_theme.dart';

class OfflineFeed extends FeedProvider {
  @override
  Future<void> loadInitial() async {}
}

void main() {
  testWidgets('Catalogue header and filters fit a narrow screen with large text', (tester) async {
    SharedPreferences.setMockInitialValues({});
    DatabaseService().enableInMemoryTestMode();
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(320, 740);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MultiProvider(providers: [
      ChangeNotifierProvider<FeedProvider>(create: (_) => OfflineFeed()),
      ChangeNotifierProvider(create: (_) => SettingsProvider()),
      ChangeNotifierProvider(create: (_) => FavoritesProvider()),
      ChangeNotifierProvider(create: (_) => DownloadsProvider()),
    ], child: MaterialApp(theme: AppTheme.dark, builder: (context, child) => MediaQuery(
      data: MediaQuery.of(context).copyWith(textScaler: const TextScaler.linear(1.3)),
      child: child!,
    ), home: const HomeScreen())));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.tap(find.byTooltip('Фильтры').first);
    await tester.pumpAndSettle();
    expect(find.text('Фильтры поиска'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.ensureVisible(find.text('Применить'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
