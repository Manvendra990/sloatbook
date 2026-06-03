import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:slotbooking/features/auth/screens/login_screen.dart';

class RoleSelectionScreen extends StatefulWidget {
  const RoleSelectionScreen({super.key});

  @override
  State<RoleSelectionScreen> createState() => _RoleSelectionScreenState();
}

class _RoleSelectionScreenState extends State<RoleSelectionScreen>
    with TickerProviderStateMixin {
  late final List<AnimationController> _cardControllers;
  late final List<Animation<double>> _cardFades;
  late final List<Animation<Offset>> _cardSlides;
  late final AnimationController _headerController;
  late final Animation<double> _headerFade;
  late final Animation<Offset> _headerSlide;

  @override
  void initState() {
    super.initState();
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
      ),
    );

    _headerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _headerFade = CurvedAnimation(
      parent: _headerController,
      curve: Curves.easeOut,
    );
    _headerSlide = Tween<Offset>(begin: const Offset(0, -0.3), end: Offset.zero)
        .animate(
          CurvedAnimation(
            parent: _headerController,
            curve: Curves.easeOutCubic,
          ),
        );

    _cardControllers = List.generate(
      3,
      (i) => AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 600),
      ),
    );

    _cardFades = _cardControllers
        .map((c) => CurvedAnimation(parent: c, curve: Curves.easeOut))
        .toList();

    _cardSlides = _cardControllers
        .map(
          (c) => Tween<Offset>(
            begin: const Offset(0, 0.15),
            end: Offset.zero,
          ).animate(CurvedAnimation(parent: c, curve: Curves.easeOutCubic)),
        )
        .toList();

    _startAnimations();
  }

  Future<void> _startAnimations() async {
    _headerController.forward();
    await Future.delayed(const Duration(milliseconds: 200));
    for (var i = 0; i < _cardControllers.length; i++) {
      _cardControllers[i].forward();
      await Future.delayed(const Duration(milliseconds: 120));
    }
  }

  @override
  void dispose() {
    _headerController.dispose();
    for (final c in _cardControllers) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFE8EBE8),
      body: SafeArea(
        child: Column(
          children: [
            // ── Header ───────────────────────────────────────────────
            SlideTransition(
              position: _headerSlide,
              child: FadeTransition(
                opacity: _headerFade,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(0, 36, 0, 28),
                  child: Column(
                    children: [
                      RichText(
                        text: const TextSpan(
                          children: [
                            TextSpan(
                              text: 'KINETIC',
                              style: TextStyle(
                                fontFamily: 'serif',
                                fontSize: 34,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 3,
                                color: Color(0xFF0D5C40),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'U N L E A S H   T H E   G A M E',
                        style: TextStyle(
                          fontSize: 10,
                          letterSpacing: 3.5,
                          fontWeight: FontWeight.w500,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // ── Cards ────────────────────────────────────────────────
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                children: [
                  _RoleCard(
                    index: 0,
                    fade: _cardFades[0],
                    slide: _cardSlides[0],
                    icon: Icons.sports_soccer_rounded,
                    iconBg: const Color(0xFFD6F0E5),
                    iconColor: const Color(0xFF0D8C5A),
                    title: 'Player / User',
                    description:
                        'Book premium grounds, track performance, and join the local elite sports community.',
                    buttonLabel: 'Enter Arena',
                    buttonIcon: Icons.arrow_forward_rounded,
                    buttonStyle: _ButtonStyle.filled,
                    onTap: () => context.go('/user/login'),
                  ),
                  const SizedBox(height: 14),
                  _RoleCard(
                    index: 1,
                    fade: _cardFades[1],
                    slide: _cardSlides[1],
                    icon: Icons.calendar_month_rounded,
                    iconBg: const Color(0xFFE4EAF6),
                    iconColor: const Color(0xFF3B5AA0),
                    title: 'Facility Admin',
                    description:
                        'Full-stack ground management, real-time slot scheduling, and revenue optimization.',
                    buttonLabel: 'Manage Grounds',
                    buttonIcon: Icons.tune_rounded,
                    buttonStyle: _ButtonStyle.outlined,
                    onTap: () => context.go('/admin/login?role=admin'),
                  ),
                  const SizedBox(height: 14),
                ],
              ),
            ),

            // ── Footer ───────────────────────────────────────────────
            FadeTransition(
              opacity: _cardFades.last,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _FooterLink(
                          icon: Icons.handshake_outlined,
                          label: 'Become a Partner',
                          onTap: () {},
                        ),
                        const SizedBox(width: 28),
                        _FooterLink(
                          icon: Icons.headset_mic_outlined,
                          label: 'Support',
                          onTap: () {},
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '© 2024 KINETIC TECHNOLOGIES. ALL RIGHTS RESERVED.',
                      style: TextStyle(
                        fontSize: 9,
                        letterSpacing: 0.5,
                        color: Colors.grey[500],
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Role Card ─────────────────────────────────────────────────────────────────

enum _ButtonStyle { filled, outlined, ghost }

class _RoleCard extends StatefulWidget {
  final int index;
  final Animation<double> fade;
  final Animation<Offset> slide;
  final IconData icon;
  final Color iconBg;
  final Color iconColor;
  final String title;
  final String description;
  final String buttonLabel;
  final IconData buttonIcon;
  final _ButtonStyle buttonStyle;
  final VoidCallback onTap;

  const _RoleCard({
    required this.index,
    required this.fade,
    required this.slide,
    required this.icon,
    required this.iconBg,
    required this.iconColor,
    required this.title,
    required this.description,
    required this.buttonLabel,
    required this.buttonIcon,
    required this.buttonStyle,
    required this.onTap,
  });

  @override
  State<_RoleCard> createState() => _RoleCardState();
}

class _RoleCardState extends State<_RoleCard> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return SlideTransition(
      position: widget.slide,
      child: FadeTransition(
        opacity: widget.fade,
        child: GestureDetector(
          onTapDown: (_) => setState(() => _pressed = true),
          onTapUp: (_) {
            setState(() => _pressed = false);
            widget.onTap();
          },
          onTapCancel: () => setState(() => _pressed = false),
          child: AnimatedScale(
            scale: _pressed ? 0.975 : 1.0,
            duration: const Duration(milliseconds: 100),
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.06),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Icon badge
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: widget.iconBg,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(widget.icon, color: widget.iconColor, size: 26),
                  ),
                  const SizedBox(height: 18),

                  // Title
                  Text(
                    widget.title,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.5,
                      color: Color(0xFF0E1A13),
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Description
                  Text(
                    widget.description,
                    style: TextStyle(
                      fontSize: 14,
                      height: 1.55,
                      color: Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 22),

                  // Button
                  _ActionButton(
                    label: widget.buttonLabel,
                    icon: widget.buttonIcon,
                    style: widget.buttonStyle,
                    onTap: widget.onTap,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Action Button ─────────────────────────────────────────────────────────────

class _ActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final _ButtonStyle style;
  final VoidCallback onTap;

  const _ActionButton({
    required this.label,
    required this.icon,
    required this.style,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    const green = Color(0xFF0D8C5A);
    const softBlue = Color(0xFFE4EAF6);
    const blueMuted = Color(0xFF3B5AA0);

    switch (style) {
      // ── Filled (green) — Player/User
      case _ButtonStyle.filled:
        return SizedBox(
          width: double.infinity,
          height: 50,
          child: ElevatedButton(
            onPressed: onTap,
            style: ElevatedButton.styleFrom(
              backgroundColor: green,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(50),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                    letterSpacing: 0.2,
                  ),
                ),
                const SizedBox(width: 8),
                Icon(icon, size: 18),
              ],
            ),
          ),
        );

      // ── Outlined soft blue — Admin
      case _ButtonStyle.outlined:
        return SizedBox(
          width: double.infinity,
          height: 50,
          child: ElevatedButton(
            onPressed: onTap,
            style: ElevatedButton.styleFrom(
              backgroundColor: softBlue,
              foregroundColor: blueMuted,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(50),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                    letterSpacing: 0.2,
                  ),
                ),
                const SizedBox(width: 8),
                Icon(icon, size: 18),
              ],
            ),
          ),
        );

      // ── Ghost muted — Super Admin
      case _ButtonStyle.ghost:
        return SizedBox(
          width: double.infinity,
          height: 50,
          child: ElevatedButton(
            onPressed: onTap,
            style: ElevatedButton.styleFrom(
              backgroundColor: softBlue.withOpacity(0.6),
              foregroundColor: blueMuted.withOpacity(0.7),
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(50),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontWeight: FontWeight.w500,
                    fontSize: 15,
                    letterSpacing: 0.2,
                  ),
                ),
                const SizedBox(width: 8),
                Icon(icon, size: 18),
              ],
            ),
          ),
        );
    }
  }
}

// ── Footer Link ───────────────────────────────────────────────────────────────

class _FooterLink extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _FooterLink({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Row(
        children: [
          Icon(icon, size: 14, color: Colors.grey[600]),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: Colors.grey[700],
              decoration: TextDecoration.underline,
              decorationColor: Colors.grey[400],
            ),
          ),
        ],
      ),
    );
  }
}
