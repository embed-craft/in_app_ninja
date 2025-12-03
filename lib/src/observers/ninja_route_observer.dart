import 'package:flutter/material.dart';
import '../app_ninja.dart';

typedef NinjaNameExtractor = String? Function(Route route);

String? defaultNameExtractor(Route route) {
  String? name = route.settings.name;
  if (name != null) {
    return name;
  }

  if (route.settings is Page) {
    final page = route.settings as Page;
    if (page.name != null) {
      return page.name;
    }

    final key = page.key;
    if (key != null && key is ValueKey) {
      return key.value.toString();
    }
  }

  return null;
}

/// NinjaRouteObserver - Automatic page tracking for navigation
///
/// Add to your MaterialApp to automatically track page views:
///
/// ```dart
/// MaterialApp(
///   navigatorObservers: [NinjaRouteObserver()],
///   // ...
/// )
/// ```
class NinjaRouteObserver extends NavigatorObserver {
  final NinjaNameExtractor nameExtractor;

  NinjaRouteObserver({this.nameExtractor = defaultNameExtractor});

  @override
  void didPop(Route route, Route? previousRoute) {
    super.didPop(route, previousRoute);
    _trackScreenInternal(previousRoute);
  }

  @override
  void didPush(Route route, Route? previousRoute) {
    super.didPush(route, previousRoute);
    _trackScreenInternal(route);
  }

  @override
  void didReplace({Route? newRoute, Route? oldRoute}) {
    super.didReplace(newRoute: newRoute, oldRoute: oldRoute);
    _trackScreenInternal(newRoute);
  }

  void _trackScreenInternal(Route? route) {
    if (route != null && route is PageRoute) {
      String? name = nameExtractor(route);
      if (name != null) {
        final nameParts = name.split('?');
        final cleanedName = nameParts[0];
        if (route.navigator?.context != null) {
          AppNinja.trackPage(cleanedName, route.navigator!.context);
        }
      }
    }
  }
}
