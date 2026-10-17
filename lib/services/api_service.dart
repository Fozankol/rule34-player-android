import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../models/post_model.dart';
import '../models/filter_options.dart';
import '../models/app_settings.dart';
import 'realbooru_service.dart';

class TagSuggestion {
  final String label;
  final String value;

  TagSuggestion({required this.label, required this.value});

  factory TagSuggestion.fromJson(Map<String, dynamic> json) {
    return TagSuggestion(
      label: (json['label'] ?? json['value'] ?? '').toString(),
      value: (json['value'] ?? '').toString(),
    );
  }
}

class ApiService {
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;
  ApiService._internal();

  final http.Client _client = http.Client();
  final RealbooruService _realbooruService = RealbooruService();
  AppSettings _settings = AppSettings();

  static const String _defaultUserAgent =
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36';

  String get _baseUrl {
    switch (_settings.booruSource) {
      case 'tbib':
        return 'https://tbib.org/index.php';
      case 'safebooru':
        return 'https://safebooru.org/index.php';
      case 'rule34':
      default:
        return 'https://api.rule34.xxx/index.php';
    }
  }

  String get _autocompleteUrl {
    switch (_settings.booruSource) {
      case 'tbib':
        return 'https://tbib.org/autocomplete.php';
      case 'safebooru':
        return 'https://safebooru.org/autocomplete.php';
      case 'rule34':
      default:
        return 'https://api.rule34.xxx/autocomplete.php';
    }
  }

  void updateSettings(AppSettings settings) {
    _settings = settings;
  }

  /// Resolves hostname via DNS-over-HTTPS (Cloudflare / Google)
  Future<String?> resolveDoh(String hostname) async {
    try {
      String endpoint;
      if (_settings.dohProvider == 'google') {
        endpoint = 'https://dns.google/resolve?name=$hostname&type=A';
      } else {
        endpoint = 'https://cloudflare-dns.com/dns-query?name=$hostname&type=A';
      }

      final res = await _client.get(
        Uri.parse(endpoint),
        headers: {'Accept': 'application/dns-json'},
      ).timeout(const Duration(seconds: 5));

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data['Answer'] != null && (data['Answer'] as List).isNotEmpty) {
          for (final ans in data['Answer']) {
            if (ans['type'] == 1) {
              return ans['data'] as String;
            }
          }
        }
      }
    } catch (_) {}
    return null;
  }

  /// Fetches posts from booru API or scraper
  Future<List<PostModel>> fetchPosts({
    required int page,
    int limit = 100,
    FilterOptions? filterOptions,
  }) async {
    // If source is Realbooru, delegate to HTML scraper
    if (_settings.booruSource == 'realbooru') {
      return _realbooruService.fetchPosts(
        page: page,
        limit: limit,
        filterOptions: filterOptions,
      );
    }

    final tags = <String>[];

    if (filterOptions != null) {
      if (filterOptions.contentType == ContentTypeFilter.videoOnly) {
        tags.add('video');
      } else if (filterOptions.contentType == ContentTypeFilter.photoOnly) {
        tags.add('-video');
      }

      // Add user search tags
      for (final tag in filterOptions.searchTags) {
        final trimmed = tag.trim();
        if (trimmed.isNotEmpty && !tags.contains(trimmed)) {
          tags.add(trimmed);
        }
      }

      // Add score filter tag if specified (e.g. score:>=100)
      if (filterOptions.minScore > 0) {
        tags.add('score:>=${filterOptions.minScore}');
      }

      // Rule34 booru API has a 4-tag search limit for unauthenticated queries.
      // Append negative blacklist tags up to 4 tags
      final maxTagsAllowed = (filterOptions.sortOption == SortOption.score) ? 3 : 4;
      if (tags.length < maxTagsAllowed) {
        for (final blocked in filterOptions.blacklistedTags) {
          final bTrim = blocked.trim();
          if (bTrim.isNotEmpty && !tags.contains('-$bTrim')) {
            tags.add('-$bTrim');
            if (tags.length >= maxTagsAllowed) break;
          }
        }
      }

      // Sorting
      if (filterOptions.sortOption == SortOption.score) {
        tags.add('sort:score:desc');
      }
    } else {
      tags.add('video');
    }

    final queryParams = <String, String>{
      'page': 'dapi',
      's': 'post',
      'q': 'index',
      'json': '1',
      'pid': page.toString(),
      'limit': limit.toString(),
      'tags': tags.join(' '),
    };

    // If source is rule34 and credentials are provided, append them
    if (_settings.booruSource == 'rule34') {
      if (_settings.r34UserId.trim().isNotEmpty && _settings.r34ApiKey.trim().isNotEmpty) {
        queryParams['user_id'] = _settings.r34UserId.trim();
        queryParams['api_key'] = _settings.r34ApiKey.trim();
      }
    }

    final uri = Uri.parse(_baseUrl).replace(queryParameters: queryParams);

    final response = await _client.get(
      uri,
      headers: {
        'User-Agent': _defaultUserAgent,
        'Accept': 'application/json, text/plain, */*',
      },
    ).timeout(const Duration(seconds: 15));

    if (response.statusCode != 200) {
      throw HttpException(
        'Ошибка сервера: HTTP ${response.statusCode}',
        uri: uri,
      );
    }

    dynamic decoded;
    try {
      decoded = jsonDecode(response.body);
    } catch (_) {
      if (response.body.contains('Missing authentication') ||
          response.body.contains('authentication')) {
        throw const HttpException(
          'Сайт Rule34.xxx требует бесплатный API-ключ!\n\n'
          'Перейдите в Настройки (вкладка внизу) и введите свой User ID и API Key.\n'
          '(Получить бесплатно за 10 сек: rule34.xxx -> Account -> Options)\n\n'
          'Или переключите источник в Настройках на "Realbooru" или "TBIB" для просмотра без ключа.',
        );
      }
      throw HttpException('Некорректный ответ сервера: ${response.body.length > 100 ? response.body.substring(0, 100) : response.body}');
    }

    if (decoded is String) {
      if (decoded.contains('Missing authentication') || decoded.contains('authentication')) {
        throw const HttpException(
          'Сайт Rule34.xxx требует бесплатный API-ключ!\n\n'
          'Перейдите в Настройки (вкладка внизу) и введите свой User ID и API Key.\n'
          '(Получить бесплатно за 10 сек: rule34.xxx -> Account -> Options)\n\n'
          'Или переключите источник в Настройках на "Realbooru" или "TBIB" для просмотра без ключа.',
        );
      }
      throw HttpException('Ответ API: $decoded');
    }

    final List<PostModel> posts = [];

    if (decoded is List) {
      for (final item in decoded) {
        if (item is Map<String, dynamic>) {
          final post = PostModel.fromJson(item, source: _settings.booruSource);
          posts.add(post);
        }
      }
    }

    return posts;
  }

  /// Autocomplete tag search
  Future<List<TagSuggestion>> fetchAutocomplete(String query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return [];

    final uri = Uri.parse('$_autocompleteUrl?q=${Uri.encodeComponent(trimmed)}');

    try {
      final response = await _client.get(
        uri,
        headers: {
          'User-Agent': _defaultUserAgent,
          'Accept': 'application/json',
        },
      ).timeout(const Duration(seconds: 6));

      if (response.statusCode == 200) {
        final dynamic decoded = jsonDecode(response.body);
        if (decoded is List) {
          return decoded
              .map((item) => TagSuggestion.fromJson(item as Map<String, dynamic>))
              .toList();
        }
      }
    } catch (_) {}

    return [];
  }

  void dispose() {
    _client.close();
  }
}
