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
      const SystemUiOverlayStyle(statusBarColor: Colors.transparent),
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

    // Navigate after 3 seconds
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
        children: [
          // Background radial glow
          Center(
            child: AnimatedBuilder(
              animation: _logoOpacity,
              builder: (_, __) => Opacity(
                opacity: _logoOpacity.value * 0.15,
                child: Container(
                  width: 320,
                  height: 320,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [Color(0xFF39FF8F), Colors.transparent],
                    ),
                  ),
                ),
              ),
            ),
          ),

          // Main content
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // KINETIC logo
                AnimatedBuilder(
                  animation: _logoController,
                  builder: (_, __) => Opacity(
                    opacity: _logoOpacity.value,
                    child: Transform.scale(
                      scale: _logoScale.value,
                      child: ShaderMask(
                        shaderCallback: (bounds) => const LinearGradient(
                          colors: [Color(0xFF4DFFA0), Color(0xFF00CC6A)],
                        ).createShader(bounds),
                        child: const Text(
                          'KINETIC',
                          style: TextStyle(
                            fontSize: 44,
                            fontWeight: FontWeight.w900,
                            fontStyle: FontStyle.italic,
                            color: Colors.white,
                            letterSpacing: 3,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // Tagline
                AnimatedBuilder(
                  animation: _taglineOpacity,
                  builder: (_, __) => Opacity(
                    opacity: _taglineOpacity.value,
                    child: Text(
                      'UNLEASH THE GAME',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w300,
                        color: Colors.white.withOpacity(0.5),
                        letterSpacing: 8,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 48),

                // Progress bar
                SizedBox(
                  width: 160,
                  child: AnimatedBuilder(
                    animation: Listenable.merge([_progressWidth, _glowOpacity]),
                    builder: (_, __) => Stack(
                      children: [
                        Container(
                          height: 2,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(1),
                          ),
                        ),
                        FractionallySizedBox(
                          widthFactor: _progressWidth.value,
                          child: Container(
                            height: 2,
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFF4DFFA0), Color(0xFF00CC6A)],
                              ),
                              borderRadius: BorderRadius.circular(1),
                              boxShadow: [
                                BoxShadow(
                                  color: Color.fromRGBO(
                                    57,
                                    255,
                                    143,
                                    _glowOpacity.value * 0.8,
                                  ),
                                  blurRadius: 8,
                                  spreadRadius: 1,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                // Powered by
                AnimatedBuilder(
                  animation: _taglineOpacity,
                  builder: (_, __) => Opacity(
                    opacity: _taglineOpacity.value,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Powered by KINETIC Tech',
                          style: TextStyle(
                            fontSize: 10,
                            color: Colors.white.withOpacity(0.4),
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Icon(
                          Icons.bolt,
                          size: 12,
                          color: Color(0xFF4DFFA0),
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
