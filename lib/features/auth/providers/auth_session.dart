import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ─────────────────────────────────────────────────────────────────────────────
// AuthSession
// ─────────────────────────────────────────────────────────────────────────────
//
// SETUP — pubspec.yaml:
//   shared_preferences: ^2.2.3
//
// USAGE IN main.dart:
//
//   void main() async {
//     WidgetsFlutterBinding.ensureInitialized();
//     await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
//     final uid = await AuthSession.getSavedUid();
//     runApp(MyApp(startLoggedIn: uid != null));
//   }
//
// USAGE IN GoRouter (redirect guard):
//
//   redirect: (context, state) async {
//     final uid = await AuthSession.getSavedUid();
//     final onLogin = state.matchedLocation == '/user/login';
//     if (uid == null && !onLogin) return '/user/login';
//     if (uid != null && onLogin) return '/user/home';
//     return null;
//   },
//
// SIGN-OUT (call from profile screen):
//
//   await AuthSession.signOut();
//   if (context.mounted) context.go('/user/login');
//
// ─────────────────────────────────────────────────────────────────────────────

const _kUidKey = 'signed_in_uid';

class AuthSession {
  AuthSession._(); // prevent instantiation

  /// Returns saved UID if user is still signed in, null otherwise.
  /// Cross-checks with Firebase — if Firebase has no user, clears local pref.
  static Future<String?> getSavedUid() async {
    final firebaseUser = FirebaseAuth.instance.currentUser;
    if (firebaseUser == null) {
      await clearUid();
      return null;
    }
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_kUidKey);
  }

  /// Save UID after successful sign-in.
  static Future<void> saveUid(String uid) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kUidKey, uid);
  }

  /// Clear UID (called internally and on sign-out).
  static Future<void> clearUid() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kUidKey);
  }

  /// Full sign-out: Firebase + Google account revoke + local pref cleared.
  static Future<void> signOut() async {
    try {
      await GoogleSignIn().signOut();
    } catch (_) {}
    await FirebaseAuth.instance.signOut();
    await clearUid();
  }
}
