import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'dart:typed_data';

class NinjaLayerUtils {
  // Reference design dimensions (iPhone 14 Pro - matches Dashboard)
  // PARITY FIX: Updated from 375×813 to 393×852 to match Dashboard baseline
  static const double kDesignWidth = 393.0;
  static const double kDesignHeight = 852.0;

  // ✅ BUNDLED FONTS: Pre-cached fonts for instant loading
  // These fonts work offline and load instantly via google_fonts package
  static const List<String> supportedFonts = [
    // Sans-Serif
    'Roboto', 'Inter', 'Poppins', 'Open Sans', 'Lato',
    'Montserrat', 'Nunito', 'Raleway', 'Ubuntu', 'Source Sans Pro',
    // Serif
    'Playfair Display', 'Merriweather', 'Lora', 'PT Serif',
    // Monospace
    'Fira Code', 'Source Code Pro', 'JetBrains Mono',
    // Decorative
    'Pacifico', 'Dancing Script', 'Lobster',
  ];

  /// Check if a font is in the supported bundled fonts list
  static bool isSupportedFont(String fontFamily) {
    final cleanName = fontFamily.split(',').first.trim()
        .replaceAll("'", "").replaceAll('"', "");
    return supportedFonts.any((f) => f.toLowerCase() == cleanName.toLowerCase());
  }

  static double? parseDouble(dynamic value, [BuildContext? context, bool isVertical = false]) {
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
       final size = MediaQuery.of(context).size;
       if (isVertical) {
          // Fix 16: Vertical Positioning scales with HEIGHT to match 'cover' background behavior
          return result * (size.height / kDesignHeight);
       } else {
          // Horizontal / Size uses WIDTH scaling
          return result * (size.width / kDesignWidth);
       }
    }
    
