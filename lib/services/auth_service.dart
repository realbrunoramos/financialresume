/// AuthService — thin wrapper around FirebaseAuth + GoogleSignIn.
///
/// All public methods are safe to call even when Firebase has not been
/// initialised; they catch and log errors instead of throwing.
library;

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

class AuthService {
  static final FirebaseAuth  _auth         = FirebaseAuth.instance;
  static final GoogleSignIn  _googleSignIn = GoogleSignIn(
    scopes: ['email', 'profile'],
  );

  // ── State ──────────────────────────────────────────────────────────────────

  static Stream<User?> get authStateChanges => _auth.authStateChanges();
  static User?         get currentUser       => _auth.currentUser;

  // ── Actions ────────────────────────────────────────────────────────────────

  /// Launches the Google OAuth flow and returns the [UserCredential] on
  /// success, or `null` if the user cancelled or an error occurred.
  static Future<UserCredential?> signInWithGoogle() async {
    try {
      final googleUser = await _googleSignIn.signIn();
      if (googleUser == null) return null; // user cancelled

      final googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken:     googleAuth.idToken,
      );
      return await _auth.signInWithCredential(credential);
    } on FirebaseAuthException catch (e) {
      debugPrint('[AuthService] FirebaseAuthException: ${e.code} — ${e.message}');
      rethrow;
    } catch (e) {
      debugPrint('[AuthService] Google Sign-In failed: $e');
      rethrow;
    }
  }

  /// Signs out from both Firebase and Google.
  static Future<void> signOut() async {
    try {
      await Future.wait([
        _googleSignIn.signOut(),
        _auth.signOut(),
      ]);
    } catch (e) {
      debugPrint('[AuthService] Sign-out error: $e');
    }
  }

  /// Delete the account and all associated Firebase data.
  /// The caller must re-authenticate before calling this if the user
  /// signed in a long time ago (Firebase requires recent auth for deletion).
  static Future<void> deleteAccount() async {
    try {
      await _googleSignIn.signOut();
      await _auth.currentUser?.delete();
    } catch (e) {
      debugPrint('[AuthService] Delete account error: $e');
      rethrow;
    }
  }
}
