import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:url_launcher/url_launcher.dart';
import '../../models/campaign.dart';
import '../layers/ninja_layer_utils.dart';

/// BottomSheet Nudge Renderer - Uses EXACT Modal Engine for parity
/// 
/// This renderer shares the same core rendering logic as ModalNudgeRenderer:
/// - _buildFlexibleLayout for flex/absolute layer separation
/// - _buildComponent switch for all 25+ component types
/// - _applyStyle for container decoration
/// - NinjaLayerUtils.toPercentOfContainer for absolute positioning
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
  late Animation<double> _fadeAnimation;
  final Map<String, dynamic> _formData = {};

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

  Future<void> _handleAction(String action, [Map<String, dynamic>? data]) async {
    debugPrint('InAppNinja: 🎯 BottomSheet Action triggered: $action, data: $data');
    
    switch (action) {
      case 'dismiss':
      case 'close':
        _handleDismiss();
        break;
      case 'open_link':
      case 'openLink':
      case 'deeplink':
        final url = data?['url'] as String?;
        if (url != null && url.isNotEmpty) {
          debugPrint('InAppNinja: 🔗 Opening URL: $url');
          try {
            final uri = Uri.parse(url);
            final isWebUrl = uri.scheme == 'http' || uri.scheme == 'https';
            
            if (isWebUrl) {
              if (await canLaunchUrl(uri)) {
                await launchUrl(uri, mode: LaunchMode.externalApplication);
              }
            } else {
              await launchUrl(uri, mode: LaunchMode.externalApplication);
            }
          } catch (e) {
            debugPrint('InAppNinja: ❌ Error launching URL: $e');
          }
          if (data?['autoDismiss'] == true) {
            _handleDismiss();
          }
          widget.onCTAClick?.call(action, {'url': url, ...?data});
        }
        break;
      case 'navigate':
        final route = data?['route'] as String? ?? data?['screen'] as String?;
        widget.onCTAClick?.call(action, {'route': route, ...?data});
        break;
      case 'custom':
        widget.onCTAClick?.call(action, data);
        break;
      case 'submit':
        widget.onCTAClick?.call(action, {'formData': _formData, ...?data});
        break;
      case 'none':
      case 'no_action':
        break;
      default:
        widget.onCTAClick?.call(action, data);
    }
  }

  @override
  Widget build(BuildContext context) {
    final config = widget.campaign.config;
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    
    // CRITICAL DEBUG: Verify renderer is being called
    debugPrint('=== InAppNinja: 🚀 BOTTOMSHEET BUILD CALLED ===');
    debugPrint('InAppNinja: 📱 Screen: ${screenWidth}x${screenHeight}');
    debugPrint('InAppNinja: 📦 Components: ${(config['components'] as List?)?.length ?? 0}');
    
    // MODAL PARITY: Resolve config
    final responsiveConfig = _resolveResponsiveConfig(config, screenWidth);
    
    // Parse height
    double? sheetHeight;
    final rHeight = responsiveConfig['height'];
    if (rHeight is num) {
      sheetHeight = rHeight.toDouble();
    } else if (rHeight is String) {
      if (rHeight == 'auto') {
        sheetHeight = null;
      } else if (rHeight.endsWith('%')) {
        final pct = double.tryParse(rHeight.replaceAll('%', ''));
        if (pct != null) sheetHeight = screenHeight * pct / 100;
      } else {
        sheetHeight = double.tryParse(rHeight.replaceAll('px', ''));
      }
    }
    
    final backgroundColor = NinjaLayerUtils.parseColor(responsiveConfig['backgroundColor']) ?? Colors.white;
    final borderRadiusRaw = responsiveConfig['borderRadius'];
    
    double topLeftRadius = 16.0;
    double topRightRadius = 16.0;
    
    if (borderRadiusRaw is num) {
      topLeftRadius = borderRadiusRaw.toDouble();
      topRightRadius = borderRadiusRaw.toDouble();
    } else if (borderRadiusRaw is Map) {
      topLeftRadius = (borderRadiusRaw['topLeft'] as num?)?.toDouble() ?? 16.0;
      topRightRadius = (borderRadiusRaw['topRight'] as num?)?.toDouble() ?? 16.0;
    }

    // MODAL PARITY: Check for absolute positioned layers to skip padding
    bool hasAbsolutePositionedLayers = false;
    final components = responsiveConfig['components'] as List?;
    if (components != null) {
      for (final component in components) {
        if (component is Map<String, dynamic>) {
          final style = component['style'] as Map<String, dynamic>? ?? {};
          if (style['position'] == 'absolute' || style['position'] == 'fixed') {
            hasAbsolutePositionedLayers = true;
            break;
          }
          // Check children too
          final children = component['children'] as List?;
          if (children != null) {
            for (final child in children) {
              if (child is Map<String, dynamic>) {
                final childStyle = child['style'] as Map<String, dynamic>? ?? {};
                if (childStyle['position'] == 'absolute' || childStyle['position'] == 'fixed') {
                  hasAbsolutePositionedLayers = true;
                  break;
                }
              }
            }
          }
          if (hasAbsolutePositionedLayers) break;
        }
      }
    }
    debugPrint('InAppNinja: 🎯 BottomSheet hasAbsolutePositionedLayers=$hasAbsolutePositionedLayers');
    
    final padding = hasAbsolutePositionedLayers 
        ? EdgeInsets.zero 
        : NinjaLayerUtils.parsePadding(responsiveConfig['padding']);
    final showCloseButton = responsiveConfig['showCloseButton'] == true;
    
    final backdropOverlayColor = NinjaLayerUtils.parseColor(responsiveConfig['overlay']?['color']) ?? Colors.black;
    final backdropOpacity = (responsiveConfig['overlay']?['opacity'] as num?)?.toDouble() ?? 0.5;
    final backdropColor = backdropOverlayColor.withOpacity(backdropOpacity);
    
    final backgroundImageUrl = responsiveConfig['backgroundImageUrl'] as String?;
    
    final maxHeight = NinjaLayerUtils.parseResponsiveSize(responsiveConfig['maxHeight'], context, isVertical: true) ?? screenHeight * 0.9;
    
    final shadows = NinjaLayerUtils.parseShadows(responsiveConfig['shadows']) ?? [
      BoxShadow(
        color: Colors.black.withOpacity(0.12),
        blurRadius: 16,
        offset: const Offset(0, -4),
      )
    ];

    // MODAL PARITY: Use sheet dimensions for parentSize
    final sheetWidth = screenWidth;
    final effectiveHeight = sheetHeight ?? maxHeight;
    final parentSize = Size(sheetWidth, effectiveHeight);
    debugPrint('InAppNinja: 📐 BottomSheet parentSize: ${parentSize.width}x${parentSize.height}');

    Widget sheetContent = Container(
      width: sheetWidth,
      height: sheetHeight,
      constraints: BoxConstraints(
        minHeight: 100,
        maxHeight: maxHeight,
      ),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(topLeftRadius),
          topRight: Radius.circular(topRightRadius),
        ),
        boxShadow: shadows,
        // MODAL PARITY: BoxFit.fill + topLeft for layer alignment
        image: backgroundImageUrl != null && backgroundImageUrl.isNotEmpty
            ? DecorationImage(
                image: NetworkImage(backgroundImageUrl),
                fit: BoxFit.fill,
                alignment: Alignment.topLeft,
              )
            : null,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(topLeftRadius),
          topRight: Radius.circular(topRightRadius),
        ),
        child: Stack(
          children: [
            SingleChildScrollView(
              physics: responsiveConfig['scrollable'] == true ? null : const NeverScrollableScrollPhysics(),
              child: Padding(
                padding: padding ?? EdgeInsets.zero,
                // MODAL PARITY: Use _buildContent with parentSize
                child: _buildContent(responsiveConfig, width: sheetWidth, height: effectiveHeight),
              ),
            ),
            // Handle bar
            if (responsiveConfig['dragHandle'] == true)
              Positioned(
                top: 8,
                left: 0,
                right: 0,
                child: Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE5E7EB),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
              ),
            // Close Button
            if (showCloseButton)
              Positioned(
                top: NinjaLayerUtils.scaleValue(8, parentSize, isVertical: true) ?? 8,
                right: NinjaLayerUtils.scaleValue(8, parentSize) ?? 8,
                child: GestureDetector(
                  onTap: _handleDismiss,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.grey.withOpacity(0.1),
                    ),
                    child: const Icon(Icons.close, size: 20, color: Colors.grey),
                  ),
                ),
              ),
          ],
        ),
      ),
    );

    return Stack(
      children: [
        // Backdrop
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () {
            if (responsiveConfig['overlay']?['dismissOnClick'] ?? true) {
              _handleDismiss();
            }
          },
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
        // Sheet
        Align(
          alignment: Alignment.bottomCenter,
          child: SlideTransition(
            position: _slideAnimation,
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onVerticalDragUpdate: (details) {
                if (responsiveConfig['swipeToDismiss'] == true) {
                  _controller.value -= details.primaryDelta! / (sheetHeight ?? screenHeight);
                }
              },
              onVerticalDragEnd: (details) {
                if (responsiveConfig['swipeToDismiss'] == true) {
                  if (details.primaryVelocity! > 300 || _controller.value < 0.6) {
                    _handleDismiss();
                  } else {
                    _controller.forward();
                  }
                }
              },
              child: Material(
                color: Colors.transparent,
                child: sheetContent,
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ===========================================================================
  // MODAL PARITY: Config Resolution (copied from ModalNudgeRenderer)
  // ===========================================================================
  
  Map<String, dynamic> _resolveResponsiveConfig(Map<String, dynamic> config, double screenWidth) {
    var finalConfig = Map<String, dynamic>.from(config);
    
    // Prioritize bottomSheetConfig / modalConfig values
    final sheetConfig = config['bottomSheetConfig'] as Map<String, dynamic>? ?? 
                        config['modalConfig'] as Map<String, dynamic>?;
    if (sheetConfig != null) {
      if (sheetConfig['width'] != null) finalConfig['width'] = sheetConfig['width'];
      if (sheetConfig['height'] != null) finalConfig['height'] = sheetConfig['height'];
      if (sheetConfig['backgroundColor'] != null) finalConfig['backgroundColor'] = sheetConfig['backgroundColor'];
      if (sheetConfig['backgroundImageUrl'] != null) finalConfig['backgroundImageUrl'] = sheetConfig['backgroundImageUrl'];
      if (sheetConfig['borderRadius'] != null) finalConfig['borderRadius'] = sheetConfig['borderRadius'];
      if (sheetConfig['showCloseButton'] != null) finalConfig['showCloseButton'] = sheetConfig['showCloseButton'];
      if (sheetConfig['overlay'] != null) finalConfig['overlay'] = sheetConfig['overlay'];
    }
    
    // Fallback: Recover from Container Component
    var components = (config['components'] as List?)?.map((e) => Map<String, dynamic>.from(e)).toList();
    
    if (components != null && components.isNotEmpty) {
      finalConfig['components'] = components;

      final containerIndex = components.indexWhere(
        (c) => c['type'] == 'container' || c['name'] == 'Bottom Sheet' || c['name'] == 'Modal Container'
      );
      
      if (containerIndex != -1) {
        final container = components[containerIndex];
        final style = Map<String, dynamic>.from(container['style'] as Map<String, dynamic>? ?? {});
        
        if (finalConfig['backgroundImageUrl'] == null && style['backgroundImage'] != null) {
          finalConfig['backgroundImageUrl'] = style['backgroundImage'];
        }
        if (finalConfig['backgroundColor'] == null && style['backgroundColor'] != null) {
          finalConfig['backgroundColor'] = style['backgroundColor'];
        }
        if (finalConfig['borderRadius'] == null && style['borderRadius'] != null) {
          finalConfig['borderRadius'] = style['borderRadius'];
        }

        // Neutralize inner container to prevent double styling
        style['backgroundColor'] = 'transparent';
        style['backgroundImage'] = null;
        style['width'] = '100%';
        style['height'] = '100%';
        style['padding'] = 0;
        
        container['style'] = style;
        components[containerIndex] = container;
      }
    }

    return finalConfig;
  }

  // ===========================================================================
  // MODAL PARITY: _buildContent (copied from ModalNudgeRenderer)
  // ===========================================================================
  
  Widget _buildContent(Map<String, dynamic> config, {double? width, double? height}) {
    if (config['components'] != null && config['components'] is List) {
      final screenSize = MediaQuery.of(context).size;
      final parentSize = Size(
        width ?? screenSize.width,
        height ?? screenSize.height,
      );
      return _buildFlexibleLayout(config, parentSize: parentSize);
    }
    return const Center(child: Text('No components configured'));
  }

  // ===========================================================================
  // MODAL PARITY: _buildFlexibleLayout (copied from ModalNudgeRenderer)
  // ===========================================================================
  
  Widget _buildFlexibleLayout(Map<String, dynamic> config, {required Size parentSize}) {
    final components = config['components'] as List;
    final layout = config['layout'] as Map<String, dynamic>? ?? {};
    
    final direction = layout['direction'] == 'row' ? Axis.horizontal : Axis.vertical;
    final gapRaw = (layout['gap'] as num?)?.toDouble() ?? 0.0;
    final gap = NinjaLayerUtils.scaleValue(gapRaw, parentSize) ?? gapRaw;
    final mainAxisAlignment = _parseMainAxisAlignment(layout['justifyContent']);
    final crossAxisAlignment = _parseCrossAxisAlignment(layout['alignItems']);
    final wrap = layout['flexWrap'] == 'wrap';

    // Sort by order
    final sortedComponents = List<Map<String, dynamic>>.from(
      components.map((c) => c as Map<String, dynamic>),
    )..sort((a, b) {
        final aOrder = (a['position']?['order'] as num?) ?? 0;
        final bOrder = (b['position']?['order'] as num?) ?? 0;
        return aOrder.compareTo(bOrder);
      });

    final flowComponents = <Widget>[];
    final absoluteEntries = <Map<String, dynamic>>[];

    for (final c in sortedComponents) {
      final style = c['style'] as Map<String, dynamic>? ?? {};
      final position = style['position'] as String? ?? 'relative';
      final zIndex = (style['zIndex'] as num?)?.toInt() ?? 0;
      
      // DEBUG: Log component position detection
      debugPrint('InAppNinja: 🔍 BottomSheet Component: type=${c['type']}, position=$position, top=${style['top']}, left=${style['left']}');
      
      Widget child = _buildComponent(c, parentSize: parentSize);

      // Wrap in Entrance Animator
      if (c['animation'] != null) {
        child = _EntranceAnimator(
          animation: c['animation'],
          child: child,
        );
      }

      if (position == 'absolute' || position == 'fixed') {
        absoluteEntries.add({
          'zIndex': zIndex,
          'style': style,
          'child': child,
        });
      } else {
        // Handle Flex Child Properties
        final flexChild = c['flexChild'] as Map<String, dynamic>?;
        if (flexChild != null) {
          final flexGrow = (flexChild['flexGrow'] as num?)?.toInt() ?? 0;
          
          if (!wrap && flexGrow > 0) {
            child = Flexible(
              flex: flexGrow,
              fit: FlexFit.tight,
              child: child,
            );
          }
        }
        flowComponents.add(child);
      }
    }

    // Sort absolute components by z-index
    absoluteEntries.sort((a, b) => (a['zIndex'] as int).compareTo(b['zIndex'] as int));

    Widget flowWidget;
    if (wrap) {
      flowWidget = Wrap(
        direction: direction,
        spacing: gap,
        runSpacing: gap,
        alignment: _wrapAlignment(mainAxisAlignment),
        crossAxisAlignment: _wrapCrossAlignment(crossAxisAlignment),
        children: flowComponents,
      );
    } else {
      if (gap > 0) {
        final spacedChildren = <Widget>[];
        for (var i = 0; i < flowComponents.length; i++) {
          spacedChildren.add(flowComponents[i]);
          if (i < flowComponents.length - 1) {
            spacedChildren.add(SizedBox(
              width: direction == Axis.horizontal ? gap : 0,
              height: direction == Axis.vertical ? gap : 0,
            ));
          }
        }
        flowWidget = Flex(
          direction: direction,
          mainAxisAlignment: mainAxisAlignment,
          crossAxisAlignment: crossAxisAlignment,
          children: spacedChildren,
        );
      } else {
        flowWidget = Flex(
          direction: direction,
          mainAxisAlignment: mainAxisAlignment,
          crossAxisAlignment: crossAxisAlignment,
          children: flowComponents,
        );
      }
    }

    if (absoluteEntries.isNotEmpty) {
      return SizedBox(
        width: parentSize.width,
        height: parentSize.height,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            flowWidget,
             ...absoluteEntries.map((e) {
               final style = e['style'] as Map<String, dynamic>;
               final child = e['child'] as Widget;
               
               // DEBUG: Print position values - same as Modal
               debugPrint('InAppNinja: 📍 BottomSheet Absolute Layer Position: top=${style['top']}, left=${style['left']}, bottom=${style['bottom']}, right=${style['right']}');
               debugPrint('InAppNinja: 📐 BottomSheet ParentSize: ${parentSize.width}x${parentSize.height}');
               
               final topVal = NinjaLayerUtils.toPercentOfContainer(style['top'], isVertical: true, parentSize: parentSize);
               final leftVal = NinjaLayerUtils.toPercentOfContainer(style['left'], isVertical: false, parentSize: parentSize);
               debugPrint('InAppNinja: 📏 BottomSheet Calculated: top=$topVal, left=$leftVal');
               
               return Positioned(
                 // USE SAME FUNCTION AS MODAL
                 top: topVal,
                 bottom: NinjaLayerUtils.toPercentOfContainer(style['bottom'], isVertical: true, parentSize: parentSize),
                 left: leftVal,
                 right: NinjaLayerUtils.toPercentOfContainer(style['right'], isVertical: false, parentSize: parentSize),
                 child: child,
               );
             }).toList(),
          ],
        ),
      );
    }

    return flowWidget;
  }

  // ===========================================================================
  // MODAL PARITY: _buildComponent (copied from ModalNudgeRenderer)
  // ===========================================================================
  
  Widget _buildComponent(Map<String, dynamic> component, {required Size parentSize}) {
    final type = component['type'] as String? ?? 'text';
    
    Widget child;
    switch (type) {
      case 'text': child = _buildTextComponent(component); break;
      case 'image': 
      case 'media': child = _buildImageComponent(component); break;
      case 'button': child = _buildButtonComponent(component); break;
      case 'container': child = _buildContainerComponent(component, parentSize: parentSize); break;
      case 'divider': child = _buildDividerComponent(component); break;
      case 'spacer': child = _buildSpacerComponent(component); break;
      default: child = const SizedBox.shrink();
    }

    Map<String, dynamic> finalStyle = Map<String, dynamic>.from(component['style'] as Map<String, dynamic>? ?? {});
    
    // Strip margin/padding for absolute elements
    final position = finalStyle['position'] as String?;
    if (position == 'absolute' || position == 'fixed') {
      finalStyle.remove('margin');
      finalStyle.remove('padding');
    }

    child = _applyStyle(child, finalStyle, parentSize: parentSize);
    child = _buildInteraction(child, component);
    
    return child;
  }

  // ===========================================================================
  // Component Builders (Simplified versions from Modal)
  // ===========================================================================
  
  Widget _buildTextComponent(Map<String, dynamic> component) {
    final content = component['content'] as Map<String, dynamic>? ?? {};
    final style = component['style'] as Map<String, dynamic>? ?? {};
    
    final text = content['text'] as String? ?? '';
    final fontSize = NinjaLayerUtils.parseDouble(style['fontSize'] ?? content['fontSize'], context) ?? 16.0;
    final fontWeight = NinjaLayerUtils.parseFontWeight(style['fontWeight'] ?? content['fontWeight']);
    final color = NinjaLayerUtils.parseColor(style['color'] ?? content['color']) ?? Colors.black;
    final textAlign = _parseTextAlign(style['textAlign'] ?? content['textAlign']);
    
    TextStyle textStyle = TextStyle(
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
      height: NinjaLayerUtils.parseDouble(style['lineHeight'], context, true) ?? 1.2,
    );

    final fontFamily = style['fontFamily'] as String? ?? content['fontFamily'] as String?;
    if (fontFamily != null && fontFamily.isNotEmpty) {
      final googleFont = NinjaLayerUtils.getGoogleFont(fontFamily, textStyle: textStyle);
      if (googleFont != null) {
        textStyle = googleFont;
      }
    }

    return Text(
      text,
      style: textStyle,
      textAlign: textAlign,
      // PARITY FIX: Disable OS font scaling
      textScaleFactor: 1.0,
    );
  }

  Widget _buildImageComponent(Map<String, dynamic> component) {
    final content = component['content'] as Map<String, dynamic>? ?? {};
    final style = component['style'] as Map<String, dynamic>? ?? {};
    
    // PARITY FIX: Check all possible URL keys (Dashboard uses 'imageUrl')
    final url = content['imageUrl'] as String? ?? 
                content['url'] as String? ?? 
                content['src'] as String? ?? 
                style['backgroundImage'] as String? ?? '';
    
    debugPrint('InAppNinja: 🖼️ Image component: url=$url');
    
    if (url.isEmpty) {
      debugPrint('InAppNinja: ⚠️ Image URL is empty!');
      return const SizedBox.shrink();
    }
    
    final fit = NinjaLayerUtils.parseBoxFit(content['objectFit'] ?? style['objectFit']);
    final borderRadius = NinjaLayerUtils.parseDouble(style['borderRadius']) ?? 0;
    
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: Image.network(
        url,
        fit: fit,
        errorBuilder: (_, __, ___) => Container(
          color: Colors.grey[200],
          child: const Icon(Icons.image_not_supported, color: Colors.grey),
        ),
      ),
    );
  }

  Widget _buildButtonComponent(Map<String, dynamic> component) {
    final content = component['content'] as Map<String, dynamic>? ?? {};
    final style = component['style'] as Map<String, dynamic>? ?? {};
    
    final text = content['text'] as String? ?? content['label'] as String? ?? 'Button';
    
    // MODAL PARITY: Action handling
    dynamic rawAction = content['action'];
    String actionType = 'default';
    Map<String, dynamic> actionData = {};
    
    if (rawAction is String) {
      actionType = rawAction;
    } else if (rawAction is Map) {
      actionType = rawAction['type']?.toString() ?? 'default';
      actionData = Map<String, dynamic>.from(rawAction);
    }
    
    // PARITY FIX: Check style FIRST (where Dashboard stores actual values), then content for fallbacks
    final themeColor = NinjaLayerUtils.parseColor(
      style['backgroundColor'] ??   // Primary: style.backgroundColor (#007022)
      content['buttonColor'] ?? 
      content['themeColor']         // Last: default theme color
    ) ?? Colors.indigo;
    
    final textColor = NinjaLayerUtils.parseColor(
      style['color'] ??             // Primary: style.color 
      content['textColor'] ?? 
      content['buttonTextColor']
    ) ?? Colors.white;
    
    final borderRadius = NinjaLayerUtils.parseDouble(
      style['borderRadius'] ?? 
      content['buttonBorderRadius']
    ) ?? 8.0;
    
    final fontSize = NinjaLayerUtils.parseDouble(
      style['fontSize'] ??          // Primary: from style
      content['fontSize'] ?? 
      content['buttonFontSize'], 
      context
    ) ?? 16.0;
    
    final fontWeight = NinjaLayerUtils.parseFontWeight(
      style['fontWeight'] ??        // Primary: from style
      content['fontWeight'] ?? 
      content['buttonFontWeight']
    ) ?? FontWeight.w600;
    
    // DEBUG: Log button properties - check ALL locations
    debugPrint('InAppNinja: 🔘 Button: text=$text, themeColor=$themeColor, fontSize=$fontSize, fontWeight=$fontWeight');
    debugPrint('InAppNinja: 🔘 FULL CONTENT: $content');
    debugPrint('InAppNinja: 🔘 Button style: backgroundColor=${style['backgroundColor']}, fontFamily=${style['fontFamily']}');
    
    // Font family support - check style FIRST (where Dashboard stores actual values)
    String? fontFamily = (style['fontFamily'] as String?) ?? 
                         (content['fontFamily'] as String?) ??
                         (content['buttonFontFamily'] as String?);
    
    TextStyle textStyle = TextStyle(
      color: textColor,
      fontSize: fontSize,
      fontWeight: fontWeight,
    );
    
    // Apply Google Font
    if (fontFamily != null && fontFamily.isNotEmpty) {
      final googleFont = NinjaLayerUtils.getGoogleFont(fontFamily, textStyle: textStyle);
      if (googleFont != null) {
        textStyle = googleFont;
      } else {
        textStyle = textStyle.copyWith(fontFamily: fontFamily);
      }
    }

    // MODAL PARITY: GestureDetector with action, EdgeInsets.zero
    return GestureDetector(
      onTap: () => _handleAction(actionType, actionData),
      child: Container(
        // MODAL PARITY: No padding, just centered text like Dashboard
        padding: EdgeInsets.zero,
        decoration: BoxDecoration(
          color: themeColor,
          borderRadius: BorderRadius.circular(borderRadius),
        ),
        child: Center(
          child: Text(
            text,
            style: textStyle,
            textAlign: TextAlign.center,
            // PARITY FIX: Disable OS font scaling to match Dashboard 1:1
            textScaleFactor: 1.0,
          ),
        ),
      ),
    );
  }

  Widget _buildContainerComponent(Map<String, dynamic> component, {required Size parentSize}) {
    final children = component['children'] as List? ?? [];
    final style = component['style'] as Map<String, dynamic>? ?? {};
    final flexLayout = component['flexLayout'] as Map<String, dynamic>? ?? {};
    final componentSize = component['size'] as Map<String, dynamic>? ?? {};
    
    // DEBUG: Log container children count and types
    debugPrint('InAppNinja: 📦 Container has ${children.length} children');
    for (int i = 0; i < children.length; i++) {
      final child = children[i];
      if (child is Map<String, dynamic>) {
        final childStyle = child['style'] as Map<String, dynamic>? ?? {};
        debugPrint('InAppNinja:   → Child[$i]: type=${child['type']}, position=${childStyle['position']}, top=${childStyle['top']}, left=${childStyle['left']}');
      }
    }
    
    final cWidth = NinjaLayerUtils.parseResponsiveSize(style['width'] ?? componentSize['width'], context, isVertical: false, parentSize: parentSize) ?? parentSize.width;
    final cHeight = NinjaLayerUtils.parseResponsiveSize(style['height'] ?? componentSize['height'], context, isVertical: true, parentSize: parentSize) ?? parentSize.height;
    final containerSize = Size(cWidth, cHeight);

    Widget content;
    
    if (flexLayout['enabled'] == true || style['display'] == 'flex') {
      content = _buildFlexibleLayout({
        'components': children,
        'layout': flexLayout.isEmpty ? {
          'direction': style['flexDirection'] ?? 'column',
          'justifyContent': style['justifyContent'] ?? 'flex-start',
          'alignItems': style['alignItems'] ?? 'stretch',
          'gap': style['gap'],
        } : flexLayout,
      }, parentSize: containerSize);
    } else {
      // PARITY FIX: Separate absolute and relative children (like _buildFlexibleLayout does)
      final relativeChildren = <Widget>[];
      final absoluteEntries = <Map<String, dynamic>>[];
      
      for (final c in children) {
        if (c is! Map<String, dynamic>) continue;
        final childStyle = c['style'] as Map<String, dynamic>? ?? {};
        final position = childStyle['position'] as String? ?? 'relative';
        
        if (position == 'absolute' || position == 'fixed') {
          absoluteEntries.add({
            'component': c,
            'style': childStyle,
          });
        } else {
          relativeChildren.add(_buildComponent(c, parentSize: containerSize));
        }
      }
      
      // Base flow widget with relative children
      Widget flowWidget = relativeChildren.isEmpty 
          ? const SizedBox.shrink()
          : SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: relativeChildren,
              ),
            );
      
      // Wrap with Stack if there are absolute children
      if (absoluteEntries.isNotEmpty) {
        debugPrint('InAppNinja: 📍 Container rendering ${absoluteEntries.length} absolute children');
        content = SizedBox(
          width: containerSize.width,
          height: containerSize.height,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              flowWidget,
              ...absoluteEntries.map((entry) {
                final comp = entry['component'] as Map<String, dynamic>;
                final childStyle = entry['style'] as Map<String, dynamic>;
                final child = _buildComponent(comp, parentSize: containerSize);
                
                debugPrint('InAppNinja: 📍 Positioning ${comp['type']}: top=${childStyle['top']}, left=${childStyle['left']}');
                
                return Positioned(
                  top: NinjaLayerUtils.toPercentOfContainer(childStyle['top'], isVertical: true, parentSize: containerSize),
                  bottom: NinjaLayerUtils.toPercentOfContainer(childStyle['bottom'], isVertical: true, parentSize: containerSize),
                  left: NinjaLayerUtils.toPercentOfContainer(childStyle['left'], isVertical: false, parentSize: containerSize),
                  right: NinjaLayerUtils.toPercentOfContainer(childStyle['right'], isVertical: false, parentSize: containerSize),
                  child: child,
                );
              }).toList(),
            ],
          ),
        );
      } else {
        content = flowWidget;
      }
    }

    bool hasAbsoluteChildren = children.any((c) {
      if (c is! Map<String, dynamic>) return false;
      final childStyle = c['style'] as Map<String, dynamic>? ?? {};
      return childStyle['position'] == 'absolute' || childStyle['position'] == 'fixed';
    });
    
    final containerPadding = hasAbsoluteChildren 
        ? EdgeInsets.zero
        : NinjaLayerUtils.parsePadding(style['padding'], context);

    return Container(
      padding: containerPadding,
      child: content,
    );
  }

  Widget _buildDividerComponent(Map<String, dynamic> component) {
    final style = component['style'] as Map<String, dynamic>? ?? {};
    final color = NinjaLayerUtils.parseColor(style['backgroundColor']) ?? Colors.grey[300];
    final height = NinjaLayerUtils.parseDouble(style['height']) ?? 1.0;
    
    return Container(
      height: height,
      color: color,
    );
  }

  Widget _buildSpacerComponent(Map<String, dynamic> component) {
    final style = component['style'] as Map<String, dynamic>? ?? {};
    final height = NinjaLayerUtils.parseDouble(style['height']) ?? 16.0;
    
    return SizedBox(height: height);
  }

  // ===========================================================================
  // Style & Interaction Helpers
  // ===========================================================================
  
  Widget _applyStyle(Widget child, Map<String, dynamic> style, {required Size parentSize}) {
    final width = NinjaLayerUtils.parseResponsiveSize(style['width'], context, parentSize: parentSize);
    final height = NinjaLayerUtils.parseResponsiveSize(style['height'], context, isVertical: true, parentSize: parentSize);
    final margin = NinjaLayerUtils.parsePadding(style['margin'], context);
    final opacity = (style['opacity'] as num?)?.toDouble() ?? 1.0;
    
    if (width != null || height != null) {
      child = SizedBox(width: width, height: height, child: child);
    }
    
    if (margin != null) {
      child = Padding(padding: margin, child: child);
    }
    
    if (opacity < 1.0) {
      child = Opacity(opacity: opacity, child: child);
    }
    
    return child;
  }

  Widget _buildInteraction(Widget child, Map<String, dynamic> component) {
    final content = component['content'] as Map<String, dynamic>? ?? {};
    final action = content['action'];
    
    if (action == null) return child;
    
    return GestureDetector(
      onTap: () {
        if (action is String) {
          _handleAction(action);
        } else if (action is Map<String, dynamic>) {
          final type = action['type'] as String? ?? 'none';
          _handleAction(type, action);
        }
      },
      child: child,
    );
  }

  // ===========================================================================
  // Alignment Helpers
  // ===========================================================================
  
  MainAxisAlignment _parseMainAxisAlignment(dynamic value) {
    switch (value) {
      case 'flex-start': return MainAxisAlignment.start;
      case 'flex-end': return MainAxisAlignment.end;
      case 'center': return MainAxisAlignment.center;
      case 'space-between': return MainAxisAlignment.spaceBetween;
      case 'space-around': return MainAxisAlignment.spaceAround;
      case 'space-evenly': return MainAxisAlignment.spaceEvenly;
      default: return MainAxisAlignment.start;
    }
  }

  CrossAxisAlignment _parseCrossAxisAlignment(dynamic value) {
    switch (value) {
      case 'flex-start': return CrossAxisAlignment.start;
      case 'flex-end': return CrossAxisAlignment.end;
      case 'center': return CrossAxisAlignment.center;
      case 'stretch': return CrossAxisAlignment.stretch;
      case 'baseline': return CrossAxisAlignment.baseline;
      default: return CrossAxisAlignment.stretch;
    }
  }

  WrapAlignment _wrapAlignment(MainAxisAlignment alignment) {
    switch (alignment) {
      case MainAxisAlignment.start: return WrapAlignment.start;
      case MainAxisAlignment.end: return WrapAlignment.end;
      case MainAxisAlignment.center: return WrapAlignment.center;
      case MainAxisAlignment.spaceBetween: return WrapAlignment.spaceBetween;
      case MainAxisAlignment.spaceAround: return WrapAlignment.spaceAround;
      case MainAxisAlignment.spaceEvenly: return WrapAlignment.spaceEvenly;
    }
  }

  WrapCrossAlignment _wrapCrossAlignment(CrossAxisAlignment alignment) {
    switch (alignment) {
      case CrossAxisAlignment.start: return WrapCrossAlignment.start;
      case CrossAxisAlignment.end: return WrapCrossAlignment.end;
      case CrossAxisAlignment.center: return WrapCrossAlignment.center;
      default: return WrapCrossAlignment.start;
    }
  }

  // ===========================================================================
  // BOTTOMSHEET FIX: Position helper for sheet-relative positioning
  // ===========================================================================
  
  /// For BottomSheet, positions are designed relative to the sheet canvas.
  /// Dashboard converts: (px / designDim) × 100 → CSS percentage → applied to container
  /// We do the same but output actual pixels for Flutter's Positioned widget.
  double? _parseSheetPosition(dynamic value, {required bool isVertical, required Size containerSize}) {
    if (value == null) return null;
    final str = value.toString().trim();
    
    // Already percentage - apply directly to container
    if (str.endsWith('%')) {
      final pct = double.tryParse(str.replaceAll('%', ''));
      if (pct == null) return null;
      final containerDim = isVertical ? containerSize.height : containerSize.width;
      return containerDim * pct / 100;
    }
    
    // Pixel value - convert using design dimensions
    // Dashboard formula: (px / designDim) × 100% → applied to container
    final px = double.tryParse(str.replaceAll('px', ''));
    if (px == null) return null;
    
    // CRITICAL FIX: Use design dimensions that match the sheet canvas
    // For width: always use kDesignWidth (393) - horizontal works fine
    // For height: use kDesignHeight (852) - this matches Dashboard's designHeight
    const kDesignWidth = 393.0;
    const kDesignHeight = 852.0;
    
    final designDim = isVertical ? kDesignHeight : kDesignWidth;
    final containerDim = isVertical ? containerSize.height : containerSize.width;
    
    // Same formula as Dashboard: (px / designDim) * containerDim
    // This produces the same proportional position
    final pct = (px / designDim) * 100;
    final result = (pct / 100) * containerDim;
    
    debugPrint('InAppNinja: 🎯 Sheet Position: $px px / $designDim design = ${pct.toStringAsFixed(2)}% → ${result.toStringAsFixed(2)}px of ${containerDim.toStringAsFixed(0)}px container');
    return result;
  }

  TextAlign _parseTextAlign(dynamic value) {
    switch (value) {
      case 'left': return TextAlign.left;
      case 'right': return TextAlign.right;
      case 'center': return TextAlign.center;
      case 'justify': return TextAlign.justify;
      default: return TextAlign.left;
    }
  }
}

// ===========================================================================
// Entrance Animator Widget (copied from Modal)
// ===========================================================================

class _EntranceAnimator extends StatefulWidget {
  final Map<String, dynamic>? animation;
  final Widget child;

  const _EntranceAnimator({required this.animation, required this.child});

  @override
  State<_EntranceAnimator> createState() => _EntranceAnimatorState();
}

class _EntranceAnimatorState extends State<_EntranceAnimator> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    final duration = (widget.animation?['duration'] as num?)?.toInt() ?? 300;
    final delay = (widget.animation?['delay'] as num?)?.toInt() ?? 0;
    
    _controller = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: duration),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );

    _slideAnimation = Tween<Offset>(begin: const Offset(0, 0.1), end: Offset.zero).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );

    _scaleAnimation = Tween<double>(begin: 0.95, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );

    Future.delayed(Duration(milliseconds: delay), () {
      if (mounted) _controller.forward();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: SlideTransition(
        position: _slideAnimation,
        child: ScaleTransition(
          scale: _scaleAnimation,
          child: widget.child,
        ),
      ),
    );
  }
}
