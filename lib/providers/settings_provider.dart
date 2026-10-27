import 'package:flutter/foundation.dart';
import '../models/app_settings.dart';
import '../services/settings_service.dart';
import '../services/database_service.dart';
import '../services/api_service.dart';
import '../services/video_preload_service.dart';

class SettingsProvider extends ChangeNotifier {
  final SettingsService _settingsService = SettingsService();
  final DatabaseService _dbService = DatabaseService();
  final ApiService _apiService = ApiService();

  AppSettings _settings = SettingsService().settings;
  AppSettings get settings => _settings;
  String get language => _settings.language;

  Future<void> setLanguage(String lang) async {
    final updated = _settings.copyWith(language: lang);
    await updateSettings(updated);
  }

  SettingsProvider() {
    _load();
  }

  Future<void> _load() async {
    _settings = await _settingsService.loadSettings();
    _apiService.updateSettings(_settings);
    notifyListeners();
  }

  Future<void> updateSettings(AppSettings newSettings) async {
    _settings = newSettings;
    _apiService.updateSettings(newSettings);
    await _settingsService.saveSettings(newSettings);
    _apiService.updateSettings(newSettings);
    notifyListeners();
  }

  Future<void> addBlacklistTag(String tag) async {
    final trimmed = tag.trim().toLowerCase();
    if (trimmed.isNotEmpty && !_settings.blacklistedTags.contains(trimmed)) {
      final updatedList = List<String>.from(_settings.blacklistedTags)..add(trimmed);
      final newSettings = _settings.copyWith(blacklistedTags: updatedList);
      await updateSettings(newSettings);
    }
  }

  Future<void> removeBlacklistTag(String tag) async {
    final trimmed = tag.trim().toLowerCase();
    final updatedList = List<String>.from(_settings.blacklistedTags)..remove(trimmed);
    final newSettings = _settings.copyWith(blacklistedTags: updatedList);
    await updateSettings(newSettings);
  }

  Future<void> clearAllCache() async {
    await _dbService.clearMetadataCache();
    await VideoPreloadService().clearAll();
    notifyListeners();
  }
}
