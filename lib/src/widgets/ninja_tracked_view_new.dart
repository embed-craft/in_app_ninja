import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../app_ninja.dart';
import '../models/ninja_widget_details.dart';

/// Internal model for tracked entries
class _TrackedEntry {
  _TrackedEntry(this.label, {this.element, this.key, required this.gen});
  final String label;
  Element? element; // wrapper source (preferred)
  GlobalKey? key; // legacy source
  final int gen; // generation to enforce "latest wins"
}

/// NinjaTrackedView - Widget wrapper for automatic tracking
///
/// Similar to NudgeTrackedView from nudgecore_v2
///
/// Usage:
/// ```dart
/// NinjaTrackedView(
///   label: 'my_button',
///   child: ElevatedButton(...),
/// )
/// ```
class NinjaTrackedView extends StatefulWidget {
  final String label;
  final Widget child;

  const NinjaTrackedView({
    Key? key,
    required this.label,
    required this.child,
  }) : super(key: key);

  @override
  State<NinjaTrackedView> createState() => _NinjaTrackedViewState();
}

class _NinjaTrackedViewState extends State<NinjaTrackedView> {
  int? _gen; // generation assigned at register

  @override
  void initState() {
    super.initState();
    _gen = NinjaWidgetTracker._registerContext(widget.label, context);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      NinjaWidgetTracker._refreshContext(widget.label);
    });
  }

  @override
  void didUpdateWidget(covariant NinjaTrackedView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.label != widget.label) {
      // unregister the old label only if this instance still owns it
      if (_gen != null) {
        NinjaWidgetTracker._unregister(label: oldWidget.label, gen: _gen);
      }
      _gen = NinjaWidgetTracker._registerContext(widget.label, context);
    } else {
      // same label, refresh binding to current context
      _gen = NinjaWidgetTracker._registerContext(widget.label, context);
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      NinjaWidgetTracker._refreshContext(widget.label);
    });
  }

  @override
  void dispose() {
    if (_gen != null) {
      NinjaWidgetTracker._unregister(label: widget.label, gen: _gen);
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
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

/// NinjaWidgetTracker - Advanced widget tracking system
///
/// Similar to NudgeWidgetTracker from nudgecore_v2
/// Supports both Element-based and GlobalKey-based tracking
class NinjaWidgetTracker {
  static final Map<String, _TrackedEntry> _entries = {};
  static int _nextGen = 1; // monotonically increasing per registration

  /// Legacy API: return a GlobalKey (latest registration wins)
  static GlobalKey register(String label) {
    final gen = _nextGen++;
    final gk = GlobalKey();
    _entries[label] = _TrackedEntry(label, key: gk, gen: gen);
    AppNinja.debugLog('Registered widget: $label (gen: $gen)');
    return gk;
  }

  /// Register a pre-existing GlobalKey
  static void registerKey(String label, GlobalKey key) {
    final gen = _nextGen++;
    _entries[label] = _TrackedEntry(label, key: key, gen: gen);
    AppNinja.debugLog('Registered key for widget: $label (gen: $gen)');
  }

  /// New: wrapper path registers a context and returns its generation
  static int _registerContext(String label, BuildContext ctx) {
    final gen = _nextGen++;
    _entries[label] = _TrackedEntry(label, element: (ctx as Element), gen: gen);
    AppNinja.debugLog('Registered context for widget: $label (gen: $gen)');
    return gen;
  }

  /// Unregister only if the caller still owns the mapping (generation matches)
  static void _unregister({required String label, required int? gen}) {
    final current = _entries[label];
    if (current != null && gen != null && current.gen == gen) {
      _entries.remove(label);
      AppNinja.debugLog('Unregistered widget: $label (gen: $gen)');
    }
  }

  /// Legacy explicit remove (no gen check) — use with care
  static void unregister(String label) {
    _entries.remove(label);
    AppNinja.debugLog('Unregistered widget: $label');
  }

  /// Clear all tracked widgets for current screen
  /// CRITICAL: Called by NinjaTrackerObserver on navigation
  static void clearForCurrentScreen() {
    AppNinja.debugLog(
        'Clearing tracked entries for current screen (${_entries.length} widgets)');
    _entries.clear();
  }

  static void _refreshContext(String label) {
    // no-op for now; we always query live render objects
  }

  /// ======== Helper methods ========

  static RenderBox? _resolveRenderBox(String label) {
    final e = _entries[label];
    if (e == null) return null;

    // Prefer wrapper context (Element)
    final roFromElement = e.element?.renderObject;
    if (roFromElement is RenderBox && roFromElement.attached) {
      return roFromElement;
    }

    // Fallback to legacy GlobalKey
    final roFromKey = e.key?.currentContext?.findRenderObject();
    if (roFromKey is RenderBox && roFromKey.attached) {
      return roFromKey;
    }
    return null;
  }

  static ScrollController? _scrollControllerFor(String label) {
    final e = _entries[label];
    if (e == null) return null;
    final ctx = e.element ?? e.key?.currentContext;
    if (ctx == null) return null;

    final scrollable = Scrollable.maybeOf(ctx);
    if (scrollable == null) return null;
    return scrollable.widget.controller ?? PrimaryScrollController.maybeOf(ctx);
  }

  static Offset _globalTopLeft(RenderBox box) {
    final m = box.getTransformTo(null);
    return MatrixUtils.transformPoint(m, Offset.zero);
  }

  /// Check if page is currently scrolling
  static Future<bool> _checkPageScrollStatus(String label) async {
    final controller = _scrollControllerFor(label);
    return controller?.position.isScrollingNotifier.value ?? false;
  }

  /// Check if widget position is stable
  static Future<bool> _isWidgetStable(
    String label, {
    Duration stabilityDuration = const Duration(milliseconds: 500),
    Duration checkInterval = const Duration(milliseconds: 100),
    double tolerance = 5.0,
  }) async {
    var box = _resolveRenderBox(label);
    if (box == null || !box.hasSize) return false;

    Offset lastPos = _globalTopLeft(box);
    Size lastSize = box.size;
    final endTime = DateTime.now().add(stabilityDuration);

    double posDist(Offset a, Offset b) => (a - b).distance;
    double sizeDist(Size a, Size b) =>
        math.max((a.width - b.width).abs(), (a.height - b.height).abs());

    while (DateTime.now().isBefore(endTime)) {
      await Future.delayed(checkInterval);
      box = _resolveRenderBox(label);
      if (box == null || !box.hasSize) return false;

      final curPos = _globalTopLeft(box);
      final curSize = box.size;

      if (posDist(lastPos, curPos) > tolerance ||
          sizeDist(lastSize, curSize) > tolerance) {
        AppNinja.debugLog(
            'Widget $label moved > $tolerance px, stability check failed');
        return false;
      }
    }
    return true;
  }

  /// ======== Public API Methods ========

  /// Get all tracked widget labels
  static List<String> getAllLabels() {
    return _entries.keys.toList();
  }

  /// Get all widget details with scaling (for screenshots)
  static List<Map<String, dynamic>> getAllWidgetDetails(
      num scaleX, num scaleY) {
    AppNinja.debugLog(
        'Getting all widget details with scaleX: $scaleX, scaleY: $scaleY');
    final out = <Map<String, dynamic>>[];

    _entries.forEach((label, _) {
      final box = _resolveRenderBox(label);
      if (box == null || !box.hasSize) return;

      final pos = _globalTopLeft(box);
      final size = box.size;

      // Skip widgets with NaN or Infinite position/size values
      if (pos.dx.isNaN ||
          pos.dy.isNaN ||
          pos.dx.isInfinite ||
          pos.dy.isInfinite ||
          size.width.isNaN ||
          size.height.isNaN ||
          size.width.isInfinite ||
          size.height.isInfinite) {
        AppNinja.debugLog(
            'Skipping widget $label due to invalid position/size values: pos=($pos), size=($size)');
      } else {
        out.add({
          'name': label,
          'id': label,
          'x': pos.dx * scaleX,
          'y': pos.dy * scaleY,
          'width': size.width * scaleX,
          'height': size.height * scaleY,
          'props': const {},
        });
      }
    });

    AppNinja.debugLog('Found ${out.length} widget details');
    return out;
  }

  /// Get widget details by label (simple)
  static Map<String, dynamic>? getWidgetDetails(String label) {
    final key = _entries[label]?.key;
    if (key == null) {
      // Try element-based
      final box = _resolveRenderBox(label);
      if (box != null && box.hasSize) {
        final position = _globalTopLeft(box);
        final size = box.size;

        return {
          'label': label,
          'x': position.dx,
          'y': position.dy,
          'width': size.width,
          'height': size.height,
          'visible': true,
        };
      }
      return null;
    }

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

  /// Find widget position with native-like behavior (stability checks)
  static Future<Map<String, dynamic>> nativeFindWidgetPositionByLabel({
    required String label,
    required num scaleX,
    required num scaleY,
    num? statusBarHeight,
    required Size screenSize,
  }) async {
    if (await _checkPageScrollStatus(label)) {
      AppNinja.debugLog(
          'Widget $label is currently scrolling, cannot track position');
      return {'result': false, 'message': 'Widget is currently scrolling'};
    }

    final stable = await _isWidgetStable(
      label,
      stabilityDuration: const Duration(seconds: 1),
      checkInterval: const Duration(milliseconds: 100),
    );
    if (!stable) {
      return {
        'result': false,
        'message': 'Widget position changed during tracking'
      };
    }

    final box = _resolveRenderBox(label);
    if (box == null || !box.hasSize) return {'result': false};

    final pos = _globalTopLeft(box);
    final size = box.size;

    // Check for NaN position values
    if (pos.dx.isNaN ||
        pos.dy.isNaN ||
        pos.dx.isInfinite ||
        pos.dy.isInfinite ||
        size.width.isNaN ||
        size.height.isNaN ||
        size.width.isInfinite ||
        size.height.isInfinite) {
      AppNinja.debugLog('Widget $label has NaN position values: $pos');
      return {'result': false, 'message': 'Widget position is NaN'};
    }

    if (pos.dx < 0 ||
        pos.dy < 0 ||
        pos.dx + size.width > screenSize.width ||
        pos.dy + size.height > screenSize.height ||
        size.width == 0 ||
        size.height == 0) {
      AppNinja.debugLog('Widget $label OOB: $pos, size: $size');
      return {
        'result': false,
        'message': 'Widget position is partially or completely out of bounds',
      };
    }

    return {
      'result': true,
      'x': pos.dx * scaleX,
      'y': pos.dy * scaleY + (statusBarHeight ?? 0),
      'width': size.width * scaleX,
      'height': size.height * scaleY,
    };
  }

  /// Find widget details with scale factors
  static Future<Map<String, dynamic>> findWidgetDetails({
    required String label,
    required num scaleX,
    required num scaleY,
    num? statusBarHeight,
  }) async {
    final box = _resolveRenderBox(label);
    if (box == null || !box.hasSize) return {'result': false};

    final pos = _globalTopLeft(box);
    final size = box.size;

    // Check for NaN or Infinite values
    if (pos.dx.isNaN ||
        pos.dy.isNaN ||
        pos.dx.isInfinite ||
        pos.dy.isInfinite ||
        size.width.isNaN ||
        size.height.isNaN ||
        size.width.isInfinite ||
        size.height.isInfinite) {
      AppNinja.debugLog(
          'Widget $label has invalid position/size: pos=$pos, size=$size');
      return {
        'result': false,
        'message': 'Widget position or size is invalid (NaN/Infinity)'
      };
    }

    // Out-of-bounds or zero-size check
    if (pos.dx < 0 || pos.dy < 0 || size.width == 0 || size.height == 0) {
      AppNinja.debugLog('Widget $label OOB: $pos, size: $size');
      return {
        'result': false,
        'message': 'Widget position is partially or completely out of bounds',
      };
    }

    return {
      'result': true,
      'x': pos.dx * scaleX,
      'y': pos.dy * scaleY + (statusBarHeight ?? 0),
      'width': size.width * scaleX,
      'height': size.height * scaleY,
    };
  }

  /// Find widget position returning NinjaWidgetDetails model
  static NinjaWidgetDetails? findWidgetPositionByLabel(
    String label,
    num xFactor,
    num yFactor,
  ) {
    final box = _resolveRenderBox(label);
    if (box == null || !box.hasSize) return null;

    final pos = _globalTopLeft(box);
    final size = box.size;

    return NinjaWidgetDetails(
      label: label,
      x: pos.dx,
      y: pos.dy,
      width: size.width,
      height: size.height,
      isVisible: true,
    );
  }

  /// Check if widget is visible on screen
  static bool isWidgetVisible(String label, BuildContext context) {
    final details = getWidgetDetails(label);
    if (details == null) return false;

    final screenHeight = MediaQuery.of(context).size.height;
    final y = details['y'] as double;
    final height = details['height'] as double;

    return y >= 0 && (y + height) <= screenHeight;
  }
}
