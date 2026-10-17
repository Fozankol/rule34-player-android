import 'package:test/test.dart';
import '../../lib/models/post_model.dart';
import '../../lib/models/filter_options.dart';

void main() {
  group('FilterOptions & Duration Filtering Tests', () {
    test('gt2min preset rejects videos under 2 minutes (e.g. 45s) and keeps videos >= 120s', () {
      final filter = FilterOptions(preset: DurationFilterPreset.gt2min);

      final shortVideo = PostModel(
        id: 101,
        score: 50,
        fileUrl: 'https://example.com/short.mp4',
        previewUrl: '',
        sampleUrl: '',
        tags: ['tag1', 'tag2'],
        width: 1920,
        height: 1080,
        duration: 45.0, // 45 seconds (< 120s)
      );

      final longVideo = PostModel(
        id: 102,
        score: 50,
        fileUrl: 'https://example.com/long.mp4',
        previewUrl: '',
        sampleUrl: '',
        tags: ['tag1', 'tag2'],
        width: 1920,
        height: 1080,
        duration: 155.0, // 2m 35s (>= 120s)
      );

      final exactVideo = PostModel(
        id: 103,
        score: 50,
        fileUrl: 'https://example.com/exact.mp4',
        previewUrl: '',
        sampleUrl: '',
        tags: ['tag1', 'tag2'],
        width: 1920,
        height: 1080,
        duration: 120.0, // exactly 2m
      );

      expect(filter.matches(shortVideo), isFalse);
      expect(filter.matches(longVideo), isTrue);
      expect(filter.matches(exactVideo), isTrue);
    });

    test('gt2min rejects unprobed/unknown duration videos unless includeUnknownDuration is true', () {
      final filter = FilterOptions(preset: DurationFilterPreset.gt2min);

      final unprobedVideo = PostModel(
        id: 104,
        score: 50,
        fileUrl: 'https://example.com/unknown.mp4',
        previewUrl: '',
        sampleUrl: '',
        tags: ['video'],
        width: 1920,
        height: 1080,
        duration: null,
      );

      expect(filter.matches(unprobedVideo), isFalse);

      filter.includeUnknownDuration = true;
      expect(filter.matches(unprobedVideo), isTrue);
    });

    test('gt5min preset rejects videos under 5 minutes (300s)', () {
      final filter = FilterOptions();
      filter.setPreset(DurationFilterPreset.gt5min);

      final video3m = PostModel(
        id: 201,
        score: 10,
        fileUrl: 'https://example.com/v.mp4',
        previewUrl: '',
        sampleUrl: '',
        tags: [],
        width: 1280,
        height: 720,
        duration: 180.0, // 3 min
      );

      final video6m = PostModel(
        id: 202,
        score: 10,
        fileUrl: 'https://example.com/v.mp4',
        previewUrl: '',
        sampleUrl: '',
        tags: [],
        width: 1280,
        height: 720,
        duration: 360.0, // 6 min
      );

      expect(filter.matches(video3m), isFalse);
      expect(filter.matches(video6m), isTrue);
    });

    test('Blacklist rejects posts containing blocked tags regardless of case', () {
      final filter = FilterOptions(
        preset: DurationFilterPreset.all,
        blacklistedTags: ['guro', 'scat'],
      );

      final cleanPost = PostModel(
        id: 301,
        score: 20,
        fileUrl: 'https://example.com/1.mp4',
        previewUrl: '',
        sampleUrl: '',
        tags: ['overwatch', 'd.va', '3d'],
        width: 1920,
        height: 1080,
      );

      final blockedPost = PostModel(
        id: 302,
        score: 20,
        fileUrl: 'https://example.com/2.mp4',
        previewUrl: '',
        sampleUrl: '',
        tags: ['overwatch', 'GURO', '3d'],
        width: 1920,
        height: 1080,
      );

      expect(filter.matches(cleanPost), isTrue);
      expect(filter.matches(blockedPost), isFalse);
    });

    test('PostModel formattedDuration formats seconds correctly', () {
      final p1 = PostModel(
        id: 1,
        score: 0,
        fileUrl: 'a.mp4',
        previewUrl: '',
        sampleUrl: '',
        tags: [],
        width: 0,
        height: 0,
        duration: null,
      );
      expect(p1.formattedDuration, equals('--:--'));

      p1.duration = 45.0;
      expect(p1.formattedDuration, equals('00:45'));

      p1.duration = 154.0;
      expect(p1.formattedDuration, equals('02:34'));

      p1.duration = 3665.0; // 1 hour, 1 minute, 5 seconds
      expect(p1.formattedDuration, equals('01:01:05'));
    });
  });
}