    return result;
  }

  static double? parseSize(dynamic value, [BuildContext? context, bool isVertical = false]) {
    if (value == 'auto' || value == null) return null;
    return parseDouble(value, context, isVertical);
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

      final top = parseDouble(style['top']) ?? 0; // Context missing in static calc, acceptable?
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
     
     return parseSize(value, context, isVertical);
   }

   /// PARITY FIX: Get container-relative scale factor
   /// Dashboard formula: containerDim / designDim
   static double getScale(Size parentSize, {bool isVertical = false}) {
     if (isVertical) {
       return parentSize.height / kDesignHeight;
     }
     return parentSize.width / kDesignWidth;
   }

   /// PARITY FIX: Scale a value using container-relative scale
   /// Dashboard formula: px × (containerDim / designDim)
   static double? scaleValue(dynamic value, Size parentSize, {bool isVertical = false}) {
     if (value == null) return null;
     final str = value.toString().trim();
     // Percentages resolve against parent
     if (str.endsWith('%')) {
       final pct = double.tryParse(str.replaceAll('%', ''));
       if (pct == null) return null;
       return (isVertical ? parentSize.height : parentSize.width) * pct / 100;
     }
     // Pixels scale with container
     final px = double.tryParse(str.replaceAll('px', ''));
     if (px == null) return null;
     return px * getScale(parentSize, isVertical: isVertical);
   }

   /// PARITY FIX: Convert pixel position to container-relative position
   /// Dashboard formula: (px / designDim) × 100 → CSS percentage → applied to container
   static double? toPercentOfContainer(dynamic value, {required bool isVertical, required Size parentSize}) {
     if (value == null) return null;
     final str = value.toString().trim();
     // Already percentage - resolve against parent
     if (str.endsWith('%')) {
       final pct = double.tryParse(str.replaceAll('%', ''));
       if (pct == null) return null;
       return (isVertical ? parentSize.height : parentSize.width) * pct / 100;
     }
     // Pixel - convert using design baseline
     final px = double.tryParse(str.replaceAll('px', ''));
     if (px == null) return null;
     final designDim = isVertical ? kDesignHeight : kDesignWidth;
     final containerDim = isVertical ? parentSize.height : parentSize.width;
     final pct = (px / designDim) * 100; // Dashboard percentage
     final result = (pct / 100) * containerDim; // Apply to container
     debugPrint('InAppNinja: 🔢 toPercent: $px / $designDim = ${pct.toStringAsFixed(2)}% → ${result.toStringAsFixed(2)}px of ${containerDim}px');
     return result;
  }

  static Color? parseColor(dynamic value) {
    if (value == null) return null;
    if (value is Color) return value;
    if (value is! String) return null;
    if (value.isEmpty) return null;
    
    // Check for named colors or transparent
    if (value == 'transparent') return Colors.transparent;

    try {
      // Hex
      if (value.startsWith('#')) {
        var hex = value.replaceAll('#', '');
        if (hex.length == 6) {
          hex = 'FF$hex';
        } else if (hex.length == 8) {
          // Allow 8 digit hex (AARRGGBB or RRGGBBAA? Flutter is AARRGGBB)
          // Usually web is RRGGBBAA... sticking to standard parsing logic.
          // If needed, assume RRGGBBAA -> AARRGGBB conversion here if data source is CSS.
        }
        return Color(int.parse(hex, radix: 16));
      }
      
      // RGBA
      if (value.startsWith('rgba')) {
        final parts = value.substring(5, value.length - 1).split(',');
        if (parts.length == 4) {
          return Color.fromRGBO(
            int.parse(parts[0].trim()),
            int.parse(parts[1].trim()),
            int.parse(parts[2].trim()),
            double.parse(parts[3].trim()),
          );
        }
      }
      
      // RGB
      if (value.startsWith('rgb')) {
        final parts = value.substring(4, value.length - 1).split(',');
        if (parts.length == 3) {
          return Color.fromARGB(
            255,
            int.parse(parts[0].trim()),
            int.parse(parts[1].trim()),
            int.parse(parts[2].trim()),
          );
        }
      }
    } catch (_) {
      return null;
    }
    return null;
  }

  static FontWeight? parseFontWeight(dynamic value) {
    if (value == null) return null;
    
    // Handle numeric weights (100-900)
    if (value is num) {
      final weight = value.toInt();
      if (weight <= 100) return FontWeight.w100;
      if (weight <= 200) return FontWeight.w200;
      if (weight <= 300) return FontWeight.w300;
      if (weight <= 400) return FontWeight.w400;
      if (weight <= 500) return FontWeight.w500;
      if (weight <= 600) return FontWeight.w600;
      if (weight <= 700) return FontWeight.w700;
      if (weight <= 800) return FontWeight.w800;
      return FontWeight.w900;
    }
    
    // Handle string values (case-insensitive)
    final str = value.toString().toLowerCase().trim();
    
    // Try parsing as number first
    final numWeight = int.tryParse(str);
    if (numWeight != null) {
      if (numWeight <= 100) return FontWeight.w100;
      if (numWeight <= 200) return FontWeight.w200;
      if (numWeight <= 300) return FontWeight.w300;
      if (numWeight <= 400) return FontWeight.w400;
      if (numWeight <= 500) return FontWeight.w500;
      if (numWeight <= 600) return FontWeight.w600;
      if (numWeight <= 700) return FontWeight.w700;
      if (numWeight <= 800) return FontWeight.w800;
      return FontWeight.w900;
    }
    
    // Handle text names
    switch (str) {
      case 'thin': return FontWeight.w100;
      case 'extralight':
      case 'extra light':
      case 'ultra light': return FontWeight.w200;
      case 'light': return FontWeight.w300;
      case 'regular':
      case 'normal': return FontWeight.w400;
      case 'medium': return FontWeight.w500;
      case 'semibold':
      case 'semi bold':
      case 'demi bold': return FontWeight.w600;
      case 'bold': return FontWeight.w700;
      case 'extrabold':
      case 'extra bold':
      case 'ultra bold': return FontWeight.w800;
      case 'black':
      case 'heavy': return FontWeight.w900;
      default: return null;
    }
  }

  /// Tries to load a Google Font by name. Returns null if not found or empty.
  static TextStyle? getGoogleFont(String? fontFamily, {TextStyle? textStyle}) {
    if (fontFamily == null || fontFamily.isEmpty) return null;
    try {
      // Normalize name: Remove quotes, take first in comma-separated list
      // e.g. "'Open Sans', sans-serif" -> "Open Sans"
      var cleanName = fontFamily.split(',').first.trim();
      cleanName = cleanName.replaceAll("'", "").replaceAll('"', "");
      
      return GoogleFonts.getFont(cleanName, textStyle: textStyle);
    } catch (_) {
      return null;
    }
  }

  static String? getFontFamilyFromUrl(String? url) {
    if (url == null || url.isEmpty) return null;
    try {
       final uri = Uri.parse(url);
       final family = uri.queryParameters['family'];
       if (family != null) {
          // Handle "BBH+Bogle" -> "BBH Bogle"
          // Handle "Robin:wght@400;700" -> "Robin"
          String clean = family.replaceAll('+', ' ');
          if (clean.contains(':')) {
             clean = clean.split(':').first;
          }
          return clean;
       }
    } catch (_) {}
    return null;
  }

  static EdgeInsets? parsePadding(dynamic value, [BuildContext? context]) {
    // 1. Explicit Map: {top: 10, right: 0...}
    if (value is Map) {
      return EdgeInsets.only(
        top: parseDouble(value['top'], context, true) ?? 0,
        right: parseDouble(value['right'], context, false) ?? 0,
        bottom: parseDouble(value['bottom'], context, true) ?? 0,
        left: parseDouble(value['left'], context, false) ?? 0,
      );
    }
    
    // 2. Shorthand: 20 or "20px" (Uniform Padding)
    if (value != null) {
       // Check for 2-value syntax "10px 20px" (Vertical Horizontal)
       if (value is String && value.contains(' ')) {
          final parts = value.trim().split(RegExp(r'\s+'));
          if (parts.length == 2) {
             final v = parseDouble(parts[0], context, true) ?? 0;
             final h = parseDouble(parts[1], context, false) ?? 0;
             return EdgeInsets.symmetric(vertical: v, horizontal: h);
          }
       }

       // Uniform
       // Note: Uniform padding technically applies vertical scaling to top/bottom and horizontal to left/right?
       // BUT standard CSS 'padding: 10px' implies a square spacing.
       // Only applying width-scaling (standard) is safer for uniform scaling to preserve element shape.
       final uniform = parseDouble(value, context); // Default isVertical=false
       if (uniform != null && uniform > 0) {
          return EdgeInsets.all(uniform);
       }
    }

    return null;
  }

  static List<BoxShadow>? parseShadows(dynamic value) {
    // Forced Rebuild
    if (value == null) return null;
    
    // Case 1: List of Maps (Structured)
    if (value is List) {
      final List<BoxShadow> shadows = [];
      for (var s in value) {
        if (s is Map) {
          shadows.add(BoxShadow(
            color: parseColor(s['color']) ?? Colors.black.withOpacity(0.1),
            offset: Offset(
              (s['x'] as num?)?.toDouble() ?? 0,
              (s['y'] as num?)?.toDouble() ?? 0,
            ),
            blurRadius: math.max(0.0, (s['blur'] as num?)?.toDouble() ?? 0),
            spreadRadius: (s['spread'] as num?)?.toDouble() ?? 0,
          ));
        }
      }
      return shadows.isNotEmpty ? shadows : null;
    }

    // Case 2: String preset (Legacy/CSS)
    if (value is String && value.isNotEmpty) {
      // Try generic regex parsing: "0px 8px 16px rgba(0,0,0,0.2)"
      // Matches: Xpx Ypx Blurpx Color (Spread optional)
      // Regex: (-?\d+)px (-?\d+)px (-?\d+)px (?:(-?\d+)px )?(rgba?\(.*?\)|#[0-9a-fA-F]+)
      final regex = RegExp(r'(-?\d+)px\s+(-?\d+)px\s+(-?\d+)px\s+(?:(-?\d+)px\s+)?(rgba?\(.*?\)|#[0-9a-fA-F]+)');
      final match = regex.firstMatch(value);
      
      if (match != null) {
          final x = double.tryParse(match.group(1)!) ?? 0;
          final y = double.tryParse(match.group(2)!) ?? 0;
          final blur = double.tryParse(match.group(3)!) ?? 0;
          final spread = match.group(4) != null ? (double.tryParse(match.group(4)!) ?? 0) : 0.0;
          final colorStr = match.group(5);
          final color = parseColor(colorStr) ?? Colors.black.withOpacity(0.2);
          
          return [BoxShadow(
            color: color,
            offset: Offset(x, y),
            blurRadius: math.max(0.0, blur),
            spreadRadius: spread,
          )];
      }

      if (value.contains('rgba(0,0,0,0.1)')) { // Soft
         return [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 8, offset: const Offset(0, 2))]; 
      }
      if (value.contains('rgba(0,0,0,0.25)')) { // Hard
         return [BoxShadow(color: Colors.black.withOpacity(0.25), blurRadius: 24, offset: const Offset(0, 8))]; 
      }
    }

    return null;
  }

  static Gradient? parseGradient(dynamic value) {
    if (value == null || value is! Map) return null;
    
    final type = value['type'] as String? ?? 'linear';
    final colorsList = value['colors'] as List?;
    final stopsList = value['stops'] as List?;
    final angle = (value['angle'] as num?)?.toDouble() ?? 0.0; // Assume degrees
    
    if (colorsList == null || colorsList.isEmpty) return null;
    
    final colors = colorsList.map((c) => parseColor(c) ?? Colors.transparent).toList();
    final stops = stopsList?.map((s) => (s as num).toDouble()).toList();
    
    if (type == 'linear') {
      // Convert Angle to Alignment (Approximate)
      // 0deg = Bottom to Top? CSS 180deg = Top to Bottom
      // Simple alignment for now:
      return LinearGradient(
        colors: colors,
        stops: stops,
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        transform: GradientRotation(angle * 3.14159 / 180),
      );
    }
    
    return null;
  }

  static BoxFit parseBoxFit(dynamic value) {
    switch (value?.toString()) {
      case 'contain': return BoxFit.contain;
      case 'fill': return BoxFit.fill;
      case 'fitWidth': return BoxFit.fitWidth;
      case 'fitHeight': return BoxFit.fitHeight;
      case 'cover': return BoxFit.cover;
      default: return BoxFit.contain; // PARITY FIX: Match Dashboard
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
