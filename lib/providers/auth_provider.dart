/// AuthProvider — ChangeNotifier wrapping FirebaseAuth state.
///
/// Responsibilities:
/// • Exposes [currentUser], [isSignedIn], [isSyncing], [syncError].
/// • On sign-in → initialises [SyncService] and triggers a full sync.
/// • On sign-out → disposes [SyncService].
/// • When [cloudEnabled] is false the provider is a no-op (offline mode).
library;

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../services/auth_service.dart';
import '../services/sync_service.dart';

class AuthProvider extends ChangeNotifier {
  // ── State ──────────────────────────────────────────────────────────────────
  User?   _user;
  bool          _isSyncing    = false;
  String?       _syncError;
  final bool    _cloudEnabled;
  DateTime?     _lastSyncAt;

  AuthProvider({bool cloudEnabled = false})
      : _cloudEnabled = cloudEnabled {
    if (_cloudEnabled) _startListening();
  }

  // ── Getters ────────────────────────────────────────────────────────────────
  User?     get currentUser   => _user;
  bool      get isSignedIn    => _user != null;
  bool      get isSyncing     => _isSyncing;
  String?   get syncError     => _syncError;
  bool      get cloudEnabled  => _cloudEnabled;
  DateTime? get lastSyncAt    => _lastSyncAt;

  String get userDisplayName => _user?.displayName ?? _user?.email ?? '';
  String get userEmail       => _user?.email ?? '';
  String get userPhotoUrl    => _user?.photoURL ?? '';

  // ── Auth state stream ──────────────────────────────────────────────────────

  void _startListening() {
    AuthService.authStateChanges.listen(_onAuthStateChanged);
  }

  Future<void> _onAuthStateChanged(User? user) async {
    _user = user;
    notifyListeners();

    if (user != null) {
      SyncService.instance.init(user.uid);
      await _doFullSync();
    } else {
      SyncService.instance.dispose();
    }
  }

  // ── Actions ────────────────────────────────────────────────────────────────

  /// Launches the Google OAuth flow.  Updates state regardless of outcome.
  Future<void> signInWithGoogle() async {
    if (!_cloudEnabled) return;
    _syncError = null;
    _isSyncing = true;
    notifyListeners();
    try {
      await AuthService.signInWithGoogle();
      // Auth state listener handles the rest.
    } on FirebaseAuthException catch (e) {
      _syncError = e.message;
      debugPrint('[AuthProvider] FirebaseAuthException: ${e.code}');
    } catch (e) {
      _syncError = e.toString();
      debugPrint('[AuthProvider] signInWithGoogle error: $e');
    } finally {
      _isSyncing = false;
      notifyListeners();
    }
  }

  /// Signs out and clears all provider state.
  Future<void> signOut() async {
    if (!_cloudEnabled) return;
    await AuthService.signOut();
    // Auth state listener sets _user = null.
  }

  /// Deletes the Firebase account and remote data.
  Future<void> deleteAccount() async {
    if (!_cloudEnabled || !isSignedIn) return;
    try {
      await SyncService.instance.wipeRemoteData();
      await AuthService.deleteAccount();
    } catch (e) {
      debugPrint('[AuthProvider] deleteAccount error: $e');
      rethrow;
    }
  }

  /// Manually triggers an incremental sync (processes pending queue).
  Future<void> triggerSync() async {
    if (!isSignedIn) return;
    _syncError  = null;
    _isSyncing  = true;
    notifyListeners();
    try {
      await SyncService.instance.processPendingQueue();
      _lastSyncAt = DateTime.now();
    } catch (e) {
      _syncError = e.toString();
      debugPrint('[AuthProvider] triggerSync error: $e');
    } finally {
      _isSyncing = false;
      notifyListeners();
    }
  }

  /// Restores all data from Firestore into a fresh local DB.
  Future<void> restoreFromCloud() async {
    if (!isSignedIn) return;
    _syncError = null;
    _isSyncing = true;
    notifyListeners();
    try {
      await SyncService.instance.restoreFromCloud();
      _lastSyncAt = DateTime.now();
    } catch (e) {
      _syncError = e.toString();
    } finally {
      _isSyncing = false;
      notifyListeners();
    }
  }

  // ── Internal ───────────────────────────────────────────────────────────────

  Future<void> _doFullSync() async {
    _isSyncing = true;
    _syncError = null;
    notifyListeners();
    try {
      await SyncService.instance.fullSync();
      _lastSyncAt = DateTime.now();
    } catch (e) {
      _syncError = e.toString();
      debugPrint('[AuthProvider] _doFullSync error: $e');
    } finally {
      _isSyncing = false;
      notifyListeners();
    }
  }
}
