import 'dart:async';
import 'dart:convert';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart' as sql;
import '../models/video_metadata.dart';
import '../models/post_model.dart';
import '../models/download_item.dart';
import 'database_service.dart';

class SqfliteDatabaseStorage implements DatabaseStorage {
  sql.Database? _db;

  Future<sql.Database> _getDatabase() async {
    if (_db != null) return _db!;

    final dbPath = await sql.getDatabasesPath();
    final path = p.join(dbPath, 'rule34_player.db');

    _db = await sql.openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE video_metadata (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            post_id INTEGER UNIQUE,
            file_url TEXT,
            duration_seconds REAL,
            width INTEGER,
            height INTEGER,
            format TEXT,
            checked_at INTEGER
          )
        ''');

        await db.execute('''
          CREATE TABLE favorites (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            post_id INTEGER UNIQUE,
            json_data TEXT,
            created_at INTEGER
          )
        ''');

        await db.execute('''
          CREATE TABLE downloads (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            post_id INTEGER UNIQUE,
            file_url TEXT,
            local_path TEXT,
            total_bytes INTEGER,
            downloaded_bytes INTEGER,
            status TEXT,
            error_message TEXT,
            created_at INTEGER
          )
        ''');

        await db.execute('''
          CREATE TABLE search_history (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            query TEXT UNIQUE,
            timestamp INTEGER
          )
        ''');

        await db.execute(
          'CREATE INDEX idx_meta_post_id ON video_metadata(post_id)',
        );
      },
    );
    return _db!;
  }

  @override
  Future<void> saveMetadata(VideoMetadata meta) async {
    final db = await _getDatabase();
    await db.insert(
      'video_metadata',
      meta.toMap(),
      conflictAlgorithm: sql.ConflictAlgorithm.replace,
    );
  }

  @override
  Future<VideoMetadata?> getMetadata(int postId) async {
    final db = await _getDatabase();
    final results = await db.query(
      'video_metadata',
      where: 'post_id = ?',
      whereArgs: [postId],
      limit: 1,
    );

    if (results.isNotEmpty) {
      return VideoMetadata.fromMap(results.first);
    }
    return null;
  }

  @override
  Future<Map<int, VideoMetadata>> getMetadataBatch(List<int> postIds) async {
    final Map<int, VideoMetadata> map = {};
    if (postIds.isEmpty) return map;

    final db = await _getDatabase();
    final placeholders = List.filled(postIds.length, '?').join(',');
    final results = await db.query(
      'video_metadata',
      where: 'post_id IN ($placeholders)',
      whereArgs: postIds,
    );

    for (final row in results) {
      final meta = VideoMetadata.fromMap(row);
      map[meta.postId] = meta;
    }
    return map;
  }

  @override
  Future<void> saveFavorite(PostModel post) async {
    final db = await _getDatabase();
    await db.insert(
      'favorites',
      {
        'post_id': post.id,
        'json_data': jsonEncode(post.toJson()),
        'created_at': DateTime.now().millisecondsSinceEpoch,
      },
      conflictAlgorithm: sql.ConflictAlgorithm.replace,
    );
  }

  @override
  Future<void> removeFavorite(int postId) async {
    final db = await _getDatabase();
    await db.delete('favorites', where: 'post_id = ?', whereArgs: [postId]);
  }

  @override
  Future<bool> isFavorite(int postId) async {
    final db = await _getDatabase();
    final count = sql.Sqflite.firstIntValue(
      await db.rawQuery(
        'SELECT COUNT(*) FROM favorites WHERE post_id = ?',
        [postId],
      ),
    );
    return (count ?? 0) > 0;
  }

  @override
  Future<List<PostModel>> getFavorites() async {
    final db = await _getDatabase();
    final results = await db.query(
      'favorites',
      orderBy: 'created_at DESC',
    );

    final list = <PostModel>[];
    for (final row in results) {
      final rawJson = row['json_data'] as String;
      final map = jsonDecode(rawJson) as Map<String, dynamic>;
      final post = PostModel.fromJson(map);
      post.isFavorite = true;
      list.add(post);
    }
    return list;
  }

  @override
  Future<void> saveDownload(DownloadItem item) async {
    final db = await _getDatabase();
    await db.insert(
      'downloads',
      item.toMap(),
      conflictAlgorithm: sql.ConflictAlgorithm.replace,
    );
  }

  @override
  Future<void> updateDownload(DownloadItem item) async {
    final db = await _getDatabase();
    await db.update(
      'downloads',
      item.toMap(),
      where: 'post_id = ?',
      whereArgs: [item.postId],
    );
  }

  @override
  Future<List<DownloadItem>> getDownloads() async {
    final db = await _getDatabase();
    final results = await db.query(
      'downloads',
      orderBy: 'created_at DESC',
    );
    return results.map((r) => DownloadItem.fromMap(r)).toList();
  }

  @override
  Future<void> removeDownload(int postId) async {
    final db = await _getDatabase();
    await db.delete('downloads', where: 'post_id = ?', whereArgs: [postId]);
  }

  @override
  Future<void> addSearchQuery(String query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return;

    final db = await _getDatabase();
    await db.insert(
      'search_history',
      {
        'query': trimmed,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      },
      conflictAlgorithm: sql.ConflictAlgorithm.replace,
    );
  }

  @override
  Future<List<String>> getSearchHistory() async {
    final db = await _getDatabase();
    final results = await db.query(
      'search_history',
      orderBy: 'timestamp DESC',
      limit: 20,
    );
    return results.map((r) => r['query'] as String).toList();
  }

  @override
  Future<void> clearMetadataCache() async {
    final db = await _getDatabase();
    await db.delete('video_metadata');
  }
}
