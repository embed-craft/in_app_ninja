import 'package:flutter/material.dart';
import '../widgets/ninja_tracked_view_new.dart';

/// NinjaTrackerObserver - NavigatorObserver that clears tracked widgets on navigation
///
/// Similar to NudgeTrackerObserver from nudgecore_v2
///
/// **CRITICAL**: This observer must be added to your MaterialApp's navigatorObservers
/// to prevent memory leaks and ensure accurate widget tracking.
///
/// Usage:
/// ```dart
/// MaterialApp(
///   navigatorObservers: [
///     NinjaRouteObserver(),
///     NinjaTrackerObserver(), // Add this!
///   ],
///   ...
/// )
/// ```
///
/// What it does:
/// - Clears all tracked widgets when navigating to a new screen
/// - Prevents tracking widgets from previous screens
/// - Skips dialogs and bottom sheets (they don't change the screen)
/// - Handles: didPush, didPop, didRemove, didReplace
class NinjaTrackerObserver extends NavigatorObserver {
  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPush(route, previousRoute);

    // Don't clear for dialogs or bottom sheets
    if (route is DialogRoute || route is ModalBottomSheetRoute) {
      return;
    }

    NinjaWidgetTracker.clearForCurrentScreen();
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPop(route, previousRoute);

    NinjaWidgetTracker.clearForCurrentScreen();
  }

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didRemove(route, previousRoute);

    NinjaWidgetTracker.clearForCurrentScreen();
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    super.didReplace(newRoute: newRoute, oldRoute: oldRoute);

    NinjaWidgetTracker.clearForCurrentScreen();
  }
}
