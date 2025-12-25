import 'package:flutter/material.dart';
import 'ninja_layer_utils.dart';

class NinjaTextLayer extends StatelessWidget {
  final Map<String, dynamic> layer;
  final Size? parentSize;

  const NinjaTextLayer({Key? key, required this.layer, this.parentSize}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final content = layer['content'] as Map<String, dynamic>? ?? {};
    final style = layer['style'] as Map<String, dynamic>? ?? {};

    // 1. Content
    final text = content['text']?.toString() ?? 'Text';

    // 2. Typography
    final fontSize = NinjaLayerUtils.parseDouble(content['fontSize'], context) ?? 16.0;
    final fontWeight = NinjaLayerUtils.parseFontWeight(content['fontWeight']);
    final textColor = NinjaLayerUtils.parseColor(content['textColor']) ?? Colors.black;
    final textAlignStr = content['textAlign']?.toString() ?? 'left';
    
    TextAlign textAlign;
    switch(textAlignStr) {
      case 'center': textAlign = TextAlign.center; break;
      case 'right': textAlign = TextAlign.right; break;
      default: textAlign = TextAlign.left;
    }

    // Size (Text can have explicit size too)
    final width = NinjaLayerUtils.parseResponsiveSize(style['width'], context, isVertical: false, parentSize: parentSize);
    final height = NinjaLayerUtils.parseResponsiveSize(style['height'], context, isVertical: true, parentSize: parentSize);

    // Background/Border (Common styles often applied to text too, e.g. "Labels")
    final bgColor = NinjaLayerUtils.parseColor(style['backgroundColor']); // Optional
    final padding = NinjaLayerUtils.parsePadding(style['padding'], context);
    final radius = NinjaLayerUtils.parseDouble(style['borderRadius'], context) ?? 0;
    
    // Font Family Resolution
    String? fontFamily = (style['fontFamily'] as String?) ?? (content['fontFamily'] as String?);
    final fontUrl = content['fontUrl'] as String?;
    
    // Attempt to extract family from URL if explicit family is missing or generic
    if (fontUrl != null && fontUrl.isNotEmpty) {
       final urlFamily = NinjaLayerUtils.getFontFamilyFromUrl(fontUrl);
       if (urlFamily != null) fontFamily = urlFamily;
    }

    TextStyle textStyle = TextStyle(
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: textColor,
      height: 1.2, // Match Web Default
    );

    // Apply Google Font
    if (fontFamily != null) {
       final googleFont = NinjaLayerUtils.getGoogleFont(fontFamily, textStyle: textStyle);
       if (googleFont != null) {
          textStyle = googleFont;
       } else {
          textStyle = textStyle.copyWith(fontFamily: fontFamily);
       }
    } else {
       textStyle = textStyle.copyWith(fontFamily: 'Inter'); // Default fallback
    }

    return Container(
      width: width,
      height: height,
      padding: padding,
      decoration: bgColor != null || (style['borderWidth'] != null && style['borderWidth'] > 0)
          ? BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(radius),
               border: (style['borderWidth'] != null) 
                  ? Border.all(
                      color: NinjaLayerUtils.parseColor(style['borderColor']) ?? Colors.black, 
                      width: NinjaLayerUtils.parseDouble(style['borderWidth']) ?? 1.0
                    ) 
                  : null,
               boxShadow: NinjaLayerUtils.parseShadows(style['boxShadow']),
            )
          : null,
      alignment: width != null ? _getAlignment(textAlign) : null, // If width is fixed, align text inside
      child: Text(
        text,
        style: textStyle,
        textAlign: textAlign,
      ),
    );
  }

  Alignment _getAlignment(TextAlign align) {
    switch(align) {
      case TextAlign.center: return Alignment.center;
      case TextAlign.right: return Alignment.centerRight;
      default: return Alignment.centerLeft;
    }
  }
}
