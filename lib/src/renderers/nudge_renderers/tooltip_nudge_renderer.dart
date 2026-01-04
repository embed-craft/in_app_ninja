import 'package:flutter/material.dart';
import 'dart:async';
import 'package:url_launcher/url_launcher.dart';
import '../../models/campaign.dart';
import '../layers/ninja_layer_utils.dart';
import '../campaign_renderer.dart';
import '../../app_ninja.dart';
import '../../utils/interface_handler.dart';

/// Tooltip Nudge Renderer - New Architecture
/// 
/// Following Modal construction logic with:
/// - Layer-based structure (text, image, button)
/// - ScaleX/ScaleY dynamic positioning
/// - Arrow pointing to target element
/// - Spotlight overlay with target cutout
/// - Auto-scroll to target element
class TooltipNudgeRenderer extends StatefulWidget {
  final Campaign campaign;
  final VoidCallback? onDismiss;
  final Function(String action, Map<String, dynamic>? data)? onCTAClick;

  const TooltipNudgeRenderer({
    Key? key,
    required this.campaign,
    this.onDismiss,
    this.onCTAClick,
  }) : super(key: key);

  @override
  State<TooltipNudgeRenderer> createState() => _TooltipNudgeRendererState();
}

class _TooltipNudgeRendererState extends State<TooltipNudgeRenderer>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;
  
  // Target element bounds
  Rect? _targetRect;
  bool _hasScrolledToTarget = false;

  @override
  void initState() {
    super.initState();
    final config = widget.campaign.config;
    final duration = config['animationDuration'] as int? ?? 250;
    
    _controller = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: duration),
    );

    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutBack),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );

    // Find target element and scroll if needed
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _resolveTargetElement();
    });
  }

  void _resolveTargetElement() {
    final config = widget.campaign.config;
    
    // FIX: Check multiple paths for targetElementId
    final tooltipConfig = config['tooltipConfig'] as Map<String, dynamic>? ?? 
                          config['tooltip_config'] as Map<String, dynamic>? ?? 
                          config;
    
    final targetId = tooltipConfig['targetElementId']?.toString() ?? 
                     tooltipConfig['target_element_id']?.toString() ??
                     config['targetElementId']?.toString() ?? 
                     config['target_element_id']?.toString();
    
    debugPrint('InAppNinja: 🔍 Looking for targetElementId: $targetId');
    debugPrint('InAppNinja: 📦 Config keys: ${config.keys.toList()}');
    debugPrint('InAppNinja: 📦 TooltipConfig keys: ${tooltipConfig.keys.toList()}');
    
    if (targetId != null) {
      final targetContext = AppNinja.getTargetContext(targetId);
      if (targetContext != null) {
        final renderBox = targetContext.findRenderObject() as RenderBox?;
        if (renderBox != null && renderBox.hasSize) {
          final offset = renderBox.localToGlobal(Offset.zero);
          setState(() {
            _targetRect = Rect.fromLTWH(
              offset.dx,
              offset.dy,
              renderBox.size.width,
              renderBox.size.height,
            );
          });
          
          // 🔥 DEBUG: Print target rect
          debugPrint('🎯 Target Found! _targetRect: $_targetRect');
          
          // Auto-scroll if target is not in viewport
          if (!_hasScrolledToTarget) {
            _scrollToTargetIfNeeded(targetContext);
            _hasScrolledToTarget = true;
          }
          
          _controller.forward();
        }
      } else {
        // No target found, show centered
        _controller.forward();
      }
    } else {
      // No target specified
      _controller.forward();
    }
  }

  void _scrollToTargetIfNeeded(BuildContext targetContext) {
    // Ensure the element is visible by scrolling
    Scrollable.ensureVisible(
      targetContext,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      alignment: 0.5, // Center the target
    ).then((_) {
      // Re-resolve position after scroll
      Future.delayed(const Duration(milliseconds: 100), () {
        _resolveTargetElement();
      });
    });
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
    debugPrint('InAppNinja: 🎯 Tooltip Action: $action, data: $data');
    
    switch (action) {
      case 'dismiss':
      case 'close':
        _handleDismiss();
        break;
      case 'deeplink':
      case 'open_link':
        final url = data?['url'] as String?;
        if (url != null && url.isNotEmpty) {
          try {
            final uri = Uri.parse(url);
            final isWebUrl = uri.scheme == 'http' || uri.scheme == 'https';
            
            if (isWebUrl) {
              if (await canLaunchUrl(uri)) {
                await launchUrl(uri, mode: LaunchMode.externalApplication);
              }
            } else {
              // Custom app deeplink - try directly
              await launchUrl(uri, mode: LaunchMode.externalApplication);
            }
          } catch (e) {
            debugPrint('InAppNinja: ❌ Deeplink error: $e');
          }
          widget.onCTAClick?.call(action, {'url': url, ...?data});
        }
        break;
      case 'navigate':
        final route = data?['route'] as String? ?? data?['screen'] as String?;
        widget.onCTAClick?.call(action, {'route': route, ...?data});
        break;
      case 'interface':
        final interfaceId = data?['interfaceId'] as String?;
        if (interfaceId != null && interfaceId.isNotEmpty) {
          _showInterface(interfaceId);
        }
        break;
      default:
        widget.onCTAClick?.call(action, data);
    }
  }

  void _showInterface(String interfaceId) {
    InterfaceHandler.show(
      interfaceId: interfaceId,
      parentCampaign: widget.campaign,
      context: context,
      onDismiss: widget.onDismiss,
      onCTAClick: widget.onCTAClick,
    );
  }


  @override
  Widget build(BuildContext context) {
    final config = widget.campaign.config;
    
    // FIX #3: Properly merge tooltipConfig - try multiple sources
    final tooltipConfig = config['tooltipConfig'] as Map<String, dynamic>? 
        ?? config['tooltip_config'] as Map<String, dynamic>?
        ?? config;
    
    // FIX #4: Read layers from campaign.layers (correct source), fallback to config
    final rawLayers = widget.campaign.layers ?? config['layers'] as List<dynamic>? ?? [];
    
    // 🔥 DEBUG: Print ALL raw layers before filtering
    debugPrint('=== RAW LAYERS DEBUG ===');
    debugPrint('Total raw layers: ${rawLayers.length}');
    for (var i = 0; i < rawLayers.length; i++) {
      final l = rawLayers[i] as Map<String, dynamic>?;
      final type = l?['type']?.toString() ?? 'unknown';
      final name = l?['name']?.toString() ?? 'unnamed';
      final visible = l?['visible'];
      final parent = l?['parent']?.toString();
      debugPrint('  [$i] type: $type, name: "$name", visible: $visible, parent: $parent');
    }
    debugPrint('========================');
    
    // Filter out container layers, get only renderable child layers
    // Also filter out invisible layers
    final layers = rawLayers.where((l) {
      final layer = l as Map<String, dynamic>?;
      final type = layer?['type']?.toString() ?? '';
      final visible = layer?['visible'] != false; // Default true if not specified
      return type != 'container' && type != 'tooltip' && visible;
    }).toList();
    
    debugPrint('📦 Filtered layers for rendering: ${layers.length}');
    
    // Device scaling
    final deviceWidth = MediaQuery.of(context).size.width;
    const double designWidth = 393.0; // iPhone 14 Pro baseline
    final scaleRatio = deviceWidth / designWidth;
    
    // Position
    final position = tooltipConfig['position']?.toString() ?? 'bottom';
    // FIX: Scale offsets by scaleRatio for pixel-perfect positioning across devices
    final rawOffsetX = (tooltipConfig['offsetX'] as num?)?.toDouble() ?? 0;
    final rawOffsetY = (tooltipConfig['offsetY'] as num?)?.toDouble() ?? 0;
    final offsetX = rawOffsetX * scaleRatio;
    final offsetY = rawOffsetY * scaleRatio;
    
    // Target styling - FIX: Scale by scaleRatio!
    final rawTargetBorderRadius = (tooltipConfig['targetBorderRadius'] as num?)?.toDouble() ?? 8;
    final targetBorderRadius = rawTargetBorderRadius * scaleRatio;
    final targetBorderColor = NinjaLayerUtils.parseColor(tooltipConfig['targetBorderColor']) ?? Colors.blue;
    final rawTargetBorderWidth = (tooltipConfig['targetBorderWidth'] as num?)?.toDouble() ?? 2;
    final targetBorderWidth = rawTargetBorderWidth * scaleRatio;
    
    // Tooltip body - Handle widthMode like dashboard!
    final widthMode = tooltipConfig['widthMode']?.toString() ?? 'custom';
    final rawWidth = (tooltipConfig['width'] as num?)?.toDouble() ?? 280;
    // Only use fixed width if mode is 'custom'
    final double? tooltipWidth = widthMode == 'custom' ? rawWidth * scaleRatio : null;
    
    debugPrint('📐 widthMode: $widthMode, rawWidth: $rawWidth, tooltipWidth: $tooltipWidth');
    
    final tooltipBgColor = NinjaLayerUtils.parseColor(tooltipConfig['backgroundColor']) ?? const Color(0xFF1F2937);
    final backgroundOpacity = (tooltipConfig['backgroundOpacity'] as num?)?.toDouble() ?? 1.0;
    final backgroundImageUrl = tooltipConfig['backgroundImageUrl']?.toString();
    final backgroundSize = tooltipConfig['backgroundSize']?.toString() ?? 'cover';
    // SCALE borderRadius and padding!
    final rawBorderRadius = (tooltipConfig['borderRadius'] as num?)?.toDouble() ?? 12;
    final borderRadius = rawBorderRadius * scaleRatio;
    final rawPadding = (tooltipConfig['padding'] as num?)?.toDouble() ?? 0;
    final padding = rawPadding * scaleRatio;
    
    // Height (optional)
    final heightMode = tooltipConfig['heightMode']?.toString() ?? 'auto';
    final rawHeight = (tooltipConfig['height'] as num?)?.toDouble();
    final tooltipHeight = heightMode == 'custom' && rawHeight != null ? rawHeight * scaleRatio : null;
    
    // Shadow - SCALE blur and offset!
    final shadowEnabled = tooltipConfig['shadowEnabled'] != false;
    final rawShadowBlur = (tooltipConfig['shadowBlur'] as num?)?.toDouble() ?? 25;
    final shadowBlur = rawShadowBlur * scaleRatio;
    final shadowOpacity = (tooltipConfig['shadowOpacity'] as num?)?.toDouble() ?? 0.2;
    // FIX: Read shadow offset from config instead of hardcoded (0, 4)
    final rawShadowOffsetX = (tooltipConfig['shadowOffsetX'] as num?)?.toDouble() ?? 0;
    final rawShadowOffsetY = (tooltipConfig['shadowOffsetY'] as num?)?.toDouble() ?? 4;
    final shadowOffsetX = rawShadowOffsetX * scaleRatio;
    final shadowOffsetY = rawShadowOffsetY * scaleRatio;
    
    // Arrow - SCALE size!
    final arrowEnabled = tooltipConfig['arrowEnabled'] != false;
    final rawArrowSize = (tooltipConfig['arrowSize'] as num?)?.toDouble() ?? 10;
    final arrowSize = rawArrowSize * scaleRatio;
    final arrowPositionPercent = (tooltipConfig['arrowPositionPercent'] as num?)?.toDouble() ?? 50;
    final arrowRoundness = (tooltipConfig['arrowRoundness'] as num?)?.toDouble() ?? 0;
    
    // Overlay
    final overlayEnabled = tooltipConfig['overlayEnabled'] != false;
    final overlayColor = NinjaLayerUtils.parseColor(tooltipConfig['overlayColor']) ?? Colors.black;
    final overlayOpacity = (tooltipConfig['overlayOpacity'] as num?)?.toDouble() ?? 0.5;
    
    // Behavior settings
    final closeOnOutsideClick = tooltipConfig['closeOnOutsideClick'] != false; // Default true
    final closeOnTargetClick = tooltipConfig['closeOnTargetClick'] == true; // Default false
    final autoScrollToTarget = tooltipConfig['autoScrollToTarget'] == true; // Default false (requires Scrollable widget access)

    // 🔥 DEBUG: Print all parsed values
    debugPrint('=== TOOLTIP CONFIG DEBUG ===');
    debugPrint('deviceWidth: $deviceWidth, scaleRatio: $scaleRatio');
    debugPrint('rawWidth: $rawWidth → scaledWidth: $tooltipWidth');
    debugPrint('position: $position, offsetX: $offsetX, offsetY: $offsetY');
    debugPrint('bgColor: $tooltipBgColor, bgOpacity: $backgroundOpacity');
    debugPrint('shadowEnabled: $shadowEnabled, blur: $shadowBlur, opacity: $shadowOpacity');
    debugPrint('arrowEnabled: $arrowEnabled, size: $arrowSize');
    debugPrint('overlayColor: $overlayColor, overlayOpacity: $overlayOpacity');
    debugPrint('layers count: ${layers.length}');
    debugPrint('============================');
    debugPrint('🔍 overlayEnabled: $overlayEnabled, _targetRect: $_targetRect');
    if (_targetRect != null) {
      final screenHeight = MediaQuery.of(context).size.height;
      final bottomValue = screenHeight - _targetRect!.top + arrowSize + 4 - offsetY;
      debugPrint('📐 Screen height: $screenHeight, bottom value: $bottomValue');
    }

    return Material(
      color: Colors.transparent,
      child: Stack(
        children: [
          // Overlay with Spotlight (cutout for target)
          if (overlayEnabled)
            GestureDetector(
              // Only dismiss on outside click if setting is enabled
              onTap: closeOnOutsideClick ? _handleDismiss : null,
              child: _targetRect != null
                  ? CustomPaint(
                      size: MediaQuery.of(context).size,
                      painter: _SpotlightPainter(
                        targetRect: _targetRect!,
                        overlayColor: overlayColor.withOpacity(overlayOpacity),
                        targetBorderRadius: targetBorderRadius,
                        targetBorderColor: targetBorderColor,
                        targetBorderWidth: targetBorderWidth,
                      ),
                    )
                  : Container(
                      color: overlayColor.withOpacity(overlayOpacity),
                    ),
            ),
          
          // Clickable target area (for closeOnTargetClick)
          if (_targetRect != null && closeOnTargetClick)
            Positioned(
              left: _targetRect!.left,
              top: _targetRect!.top,
              width: _targetRect!.width,
              height: _targetRect!.height,
              child: GestureDetector(
                onTap: _handleDismiss,
                child: const ColoredBox(color: Colors.transparent),
              ),
            ),

          // Tooltip Positioned
          if (_targetRect != null)
            Positioned(
              // Use rawWidth for positioning (always available), but tooltipWidth for rendering
              left: _calculateTooltipX(position, _targetRect!, tooltipWidth ?? rawWidth * scaleRatio, arrowSize, offsetX, scaleRatio),
              // For 'top': position anchor at target.top, then shift UP by tooltip height
              // FIX: No gap - arrow should touch target directly when offsetY=0
              top: position == 'top' 
                  ? (_targetRect!.top + offsetY)
                  : _calculateTooltipY(position, _targetRect!, 0, offsetY, scaleRatio),
              child: position == 'top'
                  // For 'top': shift entire tooltip UP by its own height using FractionalTranslation
                  ? FractionalTranslation(
                      translation: const Offset(0, -1), // Move up by 100% of widget height
                      child: FadeTransition(
                        opacity: _fadeAnimation,
                        child: ScaleTransition(
                          scale: _scaleAnimation,
                          alignment: Alignment.bottomCenter,
                          child: _buildTooltipBody(
                            layers,
                            position,
                            tooltipWidth,
                            tooltipBgColor,
                            backgroundOpacity,
                            borderRadius,
                            padding,
                            arrowEnabled,
                            arrowSize,
                            arrowRoundness,
                            arrowPositionPercent, // Arrow position along edge
                            shadowEnabled,
                            shadowBlur,
                            shadowOpacity,
                            shadowOffsetX, // FIX: Add missing params
                            shadowOffsetY,
                            tooltipHeight,
                            scaleRatio,
                            backgroundImageUrl, // FIX: Pass background image
                            backgroundSize,
                          ),
                        ),
                      ),
                    )
                  // For other positions: normal positioning
                  : FadeTransition(
                      opacity: _fadeAnimation,
                      child: ScaleTransition(
                        scale: _scaleAnimation,
                        alignment: _getScaleAlignment(position),
                        child: _buildTooltipBody(
                          layers,
                          position,
                          tooltipWidth,
                          tooltipBgColor,
                          backgroundOpacity,
                          borderRadius,
                          padding,
                          arrowEnabled,
                          arrowSize,
                          arrowRoundness,
                          arrowPositionPercent, // Arrow position along edge
                          shadowEnabled,
                          shadowBlur,
                          shadowOpacity,
                          shadowOffsetX, // FIX: Pass shadow offset
                          shadowOffsetY,
                          tooltipHeight,
                          scaleRatio,
                          backgroundImageUrl, // FIX: Pass background image
                          backgroundSize,
                        ),
                      ),
                    ),
            )
          else
            // Centered fallback when no target
            Center(
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: ScaleTransition(
                  scale: _scaleAnimation,
                  child: _buildTooltipBody(
                    layers,
                    'bottom',
                    tooltipWidth,
                    tooltipBgColor,
                    backgroundOpacity,
                    borderRadius,
                    padding,
                    arrowEnabled,
                    arrowSize,
                    arrowRoundness,
                    arrowPositionPercent, // Arrow position along edge
                    shadowEnabled,
                    shadowBlur,
                    shadowOpacity,
                    shadowOffsetX, // FIX: Pass shadow offset
                    shadowOffsetY,
                    tooltipHeight,
                    scaleRatio,
                    backgroundImageUrl, // FIX: Pass background image
                    backgroundSize,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTooltipBody(
    List<dynamic> layers,
    String position,
    double? width, // Nullable for auto/fitContent modes
    Color bgColor,
    double backgroundOpacity,
    double borderRadius,
    double padding,
    bool arrowEnabled,
    double arrowSize,
    double arrowRoundness, // Arrow roundness percentage (0-100)
    double arrowPositionPercent, // Arrow position along edge (0-100%)
    bool shadowEnabled,
    double shadowBlur,
    double shadowOpacityVal,
    double shadowOffsetX, // FIX: Configurable shadow offset
    double shadowOffsetY,
    double? height,
    double scaleRatio, // For scaling layer content
    String? backgroundImageUrl, // FIX: Add background image support
    String backgroundSize, // FIX: Add background size (cover, contain, etc)
  ) {
    // Apply opacity to bgColor
    final effectiveBgColor = bgColor.withOpacity(backgroundOpacity);
    
    // FIX: Calculate effective dimensions for absolute positioning
    final effectiveWidth = (width ?? 280 * scaleRatio) - padding * 2;
    final effectiveHeight = (height ?? 100 * scaleRatio) - padding * 2;
    
    // FIX: Parse background size to BoxFit
    final backgroundFit = backgroundSize == 'contain' ? BoxFit.contain
                        : backgroundSize == 'fill' ? BoxFit.fill
                        : BoxFit.cover; // Default to cover
    
    // Build the main tooltip container with clipping to prevent overflow
    final tooltipContainer = ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      clipBehavior: Clip.hardEdge, // Clip any overflowing content
      child: Container(
        width: width,
        // FIX: Use explicit height or calculated height for Stack children
        height: height ?? (effectiveHeight + padding * 2),
        padding: EdgeInsets.all(padding),
        decoration: BoxDecoration(
          color: effectiveBgColor,
          borderRadius: BorderRadius.circular(borderRadius),
          // FIX: Add background image support
          image: backgroundImageUrl != null && backgroundImageUrl.isNotEmpty
            ? DecorationImage(
                image: NetworkImage(backgroundImageUrl),
                fit: backgroundFit,
              )
            : null,
          boxShadow: shadowEnabled ? [
            BoxShadow(
              color: Colors.black.withOpacity(shadowOpacityVal),
              blurRadius: shadowBlur,
              offset: Offset(shadowOffsetX, shadowOffsetY), // FIX: Now configurable
            ),
          ] : null,
        ),
        // FIX: Use Stack with absolute positioned layers (matching Dashboard)
        child: SizedBox(
          width: effectiveWidth,
          height: effectiveHeight,
          child: Stack(
            clipBehavior: Clip.none,
            children: _buildAbsolutePositionedLayers(
              layers, 
              scaleRatio, 
              effectiveWidth,
              effectiveHeight,
            ),
          ),
        ),
      ),
    );

    // If no arrow, return just the container
    Widget result;
    if (!arrowEnabled) {
      result = tooltipContainer;
    } else {
      // Arrow positioning based on position and arrowPositionPercent
      // positionPercent: 0 = start, 50 = center, 100 = end
      result = _buildTooltipWithArrow(
        tooltipContainer,
        effectiveBgColor,
        position,
        arrowSize,
        arrowRoundness,
        arrowPositionPercent,
        width, // FIX: Pass width for pixel-based arrow positioning
      );
    }

    // ✅ FEATURE: Support Container Actions
    final config = widget.campaign.config;
    final tooltipActionConfig = (config['tooltipConfig'] as Map<String, dynamic>?)?['action'] 
         ?? (config['tooltip_config'] as Map<String, dynamic>?)?['action']
         ?? config['action'];

    if (tooltipActionConfig != null) {
       dynamic actionType = 'default';
       Map<String, dynamic> actionData = {};

       if (tooltipActionConfig is String) {
         actionType = tooltipActionConfig;
       } else if (tooltipActionConfig is Map) {
         actionType = tooltipActionConfig['type'] ?? 'default';
         actionData = Map<String, dynamic>.from(tooltipActionConfig);
       }

       return GestureDetector(
          onTap: () => _handleAction(actionType.toString(), actionData),
          child: result,
       );
    }

    return result;
  }

  // Build tooltip with positioned arrow using Stack
  Widget _buildTooltipWithArrow(
    Widget tooltipContainer,
    Color arrowColor,
    String position,
    double arrowSize,
    double arrowRoundness,
    double arrowPositionPercent,
    double? tooltipWidth, // FIX: Added for pixel-based positioning
  ) {
    // For top/bottom: arrow is positioned horizontally
    // For left/right: arrow is positioned vertically
    final isVertical = position == 'top' || position == 'bottom';
    
    // FIX: Convert percentage to pixels for consistent Dashboard/SDK positioning
    // arrowPositionPx = (percent / 100) * width, centered with arrow width
    final effectiveWidth = tooltipWidth ?? 280;
    final arrowPositionPx = (arrowPositionPercent / 100) * effectiveWidth;
    // Offset to center the arrow at this position (arrow width is arrowSize * 2)
    final arrowLeftPadding = arrowPositionPx - arrowSize;
    
    Widget arrowWidget = _buildArrow(
      arrowColor, 
      arrowSize, 
      _getArrowDirection(position),
      roundness: arrowRoundness,
    );

    switch (position) {
      case 'bottom': // Tooltip below target, arrow points UP at top
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // FIX: Use Padding for pixel-based positioning instead of Align
            Padding(
              padding: EdgeInsets.only(left: arrowLeftPadding.clamp(0, effectiveWidth - arrowSize * 2)),
              child: arrowWidget,
            ),
            tooltipContainer,
          ],
        );
      case 'top': // Tooltip above target, arrow points DOWN at bottom
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            tooltipContainer,
            // FIX: Use Padding for pixel-based positioning instead of Align
            Padding(
              padding: EdgeInsets.only(left: arrowLeftPadding.clamp(0, effectiveWidth - arrowSize * 2)),
              child: arrowWidget,
            ),
          ],
        );
      case 'right': // Tooltip right of target, arrow points LEFT on left side
        // For vertical positioning, calculate top padding
        final arrowTopPaddingRight = arrowPositionPx - arrowSize;
        return Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // FIX: Use Padding for pixel-based positioning instead of Align
            Padding(
              padding: EdgeInsets.only(top: arrowTopPaddingRight.clamp(0, effectiveWidth - arrowSize * 2)),
              child: arrowWidget,
            ),
            tooltipContainer,
          ],
        );
      case 'left': // Tooltip left of target, arrow points RIGHT on right side
        // For vertical positioning, calculate top padding
        final arrowTopPaddingLeft = arrowPositionPx - arrowSize;
        return Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            tooltipContainer,
            // FIX: Use Padding for pixel-based positioning instead of Align
            Padding(
              padding: EdgeInsets.only(top: arrowTopPaddingLeft.clamp(0, effectiveWidth - arrowSize * 2)),
              child: arrowWidget,
            ),
          ],
        );
      default:
        return tooltipContainer;
    }
  }

  ArrowDirection _getArrowDirection(String position) {
    switch (position) {
      case 'bottom': return ArrowDirection.up;
      case 'top': return ArrowDirection.down;
      case 'left': return ArrowDirection.right;
      case 'right': return ArrowDirection.left;
      default: return ArrowDirection.down;
    }
  }

  // ============ ABSOLUTE POSITIONING (Matching Dashboard) ============
  
  /// Parse dynamic value to double, handling String (with unit suffixes) and num types
  double? _parseDouble(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    // Strip common unit suffixes (px, %, pt, em, rem)
    String strVal = value.toString().trim().toLowerCase();
    if (strVal.isEmpty) return null;
    strVal = strVal
        .replaceAll('px', '')
        .replaceAll('%', '')
        .replaceAll('pt', '')
        .replaceAll('em', '')
        .replaceAll('rem', '')
        .trim();
    return double.tryParse(strVal);
  }

  /// Build layers with absolute positioning (matching Dashboard renderLayerAbsolute)
  List<Widget> _buildAbsolutePositionedLayers(
    List<dynamic> layers, 
    double scaleRatio, 
    double tooltipWidth, 
    double tooltipHeight,
  ) {
    const designWidth = 393.0;
    const designHeight = 852.0;
    
    if (layers.isEmpty) {
      return [
        Positioned(
          left: 0,
          top: 0,
          child: Text(
            'Tooltip Content',
            style: TextStyle(color: Colors.white, fontSize: 14 * scaleRatio),
          ),
        ),
      ];
    }
    
    debugPrint('🎨 Building ${layers.length} absolute positioned layers...');
    
    // Sort by zIndex (lower = behind)
    final sortedLayers = layers.cast<Map<String, dynamic>>().toList()
      ..sort((a, b) {
        final zA = (_parseDouble(a['style']?['zIndex']) ?? 0).toInt();
        final zB = (_parseDouble(b['style']?['zIndex']) ?? 0).toInt();
        return zA.compareTo(zB);
      });
    
    final widgets = <Widget>[];
    
    for (final layer in sortedLayers) {
      final type = layer['type']?.toString() ?? 'text';
      final content = layer['content'] as Map<String, dynamic>? ?? {};
      final style = layer['style'] as Map<String, dynamic>? ?? {};
      final visible = layer['visible'] as bool? ?? true;
      
      if (!visible) continue;
      if (type == 'text' && (content['text']?.toString().isEmpty ?? true)) continue;
      
      debugPrint('  → Layer type: $type, style keys: ${style.keys.toList()}');
      debugPrint('    Raw width: ${style['width']} (${style['width'].runtimeType}), height: ${style['height']} (${style['height'].runtimeType})');
      
      // Build layer content
      Widget? child;
      switch (type) {
        case 'text':
          child = _buildTextLayerContent(content, style, scaleRatio);
          break;
        case 'button':
          child = _buildButtonLayerContent(content, style, scaleRatio);
          break;
        case 'image':
        case 'media':
          child = _buildImageLayerContent(content, style, scaleRatio);
          break;
        default:
          debugPrint('    ⚠️ Unknown layer type: $type');
          continue;
      }
      
      if (child == null) continue;

      // ✅ PARITY FIX: Wrap ALL layers in interaction builder
      child = _buildInteraction(child, layer);
      
      // Position calculation - match Dashboard's toPercentX/Y approach
      // Dashboard: left = (rawLeft / 393) * 100% → CSS applies percentage to container
      // SDK: We calculate the equivalent pixel position within the tooltip
      final rawLeft = _parseDouble(style['left'] ?? style['x']) ?? 0;
      final rawTop = _parseDouble(style['top'] ?? style['y']) ?? 0;
      // Convert from design coordinates to tooltip coordinates
      final left = (rawLeft / designWidth) * tooltipWidth;
      final top = (rawTop / designHeight) * tooltipHeight;
      
      // Dimension calculation - try multiple sources
      // Style might store dimensions as numbers, strings, or in a 'size' sub-object
      final sizeObj = style['size'] as Map<String, dynamic>?;
      final widthValue = style['width'] ?? sizeObj?['width'];
      final heightValue = style['height'] ?? sizeObj?['height'];
      
      // FIX: Detect unit from value string itself (e.g., "60%" or "100px")
      final widthIsPercent = widthValue?.toString().contains('%') ?? false;
      final heightIsPercent = heightValue?.toString().contains('%') ?? false;
      
      final rawWidth = _parseDouble(widthValue);
      final rawHeight = _parseDouble(heightValue);
      
      double? width;
      // FIX: Detect 'auto' string and treat as null (let child size itself)
      final isAutoWidth = widthValue?.toString().toLowerCase() == 'auto';
      if (!isAutoWidth && rawWidth != null) {
        // Use detected unit from value, fallback to explicit widthUnit
        final isPercent = widthIsPercent || (style['widthUnit']?.toString() == '%');
        width = isPercent 
          ? (rawWidth / 100) * tooltipWidth 
          : rawWidth * scaleRatio;
      }
      // FIX: Removed default width for media - let it use intrinsic size like Dashboard
      
      double? height;
      // FIX: Detect 'auto' string and treat as null (let child size itself)
      final isAutoHeight = heightValue?.toString().toLowerCase() == 'auto';
      if (!isAutoHeight && rawHeight != null) {
        // Use detected unit from value, fallback to explicit heightUnit
        final isPercent = heightIsPercent || (style['heightUnit']?.toString() == '%');
        height = isPercent
          ? (rawHeight / 100) * tooltipHeight
          : rawHeight * scaleRatio;
      }
      // FIX: Removed default height for media - let it use intrinsic size like Dashboard
      
      debugPrint('    📍 Position: left=$left, top=$top, width=$width, height=$height');
      
      widgets.add(Positioned(
        left: left,
        top: top,
        width: width,
        height: height,
        child: child,
      ));
    }
    
    return widgets.isNotEmpty ? widgets : [
      Positioned(
        left: 0,
        top: 0,
        child: Text(
          'No renderable layers',
          style: TextStyle(color: Colors.white70, fontSize: 12 * scaleRatio),
        ),
      ),
    ];
  }

  // ============ LAYER CONTENT BUILDERS (No positioning, just content) ============
  
  Widget _buildTextLayerContent(Map<String, dynamic> content, Map<String, dynamic> style, double scaleRatio) {
    final text = content['text']?.toString() ?? '';
    final fontSizeVal = content['fontSize'] ?? style['fontSize'];
    final rawFontSize = fontSizeVal is num ? fontSizeVal.toDouble() : (double.tryParse(fontSizeVal?.toString() ?? '') ?? 14);
    final fontSize = rawFontSize * scaleRatio;
    final textColor = NinjaLayerUtils.parseColor(content['textColor']) ?? NinjaLayerUtils.parseColor(style['color']) ?? Colors.white;
    // FIX: Match Dashboard - content.fontWeight first, fallback to style
    final fontWeight = NinjaLayerUtils.parseFontWeight(content['fontWeight']) 
                      ?? NinjaLayerUtils.parseFontWeight(style['fontWeight'])
                      ?? FontWeight.w400;
    // FIX: Match Dashboard - content.fontFamily first, fallback to style
    final fontFamily = content['fontFamily']?.toString() ?? style['fontFamily']?.toString();
    final lineHeightVal = content['lineHeight'] ?? style['lineHeight'];
    final lineHeight = lineHeightVal is num ? lineHeightVal.toDouble() : (double.tryParse(lineHeightVal?.toString() ?? '') ?? 1.4);
    // FIX: Add textAlign support to match Dashboard TextRenderer
    final textAlignStr = content['textAlign']?.toString() ?? style['textAlign']?.toString() ?? 'left';
    final textAlign = textAlignStr == 'center' ? TextAlign.center
                    : textAlignStr == 'right' ? TextAlign.right
                    : textAlignStr == 'justify' ? TextAlign.justify
                    : TextAlign.left;
    
    // FIX: Add text shadow support with proper scaling
    final rawShadowX = _parseDouble(content['textShadowX']) ?? 0;
    final rawShadowY = _parseDouble(content['textShadowY']) ?? 0;
    final rawShadowBlur = _parseDouble(content['textShadowBlur']) ?? 0;
    final shadowColor = NinjaLayerUtils.parseColor(content['textShadowColor']) ?? Colors.black;
    final hasShadow = rawShadowX != 0 || rawShadowY != 0 || rawShadowBlur != 0;
    
    // Scale shadow values
    final shadowX = rawShadowX * scaleRatio;
    final shadowY = rawShadowY * scaleRatio;
    final shadowBlur = rawShadowBlur * scaleRatio;
    
    // FIX: Use Google Fonts for proper font loading (same as button)
    final baseTextStyle = TextStyle(
      color: textColor,
      fontSize: fontSize,
      fontWeight: fontWeight,
      height: lineHeight,
      shadows: hasShadow ? [
        Shadow(
          offset: Offset(shadowX, shadowY),
          blurRadius: shadowBlur,
          color: shadowColor,
        ),
      ] : null,
    );
    
    // Try to load the font via Google Fonts, fallback to base style
    TextStyle textStyle;
    if (fontFamily != null && fontFamily.isNotEmpty) {
      final googleFont = NinjaLayerUtils.getGoogleFont(fontFamily, textStyle: baseTextStyle);
      textStyle = googleFont ?? baseTextStyle;
    } else {
      textStyle = baseTextStyle;
    }
    
    debugPrint('🔤 Text fontFamily: $fontFamily, fontWeight: $fontWeight, fontSize: $fontSize');
    
    return Text(
      text,
      softWrap: true,
      textAlign: textAlign,
      style: textStyle,
    );
  }

  Widget _buildButtonLayerContent(Map<String, dynamic> content, Map<String, dynamic> style, double scaleRatio) {
    final label = content['label']?.toString() ?? 'Button';
    // FIX: Match Dashboard - prioritize style.backgroundColor, fallback to content.themeColor
    final bgColor = NinjaLayerUtils.parseColor(style['backgroundColor']) 
                    ?? NinjaLayerUtils.parseColor(content['themeColor'])
                    ?? Colors.blue;
    final textColor = NinjaLayerUtils.parseColor(content['textColor']) ?? Colors.white;
    final fontSizeVal = content['fontSize'];
    final rawFontSize = fontSizeVal is num ? fontSizeVal.toDouble() : (double.tryParse(fontSizeVal?.toString() ?? '') ?? 14);
    final fontSize = rawFontSize * scaleRatio;
    final action = content['action'] as Map<String, dynamic>?;
    // FIX: Match Dashboard - ButtonEditor saves to content.fontFamily, not style.fontFamily
    final fontFamily = content['fontFamily']?.toString() ?? style['fontFamily']?.toString();
    // FIX: ButtonEditor saves fontWeight to content.fontWeight, not style
    final fontWeight = NinjaLayerUtils.parseFontWeight(content['fontWeight']) 
                       ?? NinjaLayerUtils.parseFontWeight(style['fontWeight'])
                       ?? FontWeight.w500; // Match Dashboard default 'medium'
    final borderRadiusVal = style['borderRadius'];
    final rawBorderRadius = borderRadiusVal is num ? borderRadiusVal.toDouble() : (double.tryParse(borderRadiusVal?.toString() ?? '') ?? 8);
    final borderRadius = rawBorderRadius * scaleRatio;
    final paddingTopVal = style['paddingTop'];
    final paddingRightVal = style['paddingRight'];
    final paddingBottomVal = style['paddingBottom'];
    final paddingLeftVal = style['paddingLeft'];
    final rawPaddingTop = paddingTopVal is num ? paddingTopVal.toDouble() : (double.tryParse(paddingTopVal?.toString() ?? '') ?? 0);
    final rawPaddingRight = paddingRightVal is num ? paddingRightVal.toDouble() : (double.tryParse(paddingRightVal?.toString() ?? '') ?? 0);
    final rawPaddingBottom = paddingBottomVal is num ? paddingBottomVal.toDouble() : (double.tryParse(paddingBottomVal?.toString() ?? '') ?? 0);
    final rawPaddingLeft = paddingLeftVal is num ? paddingLeftVal.toDouble() : (double.tryParse(paddingLeftVal?.toString() ?? '') ?? 0);
    
    // FIX: Use Google Fonts for proper font loading
    final baseTextStyle = TextStyle(
      fontSize: fontSize, 
      fontWeight: fontWeight,
      color: textColor,
    );
    
    debugPrint('🔤 Button fontFamily raw: style=${style['fontFamily']}, content=${content['fontFamily']}');
    debugPrint('🔤 Button fontWeight raw: style=${style['fontWeight']}, content=${content['fontWeight']}');
    debugPrint('🔤 Button resolved: fontFamily=$fontFamily, fontWeight=$fontWeight, fontSize=$fontSize');
    
    // Try to load the font via Google Fonts, fallback to base style
    TextStyle textStyle;
    if (fontFamily != null && fontFamily.isNotEmpty) {
      final googleFont = NinjaLayerUtils.getGoogleFont(fontFamily, textStyle: baseTextStyle);
      debugPrint('🔤 Google Font loaded: ${googleFont != null ? 'YES' : 'NO (fallback to default)'}');
      textStyle = googleFont ?? baseTextStyle;
    } else {
      textStyle = baseTextStyle;
    }
    
    return ElevatedButton(
      onPressed: () {
        if (action != null) {
          final actionType = action['type']?.toString() ?? 'dismiss';
          _handleAction(actionType, action);
        } else {
          _handleDismiss();
        }
      },
      style: ElevatedButton.styleFrom(
        backgroundColor: bgColor,
        foregroundColor: textColor,
        // FIX: Remove minimum size constraints to allow proper sizing
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        // FIX: Zero padding by default to match Dashboard
        padding: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(borderRadius),
        ),
        // FIX: Center text alignment
        alignment: Alignment.center,
      ),
      // FIX: Center the text and apply Google Fonts style
      child: Center(
        child: Text(
          label, 
          textAlign: TextAlign.center,
          style: textStyle,
        ),
      ),
    );
  }

  Widget _buildImageLayerContent(Map<String, dynamic> content, Map<String, dynamic> style, double scaleRatio) {
    final imageUrl = content['imageUrl']?.toString() ?? content['url']?.toString();
    final rawBorderRadiusVal = style['borderRadius'];
    final rawBorderRadius = rawBorderRadiusVal is num ? rawBorderRadiusVal.toDouble() : (double.tryParse(rawBorderRadiusVal?.toString() ?? '') ?? 0);
    final borderRadius = rawBorderRadius * scaleRatio;
    final objectFitStr = style['objectFit']?.toString() ?? 'contain';
    final objectFit = objectFitStr == 'cover' ? BoxFit.cover 
                     : objectFitStr == 'fill' ? BoxFit.fill
                     : BoxFit.contain;
    
    if (imageUrl == null || imageUrl.isEmpty) {
      return const SizedBox.shrink();
    }
    
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: Image.network(
        imageUrl,
        // FIX: Use null instead of infinity - Positioned constraints will handle sizing
        // If Positioned has width/height, they'll constrain the image
        // If not, image uses its intrinsic size
        fit: objectFit,
        errorBuilder: (_, __, ___) => const Icon(Icons.broken_image, color: Colors.white),
      ),
    );
  }

  List<Widget> _buildLayers(List<dynamic> layers, double scaleRatio) {
    if (layers.isEmpty) {
      // Default content with scaled font
      return [
        Text(
          'Tooltip Content',
          style: TextStyle(color: Colors.white, fontSize: 14 * scaleRatio),
        ),
      ];
    }
    
    // 🔥 DEBUG: Print layer info
    debugPrint('🎨 Building ${layers.length} layers (scaleRatio: $scaleRatio)...');
    
    final widgets = <Widget>[];
    
    for (final layerData in layers) {
      final layer = layerData as Map<String, dynamic>;
      final type = layer['type']?.toString() ?? 'text';
      final content = layer['content'] as Map<String, dynamic>? ?? {};
      final style = layer['style'] as Map<String, dynamic>? ?? {};
      
      debugPrint('  → Layer type: $type');
      debugPrint('    Content keys: ${content.keys.toList()}');
      
      // Skip layers with no content or container types
      if (content.isEmpty && type == 'text') {
        debugPrint('    ⚠️ Skipping empty text layer');
        continue;
      }
      
      Widget? widget;
      switch (type) {
        case 'text':
          widget = _buildTextLayer(content, style, scaleRatio);
          break;
        case 'button':
          widget = _buildButtonLayer(content, style, scaleRatio);
          break;
        case 'image':
        case 'media':
          widget = _buildImageLayer(content, style, scaleRatio);
          break;
        default:
          debugPrint('    ⚠️ Unknown layer type: $type');
          break;
      }
      
      if (widget != null) {
        widgets.add(widget);
      }
    }
    
    return widgets.isNotEmpty ? widgets : [
      Text(
        'No renderable layers',
        style: TextStyle(color: Colors.white70, fontSize: 12 * scaleRatio),
      ),
    ];
  }

  Widget _buildTextLayer(Map<String, dynamic> content, Map<String, dynamic> style, double scaleRatio) {
    final text = content['text']?.toString() ?? '';
    // FIX: Handle both String and num types for fontSize
    final fontSizeVal = content['fontSize'];
    final rawFontSize = fontSizeVal is num ? fontSizeVal.toDouble() : (double.tryParse(fontSizeVal?.toString() ?? '') ?? 14);
    final fontSize = rawFontSize * scaleRatio; // SCALE fontSize!
    final textColor = NinjaLayerUtils.parseColor(content['textColor']) ?? Colors.white;
    final fontWeight = NinjaLayerUtils.parseFontWeight(content['fontWeight']);
    // FIX: Add fontFamily support - was missing!
    final fontFamily = content['fontFamily']?.toString();
    // FIX: Read lineHeight from content, handle both String and num types
    final lineHeightVal = content['lineHeight'];
    final lineHeight = lineHeightVal is num ? lineHeightVal.toDouble() : (double.tryParse(lineHeightVal?.toString() ?? '') ?? 1.4);
    // FIX: Read marginBottom from style, handle both String and num types
    final marginBottomVal = style['marginBottom'];
    final rawMarginBottom = marginBottomVal is num ? marginBottomVal.toDouble() : (double.tryParse(marginBottomVal?.toString() ?? '') ?? 0);
    final marginBottom = rawMarginBottom * scaleRatio;
    
    return Padding(
      padding: EdgeInsets.only(bottom: marginBottom),
      // FIX: SizedBox with full width to ensure text wraps consistently like Dashboard
      child: SizedBox(
        width: double.infinity,
        child: Text(
          text,
          softWrap: true, // FIX: Ensure text wraps like Dashboard
          style: TextStyle(
            color: textColor,
            fontSize: fontSize,
            fontWeight: fontWeight,
            fontFamily: fontFamily, // Now uses custom font!
            height: lineHeight, // FIX: Now configurable
          ),
        ),
      ),
    );
  }

  Widget _buildButtonLayer(Map<String, dynamic> content, Map<String, dynamic> style, double scaleRatio) {
    final label = content['label']?.toString() ?? 'Button';
    final bgColor = NinjaLayerUtils.parseColor(style['backgroundColor']) ?? Colors.blue;
    final textColor = NinjaLayerUtils.parseColor(content['textColor']) ?? Colors.white;
    // FIX: Handle both String and num types for fontSize
    final fontSizeVal = content['fontSize'];
    final rawFontSize = fontSizeVal is num ? fontSizeVal.toDouble() : (double.tryParse(fontSizeVal?.toString() ?? '') ?? 14);
    final fontSize = rawFontSize * scaleRatio;
    final action = content['action'] as Map<String, dynamic>?;
    // FIX: Add fontFamily support - check both content and style
    final fontFamily = content['fontFamily']?.toString() ?? style['fontFamily']?.toString();
    // FIX: Add fontWeight support
    final fontWeight = NinjaLayerUtils.parseFontWeight(content['fontWeight']) 
                       ?? NinjaLayerUtils.parseFontWeight(style['fontWeight'])
                       ?? FontWeight.w600;
    // FIX: Read borderRadius from style, handle both String and num types
    final borderRadiusVal = style['borderRadius'];
    final rawBorderRadius = borderRadiusVal is num ? borderRadiusVal.toDouble() : (double.tryParse(borderRadiusVal?.toString() ?? '') ?? 8);
    final borderRadius = rawBorderRadius * scaleRatio;
    // FIX: Read custom padding from style, handle both String and num types
    final paddingTopVal = style['paddingTop'];
    final paddingRightVal = style['paddingRight'];
    final paddingBottomVal = style['paddingBottom'];
    final paddingLeftVal = style['paddingLeft'];
    final rawPaddingTop = paddingTopVal is num ? paddingTopVal.toDouble() : (double.tryParse(paddingTopVal?.toString() ?? '') ?? 12);
    final rawPaddingRight = paddingRightVal is num ? paddingRightVal.toDouble() : (double.tryParse(paddingRightVal?.toString() ?? '') ?? 16);
    final rawPaddingBottom = paddingBottomVal is num ? paddingBottomVal.toDouble() : (double.tryParse(paddingBottomVal?.toString() ?? '') ?? 12);
    final rawPaddingLeft = paddingLeftVal is num ? paddingLeftVal.toDouble() : (double.tryParse(paddingLeftVal?.toString() ?? '') ?? 16);
    
    return ElevatedButton(
      onPressed: () {
        if (action != null) {
          final actionType = action['type']?.toString() ?? 'dismiss';
          _handleAction(actionType, action);
        } else {
          _handleDismiss();
        }
      },
      style: ElevatedButton.styleFrom(
        backgroundColor: bgColor,
        foregroundColor: textColor,
        // FIX: Use custom padding from style
        padding: EdgeInsets.only(
          top: rawPaddingTop * scaleRatio,
          right: rawPaddingRight * scaleRatio,
          bottom: rawPaddingBottom * scaleRatio,
          left: rawPaddingLeft * scaleRatio,
        ),
        shape: RoundedRectangleBorder(
          // FIX: Use custom borderRadius from style
          borderRadius: BorderRadius.circular(borderRadius),
        ),
      ),
      // FIX: Add fontFamily and fontWeight to TextStyle
      child: Text(label, style: TextStyle(fontSize: fontSize, fontFamily: fontFamily, fontWeight: fontWeight)),
    );
  }

  Widget _buildImageLayer(Map<String, dynamic> content, Map<String, dynamic> style, double scaleRatio) {
    final imageUrl = content['imageUrl']?.toString() ?? content['url']?.toString();
    // FIX: Handle both String and num types for width/height
    final rawWidthVal = style['width'];
    final rawHeightVal = style['height'];
    
    // FIX: Detect percentage from value string itself (e.g., "60%")
    final widthIsPercent = rawWidthVal?.toString().contains('%') ?? false;
    final heightIsPercent = rawHeightVal?.toString().contains('%') ?? false;
    
    // Strip units for parsing (px, %, etc.)
    double? parseValue(dynamic val) {
      if (val == null) return null;
      if (val is num) return val.toDouble();
      String strVal = val.toString().trim().toLowerCase();
      strVal = strVal.replaceAll('px', '').replaceAll('%', '').replaceAll('pt', '').replaceAll('em', '').replaceAll('rem', '').trim();
      return double.tryParse(strVal);
    }
    
    final rawWidth = parseValue(rawWidthVal);
    final rawHeight = parseValue(rawHeightVal);
    
    // FIX: Check if width/height are percentages (from value OR explicit unit)
    bool usePercentageWidth = widthIsPercent || (style['widthUnit']?.toString() == '%');
    bool usePercentageHeight = heightIsPercent || (style['heightUnit']?.toString() == '%');
    
    // Calculate dimensions based on unit type
    double? width;
    double? height;
    
    if (!usePercentageWidth && rawWidth != null) {
      // Pixel-based: scale like other dimensions
      width = rawWidth * scaleRatio;
    }
    if (!usePercentageHeight && rawHeight != null) {
      // Pixel-based: scale like other dimensions  
      height = rawHeight * scaleRatio;
    }
    
    // FIX: Read borderRadius from style, handle both String and num types
    final rawBorderRadiusVal = style['borderRadius'];
    final rawBorderRadius = rawBorderRadiusVal is num ? rawBorderRadiusVal.toDouble() : (double.tryParse(rawBorderRadiusVal?.toString() ?? '') ?? 0);
    final borderRadius = rawBorderRadius * scaleRatio;
    // FIX: Read objectFit from style (default 'contain' to match Dashboard)
    final objectFitStr = style['objectFit']?.toString() ?? 'contain';
    final objectFit = objectFitStr == 'cover' ? BoxFit.cover 
                     : objectFitStr == 'fill' ? BoxFit.fill
                     : BoxFit.contain;
    
    if (imageUrl == null || imageUrl.isEmpty) {
      return const SizedBox.shrink();
    }
    
    // FIX: If using percentages, use LayoutBuilder to get parent constraints
    if (usePercentageWidth || usePercentageHeight) {
      return LayoutBuilder(
        builder: (context, constraints) {
          final percentWidth = usePercentageWidth && rawWidth != null
              ? constraints.maxWidth * (rawWidth / 100)
              : width;
          final percentHeight = usePercentageHeight && rawHeight != null
              ? constraints.maxHeight * (rawHeight / 100)
              : height;
          
          return ClipRRect(
            borderRadius: BorderRadius.circular(borderRadius),
            child: Image.network(
              imageUrl,
              width: percentWidth,
              height: percentHeight,
              fit: objectFit,
              errorBuilder: (_, __, ___) => const Icon(Icons.broken_image, color: Colors.white),
            ),
          );
        },
      );
    }
    
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: Image.network(
        imageUrl,
        width: width,
        height: height,
        fit: objectFit,
        errorBuilder: (_, __, ___) => const Icon(Icons.broken_image, color: Colors.white),
      ),
    );
  }

  Widget _buildArrow(Color color, double size, ArrowDirection direction, {double roundness = 0}) {
    return CustomPaint(
      size: Size(size * 2, size),
      painter: _ArrowPainter(color: color, direction: direction, roundness: roundness),
    );
  }

  // FIX: Removed hardcoded gap constant - Dashboard doesn't have this
  double _calculateTooltipX(String position, Rect target, double tooltipWidth, double arrowSize, double offset, double scaleRatio) {
    switch (position) {
      case 'left':
        return target.left - tooltipWidth - arrowSize + offset;
      case 'right':
        return target.right + arrowSize + offset;
      default: // top, bottom
        return target.center.dx - tooltipWidth / 2 + offset;
    }
  }

  double _calculateTooltipY(String position, Rect target, double arrowSize, double offset, double scaleRatio) {
    // FIX: Removed hardcoded 4px gap constant - Dashboard doesn't have this
    switch (position) {
      case 'top':
        return target.top - arrowSize + offset;
      case 'bottom':
        return target.bottom + arrowSize + offset;
      default: // left, right
        return target.center.dy + offset;
    }
  }

  Alignment _getScaleAlignment(String position) {
    switch (position) {
      case 'top':
        return Alignment.bottomCenter;
      case 'bottom':
        return Alignment.topCenter;
      case 'left':
        return Alignment.centerRight;
      case 'right':
        return Alignment.centerLeft;
      default:
        return Alignment.center;
    }
  }

  // ✅ FEATURE: Support Layer Actions
  Widget _buildInteraction(Widget child, Map<String, dynamic> component) {
    // Check both 'action' (root) and 'content.action'
    final actionConfig = component['action'] ?? component['content']?['action'];

    // No action configured
    if (actionConfig == null) {
      return child;
    }

    // Action can be a String or Map
    String actionType = 'default';
    Map<String, dynamic> actionData = {};

    if (actionConfig is String) {
      actionType = actionConfig;
    } else if (actionConfig is Map) {
      actionType = (actionConfig['type'] as String?) ?? 'default';
      actionData = Map<String, dynamic>.from(actionConfig);
    }

    return GestureDetector(
      behavior: HitTestBehavior.opaque, // ✅ Ensure taps are caught even if transparent
      onTap: () => _handleAction(actionType, actionData),
      child: child,
    );
  }
}

