import 'package:flutter/material.dart';

class AppRouteObserver extends NavigatorObserver {
  final ValueNotifier<String?> currentRouteNotifier = ValueNotifier(null);

  String? get currentRoute => currentRouteNotifier.value;

  void _updateRoute(Route<dynamic>? route) {
    if (route is PageRoute && route.settings.name != null) {
      currentRouteNotifier.value = route.settings.name;
    }
  }

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPush(route, previousRoute);
    _updateRoute(route);
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPop(route, previousRoute);
    if (previousRoute != null) {
      _updateRoute(previousRoute);
    }
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    super.didReplace(newRoute: newRoute, oldRoute: oldRoute);
    if (newRoute != null) {
      _updateRoute(newRoute);
    }
  }

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didRemove(route, previousRoute);
    if (previousRoute != null) {
      _updateRoute(previousRoute);
    }
  }
}

final appRouteObserver = AppRouteObserver();
