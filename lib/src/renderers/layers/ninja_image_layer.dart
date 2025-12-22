import 'package:flutter/material.dart';
import 'ninja_layer_utils.dart';

class NinjaImageLayer extends StatelessWidget {
  final Map<String, dynamic> layer;
  final Size? parentSize;

  const NinjaImageLayer({Key? key, required this.layer, this.parentSize}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final content = layer['content'] as Map<String, dynamic>? ?? {};
    final style = layer['style'] as Map<String, dynamic>? ?? {};

    // 1. Get Image Source
    final url = content['imageUrl'] as String? ?? content['url'] as String?;
    
    if (url == null || url.isEmpty) {
      return const SizedBox.shrink(); // No image to show
    }

    // 2. Dimensions
    // 2. Dimensions (Responsive)
    final width = NinjaLayerUtils.parseResponsiveSize(style['width'], context, isVertical: false, parentSize: parentSize);
    final height = NinjaLayerUtils.parseResponsiveSize(style['height'], context, isVertical: true, parentSize: parentSize);

    // 3. Styling
    final radius = NinjaLayerUtils.parseDouble(style['borderRadius']) ?? 0;
    final fitStr = style['objectFit'] ?? 'cover';
    final opacity = NinjaLayerUtils.parseDouble(style['opacity']) ?? 1.0;
    
    // Map CSS ObjectFit to Flutter BoxFit
    BoxFit fit;
    switch (fitStr) {
      case 'contain': fit = BoxFit.contain; break;
      case 'fill': fit = BoxFit.fill; break;
      case 'none': fit = BoxFit.none; break;
      case 'scale-down': fit = BoxFit.scaleDown; break;
      case 'cover': 
      default: fit = BoxFit.cover; break;
    }

    // 4. Border (Optional)
    final borderWidth = NinjaLayerUtils.parseDouble(style['borderWidth']) ?? 0;
    final borderColor = NinjaLayerUtils.parseColor(style['borderColor']) ?? Colors.transparent;

    Widget imageWidget = Image.network(
      url,
      width: width,   // If null, intrinsic width
      height: height, // If null, intrinsic height
      fit: fit,
      errorBuilder: (context, error, stackTrace) {
        return Container(
           width: width ?? 100,
           height: height ?? 100,
           color: Colors.grey[200],
           child: const Icon(Icons.broken_image, color: Colors.grey),
        );
      },
    );

    // Apply Border Radius
    if (radius > 0) {
      imageWidget = ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: imageWidget,
      );
    }
    
    // Apply Border if exists
    if (borderWidth > 0) {
      imageWidget = Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(radius),
          border: Border.all(color: borderColor, width: borderWidth),
        ),
        child: imageWidget,
      );
    }

    // Apply Opacity
    if (opacity < 1.0) {
      imageWidget = Opacity(opacity: opacity, child: imageWidget);
    }

    // If width/height are explicit, wrap in Container to enforce size?
    // Image.network already handles width/height arguments.
    
    return imageWidget;
  }
}
