import 'package:flutter/material.dart';

/// Widget details model for tracking widget information
///
/// Contains information about a tracked widget including its position, size, and visibility
class NinjaWidgetDetails {
  /// Unique widget label/key
  final String label;

  /// Widget's global key
  final GlobalKey? key;

  /// X position on screen
  final double? x;

  /// Y position on screen
  final double? y;

  /// Widget width
  final double? width;

  /// Widget height
  final double? height;

  /// Visibility percentage (0.0 to 1.0)
  final double? visibilityFraction;

  /// Whether widget is currently visible
  final bool isVisible;

  /// Additional metadata
  final Map<String, dynamic>? metadata;

  /// Last updated timestamp
  final DateTime lastUpdated;

  NinjaWidgetDetails({
    required this.label,
    this.key,
    this.x,
    this.y,
    this.width,
    this.height,
    this.visibilityFraction,
    this.isVisible = false,
    this.metadata,
    DateTime? lastUpdated,
  }) : lastUpdated = lastUpdated ?? DateTime.now();

  /// Get position as Offset
  Offset? get position => (x != null && y != null) ? Offset(x!, y!) : null;

  /// Get size as Size
  Size? get size =>
      (width != null && height != null) ? Size(width!, height!) : null;

  /// Get bounding rectangle
  Rect? get rect {
    if (x != null && y != null && width != null && height != null) {
      return Rect.fromLTWH(x!, y!, width!, height!);
    }
    return null;
  }

  /// Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'label': label,
      if (x != null) 'x': x,
      if (y != null) 'y': y,
      if (width != null) 'width': width,
      if (height != null) 'height': height,
      if (visibilityFraction != null) 'visibility_fraction': visibilityFraction,
      'is_visible': isVisible,
      if (metadata != null) 'metadata': metadata,
      'last_updated': lastUpdated.toIso8601String(),
    };
  }

  /// Create from JSON
  factory NinjaWidgetDetails.fromJson(Map<String, dynamic> json) {
    return NinjaWidgetDetails(
      label: json['label'] as String,
      x: json['x'] as double?,
      y: json['y'] as double?,
      width: json['width'] as double?,
      height: json['height'] as double?,
      visibilityFraction: json['visibility_fraction'] as double?,
      isVisible: json['is_visible'] as bool? ?? false,
      metadata: json['metadata'] as Map<String, dynamic>?,
      lastUpdated: json['last_updated'] != null
          ? DateTime.parse(json['last_updated'])
          : null,
    );
  }

  /// Create a copy with updated fields
  NinjaWidgetDetails copyWith({
    String? label,
    GlobalKey? key,
    double? x,
    double? y,
    double? width,
    double? height,
    double? visibilityFraction,
    bool? isVisible,
    Map<String, dynamic>? metadata,
    DateTime? lastUpdated,
  }) {
    return NinjaWidgetDetails(
      label: label ?? this.label,
      key: key ?? this.key,
      x: x ?? this.x,
      y: y ?? this.y,
      width: width ?? this.width,
      height: height ?? this.height,
      visibilityFraction: visibilityFraction ?? this.visibilityFraction,
      isVisible: isVisible ?? this.isVisible,
      metadata: metadata ?? this.metadata,
      lastUpdated: lastUpdated ?? this.lastUpdated,
    );
  }

  @override
  String toString() {
    return 'NinjaWidgetDetails(label: $label, position: ($x, $y), size: ($width, $height), visible: $isVisible)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is NinjaWidgetDetails && other.label == label;
  }

  @override
  int get hashCode => label.hashCode;
}
