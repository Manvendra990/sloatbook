import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:slotbooking/data/theam/app_theam.dart';
import 'package:slotbooking/shared/widgets/apptext.dart';

// ── Prefs key ─────────────────────────────────────────────────────────────────
const _kUidKey = 'signed_in_uid';

/// Call this from main.dart / router to decide initial route:
///   final uid = await AuthSession.getSavedUid();
///   initialLocation: uid != null ? '/user/home' : '/user/login'
class AuthSession {
  static Future<String?> getSavedUid() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_kUidKey);
  }

  static Future<void> saveUid(String uid) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kUidKey, uid);
  }

  static Future<void> clearUid() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kUidKey);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
class UserLoginScreen extends StatefulWidget {
  const UserLoginScreen({super.key});

  @override
  State<UserLoginScreen> createState() => _UserLoginScreenState();
}

class _UserLoginScreenState extends State<UserLoginScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animCtrl;
  late final Animation<double> _fade;
  late final Animation<Offset> _slide;

  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light, // white icons on dark bg
      ),
    );
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _fade = CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut);
    _slide = Tween<Offset>(
      begin: const Offset(0, 0.1),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _animCtrl, curve: Curves.easeOutCubic));
    _animCtrl.forward();
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    super.dispose();
  }

  // ── Google Sign-In ─────────────────────────────────────────────────────────
  Future<void> _signInWithGoogle() async {
    setState(() => _isLoading = true);
    try {
      final googleUser = await GoogleSignIn().signIn();
      if (googleUser == null) {
        setState(() => _isLoading = false);
        return;
      }

      final googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final userCred = await FirebaseAuth.instance.signInWithCredential(
        credential,
      );
      final user = userCred.user;
      if (user == null) {
        _showSnack('Sign-in failed. Please try again.');
        setState(() => _isLoading = false);
        return;
      }

      // ── Save UID locally for auto-login ──────────────────────────────────
      await AuthSession.saveUid(user.uid);

      // ── Firestore ─────────────────────────────────────────────────────────
      final userDoc = FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid);
      final docSnap = await userDoc.get();

      if (!docSnap.exists) {
        await userDoc.set({
          'uid': user.uid,
          'displayName': user.displayName ?? '',
          'email': user.email ?? '',
          'phoneNumber': user.phoneNumber ?? '',
          'photoURL': user.photoURL ?? '',
          'emailVerified': user.emailVerified,
          'googleId': googleUser.id,
          'googlePhotoUrl': googleUser.photoUrl ?? '',
          'provider': 'google',
          'status': 'active',
          'createdAt': FieldValue.serverTimestamp(),
          'lastLoginAt': FieldValue.serverTimestamp(),
        });
      } else {
        await userDoc.update({
          'displayName': user.displayName ?? '',
          'email': user.email ?? '',
          'photoURL': user.photoURL ?? '',
          'lastLoginAt': FieldValue.serverTimestamp(),
        });
      }

      if (!mounted) return;
      context.go('/user/home');
    } catch (e) {
      debugPrint('Google Sign-In error: $e');
      _showSnack('Sign-in failed: ${e.toString()}');
      setState(() => _isLoading = false);
    }
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: AppTheme.error,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // ── 1. Sports background image ─────────────────────────────────
          Image.asset(
            'assets/images/sports_bg.jpg', // replace with your asset
            fit: BoxFit.cover,
            color: Colors.black.withOpacity(0.55),
            colorBlendMode: BlendMode.darken,
          ),

          // ── 2. Gradient overlay: dark top + very dark bottom ───────────
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                stops: [0.0, 0.4, 0.75, 1.0],
                colors: [
                  Color(0xCC000000),
                  Color(0x55000000),
                  Color(0x88000000),
                  Color(0xEE000000),
                ],
              ),
            ),
          ),

          // ── 3. Content ─────────────────────────────────────────────────
          SafeArea(
            child: FadeTransition(
              opacity: _fade,
              child: SlideTransition(
                position: _slide,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 28),
                  child: SizedBox(
                    height:
                        size.height -
                        MediaQuery.of(context).padding.top -
                        MediaQuery.of(context).padding.bottom,
                    child: Column(
                      children: [
                        const SizedBox(height: 48),

                        // ── Logo ────────────────────────────────────────
                        Column(
                          children: [
                            Container(
                              width: 80,
                              height: 80,
                              decoration: BoxDecoration(
                                color: AppTheme.primaryRed,
                                borderRadius: BorderRadius.circular(22),
                                boxShadow: [
                                  BoxShadow(
                                    color: AppTheme.primaryRed.withOpacity(0.5),
                                    blurRadius: 24,
                                    spreadRadius: 2,
                                  ),
                                ],
                              ),
                              child: const Icon(
                                Icons.bolt_rounded,
                                color: Colors.white,
                                size: 44,
                              ),
                            ),
                            const SizedBox(height: 16),
                            const Text(
                              'KINETIC',
                              style: TextStyle(
                                fontSize: 32,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 6,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),

                        const Spacer(),

                        // ── Welcome text ────────────────────────────────
                        Column(
                          children: [
                            const Text(
                              'Welcome Athlete',
                              style: TextStyle(
                                fontSize: 30,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                                letterSpacing: -0.5,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'Sign in with your Google account to access\nyour performance dashboard.',
                              style: TextStyle(
                                fontSize: 15,
                                color: Colors.white.withOpacity(0.65),
                                height: 1.5,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),

                        const SizedBox(height: 44),

                        // ── Google Button ───────────────────────────────
                        _GoogleSignInButton(
                          isLoading: _isLoading,
                          onPressed: _isLoading ? null : _signInWithGoogle,
                        ),

                        const SizedBox(height: 40),

                        // ── Divider ─────────────────────────────────────
                        Row(
                          children: [
                            Expanded(
                              child: Divider(
                                color: Colors.white.withOpacity(0.2),
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                              ),
                              child: Text(
                                'SECURE ACCESS',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 1.8,
                                  color: Colors.white.withOpacity(0.35),
                                ),
                              ),
                            ),
                            Expanded(
                              child: Divider(
                                color: Colors.white.withOpacity(0.2),
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 20),

                        // ── Feature chips ───────────────────────────────
                        Row(
                          children: [
                            Expanded(
                              child: _FeatureChip(
                                icon: Icons.bar_chart_rounded,
                                label: 'Live Stats',
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _FeatureChip(
                                icon: Icons.verified_user_outlined,
                                label: 'Encrypted',
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _FeatureChip(
                                icon: Icons.flash_on_rounded,
                                label: 'Fast Login',
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 32),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Google Sign-In Button ─────────────────────────────────────────────────────
class _GoogleSignInButton extends StatelessWidget {
  final bool isLoading;
  final VoidCallback? onPressed;

  const _GoogleSignInButton({required this.isLoading, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.white,
          foregroundColor: const Color(0xFF1F1F1F),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: BorderSide(color: Colors.grey.shade200),
          ),
        ),
        child: isLoading
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: AppTheme.primaryRed,
                ),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Official Google G SVG rendered via CustomPaint
                  SizedBox(
                    width: 24,
                    height: 24,
                    child: CustomPaint(painter: _GoogleGPainter()),
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    'Continue with Google',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF1F1F1F),
                      letterSpacing: 0.1,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

// ── Accurate Google G Painter ─────────────────────────────────────────────────
class _GoogleGPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final paint = Paint()..style = PaintingStyle.fill;

    // Blue segment (top-right area)
    paint.color = const Color(0xFF4285F4);
    canvas.drawArc(
      Rect.fromLTWH(0, 0, w, h),
      -0.52, // start angle (roughly -30deg)
      1.57, // sweep ~90deg
      true,
      paint,
    );

    // Green segment (bottom-right)
    paint.color = const Color(0xFF34A853);
    canvas.drawArc(Rect.fromLTWH(0, 0, w, h), 1.05, 1.57, true, paint);

    // Yellow segment (bottom-left)
    paint.color = const Color(0xFFFBBC05);
    canvas.drawArc(Rect.fromLTWH(0, 0, w, h), 2.62, 0.79, true, paint);

    // Red segment (top-left)
    paint.color = const Color(0xFFEA4335);
    canvas.drawArc(Rect.fromLTWH(0, 0, w, h), 3.40, 2.24, true, paint);

    // White inner circle
    paint.color = Colors.white;
    canvas.drawCircle(Offset(w / 2, h / 2), w * 0.35, paint);

    // Blue horizontal bar (right side of the G)
    paint.color = const Color(0xFF4285F4);
    final barTop = h * 0.42;
    final barBottom = h * 0.58;
    canvas.drawRect(Rect.fromLTRB(w * 0.5, barTop, w * 0.95, barBottom), paint);

    // White inner circle again to clean up bar overlap
    paint.color = Colors.white;
    canvas.drawCircle(Offset(w / 2, h / 2), w * 0.295, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ── Feature Chip (dark glass style) ──────────────────────────────────────────
class _FeatureChip extends StatelessWidget {
  final IconData icon;
  final String label;
  const _FeatureChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.12)),
      ),
      child: Column(
        children: [
          Icon(icon, size: 22, color: AppTheme.primaryRed),
          const SizedBox(height: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: Colors.white.withOpacity(0.75),
            ),
          ),
        ],
      ),
    );
  }
}
