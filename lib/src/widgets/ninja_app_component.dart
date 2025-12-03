import 'package:flutter/material.dart';
import '../app_ninja.dart';
import '../models/campaign.dart';

/// NinjaAppComponent - Widget for embedding nudges at specific locations
///
/// Similar to NudgeAppComponent from nudgecore_v2
///
/// This widget displays campaigns targeted to a specific component ID.
/// Use it to embed nudges inline within your app's UI.
///
/// Example:
/// ```dart
/// NinjaAppComponent(id: 'home_banner')
/// ```
class NinjaAppComponent extends StatefulWidget {
  /// Unique identifier for this component
  final String id;

  /// Optional custom builder for rendering campaigns
  final Widget Function(BuildContext, Campaign)? builder;

  /// Default margin around the component
  final double margin;

  const NinjaAppComponent({
    super.key,
    required this.id,
    this.builder,
    this.margin = 0.0,
  });

  @override
  State<NinjaAppComponent> createState() => _NinjaAppComponentState();
}

class _NinjaAppComponentState extends State<NinjaAppComponent> {
  List<Campaign> _campaigns = [];

  @override
  void initState() {
    super.initState();
    _loadCampaigns();

    // Listen for campaign updates
    AppNinja.onCampaigns.listen((campaigns) {
      if (mounted) {
        setState(() {
          _campaigns = campaigns
              .where((c) => c.config['component_id'] == widget.id)
              .toList();
        });
      }
    });
  }

  Future<void> _loadCampaigns() async {
    try {
      final campaigns = await AppNinja.fetchCampaigns();
      if (mounted) {
        setState(() {
          _campaigns = campaigns
              .where((c) => c.config['component_id'] == widget.id)
              .toList();
        });
      }
    } catch (e) {
      AppNinja.debugLog(
          'Error loading campaigns for component ${widget.id}: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_campaigns.isEmpty) {
      return const SizedBox.shrink();
    }

    final campaign = _campaigns.first;

    // Use custom builder if provided
    if (widget.builder != null) {
      return Padding(
        padding: EdgeInsets.all(widget.margin),
        child: widget.builder!(context, campaign),
      );
    }

    // Default rendering
    return Padding(
      padding: EdgeInsets.all(widget.margin),
      child: _buildDefaultCampaign(campaign),
    );
  }

  Widget _buildDefaultCampaign(Campaign campaign) {
    final imageUrl = campaign.config['image_url'] as String?;
    final actionUrl = campaign.config['action_url'] as String?;

    return Card(
      elevation: 2,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (imageUrl != null)
            Image.network(
              imageUrl,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => const SizedBox.shrink(),
            ),
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (campaign.title.isNotEmpty)
                  Text(
                    campaign.title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                if (campaign.description != null &&
                    campaign.description!.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    campaign.description!,
                    style: const TextStyle(fontSize: 14),
                  ),
                ],
                if (actionUrl != null) ...[
                  const SizedBox(height: 12),
                  ElevatedButton(
                    onPressed: () {
                      AppNinja.track('campaign_action_clicked', properties: {
                        'campaign_id': campaign.id,
                        'component_id': widget.id,
                        'action_url': actionUrl,
                      });
                      // Handle action
                      AppNinja.triggerRedirect({
                        'url': actionUrl,
                        'campaign_id': campaign.id,
                      });
                    },
                    child: const Text('Learn More'),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
