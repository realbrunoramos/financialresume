/// PremiumBadge — reusable chip that indicates a premium feature or tier.
library;

import 'package:flutter/material.dart';
import '../theme/colors.dart';

// ─────────────────────────────────────────────────────────────────────────────
// PremiumBadge — small "PRO" pill, e.g. next to feature names
// ─────────────────────────────────────────────────────────────────────────────

class PremiumBadge extends StatelessWidget {
  final String? label;
  final double fontSize;
  final EdgeInsets padding;

  const PremiumBadge({
    super.key,
    this.label,
    this.fontSize = 10,
    this.padding = const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.premiumDeep, AppColors.premiumSoft],
        ),
        borderRadius: BorderRadius.circular(100),
      ),
      child: Text(
        label ?? 'PRO',
        style: TextStyle(
          color:      Colors.white,
          fontSize:   fontSize,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.4,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// PremiumLockedBadge — lock icon + "Premium" label, e.g. on blurred features
// ─────────────────────────────────────────────────────────────────────────────

class PremiumLockedBadge extends StatelessWidget {
  final String? label;

  const PremiumLockedBadge({super.key, this.label});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: isDark
            ? AppColors.premiumDeep.withValues(alpha: 0.2)
            : AppColors.premiumLight,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: AppColors.premiumSoft.withValues(alpha: 0.4),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.lock_rounded,
            size: 12,
            color: AppColors.premiumSoft,
          ),
          const SizedBox(width: 4),
          Text(
            label ?? 'Premium',
            style: const TextStyle(
              color:      AppColors.premiumSoft,
              fontSize:   11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// PremiumPlanBadge — larger badge for the Settings plan status card
// ─────────────────────────────────────────────────────────────────────────────

class PremiumPlanBadge extends StatelessWidget {
  final bool isPremium;

  const PremiumPlanBadge({super.key, required this.isPremium});

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      child: isPremium
          ? _buildChip(
              key: const ValueKey('premium'),
              gradient: const LinearGradient(
                colors: [AppColors.premiumDeep, AppColors.premiumSoft],
              ),
              icon:  Icons.workspace_premium_rounded,
              label: 'Premium',
            )
          : _buildChip(
              key: const ValueKey('free'),
              gradient: const LinearGradient(
                colors: [Color(0xFF6B7280), Color(0xFF9CA3AF)],
              ),
              icon:  Icons.person_rounded,
              label: 'Free',
            ),
    );
  }

  Widget _buildChip({
    required Key key,
    required LinearGradient gradient,
    required IconData icon,
    required String label,
  }) {
    return Container(
      key: key,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        gradient:     gradient,
        borderRadius: BorderRadius.circular(100),
        boxShadow: [
          BoxShadow(
            color:  gradient.colors.first.withValues(alpha: 0.35),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.white),
          const SizedBox(width: 5),
          Text(
            label,
            style: const TextStyle(
              color:      Colors.white,
              fontSize:   13,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
