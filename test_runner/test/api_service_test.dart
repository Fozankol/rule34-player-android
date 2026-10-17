import 'dart:convert';
import 'package:test/test.dart';
import '../../lib/models/post_model.dart';
import '../../lib/services/api_service.dart';

void main() {
  group('ApiService & Model Serialization Tests', () {
    test('Parses raw Rule34 JSON response into PostModel list properly', () {
      final sampleJson = '''
      [
        {
          "id": 11523450,
          "score": 342,
          "file_url": "https://wimg.rule34.xxx//images/4183/87820bb1b4e892c57f7ca7ba9917d848.mp4",
          "preview_url": "https://wimg.rule34.xxx//thumbnails/4183/thumbnail_87820bb1b4e892c57f7ca7ba9917d848.jpg",
          "sample_url": "https://wimg.rule34.xxx//samples/4183/sample_87820bb1b4e892c57f7ca7ba9917d848.jpg",
          "tags": "overwatch d.va 3d animation sound 1080p",
          "width": 1920,
          "height": 1080,
          "created_at": "Sat Oct 17 12:00:00 +0000 2026"
        },
        {
          "id": "11523451",
          "score": "12",
          "file_url": "https://wimg.rule34.xxx//images/4183/test.jpg",
          "preview_url": "https://wimg.rule34.xxx//thumbnails/4183/thumb_test.jpg",
          "sample_url": "",
          "tags": "image tag1 tag2",
          "width": 800,
          "height": 600
        }
      ]
      ''';

      final decoded = jsonDecode(sampleJson) as List;
      final posts = decoded
          .map((item) => PostModel.fromJson(item as Map<String, dynamic>))
          .toList();

      expect(posts.length, equals(2));

      // Post 1 is a video
      expect(posts[0].id, equals(11523450));
      expect(posts[0].isVideo, isTrue);
      expect(posts[0].fileExtension, equals('mp4'));
      expect(posts[0].tags.contains('overwatch'), isTrue);
      expect(posts[0].tags.contains('d.va'), isTrue);

      // Post 2 is an image (jpg), so isVideo is false
      expect(posts[1].id, equals(11523451));
      expect(posts[1].isVideo, isFalse);
    });

    test('isVideo and fileExtension handle query parameters and empty strings cleanly', () {
      final withQueryParams = PostModel(
        id: 1,
        score: 10,
        fileUrl: 'https://cdn.rule34.xxx/video.webm?expires=1700000000&token=abcdef#t=10',
        previewUrl: '',
        sampleUrl: '',
        tags: [],
        width: 1920,
        height: 1080,
      );
      expect(withQueryParams.fileExtension, equals('webm'));
      expect(withQueryParams.isVideo, isTrue);

      final emptyUrl = PostModel(
        id: 2,
        score: 0,
        fileUrl: '',
        previewUrl: '',
        sampleUrl: '',
        tags: [],
        width: 0,
        height: 0,
      );
      expect(emptyUrl.fileExtension, equals(''));
      expect(emptyUrl.isVideo, isFalse);
    });

    test('TagSuggestion parsing works with autocomplete JSON structure', () {
      final sampleAutocomplete = '''
      [
        {"value": "video", "label": "video (452109)"},
        {"value": "3d", "label": "3d (219441)"}
      ]
      ''';

      final decoded = jsonDecode(sampleAutocomplete) as List;
      final suggestions = decoded
          .map((item) => TagSuggestion.fromJson(item as Map<String, dynamic>))
          .toList();

      expect(suggestions.length, equals(2));
      expect(suggestions[0].value, equals('video'));
      expect(suggestions[0].label, contains('452109'));
    });
  });
}
