import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../l10n/app_localizations.dart';
import '../theme/colors.dart';

class AboutScreen extends StatefulWidget {
  const AboutScreen({super.key});

  @override
  State<AboutScreen> createState() => _AboutScreenState();
}

class _AboutScreenState extends State<AboutScreen> {
  PackageInfo _packageInfo = PackageInfo(
    appName: 'Financial Resume',
    packageName: 'Financial Resume',
    version: "2.0.2",
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
    return Scaffold(
      backgroundColor: AppColors.light,
      appBar: AppBar(
        title: Text(
          AppLocalizations.of(context).about,
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
          children: [
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppColors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.black.withAlpha(50),
                    blurRadius: 8,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Container(
                    height: 80,
                    width: 80,
                    child: SvgPicture.asset(
                      'assets/images/app_logo.svg',
                      fit: BoxFit.contain,
                    ),
                  ),
                  SizedBox(height: 16),
                  Text(
                    'Financial Resume',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: AppColors.dark,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    '${AppLocalizations.of(context).version} ${_packageInfo.version}',
                    style: TextStyle(
                      color: AppColors.grey,
                      fontSize: 14,
                    ),
                  ),
                  SizedBox(height: 16),
                  Text(
                    AppLocalizations.of(context).yourCompleteSolution,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: AppColors.grey,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: 16),
            _buildFeaturesSection(context),
            SizedBox(height: 16),
            _buildTechnicalInfo(context),
            SizedBox(height: 16),
            _buildDeveloperInfo(context),
            SizedBox(height: 24),
            _buildFooter(context),
          ],
        ),
      ),
    );
  }

  Widget _buildFeaturesSection(BuildContext context) {
    final features = [
      {
        'icon': Icons.camera_alt,
        'title': AppLocalizations.of(context).smartScanning,
        'desc': AppLocalizations.of(context).smartScanningDesc,
      },
      {
        'icon': Icons.analytics,
        'title': AppLocalizations.of(context).detailedReports,
        'desc': AppLocalizations.of(context).detailedReportsDesc,
      },
      {
        'icon': Icons.notifications,
        'title': AppLocalizations.of(context).automaticReminders,
        'desc': AppLocalizations.of(context).automaticRemindersDesc,
      },
      {
        'icon': Icons.security,
        'title': AppLocalizations.of(context).totalPrivacy,
        'desc': AppLocalizations.of(context).totalPrivacyDesc,
      },
      {
        'icon': Icons.photo_library,
        'title': AppLocalizations.of(context).documentManagement,
        'desc': AppLocalizations.of(context).documentManagementDesc,
      },
      {
        'icon': Icons.trending_up,
        'title': AppLocalizations.of(context).budgetControl,
        'desc': AppLocalizations.of(context).budgetControlDesc,
      },
    ];

    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: AppColors.black.withAlpha(10),
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            AppLocalizations.of(context).mainFeatures,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.dark,
            ),
          ),
          SizedBox(height: 12),
          ...features.map((feature) => _buildFeatureItem(
            icon: feature['icon'] as IconData,
            title: feature['title'] as String,
            description: feature['desc'] as String,
          )).toList(),
        ],
      ),
    );
  }

  Widget _buildFeatureItem({
    required IconData icon,
    required String title,
    required String description,
  }) {
    return Container(
      margin: EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.dark.withAlpha(50),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              icon,
              color: AppColors.dark,
              size: 20,
            ),
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
                    fontSize: 14,
                  ),
                ),
                SizedBox(height: 2),
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

  Widget _buildTechnicalInfo(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: AppColors.black.withAlpha(10),
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            AppLocalizations.of(context).technicalInformation,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.dark,
            ),
          ),
          SizedBox(height: 12),
          _buildInfoRow(
            AppLocalizations.of(context).version,
            _packageInfo.version,
          ),
          _buildInfoRow(
            AppLocalizations.of(context).buildNumber,
            _packageInfo.buildNumber,
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              color: AppColors.grey,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              color: AppColors.dark,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDeveloperInfo(BuildContext context) {
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
            AppLocalizations.of(context).developer,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.white,
            ),
          ),
          SizedBox(height: 12),
          Text(
            'Bruno Ramos',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppColors.white,
            ),
          ),
          SizedBox(height: 8),
          Text(
            AppLocalizations.of(context).appDescription1.replaceAll(
              '{version}',
              _packageInfo.version,
            ),
            style: TextStyle(
              color: AppColors.white.withAlpha(250),
              fontSize: 14,
              height: 1.5,
            ),
          ),
          SizedBox(height: 8),
          Text(
            AppLocalizations.of(context).appDescription2,
            style: TextStyle(
              color: AppColors.white.withAlpha(250),
              fontSize: 14,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFooter(BuildContext context) {
    return Column(
      children: [
        Divider(color: AppColors.grey.withAlpha(70)),
        SizedBox(height: 16),
        Text(
          'Financial Resume ${_packageInfo.version}',
          style: TextStyle(
            color: AppColors.dark,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
        SizedBox(height: 8),
        Text(
          '${AppLocalizations.of(context).developedBy} Bruno Ramos',
          style: TextStyle(
            color: AppColors.grey,
            fontSize: 12,
          ),
        ),
        SizedBox(height: 4),
        Text(
          '© 2024 ${AppLocalizations.of(context).allRightsReserved}',
          style: TextStyle(
            color: AppColors.grey,
            fontSize: 12,
          ),
        ),
      ],
    );
  }
}