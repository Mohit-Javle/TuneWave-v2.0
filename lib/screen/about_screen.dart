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
    final textLight = theme.colorScheme.onSurface.withValues(alpha: 0.7);
    final cardColor = theme.colorScheme.surface.withValues(alpha: 0.5);

    return Scaffold(
      appBar: AppBar(
        title: const Text('About TuneWave', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
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
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20),
          children: [
            const SizedBox(height: 20),
            Center(
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: primaryOrange.withValues(alpha: 0.1),
                  boxShadow: [
                    BoxShadow(
                      color: primaryOrange.withValues(alpha: 0.2),
                      blurRadius: 30,
                      spreadRadius: 2,
                    )
                  ],
                ),
                child: Image.asset(
                  'assets/images/logo.png',
                  width: 100,
                  height: 100,
                ),
              ),
            ),
            const SizedBox(height: 32),
            Center(
              child: Text(
                'TuneWave',
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w900,
                  color: textDark,
                  letterSpacing: 1.2,
                ),
              ),
            ),
            Center(
              child: Text(
                'Version 0.3 (v2.0 UI)',
                style: theme.textTheme.titleMedium?.copyWith(color: textLight, letterSpacing: 0.5),
              ),
            ),
            const SizedBox(height: 48),
            
            // Creators Card - Premium Look
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: cardColor,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: primaryOrange.withValues(alpha: 0.3), width: 1),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 24,
                        height: 1.5,
                        decoration: BoxDecoration(
                          color: primaryOrange.withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(1),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'DEVELOPED BY',
                        style: TextStyle(
                          color: primaryOrange,
                          fontWeight: FontWeight.w900,
                          fontSize: 12,
                          letterSpacing: 2.5,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Container(
                        width: 24,
                        height: 1.5,
                        decoration: BoxDecoration(
                          color: primaryOrange.withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(1),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Mohit Javle',
                    style: TextStyle(
                      color: textDark,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '&',
                    style: TextStyle(
                      color: textLight,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Mayank Mithapara',
                    style: TextStyle(
                      color: textDark,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 40),
            Text(
              'LEGAL & CREDITS',
              style: TextStyle(
                color: textLight,
                fontWeight: FontWeight.bold,
                fontSize: 12,
                letterSpacing: 1.5,
              ),
            ),
            const SizedBox(height: 16),
            
            _buildAboutTile(
              context,
              icon: Icons.description_outlined,
              title: 'Open Source Licenses',
              subtitle: 'Third-party software credits',
              onTap: () {
                showLicensePage(
                  context: context,
                  applicationName: 'TuneWave',
                  applicationVersion: '2.0',
                  applicationIcon: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Image.asset('assets/images/logo.png', width: 64),
                  ),
                );
              },
            ),
            _buildAboutTile(
              context,
              icon: Icons.code_rounded,
              title: 'Built with Flutter',
              subtitle: 'Modern cross-platform toolkit',
            ),
            
            const SizedBox(height: 60),
            Center(
              child: Text(
                '© 2025 TuneWave Studio',
                style: TextStyle(color: textLight, fontSize: 13, fontWeight: FontWeight.w500),
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildAboutTile(BuildContext context, {required IconData icon, required String title, String? subtitle, VoidCallback? onTap}) {
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(16),
      ),
      child: ListTile(
        leading: Icon(icon, color: theme.colorScheme.onSurface.withValues(alpha: 0.6)),
        title: Text(title, style: TextStyle(color: theme.colorScheme.onSurface, fontWeight: FontWeight.w600)),
        subtitle: subtitle != null ? Text(subtitle, style: TextStyle(color: theme.colorScheme.onSurface.withValues(alpha: 0.5), fontSize: 13)) : null,
        trailing: onTap != null ? const Icon(Icons.arrow_forward_ios, size: 14) : null,
        onTap: onTap,
      ),
    );
  }
}

