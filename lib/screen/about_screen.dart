// lib/screen/about_screen.dart
// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  static const Color primaryOrange = Color(0xFFFF6600);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textDark = theme.colorScheme.onSurface;
    final textLight = theme.colorScheme.onSurface.withOpacity(0.7);
    final iconColor = theme.unselectedWidgetColor;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: theme.colorScheme.surface,
        elevation: 1,
        title: Text(
          'About',
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
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          children: [
            const SizedBox(height: 40),
            Center(
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: primaryOrange.withOpacity(0.1),
                ),
                child: Image.asset(
                  'assets/images/logo.png', // Using the logo from your login screen
                  width: 80,
                  height: 80,
                ),
              ),
            ),
            const SizedBox(height: 20),
            Center(
              child: Text(
                'TuneWave',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: textDark,
                ),
              ),
            ),
            Center(
              child: Text(
                'Version 2.0',
                style: theme.textTheme.titleMedium?.copyWith(color: textLight),
              ),
            ),
            const SizedBox(height: 30),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Text(
                'This is a music streaming application built with Flutter, designed to provide a seamless and beautiful listening experience.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyLarge?.copyWith(color: textLight),
              ),
            ),
            const SizedBox(height: 30),
            const Divider(),
             ListTile(
              leading: Icon(Icons.person_pin, color: iconColor),
              title: Text(
                'Credits',
                style: TextStyle(color: textDark),
              ),
              subtitle: Text(
                'Mohit Javle & Mayank Mithapara',
                style: TextStyle(color: textLight, fontWeight: FontWeight.bold),
              ),
            ),
            ListTile(
              leading: Icon(Icons.description_outlined, color: iconColor),
              title: Text(
                'Open Source Licenses',
                style: TextStyle(color: textDark),
              ),
              subtitle: Text(
                'View licenses for third-party software',
                style: TextStyle(color: textLight),
              ),
              onTap: () {
                showLicensePage(
                  context: context,
                  applicationName: 'Music App',
                  applicationVersion: '2.0',
                  applicationIcon: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Image.asset('assets/images/logo.png', width: 48),
                  ),
                );
              },
            ),
            ListTile(
              leading: Icon(Icons.code, color: iconColor),
              title: Text(
                'Developed with Flutter',
                style: TextStyle(color: textDark),
              ),
              subtitle: Text(
                'Google\'s UI toolkit for beautiful apps',
                style: TextStyle(color: textLight),
              ),
              onTap: null,
            ),
            const SizedBox(height: 40),
            Center(
              child: Text(
                '© 2025 TuneWave',
                style: TextStyle(color: textLight, fontSize: 12),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}
