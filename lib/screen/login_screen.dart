// ignore_for_file: use_build_context_synchronously, deprecated_member_use

import 'package:clone_mp/services/auth_service.dart';
import 'package:clone_mp/services/playlist_service.dart';
import 'package:clone_mp/services/theme_notifier.dart';
import 'package:flutter/material.dart';
import 'package:clone_mp/route_names.dart';
import 'package:clone_mp/services/personalization_service.dart';
import 'package:clone_mp/services/migration_service.dart';
import 'package:provider/provider.dart';
import 'package:clone_mp/widgets/music_toast.dart';

// This file remains the entry point for your onboarding flow.
// It now loads the AuthPager which contains the separate Login and Sign Up pages.
class OnboardingPager extends StatefulWidget {
  const OnboardingPager({super.key});

  @override
  State<OnboardingPager> createState() => _OnboardingPagerState();
}

class _OnboardingPagerState extends State<OnboardingPager> {
  final PageController _pageController = PageController();

  void _goToAuthPage() {
    _pageController.animateToPage(
      1,
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeInOut,
    );
  }

  void _goToWelcomePage() {
    _pageController.animateToPage(
      0,
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeInOut,
    );
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: PageView(
        controller: _pageController,
        scrollDirection: Axis.vertical,
        physics: const NeverScrollableScrollPhysics(), // Disable user swiping
        children: [
          SwipeUpWelcomeScreen(onSwipeUp: _goToAuthPage),
          AuthPager(onSwipeDown: _goToWelcomePage),
        ],
      ),
    );
  }
}

// This new widget acts as a container for the Login and Sign Up pages,
// allowing the user to swipe horizontally between them.
class AuthPager extends StatefulWidget {
  final VoidCallback? onSwipeDown;
  const AuthPager({super.key, this.onSwipeDown});

  @override
  State<AuthPager> createState() => _AuthPagerState();
}

class _AuthPagerState extends State<AuthPager> {
  final PageController _pageController = PageController();

  void _goToSignUp() {
    _pageController.animateToPage(
      1,
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeInOut,
    );
  }

  void _goToLogin() {
    _pageController.animateToPage(
      0,
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeInOut,
    );
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PageView(
      controller: _pageController,
      physics: const ClampingScrollPhysics(),
      children: [
        LoginPage(onGoToSignUp: _goToSignUp, onSwipeDown: widget.onSwipeDown),
        SignUpPage(onGoToLogin: _goToLogin, onSwipeDown: widget.onSwipeDown),
      ],
    );
  }
}

// The new, dedicated Login Page.
class LoginPage extends StatefulWidget {
  final VoidCallback? onGoToSignUp;
  final VoidCallback? onSwipeDown;

  const LoginPage({super.key, this.onGoToSignUp, this.onSwipeDown});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _isLoading = false;
  bool _isResettingPassword = false;

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    final email = _emailController.text;
    final password = _passwordController.text;

    try {
      await AuthService.instance.login(email, password);

      if (!mounted) return;

      // Migrate SharedPreferences data to Firestore (no-op if already done)
      final user = AuthService.instance.currentUser!;
      await MigrationService().migrateIfNeeded(user.email);

      // Load user data
      await Provider.of<PlaylistService>(context, listen: false).loadUserData(user.email);
      await Provider.of<ThemeNotifier>(context, listen: false).loadTheme(user.email);

      // Check Personalization Status
      final personalizationService = Provider.of<PersonalizationService>(context, listen: false);
      final isPersonalized = await personalizationService.isPersonalizationCompleted(user.email);

      setState(() => _isLoading = false);

      if (isPersonalized) {
        Navigator.pushNamedAndRemoveUntil(context, AppRoutes.main, (route) => false);
      } else {
        Navigator.pushNamedAndRemoveUntil(context, AppRoutes.personalization, (route) => false);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      showMusicToast(context, e.toString(), type: ToastType.error);
    }
  }

  void _handleForgotPassword() {
    final email = _emailController.text;
    if (email.isEmpty ||
        !RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(email)) {
      showMusicToast(context, "Please enter your email address first.", type: ToastType.error);
      return;
    }
    setState(() {
      _isResettingPassword = true;
    });
  }

