/// SubscriptionProvider — ChangeNotifier that owns the subscription lifecycle.
///
/// Single source of truth for:
///   • isPremium  (IAP active OR BYOK Gemini key present)
///   • currentPlan / limits
///   • products loaded from store
///   • purchase / restore flow coordination
library;

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import '../models/subscription_plan.dart';
import '../services/billing_service.dart';
import '../services/subscription_repository.dart';
import '../services/subscription_service.dart' show SubscriptionService;
import '../services/analytics_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
// SubscriptionProvider
// ─────────────────────────────────────────────────────────────────────────────

class SubscriptionProvider extends ChangeNotifier {
  // ── State ──────────────────────────────────────────────────────────────────

  bool _isPremiumIap  = false;
  bool _isPremiumByok = false;
  bool _isLoading     = true;
  bool _isPurchasing  = false;
  bool _isRestoring   = false;
  String? _errorMessage;
  SubscriptionPlan _activePlan = SubscriptionPlan.freePlan;

  // ── Getters ────────────────────────────────────────────────────────────────

  bool get isPremium     => _isPremiumIap || _isPremiumByok;
  bool get isPremiumIap  => _isPremiumIap;
  bool get isPremiumByok => _isPremiumByok;
  bool get isLoading     => _isLoading;
  bool get isPurchasing  => _isPurchasing;
  bool get isRestoring   => _isRestoring;
  String? get errorMessage => _errorMessage;
  SubscriptionPlan get activePlan => _activePlan;
  FeatureLimits    get limits     => isPremium ? FeatureLimits.premium : FeatureLimits.free;

  List<ProductDetails> get storeProducts =>
      BillingService.instance.products;

  ProductDetails? storeProduct(String productId) =>
      BillingService.instance.getProduct(productId);

  // ── Initialisation ─────────────────────────────────────────────────────────

  Future<void> init() async {
    _isLoading = true;
    notifyListeners();

    // Wire up BillingService callbacks.
    final billing = BillingService.instance;
    billing.onPurchaseSuccess  = _onPurchaseSuccess;
    billing.onPurchaseError    = _onPurchaseError;
    billing.onPurchasePending  = _onPurchasePending;
    billing.onRestoreCompleted = _onRestoreCompleted;

    // Load store products in parallel with reading persisted state.
    await Future.wait([
      billing.init(),
      _refreshPremiumStatus(),
    ]);

    _isLoading = false;
    notifyListeners();

    await AnalyticsService.log(Events.appOpened, {
      'is_premium': isPremium,
      'source': _isPremiumByok ? 'byok' : (_isPremiumIap ? 'iap' : 'free'),
    });
  }

  // ── Premium status ─────────────────────────────────────────────────────────

  Future<void> _refreshPremiumStatus() async {
    // IAP path: check SQLite subscription record.
    final record = await SubscriptionRepository.instance.getActivePurchase();
    _isPremiumIap = record?.isPremium ?? false;

    // BYOK path: existing Gemini API key grants premium.
    _isPremiumByok = await SubscriptionService.isPremium();

    // Resolve active plan display.
    if (_isPremiumIap && record != null) {
      _activePlan = SubscriptionPlan.catalogue.firstWhere(
        (p) => p.id == record.planId,
        orElse: () => SubscriptionPlan.freePlan,
      );
    } else if (_isPremiumByok) {
      _activePlan = SubscriptionPlan.premiumMonthly; // BYOK shows as premium
    } else {
      _activePlan = SubscriptionPlan.freePlan;
    }
  }

  // ── Purchase flow ──────────────────────────────────────────────────────────

  Future<bool> purchase(SubscriptionPlan plan) async {
    if (_isPurchasing) return false;
    _errorMessage = null;
    _isPurchasing = true;
    notifyListeners();

    await AnalyticsService.log(Events.purchaseStarted, {
      'product_id': plan.productId,
    });

    final ok = await BillingService.instance.buySubscription(plan);
    if (!ok) {
      _isPurchasing = false;
      _errorMessage = 'Store not available';
      notifyListeners();
    }
    // Actual result comes via callbacks (_onPurchaseSuccess / _onPurchaseError).
    return ok;
  }

  Future<void> restorePurchases() async {
    if (_isRestoring) return;
    _errorMessage = null;
    _isRestoring  = true;
    notifyListeners();
    await BillingService.instance.restorePurchases();
    // Finalised via _onRestoreCompleted callback.
  }

  // ── BillingService callbacks ───────────────────────────────────────────────

  void _onPurchaseSuccess(
    PurchaseDetails details,
    SubscriptionPlan plan,
  ) async {
    final token = details.purchaseID ?? details.verificationData.localVerificationData;
    await SubscriptionRepository.instance.savePurchase(
      planId:        plan.id,
      productId:     plan.productId,
      purchaseToken: token,
    );
    await _refreshPremiumStatus();
    _isPurchasing = false;
    _errorMessage = null;
    notifyListeners();

    await AnalyticsService.log(Events.purchaseSuccess, {
      'product_id': plan.productId,
      'is_annual':  plan.isAnnual,
    });
  }

  void _onPurchaseError(String message) async {
    _isPurchasing = false;
    _isRestoring  = false;
    if (message == 'canceled') {
      _errorMessage = null;
      await AnalyticsService.log(Events.purchaseCancelled);
    } else {
      _errorMessage = message;
      await AnalyticsService.log(Events.purchaseFailed, {'error': message});
    }
    notifyListeners();
  }

  void _onPurchasePending() {
    // Keep _isPurchasing = true so UI shows spinner.
    notifyListeners();
  }

  void _onRestoreCompleted(List<PurchaseDetails> restored) async {
    _isRestoring = false;
    if (restored.isNotEmpty) {
      for (final p in restored) {
        final token = p.purchaseID ?? p.verificationData.localVerificationData;
        await SubscriptionRepository.instance.markRestored(p.productID, token);
      }
      await _refreshPremiumStatus();
      await AnalyticsService.log(Events.purchaseRestored, {
        'count': restored.length,
      });
    }
    notifyListeners();
  }

  // ── Manual refresh ─────────────────────────────────────────────────────────

  Future<void> refresh() async {
    await _refreshPremiumStatus();
    notifyListeners();
  }
}

// Extension: make PurchaseRecord.isPremium available cleanly.
extension on PurchaseRecord {
  bool get isPremium => planId != PlanId.free && isActive;
}
