import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../l10n/app_localizations.dart';
import '../theme/colors.dart';
import '../theme/app_tokens.dart';

class AboutScreen extends StatefulWidget {
  const AboutScreen({super.key});

  @override
  State<AboutScreen> createState() => _AboutScreenState();
}

class _AboutScreenState extends State<AboutScreen> {
  PackageInfo _packageInfo = PackageInfo(
    appName: 'Financial Resume',
    packageName: 'Financial Resume',
    version: '2.0.2',
    buildNumber: '1',
  );

  @override
  void initState() {
    super.initState();
    _initPackageInfo();
  }

  Future<void> _initPackageInfo() async {
    final info = await PackageInfo.fromPlatform();
    setState(() {
      _packageInfo = info;
    });
  }

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
          l.about,
          style: const TextStyle(
              fontWeight: FontWeight.w700, letterSpacing: -0.3),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppTokens.sp16),
        child: Column(
          children: [
            // ── Hero card ───────────────────────────────────────────────
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppTokens.sp24),
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkCard : AppColors.white,
                borderRadius: BorderRadius.circular(AppTokens.radius16),
                border: Border.all(
                    color:
                        isDark ? AppColors.darkBorder : AppColors.grey100),
                boxShadow: isDark ? null : AppTokens.shadowMd,
              ),
              child: Column(
                children: [
                  SizedBox(
                    height: 80,
                    width: 80,
                    child: SvgPicture.asset(
                      'assets/images/app_logo.svg',
                      fit: BoxFit.contain,
                    ),
                  ),
                  const SizedBox(height: AppTokens.sp16),
                  Text(
                    'Financial Resume',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: isDark ? AppColors.darkText : AppColors.dark,
                    ),
                  ),
                  const SizedBox(height: AppTokens.sp8),
                  Text(
                    '${l.version} ${_packageInfo.version}',
                    style: TextStyle(
                      color: isDark
                          ? AppColors.darkSubtext
                          : AppColors.grey500,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: AppTokens.sp16),
                  Text(
                    l.yourCompleteSolution,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: isDark
                          ? AppColors.darkSubtext
                          : AppColors.grey500,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppTokens.sp16),
            _buildFeaturesSection(isDark, l),
            const SizedBox(height: AppTokens.sp16),
            _buildTechnicalInfo(isDark, l),
            const SizedBox(height: AppTokens.sp16),
            _buildDeveloperInfo(isDark, l),
            const SizedBox(height: AppTokens.sp24),
            _buildFooter(isDark, l),
          ],
        ),
      ),
    );
  }

  // ── Features section ──────────────────────────────────────────────────────
  Widget _buildFeaturesSection(bool isDark, AppLocalizations l) {
    final features = [
      (
        icon: Icons.camera_alt_rounded,
        title: l.smartScanning,
        desc: l.smartScanningDesc,
      ),
      (
        icon: Icons.analytics_rounded,
        title: l.detailedReports,
        desc: l.detailedReportsDesc,
      ),
      (
        icon: Icons.notifications_rounded,
        title: l.automaticReminders,
        desc: l.automaticRemindersDesc,
      ),
      (
        icon: Icons.security_rounded,
        title: l.totalPrivacy,
        desc: l.totalPrivacyDesc,
      ),
      (
        icon: Icons.photo_library_rounded,
        title: l.documentManagement,
        desc: l.documentManagementDesc,
      ),
      (
        icon: Icons.trending_up_rounded,
        title: l.budgetControl,
        desc: l.budgetControlDesc,
      ),
    ];

    return Container(
      padding: const EdgeInsets.all(AppTokens.sp16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : AppColors.white,
        borderRadius: BorderRadius.circular(AppTokens.radius16),
        border: Border.all(
            color: isDark ? AppColors.darkBorder : AppColors.grey100),
        boxShadow: isDark ? null : AppTokens.shadowSm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l.mainFeatures,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: isDark ? AppColors.darkText : AppColors.dark,
            ),
          ),
          const SizedBox(height: AppTokens.sp12),
          ...features.map((f) => _buildFeatureItem(
                icon: f.icon,
                title: f.title,
                description: f.desc,
                isDark: isDark,
              )),
        ],
      ),
    );
  }

  Widget _buildFeatureItem({
    required IconData icon,
    required String title,
    required String description,
    required bool isDark,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppTokens.sp12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(AppTokens.sp8),
            decoration: BoxDecoration(
              color: (isDark ? AppColors.info : AppColors.dark)
                  .withAlpha(isDark ? 30 : 15),
              borderRadius: BorderRadius.circular(AppTokens.radius8),
            ),
            child: Icon(
              icon,
              color: isDark ? AppColors.info : AppColors.dark,
              size: 20,
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
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  description,
                  style: TextStyle(
                    color: isDark
                        ? AppColors.darkSubtext
                        : AppColors.grey500,
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

  // ── Technical info ────────────────────────────────────────────────────────
  Widget _buildTechnicalInfo(bool isDark, AppLocalizations l) {
    return Container(
      padding: const EdgeInsets.all(AppTokens.sp16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : AppColors.white,
        borderRadius: BorderRadius.circular(AppTokens.radius16),
        border: Border.all(
            color: isDark ? AppColors.darkBorder : AppColors.grey100),
        boxShadow: isDark ? null : AppTokens.shadowSm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l.technicalInformation,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: isDark ? AppColors.darkText : AppColors.dark,
            ),
          ),
          const SizedBox(height: AppTokens.sp12),
          _buildInfoRow(l.version, _packageInfo.version, isDark),
          _buildInfoRow(l.buildNumber, _packageInfo.buildNumber, isDark),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppTokens.sp6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              color: isDark ? AppColors.darkSubtext : AppColors.grey500,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              color: isDark ? AppColors.darkText : AppColors.dark,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  // ── Developer card ────────────────────────────────────────────────────────
  Widget _buildDeveloperInfo(bool isDark, AppLocalizations l) {
    return Container(
      padding: const EdgeInsets.all(AppTokens.sp16),
      decoration: BoxDecoration(
        // Always uses a dark-ish tone — accent card
        color: isDark ? AppColors.darkSurface : AppColors.dark,
        borderRadius: BorderRadius.circular(AppTokens.radius16),
        border: isDark ? Border.all(color: AppColors.darkBorder) : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l.developer,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.white,
            ),
          ),
          const SizedBox(height: AppTokens.sp12),
          const Text(
            'Bruno Ramos',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppColors.white,
            ),
          ),
          const SizedBox(height: AppTokens.sp8),
          Text(
            l.appDescription1.replaceAll('{version}', _packageInfo.version),
            style: TextStyle(
              color: AppColors.white.withAlpha(220),
              fontSize: 14,
              height: 1.5,
            ),
          ),
          const SizedBox(height: AppTokens.sp8),
          Text(
            l.appDescription2,
            style: TextStyle(
              color: AppColors.white.withAlpha(220),
              fontSize: 14,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  // ── Footer ────────────────────────────────────────────────────────────────
  Widget _buildFooter(bool isDark, AppLocalizations l) {
    return Column(
      children: [
        Divider(
            color: isDark ? AppColors.darkBorder : AppColors.grey200),
        const SizedBox(height: AppTokens.sp16),
        Text(
          'Financial Resume ${_packageInfo.version}',
          style: TextStyle(
            color: isDark ? AppColors.darkText : AppColors.dark,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: AppTokens.sp8),
        Text(
          '${l.developedBy} Bruno Ramos',
          style: TextStyle(
            color: isDark ? AppColors.darkSubtext : AppColors.grey500,
            fontSize: 12,
          ),
        ),
        const SizedBox(height: AppTokens.sp4),
        Text(
          '© 2024 ${l.allRightsReserved}',
          style: TextStyle(
            color: isDark ? AppColors.darkSubtext : AppColors.grey500,
            fontSize: 12,
          ),
        ),
      ],
    );
  }
}
