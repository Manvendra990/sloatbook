import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:slotbooking/features/auth/screens/userlogin_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late AnimationController _logoController;
  late AnimationController _progressController;
  late AnimationController _glowController;

  late Animation<double> _logoOpacity;
  late Animation<double> _logoScale;
  late Animation<double> _taglineOpacity;
  late Animation<double> _progressWidth;
  late Animation<double> _glowOpacity;

  @override
  void initState() {
    super.initState();
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
      ),
    );
    _setupAnimations();
    _startSequence();
  }

  void _setupAnimations() {
    _logoController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _logoOpacity = Tween<double>(
      begin: 0,
      end: 1,
    ).animate(CurvedAnimation(parent: _logoController, curve: Curves.easeOut));
    _logoScale = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _logoController, curve: Curves.easeOutBack),
    );
    _taglineOpacity = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _logoController,
        curve: const Interval(0.5, 1.0, curve: Curves.easeOut),
      ),
    );

    _progressController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    );
    _progressWidth = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _progressController, curve: Curves.easeInOut),
    );

    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);
    _glowOpacity = Tween<double>(begin: 0.4, end: 1.0).animate(_glowController);
  }

  Future<void> _startSequence() async {
    await Future.delayed(const Duration(milliseconds: 300));
    _logoController.forward();
    await Future.delayed(const Duration(milliseconds: 600));
    _progressController.forward();
    await Future.delayed(const Duration(milliseconds: 2100));
    if (mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const UserLoginScreen()),
      );
    }
  }

  @override
  void dispose() {
    _logoController.dispose();
    _progressController.dispose();
    _glowController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0E1012),
      body: Stack(
        fit: StackFit.expand,
        children: [
          // ── 1. Background sports image ─────────────────────────────────
          Image.asset(
            'assets/images/goarena.png', // same asset as login screen
            fit: BoxFit.cover,
          ),

          // ── 2. Multi-layer dark overlay ────────────────────────────────
          // Top: very dark so logo pops
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                stops: [0.0, 0.35, 0.65, 1.0],
                colors: [
                  Color(0xEE000000), // dark top
                  Color(0x99000000), // mid fade
                  Color(0x99000000), // mid fade
                  Color(0xEE000000), // dark bottom
                ],
              ),
            ),
          ),

          // ── 3. Radial red glow behind logo ─────────────────────────────
          Center(
            child: AnimatedBuilder(
              animation: _logoOpacity,
              builder: (_, __) => Opacity(
                opacity: _logoOpacity.value * 0.25,
                child: Container(
                  width: 340,
                  height: 340,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [Color(0xFFD0021B), Colors.transparent],
                    ),
                  ),
                ),
              ),
            ),
          ),

          // ── 4. Main content ────────────────────────────────────────────
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Logo icon
                AnimatedBuilder(
                  animation: _logoController,
                  builder: (_, __) => Opacity(
                    opacity: _logoOpacity.value,
                    child: Transform.scale(
                      scale: _logoScale.value,
                      child: Container(
                        width: 88,
                        height: 88,
                        decoration: BoxDecoration(
                          color: const Color(0xFFD0021B),
                          borderRadius: BorderRadius.circular(24),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFFD0021B).withOpacity(0.6),
                              blurRadius: 32,
                              spreadRadius: 4,
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.bolt_rounded,
                          color: Colors.white,
                          size: 50,
                        ),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                // Brand name — GO ARENA
                AnimatedBuilder(
                  animation: _logoController,
                  builder: (_, __) => Opacity(
                    opacity: _logoOpacity.value,
                    child: Transform.scale(
                      scale: _logoScale.value,
                      child: RichText(
                        textAlign: TextAlign.center,
                        text: const TextSpan(
                          children: [
                            TextSpan(
                              text: 'GO',
                              style: TextStyle(
                                fontSize: 48,
                                fontWeight: FontWeight.w900,
                                fontStyle: FontStyle.italic,
                                color: Colors.white,
                                letterSpacing: 2,
                              ),
                            ),
                            TextSpan(
                              text: ' ARENA',
                              style: TextStyle(
                                fontSize: 48,
                                fontWeight: FontWeight.w900,
                                fontStyle: FontStyle.italic,
                                color: Color(0xFFD0021B),
                                letterSpacing: 2,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 10),

                // Tagline
                AnimatedBuilder(
                  animation: _taglineOpacity,
                  builder: (_, __) => Opacity(
                    opacity: _taglineOpacity.value,
                    child: Text(
                      'UNLEASH THE GAME',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w400,
                        color: Colors.white.withOpacity(0.55),
                        letterSpacing: 7,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 56),

                // Progress bar — red
                SizedBox(
                  width: 160,
                  child: AnimatedBuilder(
                    animation: Listenable.merge([_progressWidth, _glowOpacity]),
                    builder: (_, __) => Stack(
                      children: [
                        // Track
                        Container(
                          height: 2,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(1),
                          ),
                        ),
                        // Fill
                        FractionallySizedBox(
                          widthFactor: _progressWidth.value,
                          child: Container(
                            height: 2,
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFFFF6B6B), Color(0xFFD0021B)],
                              ),
                              borderRadius: BorderRadius.circular(1),
                              boxShadow: [
                                BoxShadow(
                                  color: Color.fromRGBO(
                                    208,
                                    2,
                                    27,
                                    _glowOpacity.value * 0.9,
                                  ),
                                  blurRadius: 10,
                                  spreadRadius: 2,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 22),

                // Powered by
                AnimatedBuilder(
                  animation: _taglineOpacity,
                  builder: (_, __) => Opacity(
                    opacity: _taglineOpacity.value,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Powered by GO ARENA Tech',
                          style: TextStyle(
                            fontSize: 10,
                            color: Colors.white.withOpacity(0.35),
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Icon(
                          Icons.bolt,
                          size: 12,
                          color: Color(0xFFD0021B),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
