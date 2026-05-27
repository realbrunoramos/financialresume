import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';
import '../theme/colors.dart';
import '../theme/app_tokens.dart';

class HelpScreen extends StatelessWidget {
  const HelpScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final l = AppLocalizations.of(context);

    return Scaffold(
      backgroundColor:
          isDark ? AppColors.darkBackground : const Color(0xFFF5F5F7),
      appBar: AppBar(
        backgroundColor: isDark ? AppColors.darkSurface : AppColors.white,
        foregroundColor: isDark ? AppColors.darkText : AppColors.dark,
        elevation: 0,
        title: Text(
          l.help,
          style: const TextStyle(
              fontWeight: FontWeight.w700, letterSpacing: -0.3),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppTokens.sp16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSection(
              title: l.howToUseApp,
              isDark: isDark,
              children: [
                _buildHelpItem(
                  icon: Icons.add_circle_outline_rounded,
                  title: l.createSections,
                  description: l.createSectionsDesc,
                  isDark: isDark,
                ),
                _buildHelpItem(
                  icon: Icons.receipt_long_rounded,
                  title: l.addTransactions,
                  description: l.addTransactionsDesc,
                  isDark: isDark,
                ),
                _buildHelpItem(
                  icon: Icons.camera_alt_rounded,
                  title: l.scanDocuments,
                  description: l.scanDocumentsDesc,
                  isDark: isDark,
                ),
                _buildHelpItem(
                  icon: Icons.notifications_rounded,
                  title: l.reminders,
                  description: l.remindersDesc,
                  isDark: isDark,
                ),
              ],
            ),

            const SizedBox(height: AppTokens.sp24),

            _buildSection(
              title: l.faq,
              isDark: isDark,
              children: [
                _buildFAQItem(
                  question: l.howToDeleteTransaction,
                  answer: l.howToDeleteTransactionAnswer,
                  isDark: isDark,
                ),
                _buildFAQItem(
                  question: l.canExportData,
                  answer: l.canExportDataAnswer,
                  isDark: isDark,
                ),
                _buildFAQItem(
                  question: l.appWorksOffline,
                  answer: l.appWorksOfflineAnswer,
                  isDark: isDark,
                ),
                _buildFAQItem(
                  question: l.howToSetupNotifications,
                  answer: l.howToSetupNotificationsAnswer,
                  isDark: isDark,
                ),
              ],
            ),

            const SizedBox(height: AppTokens.sp24),

            _buildTipsSection(l, isDark),
          ],
        ),
      ),
    );
  }

  // ── Section header ────────────────────────────────────────────────────────
  Widget _buildSection({
    required String title,
    required bool isDark,
    required List<Widget> children,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: isDark ? AppColors.darkText : AppColors.dark,
          ),
        ),
        const SizedBox(height: AppTokens.sp16),
        ...children,
      ],
    );
  }

  // ── Help item card ────────────────────────────────────────────────────────
  Widget _buildHelpItem({
    required IconData icon,
    required String title,
    required String description,
    required bool isDark,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppTokens.sp12),
      padding: const EdgeInsets.all(AppTokens.sp16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : AppColors.white,
        borderRadius: BorderRadius.circular(AppTokens.radius12),
        border: Border.all(
            color: isDark ? AppColors.darkBorder : AppColors.grey100),
        boxShadow: isDark ? null : AppTokens.shadowSm,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(AppTokens.sp8),
            decoration: BoxDecoration(
              color: (isDark ? AppColors.info : AppColors.dark)
                  .withAlpha(isDark ? 30 : 12),
              borderRadius: BorderRadius.circular(AppTokens.radius8),
            ),
            child: Icon(
              icon,
              color: isDark ? AppColors.info : AppColors.dark,
              size: 22,
            ),
          ),
          const SizedBox(width: AppTokens.sp12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: isDark ? AppColors.darkText : AppColors.dark,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: AppTokens.sp4),
                Text(
                  description,
                  style: TextStyle(
                    color: isDark
                        ? AppColors.darkSubtext
                        : AppColors.grey500,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── FAQ expansion tile ────────────────────────────────────────────────────
  Widget _buildFAQItem({
    required String question,
    required String answer,
    required bool isDark,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppTokens.sp8),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : AppColors.white,
        borderRadius: BorderRadius.circular(AppTokens.radius12),
        border: Border.all(
            color: isDark ? AppColors.darkBorder : AppColors.grey100),
        boxShadow: isDark ? null : AppTokens.shadowSm,
      ),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(
            horizontal: AppTokens.sp16, vertical: AppTokens.sp4),
        collapsedBackgroundColor: Colors.transparent,
        backgroundColor: Colors.transparent,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTokens.radius12)),
        collapsedShape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTokens.radius12)),
        iconColor: isDark ? AppColors.darkSubtext : AppColors.grey500,
        collapsedIconColor:
            isDark ? AppColors.darkSubtext : AppColors.grey400,
        title: Text(
          question,
          style: TextStyle(
            fontWeight: FontWeight.w500,
            color: isDark ? AppColors.darkText : AppColors.dark,
            fontSize: 15,
          ),
        ),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
                AppTokens.sp16, 0, AppTokens.sp16, AppTokens.sp16),
            child: Text(
              answer,
              style: TextStyle(
                color: isDark ? AppColors.darkSubtext : AppColors.grey500,
                fontSize: 14,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Tips section ──────────────────────────────────────────────────────────
  Widget _buildTipItem(String title, String description) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppTokens.sp8),
      padding: const EdgeInsets.all(AppTokens.sp12),
      decoration: BoxDecoration(
        color: AppColors.info.withAlpha(35),
        borderRadius: BorderRadius.circular(AppTokens.radius8),
        border: Border.all(color: AppColors.info.withAlpha(70)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.lightbulb_outline_rounded,
            color: AppColors.info,
            size: 16,
          ),
          const SizedBox(width: AppTokens.sp8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    color: AppColors.white,
                    fontSize: 14,
                  ),
                ),
                Text(
                  description,
                  style: TextStyle(
                    color: AppColors.white.withAlpha(190),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTipsSection(AppLocalizations l, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(AppTokens.sp16),
      decoration: BoxDecoration(
        // Always a dark surface — gives nice contrast for white tip text
        color: isDark ? AppColors.darkSurface : AppColors.dark,
        borderRadius: BorderRadius.circular(AppTokens.radius16),
        border: isDark ? Border.all(color: AppColors.darkBorder) : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l.financialTips,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: AppColors.white,
            ),
          ),
          const SizedBox(height: AppTokens.sp16),
          _buildTipItem(
              l.organizeByCategories, l.organizeByCategoriesDesc),
          _buildTipItem(l.scanEverything, l.scanEverythingDesc),
          _buildTipItem(l.trackDaily, l.trackDailyDesc),
          _buildTipItem(l.useReserves, l.useReservesDesc),
        ],
      ),
    );
  }
}
