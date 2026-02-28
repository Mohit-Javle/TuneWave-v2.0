// services/ui_state_service.dart

import 'package:flutter/material.dart';

/// A service to manage UI state, like the visibility of the mini-player.
/// This uses a ChangeNotifier to notify listeners of state changes.
class UiStateService with ChangeNotifier {
  bool _isMiniPlayerVisible = true;
  bool _isModalActive = false;
  double _miniPlayerPadding = 0.0;

  bool get isMiniPlayerVisible => _isMiniPlayerVisible;
  bool get isModalActive => _isModalActive;
  double get miniPlayerPadding => _miniPlayerPadding;

  void setModalActive(bool active) {
    if (_isModalActive != active) {
      _isModalActive = active;
      notifyListeners();
    }
  }

  void setMiniPlayerPadding(double padding) {
    if (_miniPlayerPadding != padding) {
      _miniPlayerPadding = padding;
      notifyListeners();
    }
  }

  /// Hides the mini-player and notifies listeners.
  void hideMiniPlayer() {
    if (_isMiniPlayerVisible) {
      _isMiniPlayerVisible = false;
      notifyListeners();
    }
  }

  /// Shows the mini-player and notifies listeners.
  void showMiniPlayer() {
    if (!_isMiniPlayerVisible) {
      _isMiniPlayerVisible = true;
      notifyListeners();
    }
  }
}
