import 'package:flutter/foundation.dart';
import '../models/post_model.dart';
import '../models/filter_options.dart';
import '../services/api_service.dart';
import '../services/metadata_prober.dart';
import '../services/database_service.dart';
import '../services/settings_service.dart';

class FeedProvider extends ChangeNotifier {
  final ApiService _apiService = ApiService();
  final MetadataProber _prober = MetadataProber();
  final DatabaseService _dbService = DatabaseService();
  final SettingsService _settingsService = SettingsService();

  final List<PostModel> _allPosts = [];
  List<PostModel> _filteredPosts = [];

  FilterOptions _filterOptions = FilterOptions();
  bool _isLoading = false;
  bool _isLoadingMore = false;
  bool _isDeepScanning = false;
  String _deepScanStatus = '';
  String? _errorMessage;
  int _currentPage = 0;
  bool _hasMore = true;
  int _sessionId = 0;

  List<PostModel> get posts => _filteredPosts;
  List<PostModel> get allPosts => _allPosts;
  FilterOptions get filterOptions => _filterOptions;
  bool get isLoading => _isLoading;
  bool get isLoadingMore => _isLoadingMore;
  bool get isDeepScanning => _isDeepScanning;
  String get deepScanStatus => _deepScanStatus;
  String? get errorMessage => _errorMessage;
  bool get hasMore => _hasMore;

  FeedProvider() {
    _initSettings();
  }

  void _initSettings() {
    final settings = _settingsService.settings;
    _filterOptions.blacklistedTags = List.from(settings.blacklistedTags);

    switch (settings.defaultDurationFilter) {
      case 'all':
        _filterOptions.setPreset(DurationFilterPreset.all);
        break;
      case 'gt5min':
        _filterOptions.setPreset(DurationFilterPreset.gt5min);
        break;
      case 'gt10min':
        _filterOptions.setPreset(DurationFilterPreset.gt10min);
        break;
      case 'custom':
        _filterOptions.setPreset(DurationFilterPreset.custom);
        _filterOptions.minDurationSeconds = settings.customMinDuration;
        break;
      case 'gt2min':
      default:
        _filterOptions.setPreset(DurationFilterPreset.gt2min);
        break;
    }
  }

  /// Initial load with deep auto-pagination to gather a healthy batch of matching posts
  Future<void> loadInitial() async {
    final currentSession = ++_sessionId;
    _isLoading = true;
    _errorMessage = null;
    _currentPage = 0;
    _hasMore = true;
    _allPosts.clear();
    _filteredPosts.clear();
    _isDeepScanning = false;
    _deepScanStatus = '';
    notifyListeners();

    try {
      int pagesScanned = 0;
      const int targetInitialMatches = 20;
      const int maxInitialPages = 8;

      while (_hasMore && _filteredPosts.length < targetInitialMatches && pagesScanned < maxInitialPages) {
        if (currentSession != _sessionId) return;

        if (pagesScanned > 0) {
          _isDeepScanning = true;
          _deepScanStatus = 'Глубокий поиск... Найдено ${_filteredPosts.length}/$targetInitialMatches (стр. ${_currentPage + 1})';
          notifyListeners();
        }

        final fetched = await _apiService.fetchPosts(
          page: _currentPage,
          limit: 100,
          filterOptions: _filterOptions,
        );

        if (currentSession != _sessionId) return;

        if (fetched.isEmpty) {
          _hasMore = false;
          break;
        }

        _allPosts.addAll(fetched);

        // Pre-populate durations from SQLite cache in batch
        final ids = fetched.map((p) => p.id).toList();
        final cachedMap = await _dbService.getMetadataBatch(ids);
        for (final post in fetched) {
          if (cachedMap.containsKey(post.id)) {
            post.duration = cachedMap[post.id]!.durationSeconds;
          }
        }

        _recalculateFilteredPosts();
        if (_filteredPosts.isNotEmpty) {
          // If we got initial items, turn off full screen spinner so user sees items immediately
          _isLoading = false;
          notifyListeners();
        }

        // If duration filtering is needed, probe uncached batch promptly
        final needsDurationFilter = _filterOptions.contentType != ContentTypeFilter.photoOnly &&
            _filterOptions.preset != DurationFilterPreset.all;

        if (needsDurationFilter) {
          await _prober.probeBatch(
            fetched,
            concurrency: 6,
            dbService: _dbService,
            onProbed: (p) {
              if (currentSession == _sessionId) {
                _recalculateFilteredPosts();
                notifyListeners();
              }
            },
          );
        } else {
          // Probing can happen in background
          _startProbing(fetched);
        }

        pagesScanned++;
        if (_filteredPosts.length >= targetInitialMatches) {
          break;
        }

        _currentPage++;
      }
    } catch (e) {
      if (currentSession == _sessionId) {
        _errorMessage = e.toString();
      }
    } finally {
      if (currentSession == _sessionId) {
        _isLoading = false;
        _isDeepScanning = false;
        _deepScanStatus = '';
        notifyListeners();
      }
    }
  }

