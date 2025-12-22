import 'package:flutter/material.dart';
import 'ninja_layer_utils.dart';

/// The Brains of the Ninja Layout Engine 🧠
/// Replicates Android's measure pass by calculating exact text dimensions
/// before the Widget tree is built.
class NinjaTextMeasurer {
  
  /// Measures the exact size of a text block given its style and content.
  /// Mimics: Android TextView.measure()
  static Size measureText({
    required String text,
    required Map<String, dynamic> style,
    double maxWidth = double.infinity,
    required BuildContext context,
  }) {
    if (text.isEmpty) return Size.zero;

    final fontSize = NinjaLayerUtils.parseDouble(style['fontSize']) ?? 14.0;
    // Default to Inter if not specified, matching Dashboard
    final fontFamily = style['fontFamily'] as String? ?? 'Inter'; 
    final fontWeight = _parseFontWeight(style['fontWeight']);
    final lineHeight = NinjaLayerUtils.parseDouble(style['lineHeight']) ?? 1.2;

    final textStyle = TextStyle(
      fontFamily: fontFamily, 
      fontSize: fontSize,
      fontWeight: fontWeight,
      height: lineHeight,
    );

    final textSpan = TextSpan(
      text: text,
      style: textStyle,
    );

    final textPainter = TextPainter(
      text: textSpan,
      textDirection: TextDirection.ltr,
      maxLines: style['maxLines'] as int? ?? 1,
    );

    textPainter.layout(
      minWidth: 0,
      maxWidth: maxWidth,
    );

    return textPainter.size;
  }

  /// Calculates the intrinsic size of a button (Pill Shape).
  /// Mimics: Android Button Wrap_Content
  static Size measureButton({
    required String text,
    required Map<String, dynamic> style,
    required BuildContext context,
  }) {
    // 1. Measure the Text Content
    final textSize = measureText(
      text: text,
      style: style, // Button style usually contains text style props
      context: context,
    );

    // 2. Add Padding
    final padding = NinjaLayerUtils.parsePadding(style['padding']) ?? EdgeInsets.zero;
    
    // 3. Calculate Total Size
    return Size(
      textSize.width + padding.horizontal,
      textSize.height + padding.vertical,
    );
  }

  static FontWeight _parseFontWeight(dynamic weight) {
    if (weight == null) return FontWeight.normal;
    final w = weight.toString();
    switch (w) {
      case '100': return FontWeight.w100;
      case '200': return FontWeight.w200;
      case '300': return FontWeight.w300;
      case '400':
      case 'normal': return FontWeight.w400;
      case '500': return FontWeight.w500;
      case '600': return FontWeight.w600;
      case '700': 
      case 'bold': return FontWeight.w700;
      case '800': return FontWeight.w800;
      case '900': return FontWeight.w900;
      default: return FontWeight.normal;
    }
  }
}
