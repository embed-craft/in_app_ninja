import 'package:flutter/material.dart';
import 'package:flutter_widget_from_html/flutter_widget_from_html.dart';
import '../../models/campaign.dart';
import '../../app_ninja.dart';

/// Tooltip Nudge Renderer
/// 
/// Renders a tooltip pointing to a target widget:
/// - Arrow pointing to target element
/// - Positioned above/below/left/right of target
/// - Highlight/pulse effect on target
/// - Auto-dismiss or manual close
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

  @override
  void initState() {
    super.initState();
    
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );

    _scaleAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutBack),
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

  void _handleCTA(String action) {
    final config = widget.campaign.config;
    widget.onCTAClick?.call(action, config);
    _handleDismiss();
  }

  @override
  Widget build(BuildContext context) {
    final config = widget.campaign.config;
    final text = config['text']?.toString() ?? 'Tip!';
    final position = config['position']?.toString() ?? 'bottom'; // top, bottom, left, right
    final backgroundColor = _parseColor(config['backgroundColor']) ?? const Color(0xFF1F2937);
    final textColor = _parseColor(config['textColor']) ?? Colors.white;
    
    double targetX = (config['targetX'] as num?)?.toDouble() ?? MediaQuery.of(context).size.width / 2;
    double targetY = (config['targetY'] as num?)?.toDouble() ?? MediaQuery.of(context).size.height / 2;
    double targetWidth = 0;
    double targetHeight = 0;

    // Resolve Target ID if present
    final targetId = config['targetElementId']?.toString() ?? config['target_element_id']?.toString();
    
    if (targetId != null) {
      final targetContext = AppNinja.getTargetContext(targetId);
      if (targetContext != null) {
        final renderBox = targetContext.findRenderObject() as RenderBox?;
        if (renderBox != null && renderBox.hasSize) {
           final offset = renderBox.localToGlobal(Offset.zero);
           targetX = offset.dx;
           targetY = offset.dy;
           targetWidth = renderBox.size.width;
           targetHeight = renderBox.size.height;
           
           // Adjust target point to center specific edge based on position
           if (position == 'bottom') {
             targetX += targetWidth / 2;
             targetY += targetHeight;
           } else if (position == 'top') {
             targetX += targetWidth / 2;
             // targetY is already top
           } else if (position == 'right') {
             targetX += targetWidth;
             targetY += targetHeight / 2;
           } else if (position == 'left') {
             targetY += targetHeight / 2;
           }
        }
      } else {
        debugPrint('⚠️ Tooltip Target NOT Found: $targetId');
      }
    }

    // Parse Design Properties
    final double roundness = (config['roundness'] as num?)?.toDouble() ?? 8.0;
    final double paddingVal = (config['padding'] as num?)?.toDouble() ?? 12.0;
    final EdgeInsets padding = EdgeInsets.all(paddingVal);
    final String? overlayColorStr = config['overlayColor']?.toString() ?? config['overlay']?.toString();
    final Color overlayColor = _parseColor(overlayColorStr)?.withOpacity((config['overlayOpacity'] as num?)?.toDouble() ?? 0.3) 
                             ?? Colors.black.withOpacity(0.3);
    
    final double targetRoundness = (config['targetRoundness'] as num?)?.toDouble() ?? 0.0; // 0 = Rect, 50/100 = Circle
    final BoxShape targetShape = targetRoundness > 20 ? BoxShape.circle : BoxShape.rectangle;

    return Material(
      color: Colors.transparent,
      child: Stack(
        children: [
          // Overlay
          GestureDetector(
            onTap: _handleDismiss,
            child: Container(
              color: overlayColor,
            ),
          ),

          // Tooltip positioned near target
          Positioned(
            left: _getTooltipX(context, position, targetX),
            top: _getTooltipY(context, position, targetY),
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: ScaleTransition(
                scale: _scaleAnimation,
                alignment: _getScaleAlignment(position),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (position == 'bottom') _buildArrow(backgroundColor, ArrowDirection.up),
                    
                    Container(
                      constraints: const BoxConstraints(maxWidth: 280),
                      padding: padding,
                      decoration: BoxDecoration(
                        color: backgroundColor,
                        gradient: config['mode'] == 'advanced' && config['gradientWith'] != null && config['gradientTo'] != null
                            ? LinearGradient(
                                colors: [
                                  _parseColor(config['gradientWith']) ?? backgroundColor,
                                  _parseColor(config['gradientTo']) ?? backgroundColor,
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              )
                            : null,
                        borderRadius: BorderRadius.circular(roundness),
                        boxShadow: (config['mode'] == 'image' && (config['boxShadow'] == null || config['boxShadow'] == 'none')) 
                            ? [] // Force cleanup for image mode
                            : [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.2),
                                  blurRadius: 12,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                      ),
                      child: config['mode'] == 'html' 
                        ? (config['htmlContent'] != null 
                            ? HtmlWidget(config['htmlContent']) 
                            : const Text('HTML Content'))
                        : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (config['title'] != null)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 6),
                              child: Text(
                                config['title'],
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                  color: textColor,
                                ),
                              ),
                            ),

                          Text(
                            text,
                            style: TextStyle(
                              fontSize: 14,
                              color: textColor.withOpacity(0.9),
                              height: 1.4,
                            ),
                          ),

                          if (config['buttonText'] != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 12),
                              child: SizedBox(
                                width: double.infinity,
                                child: ElevatedButton(
                                  onPressed: () => _handleCTA('primary'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: textColor,
                                    foregroundColor: backgroundColor,
                                    padding: const EdgeInsets.symmetric(vertical: 10),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    elevation: 0,
                                  ),
                                  child: Text(
                                    config['buttonText'],
                                    style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    
                    if (position == 'top') _buildArrow(backgroundColor, ArrowDirection.down),
                  ],
                ),
              ),
            ),
          ),

          // Target highlight (pulse effect)
          Positioned(
            left: targetX - (targetWidth / 2) - 10, // Adjust centering relative to calculated target center
            top: targetY - (targetHeight / 2) - 10,
            child: _buildTargetHighlight(targetWidth, targetHeight, targetShape, targetRoundness),
          ),
        ],
      ),
    );
  }

  Widget _buildArrow(Color color, ArrowDirection direction) {
    // If gradient is used, try to match the gradient start/end color based on direction, 
    // or just use a solid approximation. For simplified "Brand of the Day", solid color usually works or main color.
    return CustomPaint(
      size: const Size(20, 10), // Slightly larger for bubble
      painter: _ArrowPainter(
        color: color, 
        direction: direction,
        isBubble: widget.campaign.config['arrowStyle'] == 'bubble',
      ),
    );
  }
