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
    
    // Default Target: Center of Screen
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
           
           // Adjust target point to specific edge based on position
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
      }
    }

    // Parse Design Properties
    final double roundness = (config['roundness'] as num?)?.toDouble() ?? 8.0;
    final double paddingVal = (config['padding'] as num?)?.toDouble() ?? 12.0;
    final EdgeInsets padding = EdgeInsets.all(paddingVal);
    final String? overlayColorStr = config['overlayColor']?.toString() ?? config['overlay']?.toString();
    final Color overlayColor = _parseColor(overlayColorStr)?.withOpacity((config['overlayOpacity'] as num?)?.toDouble() ?? 0.3) 
                             ?? Colors.black.withOpacity(0.3);
    
    final double targetRoundness = (config['targetRoundness'] as num?)?.toDouble() ?? 0.0;
    final BoxShape targetShape = targetRoundness > 20 ? BoxShape.circle : BoxShape.rectangle;

    // Calculate Tooltip Offsets
    // Since we don't know the tooltip size, we use FractionalTranslation to center/offset it.
    double? left, top, right, bottom;
    Offset translation = Offset.zero;

    if (position == 'bottom') {
      left = targetX;
      top = targetY + 10; // Gap
      translation = const Offset(-0.5, 0); // Center Horizontally
    } else if (position == 'top') {
      left = targetX;
      bottom = MediaQuery.of(context).size.height - targetY + 10;
      translation = const Offset(-0.5, 0); // Center Horizontally
    } else if (position == 'right') {
      left = targetX + 10;
      top = targetY;
      translation = const Offset(0, -0.5); // Center Vertically
    } else if (position == 'left') {
      right = MediaQuery.of(context).size.width - targetX + 10;
      top = targetY;
      translation = const Offset(0, -0.5); // Center Vertically
    }

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

          // Tooltip Layer
          Positioned(
            left: left,
            top: top,
            right: right,
            bottom: bottom,
            child: FractionalTranslation(
              translation: translation,
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: ScaleTransition(
                  scale: _scaleAnimation,
                  alignment: _getScaleAlignment(position),
                  child: Transform(
                    transform: Matrix4.identity()
                      ..rotateZ((config['rotate'] as num? ?? 0.0) * 3.14159 / 180)
                      ..scale((config['scale'] as num? ?? 1.0).toDouble()),
                    alignment: Alignment.center,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (position == 'bottom') _buildArrow(backgroundColor, ArrowDirection.up),
                        
                        Container(
                          // Constraints & Sizing
                          width: (config['width'] as num?)?.toDouble(),
                          height: (config['height'] as num?)?.toDouble(),
                          constraints: (config['width'] == null && config['height'] == null) 
                              ? const BoxConstraints(maxWidth: 280) 
                              : null,
                          padding: padding,
                          decoration: BoxDecoration(
                            color: backgroundColor,
                            borderRadius: BorderRadius.circular(roundness),
                            boxShadow: (config['mode'] == 'image' && (config['boxShadow'] == null || config['boxShadow'] == 'none')) 
                                ? [] 
                                : [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.2),
                                      blurRadius: 12,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                             // ... Support Gradient if needed ...
                          ),
                          child: _buildContent(config, textColor, text, backgroundColor, roundness, paddingVal),
                        ),
                        
                        if (position == 'top') _buildArrow(backgroundColor, ArrowDirection.down),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),

          // Target Highlight
          if (targetWidth > 0)
            Positioned(
               left: targetX - (targetWidth / 2) - 4, // 4px padding
               top: targetY - (targetHeight / 2) - (position == 'bottom' ? targetHeight : 0) - 4, 
               // Wait, logic for target Y is tricky because targetY depends on edge. 
               // Let's re-calculate absolute center for highlight
               // Actually, let's just use the original renderBox center if possible? 
               // But we only have adjusted targetX/Y.
               // Let's simplify:
               child: IgnorePointer(
                  child: Transform.translate(
                    offset: Offset(
                      position == 'right' ? -targetWidth : position == 'left' ? 0 : -targetWidth/2,
                      position == 'bottom' ? -targetHeight : position == 'top' ? 0 : -targetHeight/2
                    ),
                    child: _buildTargetHighlight(targetWidth, targetHeight, targetShape, targetRoundness),
                  )
               ),
            ),
        ],
      ),
    );
  }

  Widget _buildContent(Map<String, dynamic> config, Color textColor, String text, Color btnColor, double roundness, double paddingVal) {
     if (config['mode'] == 'html' && config['htmlContent'] != null) {
        return HtmlWidget(config['htmlContent']);
     }
     
     if (config['mode'] == 'image' && config['imageUrl'] != null) {
        return ClipRRect(
            borderRadius: BorderRadius.circular(roundness > paddingVal ? roundness - paddingVal : 0),
            child: Image.network(
               config['imageUrl'],
               fit: BoxFit.cover,
               width: (config['width'] as num?)?.toDouble(),
               height: (config['height'] as num?)?.toDouble(),
               errorBuilder: (ctx, err, stack) => const Icon(Icons.broken_image, color: Colors.white),
            )
        );
     }

     return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (config['title'] != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text(
                config['title'],
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: textColor),
              ),
            ),
          Text(
            text,
            style: TextStyle(fontSize: 14, color: textColor.withOpacity(0.9), height: 1.4),
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
                         foregroundColor: btnColor,
                         padding: const EdgeInsets.symmetric(vertical: 10),
                      ),
                      child: Text(config['buttonText'], style: const TextStyle(fontWeight: FontWeight.bold)),
                   ),
                ),
             ),
        ],
     );
  }

  // HELPER METHODS

  Color? _parseColor(dynamic color) {
    if (color is Color) return color;
    if (color is int) return Color(color);
    if (color is String) {
      if (color.isEmpty || color == 'transparent') return Colors.transparent;
      try {
        var hex = color.replaceAll('#', '');
        if (hex.length == 6) hex = 'FF$hex';
        return Color(int.parse('0x$hex'));
      } catch (e) {
        return null;
      }
    }
    return null;
  }

  Alignment _getScaleAlignment(String position) {
      switch (position) {
        case 'top': return Alignment.bottomCenter;
        case 'bottom': return Alignment.topCenter;
        case 'left': return Alignment.centerRight;
        case 'right': return Alignment.centerLeft;
        default: return Alignment.center;
      }
  }

  Widget _buildTargetHighlight(double width, double height, BoxShape shape, double roundness) {
      return Container(
         width: width + 8,
         height: height + 8,
         decoration: BoxDecoration(
           shape: shape,
           borderRadius: shape == BoxShape.rectangle ? BorderRadius.circular(roundness) : null,
           border: Border.all(color: Colors.white.withOpacity(0.5), width: 2),
           boxShadow: [
             BoxShadow(color: Colors.white.withOpacity(0.3), blurRadius: 8, spreadRadius: 2),
           ]
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
