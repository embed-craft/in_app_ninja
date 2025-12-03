import 'package:flutter/material.dart';
import '../../models/campaign.dart';

/// Inline Nudge Renderer
/// 
/// Renders content inline within app UI:
/// - Embedded in lists/scrollviews
/// - Matches app design system
/// - Compact or expanded states
/// - Subtle, non-intrusive
class InlineNudgeRenderer extends StatefulWidget {
  final Campaign campaign;
  final VoidCallback? onDismiss;
  final Function(String action, Map<String, dynamic>? data)? onCTAClick;

  const InlineNudgeRenderer({
    Key? key,
    required this.campaign,
    this.onDismiss,
    this.onCTAClick,
  }) : super(key: key);

  @override
  State<InlineNudgeRenderer> createState() => _InlineNudgeRendererState();
}

class _InlineNudgeRendererState extends State<InlineNudgeRenderer>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<double> _slideAnimation;
  bool _isExpanded = false;

  @override
  void initState() {
    super.initState();
    
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );

    _slideAnimation = Tween<double>(begin: 20.0, end: 0.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleDismiss() {
    _controller.reverse().then((_) {
      widget.onDismiss?.call();
    });
  }

  void _handleCTA(String action) {
    final config = widget.campaign.config;
    widget.onCTAClick?.call(action, config);
  }

  void _toggleExpand() {
    setState(() {
      _isExpanded = !_isExpanded;
    });
  }

  @override
  Widget build(BuildContext context) {
    final config = widget.campaign.config;
    final variant = config['variant']?.toString() ?? 'card'; // card, banner, compact
    
    return FadeTransition(
      opacity: _fadeAnimation,
      child: AnimatedBuilder(
        animation: _slideAnimation,
        builder: (context, child) {
          return Transform.translate(
            offset: Offset(0, _slideAnimation.value),
            child: child,
          );
        },
        child: _buildVariant(variant, config),
      ),
    );
  }

  Widget _buildVariant(String variant, Map<String, dynamic> config) {
    switch (variant) {
      case 'banner':
        return _buildBannerVariant(config);
      case 'compact':
        return _buildCompactVariant(config);
      case 'card':
      default:
        return _buildCardVariant(config);
    }
  }

  Widget _buildCardVariant(Map<String, dynamic> config) {
    final backgroundColor = _parseColor(config['backgroundColor']) ?? const Color(0xFFF3F4F6);
    final textColor = _parseColor(config['textColor']) ?? Colors.black;
    final title = config['title']?.toString();
    final text = config['text']?.toString() ?? 'Check this out!';
    final imageUrl = config['imageUrl']?.toString();
    final buttonText = config['buttonText']?.toString();
    final dismissible = config['dismissible'] != false;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _parseColor(config['borderColor']) ?? Colors.grey.withOpacity(0.2),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Image header (optional)
          if (imageUrl != null)
            ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
              child: Image.network(
                imageUrl,
                height: 150,
                width: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const SizedBox(),
              ),
            ),

          // Content
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header with title and close button
                Row(
                  children: [
                    Expanded(
                      child: title != null
                          ? Text(
                              title,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: textColor,
                              ),
                            )
                          : const SizedBox.shrink(),
                    ),
                    if (dismissible)
                      IconButton(
                        icon: Icon(
                          Icons.close,
                          size: 18,
                          color: textColor.withOpacity(0.6),
                        ),
                        onPressed: _handleDismiss,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(
                          minWidth: 32,
                          minHeight: 32,
                        ),
                      ),
                  ],
                ),

                if (title != null) const SizedBox(height: 8),

                // Message
                Text(
                  text,
                  style: TextStyle(
                    fontSize: 14,
                    color: textColor.withOpacity(0.8),
                    height: 1.5,
                  ),
                ),

                // CTA Button (optional)
                if (buttonText != null) ...[
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => _handleCTA('primary'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _parseColor(config['buttonColor']) ?? 
                                       Theme.of(context).primaryColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        elevation: 0,
                      ),
                      child: Text(
                        buttonText,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBannerVariant(Map<String, dynamic> config) {
    final backgroundColor = _parseColor(config['backgroundColor']) ?? const Color(0xFFEEF2FF);
    final textColor = _parseColor(config['textColor']) ?? const Color(0xFF1E40AF);
    final text = config['text']?.toString() ?? 'New update available';
    final iconData = _getIconData(config['icon']?.toString());
    final buttonText = config['buttonText']?.toString();
    final dismissible = config['dismissible'] != false;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          // Icon
          if (iconData != null)
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Icon(iconData, color: textColor, size: 24),
            ),

          // Text
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 13,
                color: textColor,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),

          // CTA Button
          if (buttonText != null)
            TextButton(
              onPressed: () => _handleCTA('primary'),
              style: TextButton.styleFrom(
                foregroundColor: textColor,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              ),
              child: Text(
                buttonText,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),

          // Close button
          if (dismissible)
            IconButton(
              icon: Icon(Icons.close, size: 16, color: textColor.withOpacity(0.6)),
              onPressed: _handleDismiss,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
            ),
        ],
      ),
    );
  }

  Widget _buildCompactVariant(Map<String, dynamic> config) {
    final backgroundColor = _parseColor(config['backgroundColor']) ?? Colors.white;
    final textColor = _parseColor(config['textColor']) ?? Colors.black;
    final text = config['text']?.toString() ?? 'Tip';
    final iconData = _getIconData(config['icon']?.toString());

    return InkWell(
      onTap: _toggleExpand,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: Colors.grey.withOpacity(0.3),
            width: 1,
          ),
        ),
        child: Row(
          children: [
            // Icon
            if (iconData != null)
              Padding(
                padding: const EdgeInsets.only(right: 10),
                child: Icon(iconData, color: textColor.withOpacity(0.7), size: 20),
              ),

            // Text
            Expanded(
              child: Text(
                text,
                style: TextStyle(
                  fontSize: 13,
                  color: textColor,
                ),
                maxLines: _isExpanded ? null : 1,
                overflow: _isExpanded ? null : TextOverflow.ellipsis,
              ),
            ),

            // Expand icon
            Icon(
              _isExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
              size: 18,
              color: textColor.withOpacity(0.6),
            ),
          ],
        ),
      ),
    );
  }

  IconData? _getIconData(String? iconName) {
    switch (iconName) {
      case 'info':
        return Icons.info_outline;
      case 'warning':
        return Icons.warning_amber_outlined;
      case 'star':
        return Icons.star_outline;
      case 'gift':
        return Icons.card_giftcard_outlined;
      case 'notification':
        return Icons.notifications_outlined;
      default:
        return null;
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
