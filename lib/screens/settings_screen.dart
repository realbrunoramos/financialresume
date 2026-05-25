import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../providers/language_provider.dart';
import '../providers/theme_provider.dart';
import '../services/database_service.dart';
import '../services/secure_storage_service.dart';
import '../theme/colors.dart';
import '../theme/app_tokens.dart';
import '../l10n/app_localizations.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final DatabaseService _db = DatabaseService();
  final TextEditingController _apiKeyCtrl = TextEditingController();
  String _lang = 'pt';
  bool _loading = true;
  bool _obscure = true;

  static const Map<String, String> _languages = {
    'pt': 'Português',
    'en': 'English',
    'es': 'Español',
    'fr': 'Français',
    'ru': 'Русский',
    'zh': '中文',
    'it': 'Italiano',
  };

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  @override
  void dispose() {
    _apiKeyCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    try {
      final apiKey  = await SecureStorageService.readApiKey();
      final langKey = await _db.getSetting('language');

      if (apiKey != null) _apiKeyCtrl.text = apiKey;

      setState(() {
        _lang = (langKey != null && _languages.containsKey(langKey))
            ? langKey
            : 'pt';
        _loading = false;
      });

      if (langKey == null) await _db.saveSetting('language', 'pt');
    } catch (_) {
      setState(() => _loading = false);
    }
  }

  Future<void> _save() async {
    final l = AppLocalizations.of(context);
    try {
      if (_apiKeyCtrl.text.isNotEmpty) {
        await SecureStorageService.writeApiKey(_apiKeyCtrl.text);
      }
      await _db.saveSetting('language', _lang);
      if (mounted) {
        context.read<LanguageProvider>().setLocaleFromString(_lang);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(l.settingsSaved),
          backgroundColor: AppColors.success,
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('${l.errorSavingSettings}: $e'),
          backgroundColor: AppColors.danger,
        ));
      }
    }
  }

  Future<void> _copyApiKey() async {
    if (_apiKeyCtrl.text.isEmpty) return;
    await Clipboard.setData(ClipboardData(text: _apiKeyCtrl.text));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(AppLocalizations.of(context).apiKeyCopied),
        backgroundColor: AppColors.success,
      ));
    }
  }

  Future<void> _launchUrl() async {
    const url = 'https://aistudio.google.com/app/apikey';
    try {
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        await launchUrl(uri, mode: LaunchMode.platformDefault);
      }
    } catch (_) {
      if (mounted) _showLinkDialog(url);
    }
  }

  void _showLinkDialog(String url) {
    final l      = AppLocalizations.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => SafeArea(
        child: Container(
          margin: const EdgeInsets.all(AppTokens.sp12),
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkCard : AppColors.white,
            borderRadius: BorderRadius.circular(AppTokens.radius24),
          ),
          padding: const EdgeInsets.all(AppTokens.sp20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(l.cantOpenLink,
                  style: TextStyle(
                      fontSize: 17, fontWeight: FontWeight.w700,
                      color: isDark ? AppColors.darkText : AppColors.dark)),
              const SizedBox(height: AppTokens.sp8),
              Text(l.copyPasteLink,
                  style: TextStyle(
                      color:
                          isDark ? AppColors.darkSubtext : AppColors.grey500)),
              const SizedBox(height: AppTokens.sp12),
              SelectableText(url,
                  style: const TextStyle(
                      color: AppColors.info,
                      decoration: TextDecoration.underline)),
              const SizedBox(height: AppTokens.sp20),
              Row(children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text(l.cancel),
                  ),
                ),
                const SizedBox(width: AppTokens.sp12),
                Expanded(
                  child: FilledButton(
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: url));
                      ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(l.linkCopied)));
                      Navigator.pop(context);
                    },
                    child: Text(l.copyLink),
                  ),
                ),
              ]),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final l      = AppLocalizations.of(context);

    return Scaffold(
      backgroundColor:
          isDark ? AppColors.darkBackground : const Color(0xFFF5F5F7),
      appBar: AppBar(
        backgroundColor: isDark ? AppColors.darkSurface : AppColors.white,
        foregroundColor: isDark ? AppColors.darkText : AppColors.dark,
        elevation: 0,
        title: Text(l.settings,
            style: const TextStyle(
                fontWeight: FontWeight.w700, letterSpacing: -0.3)),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(AppTokens.sp16),
              children: [
                // ── AI Section ─────────────────────────────────────────────
                _SectionLabel(label: 'AI', isDark: isDark),
                _SettingsCard(
                  isDark: isDark,
                  child: Padding(
                    padding: const EdgeInsets.all(AppTokens.sp16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Header
                        Row(children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: AppColors.info.withAlpha(isDark ? 40 : 20),
                              borderRadius:
                                  BorderRadius.circular(AppTokens.radius8),
                            ),
                            child: const Icon(Icons.auto_awesome_rounded,
                                color: AppColors.info, size: 18),
                          ),
                          const SizedBox(width: AppTokens.sp12),
                          Expanded(
                            child: Text(l.geminiApiKey,
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: isDark
                                      ? AppColors.darkText
                                      : AppColors.dark,
                                )),
                          ),
                        ]),
                        const SizedBox(height: AppTokens.sp8),
                        Text(l.apiKeyDescription,
                            style: TextStyle(
                                fontSize: 13,
                                color: isDark
                                    ? AppColors.darkSubtext
                                    : AppColors.grey500)),
                        const SizedBox(height: AppTokens.sp16),

                        // API key field
                        TextField(
                          controller: _apiKeyCtrl,
                          obscureText: _obscure,
                          style: TextStyle(
                              color:
                                  isDark ? AppColors.darkText : AppColors.dark),
                          decoration: InputDecoration(
                            labelText: l.geminiApiKey,
                            hintText: l.apiKeyHint,
                            suffixIcon: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: Icon(
                                    _obscure
                                        ? Icons.visibility_off_rounded
                                        : Icons.visibility_rounded,
                                    size: 20,
                                  ),
                                  onPressed: () =>
                                      setState(() => _obscure = !_obscure),
                                  tooltip: _obscure ? l.showKey : l.hideKey,
                                ),
                                if (_apiKeyCtrl.text.isNotEmpty)
                                  IconButton(
                                    icon: const Icon(Icons.copy_rounded,
                                        size: 20),
                                    onPressed: _copyApiKey,
                                    tooltip: l.copyKey,
                                  ),
                              ],
                            ),
                          ),
                          onChanged: (_) => setState(() {}),
                        ),
                        const SizedBox(height: AppTokens.sp8),
                        Row(children: [
                          const Icon(Icons.lock_outline_rounded,
                              size: 13, color: AppColors.grey400),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(l.apiKeySecurity,
                                style: const TextStyle(
                                    fontSize: 12,
                                    color: AppColors.grey400,
                                    fontStyle: FontStyle.italic)),
                          ),
                        ]),
                        const SizedBox(height: AppTokens.sp16),
                        const Divider(),
                        const SizedBox(height: AppTokens.sp12),

                        // How to get
                        Row(children: [
                          const Icon(Icons.help_outline_rounded,
                              size: 18, color: AppColors.info),
                          const SizedBox(width: AppTokens.sp8),
                          Text(l.howToGetApiKey,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: isDark
                                    ? AppColors.darkText
                                    : AppColors.dark,
                              )),
                        ]),
                        const SizedBox(height: AppTokens.sp8),
                        Text(l.apiKeyInstructions,
                            style: TextStyle(
                                fontSize: 13,
                                height: 1.6,
                                color: isDark
                                    ? AppColors.darkSubtext
                                    : AppColors.grey500)),
                        const SizedBox(height: AppTokens.sp16),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton.icon(
                            onPressed: _launchUrl,
                            icon: const Icon(Icons.open_in_new_rounded,
                                size: 18),
                            label: Text(l.getApiKey),
                            style: FilledButton.styleFrom(
                              backgroundColor: AppColors.info,
                              padding: const EdgeInsets.symmetric(
                                  vertical: AppTokens.sp14),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: AppTokens.sp20),

                // ── Language Section ───────────────────────────────────────
                _SectionLabel(label: l.language, isDark: isDark),
                _SettingsCard(
                  isDark: isDark,
                  child: Padding(
                    padding: const EdgeInsets.all(AppTokens.sp16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color:
                                  AppColors.success.withAlpha(isDark ? 40 : 20),
                              borderRadius:
                                  BorderRadius.circular(AppTokens.radius8),
                            ),
                            child: const Icon(Icons.language_rounded,
                                color: AppColors.success, size: 18),
                          ),
                          const SizedBox(width: AppTokens.sp12),
                          Expanded(
                            child: Text(l.language,
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: isDark
                                      ? AppColors.darkText
                                      : AppColors.dark,
                                )),
                          ),
                        ]),
                        const SizedBox(height: AppTokens.sp16),
                        DropdownButtonFormField<String>(
                          key: ValueKey(_lang),
                          initialValue: _lang,
                          dropdownColor:
                              isDark ? AppColors.darkCard : AppColors.white,
                          decoration: InputDecoration(
                            labelText: l.selectLanguage,
                          ),
                          items: _languages.entries
                              .map((e) => DropdownMenuItem(
                                    value: e.key,
                                    child: Text(e.value),
                                  ))
                              .toList(),
                          onChanged: (v) {
                            if (v != null) setState(() => _lang = v);
                          },
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: AppTokens.sp20),

                // ── Appearance Section ─────────────────────────────────────
                _SectionLabel(label: l.appearance, isDark: isDark),
                _SettingsCard(
                  isDark: isDark,
                  child: Padding(
                    padding: const EdgeInsets.all(AppTokens.sp16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: AppColors.warning.withAlpha(isDark ? 40 : 20),
                              borderRadius: BorderRadius.circular(AppTokens.radius8),
                            ),
                            child: const Icon(Icons.brightness_6_rounded,
                                color: AppColors.warning, size: 18),
                          ),
                          const SizedBox(width: AppTokens.sp12),
                          Expanded(
                            child: Text(l.theme,
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: isDark ? AppColors.darkText : AppColors.dark,
                                )),
                          ),
                        ]),
                        const SizedBox(height: AppTokens.sp16),
                        Consumer<ThemeProvider>(
                          builder: (_, themeProvider, __) =>
                            SegmentedButton<ThemeMode>(
                              style: SegmentedButton.styleFrom(
                                backgroundColor: isDark
                                    ? AppColors.darkBackground
                                    : AppColors.grey100,
                                selectedBackgroundColor: isDark
                                    ? AppColors.darkCard
                                    : AppColors.dark,
                                selectedForegroundColor: AppColors.white,
                                foregroundColor: isDark
                                    ? AppColors.darkSubtext
                                    : AppColors.grey500,
                              ),
                              segments: [
                                ButtonSegment(
                                  value: ThemeMode.light,
                                  icon: const Icon(Icons.light_mode_rounded, size: 17),
                                  label: Text(l.themeLight),
                                ),
                                ButtonSegment(
                                  value: ThemeMode.system,
                                  icon: const Icon(Icons.phone_android_rounded, size: 17),
                                  label: Text(l.themeSystem),
                                ),
                                ButtonSegment(
                                  value: ThemeMode.dark,
                                  icon: const Icon(Icons.dark_mode_rounded, size: 17),
                                  label: Text(l.themeDark),
                                ),
                              ],
                              selected: {themeProvider.mode},
                              onSelectionChanged: (selected) =>
                                  context.read<ThemeProvider>().setMode(selected.first),
                            ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: AppTokens.sp28),

                // ── Save button ────────────────────────────────────────────
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _save,
                    icon: const Icon(Icons.save_rounded),
                    label: Text(l.saveAllSettings),
                    style: FilledButton.styleFrom(
                      backgroundColor:
                          isDark ? AppColors.info : AppColors.dark,
                      padding: const EdgeInsets.symmetric(
                          vertical: AppTokens.sp16),
                    ),
                  ),
                ),
                const SizedBox(height: AppTokens.sp32),
              ],
            ),
    );
  }
}

// ── Helpers ───────────────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final String label;
  final bool isDark;
  const _SectionLabel({required this.label, required this.isDark});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(
            left: AppTokens.sp4, bottom: AppTokens.sp8),
        child: Text(
          label.toUpperCase(),
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.9,
            color: isDark ? AppColors.darkSubtext : AppColors.grey500,
          ),
        ),
      );
}

class _SettingsCard extends StatelessWidget {
  final bool isDark;
  final Widget child;
  const _SettingsCard({required this.isDark, required this.child});

  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkCard : AppColors.white,
          borderRadius: BorderRadius.circular(AppTokens.radius16),
          border: Border.all(
              color: isDark ? AppColors.darkBorder : AppColors.grey100),
          boxShadow: isDark ? null : AppTokens.shadowSm,
        ),
        child: child,
      );
}
