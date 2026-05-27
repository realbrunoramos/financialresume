import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SecureStorageService {
  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  // ── Keys ──────────────────────────────────────────────────────────────────
  static const _keyGeminiApiKey  = 'gemini_api_key';
  static const _keyEmail         = 'email';
  static const _keyPassword      = 'password';
  static const _keySmtpServer    = 'smtp_server';
  static const _keySmtpPort      = 'smtp_port';

  // ── Gemini API key ────────────────────────────────────────────────────────
  static Future<String?> readApiKey() =>
      _storage.read(key: _keyGeminiApiKey);

  static Future<void> writeApiKey(String value) =>
      _storage.write(key: _keyGeminiApiKey, value: value);

  // ── Email credentials ─────────────────────────────────────────────────────
  static Future<String?> readEmail() =>
      _storage.read(key: _keyEmail);

  static Future<void> writeEmail(String value) =>
      _storage.write(key: _keyEmail, value: value);

  static Future<String?> readPassword() =>
      _storage.read(key: _keyPassword);

  static Future<void> writePassword(String value) =>
      _storage.write(key: _keyPassword, value: value);

  static Future<String?> readSmtpServer() =>
      _storage.read(key: _keySmtpServer);

  static Future<void> writeSmtpServer(String value) =>
      _storage.write(key: _keySmtpServer, value: value);

  static Future<String?> readSmtpPort() =>
      _storage.read(key: _keySmtpPort);

  static Future<void> writeSmtpPort(String value) =>
      _storage.write(key: _keySmtpPort, value: value);

  /// Read all email-related credentials at once.
  static Future<({String? email, String? password, String? smtpServer, String? smtpPort})>
      readEmailCredentials() async {
    final results = await Future.wait([
      _storage.read(key: _keyEmail),
      _storage.read(key: _keyPassword),
      _storage.read(key: _keySmtpServer),
      _storage.read(key: _keySmtpPort),
    ]);
    return (
      email:      results[0],
      password:   results[1],
      smtpServer: results[2],
      smtpPort:   results[3],
    );
  }

  /// Write all email-related credentials at once.
  static Future<void> writeEmailCredentials({
    required String email,
    required String password,
    String smtpServer = 'smtp.gmail.com',
    String smtpPort   = '587',
  }) async {
    await Future.wait([
      _storage.write(key: _keyEmail,      value: email),
      _storage.write(key: _keyPassword,   value: password),
      _storage.write(key: _keySmtpServer, value: smtpServer),
      _storage.write(key: _keySmtpPort,   value: smtpPort),
    ]);
  }
}
