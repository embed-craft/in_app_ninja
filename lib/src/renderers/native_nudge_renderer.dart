import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import '../models/campaign.dart';
import 'nudge_renderers/bottom_sheet_nudge_renderer.dart';

/// Native platform view renderer that uses WebView for perfect layout parity
class NativeNudgeRenderer extends StatelessWidget {
  final Campaign campaign;
  
  const NativeNudgeRenderer({
    Key? key,
    required this.campaign,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Use native rendering on mobile platforms
    if (Platform.isAndroid) {
      return _buildAndroidView();
    } else if (Platform.isIOS) {
      return _buildIOSView();
    }
    
    // Fallback to Flutter widgets on other platforms
    return BottomSheetNudgeRenderer(campaign: campaign);
  }

  Widget _buildAndroidView() {
    // Merge campaign config with root-level fields
    // Ensure vital fields like type and layers are explicitly passed
    final campaignJson = campaign.toJson();
    final campaignData = {
      // Base config
      ...campaign.config,
      // Root overrides/fallbacks
      'type': campaign.type,
      'nudgeType': campaign.type,
      'id': campaign.id,
      // Ensure layers are present
      'layers': campaign.layers ?? campaign.config['layers'] ?? campaignJson['layers'] ?? [],
      'components': campaign.layers ?? campaign.config['components'] ?? campaignJson['layers'] ?? [],
    };
    
    return AndroidView(
      viewType: 'ninja_native_view',
      creationParams: {
        'config': jsonEncode(campaignData),
      },
      creationParamsCodec: const StandardMessageCodec(),
      gestureRecognizers: <Factory<OneSequenceGestureRecognizer>>{
        Factory<VerticalDragGestureRecognizer>(
          () => VerticalDragGestureRecognizer(),
        ),
        Factory<TapGestureRecognizer>(
          () => TapGestureRecognizer(),
        ),
      },
    );
  }

  Widget _buildIOSView() {
    // Merge campaign config with root-level fields
    final campaignJson = campaign.toJson();
    final campaignData = {
      ...campaign.config,
      'type': campaign.type,
      'nudgeType': campaign.type,
      'id': campaign.id,
      'layers': campaign.layers ?? campaign.config['layers'] ?? campaignJson['layers'] ?? [],
      'components': campaign.layers ?? campaign.config['components'] ?? campaignJson['layers'] ?? [],
    };
    
    return UiKitView(
      viewType: 'ninja_native_view',
      creationParams: {
        'config': jsonEncode(campaignData),
      },
      creationParamsCodec: const StandardMessageCodec(),
      gestureRecognizers: <Factory<OneSequenceGestureRecognizer>>{
        Factory<VerticalDragGestureRecognizer>(
          () => VerticalDragGestureRecognizer(),
        ),
      },
    );
  }
}
