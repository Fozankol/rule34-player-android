import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'providers/feed_provider.dart';
import 'providers/favorites_provider.dart';
import 'providers/downloads_provider.dart';
import 'providers/settings_provider.dart';
import 'screens/home_screen.dart';
import 'services/database_service.dart';
import 'services/sqflite_storage.dart';
import 'services/settings_service.dart';
import 'services/api_service.dart';
import 'theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize SQLite storage for mobile persistence
  DatabaseService.setStorage(SqfliteDatabaseStorage());
  final settings = await SettingsService().loadSettings();
  ApiService().updateSettings(settings);

  // Set system UI style (dark navigation & status bars)
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: Color(0xFF1B1B22),
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );

  runApp(const Rule34VideoApp());
}

class Rule34VideoApp extends StatelessWidget {
  const Rule34VideoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => SettingsProvider()),
        ChangeNotifierProvider(create: (_) => FeedProvider()),
        ChangeNotifierProvider(create: (_) => FavoritesProvider()),
        ChangeNotifierProvider(create: (_) => DownloadsProvider()),
      ],
      child: MaterialApp(
        title: 'Rule34 Video Player',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.dark,
        home: const HomeScreen(),
      ),
    );
  }
}
