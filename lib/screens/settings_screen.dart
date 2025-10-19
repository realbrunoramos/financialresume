import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/database_service.dart';
import '../theme/colors.dart';

class SettingsScreen extends StatefulWidget {
  @override
  _SettingsScreenState createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final DatabaseService _dbService = DatabaseService();
  final TextEditingController _apiKeyController = TextEditingController();
  String _selectedLanguage = 'pt';
  bool _isLoading = true;

  final Map<String, String> _languages = {
    'pt': 'Português',
    'en': 'English',
    'es': 'Español',
    'fr': 'Français',
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
      print('Erro ao abrir URL: $e');

      // Fallback final: mostrar diálogo com o link
      if (mounted) {
        _showLinkDialog(url);
      }
    }
  }

  // Diálogo de fallback se não conseguir abrir o link
  void _showLinkDialog(String url) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Não foi possível abrir o link automaticamente'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Por favor, copie e cole este link no seu browser:'),
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
            child: Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: url));
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Link copiado para a área de transferência!')),
              );
              Navigator.pop(context);
            },
            child: Text('Copiar Link'),
          ),
        ],
      ),
    );
  }

  // MÉTODO ALTERNATIVO - URL mais simples
  Future<void> _launchSimpleURL() async {
    const url = 'https://aistudio.google.com/';

    try {
      final uri = Uri.parse(url);
      await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
    } catch (e) {
      print('Erro ao abrir URL simples: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao abrir link. Aceda manualmente a: aistudio.google.com'),
            backgroundColor: AppColors.red,
          ),
        );
      }
    }
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
    } catch (e) {
      print('Erro ao carregar configurações: $e');
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

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Configurações salvas com sucesso!'),
            backgroundColor: AppColors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao salvar configurações: $e'),
            backgroundColor: AppColors.red,
          ),
        );
      }
    }
  }

  Future<void> _clearApiKey() async {
    await _dbService.saveSetting('gemini_api_key', '');
    _apiKeyController.clear();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Chave API removida!'),
          backgroundColor: AppColors.green,
        ),
      );
    }
  }

  Future<void> _copyApiKey() async {
    if (_apiKeyController.text.isNotEmpty) {
      await Clipboard.setData(ClipboardData(text: _apiKeyController.text));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Chave API copiada para a área de transferência!'),
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
                Icon(Icons.api, color: AppColors.dark),
                SizedBox(width: 8),
                Text(
                  'Chave API Gemini',
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
              'Para obter análise automática de documentos, insira sua chave da API Google Gemini:',
              style: TextStyle(color: AppColors.grey.shade700),
            ),
            SizedBox(height: 16),
            TextField(
              controller: _apiKeyController,
              decoration: InputDecoration(
                labelText: 'Chave API Gemini',
                hintText: 'AIzaSy...',
                border: OutlineInputBorder(),
                suffixIcon: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_apiKeyController.text.isNotEmpty)
                      IconButton(
                        icon: Icon(Icons.content_copy, size: 20),
                        onPressed: _copyApiKey,
                        tooltip: 'Copiar chave',
                      ),
                    if (_apiKeyController.text.isNotEmpty)
                      IconButton(
                        icon: Icon(Icons.clear, size: 20),
                        onPressed: _clearApiKey,
                        tooltip: 'Limpar chave',
                      ),
                  ],
                ),
              ),
              obscureText: true,
            ),
            SizedBox(height: 8),
            Text(
              'A chave é armazenada localmente no seu dispositivo e nunca é partilhada.',
              style: TextStyle(
                fontSize: 12,
                color: AppColors.grey.shade600,
                fontStyle: FontStyle.italic,
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
                  'Idioma',
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
              value: _selectedLanguage,
              decoration: InputDecoration(
                labelText: 'Selecionar Idioma',
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

  Widget _buildHelpSection() {
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
                Icon(Icons.help_outline, color: AppColors.dark),
                SizedBox(width: 8),
                Text(
                  'Como obter a chave API',
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
              '1. Aceda ao Google AI Studio usando o botão abaixo\n'
                  '2. Faça login com sua conta Google\n'
                  '3. Clique em "Create API Key" no menu lateral\n'
                  '4. Selecione o projeto e crie uma nova chave\n'
                  '5. Copie e cole a chave no campo acima',
              style: TextStyle(color: AppColors.grey.shade700),
            ),
            SizedBox(height: 16),
            // BOTÃO PRINCIPAL
            ElevatedButton.icon(
              onPressed: _launchURL,
              icon: Icon(Icons.open_in_new, size: 20),
              label: Text(
                'Obter Chave API no Google AI Studio',
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
            SizedBox(height: 8),
            // BOTÃO ALTERNATIVO
            OutlinedButton.icon(
              onPressed: _launchSimpleURL,
              icon: Icon(Icons.public, size: 18),
              label: Text(
                'Abrir Google AI Studio (Site Principal)',
                style: TextStyle(fontSize: 12),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.dark,
                minimumSize: Size(double.infinity, 40),
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Se os botões não funcionarem, aceda manualmente a: aistudio.google.com',
              style: TextStyle(
                fontSize: 12,
                color: AppColors.grey.shade600,
                fontStyle: FontStyle.italic,
              ),
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
        title: Text('Definições'),
        backgroundColor: AppColors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(Icons.save),
            onPressed: _saveSettings,
            tooltip: 'Salvar configurações',
          ),
        ],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: Column(
          children: [
            _buildApiKeySection(),
            _buildLanguageSection(),
            _buildHelpSection(),
            SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: _saveSettings,
              icon: Icon(Icons.save),
              label: Text('Salvar Todas as Configurações'),
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