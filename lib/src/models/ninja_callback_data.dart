/// NinjaCallbackData - Data model for callback events
///
/// This class represents the data passed to callback listeners when
/// SDK events occur. It contains:
/// - [type] - Event category ('CORE' or 'UI')
/// - [action] - Specific action name (e.g., 'NINJA_INITIALISED')
/// - [method] - Method or source that triggered the event
/// - [data] - Map containing event-specific data
class NinjaCallbackData {
  /// Event category: 'CORE' for SDK lifecycle events, 'UI' for user interactions
  final String type;

  /// Specific action associated with the event
  final String action;

  /// Method or source that triggered the event
  final String method;

  /// Payload containing event-specific data
  final Map<String, dynamic> data;

  NinjaCallbackData({
    required this.type,
    required this.action,
    this.method = '',
    this.data = const {},
  });

  /// Create from JSON map
  factory NinjaCallbackData.fromJson(Map<String, dynamic> json) {
    return NinjaCallbackData(
      type: json['type'] as String? ?? 'CORE',
      action: json['action'] as String? ?? '',
      method: json['method'] as String? ?? '',
      data: json['data'] as Map<String, dynamic>? ?? {},
    );
  }

  /// Convert to JSON map
  Map<String, dynamic> toJson() {
    return {
      'type': type,
      'action': action,
      'method': method,
      'data': data,
    };
  }

  @override
  String toString() {
    return 'NinjaCallbackData(type: $type, action: $action, method: $method, data: $data)';
  }
}

// ============================================================================
// CORE CALLBACK ACTIONS
// ============================================================================

/// SDK successfully initialized
const String NINJA_INITIALISED = 'NINJA_INITIALISED';

/// User identification succeeded
const String NINJA_USER_IDENTIFIER_SUCCESS = 'NINJA_USER_IDENTIFIER_SUCCESS';

/// User identification failed
const String NINJA_USER_IDENTIFIER_FAILURE = 'NINJA_USER_IDENTIFIER_FAILURE';

/// Event tracking completed
const String NINJA_TRACK_EVENT = 'NINJA_TRACK_EVENT';

/// Reward received from campaign
const String NINJA_REWARD_RECEIVED = 'NINJA_REWARD_RECEIVED';

// ============================================================================
// UI CALLBACK ACTIONS
// ============================================================================

/// Experience/Campaign became visible to user
const String NINJA_EXPERIENCE_OPEN = 'NINJA_EXPERIENCE_OPEN';

/// Experience/Campaign was dismissed
const String NINJA_EXPERIENCE_DISMISS = 'NINJA_EXPERIENCE_DISMISS';

/// User clicked on a widget/component CTA
const String NINJA_COMPONENT_CTA_CLICK = 'NINJA_COMPONENT_CTA_CLICK';

/// Floater was expanded
const String NINJA_FLOATER_EXPANDED = 'NINJA_FLOATER_EXPANDED';

/// Scratch card was scratched
const String NINJA_SCRATCH_CARD_SCRATCHED = 'NINJA_SCRATCH_CARD_SCRATCHED';

/// Scratch card was fully revealed
const String NINJA_SCRATCH_CARD_REVEALED = 'NINJA_SCRATCH_CARD_REVEALED';
