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
import 'package:clone_mp/services/ui_state_service.dart';
import 'package:animated_text_kit/animated_text_kit.dart';
import 'package:google_fonts/google_fonts.dart';

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
    
    // Explicitly lock the mini player during splash screen
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<UiStateService>(context, listen: false).hideMiniPlayer();
    });

    // Call the new method to decide where to navigate
    _checkLoginStatus();
  }

  Future<void> _checkLoginStatus() async {
    debugPrint("SPLASH: Checking login status...");
    try {
      // 1. Initialize Auth Service with timeout
      await AuthService.instance.init().timeout(const Duration(seconds: 5));
    } catch (e) {
      debugPrint("SPLASH: Auth init timed out or failed: $e");
    }

    await Future.delayed(const Duration(seconds: 1)); // Reduced delay for faster startup

    if (!mounted) return;

    final firebaseUser = FirebaseAuth.instance.currentUser;

    if (firebaseUser != null) {
      // If user profile is null but firebaseUser exists, we likely have a network issue.
      // We can create a temporary user model from firebaseUser to allow app to open.
      final String userEmail = firebaseUser.email ?? "";

      // 2. Migration with strict timeout
      try {
        await MigrationService().migrateIfNeeded(userEmail).timeout(const Duration(seconds: 5));
      } catch (e) {
        debugPrint("SPLASH: Migration timed out or failed: $e");
      }

      if (!mounted) return;

      final playlistService = Provider.of<PlaylistService>(context, listen: false);
      final themeNotifier = Provider.of<ThemeNotifier>(context, listen: false);

      // 3. Load user data (liked songs, playlists) with timeout
      try {
        await playlistService.loadUserData(userEmail).timeout(const Duration(seconds: 8));
      } catch (e) {
        debugPrint("SPLASH: Playlist loading timed out or failed: $e");
      }
      
      try {
        await themeNotifier.loadTheme(userEmail).timeout(const Duration(seconds: 3));
      } catch (e) {
        debugPrint("SPLASH: Theme loading failed: $e");
      }

      if (!mounted) return;

      // 4. Personalization check with timeout
      final personalizationService = Provider.of<PersonalizationService>(context, listen: false);
      bool isPersonalized = true; // Assume true if we can't check
      try {
        isPersonalized = await personalizationService
          .isPersonalizationCompleted(userEmail)
          .timeout(const Duration(seconds: 5));
      } catch (e) {
        debugPrint("SPLASH: Personalization check timed out: $e");
      }

      if (!mounted) return;

      if (isPersonalized) {
        Navigator.of(context).pushNamedAndRemoveUntil(AppRoutes.main, (route) => false);
      } else {
        Navigator.of(context).pushNamedAndRemoveUntil(AppRoutes.personalization, (route) => false);
      }
    } else {
      Navigator.of(context).pushNamedAndRemoveUntil(AppRoutes.login, (route) => false);
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
                DefaultTextStyle(
                  style: GoogleFonts.pacifico(
                    fontSize: 40,
                    fontWeight: FontWeight.w400,
                    color: Colors.black87,
                    shadows: [
                      const Shadow(
                        blurRadius: 4.0,
                        color: Colors.black12,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  child: AnimatedTextKit(
                    animatedTexts: [
                      TyperAnimatedText(
                        'TuneWave',
                        speed: const Duration(milliseconds: 150),
                      ),
                    ],
                    isRepeatingAnimation: false,
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
