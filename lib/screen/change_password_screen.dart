// lib/screen/change_password_screen.dart
// ignore_for_file: use_build_context_synchronously, unused_field, deprecated_member_use

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ChangePasswordScreen extends StatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _isLoading = false;

  static const Color primaryOrange = Color(0xFFFF6600);

  @override
  void dispose() {
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _savePassword() async {
    if (!_formKey.currentState!.validate()) return;
    
    setState(() => _isLoading = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null || user.email == null) {
        throw Exception("No user is currently signed in.");
      }

      // 1. Re-authenticate
      final credential = EmailAuthProvider.credential(
        email: user.email!,
        password: _currentPasswordController.text,
      );
      await user.reauthenticateWithCredential(credential);

      // 2. Update password
      await user.updatePassword(_newPasswordController.text);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Password changed successfully!"),
          backgroundColor: Colors.green,
        ),
      );

      Navigator.pop(context);
    } on FirebaseAuthException catch (e) {
      String message = 'Something went wrong. Please try again';
      switch (e.code) {
        case 'wrong-password': message = 'Current password is incorrect'; break;
        case 'weak-password': message = 'New password must be at least 6 characters'; break;
        case 'requires-recent-login': message = 'Session expired. Please log in again'; break;
        case 'network-request-failed': message = 'No internet connection'; break;
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.red,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Something went wrong. Please try again'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textDark = theme.colorScheme.onSurface;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: theme.colorScheme.surface,
        elevation: 1,
        title: Text(
          'Change Password',
          style: TextStyle(color: textDark, fontWeight: FontWeight.bold),
        ),
        iconTheme: IconThemeData(color: textDark),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [theme.colorScheme.surface, theme.colorScheme.background],
            stops: const [0.3, 0.7],
          ),
        ),
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(24.0),
            children: [
              const SizedBox(height: 20),
              _PasswordTextField(
                controller: _currentPasswordController,
                hintText: "Current Password",
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter your current password';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),
              _PasswordTextField(
                controller: _newPasswordController,
                hintText: "New Password",
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter a new password';
                  }
                  if (value.length < 6) {
                    return 'Password must be at least 6 characters';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),
              _PasswordTextField(
                controller: _confirmPasswordController,
                hintText: "Confirm New Password",
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please confirm your new password';
                  }
                  if (value != _newPasswordController.text) {
                    return 'Passwords do not match';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 40),
              _buildAuthButton(
                text: "Save Changes",
                isLoading: _isLoading,
                onPressed: _savePassword,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Helper Widget for Password Text Fields (reused from login_screen.dart for consistency)
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
      decoration: InputDecoration(
        hintText: widget.hintText,
        hintStyle: TextStyle(
          color: theme.colorScheme.onSurface.withOpacity(0.7),
        ),
        suffixIcon: IconButton(
          icon: Icon(
            _isObscured
                ? Icons.visibility_off_rounded
                : Icons.visibility_rounded,
            color: theme.unselectedWidgetColor,
          ),
          onPressed: () => setState(() => _isObscured = !_isObscured),
        ),
        filled: true,
        fillColor: theme.brightness == Brightness.light
            ? Colors.grey.shade50
            : theme.colorScheme.onSurface.withOpacity(0.1),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFFF6600), width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.red, width: 1),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
      ),
    );
  }
}

// Helper Widget for the main button (reused from login_screen.dart for consistency)
Widget _buildAuthButton({
  required String text,
  required bool isLoading,
  required VoidCallback onPressed,
}) {
  return Container(
    width: double.infinity,
    height: 56,
    decoration: BoxDecoration(
      color: const Color(0xFFFF6600),
      borderRadius: BorderRadius.circular(12),
      boxShadow: [
        BoxShadow(
          color: const Color(0xFFFF6600).withOpacity(0.3),
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
