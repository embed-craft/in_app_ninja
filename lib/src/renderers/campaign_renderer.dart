import 'package:flutter/material.dart';
import '../models/campaign.dart';
import 'nudge_renderers/modal_nudge_renderer_v2.dart';
import 'nudge_renderers/banner_nudge_renderer_v2.dart';
import 'nudge_renderers/tooltip_nudge_renderer_v2.dart';
import 'nudge_renderers/bottom_sheet_nudge_renderer_v2.dart';
import 'nudge_renderers/pip_nudge_renderer_v2.dart';
import 'nudge_renderers/scratch_card_renderer.dart';
import 'nudge_renderers/story_carousel_renderer.dart';
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

      case 'bottom_sheet':
      case 'bottomsheet':
        return BottomSheetNudgeRenderer(
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
    VoidCallback? onImpression,
    VoidCallback? onDismiss,
    Function(String action, Map<String, dynamic>? data)? onCTAClick,
  }) {
    final type = campaign.config['type']?.toString().toLowerCase() ?? 'modal';

    // For overlay types (modal, bottom sheet, etc.), use dialog
    if (['modal', 'dialog', 'bottom_sheet', 'bottomsheet'].contains(type)) {
      final future = showDialog(
        context: context,
        barrierDismissible: campaign.config['dismissible'] != false,
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
      
      // Return dismiss function
      return () {
        // We need to be careful here. Navigator.pop might pop the wrong thing if
        // the user has navigated. But for now, assuming the dialog is top-most
        // or we want to close whatever is top.
        // A safer way would be to check if the dialog is still active.
        // But showDialog doesn't give us a controller.
        // We'll use the context passed to showDialog.
        if (Navigator.canPop(context)) {
          Navigator.of(context).pop();
        }
      };
    }
    // For floating types, use overlay
    else if (['pip', 'floater', 'floating', 'banner'].contains(type)) {
      final overlay = Overlay.of(context);
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
}
