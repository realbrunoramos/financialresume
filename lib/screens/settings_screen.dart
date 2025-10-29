import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../providers/language_provider.dart';
import '../services/database_service.dart';
import '../theme/colors.dart';
import '../l10n/app_localizations.dart';

class SettingsScreen extends StatefulWidget {
  @override
  _SettingsScreenState createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final DatabaseService _dbService = DatabaseService();
  final TextEditingController _apiKeyController = TextEditingController();
  String _selectedLanguage = 'pt';
  bool _isLoading = true;
  bool _obscureApiKey = true;

  final Map<String, String> _languages = {
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

  Future<void> _launchURL() async {
    const url = 'https://aistudio.google.com/app/apikey';

    try {
      final uri = Uri.parse(url);

      if (await canLaunchUrl(uri)) {
        await launchUrl(
          uri,
          mode: LaunchMode.externalApplication,
        );
      } else {
        await launchUrl(
          uri,
          mode: LaunchMode.platformDefault,
        );
      }
    } catch (e) {
      if (mounted) {
        _showLinkDialog(url);
      }
    }
  }

  void _showLinkDialog(String url) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(AppLocalizations.of(context).cantOpenLink),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(AppLocalizations.of(context).copyPasteLink),
            SizedBox(height: 10),
            SelectableText(
              url,
              style: TextStyle(
                color: AppColors.blue,
                decoration: TextDecoration.underline,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(AppLocalizations.of(context).cancel),
          ),
          ElevatedButton(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: url));
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(AppLocalizations.of(context).linkCopied)),
              );
              Navigator.pop(context);
            },
            child: Text(AppLocalizations.of(context).copyLink),
          ),
        ],
      ),
    );
  }

  Future<void> _loadSettings() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final apiKey = await _dbService.getSetting('gemini_api_key');
      if (apiKey != null) {
        _apiKeyController.text = apiKey;
      }

      final language = await _dbService.getSetting('language');
      if (language != null && _languages.containsKey(language)) {
        _selectedLanguage = language;
      } else {
        _selectedLanguage = 'pt';
        await _dbService.saveSetting('language', 'pt');
      }

      if (apiKey == null) {
        await _dbService.saveSetting('gemini_api_key', 'AIzaSyDUpBTcTpDLDbbiKw0BAjsHhB7cJVkT5ag');
      }
    } catch (e) {
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _saveSettings() async {
    try {
      if (_apiKeyController.text.isNotEmpty) {
        await _dbService.saveSetting('gemini_api_key', _apiKeyController.text);
      }

      await _dbService.saveSetting('language', _selectedLanguage);
      final languageProvider = Provider.of<LanguageProvider>(context, listen: false);
      languageProvider.setLocaleFromString(_selectedLanguage);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context).settingsSaved),
            backgroundColor: AppColors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${AppLocalizations.of(context).errorSavingSettings}: $e'),
            backgroundColor: AppColors.red,
          ),
        );
      }
    }
  }

  Future<void> _copyApiKey() async {
    if (_apiKeyController.text.isNotEmpty) {
      await Clipboard.setData(ClipboardData(text: _apiKeyController.text));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context).apiKeyCopied),
            backgroundColor: AppColors.green,
          ),
        );
      }
    }
  }

  Widget _buildApiKeySection() {
    return Card(
      elevation: 4,
      margin: EdgeInsets.symmetric(vertical: 8),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Image.network(
                  'https://img.icons8.com/?size=100&id=rnK88i9FvAFO&format=png&color=000000',
                  width: 28,
                  height: 28,
                  color: AppColors.dark,
                  errorBuilder: (context, error, stackTrace) =>
                      Icon(Icons.api, color: AppColors.dark),
                ),
                SizedBox(width: 8),
                Text(
                  AppLocalizations.of(context).geminiApiKey,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.dark,
                  ),
                ),
              ],
            ),

            SizedBox(height: 12),
            Text(AppLocalizations.of(context).apiKeyDescription,
              style: TextStyle(color: AppColors.grey.shade700),),
            SizedBox(height: 16),
            TextField(
              controller: _apiKeyController,
              obscureText: _obscureApiKey,
              decoration: InputDecoration(
                labelText: AppLocalizations.of(context).geminiApiKey,
                hintText: AppLocalizations.of(context).apiKeyHint,
                border: const OutlineInputBorder(),
                suffixIcon: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: Icon(
                        _obscureApiKey ? Icons.visibility_off : Icons.visibility,
                        size: 20,
                      ),
                      onPressed: () {
                        setState(() {
                          _obscureApiKey = !_obscureApiKey;
                        });
                      },
                      tooltip: _obscureApiKey ?
                      AppLocalizations.of(context).showKey :
                      AppLocalizations.of(context).hideKey,
                    ),

                    if (_apiKeyController.text.isNotEmpty)
                      IconButton(
                        icon: const Icon(Icons.content_copy, size: 20),
                        onPressed: _copyApiKey,
                        tooltip: AppLocalizations.of(context).copyKey,
                      ),

                  ],
                ),
              ),
              onChanged: (_) => setState(() {}),
            ),

            SizedBox(height: 8),
            Text(
              AppLocalizations.of(context).apiKeySecurity,
              style: TextStyle(
                fontSize: 12,
                color: AppColors.grey.shade600,
                fontStyle: FontStyle.italic,
              ),
            ),

            SizedBox(height: 8,),
            Padding(
              padding: EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.help_outline, color: AppColors.dark),
                      SizedBox(width: 8),
                      Text(
                        AppLocalizations.of(context).howToGetApiKey,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppColors.dark,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 12),
                  Text(
                    AppLocalizations.of(context).apiKeyInstructions,
                    style: TextStyle(color: AppColors.grey.shade700),
                  ),
                  SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: _launchURL,
                    icon: Icon(Icons.open_in_new, size: 20),
                    label: Text(
                      AppLocalizations.of(context).getApiKey,
                      style: TextStyle(fontSize: 14),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.blue,
                      foregroundColor: AppColors.white,
                      minimumSize: Size(double.infinity, 50),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLanguageSection() {
    return Card(
      elevation: 4,
      margin: EdgeInsets.symmetric(vertical: 8),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.language, color: AppColors.dark),
                SizedBox(width: 8),
                Text(
                  AppLocalizations.of(context).language,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.dark,
                  ),
                ),
              ],
            ),
            SizedBox(height: 12),
            DropdownButtonFormField<String>(
              dropdownColor: Colors.white,
              value: _selectedLanguage,
              decoration: InputDecoration(
                labelText: AppLocalizations.of(context).selectLanguage,
                border: OutlineInputBorder(),
              ),
              items: _languages.entries.map((entry) {
                return DropdownMenuItem(
                  value: entry.key,
                  child: Text(entry.value),
                );
              }).toList(),
              onChanged: (String? newValue) {
                if (newValue != null) {
                  setState(() {
                    _selectedLanguage = newValue;
                  });
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(

      backgroundColor: AppColors.light,
      appBar: AppBar(
        title: Text(AppLocalizations.of(context).settings),
        backgroundColor: AppColors.white,
        elevation: 0,
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: Column(
          children: [
            _buildApiKeySection(),
            _buildLanguageSection(),
            SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: _saveSettings,
              icon: Icon(Icons.save),
              label: Text(AppLocalizations.of(context).saveAllSettings),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.dark,
                foregroundColor: AppColors.white,
                minimumSize: Size(double.infinity, 50),
              ),
            ),
          ],
        ),
      ),
    );
  }
}