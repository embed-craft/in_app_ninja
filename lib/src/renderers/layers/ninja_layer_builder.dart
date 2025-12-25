import 'package:flutter/material.dart';
import 'ninja_text_layer.dart';
import 'ninja_layer_utils.dart';
import 'ninja_button_layer.dart';
import 'ninja_container_layer.dart';
import 'ninja_image_layer.dart';
import 'ninja_countdown_layer.dart';

class NinjaLayerBuilder {
  static Widget build(Map<String, dynamic> layer, BuildContext context, {Size? parentSize, Function(String action, Map<String, dynamic> data)? onAction}) {
    // 1. Identify Layer Type
    final type = layer['type']?.toString().toLowerCase() ?? 'text';
    debugPrint('NinjaLayerBuilder: Building layer type=$type, id=${layer['id']}');
    
    // 2. Dispatch to specific rendered
    Widget content;
    switch (type) {
      case 'text':
        content = NinjaTextLayer(layer: layer, parentSize: parentSize);
        break;
      case 'button':
        content = NinjaButtonLayer(layer: layer, parentSize: parentSize);
        break;
      case 'container':
        content = NinjaContainerLayer(layer: layer, parentSize: parentSize);
        break;
      case 'countdown':
        content = NinjaCountdownLayer(layer: layer); // TODO: Add parentSize support if needed
        break;
      case 'image':
      case 'media': // Alias
        content = NinjaImageLayer(layer: layer, parentSize: parentSize);
        break;
      case 'handle':
        // Match Dashboard 'handle' default styles (40x4, grey, centered)
        final style = layer['style'] as Map<String, dynamic>? ?? {};
        final width = NinjaLayerUtils.parseResponsiveSize(style['width'], context, parentSize: parentSize) ?? 40.0;
        final height = NinjaLayerUtils.parseResponsiveSize(style['height'], context, isVertical: true, parentSize: parentSize) ?? 4.0;
        final bg = NinjaLayerUtils.parseColor(style['backgroundColor']) ?? const Color(0xFFE5E7EB);
        final radius = NinjaLayerUtils.parseDouble(style['borderRadius']) ?? 2.0;

        content = Center(
           child: Container(
             width: width,
             height: height,
             decoration: BoxDecoration(
               color: bg,
               borderRadius: BorderRadius.circular(radius),
             ),
           ),
        );
        break;
      default:
        content = const SizedBox.shrink();
    }

    // 3. Handle Visibility
    if (layer['visible'] == false) return const SizedBox.shrink();

    // 4. Handle Actions (Tap)
    // Extract action from content.action or direct usage
    final contentMap = layer['content'] as Map<String, dynamic>?;
    final rawAction = contentMap?['action'];
    
    if (onAction != null && rawAction != null) {
      String actionType = 'default';
      Map<String, dynamic> actionData = {};
      
      if (rawAction is String) {
        actionType = rawAction;
      } else if (rawAction is Map) {
         actionType = rawAction['type']?.toString() ?? 'default';
         actionData = Map<String, dynamic>.from(rawAction);
      }
      
      if (actionType != 'none' && actionType != 'no_action') {
         content = GestureDetector(
           behavior: HitTestBehavior.opaque, // Ensure clicks are caught
           onTap: () {
             debugPrint("NinjaLayerBuilder: Tap detected on $type. Action: $actionType");
             onAction(actionType, actionData);
           },
           child: content,
         );
      }
    }

    // 5. Handle Absolute Positioning (Overlay Mode)
    if (isAbsolute(layer)) {
      return _buildPositioned(layer, content, context);
    }

    // 6. Default Flow
    final style = layer['style'] as Map<String, dynamic>?;
    final margin = NinjaLayerUtils.parsePadding(style?['margin'], context);
    
    // Relative Positioning (Visual Offset without Flow Impact)
    final top = NinjaLayerUtils.parseDouble(style?['top'], context, true) ?? 0;
    final left = NinjaLayerUtils.parseDouble(style?['left'], context) ?? 0;

    Widget result = content;

    // Apply Margins first (Flow Impact)
    if (margin != null) {
       result = Padding(padding: margin, child: result);
    } else {
       // Smart Default: If no margin set, apply bottom spacing (Dashboard Parity)
       // This replaces the old "Forced Padding" loop in the renderer
       result = Padding(
         padding: EdgeInsets.only(bottom: NinjaLayerUtils.parseDouble(10, context, true) ?? 10.0), 
         child: result
       );
    }

    // Apply Relative Position (Visual Shift)
    if (top != 0 || left != 0) {
       result = Transform.translate(offset: Offset(left, top), child: result);
    }
    
    return result;
  }

  static bool isAbsolute(Map<String, dynamic> layer) {
     final style = layer['style'] as Map<String, dynamic>?;
     if (style == null) return false;
     
     // Explicit Absolute or Fixed
     if (style['position'] == 'absolute' || style['position'] == 'fixed') return true;
     
     // STRICT PARITY: Dashboard defaults to 'relative' (Flow + Offset).
     // We previously forced absolute if 'top/left' existed, which broke parity.
     // Now we only return true if explicit 'position: absolute' key exists.
     
     return false;
  }

  static Widget _buildPositioned(Map<String, dynamic> layer, Widget child, BuildContext context) {
    final style = layer['style'] as Map<String, dynamic>? ?? {};
    
    // Parse Position
    final top = NinjaLayerUtils.parseDouble(style['top'], context, true);
    final left = NinjaLayerUtils.parseDouble(style['left'], context); // false
    final right = NinjaLayerUtils.parseDouble(style['right'], context); // false
    final bottom = NinjaLayerUtils.parseDouble(style['bottom'], context, true);

    // Note: Margin is ignored for absolute positioning (Standard CSS behavior).
    // Dashboard 'PositionEditor' only edits Top/Left, so Margin is likely legacy or irrelevant here.

    // Effective Position (Scaled by Device Ratio)
    return Positioned(
      top: top,
      left: left,
      right: right,
      bottom: bottom,
      child: child,
    );
  }
}
