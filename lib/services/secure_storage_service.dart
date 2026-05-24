import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SecureStorageService {
  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );
  static const _keyGeminiApiKey = 'gemini_api_key';

  static Future<String?> readApiKey() =>
      _storage.read(key: _keyGeminiApiKey);

  static Future<void> writeApiKey(String value) =>
      _storage.write(key: _keyGeminiApiKey, value: value);
}
