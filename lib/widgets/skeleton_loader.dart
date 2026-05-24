import 'package:flutter/material.dart';
import '../theme/colors.dart';
import '../theme/app_tokens.dart';

/// Caixa de skeleton animada. Usa pulse suave.
class SkeletonBox extends StatefulWidget {
  final double? width;
  final double height;
  final double borderRadius;

  const SkeletonBox({
    super.key,
    this.width,
    required this.height,
    this.borderRadius = AppTokens.radius8,
  });

  @override
  State<SkeletonBox> createState() => _SkeletonBoxState();
}

class _SkeletonBoxState extends State<SkeletonBox>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..repeat(reverse: true);
    _animation = Tween<double>(begin: 0.45, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return AnimatedBuilder(
      animation: _animation,
      builder: (_, __) => Opacity(
        opacity: _animation.value,
        child: Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkBorder : AppColors.grey200,
            borderRadius: BorderRadius.circular(widget.borderRadius),
          ),
        ),
      ),
    );
  }
}

// ─── Skeletons prontos a usar ─────────────────────────────────────────────────

/// Skeleton de um card de secção (HomeScreen)
class SectionCardSkeleton extends StatelessWidget {
  const SectionCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark
            ? AppColors.darkCard
            : AppColors.grey100,
        borderRadius: BorderRadius.circular(AppTokens.radius20),
      ),
      padding: const EdgeInsets.all(AppTokens.sp20),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SkeletonBox(width: 80, height: 12),
          SizedBox(height: AppTokens.sp12),
          Spacer(),
          SkeletonBox(width: 120, height: 22),
          SizedBox(height: AppTokens.sp8),
          SkeletonBox(width: 80, height: 10),
        ],
      ),
    );
  }
}

/// Skeleton de uma transaction tile
class TransactionTileSkeleton extends StatelessWidget {
  const TransactionTileSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTokens.sp16, vertical: AppTokens.sp6,
      ),
      child: Row(
        children: [
          const SkeletonBox(width: 44, height: 44, borderRadius: AppTokens.radiusFull),
          const SizedBox(width: AppTokens.sp12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SkeletonBox(height: 14),
                const SizedBox(height: AppTokens.sp6),
                SkeletonBox(width: MediaQuery.of(context).size.width * 0.35, height: 10),
              ],
            ),
          ),
          const SizedBox(width: AppTokens.sp12),
          const Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              SkeletonBox(width: 70, height: 14),
              SizedBox(height: AppTokens.sp6),
              SkeletonBox(width: 40, height: 10),
            ],
          ),
        ],
      ),
    );
  }
}

/// Lista de skeletons de transacção
class TransactionListSkeleton extends StatelessWidget {
  final int count;
  const TransactionListSkeleton({super.key, this.count = 6});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: List.generate(count, (_) => const TransactionTileSkeleton()),
    );
  }
}
