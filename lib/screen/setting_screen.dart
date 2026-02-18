// screens/settings_screen.dart
// ignore_for_file: deprecated_member_use

import 'package:clone_mp/services/auth_service.dart';
import 'package:clone_mp/services/playlist_service.dart';
import 'package:clone_mp/services/theme_notifier.dart';
import 'package:flutter/material.dart';
import 'package:clone_mp/route_names.dart';
import 'package:provider/provider.dart';

// ### REMOVE: Enum is no longer needed ###
// enum ThemeOption { light, dark, system }

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _offlineMode = false;
  bool _dataSaver = true;
  bool _pushNotifications = true;

  // ### REMOVE: Local state for theme ###
  // ThemeOption _selectedTheme = ThemeOption.light;

  static const Color primaryOrange = Color(0xFFFF6600);

  // ### REMOVE: Hardcoded text/icon colors, we will use the theme ###
  // static const Color textDark = Colors.black87;
  // static const Color textLight = Colors.black54;
  // static const Color iconColor = Colors.black54;

  @override
  Widget build(BuildContext context) {
    // ### ADD: Access ThemeNotifier ###
    final themeNotifier = Provider.of<ThemeNotifier>(context);
    final theme = Theme.of(context);
    final textDark = theme.colorScheme.onSurface;
    final textLight = theme.colorScheme.onSurface.withOpacity(0.7);
    final iconColor = theme.unselectedWidgetColor;

    return Scaffold(
      appBar: AppBar(
        backgroundColor:
            theme.colorScheme.surface, // ### CHANGE: Use theme color ###
        elevation: 1, // You might want to adjust elevation based on theme
        title: Text(
          'Settings',
          style: TextStyle(color: textDark, fontWeight: FontWeight.bold),
        ),
        iconTheme: IconThemeData(color: textDark),
      ),
      body: Container(
        // ### CHANGE: Use theme gradient ###
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [theme.colorScheme.surface, theme.colorScheme.background],
            stops: const [0.3, 0.7],
          ),
        ),
        child: ListView(
          children: [
            _buildSectionHeader('Account'),
            ListTile(
              leading: Icon(Icons.person_outline, color: iconColor),
              title: Text('Edit Profile', style: TextStyle(color: textDark)),
              onTap: () => Navigator.pushNamed(context, AppRoutes.profile),
            ),
            ListTile(
              leading: Icon(Icons.lock_outline, color: iconColor),
              title: Text('Change Password', style: TextStyle(color: textDark)),
              onTap: () => Navigator.pushNamed(context, AppRoutes.changePassword),

            ),
            ListTile(
              leading: const Icon(Icons.logout, color: Colors.red),
              title: const Text('Logout', style: TextStyle(color: Colors.red)),
              onTap: () async {
                await AuthService.instance.logout();
                if (context.mounted) {
                  Provider.of<PlaylistService>(context, listen: false).clearData();
                  // Reset theme to light or keep? Let's keep as is or reset.
                  // Provider.of<ThemeNotifier>(context, listen: false).setTheme(ThemeMode.light);
                  
                  Navigator.pushNamedAndRemoveUntil(context, AppRoutes.login, (route) => false);
                }
              },
            ),

            _buildSectionHeader('Appearance'),
            RadioListTile<ThemeMode>(
              title: Text('Light Mode', style: TextStyle(color: textDark)),
              value: ThemeMode.light,
              groupValue: themeNotifier.getThemeMode, // ### CHANGE ###
              onChanged: (ThemeMode? value) {
                if (value != null) {
                  themeNotifier.setTheme(value); // ### CHANGE ###
                }
              },
              activeColor: primaryOrange,
              secondary: Icon(Icons.light_mode_outlined, color: iconColor),
            ),
            RadioListTile<ThemeMode>(
              title: Text('Dark Mode', style: TextStyle(color: textDark)),
              value: ThemeMode.dark,
              groupValue: themeNotifier.getThemeMode, // ### CHANGE ###
              onChanged: (ThemeMode? value) {
                if (value != null) {
                  themeNotifier.setTheme(value); // ### CHANGE ###
                }
              },
              activeColor: primaryOrange,
              secondary: Icon(Icons.dark_mode_outlined, color: iconColor),
            ),
            RadioListTile<ThemeMode>(
              title: Text('System Default', style: TextStyle(color: textDark)),
              subtitle: Text(
                'Matches your device\'s theme',
                style: TextStyle(color: textLight),
              ),
              value: ThemeMode.system,
              groupValue: themeNotifier.getThemeMode, // ### CHANGE ###
              onChanged: (ThemeMode? value) {
                if (value != null) {
                  themeNotifier.setTheme(value); // ### CHANGE ###
                }
              },
              activeColor: primaryOrange,
              secondary: Icon(
                Icons.settings_system_daydream_outlined,
                color: iconColor,
              ),
            ),

            _buildSectionHeader('Playback'),
            SwitchListTile(
              title: Text('Offline Mode', style: TextStyle(color: textDark)),
              subtitle: Text(
                'Play downloaded music only',
                style: TextStyle(color: textLight),
              ),
              value: _offlineMode,
              onChanged: (bool value) {
                setState(() {
                  _offlineMode = value;
                });
              },
              activeColor: primaryOrange,
              secondary: Icon(Icons.cloud_off_outlined, color: iconColor),
            ),
            SwitchListTile(
              title: Text('Data Saver', style: TextStyle(color: textDark)),
              subtitle: Text(
                'Reduces audio quality to save data',
                style: TextStyle(color: textLight),
              ),
              value: _dataSaver,
              onChanged: (bool value) {
                setState(() {
                  _dataSaver = value;
                });
              },
              activeColor: primaryOrange,
              secondary: Icon(
                Icons.signal_cellular_alt_outlined,
                color: iconColor,
              ),
            ),
            _buildSectionHeader('Notifications'),
            SwitchListTile(
              title: Text(
                'Push Notifications',
                style: TextStyle(color: textDark),
              ),
              subtitle: Text(
                'For new releases and recommendations',
                style: TextStyle(color: textLight),
              ),
              value: _pushNotifications,
              onChanged: (bool value) {
                setState(() {
                  _pushNotifications = value;
                });
              },
              activeColor: primaryOrange,
              secondary: Icon(
                Icons.notifications_active_outlined,
                color: iconColor,
              ),
            ),
            _buildSectionHeader('About'),
            ListTile(
              leading: Icon(Icons.info_outline, color: iconColor),
              title: Text('About this App', style: TextStyle(color: textDark)),
              onTap: () {},
            ),
            ListTile(
              leading: Icon(Icons.privacy_tip_outlined, color: iconColor),
              title: Text('Privacy Policy', style: TextStyle(color: textDark)),
              onTap: () {},
            ),
          ],
        ),
      ),
    );
  }

  Padding _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16.0, 20.0, 16.0, 8.0),
      child: Text(
        title,
        style: const TextStyle(
          color: primaryOrange,
          fontWeight: FontWeight.bold,
          fontSize: 16,
        ),
      ),
    );
  }
}
