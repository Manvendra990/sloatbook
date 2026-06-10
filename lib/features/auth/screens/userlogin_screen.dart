import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:slotbooking/data/theam/app_theam.dart';
import 'package:slotbooking/shared/widgets/app_button.dart';
import 'package:slotbooking/shared/widgets/apptext.dart';

class UserLoginScreen extends StatefulWidget {
  const UserLoginScreen({super.key});

  @override
  State<UserLoginScreen> createState() => _UserLoginScreenState();
}

class _UserLoginScreenState extends State<UserLoginScreen>
    with SingleTickerProviderStateMixin {
  final _phoneCtrl = TextEditingController();

  late final AnimationController _animCtrl;
  late final Animation<double> _fade;
  late final Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
      ),
    );
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fade = CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut);
    _slide = Tween<Offset>(
      begin: const Offset(0, 0.08),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _animCtrl, curve: Curves.easeOutCubic));
    _animCtrl.forward();
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  // ── Continue ───────────────────────────────────────────────────────────────
  void _continue() {
    final phone = _phoneCtrl.text.trim();
    if (phone.length != 10) {
      _showSnack('Please enter a valid 10-digit mobile number.');
      return;
    }
    FocusScope.of(context).unfocus();
    context.push('/user/otp?phone=${Uri.encodeComponent('+91$phone')}');
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

  bool get _phoneReady => _phoneCtrl.text.length == 10;

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
                  const SizedBox(height: 60),

                  // ── Logo ──────────────────────────────────────────────────
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          color: AppTheme.primaryRed,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Icon(
                          Icons.bolt_rounded,
                          color: Colors.white,
                          size: 30,
                        ),
                      ),
                      const SizedBox(width: 12),
                      AppText(
                        'KINETIC',
                        variant: AppTextVariant.headlineMedium,
                        color: AppTheme.primaryRed,
                        letterSpacing: 3,
                      ),
                    ],
                  ),

                  const SizedBox(height: 48),

                  // ── Welcome ───────────────────────────────────────────────
                  AppText.headlineLarge(
                    'Welcome Athlete',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 10),
                  AppText.bodyMedium(
                    'Enter your mobile number to access\nyour performance dashboard.',
                    textAlign: TextAlign.center,
                  ),

                  const SizedBox(height: 44),

                  // ── Phone field label ─────────────────────────────────────
                  Align(
                    alignment: Alignment.centerLeft,
                    child: AppText.label(
                      'MOBILE NUMBER',
                      color: AppTheme.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 10),

                  // ── Phone input ───────────────────────────────────────────
                  Container(
                    decoration: BoxDecoration(
                      color: AppTheme.surface,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Colors.grey.shade200),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.04),
                          blurRadius: 10,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        // Country code badge
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 16,
                          ),
                          decoration: BoxDecoration(
                            border: Border(
                              right: BorderSide(color: Colors.grey.shade200),
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.phone_outlined,
                                size: 18,
                                color: AppTheme.textSecondary,
                              ),
                              const SizedBox(width: 6),
                              AppText.bodyLarge(
                                '+91',
                                color: AppTheme.textSecondary,
                              ),
                            ],
                          ),
                        ),

                        // Number input
                        Expanded(
                          child: TextField(
                            controller: _phoneCtrl,
                            keyboardType: TextInputType.phone,
                            maxLength: 10,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                            ],
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w500,
                              color: AppTheme.textPrimary,
                            ),
                            decoration: InputDecoration(
                              hintText: 'Enter 10 digit number',
                              hintStyle: TextStyle(
                                color: Colors.grey.shade400,
                                fontSize: 14,
                                fontWeight: FontWeight.w400,
                              ),
                              border: InputBorder.none,
                              enabledBorder: InputBorder.none,
                              focusedBorder: InputBorder.none,
                              counterText: '',
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 16,
                              ),
                            ),
                            onChanged: (_) => setState(() {}),
                            onSubmitted: (_) => _continue(),
                          ),
                        ),

                        // Red check when 10 digits filled
                        if (_phoneReady)
                          Padding(
                            padding: const EdgeInsets.only(right: 14),
                            child: Container(
                              width: 22,
                              height: 22,
                              decoration: const BoxDecoration(
                                color: AppTheme.primaryRed,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.check_rounded,
                                size: 14,
                                color: Colors.white,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // ── Continue button ───────────────────────────────────────
                  AppButton.primary(
                    label: 'Continue',
                    onPressed: _phoneReady ? _continue : null,
                    disabled: !_phoneReady,
                    trailingIcon: const Icon(Icons.arrow_forward_rounded),
                  ),

                  const SizedBox(height: 36),

                  // ── Secure divider ────────────────────────────────────────
                  Row(
                    children: [
                      Expanded(child: Divider(color: Colors.grey.shade300)),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: AppText.label(
                          'SECURE ACCESS',
                          color: Colors.grey.shade400,
                        ),
                      ),
                      Expanded(child: Divider(color: Colors.grey.shade300)),
                    ],
                  ),

                  const SizedBox(height: 20),

                  // ── Feature chips ─────────────────────────────────────────
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
                          label: 'Fast OTP',
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 36),

                  // ── Login as Admin ────────────────────────────────────────
                  AppButton.ghost(
                    label: 'Login as Admin',
                    onPressed: () => context.go('/admin/login'),
                    leadingIcon: const Icon(
                      Icons.admin_panel_settings_outlined,
                    ),
                    width: null,
                  ),

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

// ── Feature Chip ──────────────────────────────────────────────────────────────
class _FeatureChip extends StatelessWidget {
  final IconData icon;
  final String label;
  const _FeatureChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(icon, size: 22, color: AppTheme.primaryRed),
          const SizedBox(height: 6),
          AppText.bodyMedium(label),
        ],
      ),
    );
  }
}
