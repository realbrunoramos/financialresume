/// AiCacheService — SQLite-backed cache for AI analysis responses.
///
/// Cache key : FNV-1a 32-bit hash of the first 2 000 chars of OCR text.
/// TTL       : 7 days.
/// Eviction  : expired rows + LRU when total exceeds kMaxCacheSize.
library;

import 'dart:convert';

import 'database_service.dart';

class AiCacheService {
  AiCacheService._();

  static const Duration kCacheTtl     = Duration(days: 7);
  static const int      kMaxCacheSize = 200;

  static final _db = DatabaseService();

  // ── Public API ─────────────────────────────────────────────────────────────

  /// Returns the cached result map, or null on cache miss / expiry.
  static Future<Map<String, dynamic>?> lookup(String cacheKey) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final db  = await _db.database;
    final rows = await db.rawQuery(
        'SELECT response_json FROM ai_cache '
        'WHERE cache_key = ? AND expires_at > ?',
        [cacheKey, now]);
    if (rows.isEmpty) { return null; }
    try {
      return jsonDecode(rows.first['response_json'] as String)
          as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  /// Stores a result map under [cacheKey] with a TTL of [kCacheTtl].
  static Future<void> store(
    String cacheKey,
    Map<String, dynamic> result, {
    String model = 'gemini-2.5-flash',
  }) async {
    final now    = DateTime.now().millisecondsSinceEpoch;
    final expiry = now + kCacheTtl.inMilliseconds;
    final db     = await _db.database;

    await db.rawInsert('''
      INSERT OR REPLACE INTO ai_cache
        (cache_key, response_json, model, created_at, expires_at)
      VALUES (?, ?, ?, ?, ?)
    ''', [cacheKey, jsonEncode(result), model, now, expiry]);

    // Fire-and-forget background eviction
    _evict(db);
  }

  /// Manually evict all expired rows.
  static Future<void> evictExpired() async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final db  = await _db.database;
    await db.rawDelete(
        'DELETE FROM ai_cache WHERE expires_at <= ?', [now]);
  }

  /// Returns the current number of cached entries (including expired).
  static Future<int> getCacheSize() async {
    final db   = await _db.database;
    final rows = await db.rawQuery('SELECT COUNT(*) as cnt FROM ai_cache');
    return (rows.first['cnt'] as int?) ?? 0;
  }

  // ── Cache key ──────────────────────────────────────────────────────────────

  /// FNV-1a 32-bit hash of the first 2 000 chars of lowercase OCR text.
  /// Stable across Dart runtimes (no Object.hashCode).
  static String computeKey(String ocrText) {
    final src = ocrText.toLowerCase().trim();
    final len = src.length.clamp(0, 2000);
    var h = 2166136261; // FNV offset basis 32-bit
    for (var i = 0; i < len; i++) {
      h ^= src.codeUnitAt(i);
      h  = (h * 16777619) & 0xFFFFFFFF;
    }
    return h.toRadixString(16).padLeft(8, '0');
  }

  // ── Private ────────────────────────────────────────────────────────────────

  static Future<void> _evict(dynamic db) async {
    try {
      final now = DateTime.now().millisecondsSinceEpoch;
      // Remove expired
      await db.rawDelete(
          'DELETE FROM ai_cache WHERE expires_at <= ?', [now]);
      // If still over limit, drop oldest 20 %
      final rows = await db.rawQuery('SELECT COUNT(*) as cnt FROM ai_cache');
      final cnt  = (rows.first['cnt'] as int?) ?? 0;
      if (cnt > kMaxCacheSize) {
        final drop = (cnt * 0.2).ceil();
        await db.rawDelete('''
          DELETE FROM ai_cache WHERE id IN (
            SELECT id FROM ai_cache ORDER BY created_at ASC LIMIT ?
          )
        ''', [drop]);
      }
    } catch (_) {
      // Eviction is best-effort; never propagate
    }
  }
}
