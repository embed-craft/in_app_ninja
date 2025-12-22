import 'package:flutter/material.dart';

class NinjaLayerUtils {
  // Reference design width (Precision Tuned)
  // Adjusted to 290.0 based on feedback "Button 10px above".
  // This forces vertical offsets to scale aggressively (1.4x), clearing the aspect-ratio zoomed image.
  static const double kDesignWidth = 290.0;

  static double? parseDouble(dynamic value, [BuildContext? context]) {
    if (value == null) return null;
    double? result;
    
    if (value is num) {
       result = value.toDouble();
    } else if (value is String) {
       // Percentage check
       if (value.trim().endsWith('%')) return null;
       // Parse Px / Number
       result = double.tryParse(value.replaceAll('px', ''));
    }

    // Dynamic Density: RE-ENABLED for Layout Sync.
    // Dashboard (375px) vs Device (e.g. 400px). 
    // Images scale with width (Aspect Ratio). Fixed coords MUST scale too used to prevent overlap.
    if (context != null && result != null) {
       double screenWidth = MediaQuery.of(context).size.width;
       // Limit scaling to reasonable bounds (e.g. Tablet shouldn't explode buttons)
       // But for mobile parity, linear scaling is desired.
       return result * (screenWidth / kDesignWidth);
    }
    
    return result;
  }

  static double? parseSize(dynamic value, [BuildContext? context]) {
    if (value == 'auto' || value == null) return null;
    return parseDouble(value, context);
  }

  /// Solves the required container height to fit all layers.
  /// Handles both fixed pixels (Top + Height) and percentages (Top / (1 - Pct)).
  static double solveRequiredHeight(List<dynamic> layers) {
    double maxH = 0.0;
    
    for (var layer in layers) {
      if (layer is! Map<String, dynamic>) continue;
      
      final style = layer['style'] as Map<String, dynamic>? ?? {};
      // Skip non-absolute (flow) layers for this calculation, or assume flow adds to height separately?
      // For now focusing on absolute layers which caused the collapse.
      if (style['position'] != 'absolute') continue;

      final top = parseDouble(style['top']) ?? 0;
      final hVal = style['height'];

      if (hVal is String && hVal.trim().endsWith('%')) {
        // Percentage Case: P = Top / (1 - Pct)
        try {
          final pct = double.parse(hVal.replaceAll('%', '')) / 100.0;
          if (pct < 1.0) {
             final req = top / (1.0 - pct);
             if (req > maxH) maxH = req;
          }
        } catch (_) {}
      } else {
        // Pixel Case: P = Top + Height
        final h = parseSize(hVal) ?? 0;
        if (top + h > maxH) maxH = top + h;
      }
    }
    
    return maxH;
  }

  /// Parses a size value, handling px (10px) and % (50%) values.
  /// For percentages, [context] and [isVertical] are required to resolve against viewport.
  /// [constraints] can be provided to resolve % against the parent container instead of screen.
  static double? parseResponsiveSize(dynamic value, BuildContext context, {bool isVertical = false, BoxConstraints? constraints, Size? parentSize}) {
     if (value == null) return null;
     
     if (value is String && value.trim().endsWith('%')) {
        try {
          final pct = double.parse(value.replaceAll('%', '')) / 100.0;
          
          // 0. Priority: Explicit Parent Size (passed from Container)
          // This ensures % is relative to the Nudge Container, not Screen/Constraints
          if (parentSize != null) {
             return isVertical ? parentSize.height * pct : parentSize.width * pct;
          }

          // 1. Try resolving against Parent Constraints (LayoutBuilder)
          if (constraints != null) {
            if (isVertical && constraints.hasBoundedHeight) {
                return constraints.maxHeight * pct;
            }
            if (!isVertical && constraints.hasBoundedWidth) {
                return constraints.maxWidth * pct;
            }
          }

          // 2. Fallback to Screen Size (MediaQuery)
          final screenSize = MediaQuery.of(context).size;
          final total = isVertical ? screenSize.height : screenSize.width;
          return total * pct;
        } catch (_) {
          return null;
        }
     }
     
     return parseSize(value);
  }

