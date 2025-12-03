import 'package:flutter/material.dart';
import '../app_ninja.dart';

/// NinjaTrackedView - Widget wrapper for automatic visibility tracking
///
/// Similar to NudgeTrackedView from nudgecore_v2
///
/// Wraps any widget to automatically track its visibility and position
///
/// Example:
/// ```dart
/// NinjaTrackedView(
///   label: 'signup_button',
///   child: ElevatedButton(
///     onPressed: () {},
///     child: Text('Sign Up'),
///   ),
/// )
/// ```
class NinjaTrackedView extends StatefulWidget {
  final String label;
  final Widget child;
  final Function(String label, bool visible)? onVisibilityChanged;

  const NinjaTrackedView({
    super.key,
    required this.label,
    required this.child,
    this.onVisibilityChanged,
  });

  @override
  State<NinjaTrackedView> createState() => _NinjaTrackedViewState();
}

class _NinjaTrackedViewState extends State<NinjaTrackedView> {
  final GlobalKey _key = GlobalKey();

  @override
  void initState() {
    super.initState();
    NinjaWidgetTracker.register(widget.label, _key);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkVisibility();
    });
  }

  @override
  void didUpdateWidget(covariant NinjaTrackedView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.label != widget.label) {
      NinjaWidgetTracker.unregister(oldWidget.label);
      NinjaWidgetTracker.register(widget.label, _key);
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkVisibility();
    });
  }

  @override
  void dispose() {
    NinjaWidgetTracker.unregister(widget.label);
    super.dispose();
  }

  void _checkVisibility() {
    if (!mounted) return;

    final renderBox = _key.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox != null && renderBox.hasSize) {
      final position = renderBox.localToGlobal(Offset.zero);
      final size = renderBox.size;

      // Simple visibility check (on screen)
      final screenHeight = MediaQuery.of(context).size.height;
      final isVisible =
          position.dy < screenHeight && position.dy + size.height > 0;

      widget.onVisibilityChanged?.call(widget.label, isVisible);

      // Track widget view
      if (isVisible) {
        AppNinja.track('widget_viewed', properties: {
          'label': widget.label,
          'x': position.dx,
          'y': position.dy,
          'width': size.width,
          'height': size.height,
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      key: _key,
      child: widget.child,
    );
  }
}

/// Extension method for easy inline tracking
///
/// Similar to nudgeWidgetLabel from nudgecore_v2
///
/// Usage:
/// ```dart
/// Text('Hello').ninjaLabel('greeting_text')
/// ```
extension NinjaTrackX on Widget {
  Widget ninjaLabel(String label) {
    return NinjaTrackedView(label: label, child: this);
  }

  Widget ninjaWidgetLabel(String label) {
    return NinjaTrackedView(label: label, child: this);
  }
}

/// NinjaWidgetTracker - Internal tracker for managing widget registrations
///
/// Similar to NudgeWidgetTracker from nudgecore_v2
class NinjaWidgetTracker {
  static final Map<String, GlobalKey> _trackedWidgets = {};

  /// Register a widget with a label
  static void register(String label, GlobalKey key) {
    _trackedWidgets[label] = key;
    AppNinja.debugLog('Registered widget: $label');
  }

  /// Unregister a widget
  static void unregister(String label) {
    _trackedWidgets.remove(label);
    AppNinja.debugLog('Unregistered widget: $label');
  }

  /// Get all tracked widget labels
  static List<String> getAllLabels() {
    return _trackedWidgets.keys.toList();
  }

  /// Get widget details by label
  static Map<String, dynamic>? getWidgetDetails(String label) {
    final key = _trackedWidgets[label];
    if (key == null) return null;

    final context = key.currentContext;
    if (context == null) return null;

    final renderBox = context.findRenderObject() as RenderBox?;
    if (renderBox == null || !renderBox.hasSize) return null;

    final position = renderBox.localToGlobal(Offset.zero);
    final size = renderBox.size;

    return {
      'label': label,
      'x': position.dx,
      'y': position.dy,
      'width': size.width,
      'height': size.height,
      'visible': true,
    };
  }

  /// Get all tracked widget details
  static List<Map<String, dynamic>> getAllWidgetDetails() {
    final details = <Map<String, dynamic>>[];
    for (final label in _trackedWidgets.keys) {
      final widgetDetails = getWidgetDetails(label);
      if (widgetDetails != null) {
        details.add(widgetDetails);
      }
    }
    return details;
  }

  /// Check if widget is visible on screen
  static bool isWidgetVisible(String label, BuildContext context) {
    final details = getWidgetDetails(label);
    if (details == null) return false;

    final screenHeight = MediaQuery.of(context).size.height;
    final y = details['y'] as double;
    final height = details['height'] as double;

    return y < screenHeight && y + height > 0;
  }
}
