// GENERATED FILE — DO NOT EDIT MANUALLY.
//
// ════════════════════════════════════════════════════════════════════
// FIREBASE SETUP INSTRUCTIONS
// ════════════════════════════════════════════════════════════════════
//
// 1. Install the FlutterFire CLI (once):
//    dart pub global activate flutterfire_cli
//
// 2. Create a Firebase project at https://console.firebase.google.com
//    – Add an Android app with package: com.example.financialresume
//    – Add an iOS app with your bundle ID
//    – Enable Google Sign-In in Authentication → Sign-in methods
//    – Create a Firestore database (start in test mode, then apply rules)
//    – Enable Cloud Storage
//
// 3. Run in this project root:
//    flutterfire configure --project=YOUR_FIREBASE_PROJECT_ID
//
//    This replaces this placeholder with the real firebase_options.dart
//    and downloads google-services.json / GoogleService-Info.plist.
//
// 4. For Google Sign-In on Android you also need to register the SHA-1
//    fingerprint in the Firebase console:
//    keytool -list -v -keystore ~/.android/debug.keystore -alias androiddebugkey -storepass android -keypass android
//
// 5. Apply the Firestore security rules from firestore.rules.
//
// ════════════════════════════════════════════════════════════════════
//
// Until step 3 is complete the app runs in OFFLINE-ONLY mode —
// all local data is preserved; cloud sync is simply disabled.

// ignore_for_file: lines_longer_than_80_chars, avoid_classes_with_only_static_members
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    throw UnsupportedError(
      'DefaultFirebaseOptions is not configured.\n'
      'Run: flutterfire configure --project=YOUR_FIREBASE_PROJECT_ID\n'
      'See lib/firebase_options.dart for full instructions.',
    );
  }
}
