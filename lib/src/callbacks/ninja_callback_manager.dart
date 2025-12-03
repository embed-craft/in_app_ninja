import 'package:flutter/foundation.dart';
import '../models/ninja_callback_data.dart';
import '../app_ninja.dart';

/// Abstract listener interface for Ninja callbacks
abstract class NinjaCallbackListener {
  /// Called when an event is dispatched
  void onEvent(NinjaCallbackData event);
}

/// Manages callback listeners and event dispatching
///
/// Provides a centralized event system for handling all ninja events
class NinjaCallbackManager {
  static final Set<NinjaCallbackListener> _listeners = {};

  /// Register a callback listener
  static void registerListener(NinjaCallbackListener listener) {
    String listenerType = listener.runtimeType.toString();
    AppNinja.debugLog('Registering listener: $listenerType');
    _listeners.add(listener);
  }

  /// Unregister a callback listener
  static void unregisterListener(NinjaCallbackListener listener) {
    _listeners.remove(listener);
    AppNinja.debugLog(
        'Unregistered listener: ${listener.runtimeType.toString()}');
  }

  /// Dispatch an event to all registered listeners
  static void dispatchEvent(NinjaCallbackData event) {
    try {
      AppNinja.debugLog('Dispatching event: ${event.toString()}');

      // Handle special actions
      _handleSpecialActions(event);

      // Notify all listeners
      for (var listener in _listeners) {
        try {
          listener.onEvent(event);
        } catch (e) {
          debugPrint('Error in listener ${listener.runtimeType}: $e');
        }
      }
    } catch (e) {
      debugPrint('NinjaCallbackManager error: $e');
    }
  }

  /// Handle special built-in actions
  static void _handleSpecialActions(NinjaCallbackData event) {
    // Handle CTA clicks with deep links
    if (event.action == 'cta_click' ||
        event.action == 'NUDGE_COMPONENT_CTA_CLICK') {
      final target = event.data['TARGET'] ?? event.data['target'];
      final clickType = event.data['CLICK_TYPE'] ?? event.data['click_type'];

      if (target != null && clickType == 'DEEP_LINK') {
        AppNinja.debugLog('CTA clicked with deep link: $target');
        _launchDeepLink(target.toString());
      }
    }

    // Handle internal errors
    if (event.action == 'INTERNAL_ERROR') {
      debugPrint('Ninja internal error: ${event.data}');
      AppNinja.setShouldDisableNinja(true);
    }

    // Track the event
    AppNinja.track(event.event, properties: {
      'type': event.type,
      'action': event.action,
      ...event.data,
    });
  }

  /// Launch deep link URL
  static void _launchDeepLink(String url) {
    try {
      // Use redirect listener if available
      AppNinja.triggerRedirect({'url': url, 'target': url});

      // In a real app, integrate url_launcher:
      // await launchUrl(Uri.parse(url));
      AppNinja.debugLog('Deep link triggered: $url');
    } catch (e) {
      debugPrint('Error launching deep link: $e');
    }
  }

  /// Clear all listeners
  static void clearAllListeners() {
    _listeners.clear();
    AppNinja.debugLog('All listeners cleared');
  }

  /// Get number of registered listeners
  static int get listenerCount => _listeners.length;
}
