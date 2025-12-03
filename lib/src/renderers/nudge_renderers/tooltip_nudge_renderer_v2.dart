import 'package:flutter/material.dart';
import '../../models/campaign.dart';

/// TOOLTIP NUDGE RENDERER V2
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
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _fadeAnimation = CurvedAnimation(parent: _controller, curve: Curves.easeIn);
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final config = widget.campaign.config;
    final position = config['position'] as String? ?? 'bottom-right';
    
    Alignment alignment;
    switch(position) {
      case 'top-left': alignment = Alignment.topLeft; break;
      case 'top-right': alignment = Alignment.topRight; break;
      case 'bottom-left': alignment = Alignment.bottomLeft; break;
      case 'center': alignment = Alignment.center; break;
      case 'bottom-right': 
      default: alignment = Alignment.bottomRight; break;
    }

    return Stack(
      children: [
        // Dismissible background
        Positioned.fill(
          child: GestureDetector(
            onTap: widget.onDismiss,
            behavior: HitTestBehavior.opaque,
            child: Container(color: Colors.transparent),
          ),
        ),
        
        // Tooltip Content
        Align(
          alignment: alignment,
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF1F2937),
                borderRadius: BorderRadius.circular(8),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  )
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    config['components']?[0]?['content']?['text'] ?? 'Tooltip',
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
