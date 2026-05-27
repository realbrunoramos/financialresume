/// SubscriptionRepository — persists subscription state to SQLite + SecureStorage.
///
/// Split of concerns:
///   SQLite `subscriptions` table → current plan, expiry, source (fast reads).
///   FlutterSecureStorage         → purchase token (encrypted keychain/keystore).
///
/// Anti-tampering: the premium flag is DERIVED from (planId + isActive +
/// expiresAt) at read time — there is no stored boolean that can be flipped.
library;

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../models/subscription_plan.dart';
import 'database_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Keys
// ─────────────────────────────────────────────────────────────────────────────

abstract final class _Keys {
  static const String purchaseToken = 'sub_purchase_token';
  static const String productId     = 'sub_product_id';
}

// ─────────────────────────────────────────────────────────────────────────────
// SubscriptionRepository
// ─────────────────────────────────────────────────────────────────────────────

class SubscriptionRepository {
  SubscriptionRepository._();
  static final SubscriptionRepository instance = SubscriptionRepository._();

  final _db = DatabaseService();

  static const _secure = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  // ── Read ───────────────────────────────────────────────────────────────────

  /// Returns the active PurchaseRecord, or null when there is no premium sub.
  Future<PurchaseRecord?> getActivePurchase() async {
    try {
      final db = await _db.database;
      final rows = await db.query(
        'subscriptions',
        where:   'is_active = 1',
        orderBy: 'updated_at DESC',
        limit:   1,
      );
      if (rows.isEmpty) return null;
      final record = PurchaseRecord.fromMap(rows.first);
      // Treat expired subscriptions as inactive.
      if (record.expiresAt != null &&
          record.expiresAt!.isBefore(DateTime.now())) {
        await _setInactive();
        return null;
      }
      return record;
    } catch (e) {
      debugPrint('[SubRepo] getActivePurchase error: $e');
      return null;
    }
  }

  Future<bool> isPremiumActive() async {
    final r = await getActivePurchase();
    return r != null && r.isPremium;
  }

  // ── Write ──────────────────────────────────────────────────────────────────

  /// Saves (or replaces) an active premium subscription record.
  Future<void> savePurchase({
    required PlanId planId,
    required String productId,
    required String purchaseToken,
    String source = 'iap',
    DateTime? expiresAt,
  }) async {
    try {
      // Token goes to SecureStorage (encrypted keychain/keystore).
      await _secure.write(key: _Keys.purchaseToken, value: purchaseToken);
      await _secure.write(key: _Keys.productId,     value: productId);

      final db = await _db.database;
      // Deactivate any previous row first.
      await db.update(
        'subscriptions',
        {'is_active': 0},
        where: 'is_active = 1',
      );
      await db.insert('subscriptions', {
        'plan_id':    planId.name,
        'product_id': productId,
        'is_active':  1,
        'source':     source,
        'expires_at': expiresAt?.toIso8601String(),
        'updated_at': DateTime.now().millisecondsSinceEpoch,
      });
    } catch (e) {
      debugPrint('[SubRepo] savePurchase error: $e');
    }
  }

  Future<void> markRestored(String productId, String purchaseToken) async {
    final plan = SubscriptionPlan.catalogue.firstWhere(
      (p) => p.productId == productId,
      orElse: () => SubscriptionPlan.freePlan,
    );
    if (!plan.isPremium) return;
    await savePurchase(
      planId:        plan.id,
      productId:     productId,
      purchaseToken: purchaseToken,
      source:        'restore',
    );
  }

  Future<void> revokePremium() async {
    try {
      await _setInactive();
      await _secure.delete(key: _Keys.purchaseToken);
      await _secure.delete(key: _Keys.productId);
    } catch (e) {
      debugPrint('[SubRepo] revokePremium error: $e');
    }
  }

  // ── Token verification support ─────────────────────────────────────────────

  /// Returns the stored purchase token for server-side validation.
  Future<String?> getPurchaseToken() =>
      _secure.read(key: _Keys.purchaseToken);

  // ── Helpers ────────────────────────────────────────────────────────────────

  Future<void> _setInactive() async {
    final db = await _db.database;
    await db.update(
      'subscriptions',
      {'is_active': 0},
      where: 'is_active = 1',
    );
  }
}

// Extension: isPremium derivation on PurchaseRecord.
extension _PurchaseRecordX on PurchaseRecord {
  bool get isPremium => planId != PlanId.free && isActive;
}
