import 'package:flutter/material.dart';
import '../app_ninja.dart';
import '../models/campaign.dart';
import 'ninja_view.dart';

/// NinjaWidget - Inline widget for embedding campaigns
///
/// Place this widget anywhere in your app to show targeted campaigns inline.
/// The widget automatically fetches and displays campaigns based on the valueKey.
///
/// Example:
/// ```dart
/// NinjaWidget(
///   valueKey: 'home_banner',
///   defaultMargin: 16.0,
/// )
/// ```
class NinjaWidget extends StatefulWidget {
  final String valueKey;
  final double defaultMargin;
  final Widget Function(Campaign campaign)? customBuilder;

  const NinjaWidget({
    Key? key,
    required this.valueKey,
    this.defaultMargin = 8.0,
    this.customBuilder,
  }) : super(key: key);

  @override
  State<NinjaWidget> createState() => NinjaWidgetState();
}

class NinjaWidgetState extends State<NinjaWidget> {
  static final Map<String, Size> _widgetDimensions = {};

  Campaign? _campaign;
  bool _visible = false;
  double _height = 200.0;
  double _width = double.infinity;
  int _lastRefreshTime = 0;

  @override
  void initState() {
    super.initState();

    // Load stored dimensions if available
    if (_widgetDimensions.containsKey(widget.valueKey)) {
      final storedSize = _widgetDimensions[widget.valueKey]!;
      _height = storedSize.height;
      _width = storedSize.width;
      _visible = true;
    }

    _loadCampaign();

    // Listen to campaign updates
    AppNinja.onCampaigns.listen((campaigns) {
      _updateCampaign(campaigns);
    });
  }

  Future<void> _loadCampaign() async {
    try {
      final campaigns = await AppNinja.fetchCampaigns();
      _updateCampaign(campaigns);
    } catch (e) {
      AppNinja.debugLog('NinjaWidget error loading campaign: $e');
    }
  }

  void _updateCampaign(List<Campaign> campaigns) {
    // Find campaign matching this widget's valueKey
    final matching = campaigns
        .where(
          (c) =>
              c.config['placement'] == widget.valueKey ||
              c.config['widget_id'] == widget.valueKey ||
              c.id == widget.valueKey,
        )
        .toList();

    if (matching.isNotEmpty && mounted) {
      setState(() {
        _campaign = matching.first;
        _visible = true;
      });

      // Track impression
      AppNinja.track(
        'campaign_impression',
        properties: {
          'campaign_id': _campaign!.id,
          'campaign_type': _campaign!.type,
          'placement': widget.valueKey,
        },
      );
    }
  }

  /// Refresh widget content (similar to PlotlineWidget)
  void refreshWidget() {
    AppNinja.debugLog('NinjaWidget refresh: ${widget.valueKey}');

    // Throttle refresh to max once per second
    final now = DateTime.now().millisecondsSinceEpoch;
    if (now - _lastRefreshTime < 1000) {
      return;
    }
    _lastRefreshTime = now;

    _loadCampaign();
  }

  /// Reload widget (reset and fetch fresh)
  void reloadWidget() {
    AppNinja.debugLog('NinjaWidget reload: ${widget.valueKey}');

    setState(() {
      _visible = false;
      _campaign = null;
    });

    // Remove stored dimensions
    _widgetDimensions.remove(widget.valueKey);

    // Reload after frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadCampaign();
    });
  }

  /// Update stored dimensions
  void updateDimensions(double height, double width) {
    AppNinja.debugLog(
      'NinjaWidget updateDimensions: ${widget.valueKey} - $height x $width',
    );

    _widgetDimensions[widget.valueKey] = Size(width, height);

    if (mounted) {
      setState(() {
        _height = height;
        _width = width;
        _visible = true;
      });
    }
  }

  /// Get current dimensions
  Size? get dimensions => _widgetDimensions[widget.valueKey];

  @override
  Widget build(BuildContext context) {
    if (!_visible || _campaign == null) {
      return const SizedBox.shrink();
    }

    return NinjaView(
      valueKey: widget.valueKey,
      isWidget: true,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        height: _height,
        width: _width == double.infinity ? null : _width,
        margin: EdgeInsets.all(widget.defaultMargin),
        child: widget.customBuilder != null
            ? widget.customBuilder!(_campaign!)
            : _buildDefaultCampaign(),
      ),
    );
  }

  Widget _buildDefaultCampaign() {
    if (_campaign == null) return const SizedBox.shrink();

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_campaign!.config['image'] != null)
              Image.network(
                _campaign!.config['image'],
                height: 150,
                width: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const SizedBox.shrink(),
              ),
            const SizedBox(height: 12),
            Text(
              _campaign!.title,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            if (_campaign!.description != null) ...[
              const SizedBox(height: 8),
              Text(
                _campaign!.description!,
                style: const TextStyle(fontSize: 14),
              ),
            ],
            if (_campaign!.config['button'] != null) ...[
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () {
                  AppNinja.track(
                    'campaign_clicked',
                    properties: {
                      'campaign_id': _campaign!.id,
                      'campaign_type': _campaign!.type,
                    },
                  );
                  // Handle CTA
                },
                child: Text(_campaign!.config['button'].toString()),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
