/// AnalyticsService — lightweight SQLite-backed event log.
///
/// Designed for Firebase/Mixpanel forward-compatibility:
/// each event is stored as (name, properties JSON, timestamp).
/// No external network calls — purely local in v1.
library;

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'database_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Event name constants
// ─────────────────────────────────────────────────────────────────────────────

abstract final class Events {
  // Paywall
  static const String paywallViewed       = 'paywall_viewed';
  static const String paywallClosed       = 'paywall_closed';
  static const String planToggled         = 'plan_toggled';      // monthly↔annual
  // Purchase flow
  static const String purchaseStarted     = 'purchase_started';
  static const String purchaseSuccess     = 'purchase_success';
  static const String purchaseFailed      = 'purchase_failed';
  static const String purchaseCancelled   = 'purchase_cancelled';
  static const String purchaseRestored    = 'purchase_restored';
  // Feature usage
  static const String aiAnalysisUsed      = 'ai_analysis_used';
  static const String ocrFallbackUsed     = 'ocr_fallback_used';
  static const String featureGated        = 'feature_gated';
  // App lifecycle
  static const String appOpened           = 'app_opened';
  static const String settingsViewed      = 'settings_viewed';
  static const String scanStarted         = 'scan_started';
}

// ─────────────────────────────────────────────────────────────────────────────
// AnalyticsService
// ─────────────────────────────────────────────────────────────────────────────

class AnalyticsService {
  AnalyticsService._();

  static final _db = DatabaseService();

  // ── Public API ─────────────────────────────────────────────────────────────

  /// Log a named event with optional properties.
  static Future<void> log(
    String event, [
    Map<String, dynamic>? properties,
  ]) async {
    try {
      final db = await _db.database;
      await db.insert('app_events', {
        'event_name': event,
        'properties': properties != null ? jsonEncode(properties) : null,
        'created_at': DateTime.now().millisecondsSinceEpoch,
      });
    } catch (e) {
      debugPrint('[Analytics] log error: $e');
    }
  }

  /// Retrieve recent events (newest first), optionally filtered by name.
  static Future<List<Map<String, dynamic>>> getEvents({
    String? eventName,
    int limit = 100,
  }) async {
    try {
      final db = await _db.database;
      return db.query(
        'app_events',
        where:     eventName != null ? 'event_name = ?' : null,
        whereArgs: eventName != null ? [eventName] : null,
        orderBy:   'created_at DESC',
        limit:     limit,
      );
    } catch (e) {
      debugPrint('[Analytics] getEvents error: $e');
      return [];
    }
  }

  /// Count occurrences of an event in the last [days] days.
  static Future<int> countRecent(String event, {int days = 30}) async {
    try {
      final cutoff = DateTime.now()
          .subtract(Duration(days: days))
          .millisecondsSinceEpoch;
      final db = await _db.database;
      final rows = await db.rawQuery(
        'SELECT COUNT(*) as cnt FROM app_events '
        'WHERE event_name = ? AND created_at >= ?',
        [event, cutoff],
      );
      return (rows.first['cnt'] as int?) ?? 0;
    } catch (e) {
      return 0;
    }
  }

  /// Purge events older than [days] days to keep the table lean.
  static Future<void> pruneOldEvents({int days = 90}) async {
    try {
      final cutoff = DateTime.now()
          .subtract(Duration(days: days))
          .millisecondsSinceEpoch;
      final db = await _db.database;
      await db.delete(
        'app_events',
        where:     'created_at < ?',
        whereArgs: [cutoff],
      );
    } catch (e) {
      debugPrint('[Analytics] prune error: $e');
    }
  }
}
