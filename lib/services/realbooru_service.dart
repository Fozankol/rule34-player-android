import 'dart:async';
import 'package:http/http.dart' as http;
import 'package:html/parser.dart' as html_parser;
import '../models/post_model.dart';
import '../models/filter_options.dart';

class RealbooruService {
  static final RealbooruService _instance = RealbooruService._internal();
  factory RealbooruService() => _instance;
  RealbooruService._internal();

  final http.Client _client = http.Client();

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
    }

    final pid = page * limit;
    final tagsParam = tags.isNotEmpty ? tags.join(' ') : 'all';
    final urlStr = 'https://realbooru.com/index.php?page=post&s=list&pid=$pid&tags=${Uri.encodeComponent(tagsParam)}';

    final response = await _client.get(
      Uri.parse(urlStr),
      headers: realbooruHeaders,
    ).timeout(const Duration(seconds: 15));

    if (response.statusCode != 200) {
      return [];
    }

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
      if (!previewUrl.startsWith('http')) {
        previewUrl = 'https:${previewUrl.startsWith('//') ? previewUrl : '//$previewUrl'}';
      }

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
          fileUrl = 'https://realbooru.com/images/$d1/$d2/$hash.jpg';
        }
      }

      posts.add(
        PostModel(
          id: postId,
          score: 10,
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
}
