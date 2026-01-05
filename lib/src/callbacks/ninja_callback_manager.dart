import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/ninja_callback_data.dart';
import 'ninja_callbacks.dart';

/// NinjaCallbackManager - Central manager for SDK event callbacks
///
/// Use this class to register/unregister listeners that will receive
/// callback events from the Ninja SDK.
///
/// Example:
/// ```dart
/// // Register listener
/// NinjaCallbackManager.registerListener(this);
///
/// // Unregister when done
/// NinjaCallbackManager.unregisterListener(this);
/// ```
class NinjaCallbackManager {
  // Private constructor to prevent instantiation
  NinjaCallbackManager._();

  // List of registered listeners
  static final List<NinjaCallbackListener> _listeners = [];
  
  // Stream controller for events (Modern approach)
  static final StreamController<NinjaCallbackData> _eventController = 
      StreamController<NinjaCallbackData>.broadcast();

  /// Stream of all SDK events
  /// 
  /// Listen to this stream for a modern, reactive way to handle callbacks.
  /// ```dart
  /// NinjaCallbackManager.onEvent.listen((event) {
  ///   print(event.action);
  /// });
  /// ```
  static Stream<NinjaCallbackData> get onEvent => _eventController.stream;

  /// Register a callback listener
  ///
  /// [listener] - Object implementing NinjaCallbackListener interface
  static void registerListener(NinjaCallbackListener listener) {
    if (!_listeners.contains(listener)) {
      _listeners.add(listener);
      debugPrint('🔔 NinjaCallbackManager: Listener registered (${_listeners.length} total)');
    }
  }

  /// Unregister a callback listener
  ///
  /// [listener] - Previously registered listener to remove
  static void unregisterListener(NinjaCallbackListener listener) {
    if (_listeners.remove(listener)) {
      debugPrint('🔕 NinjaCallbackManager: Listener unregistered (${_listeners.length} remaining)');
    }
  }

  /// Clear all registered listeners
  static void clearAllListeners() {
    _listeners.clear();
    debugPrint('🧹 NinjaCallbackManager: All listeners cleared');
  }

  /// Get the count of registered listeners
  static int get listenerCount => _listeners.length;

  /// Dispatch an event to all registered listeners
  ///
  /// This method is called internally by the SDK to notify listeners
  /// of various events (initialization, user identification, UI interactions, etc.)
  static void dispatchEvent(NinjaCallbackData event) {
    debugPrint('📢 NinjaCallbackManager: Dispatching ${event.action} to ${_listeners.length} listener(s)');
    
    // 1. Dispatch to Listeners
    for (final listener in _listeners.toList()) {
      try {
        listener.onEvent(event);
      } catch (e) {
        debugPrint('⚠️ NinjaCallbackManager: Error in listener callback: $e');
      }
    }

    // 2. Dispatch to Stream
    _eventController.add(event);
  }

  // ============================================================================
  // CONVENIENCE METHODS FOR DISPATCHING SPECIFIC EVENTS
  // ============================================================================

  /// Dispatch SDK initialization success event
  static void dispatchInitialised({String? sdkVersion}) {
    dispatchEvent(NinjaCallbackData(
      type: 'CORE',
      action: NINJA_INITIALISED,
      method: 'init',
      data: {'sdk_version': sdkVersion ?? 'unknown'},
    ));
  }

  /// Dispatch user identification success event
  static void dispatchUserIdentifierSuccess(Map<String, dynamic> userDetails) {
    dispatchEvent(NinjaCallbackData(
      type: 'CORE',
      action: NINJA_USER_IDENTIFIER_SUCCESS,
      method: 'identify',
      data: {'user_details': userDetails},
    ));
  }

  /// Dispatch user identification failure event
  static void dispatchUserIdentifierFailure(String error) {
    dispatchEvent(NinjaCallbackData(
      type: 'CORE',
      action: NINJA_USER_IDENTIFIER_FAILURE,
      method: 'identify',
      data: {'error': error},
    ));
  }

