import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:test/test.dart';
import '../../lib/models/app_settings.dart';
import '../../lib/models/filter_options.dart';
import '../../lib/models/post_model.dart';
import '../../lib/services/api_service.dart';
import '../../lib/services/realbooru_service.dart';

PostModel thumbnail() => PostModel(
  id: 123, score: 0, fileUrl: 'https://realbooru.com/guess.jpg',
  previewUrl: '', sampleUrl: '', tags: [], width: 0, height: 0,
);

void main() {
  const listing = '''
    <div class="thumb" id="s123"><a href="?id=123">
      <img src="/thumbnails/ab/cd/thumbnail_abcd.jpg" title="video">
    </a></div>
  ''';
  const details = '''
    <div class="imageContainer"><span id="psc123">157</span>
      <a href="/images/ab/cd/abcd.mp4">Original</a>
    </div>
  ''';

  test('Realbooru retries temporary catalogue and detail failures and caches details', () async {
    var listRequests = 0;
    var detailRequests = 0;
    final waits = <Duration>[];
    final client = MockClient((request) async {
      if (request.url.queryParameters['s'] == 'list') {
        listRequests++;
        if (listRequests == 1) {
          return http.Response('', 503, headers: {'retry-after': '3'});
        }
        return http.Response(listing, 200);
      }
      detailRequests++;
      return detailRequests == 1 ? http.Response('', 503) : http.Response(details, 200);
    });
    addTearDown(client.close);
    final service = RealbooruService.withClient(client, wait: (d) async { waits.add(d); });
    expect((await service.fetchPosts(page: 0)).single.score, 157);
    expect((await service.fetchPosts(page: 0)).single.score, 157);
    expect(listRequests, 3);
    expect(detailRequests, 2);
    expect(waits, contains(const Duration(seconds: 3)));
    expect(waits, contains(const Duration(seconds: 2)));
  });

  test('Persistent 503 stops after three attempts and the queue recovers', () async {
    var requests = 0;
    var unavailable = true;
    final client = MockClient((_) async {
      requests++;
      return unavailable ? http.Response('', 503) : http.Response('', 200);
    });
    addTearDown(client.close);
    final service = RealbooruService.withClient(client, wait: (_) async {});
    await expectLater(service.fetchPosts(page: 0), throwsA(isA<HttpException>()
        .having((e) => e.message, 'message', contains('Повторите загрузку позже'))));
    expect(requests, 3);
    unavailable = false;
    expect(await service.fetchPosts(page: 0), isEmpty);
    expect(requests, 4);
  });

  test('Concurrent Realbooru searches serialize requests and share detail work', () async {
    var active = 0;
    var maxActive = 0;
    var detailRequests = 0;
    final client = MockClient((request) async {
      active++;
      if (active > maxActive) maxActive = active;
      await Future<void>.delayed(const Duration(milliseconds: 1));
      active--;
      if (request.url.queryParameters['s'] == 'list') return http.Response(listing, 200);
      detailRequests++;
      return http.Response(details, 200);
    });
    addTearDown(client.close);
    final service = RealbooruService.withClient(client, wait: (_) async {});
    final results = await Future.wait([service.fetchPosts(page: 0), service.fetchPosts(page: 0)]);
    expect(results.map((posts) => posts.single.score), [157, 157]);
    expect(maxActive, 1);
    expect(detailRequests, 1);
  });

  test('Realbooru reads actual score, original URL and canonical tags', () {
    final post = RealbooruService.parsePostDetails('''
      <div class="imageContainer">
        <span id="psc123">157</span>
        <a href="//realbooru.com/images/test.webm">Original</a>
      </div>
      <textarea name="tags">video long_video</textarea>
    ''', thumbnail());
    expect(post.score, 157);
    expect(post.fileUrl, 'https://realbooru.com/images/test.webm');
    expect(post.tags, ['video', 'long_video']);
    expect(FilterOptions(preset: DurationFilterPreset.all, minScore: 100).matches(post), isTrue);
    expect(FilterOptions(preset: DurationFilterPreset.all, minScore: 500).matches(post), isFalse);
  });

  test('Realbooru does not invent a score when markup is missing', () {
    expect(() => RealbooruService.parsePostDetails('<html></html>', thumbnail()), throwsFormatException);
  });

  test('Gelbooru credentials survive settings round trip', () {
    final settings = AppSettings().copyWith(
      booruSource: 'gelbooru', gelbooruUserId: '42', gelbooruApiKey: 'key',
    );
    final restored = AppSettings.fromJson(settings.toJson());
    expect(restored.gelbooruUserId, '42');
    expect(restored.gelbooruApiKey, 'key');
    expect(restored.booruSource, 'gelbooru');
  });

  test('Gelbooru uses its own credentials and parses wrapped posts', () async {
    final api = ApiService.withClient(MockClient((request) async {
      expect(request.url.host, 'gelbooru.com');
      expect(request.url.queryParameters['user_id'], '42');
      expect(request.url.queryParameters['api_key'], 'gel-key');
      expect(request.url.queryParameters['pid'], '2');
      expect(request.url.queryParameters['tags'], contains('score:>=100'));
      return http.Response(jsonEncode({
        '@attributes': {'count': 1},
        'post': [{'id': 123, 'score': 150, 'file_url': 'https://img3.gelbooru.com/test.mp4'}],
      }), 200);
    }));
    addTearDown(api.dispose);
    api.updateSettings(AppSettings(booruSource: 'gelbooru',
      gelbooruUserId: '42', gelbooruApiKey: 'gel-key', r34ApiKey: 'r34-key'));
    final posts = await api.fetchPosts(page: 2, filterOptions: FilterOptions(minScore: 100));
    expect(posts.single.score, 150);
    expect(posts.single.isVideo, isTrue);
  });

  test('Gelbooru authorization errors explain where to enter keys', () async {
    final api = ApiService.withClient(MockClient((_) async => http.Response('', 401)));
    addTearDown(api.dispose);
    api.updateSettings(AppSettings(booruSource: 'gelbooru'));
    await expectLater(api.fetchPosts(page: 0), throwsA(predicate((Object e) =>
      e.toString().contains('User ID и API Key Gelbooru'))));
  });
}
