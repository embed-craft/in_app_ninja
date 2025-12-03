import 'package:flutter/material.dart';
import 'dart:ui' as ui;
import '../../models/campaign.dart';

/// ScratchCard Nudge Renderer
/// 
/// Renders a scratch-to-reveal card:
/// - Touch/drag to reveal content underneath
/// - Custom paint for scratch effect
/// - Threshold-based reveal (e.g., 60% scratched)
/// - Rewards/offers reveal
class ScratchCardNudgeRenderer extends StatefulWidget {
  final Campaign campaign;
  final VoidCallback? onDismiss;
  final Function(String action, Map<String, dynamic>? data)? onCTAClick;

  const ScratchCardNudgeRenderer({
    Key? key,
    required this.campaign,
    this.onDismiss,
    this.onCTAClick,
  }) : super(key: key);

  @override
  State<ScratchCardNudgeRenderer> createState() => _ScratchCardNudgeRendererState();
}

class _ScratchCardNudgeRendererState extends State<ScratchCardNudgeRenderer> {
  final List<Offset?> _points = [];
  bool _isRevealed = false;
  double _scratchPercentage = 0.0;

  @override
  void initState() {
    super.initState();
  }

  Future<void> _handleDismiss() async {
    widget.onDismiss?.call();
  }

  void _handleCTA(String action) {
    final config = widget.campaign.config;
    widget.onCTAClick?.call(action, config);
    _handleDismiss();
  }

  void _handlePanUpdate(DragUpdateDetails details) {
    if (_isRevealed) return;

    setState(() {
      final RenderBox box = context.findRenderObject() as RenderBox;
      final localPosition = box.globalToLocal(details.globalPosition);
      _points.add(localPosition);

      // Calculate scratch percentage (simplified)
      _scratchPercentage = (_points.length / 500).clamp(0.0, 1.0);

      // Auto-reveal if threshold reached
      final threshold = (widget.campaign.config['revealThreshold'] as num?)?.toDouble() ?? 0.6;
      if (_scratchPercentage >= threshold) {
        _isRevealed = true;
      }
    });
  }

  void _handlePanEnd(DragEndDetails details) {
    setState(() {
      _points.add(null); // Break the line
    });
  }

  @override
  Widget build(BuildContext context) {
    final config = widget.campaign.config;
    final backgroundColor = _parseColor(config['backgroundColor']) ?? Colors.white;
    final overlayColor = _parseColor(config['overlayColor']) ?? const Color(0xFFC0C0C0);
    
    return Material(
      color: Colors.black54, // Backdrop
      child: Center(
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 24),
          constraints: const BoxConstraints(maxWidth: 400),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Scratch area
                GestureDetector(
                  onPanUpdate: _handlePanUpdate,
                  onPanEnd: _handlePanEnd,
                  child: Stack(
                    children: [
                      // Hidden content (revealed)
                      _buildRevealedContent(config, backgroundColor),

                      // Scratch overlay
                      if (!_isRevealed)
                        CustomPaint(
                          size: const Size(double.infinity, 300),
                          painter: _ScratchPainter(
                            points: _points,
                            overlayColor: overlayColor,
                          ),
                          child: Container(
                            height: 300,
                            width: double.infinity,
                            alignment: Alignment.center,
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.swipe,
                                  color: Colors.white.withOpacity(0.8),
                                  size: 48,
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  config['scratchPrompt']?.toString() ?? 'Scratch to reveal',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white.withOpacity(0.9),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                      // Progress indicator
                      if (!_isRevealed && _scratchPercentage > 0)
                        Positioned(
                          top: 16,
                          right: 16,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.6),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              '${(_scratchPercentage * 100).toInt()}%',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),

                // CTA Buttons (only show when revealed)
                if (_isRevealed)
                  Container(
                    padding: const EdgeInsets.all(24),
                    color: backgroundColor,
                    child: _buildCTAButtons(config),
                  ),

                // Close button
                Container(
                  padding: const EdgeInsets.all(8),
                  color: backgroundColor,
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: _handleDismiss,
                      child: const Text('Close'),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRevealedContent(Map<String, dynamic> config, Color backgroundColor) {
    final textColor = _parseColor(config['textColor']) ?? Colors.black;
    final rewardText = config['rewardText']?.toString() ?? 'Congratulations!';
    final rewardAmount = config['rewardAmount']?.toString();

    return Container(
      height: 300,
      width: double.infinity,
      color: backgroundColor,
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Reward icon/image
          if (config['rewardIcon'] != null)
            Image.network(
              config['rewardIcon'],
              width: 80,
              height: 80,
              errorBuilder: (_, __, ___) => const Icon(
                Icons.card_giftcard,
                size: 80,
                color: Color(0xFFFFB800),
              ),
            )
          else
            const Icon(
              Icons.card_giftcard,
              size: 80,
              color: Color(0xFFFFB800),
            ),

          const SizedBox(height: 16),

          // Reward amount (if provided)
          if (rewardAmount != null)
            Text(
              rewardAmount,
              style: TextStyle(
                fontSize: 48,
                fontWeight: FontWeight.bold,
                color: _parseColor(config['accentColor']) ?? const Color(0xFFFFB800),
              ),
            ),

          const SizedBox(height: 8),

          // Reward text
          Text(
            rewardText,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: textColor,
            ),
            textAlign: TextAlign.center,
          ),

          const SizedBox(height: 8),

          // Description (optional)
          if (config['description'] != null)
            Text(
              config['description'],
              style: TextStyle(
                fontSize: 14,
                color: textColor.withOpacity(0.7),
              ),
              textAlign: TextAlign.center,
            ),
        ],
      ),
    );
  }

  Widget _buildCTAButtons(Map<String, dynamic> config) {
    final buttonText = config['buttonText']?.toString() ?? 'Claim Reward';
    final buttonColor = _parseColor(config['buttonColor']) ?? const Color(0xFFFFB800);

    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: () => _handleCTA('primary'),
        style: ElevatedButton.styleFrom(
          backgroundColor: buttonColor,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 0,
        ),
        child: Text(
          buttonText,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
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

class _ScratchPainter extends CustomPainter {
  final List<Offset?> points;
  final Color overlayColor;

  _ScratchPainter({required this.points, required this.overlayColor});

  @override
  void paint(Canvas canvas, Size size) {
    // Draw the overlay
    final overlayPaint = Paint()
      ..color = overlayColor
      ..style = PaintingStyle.fill;

    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      overlayPaint,
    );

    // Draw scratched areas (using BlendMode to erase)
    final scratchPaint = Paint()
      ..color = Colors.transparent
      ..strokeWidth = 40
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke
      ..blendMode = ui.BlendMode.clear;

    for (int i = 0; i < points.length - 1; i++) {
      if (points[i] != null && points[i + 1] != null) {
        canvas.drawLine(points[i]!, points[i + 1]!, scratchPaint);
      }
    }
  }

  @override
  bool shouldRepaint(_ScratchPainter oldDelegate) {
    return oldDelegate.points.length != points.length;
  }
}
