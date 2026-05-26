/// BillingService — thin abstraction over in_app_purchase.
///
/// Responsibilities:
///   • Load product details from the stores.
///   • Initiate purchases and restores.
///   • Broadcast purchase results via callbacks.
///   • Call completePurchase() for every terminal PurchaseStatus to satisfy
///     both Google Play Billing and Apple StoreKit requirements.
///
/// Security model:
///   • Purchase tokens are saved by SubscriptionRepository into SecureStorage.
///   • No local boolean flags are ever the sole source-of-truth for premium.
///   • Future server-side validation can be plugged in at _onPurchaseVerified.
library;

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import '../models/subscription_plan.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Callbacks
// ─────────────────────────────────────────────────────────────────────────────

typedef OnPurchaseSuccess  = void Function(PurchaseDetails, SubscriptionPlan);
typedef OnPurchaseError    = void Function(String message);
typedef OnPurchasePending  = void Function();
typedef OnRestoreCompleted = void Function(List<PurchaseDetails>);

// ─────────────────────────────────────────────────────────────────────────────
// BillingService
// ─────────────────────────────────────────────────────────────────────────────

class BillingService {
  BillingService._();
  static final BillingService instance = BillingService._();

  // ── State ──────────────────────────────────────────────────────────────────

  final InAppPurchase _iap = InAppPurchase.instance;
  StreamSubscription<List<PurchaseDetails>>? _purchaseSub;

  bool _available = false;
  bool get isAvailable => _available;

  final Map<String, ProductDetails> _products = {};
  List<ProductDetails> get products => _products.values.toList();

  // ── Callbacks (set by SubscriptionProvider) ────────────────────────────────
  OnPurchaseSuccess?  onPurchaseSuccess;
  OnPurchaseError?    onPurchaseError;
  OnPurchasePending?  onPurchasePending;
  OnRestoreCompleted? onRestoreCompleted;

  // Restore accumulator — collects restored purchases over a short window,
  // then fires onRestoreCompleted once idle.
  final List<PurchaseDetails> _restoredBuffer = [];
  Timer? _restoreTimer;

  // ── Lifecycle ──────────────────────────────────────────────────────────────

  /// Call once at app startup (inside SubscriptionProvider.init).
  Future<void> init() async {
    _available = await _iap.isAvailable();
    if (!_available) {
      debugPrint('[Billing] Store not available');
      return;
    }
    _purchaseSub = _iap.purchaseStream.listen(
      _handlePurchaseUpdates,
      onError: (e) => debugPrint('[Billing] stream error: $e'),
    );
    await _loadProducts();
  }

  void dispose() {
    _purchaseSub?.cancel();
    _restoreTimer?.cancel();
  }

  // ── Product loading ────────────────────────────────────────────────────────

  Future<void> _loadProducts() async {
    final ids = {
      SubscriptionPlan.premiumMonthly.productId,
      SubscriptionPlan.premiumAnnual.productId,
    };
    final response = await _iap.queryProductDetails(ids);
    if (response.error != null) {
      debugPrint('[Billing] queryProductDetails error: ${response.error}');
    }
    for (final p in response.productDetails) {
      _products[p.id] = p;
    }
    debugPrint('[Billing] loaded ${_products.length} products');
  }

  ProductDetails? getProduct(String productId) => _products[productId];

  // ── Purchase initiation ────────────────────────────────────────────────────

  /// Returns false when the store is unavailable or the product isn't loaded.
  Future<bool> buySubscription(SubscriptionPlan plan) async {
    if (!_available) return false;
    final product = _products[plan.productId];
    if (product == null) {
      debugPrint('[Billing] product not found: ${plan.productId}');
      return false;
    }
    final param = PurchaseParam(productDetails: product);
    try {
      return await _iap.buyNonConsumable(purchaseParam: param);
    } catch (e) {
      debugPrint('[Billing] buyNonConsumable error: $e');
      return false;
    }
  }

  /// Restores previous purchases from the store.
  Future<void> restorePurchases() async {
    if (!_available) return;
    _restoredBuffer.clear();
    _restoreTimer?.cancel();
    try {
      await _iap.restorePurchases();
    } catch (e) {
      debugPrint('[Billing] restorePurchases error: $e');
      onPurchaseError?.call(e.toString());
    }
  }

  // ── Purchase stream handler ────────────────────────────────────────────────

  Future<void> _handlePurchaseUpdates(List<PurchaseDetails> updates) async {
    for (final purchase in updates) {
      if (purchase.status == PurchaseStatus.pending) {
        onPurchasePending?.call();
        continue;
      }

      // Always complete the purchase (required by both stores).
      if (purchase.pendingCompletePurchase) {
        await _iap.completePurchase(purchase);
      }

      switch (purchase.status) {
        case PurchaseStatus.purchased:
          await _onVerifiedPurchase(purchase, isRestore: false);

        case PurchaseStatus.restored:
          _restoredBuffer.add(purchase);
          _restoreTimer?.cancel();
          // Fire onRestoreCompleted 2 s after the last restored purchase
          // to batch all items from a single restore call.
          _restoreTimer = Timer(const Duration(seconds: 2), () {
            final copy = List<PurchaseDetails>.from(_restoredBuffer);
            _restoredBuffer.clear();
            _restoreTimer = null;
            for (final p in copy) {
              _onVerifiedPurchase(p, isRestore: true);
            }
            onRestoreCompleted?.call(copy);
          });

        case PurchaseStatus.error:
          final msg = purchase.error?.message ?? 'Unknown error';
          debugPrint('[Billing] purchase error: $msg');
          onPurchaseError?.call(msg);

        case PurchaseStatus.canceled:
          onPurchaseError?.call('canceled');

        case PurchaseStatus.pending:
          break; // handled above
      }
    }
  }

  Future<void> _onVerifiedPurchase(
    PurchaseDetails purchase, {
    required bool isRestore,
  }) async {
    // Resolve which plan this product belongs to.
    final plan = SubscriptionPlan.catalogue.firstWhere(
      (p) => p.productId == purchase.productID,
      orElse: () => SubscriptionPlan.freePlan,
    );

    if (!plan.isPremium) {
      debugPrint('[Billing] unknown productId: ${purchase.productID}');
      return;
    }

    // TODO: plug in server-side receipt validation here before calling success.
    // For now we trust the platform (typical pattern for indie apps).
    debugPrint('[Billing] verified ${isRestore ? "restore" : "purchase"}: '
        '${purchase.productID}');
    onPurchaseSuccess?.call(purchase, plan);
  }
}
