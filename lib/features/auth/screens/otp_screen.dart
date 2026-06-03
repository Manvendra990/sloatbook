import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/auth_provider.dart';

class OtpScreen extends ConsumerStatefulWidget {
  final String phoneNumber; // e.g. "+919876543210"
  const OtpScreen({super.key, required this.phoneNumber});

  @override
  ConsumerState<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends ConsumerState<OtpScreen>
    with SingleTickerProviderStateMixin {
  static const _green = Color(0xFF0D5C3A);
  static const _greenLight = Color(0xFFE8F5EE);
  static const _bg = Color(0xFFF5F7F5);

  final List<TextEditingController> _controllers = List.generate(
    6,
    (_) => TextEditingController(),
  );
  final List<FocusNode> _focusNodes = List.generate(6, (_) => FocusNode());

  String? _verificationId;
  bool _isSending = true;
  bool _isVerifying = false;
  bool _isResending = false;
  String? _error;

  int _secondsLeft = 30;
  Timer? _timer;

  late final AnimationController _animCtrl;
  late final Animation<double> _fade;
  late final Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _fade = CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut);
    _slide = Tween<Offset>(
      begin: const Offset(0, 0.08),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _animCtrl, curve: Curves.easeOutCubic));
    _animCtrl.forward();
    _sendOtp();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _animCtrl.dispose();
    for (final c in _controllers) c.dispose();
    for (final f in _focusNodes) f.dispose();
    super.dispose();
  }

  void _startTimer() {
    _timer?.cancel();
    setState(() => _secondsLeft = 30);
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_secondsLeft == 0) {
        t.cancel();
      } else {
        setState(() => _secondsLeft--);
      }
    });
  }

  Future<void> _sendOtp() async {
    setState(() {
      _isSending = true;
      _error = null;
    });

    await FirebaseAuth.instance.verifyPhoneNumber(
      phoneNumber: widget.phoneNumber,
      timeout: const Duration(seconds: 60),

      // Auto-verified on Android (no OTP box needed)
      verificationCompleted: (PhoneAuthCredential credential) async {
        await _signInWithCredential(credential);
      },

      verificationFailed: (FirebaseAuthException e) {
        setState(() {
          _isSending = false;
          _error = _friendlyError(e.code);
        });
      },

      codeSent: (String verificationId, int? resendToken) {
        setState(() {
          _verificationId = verificationId;
          _isSending = false;
        });
        _startTimer();
        _focusNodes[0].requestFocus();
      },

      codeAutoRetrievalTimeout: (String verificationId) {
        _verificationId = verificationId;
      },
    );
  }

  Future<void> _resendOtp() async {
    if (_secondsLeft > 0 || _isResending) return;
    setState(() => _isResending = true);
    for (final c in _controllers) c.clear();
    _focusNodes[0].requestFocus();
    await _sendOtp();
    setState(() => _isResending = false);
  }

  Future<void> _verifyOtp() async {
    final otp = _controllers.map((c) => c.text).join();
    if (otp.length != 6) {
      setState(() => _error = 'Please enter the complete 6-digit OTP.');
      return;
    }
    if (_verificationId == null) {
      setState(() => _error = 'Verification ID missing. Please resend OTP.');
      return;
    }

    setState(() {
      _isVerifying = true;
      _error = null;
    });

    final credential = PhoneAuthProvider.credential(
      verificationId: _verificationId!,
      smsCode: otp,
    );
    await _signInWithCredential(credential);
  }

  Future<void> _signInWithCredential(PhoneAuthCredential credential) async {
    // Use AuthNotifier so Firestore doc is created automatically
    final role = await ref
        .read(authNotifierProvider.notifier)
        .signInWithPhoneCredential(credential);

    if (!mounted) return;

    setState(() => _isVerifying = false);

    if (role != null) {
      // Navigate based on role
      context.go(switch (role) {
        _ => '/user/home',
      });
    } else {
      // Error is already in authState, but also set local error for OTP box UI
      final err = ref.read(authNotifierProvider).error;
      setState(() => _error = err ?? 'Verification failed.');
      ref.read(authNotifierProvider.notifier).clearError();
    }
  }

  String get _enteredOtp => _controllers.map((c) => c.text).join();

  String _friendlyError(String code) => switch (code) {
    'invalid-verification-code' => 'Invalid OTP. Please check and try again.',
    'session-expired' => 'OTP session expired. Please resend.',
    'invalid-phone-number' => 'Invalid phone number.',
    'too-many-requests' => 'Too many attempts. Try again later.',
    'network-request-failed' => 'No internet connection.',
    _ => 'Verification failed. Please try again.',
  };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: FadeTransition(
          opacity: _fade,
          child: SlideTransition(
            position: _slide,
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const SizedBox(height: 40),

                  // Back + Logo
                  Row(
                    children: [
                      GestureDetector(
                        onTap: () => context.pop(),
                        child: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFFDDE0DD)),
                          ),
                          child: Icon(
                            Icons.arrow_back_ios_new_rounded,
                            size: 16,
                            color: Colors.grey[700],
                          ),
                        ),
                      ),
                      const Spacer(),
                      Row(
                        children: [
                          Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: _green,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(
                              Icons.bolt_rounded,
                              color: Colors.white,
                              size: 22,
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Text(
                            'KINETIC',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 2.5,
                              color: _green,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),

                  const SizedBox(height: 48),

                  // Icon
                  Container(
                    width: 80,
                    height: 80,
                    decoration: const BoxDecoration(
                      color: _greenLight,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.sms_outlined,
                      color: _green,
                      size: 38,
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Title
                  const Text(
                    'Verify Your Number',
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF0E1A13),
                      letterSpacing: -0.4,
                    ),
                  ),
                  const SizedBox(height: 10),
                  RichText(
                    textAlign: TextAlign.center,
                    text: TextSpan(
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[500],
                        height: 1.5,
                      ),
                      children: [
                        const TextSpan(text: 'We sent a 6-digit OTP to\n'),
                        TextSpan(
                          text: widget.phoneNumber,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF0E1A13),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 40),

                  // Sending state
                  if (_isSending)
                    Column(
                      children: [
                        const CircularProgressIndicator(color: _green),
                        const SizedBox(height: 16),
                        Text(
                          'Sending OTP…',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[500],
                          ),
                        ),
                      ],
                    )
                  else ...[
                    // OTP boxes
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: List.generate(
                        6,
                        (i) => _OtpBox(
                          controller: _controllers[i],
                          focusNode: _focusNodes[i],
                          onChanged: (val) {
                            if (val.isNotEmpty && i < 5)
                              _focusNodes[i + 1].requestFocus();
                            setState(() {});
                            if (_enteredOtp.length == 6) _verifyOtp();
                          },
                          onBackspace: () {
                            if (_controllers[i].text.isEmpty && i > 0) {
                              _focusNodes[i - 1].requestFocus();
                            }
                          },
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Error
                    if (_error != null)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.red[50],
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.red[200]!),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.error_outline_rounded,
                              size: 16,
                              color: Colors.red[600],
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _error!,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.red[700],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                    const SizedBox(height: 28),

                    // Verify button
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton(
                        onPressed: (_isVerifying || _enteredOtp.length != 6)
                            ? null
                            : _verifyOtp,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _green,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          disabledBackgroundColor: _green.withOpacity(0.5),
                        ),
                        child: _isVerifying
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2.5,
                                ),
                              )
                            : const Text(
                                'Verify & Continue',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Resend
                    GestureDetector(
                      onTap: _secondsLeft == 0 ? _resendOtp : null,
                      child: RichText(
                        text: TextSpan(
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[500],
                          ),
                          children: [
                            const TextSpan(text: "Didn't receive OTP? "),
                            TextSpan(
                              text: _secondsLeft > 0
                                  ? 'Resend in ${_secondsLeft}s'
                                  : _isResending
                                  ? 'Resending…'
                                  : 'Resend OTP',
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                color: _secondsLeft > 0
                                    ? Colors.grey[400]
                                    : _green,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 32),

                    // Security note
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: _greenLight,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.verified_user_outlined,
                            size: 18,
                            color: _green,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Your number is secured with end-to-end encryption.',
                              style: TextStyle(
                                fontSize: 12,
                                color: _green.withOpacity(0.8),
                                height: 1.4,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── OTP Box — uses KeyboardListener (replaces deprecated RawKeyboardListener) ──
class _OtpBox extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final ValueChanged<String> onChanged;
  final VoidCallback onBackspace;

  static const _green = Color(0xFF0D5C3A);

  const _OtpBox({
    required this.controller,
    required this.focusNode,
    required this.onChanged,
    required this.onBackspace,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 46,
      height: 56,
      child: KeyboardListener(
        focusNode: FocusNode(),
        onKeyEvent: (event) {
          if (event is KeyDownEvent &&
              event.logicalKey == LogicalKeyboardKey.backspace &&
              controller.text.isEmpty) {
            onBackspace();
          }
        },
        child: TextFormField(
          controller: controller,
          focusNode: focusNode,
          keyboardType: TextInputType.number,
          textAlign: TextAlign.center,
          maxLength: 1,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: Color(0xFF0E1A13),
          ),
          decoration: InputDecoration(
            counterText: '',
            filled: true,
            fillColor: controller.text.isNotEmpty
                ? const Color(0xFFE8F5EE)
                : Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey[200]!),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: controller.text.isNotEmpty ? _green : Colors.grey[200]!,
                width: controller.text.isNotEmpty ? 1.5 : 1,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: _green, width: 2),
            ),
          ),
          onChanged: onChanged,
        ),
      ),
    );
  }
}
