import 'package:flutter/material.dart';
import 'ninja_layer_utils.dart';
import 'ninja_text_measurer.dart';

class NinjaButtonLayer extends StatelessWidget {
  final Map<String, dynamic> layer;
  final Size? parentSize;

  const NinjaButtonLayer({Key? key, required this.layer, this.parentSize}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    debugPrint("NinjaButtonLayer: Building button ${layer['id']}");
    final content = layer['content'] as Map<String, dynamic>? ?? {};
    final style = layer['style'] as Map<String, dynamic>? ?? {};

    // 1. Content
    final text = content['label']?.toString() ?? content['text']?.toString() ?? 'Button';
    
    // 2. Core Styles
    final fontSize = NinjaLayerUtils.parseDouble(content['fontSize'], context) ?? 14.0;
    final fontWeight = NinjaLayerUtils.parseFontWeight(content['fontWeight']);
    final themeColor = NinjaLayerUtils.parseColor(content['themeColor']) ?? Colors.blue; 
    final textColor = NinjaLayerUtils.parseColor(content['textColor']) ?? Colors.white;
    
    // Decoration
    final bgColor = NinjaLayerUtils.parseColor(style['backgroundColor']) ?? themeColor;
    final radius = NinjaLayerUtils.parseDouble(style['borderRadius'], context) ?? 50.0;
    final borderWidth = NinjaLayerUtils.parseDouble(style['borderWidth'], context) ?? 0.0;
    final borderColor = NinjaLayerUtils.parseColor(style['borderColor']) ?? Colors.transparent;

    // Common
    final padding = NinjaLayerUtils.parsePadding(style['padding'], context); 

    return LayoutBuilder(
      builder: (context, constraints) {
        // 1. Calculate Intrinsic Size (Content-Aware) 🧠
        final intrinsicSize = NinjaTextMeasurer.measureButton(
          text: text,
          style: {
             ...style, 
             'fontSize': fontSize,
             'fontWeight': fontWeight,
             'fontFamily': 'Inter', // Sync with dashboard default
             'lineHeight': style['lineHeight'],
             'padding': padding, // Pass parsed padding if possible, or raw style
          }, 
          context: context,
        );

        // 2. Resolve Final Dimensions
        // Use parentSize if available (Priority) for % calculation
        var width = NinjaLayerUtils.parseResponsiveSize(
           style['width'], context, isVertical: false, constraints: constraints, parentSize: parentSize
        );
        var height = NinjaLayerUtils.parseResponsiveSize(
           style['height'], context, isVertical: true, constraints: constraints, parentSize: parentSize
        );

        width ??= intrinsicSize.width;
        height ??= intrinsicSize.height;

        // 3. Handle Padding vs Fixed Height 🤏
        // If height is fixed (e.g. 17%), large vertical padding (e.g. 37px) will push text out of view.
        // Standard behavior for fixed-height buttons is to CENTER the text and ignore vertical padding 
        // (unless alignment is specifically Top, which we don't support yet).
        EdgeInsetsGeometry? effectivePadding;
        if (height != null) {
           // Fixed Height -> Ignore Vertical Padding, Keep Horizontal
           effectivePadding = padding != null 
              ? EdgeInsets.only(left: padding.left, right: padding.right)
              : EdgeInsets.zero;
        } else {
           // Auto Height -> Use Padding to determine size
           effectivePadding = padding ?? const EdgeInsets.symmetric(horizontal: 16, vertical: 8);
        }

        return Container(
          width: width,
          height: height,
          padding: effectivePadding,
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(radius),
            border: borderWidth > 0 
               ? Border.all(color: borderColor, width: borderWidth) 
               : null,
            boxShadow: NinjaLayerUtils.parseShadows(style['boxShadow']),
          ),
          alignment: Alignment.center,
          child: Text(
            text,
            style: TextStyle(
              fontSize: fontSize,
              fontWeight: fontWeight,
              color: textColor,
              fontFamily: 'Inter',
            ),
            textAlign: TextAlign.center,
          ),
        );
      }
    );
  }
}
