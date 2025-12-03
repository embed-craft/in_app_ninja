import 'package:flutter/material.dart';

/// Configuration for nudge rendering (colors, animations, buttons, etc.)
class NudgeConfig {
  final Color? backgroundColor;
  final Color? titleColor;
  final Color? descriptionColor;
  final Color? buttonColor;
  final Color? buttonTextColor;
  final String? imageUrl;
  final String? buttonText;
  final String? ctaUrl;
  final Duration? displayDuration;
  final bool dismissible;
  final Map<String, dynamic>? customData;

  const NudgeConfig({
    this.backgroundColor,
    this.titleColor,
    this.descriptionColor,
    this.buttonColor,
    this.buttonTextColor,
    this.imageUrl,
    this.buttonText,
    this.ctaUrl,
    this.displayDuration,
    this.dismissible = true,
    this.customData,
  });

  factory NudgeConfig.fromJson(Map<String, dynamic> json) {
    return NudgeConfig(
      backgroundColor: _parseColor(
        json['background'] ?? json['backgroundColor'],
      ),
      titleColor: _parseColor(json['titleColor'] ?? json['title_color']),
      descriptionColor: _parseColor(
        json['descriptionColor'] ?? json['description_color'],
      ),
      buttonColor: _parseColor(json['buttonColor'] ?? json['button_color']),
      buttonTextColor: _parseColor(
        json['buttonTextColor'] ?? json['button_text_color'],
      ),
      imageUrl: json['image']?.toString() ?? json['imageUrl']?.toString(),
      buttonText: json['button']?.toString() ??
          json['buttonText']?.toString() ??
          json['cta']?.toString(),
      ctaUrl: json['ctaUrl']?.toString() ?? json['url']?.toString(),
      displayDuration: json['duration'] != null
          ? Duration(milliseconds: json['duration'] as int)
          : null,
      dismissible: json['dismissible'] ?? json['can_dismiss'] ?? true,
      customData: json['customData'] != null
          ? Map<String, dynamic>.from(json['customData'])
          : null,
    );
  }

  static Color? _parseColor(dynamic value) {
    if (value == null) return null;
    if (value is Color) return value;
    String colorString = value.toString();
    if (colorString.startsWith('#')) {
      colorString = colorString.substring(1);
      if (colorString.length == 6) {
        colorString = 'FF$colorString';
      }
      return Color(int.parse(colorString, radix: 16));
    }
    return null;
  }

  Map<String, dynamic> toJson() {
    return {
      'backgroundColor': backgroundColor?.toString(),
      'titleColor': titleColor?.toString(),
      'descriptionColor': descriptionColor?.toString(),
      'buttonColor': buttonColor?.toString(),
      'buttonTextColor': buttonTextColor?.toString(),
      'imageUrl': imageUrl,
      'buttonText': buttonText,
      'ctaUrl': ctaUrl,
      'duration': displayDuration?.inMilliseconds,
      'dismissible': dismissible,
      'customData': customData,
    };
  }
}
