import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../models/transaction.dart';
import '../theme/colors.dart';
import '../theme/app_tokens.dart';

class TransactionListTile extends StatelessWidget {
  final Transaction transaction;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final VoidCallback? onDelete;

  const TransactionListTile({
    super.key,
    required this.transaction,
    required this.onTap,
    required this.onLongPress,
    this.onDelete,
  });

  // ── Ícone por tipo de documento ──────────────────────────────────────────
  IconData get _docIcon {
    switch (transaction.docType) {
      case '1': return Icons.receipt_rounded;
      case '2': return Icons.description_rounded;
      case '3': return Icons.check_circle_rounded;
      default:  return transaction.isCredit
          ? Icons.arrow_downward_rounded
          : Icons.arrow_upward_rounded;
    }
  }

  // ── Cores do ícone ────────────────────────────────────────────────────────
  Color _iconBg(bool isDark) {
    if (transaction.isCredit) {
      return isDark ? AppColors.success.withAlpha(30) : AppColors.successLight;
    }
    return isDark ? AppColors.danger.withAlpha(30) : AppColors.dangerLight;
  }

  Color get _iconColor =>
      transaction.isCredit ? AppColors.success : AppColors.danger;

  // ── Subtítulo (data + tipo de doc) ───────────────────────────────────────
  String _buildSubtitle() {
    final date = DateFormat('dd MMM yyyy').format(transaction.date);
    if (transaction.entity.isNotEmpty &&
        transaction.entity != transaction.description) {
      return '${transaction.entity} · $date';
    }
    return date;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final currency = NumberFormat.currency(locale: 'pt_PT', symbol: '€');
    final amountStr =
        '${transaction.isCredit ? '+' : '-'} ${currency.format(transaction.amount)}';

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTokens.sp16,
        vertical: 3.0,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            HapticFeedback.lightImpact();
            onTap();
          },
          onLongPress: () {
            HapticFeedback.mediumImpact();
            onLongPress();
          },
          borderRadius: BorderRadius.circular(AppTokens.radius16),
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppTokens.sp16,
              vertical: AppTokens.sp12,
            ),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkCard : AppColors.white,
              borderRadius: BorderRadius.circular(AppTokens.radius16),
              border: Border.all(
                color: isDark ? AppColors.darkBorder : AppColors.grey100,
                width: 1,
              ),
              boxShadow: isDark ? null : AppTokens.shadowSm,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // ── Ícone ─────────────────────────────────────────────────
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: _iconBg(isDark),
                    borderRadius: BorderRadius.circular(AppTokens.radius12),
                  ),
                  child: Icon(
                    _docIcon,
                    color: _iconColor,
                    size: 20,
                  ),
                ),
                const SizedBox(width: AppTokens.sp12),

                // ── Texto ─────────────────────────────────────────────────
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        transaction.description.isNotEmpty
                            ? transaction.description
                            : transaction.entity,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: isDark ? AppColors.darkText : AppColors.dark,
                          height: 1.3,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: AppTokens.sp2),
                      Text(
                        _buildSubtitle(),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w400,
                          color: isDark
                              ? AppColors.darkSubtext
                              : AppColors.grey500,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: AppTokens.sp8),

                // ── Valor + badge ─────────────────────────────────────────
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      amountStr,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: transaction.isCredit
                            ? AppColors.success
                            : AppColors.danger,
                        letterSpacing: -0.2,
                      ),
                    ),
                    if (transaction.receiptPaths.isNotEmpty)
                      _AttachmentBadge(
                        count: transaction.receiptPaths.length,
                        isDark: isDark,
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Badge de anexos ────────────────────────────────────────────────────────────
class _AttachmentBadge extends StatelessWidget {
  final int count;
  final bool isDark;

  const _AttachmentBadge({required this.count, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: AppTokens.sp4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.attach_file_rounded,
            size: 11,
            color: isDark ? AppColors.darkSubtext : AppColors.grey400,
          ),
          const SizedBox(width: 2),
          Text(
            count.toString(),
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: isDark ? AppColors.darkSubtext : AppColors.grey400,
            ),
          ),
        ],
      ),
    );
  }
}

