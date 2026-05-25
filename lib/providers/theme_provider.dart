import 'package:flutter/material.dart';
import '../services/database_service.dart';

/// Persists and exposes the user's preferred [ThemeMode].
/// Loaded from the settings table on construction; changes are
/// immediately persisted and reflected across the app.
class ThemeProvider with ChangeNotifier {
  ThemeMode _mode = ThemeMode.system;
  final DatabaseService _db = DatabaseService();

  ThemeMode get mode => _mode;

  ThemeProvider() {
    _load();
  }

  Future<void> _load() async {
    try {
      final saved = await _db.getSetting('theme_mode');
      if (saved != null) {
        final resolved = ThemeMode.values.firstWhere(
          (e) => e.name == saved,
          orElse: () => ThemeMode.system,
        );
        if (resolved != _mode) {
          _mode = resolved;
          notifyListeners();
        }
      }
    } catch (e) {
      debugPrint('ThemeProvider._load error: $e');
    }
  }

  Future<void> setMode(ThemeMode mode) async {
    if (_mode == mode) return;
    _mode = mode;
    notifyListeners();
    try {
      await _db.saveSetting('theme_mode', mode.name);
    } catch (e) {
      debugPrint('ThemeProvider.setMode save error: $e');
    }
  }
}