// ============ SPOTLIGHT PAINTER ============
class _SpotlightPainter extends CustomPainter {
  final Rect targetRect;
  final Color overlayColor;
  final double targetBorderRadius;
  final Color targetBorderColor;
  final double targetBorderWidth;

  _SpotlightPainter({
    required this.targetRect,
    required this.overlayColor,
    required this.targetBorderRadius,
    required this.targetBorderColor,
    required this.targetBorderWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Full screen overlay
    final overlayPaint = Paint()..color = overlayColor;
    
    // Cutout path
    final fullRect = Rect.fromLTWH(0, 0, size.width, size.height);
    final cutoutRect = RRect.fromRectAndRadius(
      targetRect.inflate(4), // Small padding
      Radius.circular(targetBorderRadius),
    );
    
    // Draw overlay with cutout
    final path = Path()
      ..addRect(fullRect)
      ..addRRect(cutoutRect);
    path.fillType = PathFillType.evenOdd;
    
    canvas.drawPath(path, overlayPaint);
    
    // Draw target border
    final borderPaint = Paint()
      ..color = targetBorderColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = targetBorderWidth;
    
    canvas.drawRRect(cutoutRect, borderPaint);
  }

  @override
  bool shouldRepaint(_SpotlightPainter oldDelegate) =>
      targetRect != oldDelegate.targetRect ||
      overlayColor != oldDelegate.overlayColor;
}

// ============ ARROW PAINTER (with roundness support) ============
enum ArrowDirection { up, down, left, right }

class _ArrowPainter extends CustomPainter {
  final Color color;
  final ArrowDirection direction;
  final double roundness; // 0-100, 0 = sharp, 100 = very rounded
  final double positionPercent; // 0-100, position along edge

