/// Subscription plan models — data-only, no Flutter dependencies.
library;

// ─────────────────────────────────────────────────────────────────────────────
// Enums
// ─────────────────────────────────────────────────────────────────────────────

enum PlanId { free, premiumMonthly, premiumAnnual }

enum AppFeature {
  // Core
  basicOcr,
  basicPdfExport,
  basicAnalytics,
  // Premium
  aiDocumentAnalysis,
  advancedOcr,
  advancedPdfExport,
  financialInsights,
  advancedAnalytics,
  anomalyDetection,
  merchantDetection,
  categoryClassification,
  unlimitedSections,
  prioritySupport,
  cloudSync, // future
}

// ─────────────────────────────────────────────────────────────────────────────
// Feature limits
// ─────────────────────────────────────────────────────────────────────────────

class FeatureLimits {
  final int maxSections;       // -1 = unlimited
  final int maxScansPerMonth;  // -1 = unlimited
  final int maxAiCallsPerDay;  // 0  = no AI
  final Set<AppFeature> unlockedFeatures;

  const FeatureLimits({
    required this.maxSections,
    required this.maxScansPerMonth,
    required this.maxAiCallsPerDay,
    required this.unlockedFeatures,
  });

  bool hasFeature(AppFeature f) => unlockedFeatures.contains(f);

  static const FeatureLimits free = FeatureLimits(
    maxSections: 5,
    maxScansPerMonth: 15,
    maxAiCallsPerDay: 0,
    unlockedFeatures: {
      AppFeature.basicOcr,
      AppFeature.basicPdfExport,
      AppFeature.basicAnalytics,
    },
  );

  static const FeatureLimits premium = FeatureLimits(
    maxSections: -1,
    maxScansPerMonth: -1,
    maxAiCallsPerDay: 50,
    unlockedFeatures: {
      AppFeature.basicOcr,
      AppFeature.basicPdfExport,
      AppFeature.basicAnalytics,
      AppFeature.aiDocumentAnalysis,
      AppFeature.advancedOcr,
      AppFeature.advancedPdfExport,
      AppFeature.financialInsights,
      AppFeature.advancedAnalytics,
      AppFeature.anomalyDetection,
      AppFeature.merchantDetection,
      AppFeature.categoryClassification,
      AppFeature.unlimitedSections,
      AppFeature.prioritySupport,
    },
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// SubscriptionPlan — static product catalogue
// ─────────────────────────────────────────────────────────────────────────────

class SubscriptionPlan {
  final PlanId id;
  final String productId;    // store product identifier
  final String name;
  final double priceUsd;
  final bool isAnnual;
  final FeatureLimits limits;

  const SubscriptionPlan({
    required this.id,
    required this.productId,
    required this.name,
    required this.priceUsd,
    required this.isAnnual,
    required this.limits,
  });

  double get monthlyEquivalent => isAnnual ? priceUsd / 12 : priceUsd;
  int    get savingPercent     => isAnnual ? 33 : 0;

  static const SubscriptionPlan freePlan = SubscriptionPlan(
    id:        PlanId.free,
    productId: '',
    name:      'Free',
    priceUsd:  0,
    isAnnual:  false,
    limits:    FeatureLimits.free,
  );

  static const SubscriptionPlan premiumMonthly = SubscriptionPlan(
    id:        PlanId.premiumMonthly,
    productId: 'premium_monthly',
    name:      'Premium',
    priceUsd:  4.99,
    isAnnual:  false,
    limits:    FeatureLimits.premium,
  );

  static const SubscriptionPlan premiumAnnual = SubscriptionPlan(
    id:        PlanId.premiumAnnual,
    productId: 'premium_annual',
    name:      'Premium Annual',
    priceUsd:  39.99,
    isAnnual:  true,
    limits:    FeatureLimits.premium,
  );

  static const List<SubscriptionPlan> catalogue = [
    freePlan,
    premiumMonthly,
    premiumAnnual,
  ];

  bool get isPremium => id != PlanId.free;
}

// ─────────────────────────────────────────────────────────────────────────────
// PurchaseRecord — persisted purchase state
// ─────────────────────────────────────────────────────────────────────────────

class PurchaseRecord {
  final PlanId planId;
  final String productId;
  final DateTime? expiresAt;
  final bool isActive;
  final String source; // 'iap' | 'byok' | 'restore'

  const PurchaseRecord({
    required this.planId,
    required this.productId,
    this.expiresAt,
    required this.isActive,
    required this.source,
  });

  Map<String, dynamic> toMap() => {
    'plan_id':    planId.name,
    'product_id': productId,
    'expires_at': expiresAt?.toIso8601String(),
    'is_active':  isActive ? 1 : 0,
    'source':     source,
  };

  factory PurchaseRecord.fromMap(Map<String, dynamic> m) => PurchaseRecord(
    planId:    PlanId.values.firstWhere(
      (e) => e.name == m['plan_id'],
      orElse: () => PlanId.free,
    ),
    productId: m['product_id'] as String? ?? '',
    expiresAt: m['expires_at'] != null
        ? DateTime.tryParse(m['expires_at'] as String)
        : null,
    isActive: (m['is_active'] as int? ?? 0) == 1,
    source:   m['source'] as String? ?? 'iap',
  );
}