  void _handlePasswordReset() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    await Future.delayed(const Duration(seconds: 2));

    showMusicToast(context, "Password has been reset successfully! Please log in.", type: ToastType.success);

    setState(() {
      _isLoading = false;
      _isResettingPassword = false;
      _passwordController.clear();
      _newPasswordController.clear();
      _confirmPasswordController.clear();
    });
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final themeNotifier = Provider.of<ThemeNotifier>(context, listen: false);

    List<Widget> formFields;
    Widget authButton;
    Widget switchAuthText;
    String formTitle;

    if (_isResettingPassword) {
      formTitle = "Reset Your Password";
      formFields = [
        _buildEmailField(_emailController),
        const SizedBox(height: 20),
        _buildPasswordField(_newPasswordController, isLogin: false),
        const SizedBox(height: 20),
        _buildConfirmPasswordField(
          _confirmPasswordController,
          _newPasswordController,
        ),
        const SizedBox(height: 20),
      ];
      authButton = _buildAuthButton(
        text: "Reset Password",
        isLoading: _isLoading,
        onPressed: _handlePasswordReset,
      );
      switchAuthText = GestureDetector(
        onTap: () => setState(() => _isResettingPassword = false),
        child: const Text(
          "Back to Login",
          style: TextStyle(
            color: Color(0xFFFF6B47),
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
      );
    } else {
      formTitle = "Enter your account";
      formFields = [
        _buildEmailField(_emailController),
        const SizedBox(height: 20),
        _buildPasswordField(_passwordController),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            onPressed: _handleForgotPassword,
            child: const Text(
              "Forgot your password?",
              style: TextStyle(
                color: Color(0xFFFF6B47),
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ),
      ];
      authButton = _buildAuthButton(
        text: "Login",
        isLoading: _isLoading,
        onPressed: _handleLogin,
      );
      switchAuthText = RichText(
        text: TextSpan(
          text: "Don't have an account? ",
          style: TextStyle(
            color: theme.colorScheme.onSurface.withOpacity(0.7),
            fontSize: 16,
          ),
          children: [
            WidgetSpan(
              child: GestureDetector(
                onTap: widget.onGoToSignUp,
                child: const Text(
                  "Sign up",
                  style: TextStyle(
                    color: Color(0xFFFF6B47),
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    return AuthScreenWrapper(
      topActionIcon: IconButton(
        icon: Icon(
          theme.brightness == Brightness.dark
              ? Icons.wb_sunny_rounded
              : Icons.nightlight_round,
          color: theme.brightness == Brightness.light
              ? Colors.black
              : Colors.white,
        ),
        onPressed: () {
          final newTheme = theme.brightness == Brightness.dark
              ? ThemeMode.light
              : ThemeMode.dark;
          themeNotifier.setTheme(newTheme);
        },
      ),
      onSwipeDown: widget.onSwipeDown,
      formKey: _formKey,
      welcomeTitle: "Hello.\nWelcome back!",
      formTitle: formTitle,
      formFields: formFields,
      authButton: authButton,
      switchAuthText: switchAuthText,
    );
  }
}

// The new, dedicated Sign Up Page.
class SignUpPage extends StatefulWidget {
  final VoidCallback? onGoToLogin;
  final VoidCallback? onSwipeDown;
  const SignUpPage({super.key, this.onGoToLogin, this.onSwipeDown});

  @override
  State<SignUpPage> createState() => _SignUpPageState();
}

class _SignUpPageState extends State<SignUpPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _isLoading = false;

  Future<void> _handleSignUp() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    
    final name = _nameController.text;
    final email = _emailController.text;
    final password = _passwordController.text;
    
    try {
      await AuthService.instance.register(name, email, password);

      if (!mounted) return;

      // Migrate SharedPreferences data to Firestore (no-op for new users)
      final user = AuthService.instance.currentUser!;
      await MigrationService().migrateIfNeeded(user.email);

      // Load user data (empty for new user, but sets the email in services)
      await Provider.of<PlaylistService>(context, listen: false).loadUserData(user.email);
      await Provider.of<ThemeNotifier>(context, listen: false).loadTheme(user.email);

      // Check Personalization Status
      final personalizationService = Provider.of<PersonalizationService>(context, listen: false);
      final isPersonalized = await personalizationService.isPersonalizationCompleted(user.email);

      setState(() => _isLoading = false);
      showMusicToast(context, "Account created successfully!", type: ToastType.success);

      if (isPersonalized) {
        Navigator.pushNamedAndRemoveUntil(context, AppRoutes.main, (route) => false);
      } else {
        Navigator.pushNamedAndRemoveUntil(context, AppRoutes.personalization, (route) => false);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      showMusicToast(context, e.toString(), type: ToastType.error);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final formFields = [
      _buildNameField(_nameController),
      const SizedBox(height: 20),
      _buildEmailField(_emailController),
      const SizedBox(height: 20),
      _buildPasswordField(_passwordController, isLogin: false),
      const SizedBox(height: 20),
      _buildConfirmPasswordField(
        _confirmPasswordController,
        _passwordController,
      ),
      const SizedBox(height: 20),
    ];

    return AuthScreenWrapper(
      topActionIcon: IconButton(
        icon: Icon(
          Icons.arrow_back_ios_new_rounded,
          color: theme.brightness == Brightness.light
              ? Colors.black
              : Colors.white,
        ),
        onPressed: widget.onGoToLogin,
      ),
      onSwipeDown: widget.onSwipeDown,
      formKey: _formKey,
      welcomeTitle: "Hello.\nLet's get started!",
      formTitle: "Create your account",
      formFields: formFields,
      authButton: _buildAuthButton(
        text: "Sign Up",
        isLoading: _isLoading,
        onPressed: _handleSignUp,
      ),
      switchAuthText: RichText(
        text: TextSpan(
          text: "Already have an account? ",
          style: TextStyle(
            color: theme.colorScheme.onSurface.withOpacity(0.7),
            fontSize: 16,
          ),
          children: [
            WidgetSpan(
              child: GestureDetector(
                onTap: widget.onGoToLogin,
                child: const Text(
                  "Sign in",
                  style: TextStyle(
                    color: Color(0xFFFF6B47),
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
// SHARED UI WIDGETS AND HELPERS

class AuthScreenWrapper extends StatefulWidget {
  final VoidCallback? onSwipeDown;
  final GlobalKey<FormState> formKey;
  final String welcomeTitle;
  final String formTitle;
  final List<Widget> formFields;
  final Widget authButton;
  final Widget switchAuthText;
  final Widget? topActionIcon;

  const AuthScreenWrapper({
    super.key,
    this.onSwipeDown,
    required this.formKey,
    required this.welcomeTitle,
    required this.formTitle,
    required this.formFields,
    required this.authButton,
    required this.switchAuthText,
    this.topActionIcon,
  });

  @override
  State<AuthScreenWrapper> createState() => _AuthScreenWrapperState();
}

class _AuthScreenWrapperState extends State<AuthScreenWrapper>
    with SingleTickerProviderStateMixin {
  late AnimationController _slideController;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _slideAnimation = Tween<Offset>(begin: const Offset(0, 1), end: Offset.zero)
        .animate(
          CurvedAnimation(parent: _slideController, curve: Curves.easeOutCubic),
        );
    _slideController.forward();
  }

  @override
  void dispose() {
    _slideController.dispose();
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
            colors: [const Color(0xFFFF6B47), theme.colorScheme.surface],
            stops: const [0.5, 1.0],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Top Welcome Section
              Expanded(
                flex: 2,
                // <<< MODIFIED: Wrapped with a Stack for the background icon
                child: Stack(
                  children: [
                    // <<< NEW: Background headphone icon
                    Positioned(
                      top: 40,
                      left: -80,
                      child: Icon(
                        Icons.headphones_rounded,
                        size: 300,
                        color: Colors.black.withOpacity(0.10),
                      ),
                    ),
                    GestureDetector(
                      onPanUpdate: (details) {
                        if (details.delta.dy > 5) {
                          widget.onSwipeDown?.call();
                        }
                      },
                      behavior: HitTestBehavior.opaque,
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: Stack(
                          children: [
                            if (widget.topActionIcon != null)
                              Positioned(
                                top: 0,
                                left: -12,
                                child: widget.topActionIcon!,
                              ),
                            Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const SizedBox(height: 30),
                                Text(
                                  widget.welcomeTitle,
                                  style: TextStyle(
                                    fontSize: 36,
                                    fontWeight: FontWeight.bold,
                                    color: theme.brightness == Brightness.light
                                        ? Colors.black
                                        : Colors.white,
                                    height: 1.2,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              // Bottom Form Section
              Expanded(
                flex: 4,
                child: SlideTransition(
                  position: _slideAnimation,
                  child: Container(
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surface,
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(30),
                      ),
                    ),
                    child: SingleChildScrollView(
                      physics: const ClampingScrollPhysics(),
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Form(
                          key: widget.formKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Center(
                                child: Container(
                                  width: 50,
                                  height: 4,
                                  decoration: BoxDecoration(
                                    color: theme.unselectedWidgetColor,
                                    borderRadius: BorderRadius.circular(2),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 30),
                              Text(
                                widget.formTitle,
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w600,
                                  color: theme.colorScheme.onSurface,
                                ),
                              ),
                              const SizedBox(height: 30),
                              ...widget.formFields,
                              const SizedBox(height: 30),
                              widget.authButton,
                              const SizedBox(height: 30),
                              Center(child: widget.switchAuthText),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

Widget _buildPasswordField(
  TextEditingController controller, {
  bool isLogin = true,
}) {
  return _PasswordTextField(
    controller: controller,
    hintText: isLogin ? "Enter your password..." : "New Password",
    validator: (value) {
      if (value == null || value.isEmpty) return 'Password is required';
      if (value.length < 6) return 'Password must be at least 6 characters';
      return null;
    },
  );
}

Widget _buildConfirmPasswordField(
  TextEditingController controller,
  TextEditingController passwordController,
) {
  return _PasswordTextField(
    controller: controller,
    hintText: "Confirm New Password",
    validator: (value) {
      if (value == null || value.isEmpty) return 'Confirm password is required';
      if (value != passwordController.text) return 'Passwords do not match';
      return null;
    },
  );
}

class _PasswordTextField extends StatefulWidget {
  final TextEditingController controller;
  final String hintText;
  final FormFieldValidator<String> validator;

  const _PasswordTextField({
    required this.controller,
    required this.hintText,
    required this.validator,
  });

  @override
  State<_PasswordTextField> createState() => _PasswordTextFieldState();
}

class _PasswordTextFieldState extends State<_PasswordTextField> {
  bool _isObscured = true;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return TextFormField(
      controller: widget.controller,
      validator: widget.validator,
      obscureText: _isObscured,
      style: TextStyle(color: theme.colorScheme.onSurface),
      decoration:
          _inputDecoration(
            hintText: widget.hintText,
            suffixIcon: IconButton(
              icon: Icon(
                _isObscured
                    ? Icons.visibility_off_rounded
                    : Icons.visibility_rounded,
                color: theme.unselectedWidgetColor,
              ),
              onPressed: () => setState(() => _isObscured = !_isObscured),
            ),
          ).copyWith(
            fillColor: theme.brightness == Brightness.light
                ? Colors.grey.shade50
                : theme.colorScheme.onSurface.withOpacity(0.1),
            hintStyle: TextStyle(
              color: theme.colorScheme.onSurface.withOpacity(0.7),
            ),
          ),
    );
  }
}

InputDecoration _inputDecoration({
  required String hintText,
  Widget? suffixIcon,
}) {
  return InputDecoration(
    hintText: hintText,
    suffixIcon: suffixIcon,
    filled: true,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide.none,
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: Color(0xFFFF6B47), width: 2),
    ),
    errorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: Colors.red, width: 1),
    ),
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
  );
}

class ThemedTextFormField extends StatelessWidget {
  final TextEditingController controller;
  final String hintText;
  final TextInputType keyboardType;
  final FormFieldValidator<String> validator;

  const ThemedTextFormField({
    super.key,
    required this.controller,
    required this.hintText,
    required this.validator,
    this.keyboardType = TextInputType.text,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return TextFormField(
      controller: controller,
      validator: validator,
      keyboardType: keyboardType,
      style: TextStyle(color: theme.colorScheme.onSurface),
      decoration: _inputDecoration(hintText: hintText).copyWith(
        fillColor: theme.brightness == Brightness.light
            ? Colors.grey.shade50
            : theme.colorScheme.onSurface.withOpacity(0.1),
        hintStyle: TextStyle(
          color: theme.colorScheme.onSurface.withOpacity(0.7),
        ),
      ),
    );
  }
}

Widget _buildNameField(TextEditingController controller) {
  return ThemedTextFormField(
    controller: controller,
    hintText: "Full Name",
    validator: (value) {
      if (value == null || value.isEmpty) return 'Full name is required';
      return null;
    },
  );
}

Widget _buildEmailField(TextEditingController controller) {
  return ThemedTextFormField(
    controller: controller,
    keyboardType: TextInputType.emailAddress,
    hintText: "E-mail",
    validator: (value) {
      if (value == null || value.isEmpty) return 'Email is required';
      if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) {
        return 'Enter a valid email address';
      }
      return null;
    },
  );
}

Widget _buildAuthButton({
  required String text,
  required bool isLoading,
  required VoidCallback onPressed,
}) {
  return Container(
    width: double.infinity,
    height: 56,
    decoration: BoxDecoration(
      color: const Color(0xFFFF6B47),
      borderRadius: BorderRadius.circular(12),
      boxShadow: [
        BoxShadow(
          color: const Color(0xFFFF6B47).withOpacity(0.3),
          blurRadius: 15,
          offset: const Offset(0, 8),
        ),
      ],
    ),
    child: ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.transparent,
        shadowColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      onPressed: isLoading ? null : onPressed,
      child: isLoading
          ? const CircularProgressIndicator(color: Colors.white)
          : Text(
              text,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
    ),
  );
}

class SwipeUpWelcomeScreen extends StatefulWidget {
  final VoidCallback? onSwipeUp;
  const SwipeUpWelcomeScreen({super.key, this.onSwipeUp});
  @override
  State<SwipeUpWelcomeScreen> createState() => _SwipeUpWelcomeScreenState();
}

class _SwipeUpWelcomeScreenState extends State<SwipeUpWelcomeScreen>
    with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late AnimationController _floatController;
  late Animation<double> _pulseAnimation;
  late Animation<double> _floatAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat(reverse: true);

    _floatController = AnimationController(
      duration: const Duration(seconds: 3),
      vsync: this,
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.9, end: 1.1).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _floatAnimation = Tween<double>(begin: -8, end: 8).animate(
      CurvedAnimation(parent: _floatController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _floatController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onPanEnd: (details) {
        if (details.velocity.pixelsPerSecond.dy < -500) {
          widget.onSwipeUp?.call();
        }
      },
      onTap: () {
        widget.onSwipeUp?.call();
      },
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(color: Color(0xFFFF6B47)),
        child: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      AnimatedBuilder(
                        animation: _floatAnimation,
                        builder: (context, child) {
                          return Transform.translate(
                            offset: Offset(0, _floatAnimation.value),
                            child: AnimatedBuilder(
                              animation: _pulseAnimation,
                              builder: (context, child) {
                                return Transform.scale(
                                  scale: _pulseAnimation.value,
                                  child: Container(
                                    width: 180,
                                    height: 180,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: const Color(
                                        0xFFE55A3B,
                                      ).withOpacity(0.3),
                                    ),
                                    child: Center(
                                      child: Image.asset(
                                        'assets/images/logo.png',
                                        width: 115,
                                        height: 115,
                                        fit: BoxFit.contain,
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 80),
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 40),
                        child: Text(
                          "Swipe up to\nexplore the world\nof music",
                          textAlign: TextAlign.left,
                          style: TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                            color: Colors.black,
                            height: 1.2,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: 60),
                child: AnimatedBuilder(
                  animation: _floatAnimation,
                  builder: (context, child) {
                    return Transform.translate(
                      offset: Offset(0, -_floatAnimation.value * 2),
                      child: Column(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.1),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.keyboard_arrow_up_rounded,
                              size: 32,
                              color: Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            "Swipe up or tap to continue",
                            style: TextStyle(
                              color: Colors.black.withOpacity(0.7),
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
