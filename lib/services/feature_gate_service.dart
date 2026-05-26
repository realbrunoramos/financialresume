/// FeatureGateService — pure, synchronous feature-flag checking.
///
/// Callers get the current limits from SubscriptionProvider and pass them in.
/// This keeps the gate logic testable and dependency-free.
library;

import '../models/subscription_plan.dart';

// ─────────────────────────────────────────────────────────────────────────────
// FeatureGateService
// ─────────────────────────────────────────────────────────────────────────────

abstract final class FeatureGateService {
  // ── Feature checks ─────────────────────────────────────────────────────────

  static bool canUseFeature(AppFeature feature, FeatureLimits limits) =>
      limits.hasFeature(feature);

  static bool canUseAi(FeatureLimits limits, int aiCallsToday) {
    final cap = limits.maxAiCallsPerDay;
    if (cap == 0) return false;
    if (cap == -1) return true;
    return aiCallsToday < cap;
  }

  static bool canAddSection(FeatureLimits limits, int currentSections) {
    final cap = limits.maxSections;
    if (cap == -1) return true;
    return currentSections < cap;
  }

  static bool canScan(FeatureLimits limits, int scansThisMonth) {
    final cap = limits.maxScansPerMonth;
    if (cap == -1) return true;
    return scansThisMonth < cap;
  }

  // ── Remaining counts ───────────────────────────────────────────────────────

  static int aiCallsRemaining(FeatureLimits limits, int aiCallsToday) {
    final cap = limits.maxAiCallsPerDay;
    if (cap <= 0) return 0;
    return (cap - aiCallsToday).clamp(0, cap);
  }

  static int scansRemaining(FeatureLimits limits, int scansThisMonth) {
    final cap = limits.maxScansPerMonth;
    if (cap == -1) return -1; // unlimited
    return (cap - scansThisMonth).clamp(0, cap);
  }

  static int sectionsRemaining(FeatureLimits limits, int currentSections) {
    final cap = limits.maxSections;
    if (cap == -1) return -1;
    return (cap - currentSections).clamp(0, cap);
  }

  // ── Progress (0.0–1.0) for UI progress bars ────────────────────────────────

  static double aiProgress(FeatureLimits limits, int aiCallsToday) {
    final cap = limits.maxAiCallsPerDay;
    if (cap <= 0) return 1.0;
    return (aiCallsToday / cap).clamp(0.0, 1.0);
  }

  static double scanProgress(FeatureLimits limits, int scansThisMonth) {
    final cap = limits.maxScansPerMonth;
    if (cap <= 0) return 1.0;
    if (cap == -1) return 0.0;
    return (scansThisMonth / cap).clamp(0.0, 1.0);
  }
}
