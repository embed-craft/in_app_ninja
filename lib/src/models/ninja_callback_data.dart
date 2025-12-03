/// NinjaCallbackData - Structured callback event data
///
/// Used for handling events from nudges, stories, and other components
class NinjaCallbackData {
  /// Event name
  final String event;

  /// Event type (e.g., 'nudge', 'story', 'survey', 'quiz')
  final String type;

  /// Action performed (e.g., 'cta_click', 'viewed', 'dismissed')
  final String action;

  /// Additional data payload
  final Map<String, dynamic> data;

  NinjaCallbackData(
    this.event, {
    required this.type,
    required this.action,
    required this.data,
  });

  /// Create from JSON
  factory NinjaCallbackData.fromJson(Map<String, dynamic> json) {
    return NinjaCallbackData(
      json['event'] as String? ?? 'ninja_callback',
      type: json['type'] as String? ?? '',
      action: json['action'] as String? ?? '',
      data: (json['data'] as Map<String, dynamic>?) ?? {},
    );
  }

  /// Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'event': event,
      'type': type,
      'action': action,
      'data': data,
    };
  }

  @override
  String toString() {
    return 'NinjaCallbackData(event: $event, type: $type, action: $action, data: $data)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is NinjaCallbackData &&
        other.event == event &&
        other.type == type &&
        other.action == action;
  }

  @override
  int get hashCode => event.hashCode ^ type.hashCode ^ action.hashCode;
}