// ... (rest of class)
}

enum ArrowDirection { up, down, left, right }

class _ArrowPainter extends CustomPainter {
  final Color color;
  final ArrowDirection direction;
  final bool isBubble;

  _ArrowPainter({required this.color, required this.direction, this.isBubble = false});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final path = Path();
    
    if (isBubble) {
      // Curved "Speech Bubble" Arrow
      switch (direction) {
        case ArrowDirection.up:
          path.moveTo(0, size.height); 
          path.quadraticBezierTo(size.width * 0.2, size.height, size.width * 0.5, 0);
          path.quadraticBezierTo(size.width * 0.8, size.height, size.width, size.height);
          break;
        case ArrowDirection.down:
           path.moveTo(0, 0);
           path.quadraticBezierTo(size.width * 0.2, 0, size.width * 0.5, size.height);
           path.quadraticBezierTo(size.width * 0.8, 0, size.width, 0);
          break;
        case ArrowDirection.left:
           path.moveTo(size.width, 0);
           path.quadraticBezierTo(size.width, size.height * 0.2, 0, size.height * 0.5);
           path.quadraticBezierTo(size.width, size.height * 0.8, size.width, size.height);
          break;
        case ArrowDirection.right:
           path.moveTo(0, 0);
           path.quadraticBezierTo(0, size.height * 0.2, size.width, size.height * 0.5);
           path.quadraticBezierTo(0, size.height * 0.8, 0, size.height);
          break;
      }
    } else {
      // Triangle Arrow (Standard)
      switch (direction) {
        case ArrowDirection.up:
          path.moveTo(size.width / 2, 0);
          path.lineTo(0, size.height);
          path.lineTo(size.width, size.height);
          break;
        case ArrowDirection.down:
          path.moveTo(0, 0);
          path.lineTo(size.width, 0);
          path.lineTo(size.width / 2, size.height);
          break;
        case ArrowDirection.left:
          path.moveTo(0, size.height / 2);
          path.lineTo(size.width, 0);
          path.lineTo(size.width, size.height);
          break;
        case ArrowDirection.right:
          path.moveTo(0, 0);
          path.lineTo(size.width, size.height / 2);
          path.lineTo(0, size.height);
          break;
      }
    }
    
    path.close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_ArrowPainter oldDelegate) => 
      oldDelegate.color != color || 
      oldDelegate.direction != direction ||
      oldDelegate.isBubble != isBubble;
}
