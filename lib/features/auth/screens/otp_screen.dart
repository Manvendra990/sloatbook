import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:slotbooking/data/theam/app_theam.dart';
import 'package:slotbooking/shared/widgets/app_button.dart';
import 'package:slotbooking/shared/widgets/apptext.dart';
import 'package:slotbooking/shared/widgets/otpinput.dart';
import '../providers/auth_provider.dart';

class OtpScreen extends ConsumerStatefulWidget {
  final String phoneNumber; // e.g. "+919876543210"
  const OtpScreen({super.key, required this.phoneNumber});

  @override
  ConsumerState<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends ConsumerState<OtpScreen>
    with SingleTickerProviderStateMixin {
  String? _verificationId;
  bool _isSending = true;
  bool _isVerifying = false;
  bool _isResending = false;
  String? _error;
  String _otp = '';
  int _resetTrigger = 0; // increment to clear OtpInput boxes

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
    super.dispose();
  }

  // ── Timer ──────────────────────────────────────────────────────────────────
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

  // ── Send OTP ───────────────────────────────────────────────────────────────
  Future<void> _sendOtp() async {
    setState(() {
      _isSending = true;
      _error = null;
    });

    await FirebaseAuth.instance.verifyPhoneNumber(
      phoneNumber: widget.phoneNumber,
      timeout: const Duration(seconds: 60),
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
        if (!mounted) return;
        setState(() {
          _verificationId = verificationId;
          _isSending = false;
        });
        _startTimer();
      },
      codeAutoRetrievalTimeout: (String verificationId) {
        _verificationId = verificationId;
      },
    );
  }

  // ── Resend ─────────────────────────────────────────────────────────────────
  Future<void> _resendOtp() async {
    if (_secondsLeft > 0 || _isResending) return;
    setState(() {
      _isResending = true;
      _resetTrigger++; // clears OtpInput boxes
      _otp = '';
    });
    await _sendOtp();
    setState(() => _isResending = false);
  }

  // ── Verify ─────────────────────────────────────────────────────────────────
  Future<void> _verifyOtp() async {
    if (_otp.length != 6) {
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
      smsCode: _otp,
    );
    await _signInWithCredential(credential);
  }

  Future<void> _signInWithCredential(PhoneAuthCredential credential) async {
    final role = await ref
        .read(authNotifierProvider.notifier)
        .signInWithPhoneCredential(credential);

    if (!mounted) return;
    setState(() => _isVerifying = false);

    if (role != null) {
      context.go('/user/home');
    } else {
      final err = ref.read(authNotifierProvider).error;
      setState(() => _error = err ?? 'Verification failed.');
      ref.read(authNotifierProvider.notifier).clearError();
    }
  }

  String _friendlyError(String code) => switch (code) {
    'invalid-verification-code' => 'Invalid OTP. Please check and try again.',
    'session-expired' => 'OTP session expired. Please resend.',
    'invalid-phone-number' => 'Invalid phone number.',
    'too-many-requests' => 'Too many attempts. Try again later.',
    'network-request-failed' => 'No internet connection.',
    _ => 'Verification failed. Please try again.',
  };

  // ── Build ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
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

                  // ── Top bar: Back + Logo ───────────────────────────────────
                  Row(
                    children: [
                      // Back button
                      GestureDetector(
                        onTap: () => context.pop(),
                        child: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: AppTheme.surface,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.grey.shade200),
                          ),
                          child: Icon(
                            Icons.arrow_back_ios_new_rounded,
                            size: 16,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                      ),
                      const Spacer(),
                      // Logo
                      Row(
                        children: [
                          Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: AppTheme.primaryRed,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(
                              Icons.bolt_rounded,
                              color: Colors.white,
                              size: 22,
                            ),
                          ),
                          const SizedBox(width: 8),
                          AppText(
                            'KINETIC',
                            variant: AppTextVariant.titleLarge,
                            color: AppTheme.primaryRed,
                            letterSpacing: 2.5,
                          ),
                        ],
                      ),
                    ],
                  ),

                  const SizedBox(height: 48),

                  // ── SMS icon ───────────────────────────────────────────────
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: AppTheme.lightRed,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.sms_outlined,
                      color: AppTheme.primaryRed,
                      size: 38,
                    ),
                  ),
                  const SizedBox(height: 24),

                  // ── Title & subtitle ───────────────────────────────────────
                  AppText.headlineMedium(
                    'Verify Your Number',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 10),
                  RichText(
                    textAlign: TextAlign.center,
                    text: TextSpan(
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade500,
                        height: 1.5,
                      ),
                      children: [
                        const TextSpan(text: 'We sent a 6-digit OTP to\n'),
                        TextSpan(
                          text: widget.phoneNumber,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 40),

                  // ── Sending state ──────────────────────────────────────────
                  if (_isSending)
                    Column(
                      children: [
                        const CircularProgressIndicator(
                          color: AppTheme.primaryRed,
                        ),
                        const SizedBox(height: 16),
                        AppText.bodyMedium('Sending OTP…'),
                      ],
                    )
                  else ...[
                    // ── OTP Input ────────────────────────────────────────────
                    OtpInput(
                      resetTrigger: _resetTrigger,
                      onChanged: (val) => setState(() => _otp = val),
                      onCompleted: (val) {
                        setState(() => _otp = val);
                        _verifyOtp();
                      },
                    ),

                    const SizedBox(height: 16),

                    // ── Error banner ─────────────────────────────────────────
                    if (_error != null)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: AppTheme.error.withOpacity(0.06),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: AppTheme.error.withOpacity(0.3),
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.error_outline_rounded,
                              size: 16,
                              color: AppTheme.error,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: AppText.bodyMedium(
                                _error!,
                                color: AppTheme.error,
                              ),
                            ),
                          ],
                        ),
                      ),

                    const SizedBox(height: 28),

                    // ── Verify button ────────────────────────────────────────
                    AppButton.primary(
                      label: 'Verify & Continue',
                      isLoading: _isVerifying,
                      disabled: _otp.length != 6,
                      onPressed: _otp.length == 6 ? _verifyOtp : null,
                    ),

                    const SizedBox(height: 24),

                    // ── Resend row ───────────────────────────────────────────
                    GestureDetector(
                      onTap: _secondsLeft == 0 ? _resendOtp : null,
                      child: RichText(
                        text: TextSpan(
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey.shade500,
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
                                    ? Colors.grey.shade400
                                    : AppTheme.primaryRed,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 32),

                    // ── Security note ────────────────────────────────────────
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: AppTheme.lightRed,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.verified_user_outlined,
                            size: 18,
                            color: AppTheme.primaryRed,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: AppText.bodyMedium(
                              'Your number is secured with end-to-end encryption.',
                              color: AppTheme.primaryRed.withOpacity(0.8),
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
