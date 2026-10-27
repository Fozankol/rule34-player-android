import 'dart:async';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:html/parser.dart' as html_parser;
import '../models/post_model.dart';
import '../models/filter_options.dart';

class RealbooruService {
  static final RealbooruService _instance = RealbooruService._internal();
  factory RealbooruService() => _instance;
  RealbooruService._internal()
      : _client = http.Client(),
        _wait = Future<void>.delayed;

  RealbooruService.withClient(
    http.Client client, {
    Future<void> Function(Duration)? wait,
  }) : _client = client,
       _wait = wait ?? Future<void>.delayed;

  final http.Client _client;
  final Future<void> Function(Duration) _wait;
  Future<void> _requestQueue = Future<void>.value();
  final Map<int, ({PostModel post, DateTime checkedAt})> _detailCache = {};
  final Map<int, Future<PostModel>> _pendingDetails = {};

  // All catalogue and detail requests share one queue, including overlapping
  // searches. This prevents refreshes from multiplying the request rate.
  Future<http.Response> _getPage(Uri uri) {
    final result = _requestQueue.then((_) async {
      await _wait(const Duration(milliseconds: 600));
      for (var attempt = 0; attempt < 3; attempt++) {
        final response = await _client.get(uri, headers: realbooruHeaders)
            .timeout(const Duration(seconds: 20));
        if (response.statusCode == 200) return response;
        final temporary = const [429, 502, 503, 504].contains(response.statusCode);
        if (!temporary) {
          throw HttpException('Realbooru: HTTP ${response.statusCode}');
        }
        if (attempt == 2) {
          throw HttpException(
            'Realbooru временно недоступен или ограничивает запросы '
            '(HTTP ${response.statusCode}). Повторите загрузку позже.',
          );
        }
        final retryAfter = response.headers['retry-after'];
        var seconds = int.tryParse(retryAfter ?? '');
        if (seconds == null && retryAfter != null) {
          try {
            seconds = HttpDate.parse(retryAfter).difference(DateTime.now().toUtc()).inSeconds;
          } on FormatException {
            // Use exponential backoff for an invalid Retry-After header.
          }
        }
        await _wait(Duration(seconds: (seconds ?? (2 << attempt)).clamp(1, 60)));
      }
      throw StateError('Unreachable');
    });
    // A failed request must not poison the queue for subsequent refreshes.
    _requestQueue = result.then<void>((_) {}, onError: (Object _, StackTrace __) {});
    return result;
  }

  Future<PostModel> getDetails(PostModel post) => _getDetails(post);

  Future<PostModel> _getDetails(PostModel post) async {
    final cached = _detailCache[post.id];
    if (cached != null && DateTime.now().difference(cached.checkedAt) < const Duration(minutes: 10)) {
      return cached.post;
    }
    final pending = _pendingDetails[post.id];
    if (pending != null) return pending;
    final request = () async {
      final uri = Uri.https('realbooru.com', '/index.php', {
        'page': 'post', 's': 'view', 'id': '${post.id}',
      });
      final response = await _getPage(uri);
      final detailed = parsePostDetails(response.body, post);
      _detailCache.remove(post.id);
      _detailCache[post.id] = (post: detailed, checkedAt: DateTime.now());
      if (_detailCache.length > 250) _detailCache.remove(_detailCache.keys.first);
      return detailed;
    }();
    _pendingDetails[post.id] = request;
    try {
      return await request;
    } finally {
      _pendingDetails.remove(post.id);
    }
  }

  static const String _defaultUserAgent =
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36';

  static const Map<String, String> realbooruHeaders = {
    'User-Agent': _defaultUserAgent,
    'Referer': 'https://realbooru.com/',
    'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
  };

