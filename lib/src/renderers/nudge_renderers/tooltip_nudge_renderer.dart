import 'package:flutter/material.dart';
import 'dart:async';
import 'package:url_launcher/url_launcher.dart';
import '../../models/campaign.dart';
import '../layers/ninja_layer_utils.dart';
import '../../app_ninja.dart';

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
      default:
        widget.onCTAClick?.call(action, data);
    }
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
    final offsetX = (tooltipConfig['offsetX'] as num?)?.toDouble() ?? 0;
    final offsetY = (tooltipConfig['offsetY'] as num?)?.toDouble() ?? 0;
    
    // Target styling
    final targetBorderRadius = (tooltipConfig['targetBorderRadius'] as num?)?.toDouble() ?? 8;
    final targetBorderColor = NinjaLayerUtils.parseColor(tooltipConfig['targetBorderColor']) ?? Colors.blue;
    final targetBorderWidth = (tooltipConfig['targetBorderWidth'] as num?)?.toDouble() ?? 2;
    
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
    final rawPadding = (tooltipConfig['padding'] as num?)?.toDouble() ?? 16;
    final padding = rawPadding * scaleRatio;
    
    // Height (optional)
    final heightMode = tooltipConfig['heightMode']?.toString() ?? 'auto';
    final rawHeight = (tooltipConfig['height'] as num?)?.toDouble();
    final tooltipHeight = heightMode == 'custom' && rawHeight != null ? rawHeight * scaleRatio : null;
    
    // Shadow - SCALE blur!
    final shadowEnabled = tooltipConfig['shadowEnabled'] != false;
    final rawShadowBlur = (tooltipConfig['shadowBlur'] as num?)?.toDouble() ?? 25;
    final shadowBlur = rawShadowBlur * scaleRatio;
    final shadowOpacity = (tooltipConfig['shadowOpacity'] as num?)?.toDouble() ?? 0.2;
    
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
              left: _calculateTooltipX(position, _targetRect!, tooltipWidth ?? rawWidth * scaleRatio, arrowSize, offsetX),
              // For 'top': position anchor at target.top - gap, then shift UP by tooltip height
              // For 'bottom': position at target.bottom + arrow + gap
              top: position == 'top' 
                  ? (_targetRect!.top - arrowSize - 4 + offsetY)
                  : _calculateTooltipY(position, _targetRect!, arrowSize, offsetY),
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
                            tooltipHeight,
                            scaleRatio,
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
                          tooltipHeight,
                          scaleRatio,
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
                    tooltipHeight,
                    scaleRatio,
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
    double? height,
    double scaleRatio, // For scaling layer content
  ) {
    // Apply opacity to bgColor
    final effectiveBgColor = bgColor.withOpacity(backgroundOpacity);
    
    // Build the main tooltip container with clipping to prevent overflow
    final tooltipContainer = ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      clipBehavior: Clip.hardEdge, // Clip any overflowing content
      child: Container(
        width: width,
        height: height,
        padding: EdgeInsets.all(padding),
        decoration: BoxDecoration(
          color: effectiveBgColor,
          borderRadius: BorderRadius.circular(borderRadius),
          boxShadow: shadowEnabled ? [
            BoxShadow(
              color: Colors.black.withOpacity(shadowOpacityVal),
              blurRadius: shadowBlur,
              offset: const Offset(0, 4),
            ),
          ] : null,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: _buildLayers(layers, scaleRatio),
        ),
      ),
    );

    // If no arrow, return just the container
    if (!arrowEnabled) {
      return tooltipContainer;
    }

    // Arrow positioning based on position and arrowPositionPercent
    // positionPercent: 0 = start, 50 = center, 100 = end
    return _buildTooltipWithArrow(
      tooltipContainer, 
      effectiveBgColor, 
      position, 
      arrowSize, 
      arrowRoundness,
      arrowPositionPercent,
    );
  }

  // Build tooltip with positioned arrow using Stack
  Widget _buildTooltipWithArrow(
    Widget tooltipContainer,
    Color arrowColor,
    String position,
    double arrowSize,
    double arrowRoundness,
    double arrowPositionPercent,
  ) {
    // For top/bottom: arrow is positioned horizontally
    // For left/right: arrow is positioned vertically
    final isVertical = position == 'top' || position == 'bottom';
    
    // Convert percent to alignment (-1 to 1 range)
    // 0% = -1 (start), 50% = 0 (center), 100% = 1 (end)
    final alignmentValue = (arrowPositionPercent / 50) - 1;
    
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
          children: [
            Align(
              alignment: Alignment(alignmentValue, 0),
              child: arrowWidget,
            ),
            tooltipContainer,
          ],
        );
      case 'top': // Tooltip above target, arrow points DOWN at bottom
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            tooltipContainer,
            Align(
              alignment: Alignment(alignmentValue, 0),
              child: arrowWidget,
            ),
          ],
        );
      case 'right': // Tooltip right of target, arrow points LEFT on left side
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Align(
              alignment: Alignment(0, alignmentValue),
              child: arrowWidget,
            ),
            tooltipContainer,
          ],
        );
      case 'left': // Tooltip left of target, arrow points RIGHT on right side
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            tooltipContainer,
            Align(
              alignment: Alignment(0, alignmentValue),
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
    final rawFontSize = (content['fontSize'] as num?)?.toDouble() ?? 14;
    final fontSize = rawFontSize * scaleRatio; // SCALE fontSize!
    final textColor = NinjaLayerUtils.parseColor(content['textColor']) ?? Colors.white;
    final fontWeight = NinjaLayerUtils.parseFontWeight(content['fontWeight']);
    
    return Padding(
      padding: EdgeInsets.only(bottom: 8 * scaleRatio), // SCALE padding!
      child: Text(
        text,
        style: TextStyle(
          color: textColor,
          fontSize: fontSize,
          fontWeight: fontWeight,
          height: 1.4,
        ),
      ),
    );
  }

  Widget _buildButtonLayer(Map<String, dynamic> content, Map<String, dynamic> style, double scaleRatio) {
    final label = content['label']?.toString() ?? 'Button';
    final bgColor = NinjaLayerUtils.parseColor(style['backgroundColor']) ?? Colors.blue;
    final textColor = NinjaLayerUtils.parseColor(content['textColor']) ?? Colors.white;
    final rawFontSize = (content['fontSize'] as num?)?.toDouble() ?? 14;
    final fontSize = rawFontSize * scaleRatio;
    final action = content['action'] as Map<String, dynamic>?;
    
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
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
          padding: EdgeInsets.symmetric(vertical: 12 * scaleRatio), // SCALED!
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8 * scaleRatio), // SCALED!
          ),
        ),
        child: Text(label, style: TextStyle(fontSize: fontSize)), // SCALED!
      ),
    );
  }

  Widget _buildImageLayer(Map<String, dynamic> content, Map<String, dynamic> style, double scaleRatio) {
    final imageUrl = content['imageUrl']?.toString() ?? content['url']?.toString();
    final rawWidth = (style['width'] as num?)?.toDouble();
    final rawHeight = (style['height'] as num?)?.toDouble();
    // SCALE image dimensions!
    final width = rawWidth != null ? rawWidth * scaleRatio : null;
    final height = rawHeight != null ? rawHeight * scaleRatio : null;
    
    if (imageUrl == null || imageUrl.isEmpty) {
      return const SizedBox.shrink();
    }
    
    return ClipRRect(
      borderRadius: BorderRadius.circular(8 * scaleRatio), // SCALED!
      child: Image.network(
        imageUrl,
        width: width,
        height: height,
        fit: BoxFit.cover,
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

  double _calculateTooltipX(String position, Rect target, double tooltipWidth, double arrowSize, double offset) {
    switch (position) {
      case 'left':
        return target.left - tooltipWidth - arrowSize - 4 + offset;
      case 'right':
        return target.right + arrowSize + 4 + offset;
      default: // top, bottom
        return target.center.dx - tooltipWidth / 2 + offset;
    }
  }

  double _calculateTooltipY(String position, Rect target, double arrowSize, double offset) {
    switch (position) {
      case 'top':
        return target.top - arrowSize - 4 + offset;
      case 'bottom':
        return target.bottom + arrowSize + 4 + offset;
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