  /// Deep pagination for loadMore: scans pages in background until at least 15 new matches are found
  Future<void> loadMore() async {
    if (_isLoading || _isLoadingMore || !_hasMore) return;

    final currentSession = _sessionId;
    _isLoadingMore = true;
    _isDeepScanning = true;
    final initialCount = _filteredPosts.length;
    final targetTotal = initialCount + 15;
    _deepScanStatus = 'Загрузка следующей партии... (сейчас $initialCount)';
    notifyListeners();

    int pagesScanned = 0;
    const int maxPages = 6;

    try {
      while (_hasMore && _filteredPosts.length < targetTotal && pagesScanned < maxPages) {
        if (currentSession != _sessionId) return;

        _currentPage++;
        _deepScanStatus = 'Поиск видео... Найдено ${_filteredPosts.length} (стр. ${_currentPage + 1})';
        notifyListeners();

        final fetched = await _apiService.fetchPosts(
          page: _currentPage,
          limit: 100,
          filterOptions: _filterOptions,
        );

        if (currentSession != _sessionId) return;

        if (fetched.isEmpty) {
          _hasMore = false;
          break;
        }

        _allPosts.addAll(fetched);

        // Pre-populate durations from DB cache
        final ids = fetched.map((p) => p.id).toList();
        final cachedMap = await _dbService.getMetadataBatch(ids);
        for (final post in fetched) {
          if (cachedMap.containsKey(post.id)) {
            post.duration = cachedMap[post.id]!.durationSeconds;
          }
        }

        _recalculateFilteredPosts();
        notifyListeners();

        final needsDurationFilter = _filterOptions.contentType != ContentTypeFilter.photoOnly &&
            _filterOptions.preset != DurationFilterPreset.all;

        if (needsDurationFilter) {
          await _prober.probeBatch(
            fetched,
            concurrency: 6,
            dbService: _dbService,
            onProbed: (p) {
              if (currentSession == _sessionId) {
                _recalculateFilteredPosts();
                notifyListeners();
              }
            },
          );
        } else {
          _startProbing(fetched);
        }

        pagesScanned++;
      }
    } catch (e) {
      _currentPage = (_currentPage - 1).clamp(0, 9999);
    } finally {
      if (currentSession == _sessionId) {
        _isLoadingMore = false;
        _isDeepScanning = false;
        _deepScanStatus = '';
        notifyListeners();
      }
    }
  }

  Future<void> refresh() async {
    await loadInitial();
  }

  void _startProbing(List<PostModel> posts) {
    _prober.probeBatch(
      posts,
      concurrency: 4,
      dbService: _dbService,
      onProbed: (probedPost) {
        final index = _allPosts.indexWhere((p) => p.id == probedPost.id);
        if (index != -1) {
          _allPosts[index].duration = probedPost.duration;
          _recalculateFilteredPosts();
          notifyListeners();
        }
      },
    );
  }

  void setContentType(ContentTypeFilter type) {
    if (_filterOptions.contentType == type) return;
    _filterOptions.contentType = type;
    loadInitial();
  }

  void setMinScore(int score) {
    if (_filterOptions.minScore == score) return;
    _filterOptions.minScore = score;
    loadInitial();
  }

  void setDurationPreset(DurationFilterPreset preset) {
    _filterOptions.setPreset(preset);
    _recalculateFilteredPosts();
    notifyListeners();

    if (_filteredPosts.length < 15 && _hasMore && !_isLoadingMore && !_isLoading) {
      loadMore();
    }
  }

  void setCustomDurationRange(double minSeconds, double? maxSeconds) {
    _filterOptions.preset = DurationFilterPreset.custom;
    _filterOptions.minDurationSeconds = minSeconds;
    _filterOptions.maxDurationSeconds = maxSeconds;
    _recalculateFilteredPosts();
    notifyListeners();

    if (_filteredPosts.length < 15 && _hasMore && !_isLoadingMore && !_isLoading) {
      loadMore();
    }
  }

  void setSortOption(SortOption option) {
    _filterOptions.sortOption = option;
    loadInitial();
  }

  void setSearchTags(List<String> tags) {
    _filterOptions.searchTags = List.from(tags);
    loadInitial();
  }

  void addSearchTag(String tag) {
    final trimmed = tag.trim().toLowerCase();
    if (trimmed.isNotEmpty && !_filterOptions.searchTags.contains(trimmed)) {
      _filterOptions.searchTags.add(trimmed);
      _dbService.addSearchQuery(trimmed);
      loadInitial();
    }
  }

  void removeSearchTag(String tag) {
    final trimmed = tag.trim().toLowerCase();
    if (_filterOptions.searchTags.remove(trimmed)) {
      loadInitial();
    }
  }

  void updateBlacklist(List<String> blacklist) {
    _filterOptions.blacklistedTags = List.from(blacklist);
    _recalculateFilteredPosts();
    notifyListeners();
  }

  void _recalculateFilteredPosts() {
    final list = _allPosts.where((post) {
      return _filterOptions.matches(post);
    }).toList();

    if (_filterOptions.sortOption == SortOption.duration) {
      list.sort((a, b) {
        final durA = a.duration ?? 0.0;
        final durB = b.duration ?? 0.0;
        return durB.compareTo(durA);
      });
    } else if (_filterOptions.sortOption == SortOption.score) {
      list.sort((a, b) => b.score.compareTo(a.score));
    } else {
      list.sort((a, b) => b.id.compareTo(a.id));
    }

    _filteredPosts = list;
  }
}
