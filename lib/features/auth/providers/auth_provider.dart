import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final firebaseAuthProvider = Provider<FirebaseAuth>((ref) {
  return FirebaseAuth.instance;
});

final authStateProvider = StreamProvider<User?>((ref) {
  return ref.watch(firebaseAuthProvider).authStateChanges();
});

// ── Auth State ────────────────────────────────────────────────────────────────

class AuthState {
  final bool isLoading;
  final String? error;
  final bool success;

  const AuthState({this.isLoading = false, this.error, this.success = false});

  AuthState copyWith({bool? isLoading, String? error, bool? success}) =>
      AuthState(
        isLoading: isLoading ?? this.isLoading,
        error: error,
        success: success ?? this.success,
      );
}

// ── Auth Notifier ─────────────────────────────────────────────────────────────

class AuthNotifier extends StateNotifier<AuthState> {
  final FirebaseAuth _auth;
  final FirebaseFirestore _db;

  AuthNotifier(this._auth, this._db) : super(const AuthState());

  // ── Login ──────────────────────────────────────────────────────────────────
  Future<String?> login({
    required String email,
    required String password,
  }) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      await _auth.signInWithEmailAndPassword(email: email, password: password);

      final uid = _auth.currentUser!.uid;

      // Check admin collection first
      final adminDoc = await _db.collection('admin').doc(uid).get();
      if (adminDoc.exists) {
        final data = adminDoc.data()!;
        if (data['status'] == 'suspended') {
          await _auth.signOut();
          state = state.copyWith(
            isLoading: false,
            error: 'Your account has been suspended. Contact support.',
          );
          return null;
        }
        if (data['status'] == 'pending') {
          await _auth.signOut();
          state = state.copyWith(
            isLoading: false,
            error: 'Your account is pending Super Admin approval.',
          );
          return null;
        }
        final role = data['role'] as String? ?? 'admin';
        state = state.copyWith(isLoading: false, success: true);
        return role;
      }

      // Fallback: check users collection
      final userDoc = await _db.collection('users').doc(uid).get();
      if (userDoc.exists) {
        final data = userDoc.data()!;
        if (data['status'] == 'suspended') {
          await _auth.signOut();
          state = state.copyWith(
            isLoading: false,
            error: 'Your account has been suspended. Contact support.',
          );
          return null;
        }
        final role = data['role'] as String? ?? 'user';
        state = state.copyWith(isLoading: false, success: true);
        return role;
      }

      await _auth.signOut();
      state = state.copyWith(isLoading: false, error: 'Account not found.');
      return null;
    } on FirebaseAuthException catch (e) {
      state = state.copyWith(isLoading: false, error: _friendlyError(e.code));
      return null;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'An error occurred. Try again.',
      );
      return null;
    }
  }

  // ── Phone OTP Sign-In (used by OtpScreen) ──────────────────────────────────
  Future<String?> signInWithPhoneCredential(
    PhoneAuthCredential credential,
  ) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final userCredential = await _auth.signInWithCredential(credential);
      final user = userCredential.user;

      if (user == null) {
        state = state.copyWith(
          isLoading: false,
          error: 'Sign-in failed. Please try again.',
        );
        return null;
      }

      final uid = user.uid;

      // 1️⃣ Check admin collection first (admin / superadmin)
      final adminDoc = await _db.collection('admin').doc(uid).get();
      if (adminDoc.exists) {
        final role = adminDoc.data()?['role'] as String? ?? 'admin';
        state = state.copyWith(isLoading: false, success: true);
        return role;
      }

      // 2️⃣ Check users collection
      final userDoc = await _db.collection('users').doc(uid).get();
      if (userDoc.exists) {
        final role = userDoc.data()?['role'] as String? ?? 'user';
        state = state.copyWith(isLoading: false, success: true);
        return role;
      }

      // 3️⃣ New user — auto-create Firestore doc
      await _db.collection('users').doc(uid).set({
        'uid': uid,
        'phone': user.phoneNumber ?? '',
        'role': 'user',
        'createdAt': FieldValue.serverTimestamp(),
      });

      state = state.copyWith(isLoading: false, success: true);
      return 'user';
    } on FirebaseAuthException catch (e) {
      state = state.copyWith(isLoading: false, error: _friendlyError(e.code));
      return null;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Verification failed: $e',
      );
      return null;
    }
  }

  // ── Admin Register ─────────────────────────────────────────────────────────
  Future<bool> registerAdmin({
    required String name,
    required String email,
    required String password,
    required String phone,
  }) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      // 1. Create Firebase Auth user
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      final uid = credential.user!.uid;

      // 2. Update display name
      await credential.user!.updateDisplayName(name);

      // 3. Save to admin collection
      try {
        await _db.collection('admin').doc(uid).set({
          'name': name,
          'email': email,
          'phone': phone,
          'role': 'admin',
          'status': 'active',
          'createdAt': FieldValue.serverTimestamp(),
        });
      } catch (firestoreError) {
        // ✅ Auth succeeded but Firestore failed
        // Delete the auth user to keep things clean
        await credential.user!.delete();
        state = state.copyWith(
          isLoading: false,
          error: 'Failed to save profile: $firestoreError', // shows exact error
        );
        return false;
      }

      // 4. Sign out — must wait for Super Admin approval
      await _auth.signOut();

      state = state.copyWith(isLoading: false, success: true);
      return true;
    } on FirebaseAuthException catch (e) {
      state = state.copyWith(isLoading: false, error: _friendlyError(e.code));
      return false;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Registration failed: $e', // ✅ shows exact error
      );
      return false;
    }
  }

  void clearError() => state = state.copyWith(error: null);

  String _friendlyError(String code) {
    return switch (code) {
      'user-not-found' => 'No account found with this email.',
      'wrong-password' => 'Incorrect password. Please try again.',
      'invalid-credential' => 'Invalid email or password.',
      'email-already-in-use' => 'This email is already registered.',
      'weak-password' => 'Password must be at least 6 characters.',
      'invalid-email' => 'Please enter a valid email address.',
      'too-many-requests' => 'Too many attempts. Please try again later.',
      'network-request-failed' => 'No internet connection.',
      _ => 'Something went wrong. Please try again.',
    };
  }
}

// ── Providers ─────────────────────────────────────────────────────────────────

final authNotifierProvider = StateNotifierProvider<AuthNotifier, AuthState>((
  ref,
) {
  return AuthNotifier(FirebaseAuth.instance, FirebaseFirestore.instance);
});

final currentUserRoleProvider = FutureProvider<String?>((ref) async {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) return null;
  final doc = await FirebaseFirestore.instance
      .collection('admin')
      .doc(user.uid)
      .get();
  return doc.data()?['role'] as String?;
});