  /// Dispatch track event success
  static void dispatchTrackEvent(String eventName, Map<String, dynamic> properties) {
    dispatchEvent(NinjaCallbackData(
      type: 'CORE',
      action: NINJA_TRACK_EVENT,
      method: 'track',
      data: {'event': eventName, 'properties': properties},
    ));
  }

  /// Dispatch reward received event
  static void dispatchRewardReceived(List<Map<String, dynamic>> rewards) {
    dispatchEvent(NinjaCallbackData(
      type: 'CORE',
      action: NINJA_REWARD_RECEIVED,
      method: 'reward',
      data: {'rewards': rewards},
    ));
  }

  /// Dispatch experience opened event (UI)
  static void dispatchExperienceOpen({
    required String campaignId,
    required String displayType,
    Map<String, dynamic>? additionalData,
  }) {
    dispatchEvent(NinjaCallbackData(
      type: 'UI',
      action: NINJA_EXPERIENCE_OPEN,
      method: 'render',
      data: {
        'CAMPAIGN_ID': campaignId,
        'DISPLAY_TYPE': displayType,
        ...?additionalData,
      },
    ));
  }

  /// Dispatch experience dismissed event (UI)
  static void dispatchExperienceDismiss({
    required String campaignId,
    required String displayType,
    String? dismissMethod,
    Map<String, dynamic>? additionalData,
  }) {
    dispatchEvent(NinjaCallbackData(
      type: 'UI',
      action: NINJA_EXPERIENCE_DISMISS,
      method: dismissMethod ?? 'dismiss',
      data: {
        'CAMPAIGN_ID': campaignId,
        'DISPLAY_TYPE': displayType,
        ...?additionalData,
      },
    ));
  }

  /// Dispatch component CTA click event (UI)
  static void dispatchComponentCtaClick({
    required String campaignId,
    required String widgetId,
    required String clickType,
    String? target,
    Map<String, dynamic>? additionalData,
  }) {
    dispatchEvent(NinjaCallbackData(
      type: 'UI',
      action: NINJA_COMPONENT_CTA_CLICK,
      method: 'click',
      data: {
        'CAMPAIGN_ID': campaignId,
        'WIDGET_ID': widgetId,
        'CLICK_TYPE': clickType,
        if (target != null) 'TARGET': target,
        ...?additionalData,
      },
    ));
  }

  /// Dispatch floater expanded event (UI)
  static void dispatchFloaterExpanded({
    required String campaignId,
    required String displayId,
    Map<String, dynamic>? additionalData,
  }) {
    dispatchEvent(NinjaCallbackData(
      type: 'UI',
      action: NINJA_FLOATER_EXPANDED,
      method: 'expand',
      data: {
        'CAMPAIGN_ID': campaignId,
        'DISPLAY_ID': displayId,
        ...?additionalData,
      },
    ));
  }

  /// Dispatch scratch card scratched event (UI)
  static void dispatchScratchCardScratched({
    required String campaignId,
    required double percentScratched,
    Map<String, dynamic>? additionalData,
  }) {
    dispatchEvent(NinjaCallbackData(
      type: 'UI',
      action: NINJA_SCRATCH_CARD_SCRATCHED,
      method: 'scratch',
      data: {
        'CAMPAIGN_ID': campaignId,
        'PERCENT_SCRATCHED': percentScratched,
        ...?additionalData,
      },
    ));
  }

  /// Dispatch scratch card revealed event (UI)
  static void dispatchScratchCardRevealed({
    required String campaignId,
    Map<String, dynamic>? additionalData,
  }) {
    dispatchEvent(NinjaCallbackData(
      type: 'UI',
      action: NINJA_SCRATCH_CARD_REVEALED,
      method: 'reveal',
      data: {
        'CAMPAIGN_ID': campaignId,
        ...?additionalData,
      },
    ));
  }
}
