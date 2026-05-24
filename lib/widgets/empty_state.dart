import 'package:flutter/material.dart';
import '../theme/colors.dart';
import '../theme/app_tokens.dart';

/// Empty state genérico e reutilizável.
class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;
  final Color? iconColor;
  final double iconSize;

  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.actionLabel,
    this.onAction,
    this.iconColor,
    this.iconSize = 64,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final theme = Theme.of(context);
    final color = iconColor ?? (isDark ? AppColors.grey600 : AppColors.grey300);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppTokens.sp32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Ícone com fundo circular subtil
            Container(
              width: iconSize + AppTokens.sp32,
              height: iconSize + AppTokens.sp32,
              decoration: BoxDecoration(
                color: color.withAlpha(isDark ? 30 : 20),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: iconSize, color: color),
            ),
            const SizedBox(height: AppTokens.sp20),

            // Título
            Text(
              title,
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w600,
                color: isDark ? AppColors.darkText : AppColors.dark,
              ),
              textAlign: TextAlign.center,
            ),

            // Subtítulo opcional
            if (subtitle != null) ...[
              const SizedBox(height: AppTokens.sp8),
              Text(
                subtitle!,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: isDark ? AppColors.darkSubtext : AppColors.grey500,
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
            ],

            // Botão de acção opcional
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: AppTokens.sp24),
              SizedBox(
                width: 200,
                child: ElevatedButton(
                  onPressed: onAction,
                  child: Text(actionLabel!),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Empty state inline (para listas dentro de cards)
class EmptyStateInline extends StatelessWidget {
  final IconData icon;
  final String message;

  const EmptyStateInline({
    super.key,
    required this.icon,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppTokens.sp20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 36,
            color: isDark ? AppColors.grey600 : AppColors.grey300,
          ),
          const SizedBox(height: AppTokens.sp8),
          Text(
            message,
            style: TextStyle(
              fontSize: 13,
              color: isDark ? AppColors.darkSubtext : AppColors.grey500,
              fontWeight: FontWeight.w400,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
