import 'package:flutter/material.dart';
import '../../models/campaign.dart';

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
    
    // Get target position (in real implementation, this would come from widget key)
    final targetX = (config['targetX'] as num?)?.toDouble() ?? MediaQuery.of(context).size.width / 2;
    final targetY = (config['targetY'] as num?)?.toDouble() ?? MediaQuery.of(context).size.height / 2;

    return Material(
      color: Colors.transparent,
      child: Stack(
        children: [
          // Semi-transparent overlay
          GestureDetector(
            onTap: _handleDismiss,
            child: Container(
              color: Colors.black.withOpacity(0.3),
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
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: backgroundColor,
                        borderRadius: BorderRadius.circular(8),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.2),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Title (optional)
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

                          // Message
                          Text(
                            text,
                            style: TextStyle(
                              fontSize: 14,
                              color: textColor.withOpacity(0.9),
                              height: 1.4,
                            ),
                          ),

                          // CTA Button (optional)
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
            left: targetX - 30,
            top: targetY - 30,
            child: _buildTargetHighlight(),
          ),
        ],
      ),
    );
  }

  Widget _buildArrow(Color color, ArrowDirection direction) {
    return CustomPaint(
      size: const Size(16, 8),
      painter: _ArrowPainter(color: color, direction: direction),
    );
  }

  Widget _buildTargetHighlight() {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 1500),
      builder: (context, value, child) {
        return Container(
          width: 60,
          height: 60,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: Colors.white.withOpacity(0.5 * (1 - value)),
              width: 2,
            ),
          ),
        );
      },
    );
  }

  double _getTooltipX(BuildContext context, String position, double targetX) {
    const tooltipWidth = 280.0;
    switch (position) {
      case 'left':
        return targetX - tooltipWidth - 20;
      case 'right':
        return targetX + 20;
      default:
        return (targetX - tooltipWidth / 2).clamp(16, MediaQuery.of(context).size.width - tooltipWidth - 16);
    }
  }

  double _getTooltipY(BuildContext context, String position, double targetY) {
    switch (position) {
      case 'top':
        return targetY - 120; // Approximate tooltip height
      case 'bottom':
        return targetY + 40;
      default:
        return targetY - 40;
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

  Color? _parseColor(dynamic color) {
    if (color == null) return null;
    if (color is Color) return color;
    
    final colorStr = color.toString();
    if (colorStr.startsWith('#')) {
      final hexColor = colorStr.replaceFirst('#', '');
      final value = int.tryParse('FF$hexColor', radix: 16);
      return value != null ? Color(value) : null;
    }
    return null;
  }
}

enum ArrowDirection { up, down, left, right }

class _ArrowPainter extends CustomPainter {
  final Color color;
  final ArrowDirection direction;

  _ArrowPainter({required this.color, required this.direction});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final path = Path();
    
    switch (direction) {
      case ArrowDirection.up:
        path.moveTo(size.width / 2, 0); // Top point
        path.lineTo(0, size.height); // Bottom left
        path.lineTo(size.width, size.height); // Bottom right
        break;
      case ArrowDirection.down:
        path.moveTo(0, 0); // Top left
        path.lineTo(size.width, 0); // Top right
        path.lineTo(size.width / 2, size.height); // Bottom point
        break;
      case ArrowDirection.left:
        path.moveTo(0, size.height / 2); // Left point
        path.lineTo(size.width, 0); // Top right
        path.lineTo(size.width, size.height); // Bottom right
        break;
      case ArrowDirection.right:
        path.moveTo(0, 0); // Top left
        path.lineTo(size.width, size.height / 2); // Right point
        path.lineTo(0, size.height); // Bottom left
        break;
    }
    
    path.close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_ArrowPainter oldDelegate) => false;
}
