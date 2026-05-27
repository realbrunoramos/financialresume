/// PremiumGateWidget — wraps a child with an upgrade prompt when the feature
/// requires premium and the user is on the free plan.
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/subscription_plan.dart';
import '../providers/subscription_provider.dart';
import '../screens/paywall_screen.dart';
import '../theme/colors.dart';
import 'premium_badge.dart';

// ─────────────────────────────────────────────────────────────────────────────
// PremiumGateWidget
// ─────────────────────────────────────────────────────────────────────────────

class PremiumGateWidget extends StatelessWidget {
  /// The feature this gate is protecting.
  final AppFeature feature;

  /// Content shown when the user has access.
  final Widget child;

  /// Optional custom label for the locked overlay.
  final String? lockedLabel;

  /// Called when the user taps the upgrade CTA.
  /// If null, navigates to PaywallScreen automatically.
  final VoidCallback? onUpgrade;

  const PremiumGateWidget({
    super.key,
    required this.feature,
    required this.child,
    this.lockedLabel,
    this.onUpgrade,
  });

  @override
  Widget build(BuildContext context) {
    final sub = context.watch<SubscriptionProvider>();

    // Free features are always accessible.
    if (sub.limits.hasFeature(feature)) {
      return child;
    }

    return _LockedOverlay(
      label:     lockedLabel,
      onUpgrade: onUpgrade ?? () => _openPaywall(context),
      child:     child,
    );
  }

  void _openPaywall(BuildContext context) {
    PaywallScreen.show(context);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _LockedOverlay
// ─────────────────────────────────────────────────────────────────────────────

class _LockedOverlay extends StatelessWidget {
  final Widget child;
  final String? label;
  final VoidCallback onUpgrade;

  const _LockedOverlay({
    required this.child,
    required this.onUpgrade,
    this.label,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Stack(
      children: [
        // Blurred / dimmed content beneath.
        IgnorePointer(
          child: ColorFiltered(
            colorFilter: ColorFilter.mode(
              (isDark ? Colors.black : Colors.white).withValues(alpha: 0.55),
              BlendMode.srcOver,
            ),
            child: child,
          ),
        ),

        // Upgrade overlay.
        Positioned.fill(
          child: GestureDetector(
            onTap: onUpgrade,
            child: Container(
              color: Colors.transparent,
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const PremiumLockedBadge(),
                    const SizedBox(height: 10),
                    FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.premium,
                        foregroundColor: Colors.white,
                        textStyle: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 10),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: onUpgrade,
                      icon:  const Icon(Icons.workspace_premium_rounded, size: 16),
                      label: Text(label ?? 'Upgrade to Premium'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

