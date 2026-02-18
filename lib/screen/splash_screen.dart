// lib/screen/splash_screen.dart
import 'dart:async';
import 'package:clone_mp/services/auth_service.dart';
import 'package:clone_mp/services/playlist_service.dart';
import 'package:clone_mp/services/personalization_service.dart';
import 'package:clone_mp/services/theme_notifier.dart';
import 'package:flutter/material.dart';
import 'package:clone_mp/route_names.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:clone_mp/services/migration_service.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();

    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOutQuint),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeIn),
    );

    _animationController.forward();

    // Call the new method to decide where to navigate
    _checkLoginStatus();
  }

  Future<void> _checkLoginStatus() async {
    await AuthService.instance.init();
    await Future.delayed(const Duration(seconds: 2));

    if (!mounted) return;

    final firebaseUser = FirebaseAuth.instance.currentUser;

    if (firebaseUser != null) {
      final user = AuthService.instance.currentUser;
      if (user == null) {
        Navigator.of(context).pushReplacementNamed(AppRoutes.login);
        return;
      }

      // Migrate SharedPreferences data to Firestore (no-op if already done)
      await MigrationService().migrateIfNeeded(user.email);

      final playlistService = 
        Provider.of<PlaylistService>(context, listen: false);
      final themeNotifier = 
        Provider.of<ThemeNotifier>(context, listen: false);

      await playlistService.loadUserData(user.email);
      await themeNotifier.loadTheme(user.email);

      if (!mounted) return;

      final personalizationService = 
        Provider.of<PersonalizationService>(context, listen: false);
      final isPersonalized = await personalizationService
        .isPersonalizationCompleted(user.email);

      if (!mounted) return;

      if (isPersonalized) {
        Navigator.of(context).pushReplacementNamed(AppRoutes.main);
      } else {
        Navigator.of(context).pushReplacementNamed(AppRoutes.personalization);
      }
    } else {
      Navigator.of(context).pushReplacementNamed(AppRoutes.login);
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFF6B47),
      body: Center(
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: ScaleTransition(
            scale: _scaleAnimation,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Image.asset('assets/images/logo.png', width: 120, height: 120),
                const SizedBox(height: 20),
                const Text(
                  'TuneWave',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
