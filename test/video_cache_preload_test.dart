import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rule34_player/models/post_model.dart';
import 'package:rule34_player/services/video_preload_service.dart';

class MockHttpClientAdapter implements HttpClientAdapter {
  final Map<String, int> requestCounts = {};
  final List<RequestOptions> requests = [];
  final Set<String> cancelledUrls = {};
  int defaultPayloadSize = 1024 * 1024; // 1 MB default
  final Map<String, int> customPayloadSizes = {};
  Duration? responseDelay;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    final url = options.uri.toString();
    requestCounts[url] = (requestCounts[url] ?? 0) + 1;

    cancelFuture?.then((_) {
      cancelledUrls.add(url);
    });

    if (responseDelay != null) {
      await Future.delayed(responseDelay!);
    }

    final size = customPayloadSizes[url] ?? defaultPayloadSize;
    final bytes = Uint8List(size);

    return ResponseBody(
      Stream.value(bytes),
      200,
      headers: {
        Headers.contentLengthHeader: ['${bytes.length}'],
        'content-type': ['video/mp4'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  late VideoPreloadService service;
  late Directory tempDir;
  late MockHttpClientAdapter mockAdapter;
  late Dio testDio;

  PostModel createTestPost(int id, {String? domain, bool isVideo = true}) {
    final host = domain ?? 'https://wimg.rule34.xxx';
    final ext = isVideo ? 'mp4' : 'jpg';
    return PostModel(
      id: id,
      score: 100,
      fileUrl: '$host/images/test_$id.$ext',
      previewUrl: '$host/thumbnails/test_$id.jpg',
      sampleUrl: '$host/samples/test_$id.$ext',
      tags: ['tag1', 'tag2'],
      width: 1920,
      height: 1080,
    );
  }

  Future<void> waitForPreloads({int timeoutMs = 2000}) async {
    final sw = Stopwatch()..start();
    while (service.activePreloadsCount > 0 && sw.elapsedMilliseconds < timeoutMs) {
      await Future.delayed(const Duration(milliseconds: 5));
    }
  }

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('cache_test_');
    mockAdapter = MockHttpClientAdapter();
    testDio = Dio();
    testDio.httpClientAdapter = mockAdapter;

    service = VideoPreloadService();
    service.resetForTesting();
    service.setCacheDirForTesting(tempDir);
    service.setDioForTesting(testDio);
  });

  tearDown(() {
    service.resetForTesting();
    try {
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    } catch (_) {}
  });

  group('R1: Bidirectional LRU Video Disk Cache', () {
    test('Default max cache limit is 500 MB', () {
      expect(VideoPreloadService.defaultMaxCacheSizeBytes, equals(500 * 1024 * 1024));
      expect(service.maxCacheSizeBytes, equals(500 * 1024 * 1024));
    });

    test('Strictly respects cache size limit and evicts least recently accessed first', () async {
      // Set cache limit to 3 MB (can hold at most 3 videos of 1 MB each)
      service.maxCacheSizeBytes = 3 * 1024 * 1024;

      final post1 = createTestPost(1);
      final post2 = createTestPost(2);
      final post3 = createTestPost(3);
      final post4 = createTestPost(4);

      await service.preloadVideo(post1);
      await service.preloadVideo(post2);
      await service.preloadVideo(post3);

      expect(service.cachedEntriesCount, equals(3));
      expect(service.totalCacheSizeBytes, equals(3 * 1024 * 1024));
      expect(service.isCached(post1), isTrue);
      expect(service.isCached(post2), isTrue);
      expect(service.isCached(post3), isTrue);

      // Access post1 so its lastAccessed timestamp is updated (LRU order becomes: post2, post3, post1)
      await Future.delayed(const Duration(milliseconds: 10));
      service.getCachedFile(post1);

      // Now preload post4, which exceeds the 3 MB limit
      await service.preloadVideo(post4);

      // post2 should be evicted (as post1 was touched and post3 was accessed later than post2)
      expect(service.totalCacheSizeBytes, lessThanOrEqualTo(3 * 1024 * 1024));
      expect(service.isCached(post2), isFalse, reason: 'Least recently accessed post2 must be evicted');
      expect(service.isCached(post1), isTrue, reason: 'Recently accessed post1 must be preserved');
      expect(service.isCached(post3), isTrue);
      expect(service.isCached(post4), isTrue);
    });

    test('Persists and indexes existing cache files across service reloads', () async {
      final post = createTestPost(101);
      await service.preloadVideo(post);
      expect(service.isCached(post), isTrue);

      // Re-index cache from directory
      service.resetForTesting();
      service.setCacheDirForTesting(tempDir);

      expect(service.isCached(post), isTrue);
      final cachedFile = service.getCachedFile(post);
      expect(cachedFile, isNotNull);
      expect(cachedFile!.existsSync(), isTrue);
    });

    test('Deduplicates older duplicate cache files for same postId on directory index', () async {
      // Create legacy preload_10.mp4 (older) and video_10.mp4 (newer)
      final olderFile = File('${tempDir.path}/preload_10.mp4');
      olderFile.writeAsBytesSync(Uint8List(500 * 1024)); // 500 KB
      olderFile.setLastModifiedSync(DateTime.now().subtract(const Duration(hours: 1)));

      final newerFile = File('${tempDir.path}/video_10.mp4');
      newerFile.writeAsBytesSync(Uint8List(1024 * 1024)); // 1 MB
      newerFile.setLastModifiedSync(DateTime.now());

      // Re-index
      service.resetForTesting();
      service.setCacheDirForTesting(tempDir);

      // Single entry indexed, older duplicate deleted
      expect(service.cachedEntriesCount, equals(1));
      expect(service.totalCacheSizeBytes, equals(1024 * 1024));
      expect(olderFile.existsSync(), isFalse, reason: 'Older duplicate file must be deleted to prevent disk leak');
      expect(newerFile.existsSync(), isTrue);
    });

    test('Safely overwrites existing destination without Windows OS error 183', () async {
      final post = createTestPost(202);
      // Pre-create destination file (e.g. leftover 0-byte file)
      final dest = File('${tempDir.path}/video_202.mp4');
      dest.writeAsBytesSync([]);

      await service.preloadVideo(post);
      expect(service.isCached(post), isTrue);
      expect(dest.existsSync(), isTrue);
      expect(dest.lengthSync(), equals(1024 * 1024));
    });
  });

  group('R2: Sliding Window Preloading (Ahead and Behind)', () {
    test('Preloads next 3 upcoming videos automatically', () async {
      final posts = List.generate(10, (i) => createTestPost(i + 1));

      // User opens feed at index 0 (post 1)
      service.updateSlidingWindow(posts: posts, currentIndex: 0);

      // Wait until all in-flight preloads complete deterministically
      await waitForPreloads();

      // Post 1 (current) and next 3 posts (2, 3, 4) should be cached
      expect(service.isCached(posts[0]), isTrue);
      expect(service.isCached(posts[1]), isTrue);
      expect(service.isCached(posts[2]), isTrue);
      expect(service.isCached(posts[3]), isTrue);

      // Post 5 and beyond should NOT have been preloaded yet
      expect(service.isCached(posts[4]), isFalse);
    });

    test('Ahead preloading skips non-video posts and fetches up to 3 upcoming videos', () async {
      final posts = [
        createTestPost(1, isVideo: true),
        createTestPost(2, isVideo: false), // Image post
        createTestPost(3, isVideo: true),
        createTestPost(4, isVideo: false), // Image post
        createTestPost(5, isVideo: true),
        createTestPost(6, isVideo: true),
      ];

      service.updateSlidingWindow(posts: posts, currentIndex: 0);
      expect(service.aheadPostIds, equals({3, 5, 6}),
          reason: 'Ahead preloading must skip images and collect the next 3 videos');

      await waitForPreloads();
      expect(service.isCached(posts[0]), isTrue); // current
      expect(service.isCached(posts[2]), isTrue); // video 3
      expect(service.isCached(posts[4]), isTrue); // video 5
      expect(service.isCached(posts[5]), isTrue); // video 6
    });

    test('Non-video posts are rejected by onVideoActive and never pollute watched history', () {
      final imagePost = createTestPost(999, isVideo: false);
      service.onVideoActive(imagePost);

      expect(service.watchedHistory, isEmpty);
      expect(service.currentPlayingId, isNull);
    });

    test('Maintains last 5 watched videos in active local cache during forward navigation', () async {
      final posts = List.generate(10, (i) => createTestPost(i + 1));

      // Watch posts 0, 1, 2, 3, 4, 5 sequentially
      for (int i = 0; i <= 5; i++) {
        service.updateSlidingWindow(posts: posts, currentIndex: i);
        await waitForPreloads();
      }

      // History must retain exactly the last 5 watched posts: posts[1], [2], [3], [4], [5]
      expect(service.watchedHistory, equals([posts[1].id, posts[2].id, posts[3].id, posts[4].id, posts[5].id]));

      // All 5 in history must be in cache
      for (int i = 1; i <= 5; i++) {
        expect(service.isCached(posts[i]), isTrue, reason: 'Post ${posts[i].id} in history must remain cached');
      }
    });

    test('Eviction priority under storage pressure evicts speculative ahead preloads before watched history', () async {
      // 3 MB cache: can hold 3 videos
      service.maxCacheSizeBytes = 3 * 1024 * 1024;

      final post1 = createTestPost(1);
      final post2 = createTestPost(2);
      final post3 = createTestPost(3); // ahead preload

      // User watches post 1, then post 2
      service.onVideoActive(post1);
      await service.preloadVideo(post1);

      service.onVideoActive(post2);
      await service.preloadVideo(post2);

      // Post 3 is speculative ahead preload
      await service.preloadVideo(post3);

      expect(service.isCached(post1), isTrue);
      expect(service.isCached(post2), isTrue);
      expect(service.isCached(post3), isTrue);

      // Now add post 4. Under cache pressure, speculative ahead post3 must be evicted,
      // NOT watched history post1!
      final post4 = createTestPost(4);
      await service.preloadVideo(post4);

      expect(service.totalCacheSizeBytes, lessThanOrEqualTo(3 * 1024 * 1024));
      expect(service.isCached(post1), isTrue, reason: 'Watched history post 1 must be preserved');
      expect(service.isCached(post2), isTrue, reason: 'Currently active / watched post 2 must be preserved');
      expect(service.isCached(post3), isFalse, reason: 'Unwatched speculative ahead post 3 must be evicted first');
    });

    test('Properly sends booru media headers (Referer and User-Agent)', () async {
      final realbooruPost = createTestPost(42, domain: 'https://realbooru.com');
      await service.preloadVideo(realbooruPost);

      final req = mockAdapter.requests.firstWhere((r) => r.path == realbooruPost.fileUrl);
      expect(req.headers['Referer'], equals('https://realbooru.com/'));
      expect(req.headers['User-Agent'], contains('Rule34VideoPlayer/1.0 (Preloader)'));
    });

    test('Cancels in-flight preloads when navigating far away', () async {
      final slowAdapter = MockHttpClientAdapter();
      // Delay response to ensure download is in-flight when jump occurs
      slowAdapter.responseDelay = const Duration(milliseconds: 200);
      testDio.httpClientAdapter = slowAdapter;

      final posts = List.generate(20, (i) => createTestPost(i + 1));

      // Start at index 0 (preloads 1, 2, 3, 4)
      service.updateSlidingWindow(posts: posts, currentIndex: 0);
      expect(service.activePreloadsCount, greaterThan(0));

      // Wait a few ms for preloads to transition from queue to active Dio network fetch
      await Future.delayed(const Duration(milliseconds: 10));

      // Jump far away to index 15
      service.updateSlidingWindow(posts: posts, currentIndex: 15);

      // Verify that out-of-window requests were actually cancelled
      await Future.delayed(const Duration(milliseconds: 20));
      expect(slowAdapter.cancelledUrls, isNotEmpty,
          reason: 'Far away navigation must cancel active in-flight preloads');
      expect(service.aheadPostIds, equals({posts[16].id, posts[17].id, posts[18].id}));
    });
  });

  group('Acceptance: Zero Network Requests on Backward Navigation', () {
    test('Navigating back to previously watched videos loads from disk with zero network requests', () async {
      final posts = List.generate(8, (i) => createTestPost(i + 1));

      // 1. Forward navigation: watch posts 0, 1, 2, 3, 4
      for (int i = 0; i <= 4; i++) {
        service.updateSlidingWindow(posts: posts, currentIndex: i);
        await waitForPreloads();
      }

      final requestsAfterForward = mockAdapter.requests.length;
      expect(requestsAfterForward, greaterThan(0));

      // Clear recorded requests to isolate backward navigation tracking
      mockAdapter.requests.clear();
      mockAdapter.requestCounts.clear();

      // 2. Backward navigation: navigate back through history: 3, 2, 1, 0
      for (int i = 3; i >= 0; i--) {
        final post = posts[i];

        // ReelsPlayerItem loads cached file
        final cachedFile = service.getCachedFile(post);
        expect(cachedFile, isNotNull, reason: 'Post ${post.id} must be in local disk cache');
        expect(cachedFile!.existsSync(), isTrue);
        expect(cachedFile.lengthSync(), greaterThan(0));

        // reels_player_item sets localFilePath and opens VideoPlayerController.file
        post.localFilePath = cachedFile.path;
        expect(post.localFilePath, isNotNull);
        expect(File(post.localFilePath!).existsSync(), isTrue);

        // Update window on backward step
        service.updateSlidingWindow(posts: posts, currentIndex: i);
        await waitForPreloads();
      }

      // 3. ZERO network requests must have been made during backward navigation
      expect(mockAdapter.requests.length, equals(0),
          reason: 'Navigating back to previously watched videos must make zero network requests');
    });
  });

  group('Edge Cases & Defense-in-Depth Hardening', () {
    test('External user downloaded files are never registered or deleted by cache eviction', () async {
      final externalDownloadsDir = Directory.systemTemp.createTempSync('downloads_external_');
      addTearDown(() {
        try {
          if (externalDownloadsDir.existsSync()) {
            externalDownloadsDir.deleteSync(recursive: true);
          }
        } catch (_) {}
      });

      final downloadedFile = File('${externalDownloadsDir.path}/r34_500.mp4');
      downloadedFile.writeAsBytesSync(Uint8List(5 * 1024 * 1024)); // 5 MB
      final post500 = createTestPost(500)..localFilePath = downloadedFile.path;

      // getCachedFile must return file for playback
      final file = service.getCachedFile(post500);
      expect(file, isNotNull);
      expect(file!.path, equals(downloadedFile.path));

      // But it must NOT be registered into _cacheEntries or counted towards cache size
      expect(service.cachedEntriesCount, equals(0));
      expect(service.totalCacheSizeBytes, equals(0));

      // Evicting post 500 must NOT delete the user's permanent downloaded file
      service.evict(500);
      expect(downloadedFile.existsSync(), isTrue,
          reason: 'Cache eviction must NEVER delete user downloads outside the cache directory');

      // Even under cache pressure eviction of other videos
      service.maxCacheSizeBytes = 1024 * 1024;
      final postA = createTestPost(501);
      final postB = createTestPost(502);
      await service.preloadVideo(postA);
      await service.preloadVideo(postB);

      expect(downloadedFile.existsSync(), isTrue);
    });

    test('Rapid cancel and immediate re-preload does not delete new preload temp file or cancel token', () async {
      final slowAdapter = MockHttpClientAdapter();
      slowAdapter.responseDelay = const Duration(milliseconds: 50);
      testDio.httpClientAdapter = slowAdapter;

      final post = createTestPost(600);

      // Start initial preload
      final f1 = service.preloadVideo(post);
      expect(service.activePreloadsCount, equals(1));

      // Navigate away -> cancels initial preload
      service.cancelPreload(post.id);

      // Immediately navigate back -> restarts preload
      final f2 = service.preloadVideo(post);
      expect(service.activePreloadsCount, equals(1));

      await Future.wait([f1, f2]);
      await waitForPreloads();

      // Second preload must succeed and result in a valid cached file
      expect(service.isCached(post), isTrue);
      final cachedFile = service.getCachedFile(post);
      expect(cachedFile, isNotNull);
      expect(cachedFile!.existsSync(), isTrue);
      expect(cachedFile.lengthSync(), equals(1024 * 1024));
    });

    test('Deterministic LRU tie-breaking when entries share identical timestamps', () async {
      service.maxCacheSizeBytes = 2 * 1024 * 1024; // 2 MB limit (holds 2 videos)

      final post1 = createTestPost(701);
      final post2 = createTestPost(702);
      final post3 = createTestPost(703);

      await service.preloadVideo(post1);
      await service.preloadVideo(post2);

      expect(service.cachedEntriesCount, equals(2));

      // Synthesize identical millisecond timestamps
      final sharedTimestamp = DateTime(2026, 1, 1, 12, 0, 0);
      service.setEntryTimestampForTesting(post1.id, sharedTimestamp);
      service.setEntryTimestampForTesting(post2.id, sharedTimestamp);

      // Preload post3 which forces eviction under identical timestamps
      await service.preloadVideo(post3);

      // post1 had an earlier accessSequence than post2; post1 must be evicted first
      expect(service.isCached(post1), isFalse, reason: 'Earlier accessed entry must be evicted on timestamp tie');
      expect(service.isCached(post2), isTrue);
      expect(service.isCached(post3), isTrue);
    });

    test('onPlaybackStopped cancels preloads, clears aheadPostIds and active video, but retains watched history', () async {
      final posts = List.generate(10, (i) => createTestPost(800 + i));
      service.updateSlidingWindow(posts: posts, currentIndex: 2);
      await waitForPreloads();

      expect(service.currentPlayingId, equals(posts[2].id));
      expect(service.aheadPostIds, isNotEmpty);
      expect(service.watchedHistory, isNotEmpty);

      // Player screen exits
      service.onPlaybackStopped();

      expect(service.currentPlayingId, isNull);
      expect(service.aheadPostIds, isEmpty);
      expect(service.activePreloadsCount, equals(0));
      // History of watched videos is retained for future navigation or screen reopen
      expect(service.watchedHistory, contains(posts[2].id));
    });

    test('evict cleans up disk files in cacheDir even if post was not indexed in-memory', () async {
      final leftoverFile = File('${tempDir.path}/video_950.mp4');
      leftoverFile.writeAsBytesSync(Uint8List(500 * 1024));
      expect(leftoverFile.existsSync(), isTrue);

      // Not in memory index
      expect(service.cachedEntriesCount, equals(0));

      // evict(950) should scan directory and delete disk file
      service.evict(950);
      expect(leftoverFile.existsSync(), isFalse);
    });
  });
}
