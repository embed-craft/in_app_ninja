import 'package:flutter/material.dart';
import 'dart:io';
import '../models/campaign.dart';
import 'nudge_renderers/modal_nudge_renderer.dart';
import 'nudge_renderers/banner_nudge_renderer.dart';
import 'nudge_renderers/tooltip_nudge_renderer.dart';
import 'nudge_renderers/bottom_sheet_nudge_renderer.dart';
import 'native_nudge_renderer.dart';

import 'nudge_renderers/pip_nudge_renderer_v2.dart';
import 'nudge_renderers/scratch_card_renderer.dart';
import 'nudge_renderers/story_carousel_renderer.dart';
import 'nudge_renderers/inline_nudge_renderer.dart';
import 'nudge_renderers/floater_nudge_renderer.dart';

/// Core Campaign Renderer
///
/// Parses campaign JSON and routes to appropriate nudge renderer
/// Handles animations, tracking, and lifecycle management
class NinjaCampaignRenderer {
  /// Render a campaign based on its type
  static Widget render({
    required Campaign campaign,
    required BuildContext context,
    VoidCallback? onImpression,
    VoidCallback? onDismiss,
    Function(String action, Map<String, dynamic>? data)? onCTAClick,
  }) {
    // Parse nudge config
    final config = campaign.config;
    final type = config['type']?.toString().toLowerCase() ?? 'modal';

    // Auto-track impression when widget builds
    WidgetsBinding.instance.addPostFrameCallback((_) {
      onImpression?.call();
    });

    // Route to specific renderer based on type
    switch (type) {
      case 'modal':
      case 'dialog':
        return ModalNudgeRenderer(
          campaign: campaign,
          onDismiss: onDismiss,
          onCTAClick: onCTAClick,
        );

      case 'bottomsheet':
        // Use native rendering on mobile for perfect layout parity
        if (Platform.isAndroid || Platform.isIOS) {
          return NativeNudgeRenderer(
            campaign: campaign,
          );
        }
        // Fallback to Flutter widgets on other platforms
        return BottomSheetNudgeRenderer(
          campaign: campaign,
          onDismiss: onDismiss,
          onCTAClick: onCTAClick,
        );

      case 'banner':
      case 'top_banner':
      case 'bottom_banner':
        return BannerNudgeRenderer(
          campaign: campaign,
          onDismiss: onDismiss,
          onCTAClick: onCTAClick,
        );

      case 'tooltip':
        return TooltipNudgeRenderer(
          campaign: campaign,
          onDismiss: onDismiss,
          onCTAClick: onCTAClick,
        );



      case 'pip':
        return PIPNudgeRendererV2(
          campaign: campaign,
          onDismiss: onDismiss,
          onCTAClick: onCTAClick,
        );

      case 'floater':
      case 'floating':
        return FloaterNudgeRenderer(
          campaign: campaign,
          onDismiss: onDismiss,
          onCTAClick: onCTAClick,
        );

      case 'scratch':
      case 'scratch_card':
        return ScratchCardNudgeRenderer(
          campaign: campaign,
          onDismiss: onDismiss,
          onCTAClick: onCTAClick,
        );

      case 'story':
      case 'story_carousel':
      case 'stories':
        return StoryCarouselNudgeRenderer(
          campaign: campaign,
          onDismiss: onDismiss,
          onCTAClick: onCTAClick,
        );

      case 'inline':
      case 'widget':
        return InlineNudgeRenderer(
          campaign: campaign,
          onDismiss: onDismiss,
          onCTAClick: onCTAClick,
        );

      default:
        // Fallback to modal for unknown types
        debugPrint('Unknown nudge type: $type, falling back to modal');
        return ModalNudgeRenderer(
          campaign: campaign,
          onDismiss: onDismiss,
          onCTAClick: onCTAClick,
        );
    }
  }

  /// Show campaign as overlay
  /// Returns a function to dismiss the campaign programmatically
  static VoidCallback show({
    required Campaign campaign,
    required BuildContext context,
    OverlayState? overlayState, // Allow explicit overlay state for global key usage
    VoidCallback? onImpression,
    VoidCallback? onDismiss,
    Function(String action, Map<String, dynamic>? data)? onCTAClick,
  }) {
    final type = campaign.config['type']?.toString().toLowerCase() ?? 'modal';

    // For modal/dialog/bottomsheet types
    if (['modal', 'dialog', 'bottomsheet'].contains(type)) {
      final overlayColor = _parseColor(campaign.config['overlay']?['color']);
      final overlayOpacity = (campaign.config['overlay']?['opacity'] as num?)?.toDouble() ?? 0.5;
      final barrierColor = overlayColor?.withOpacity(overlayOpacity) ?? Colors.black54;

      final future = showDialog(
        context: context,
        barrierDismissible: campaign.config['dismissible'] != false,
        barrierColor: barrierColor,
        builder: (dialogContext) => render(
          campaign: campaign,
          context: dialogContext,
          onImpression: onImpression,
          onDismiss: () {
            Navigator.of(dialogContext).pop();
            onDismiss?.call();
          },
          onCTAClick: onCTAClick,
        ),
      );
      
      return () {
        if (Navigator.canPop(context)) {
          Navigator.of(context).pop();
        }
      };
    }

    // For floating types, use overlay
    else if (['pip', 'floater', 'floating', 'banner', 'tooltip'].contains(type)) {
      // Use provided state or look up from context. 
      // Note: If context is from the Overlay widget itself (via GlobalKey), Overlay.of() might fail (looks for ancestor),
      // so passing overlayState explicitly is safer for auto-rendering.
      final overlay = overlayState ?? Overlay.of(context);
      
      if (overlay == null) {
        debugPrint('NinjaCampaignRenderer: No Overlay found for context. Cannot show $type campaign.');
        return () {};
      }

      late OverlayEntry entry;

      entry = OverlayEntry(
        builder: (context) => render(
          campaign: campaign,
          context: context,
          onImpression: onImpression,
          onDismiss: () {
            entry.remove();
            onDismiss?.call();
          },
          onCTAClick: onCTAClick,
        ),
      );

      overlay.insert(entry);
      
      return () {
        if (entry.mounted) {
          entry.remove();
        }
      };
    }
    // For inline types, show as widget (requires parent widget integration)
    else {
      debugPrint('Inline nudge type requires direct widget integration');
      return () {};
    }
  }

  static Color? _parseColor(dynamic color) {
    if (color == null) return null;
    if (color is Color) return color;
    final colorStr = color.toString();
    if (colorStr.startsWith('#')) {
      final hexColor = colorStr.replaceFirst('#', '');
      if (hexColor.length == 6) {
        return Color(int.parse('FF$hexColor', radix: 16));
      } else if (hexColor.length == 8) {
        return Color(int.parse(hexColor, radix: 16));
      }
    }
    return null;
  }
}
