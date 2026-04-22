// services/ui_state_service.dart

import 'package:flutter/material.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'dart:async';

/// A service to manage UI state, like the visibility of the mini-player.
/// This uses a ChangeNotifier to notify listeners of state changes.
class UiStateService with ChangeNotifier {
  UiStateService() {
    _initConnectivity();
  }

  Future<void> _initConnectivity() async {
    final connectivity = Connectivity();
    
    // Check initial state
    final results = await connectivity.checkConnectivity();
    _updateOfflineStatus(results);

    // Listen for changes
    _connectivitySubscription = connectivity.onConnectivityChanged.listen(_updateOfflineStatus);
  }

  void _updateOfflineStatus(List<ConnectivityResult> results) {
    // We are offline if none of the results are wifi, mobile, or ethernet
    final bool offline = results.every((r) => r == ConnectivityResult.none);
    if (_isOffline != offline) {
      _isOffline = offline;
      notifyListeners();
    }
  }
  bool _isForcedHidden = true;
  int _activeModalsCount = 0;
  double _miniPlayerPadding = 0.0;
  bool _isGlobalLocked = true; // Started as locked
  bool _isAppInitialized = false;
  int _currentTabIndex = 0;
  bool _isOffline = false;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;

  bool get isOffline => _isOffline;

  bool get isAppInitialized => _isAppInitialized;
  bool get isGlobalLocked => _isGlobalLocked;
  int get currentTabIndex => _currentTabIndex;

  void setTabIndex(int index) {
    if (_currentTabIndex != index) {
      _currentTabIndex = index;
      notifyListeners();
    }
  }

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

  void setAppInitialized(bool value) {
    if (_isAppInitialized != value) {
      _isAppInitialized = value;
      notifyListeners();
    }
  }

  void unlockMiniPlayer() {
    _isGlobalLocked = false;
    _isForcedHidden = false; // Also ensure it's not forced hidden
    notifyListeners();
  }

  void lockMiniPlayer() {
    _isGlobalLocked = true;
    _isForcedHidden = true;
    notifyListeners();
  }
  @override
  void dispose() {
    _connectivitySubscription?.cancel();
    super.dispose();
  }
}