  _ArrowPainter({
    required this.color, 
    required this.direction,
    this.roundness = 0,
    this.positionPercent = 50,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final path = Path();
    // tipOffset applies curve at the TIP, not the base
    final tipOffset = (roundness / 100) * (size.height * 0.6);
    
    switch (direction) {
      case ArrowDirection.up:
        // Arrow pointing UP - curve the TOP tip
        if (tipOffset > 0) {
          path.moveTo(0, size.height);
          path.lineTo(size.width / 2 - tipOffset, tipOffset);
          path.quadraticBezierTo(size.width / 2, -tipOffset * 0.5, size.width / 2 + tipOffset, tipOffset);
          path.lineTo(size.width, size.height);
        } else {
          path.moveTo(0, size.height);
          path.lineTo(size.width / 2, 0);
          path.lineTo(size.width, size.height);
        }
        break;
      case ArrowDirection.down:
        // Arrow pointing DOWN - curve the BOTTOM tip
        if (tipOffset > 0) {
          path.moveTo(0, 0);
          path.lineTo(size.width / 2 - tipOffset, size.height - tipOffset);
          path.quadraticBezierTo(size.width / 2, size.height + tipOffset * 0.5, size.width / 2 + tipOffset, size.height - tipOffset);
          path.lineTo(size.width, 0);
        } else {
          path.moveTo(0, 0);
          path.lineTo(size.width / 2, size.height);
          path.lineTo(size.width, 0);
        }
        break;
      case ArrowDirection.left:
        // Arrow pointing LEFT - curve the LEFT tip
        if (tipOffset > 0) {
          path.moveTo(size.width, 0);
          path.lineTo(tipOffset, size.height / 2 - tipOffset);
          path.quadraticBezierTo(-tipOffset * 0.5, size.height / 2, tipOffset, size.height / 2 + tipOffset);
          path.lineTo(size.width, size.height);
        } else {
          path.moveTo(size.width, 0);
          path.lineTo(0, size.height / 2);
          path.lineTo(size.width, size.height);
        }
        break;
      case ArrowDirection.right:
        // Arrow pointing RIGHT - curve the RIGHT tip
        if (tipOffset > 0) {
          path.moveTo(0, 0);
          path.lineTo(size.width - tipOffset, size.height / 2 - tipOffset);
          path.quadraticBezierTo(size.width + tipOffset * 0.5, size.height / 2, size.width - tipOffset, size.height / 2 + tipOffset);
          path.lineTo(0, size.height);
        } else {
          path.moveTo(0, 0);
          path.lineTo(size.width, size.height / 2);
          path.lineTo(0, size.height);
        }
        break;
    }
    
    path.close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_ArrowPainter oldDelegate) =>
      color != oldDelegate.color || 
      direction != oldDelegate.direction ||
      roundness != oldDelegate.roundness ||
      positionPercent != oldDelegate.positionPercent;
}
