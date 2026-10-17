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

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize SQLite storage for mobile persistence
  DatabaseService.setStorage(SqfliteDatabaseStorage());

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
        theme: ThemeData(
          useMaterial3: true,
          brightness: Brightness.dark,
          scaffoldBackgroundColor: const Color(0xFF121217),
          primaryColor: const Color(0xFF00C853),
          colorScheme: ColorScheme.dark(
            primary: const Color(0xFF00C853),
            secondary: const Color(0xFF6200EA),
            surface: const Color(0xFF1B1B22),
            background: const Color(0xFF121217),
          ),
          appBarTheme: const AppBarTheme(
            backgroundColor: Color(0xFF1B1B22),
            foregroundColor: Colors.white,
            elevation: 0,
            centerTitle: false,
          ),
          chipTheme: ChipThemeData(
            backgroundColor: const Color(0xFF282834),
            labelStyle: const TextStyle(color: Colors.white),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
        home: const HomeScreen(),
      ),
    );
  }
}
