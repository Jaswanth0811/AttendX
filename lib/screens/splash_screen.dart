import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'main_screen.dart';
import 'login_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _iconScaleAnimation;
  late Animation<double> _iconAlphaAnimation;
  late Animation<double> _textOffsetAnimation;
  late Animation<double> _textAlphaAnimation;

  final GoogleSignIn _googleSignIn = GoogleSignIn(
    serverClientId: '1053631789111-8pupmk1jmsfujpbuhp5ifdcnr81oesun.apps.googleusercontent.com',
  );

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );

    // Icon scale: 0.3 to 1.0 in first 800ms (0.0 to 0.53 in normalized time)
    _iconScaleAnimation = Tween<double>(begin: 0.3, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.53, curve: Curves.easeOut),
      ),
    );

    // Icon alpha: 0.0 to 1.0 in first 800ms
    _iconAlphaAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.53, curve: Curves.easeOut),
      ),
    );

    // Text offset: 30.0 to 0.0 from 300ms to 1100ms (0.2 to 0.73 in normalized time)
    _textOffsetAnimation = Tween<double>(begin: 30.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.2, 0.73, curve: Curves.easeOut),
      ),
    );

    // Text alpha: 0.0 to 1.0 from 300ms to 900ms (0.2 to 0.6 in normalized time)
    _textAlphaAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.2, 0.6, curve: Curves.easeOut),
      ),
    );

    _controller.forward();

    // Check login state and navigate after 2.5 seconds total
    Future.delayed(const Duration(milliseconds: 2500), _checkLoginAndNavigate);
  }

  Future<void> _checkLoginAndNavigate() async {
    if (!mounted) return;
    try {
      final isLoggedIn = await _googleSignIn.isSignedIn();
      if (isLoggedIn) {
        if (!mounted) return;
        Navigator.of(context).pushReplacement(
          PageRouteBuilder(
            pageBuilder: (context, animation, secondaryAnimation) => const MainScreen(),
            transitionsBuilder: (context, animation, secondaryAnimation, child) {
              return FadeTransition(opacity: animation, child: child);
            },
            transitionDuration: const Duration(milliseconds: 150),
          ),
        );
      } else {
        if (!mounted) return;
        Navigator.of(context).pushReplacement(
          PageRouteBuilder(
            pageBuilder: (context, animation, secondaryAnimation) => const LoginScreen(),
            transitionsBuilder: (context, animation, secondaryAnimation, child) {
              return FadeTransition(opacity: animation, child: child);
            },
            transitionDuration: const Duration(milliseconds: 150),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      // In case of error (e.g. no internet/play services), fall back to Login screen
      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) => const LoginScreen(),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(opacity: animation, child: child);
          },
          transitionDuration: const Duration(milliseconds: 150),
        ),
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              theme.colorScheme.primary,
              theme.colorScheme.primaryContainer,
            ],
          ),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedBuilder(
                animation: _controller,
                builder: (context, child) {
                  return Opacity(
                    opacity: _iconAlphaAnimation.value,
                    child: Transform.scale(
                      scale: _iconScaleAnimation.value,
                      child: Image.asset(
                        'assets/images/attendx_logo.png',
                        width: 160,
                        height: 160,
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 24),
              AnimatedBuilder(
                animation: _controller,
                builder: (context, child) {
                  return Opacity(
                    opacity: _textAlphaAnimation.value,
                    child: Transform.translate(
                      offset: Offset(0, _textOffsetAnimation.value),
                      child: Column(
                        children: [
                          Text(
                            'AttendX',
                            style: TextStyle(
                              fontSize: 36,
                              fontWeight: FontWeight.bold,
                              color: theme.colorScheme.onPrimary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Track Smart. Attend Better.',
                            style: TextStyle(
                              fontSize: 16,
                              color: theme.colorScheme.onPrimary.withOpacity(0.8),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
