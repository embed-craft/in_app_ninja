import 'package:flutter/material.dart';
import 'dart:io';
import '../models/campaign.dart';
import 'nudge_renderers/modal_nudge_renderer.dart';
import 'nudge_renderers/banner_nudge_renderer.dart';
import '../callbacks/ninja_callback_manager.dart';
import '../app_ninja.dart';

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

    debugPrint('🎨 [CampaignRenderer] Rendering campaign: ${campaign.id}');
    debugPrint('   Type: "$type" (Raw config type: ${config['type']})');
    debugPrint('   Config keys: ${config.keys.toList()}');

    // Callback Wrappers with NinjaCallbackManager dispatch
    final wrappedOnImpression = () {
      onImpression?.call();
      NinjaCallbackManager.dispatchExperienceOpen(
        campaignId: campaign.id,
        displayType: type,
      );
      // Send analytics to backend with campaign ID for report tracking
      AppNinja.track(
        'impression',
        properties: {
          'nudgeId': campaign.id,
          'campaignId': campaign.id,
          'type': type,
        },
      );
    };

    final wrappedOnDismiss = () {
      onDismiss?.call();
      NinjaCallbackManager.dispatchExperienceDismiss(
        campaignId: campaign.id,
        displayType: type,
      );
    };

    final wrappedOnCTAClick = (String action, Map<String, dynamic>? data) {
      onCTAClick?.call(action, data);
      NinjaCallbackManager.dispatchComponentCtaClick(
        campaignId: campaign.id,
        widgetId: data?['id'] ?? 'unknown',
        clickType: action,
        additionalData: data,
      );
      // Send click analytics to backend with campaign ID
      AppNinja.track(
        'click',
        properties: {
          'nudgeId': campaign.id,
          'campaignId': campaign.id,
          'type': type,
          'action': action,
          ...?data,
        },
      );
    };

    // Auto-track impression when widget builds
    WidgetsBinding.instance.addPostFrameCallback((_) {
      wrappedOnImpression();
    });

    // Route to specific renderer based on type
    switch (type) {
      case 'modal':
      case 'dialog':
        return ModalNudgeRenderer(
          campaign: campaign,
          onDismiss: wrappedOnDismiss,
          onCTAClick: wrappedOnCTAClick,
        );

      case 'bottomsheet':
        // PARITY FIX: Use Flutter renderer (like Modal) for consistent layer positioning
        // Previously used NativeNudgeRenderer (WebView) which had different scaling logic
        return BottomSheetNudgeRenderer(
          campaign: campaign,
          onDismiss: wrappedOnDismiss,
          onCTAClick: wrappedOnCTAClick,
        );



      case 'banner':
      case 'top_banner':
      case 'bottom_banner':
        return BannerNudgeRenderer(
          campaign: campaign,
          onDismiss: wrappedOnDismiss,
          onCTAClick: wrappedOnCTAClick,
        );

      case 'tooltip':
        return TooltipNudgeRenderer(
          campaign: campaign,
          onDismiss: wrappedOnDismiss,
          onCTAClick: wrappedOnCTAClick,
        );



      case 'pip':
        return PIPNudgeRendererV2(
          campaign: campaign,
          onDismiss: wrappedOnDismiss,
          onCTAClick: wrappedOnCTAClick,
        );

      case 'floater':
      case 'floating':
        return FloaterNudgeRenderer(
          campaign: campaign,
          onDismiss: wrappedOnDismiss,
          onCTAClick: wrappedOnCTAClick,
        );

      case 'scratch':
      case 'scratch_card':
      case 'scratchcard':
      case 'scratch-card':
        return ScratchCardNudgeRenderer(
          campaign: campaign,
          onDismiss: wrappedOnDismiss,
          onCTAClick: wrappedOnCTAClick,
        );

      case 'story':
      case 'story_carousel':
      case 'storycarousel':
      case 'stories':
      case 'story-carousel':
        return StoryCarouselNudgeRenderer(
          campaign: campaign,
          onDismiss: wrappedOnDismiss,
          onCTAClick: wrappedOnCTAClick,
        );

      case 'inline':
      case 'widget':
        return InlineNudgeRenderer(
          campaign: campaign,
          onDismiss: wrappedOnDismiss,
          onCTAClick: wrappedOnCTAClick,
        );

      default:
        // Fallback to modal for unknown types
        debugPrint('Unknown nudge type: $type, falling back to modal');
        return ModalNudgeRenderer(
          campaign: campaign,
          onDismiss: wrappedOnDismiss,
          onCTAClick: wrappedOnCTAClick,
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
    debugPrint('NinjaCampaignRenderer: 🎯 Resolving presentation for type: "$type"');

    // For modal/dialog/bottomsheet types
    if (['modal', 'dialog', 'bottomsheet', 'scratch', 'scratch_card', 'scratchcard', 'scratch-card', 'story', 'story_carousel', 'storycarousel', 'stories', 'story-carousel'].contains(type)) {
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