  /// Scrapes posts from realbooru.com HTML listing
  Future<List<PostModel>> fetchPosts({
    required int page,
    int limit = 50,
    FilterOptions? filterOptions,
  }) async {
    final tags = <String>[];

    if (filterOptions != null) {
      if (filterOptions.contentType == ContentTypeFilter.videoOnly) {
        tags.add('video');
      } else if (filterOptions.contentType == ContentTypeFilter.photoOnly) {
        tags.add('-video');
      }

      for (final t in filterOptions.searchTags) {
        final trimmed = t.trim();
        if (trimmed.isNotEmpty && !tags.contains(trimmed)) {
          tags.add(trimmed);
        }
      }

      if (filterOptions.minScore > 0) {
        tags.add('score:>=${filterOptions.minScore}');
      }
      if (filterOptions.sortOption == SortOption.score) {
        tags.add('sort:score:desc');
      }

      for (final b in filterOptions.blacklistedTags) {
        final bTrim = b.trim();
        if (bTrim.isNotEmpty && !tags.contains('-$bTrim')) {
          tags.add('-$bTrim');
        }
      }
    }

    // The HTML listing ignores API limits and always uses 42 posts per page.
    final pid = page * 42;
    final tagsParam = tags.isNotEmpty ? tags.join(' ') : 'all';
    final urlStr = 'https://realbooru.com/index.php?page=post&s=list&pid=$pid&tags=${Uri.encodeComponent(tagsParam)}';

    final response = await _getPage(Uri.parse(urlStr));

    final document = html_parser.parse(response.body);
    final thumbDivs = document.querySelectorAll('.thumb');

    final List<PostModel> posts = [];

    for (final div in thumbDivs) {
      final img = div.querySelector('img');
      final link = div.querySelector('a');
      if (img == null || link == null) continue;

      final href = link.attributes['href'] ?? '';
      final imgSrc = img.attributes['src'] ?? '';
      final title = img.attributes['title'] ?? '';

      // Extract ID from div id "s1011838" or href "...id=1011838"
      int postId = 0;
      final divId = div.attributes['id'] ?? '';
      if (divId.startsWith('s')) {
        postId = int.tryParse(divId.substring(1)) ?? 0;
      }
      if (postId == 0) {
        final idMatch = RegExp(r'id=(\d+)').firstMatch(href);
        if (idMatch != null) {
          postId = int.tryParse(idMatch.group(1)!) ?? 0;
        }
      }

      // Parse tags from title attribute (comma separated)
      final parsedTags = title
          .split(',')
          .map((t) => t.trim().toLowerCase())
          .where((t) => t.isNotEmpty)
          .toList();

      final isVideo = parsedTags.contains('video') ||
          parsedTags.contains('mp4') ||
          parsedTags.contains('webm') ||
          (img.attributes['style']?.contains('#0000ff') ?? false);

      // Reconstruct file URL from thumbnail URL
      // e.g. https://realbooru.com/thumbnails/31/a0/thumbnail_31a07301fcc2bcf67676234b096433be.jpg
      String previewUrl = imgSrc;
      previewUrl = Uri.parse('https://realbooru.com/').resolve(previewUrl).toString();

      String fileUrl = previewUrl;
      final thumbMatch = RegExp(r'/thumbnails/([a-z0-9]+)/([a-z0-9]+)/thumbnail_([a-z0-9]+)\.jpg')
          .firstMatch(previewUrl);

      if (thumbMatch != null) {
        final d1 = thumbMatch.group(1)!;
        final d2 = thumbMatch.group(2)!;
        final hash = thumbMatch.group(3)!;

        if (isVideo) {
          final ext = parsedTags.contains('webm') ? 'webm' : 'mp4';
          fileUrl = 'https://realbooru.com/images/$d1/$d2/$hash.$ext';
        } else {
          final ext = parsedTags.contains('gif')
              ? 'gif'
              : parsedTags.contains('png')
                  ? 'png'
                  : 'jpg';
          fileUrl = 'https://realbooru.com/images/$d1/$d2/$hash.$ext';
        }
      }

      final initialScore = (filterOptions != null && filterOptions.minScore > 0)
          ? filterOptions.minScore
          : 0;

      posts.add(
        PostModel(
          id: postId,
          score: initialScore,
          hasExactScore: false,
          fileUrl: fileUrl,
          previewUrl: previewUrl,
          sampleUrl: fileUrl,
          tags: parsedTags,
          width: 1280,
          height: 720,
        ),
      );
    }

    return posts;
  }

  static PostModel parsePostDetails(String html, PostModel post) {
    final document = html_parser.parse(html);
    final scoreText = document.getElementById('psc${post.id}')?.text.trim();
    final score = int.tryParse(scoreText ?? '') ?? post.score;
    final original = document.querySelectorAll('.imageContainer a[href]')
        .where((a) => a.text.trim() == 'Original');
    final url = original.isEmpty ? post.fileUrl :
        Uri.parse('https://realbooru.com/').resolve(original.first.attributes['href']!).toString();
    final tagsText = document.querySelector('textarea[name="tags"]')?.text;
    return post.copyWith(
      score: score,
      hasExactScore: true,
      fileUrl: url,
      sampleUrl: url,
      tags: tagsText == null ? post.tags : tagsText.trim().split(RegExp(r'\s+')),
    );
  }
}
