import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeNotifier with ChangeNotifier {
  ThemeMode _themeMode = ThemeMode.light;
  bool _isDiscStyle = true;
  String? _currentUserEmail;

  ThemeMode get getThemeMode => _themeMode;
  bool get isDiscStyle => _isDiscStyle;

  Future<void> loadTheme(String userEmail) async {
    _currentUserEmail = userEmail;
    final prefs = await SharedPreferences.getInstance();
    final key = 'theme_$userEmail';
    final themeIndex = prefs.getInt(key);
    
    if (themeIndex != null) {
      _themeMode = ThemeMode.values[themeIndex];
    } else {
      _themeMode = ThemeMode.light; // Default
    }

    final isDisc = prefs.getBool('isDiscStyle_$userEmail');
    if (isDisc != null) {
      _isDiscStyle = isDisc;
    } else {
      _isDiscStyle = true; // Default
    }
    
    notifyListeners();
  }

  void setTheme(ThemeMode themeMode) {
    _themeMode = themeMode;
    notifyListeners();
    _saveSettings();
  }

  void setDiscStyle(bool value) {
    _isDiscStyle = value;
    notifyListeners();
    _saveSettings();
  }

  Future<void> _saveSettings() async {
    if (_currentUserEmail == null) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('theme_$_currentUserEmail', _themeMode.index);
    await prefs.setBool('isDiscStyle_$_currentUserEmail', _isDiscStyle);
  }
}
