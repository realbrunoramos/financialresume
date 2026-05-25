import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import '../services/database_service.dart';

class LanguageProvider with ChangeNotifier {
  Locale _locale = Locale('pt');
  final DatabaseService _dbService = DatabaseService();

  Locale get locale => _locale;

  LanguageProvider() {
    _loadSavedLanguage();
  }

  Future<void> _loadSavedLanguage() async {
    try {
      final language = await _dbService.getSetting('language');
      if (language != null && language.isNotEmpty) {
        _locale = Locale(language);
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error loading language: $e');
    }
  }

  Future<void> setLocale(Locale newLocale) async {
    _locale = newLocale;
    await _dbService.saveSetting('language', newLocale.languageCode);
    notifyListeners();
  }

  Future<void> setLocaleFromString(String languageCode) async {
    _locale = Locale(languageCode);
    await _dbService.saveSetting('language', languageCode);
    notifyListeners();
  }
}