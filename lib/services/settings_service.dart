import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/app_settings.dart';

class SettingsService {
  static final SettingsService _instance = SettingsService._internal();
  factory SettingsService() => _instance;
  SettingsService._internal();

  static const String _keySettings = 'app_settings_json';
  AppSettings _currentSettings = AppSettings();

  AppSettings get settings => _currentSettings;

  Future<AppSettings> loadSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_keySettings);
      if (raw != null && raw.isNotEmpty) {
        final map = jsonDecode(raw) as Map<String, dynamic>;
        _currentSettings = AppSettings.fromJson(map);
      }
    } catch (_) {
      // In tests or missing prefs, default settings remain
    }
    return _currentSettings;
  }

  Future<void> saveSettings(AppSettings settings) async {
    _currentSettings = settings;
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = jsonEncode(settings.toJson());
      await prefs.setString(_keySettings, raw);
    } catch (_) {}
  }

  void updateInMemoryOnly(AppSettings settings) {
    _currentSettings = settings;
  }
}
