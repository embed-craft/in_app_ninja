import 'package:flutter/material.dart';
import '../app_ninja.dart';

/// Auto NavigatorObserver for InAppNinja SDK
///
/// Automatically tracks screen views when routes change
/// Add to MaterialApp.navigatorObservers for auto-tracking
///
/// Example:
/// ```dart
/// MaterialApp(
///   navigatorObservers: [NinjaAutoObserver()],
/// )
/// ```
class NinjaAutoObserver extends NavigatorObserver {
  @override
  void didPush(Route route, Route? previousRoute) {
    super.didPush(route, previousRoute);
    _trackScreenView(route);
  }

  @override
  void didPop(Route route, Route? previousRoute) {
    super.didPop(route, previousRoute);
    if (previousRoute != null) {
      _trackScreenView(previousRoute);
    }
  }

  @override
  void didReplace({Route? newRoute, Route? oldRoute}) {
    super.didReplace(newRoute: newRoute, oldRoute: oldRoute);
    if (newRoute != null) {
      _trackScreenView(newRoute);
    }
  }

  void _trackScreenView(Route route) {
    final screenName = route.settings.name ??
        route.runtimeType.toString().replaceAll('MaterialPageRoute', '');

    if (screenName.isEmpty || screenName == 'null') return;

    // Auto-track screen view event
    AppNinja.track(
      '${screenName}_Viewed',
      properties: {
        'screen_name': screenName,
        'timestamp': DateTime.now().toIso8601String(),
        'auto_tracked': true,
      },
    );

    print('📱 Auto-tracked: ${screenName}_Viewed');

    // Auto-fetch campaigns on screen view
    AppNinja.autoFetchCampaigns();
  }
}
