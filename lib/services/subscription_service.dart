/// SubscriptionService — plan detection and usage-limit enforcement.
///
/// Plan model: BYOK (Bring Your Own Key)
///   free    → no Gemini API key configured
///   premium → Gemini API key present in secure storage
///
/// Usage limits are tracked in the SQLite `ai_usage` table
/// (see DatabaseService v14 schema).
library;

import 'database_service.dart';
import 'secure_storage_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Enums & value types
// ─────────────────────────────────────────────────────────────────────────────

enum AppPlan { free, premium }

enum PremiumFeature {
  aiDocumentAnalysis,
  anomalyDetection,
  financialInsights,
  merchantDetection,
  categoryClassification,
  expenseSummary,
}

class UsageStats {
  final int callsToday;
  final int callsThisMonth;
  final int tokensToday;
  final int limitDaily;

  const UsageStats({
    required this.callsToday,
    required this.callsThisMonth,
    required this.tokensToday,
    required this.limitDaily,
  });

  bool   get isAtDailyLimit => callsToday >= limitDaily;
  double get dailyProgress  => (callsToday / limitDaily.clamp(1, limitDaily)).clamp(0.0, 1.0);
  int    get callsRemaining => (limitDaily - callsToday).clamp(0, limitDaily);
}

// ─────────────────────────────────────────────────────────────────────────────
// SubscriptionService
// ─────────────────────────────────────────────────────────────────────────────

class SubscriptionService {
  SubscriptionService._();

  static const int kPremiumDailyLimit   = 50;
  static const int kPremiumMonthlyLimit = 500;

  static final _db = DatabaseService();

  // ── Plan detection ─────────────────────────────────────────────────────────

  static Future<AppPlan> getCurrentPlan() async {
    try {
      final key = await SecureStorageService.readApiKey();
      return (key != null && key.trim().length > 10)
          ? AppPlan.premium
          : AppPlan.free;
    } catch (_) {
      return AppPlan.free;
    }
  }

  static Future<bool> isPremium() async =>
      (await getCurrentPlan()) == AppPlan.premium;

  // ── Feature gating ─────────────────────────────────────────────────────────

  /// All listed features are premium-only.
  static bool isFeaturePremium(PremiumFeature _) => true;

  static Future<bool> canUseFeature(PremiumFeature feature) async {
    if (!isFeaturePremium(feature)) { return true; }
    return isPremium();
  }

  // ── Usage limits ───────────────────────────────────────────────────────────

  /// Returns true when the user is premium AND has not hit the daily limit.
  static Future<bool> canUseAi() async {
    if (!await isPremium()) { return false; }
    final stats = await getUsageStats();
    return !stats.isAtDailyLimit;
  }

  static Future<UsageStats> getUsageStats() async {
    final today    = _todayStr();
    final monthPfx = today.substring(0, 7); // 'yyyy-MM'
    final db       = await _db.database;

    final todayRows = await db.rawQuery(
        'SELECT calls_count, tokens_used FROM ai_usage WHERE date_str = ?',
        [today]);
    final callsToday  = todayRows.isEmpty
        ? 0
        : (todayRows.first['calls_count'] as int? ?? 0);
    final tokensToday = todayRows.isEmpty
        ? 0
        : (todayRows.first['tokens_used'] as int? ?? 0);

    final monthRows = await db.rawQuery(
        'SELECT SUM(calls_count) as total FROM ai_usage WHERE date_str LIKE ?',
        ['$monthPfx%']);
    final callsMonth = (monthRows.first['total'] as int?) ?? 0;

    return UsageStats(
      callsToday:     callsToday,
      callsThisMonth: callsMonth,
      tokensToday:    tokensToday,
      limitDaily:     kPremiumDailyLimit,
    );
  }

  static Future<void> recordAiCall({int tokensUsed = 0}) async {
    final today = _todayStr();
    final db    = await _db.database;
    // ON CONFLICT upsert supported by SQLite 3.24+ (Android 9+)
    await db.rawInsert('''
      INSERT INTO ai_usage (date_str, calls_count, tokens_used)
      VALUES (?, 1, ?)
      ON CONFLICT(date_str) DO UPDATE SET
        calls_count = calls_count + 1,
        tokens_used = tokens_used + ?
    ''', [today, tokensUsed, tokensUsed]);
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  static String _todayStr() {
    final dt = DateTime.now();
    return '${dt.year.toString().padLeft(4, '0')}-'
        '${dt.month.toString().padLeft(2, '0')}-'
        '${dt.day.toString().padLeft(2, '0')}';
  }
}