  static Color? parseColor(dynamic value) {
    if (value == null || value is! String) return null;
    if (value.isEmpty) return null;
    
    // Check for named colors or transparent
    if (value == 'transparent') return Colors.transparent;

    try {
      var hex = value.replaceAll('#', '');
      if (hex.length == 6) {
        hex = 'FF$hex';
      }
      return Color(int.parse(hex, radix: 16));
    } catch (_) {
      return null;
    }
  }

  static FontWeight parseFontWeight(dynamic value) {
    switch (value?.toString()) {
      case 'bold': return FontWeight.bold;
      case 'semibold': return FontWeight.w600;
      case 'medium': return FontWeight.w500;
      case 'normal': 
      default: return FontWeight.normal;
    }
  }

  static EdgeInsets? parsePadding(dynamic value, [BuildContext? context]) {
    // 1. Explicit Map: {top: 10, right: 0...}
    if (value is Map) {
      return EdgeInsets.only(
        top: parseDouble(value['top'], context) ?? 0,
        right: parseDouble(value['right'], context) ?? 0,
        bottom: parseDouble(value['bottom'], context) ?? 0,
        left: parseDouble(value['left'], context) ?? 0,
      );
    }
    
    // 2. Shorthand: 20 or "20px" (Uniform Padding)
    if (value != null) {
       final uniform = parseDouble(value, context);
       if (uniform != null && uniform > 0) {
          return EdgeInsets.all(uniform);
       }
    }

    return null;
  }

  static List<BoxShadow>? parseShadows(dynamic value) {
    if (value == null || value is! String) return null;
    if (value.isEmpty) return null;
    
    // Basic parser for "0 2px 8px rgba(0,0,0,0.1)"
    // This is complex to parse perfectly without a CSS parser. 
    // We can map specific known presets from the dashboard to Flutter shadows.
    
    if (value.contains('rgba(0,0,0,0.1)')) { // Soft
       return [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 8, offset: const Offset(0, 2))]; 
    }
    if (value.contains('rgba(0,0,0,0.25)')) { // Hard
       return [BoxShadow(color: Colors.black.withOpacity(0.25), blurRadius: 24, offset: const Offset(0, 8))]; 
    }

    return null;
  }

  static BoxFit parseBoxFit(dynamic value) {
    switch (value?.toString()) {
      case 'contain': return BoxFit.contain;
      case 'fill': return BoxFit.fill;
      case 'fitWidth': return BoxFit.fitWidth;
      case 'fitHeight': return BoxFit.fitHeight;
      case 'cover': 
      default: return BoxFit.cover;
    }
  }

  /// Sort layers for Flutter Stack rendering:
  /// 1. Higher z-index on top (later in list)
  /// 2. If z-index equal, reverse original order (assuming strict "Layers Panel" order where Top=Front)
  ///    Original: [Front, Middle, Back]
  ///    Flutter Needs: [Back, Middle, Front]
  static List<dynamic> sortLayers(List<dynamic> layers) {
    if (layers.isEmpty) return [];
    
    // Create wrapper to keep track of original index
    List<Map<String, dynamic>> wrapped = [];
    for (int i = 0; i < layers.length; i++) {
      if (layers[i] is Map<String, dynamic>) {
        wrapped.add({'data': layers[i], 'originalIndex': i});
      }
    }

    wrapped.sort((a, b) {
      final layerA = a['data'] as Map<String, dynamic>;
      final layerB = b['data'] as Map<String, dynamic>;

      final zA = parseDouble(layerA['style']?['zIndex'] ?? layerA['zIndex'])?.toInt() ?? 0;
      final zB = parseDouble(layerB['style']?['zIndex'] ?? layerB['zIndex'])?.toInt() ?? 0;

      if (zA != zB) {
        return zA.compareTo(zB); // Lower Z -> Lower in Stack (Back)
      }
      
      // If Z is equal, Keep Original Order (Standard DOM/Flutter behavior).
      // Later in list = Higher Z (Front) AND Lower in Flow (Bottom).
      return a['originalIndex'].compareTo(b['originalIndex']);
    });

    return wrapped.map((w) => w['data']).toList();
  }
}
