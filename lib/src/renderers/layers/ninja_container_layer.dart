import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'ninja_layer_utils.dart';
import 'ninja_layer_builder.dart';

class NinjaContainerLayer extends StatelessWidget {
  final Map<String, dynamic> layer;
  final Size? parentSize;

  const NinjaContainerLayer({Key? key, required this.layer, this.parentSize}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final style = layer['style'] as Map<String, dynamic>? ?? {};
    
    // Size
    final width = NinjaLayerUtils.parseSize(style['width'], context);
    final height = NinjaLayerUtils.parseSize(style['height'], context);
    
    // Decoration
    final bgColor = NinjaLayerUtils.parseColor(style['backgroundColor']);
    final radius = NinjaLayerUtils.parseDouble(style['borderRadius'], context) ?? 0;
    final borderWidth = NinjaLayerUtils.parseDouble(style['borderWidth'], context) ?? 0;
    final borderColor = NinjaLayerUtils.parseColor(style['borderColor']) ?? Colors.transparent;
    
    // Padding
    final padding = NinjaLayerUtils.parsePadding(style['padding'], context);

    // Children (Recursive)
    final childrenProp = layer['children'] ?? layer['layers'] ?? [];
    Widget? childContent;
    
       // Hybrid Layout: Flow items in Column, Absolute items in Stack
       List<Widget> stackChildren = [];
       List<Widget> flowChildren = [];
       List<Map<String, dynamic>> absCandidates = [];

       // Helper to calculate height including percentage support
       double calculatedMinHeight = NinjaLayerUtils.solveRequiredHeight(childrenProp);
       
       // Dashboard Logic: Default to reasonable height (e.g. 350) if content is small, 
       // but expand if content demands it.
       if (calculatedMinHeight < 350.0 && flowChildren.isEmpty) {
          calculatedMinHeight = 350.0;
       }
       
       debugPrint('NinjaContainerLayer ${layer['id']}: Solved Height=$calculatedMinHeight');

       // 3. Build Children Widgets 🏗️
       // Determine MY size to pass to children for % resolution
       final myWidth = width ?? parentSize?.width ?? MediaQuery.of(context).size.width;
       final mySize = Size(myWidth, calculatedMinHeight);

       // Separating Candidates (Decoupled Sorting Logic)
       for (var childLayer in childrenProp) {
         if (childLayer is! Map<String, dynamic>) continue;
         
         final isAbs = NinjaLayerBuilder.isAbsolute(childLayer);
         
         if (isAbs) {
            absCandidates.add(childLayer);
         } else {
            // Flow: Preserve Array Order (Dashboard Parity)
            // Do NOT sort by Z-Index for flow items.
            flowChildren.add(NinjaLayerBuilder.build(childLayer, context, parentSize: mySize));
         }
       }
       
       // Stack: Sort by Z-Index (Stacking Order)
       final sortedAbs = NinjaLayerUtils.sortLayers(absCandidates).cast<Map<String, dynamic>>();
       for (var layer in sortedAbs) {
           stackChildren.add(NinjaLayerBuilder.build(layer, context, parentSize: mySize));
       }

       if (flowChildren.isNotEmpty) {
         // Insert flow column at the base of the stack
         stackChildren.insert(0, Container(
           constraints: BoxConstraints(minHeight: calculatedMinHeight),
           padding: padding, // Apply padding ONLY to flow content 🧠
           child: Column(
             crossAxisAlignment: CrossAxisAlignment.stretch, // Match Dashboard Flex-Stretch
             mainAxisSize: MainAxisSize.min, // Shrink wrap
             children: flowChildren.map((child) => Padding(
               padding: const EdgeInsets.only(bottom: 10), // Match Dashboard Gap (margin-bottom: 10px)
               child: child,
             )).toList(),
           ),
         ));
       } else {
         // Placeholder for background size
         stackChildren.insert(0, Container(
            height: calculatedMinHeight > 0 ? calculatedMinHeight : 1,
            width: double.infinity,
            padding: padding, // Apply padding even if empty (though less critical)
         ));
       }

       childContent = Stack(
         clipBehavior: Clip.none,
         children: stackChildren,
       );

    return Container(
      width: width,
      height: height,
      padding: EdgeInsets.zero, // Explicitly Zero per user request
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(radius),
        border: borderWidth > 0 
            ? Border.all(color: borderColor, width: borderWidth)
            : null,
        boxShadow: NinjaLayerUtils.parseShadows(style['boxShadow']),
      ),
      clipBehavior: Clip.antiAlias, // Clip children to border radius
      child: childContent,
    );
  }
}
