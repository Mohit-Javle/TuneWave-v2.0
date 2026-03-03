// services/ui_state_service.dart

import 'package:flutter/material.dart';

/// A service to manage UI state, like the visibility of the mini-player.
/// This uses a ChangeNotifier to notify listeners of state changes.
class UiStateService with ChangeNotifier {
  bool _isForcedHidden = false;
  int _activeModalsCount = 0;
  double _miniPlayerPadding = 0.0;

  bool get isMiniPlayerVisible => !_isForcedHidden && _activeModalsCount == 0;
  bool get isModalActive => _activeModalsCount > 0;
  double get miniPlayerPadding => _miniPlayerPadding;

  void setModalActive(bool active) {
    if (active) {
      _activeModalsCount++;
    } else {
      if (_activeModalsCount > 0) _activeModalsCount--;
    }
    notifyListeners();
  }

  void setMiniPlayerPadding(double padding) {
    if (_miniPlayerPadding != padding) {
      _miniPlayerPadding = padding;
      notifyListeners();
    }
  }

  /// Hides the mini-player and notifies listeners (used for drawer).
  void hideMiniPlayer() {
    if (!_isForcedHidden) {
      _isForcedHidden = true;
      notifyListeners();
    }
  }

  /// Shows the mini-player and notifies listeners (used for drawer).
  void showMiniPlayer() {
    if (_isForcedHidden) {
      _isForcedHidden = false;
      notifyListeners();
    }
  }
}
