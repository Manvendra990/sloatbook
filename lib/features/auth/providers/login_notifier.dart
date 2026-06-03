import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

enum AppRole { user, admin, superadmin }

class LoginState {
  final bool loading;
  final String? error;
  final AppRole? selectedRole;

  LoginState({this.loading = false, this.error, this.selectedRole});

  LoginState copyWith({bool? loading, String? error, AppRole? selectedRole}) {
    return LoginState(
      loading: loading ?? this.loading,
      error: error,
      selectedRole: selectedRole ?? this.selectedRole,
    );
  }
}

final loginNotifierProvider = StateNotifierProvider<LoginNotifier, LoginState>((
  ref,
) {
  return LoginNotifier();
});

class LoginNotifier extends StateNotifier<LoginState> {
  LoginNotifier() : super(LoginState());

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  void selectRole(AppRole role) {
    state = state.copyWith(selectedRole: role, error: null);
  }

  String roleToString(AppRole role) {
    switch (role) {
      case AppRole.user:
        return 'user';
      case AppRole.admin:
        return 'admin';
      case AppRole.superadmin:
        return 'superadmin';
    }
  }

  AppRole stringToRole(String role) {
    if (role == 'admin') return AppRole.admin;
    if (role == 'superadmin') return AppRole.superadmin;
    return AppRole.user;
  }

  Future<AppRole?> getCurrentUserRole() async {
    final user = _auth.currentUser;
    if (user == null) return null;

    final doc = await _firestore.collection('users').doc(user.uid).get();

    if (!doc.exists) return null;

    final role = doc.data()?['role'] ?? 'user';
    return stringToRole(role);
  }

  Future<void> login({
    required String email,
    required String password,
    required AppRole role,
  }) async {
    try {
      state = state.copyWith(loading: true, error: null);

      final credential = await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password.trim(),
      );

      final uid = credential.user!.uid;

      final doc = await _firestore.collection('users').doc(uid).get();

      if (!doc.exists) {
        await _auth.signOut();
        throw Exception('User data not found');
      }

      final dbRole = doc.data()?['role'];
      final status = doc.data()?['status'];

      if (dbRole != roleToString(role)) {
        await _auth.signOut();
        throw Exception('Invalid role selected');
      }

      if (status != 'active') {
        await _auth.signOut();
        throw Exception('Your account is not active');
      }

      state = state.copyWith(loading: false);
    } catch (e) {
      state = state.copyWith(
        loading: false,
        error: e.toString().replaceAll('Exception:', '').trim(),
      );
    }
  }

  Future<void> register({
    required String name,
    required String email,
    required String phone,
    required String password,
    required AppRole role,
  }) async {
    try {
      state = state.copyWith(loading: true, error: null);

      final credential = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password.trim(),
      );

      final uid = credential.user!.uid;

      await _firestore.collection('users').doc(uid).set({
        'uid': uid,
        'name': name.trim(),
        'email': email.trim(),
        'phone': phone.trim(),
        'role': roleToString(role),
        'status': role == AppRole.user ? 'active' : 'pending',
        'createdAt': FieldValue.serverTimestamp(),
      });

      state = state.copyWith(loading: false);
    } catch (e) {
      state = state.copyWith(
        loading: false,
        error: e.toString().replaceAll('Exception:', '').trim(),
      );
    }
  }

  Future<void> logout() async {
    await _auth.signOut();
  }

  Future<void> sendOtp({
    required String phoneNumber,
    required Function(String verificationId) onCodeSent,
    required Function(String error) onError,
  }) async {
    await _auth.verifyPhoneNumber(
      phoneNumber: phoneNumber,
      verificationCompleted: (PhoneAuthCredential credential) async {
        await _auth.signInWithCredential(credential);
      },
      verificationFailed: (FirebaseAuthException e) {
        onError(e.message ?? 'OTP verification failed');
      },
      codeSent: (String verificationId, int? resendToken) {
        onCodeSent(verificationId);
      },
      codeAutoRetrievalTimeout: (String verificationId) {},
    );
  }

  Future<void> verifyOtp({
    required String verificationId,
    required String otp,
  }) async {
    try {
      state = state.copyWith(loading: true, error: null);

      final credential = PhoneAuthProvider.credential(
        verificationId: verificationId,
        smsCode: otp,
      );

      await _auth.signInWithCredential(credential);

      state = state.copyWith(loading: false);
    } catch (e) {
      state = state.copyWith(loading: false, error: 'Invalid OTP');
    }
  }
}
