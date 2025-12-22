import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter_widget_from_html/flutter_widget_from_html.dart';
import 'package:flutter_widget_from_html/flutter_widget_from_html.dart';
import '../../models/campaign.dart';
import '../layers/ninja_layer_builder.dart';
import '../layers/ninja_layer_utils.dart';

class BottomSheetNudgeRenderer extends StatefulWidget {
  final Campaign campaign;
  final VoidCallback? onDismiss;
  final Function(String action, Map<String, dynamic>? data)? onCTAClick;

  const BottomSheetNudgeRenderer({
    Key? key,
    required this.campaign,
    this.onDismiss,
    this.onCTAClick,
  }) : super(key: key);

  @override
  State<BottomSheetNudgeRenderer> createState() => _BottomSheetNudgeRendererState();
}

class _BottomSheetNudgeRendererState extends State<BottomSheetNudgeRenderer> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeAnimation; // Backdrop fade

  @override
  void initState() {
    super.initState();
    final config = widget.campaign.config;
    final duration = config['animationDuration'] as int? ?? 300;
    
    _controller = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: duration),
    );

    _slideAnimation = Tween<Offset>(begin: const Offset(0, 1), end: Offset.zero).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _handleDismiss() async {
    await _controller.reverse();
    widget.onDismiss?.call();
  }

  void _handleAction(String action, [Map<String, dynamic>? data]) {
    if (action == 'dismiss') {
      _handleDismiss();
    } else {
      widget.onCTAClick?.call(action, data);
    }
  }

  @override
  Widget build(BuildContext context) {
    final config = widget.campaign.config;
    final width = MediaQuery.of(context).size.width;
    
    // Resolve config (Responsive logic omitted for brevity, assuming direct config)
    final responsiveConfig = config; 
    
    double? height;
    final rHeight = responsiveConfig['height'];
    if (rHeight is num) {
      height = rHeight.toDouble();
    } else if (rHeight is String) {
      if (rHeight == 'auto') {
        height = null;
      } else if (rHeight.endsWith('%')) {
        try {
          final pct = double.parse(rHeight.replaceAll('%', '')) / 100;
          height = MediaQuery.of(context).size.height * pct;
        } catch (_) {}
      } else {
         // Try parsing simple string or "px"
         try {
           height = double.parse(rHeight.replaceAll('px', ''));
         } catch (_) {}
      }
    }
    
    final backgroundColor = NinjaLayerUtils.parseColor(responsiveConfig['backgroundColor']) ?? Colors.white;
    final borderRadiusRaw = responsiveConfig['borderRadius'];
    
    // Handle border radius object or number
    double topLeftRadius = 16.0;
    double topRightRadius = 16.0;
    
    if (borderRadiusRaw is num) {
      topLeftRadius = borderRadiusRaw.toDouble();
      topRightRadius = borderRadiusRaw.toDouble();
    } else if (borderRadiusRaw is Map) {
      topLeftRadius = (borderRadiusRaw['topLeft'] as num?)?.toDouble() ?? 16.0;
      topRightRadius = (borderRadiusRaw['topRight'] as num?)?.toDouble() ?? 16.0;
    }

    final padding = NinjaLayerUtils.parsePadding(responsiveConfig['padding']);
    
    final backdropOverlayColor = NinjaLayerUtils.parseColor(responsiveConfig['overlay']?['color']) ?? Colors.black;
    final backdropOpacity = (responsiveConfig['overlay']?['opacity'] as num?)?.toDouble() ?? 0.5;
    final backdropColor = backdropOverlayColor.withOpacity(backdropOpacity);
    
    final backgroundImageUrl = responsiveConfig['backgroundImageUrl'] as String?;
    final backgroundSize = responsiveConfig['backgroundSize'] as String? ?? 'cover';
    
    return Stack(
      children: [
        // Backdrop
        GestureDetector(
          onTap: (responsiveConfig['overlay']?['dismissOnClick'] ?? true) ? _handleDismiss : null,
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: Container(
              color: backdropColor,
              child: responsiveConfig['overlay']?['blur'] != null 
                  ? BackdropFilter(
                      filter: ui.ImageFilter.blur(
                        sigmaX: (responsiveConfig['overlay']['blur'] as num).toDouble(),
                        sigmaY: (responsiveConfig['overlay']['blur'] as num).toDouble(),
                      ),
                      child: Container(color: Colors.transparent),
                    )
                  : null,
            ),
          ),
        ),
        
        // Sheet Content
        Align(
          alignment: Alignment.bottomCenter,
          child: SlideTransition(
            position: _slideAnimation,
            child: Material(
              color: Colors.transparent,
              child: Container(
                width: width,
                height: height, // null = auto
                 constraints: BoxConstraints(
                   minHeight: 100,
                   maxHeight: MediaQuery.of(context).size.height * 0.9,
                 ),
                 decoration: BoxDecoration(
                   color: backgroundColor,
                   borderRadius: BorderRadius.only(
                     topLeft: Radius.circular(topLeftRadius),
                     topRight: Radius.circular(topRightRadius),
                   ),
                   image: backgroundImageUrl != null && backgroundImageUrl.isNotEmpty
                      ? DecorationImage(
                          image: NetworkImage(backgroundImageUrl),
                          fit: NinjaLayerUtils.parseBoxFit(backgroundSize),
                        )
                      : null,
                   boxShadow: const [
                      BoxShadow(
                        color: Colors.black12,
                        blurRadius: 16,
                        offset: Offset(0, -4)
                      )
                   ]
                 ),
                 child: Stack(
                   children: [
                     // Content (Internal Scroll + Absolute Layers)
                     _buildContent(responsiveConfig),
                     
                     // Close Button (if enabled)
                     if (responsiveConfig['showCloseButton'] == true)
                        Positioned(
                          top: 16, // Match Dashboard Top Offset
                          right: 12,
                          child: GestureDetector(
                            onTap: _handleDismiss,
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.black12, // subtle bg
                              ),
                              child: const Icon(Icons.close, size: 20, color: Colors.black54),
                            ),
                          ),
                        )
                   ],
                 ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildContent(Map<String, dynamic> config) {
    final layersRaw = (config['layers'] as List? ?? config['components'] as List? ?? []);
    final padding = NinjaLayerUtils.parsePadding(config['padding']) ?? EdgeInsets.zero;

    if (layersRaw.isEmpty) return const Center(child: Text('No content'));

    final layersList = layersRaw.cast<Map<String, dynamic>>();
    
    // Separation: Flow vs Absolute
    List<Widget> flowChildren = [];
    List<Map<String, dynamic>> absCandidates = [];

    final contextWidth = MediaQuery.of(context).size.width;
    // Use full screen size for parentSize to support % based dimensions/positioning
    // Passing height:0 broke % calculations.
    final rootSize = MediaQuery.of(context).size;

    for (var layer in layersList) {
      if (NinjaLayerBuilder.isAbsolute(layer)) {
         absCandidates.add(layer);
      } else {
         final builtWidget = NinjaLayerBuilder.build(layer, context, parentSize: rootSize);
         flowChildren.add(builtWidget);
      }
    }

    // Sort Absolute Layers by Z-Index
    final sortedAbs = NinjaLayerUtils.sortLayers(absCandidates).cast<Map<String, dynamic>>();
    
    // --- CONSTRUCT LAYOUT ---
    
    // 1. Flow Layer (The "Document" Flow)
    // We wrap flow + absolute layers in a Stack so they scroll together (Dashboard behavior)
    Widget contentStack;
    
    // Calculate min height for the scrollable area to ensure full canvas availability
    // This allows absolute layers to be positioned relative to the "Content Document"
    Widget flowStructure = Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: flowChildren.map((child) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: child,
        )).toList(),
    );

    contentStack = Stack(
       children: [
         // Flow content at z=0
         flowStructure,
         // Absolute layers on top, scrolling with flow  
         ...sortedAbs.map((layer) => NinjaLayerBuilder.build(layer, context, parentSize: rootSize)),
       ],
    );

    // 2. Add Handle (Pushes content down)
    // CRITICAL: Padding applies to the Handle+Content assembly
    Widget contentColumn = Padding(
       padding: padding,
       child: Column(
         mainAxisSize: MainAxisSize.min,
         crossAxisAlignment: CrossAxisAlignment.stretch,
         children: [
            // Handle
            if (config['dragHandle'] == true)
                Center(
                  child: Container(
                     margin: const EdgeInsets.only(bottom: 16),
                     width: 40,
                     height: 4,
                     decoration: BoxDecoration(
                       color: const Color(0xFFE5E7EB),
                       borderRadius: BorderRadius.circular(2),
                     ),
                  ),
                ),
            
            // Allow scrolling behavior
            Flexible(
              fit: FlexFit.loose,
              child: SingleChildScrollView(
                 physics: const ClampingScrollPhysics(),
                 child: contentStack,
              ),
            ),
         ],
       ),
    );

    // 3. Root Stack (Sheet Container)
    return contentColumn;
  }
}
