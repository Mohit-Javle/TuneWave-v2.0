// services/ui_state_service.dart

import 'package:flutter/material.dart';

/// A service to manage UI state, like the visibility of the mini-player.
/// This uses a ChangeNotifier to notify listeners of state changes.
class UiStateService with ChangeNotifier {
  bool _isMiniPlayerVisible = true;

  bool get isMiniPlayerVisible => _isMiniPlayerVisible;

  /// Hides the mini-player and notifies listeners.
  void hideMiniPlayer() {
    _isMiniPlayerVisible = false;
    notifyListeners();
  }

  /// Shows the mini-player and notifies listeners.
  void showMiniPlayer() {
    _isMiniPlayerVisible = true;
    notifyListeners();
  }
}
