import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';
import '../theme/colors.dart';

class HelpScreen extends StatelessWidget {
  const HelpScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.light,
      appBar: AppBar(
        title: Text(
          AppLocalizations.of(context).help,
          style: TextStyle(
            color: AppColors.dark,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: AppColors.white,
        elevation: 0,
        iconTheme: IconThemeData(color: AppColors.dark),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSection(
              title: AppLocalizations.of(context).howToUseApp,
              children: [
                _buildHelpItem(
                  icon: Icons.add_circle_outline,
                  title: AppLocalizations.of(context).createSections,
                  description: AppLocalizations.of(context).createSectionsDesc,
                ),
                _buildHelpItem(
                  icon: Icons.receipt_long,
                  title: AppLocalizations.of(context).addTransactions,
                  description: AppLocalizations.of(context).addTransactionsDesc,
                ),
                _buildHelpItem(
                  icon: Icons.camera_alt,
                  title: AppLocalizations.of(context).scanDocuments,
                  description: AppLocalizations.of(context).scanDocumentsDesc,
                ),
                _buildHelpItem(
                  icon: Icons.notifications,
                  title: AppLocalizations.of(context).reminders,
                  description: AppLocalizations.of(context).remindersDesc,
                ),
              ],
            ),

            SizedBox(height: 24),

            _buildSection(
              title: AppLocalizations.of(context).faq,
              children: [
                _buildFAQItem(
                  question: AppLocalizations.of(context).howToDeleteTransaction,
                  answer: AppLocalizations.of(context).howToDeleteTransactionAnswer,
                ),
                _buildFAQItem(
                  question: AppLocalizations.of(context).canExportData,
                  answer: AppLocalizations.of(context).canExportDataAnswer,
                ),
                _buildFAQItem(
                  question: AppLocalizations.of(context).appWorksOffline,
                  answer: AppLocalizations.of(context).appWorksOfflineAnswer,
                ),
                _buildFAQItem(
                  question: AppLocalizations.of(context).howToSetupNotifications,
                  answer: AppLocalizations.of(context).howToSetupNotificationsAnswer,
                ),
              ],
            ),

            SizedBox(height: 24),

            _buildTipsSection(context),
          ],
        ),
      ),
    );
  }

  Widget _buildSection({required String title, required List<Widget> children}) {
    return
      Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: AppColors.dark,
          ),
        ),
        SizedBox(height: 16),
        ...children,
      ],
    );
  }

  Widget _buildHelpItem({
    required IconData icon,
    required String title,
    required String description,
  }) {
    return Container(
      margin: EdgeInsets.only(bottom: 12),
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: AppColors.black.withAlpha(50),
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            color: AppColors.dark,
            size: 24,
          ),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: AppColors.dark,
                    fontSize: 16,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  description,
                  style: TextStyle(
                    color: AppColors.grey,
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

  Widget _buildTipItem(String title, String description) {
    return Container(
      margin: EdgeInsets.only(bottom: 8),
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.blue.withAlpha(50),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.blue.withAlpha(90)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.lightbulb_outline,
            color: AppColors.blue,
            size: 16,
          ),
          SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: AppColors.white,
                    fontSize: 14,
                  ),
                ),
                Text(
                  description,
                  style: TextStyle(
                    color: AppColors.grey,
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

  Widget _buildFAQItem({required String question, required String answer}) {
    return Container(
      margin: EdgeInsets.only(bottom: 8),
      child: ExpansionTile(
        tilePadding: EdgeInsets.zero,
        collapsedBackgroundColor: AppColors.white,
        backgroundColor: AppColors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        collapsedShape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        title: Text(
          question,
          style: TextStyle(
            fontWeight: FontWeight.w500,
            color: AppColors.dark,
          ),
        ),
        children: [
          Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              answer,
              style: TextStyle(
                color: AppColors.grey,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTipsSection(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.dark,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
          AppLocalizations.of(context).financialTips,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: AppColors.white,
            ),
          ),
          SizedBox(height: 16),
          _buildTipItem(
            AppLocalizations.of(context).organizeByCategories,
            AppLocalizations.of(context).organizeByCategoriesDesc,
          ),
          _buildTipItem(
            AppLocalizations.of(context).scanEverything,
            AppLocalizations.of(context).scanEverythingDesc,
          ),
          _buildTipItem(
            AppLocalizations.of(context).trackDaily,
            AppLocalizations.of(context).trackDailyDesc,
          ),
          _buildTipItem(
            AppLocalizations.of(context).useReserves,
            AppLocalizations.of(context).useReservesDesc,
          ),
        ],
      )
    );
  }

}