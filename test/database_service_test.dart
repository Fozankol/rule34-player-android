import 'package:test/test.dart';
import '../lib/models/video_metadata.dart';
import '../lib/models/post_model.dart';
import '../lib/services/database_service.dart';

void main() {
  group('DatabaseService Tests', () {
    late DatabaseService db;

    setUp(() {
      db = DatabaseService();
      db.enableInMemoryTestMode();
    });

    test('Saves and retrieves probed metadata by postId', () async {
      final meta = VideoMetadata(
        postId: 12345,
        fileUrl: 'https://example.com/video.mp4',
        durationSeconds: 195.5,
        width: 1920,
        height: 1080,
        format: 'mp4',
        checkedAt: 1690000000,
      );

      await db.saveMetadata(meta);

      final retrieved = await db.getMetadata(12345);
      expect(retrieved, isNotNull);
      expect(retrieved!.postId, equals(12345));
      expect(retrieved.durationSeconds, equals(195.5));
      expect(retrieved.format, equals('mp4'));
    });

    test('Batch retrieves metadata for multiple posts', () async {
      await db.saveMetadata(VideoMetadata(
        postId: 1,
        fileUrl: '1.mp4',
        durationSeconds: 120.0,
        checkedAt: 100,
      ));
      await db.saveMetadata(VideoMetadata(
        postId: 2,
        fileUrl: '2.mp4',
        durationSeconds: 240.0,
        checkedAt: 100,
      ));

      final batch = await db.getMetadataBatch([1, 2, 3]);
      expect(batch.containsKey(1), isTrue);
      expect(batch.containsKey(2), isTrue);
      expect(batch.containsKey(3), isFalse);
      expect(batch[1]!.durationSeconds, equals(120.0));
      expect(batch[2]!.durationSeconds, equals(240.0));
    });

    test('Favorites bookmarking and removal', () async {
      final post = PostModel(
        id: 999,
        score: 150,
        fileUrl: 'https://example.com/999.mp4',
        previewUrl: '',
        sampleUrl: '',
        tags: ['favorite_tag'],
        width: 1080,
        height: 1920,
        duration: 210.0,
      );

      expect(await db.isFavorite(999), isFalse);

      await db.saveFavorite(post);
      expect(await db.isFavorite(999), isTrue);

      final favs = await db.getFavorites();
      expect(favs.length, equals(1));
      expect(favs.first.id, equals(999));

      await db.removeFavorite(999);
      expect(await db.isFavorite(999), isFalse);
    });

    test('Search history query deduplication and order', () async {
      await db.addSearchQuery('overwatch');
      await db.addSearchQuery('genshin');
      await db.addSearchQuery('overwatch'); // repeated, should bump to top

      final history = await db.getSearchHistory();
      expect(history.first, equals('overwatch'));
      expect(history.length, equals(2));
    });
  });
}
