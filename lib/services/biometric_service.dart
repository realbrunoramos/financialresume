/// BiometricService — on-device biometric / PIN authentication.
///
/// Wraps the `local_auth` package.  Call [authenticate] to prompt the user;
/// it returns true on success, false if the user cancels or no hardware is
/// available.
///
/// Enable/disable the lock via the settings key `biometric_lock` in the
/// SQLite settings table (persisted through DatabaseService).
library;

import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';
import 'database_service.dart';

class BiometricService {
  BiometricService._();

  static final LocalAuthentication _auth = LocalAuthentication();
  static final DatabaseService _db = DatabaseService();

  // ── Capability checks ──────────────────────────────────────────────────────

  /// Returns true when the device supports biometrics or device credentials.
  static Future<bool> isAvailable() async {
    try {
      return await _auth.canCheckBiometrics || await _auth.isDeviceSupported();
    } catch (_) {
      return false;
    }
  }

  /// Returns the list of enrolled biometric types (e.g. face / fingerprint).
  static Future<List<BiometricType>> enrolledBiometrics() async {
    try {
      return await _auth.getAvailableBiometrics();
    } catch (_) {
      return [];
    }
  }

  // ── Settings persistence ───────────────────────────────────────────────────

  /// Returns true when the user has enabled biometric lock in Settings.
  static Future<bool> isEnabled() async {
    final val = await _db.getSetting('biometric_lock');
    return val == 'true';
  }

  /// Persist the user's choice.
  static Future<void> setEnabled({required bool enabled}) async {
    await _db.saveSetting('biometric_lock', enabled ? 'true' : 'false');
  }

  // ── Authentication ─────────────────────────────────────────────────────────

  /// Prompt the user to authenticate.
  ///
  /// [localizedReason] is shown in the system dialog.
  /// Returns false if hardware is unavailable, authentication fails,
  /// or the user cancels.
  static Future<bool> authenticate({
    required String localizedReason,
  }) async {
    try {
      final available = await isAvailable();
      if (!available) return false;

      return await _auth.authenticate(
        localizedReason: localizedReason,
        options: const AuthenticationOptions(
          biometricOnly: false, // allow device PIN / pattern as fallback
          stickyAuth: true,     // keep the prompt open on app switch
        ),
      );
    } on PlatformException {
      return false;
    } catch (_) {
      return false;
    }
  }
}
