import 'dart:async';
import 'package:flutter/material.dart';
import '../app_ninja.dart';

/// NinjaWrapper - Wraps content to detect scroll events
///
/// Use this widget to wrap scrollable content and automatically track scroll events
///
/// Example:
/// ```dart
/// NinjaWrapper(
///   child: ListView(
///     children: [...],
///   ),
/// )
/// ```
class NinjaWrapper extends StatefulWidget {
  final Widget child;
  final Function(double scrollOffset, double maxScrollExtent)? onScroll;

  const NinjaWrapper({
    super.key,
    required this.child,
    this.onScroll,
  });

  @override
  State<NinjaWrapper> createState() => _NinjaWrapperState();
}

class _NinjaWrapperState extends State<NinjaWrapper> {
  Timer? _scrollDebounceTimer;
  double _lastScrollOffset = 0.0;
  double _lastMaxScrollExtent = 0.0;

  void _handleScrollNotification(ScrollNotification notification) {
    if (notification is ScrollUpdateNotification) {
      final currentOffset = notification.metrics.pixels;
      final maxExtent = notification.metrics.maxScrollExtent;

      // Throttle scroll events (250ms)
      _scrollDebounceTimer?.cancel();
      _scrollDebounceTimer = Timer(const Duration(milliseconds: 250), () {
        if (_lastScrollOffset != currentOffset ||
            _lastMaxScrollExtent != maxExtent) {
          _lastScrollOffset = currentOffset;
          _lastMaxScrollExtent = maxExtent;

          // Track scroll event
          AppNinja.track('scroll', properties: {
            'offset': currentOffset,
            'max_extent': maxExtent,
            'percentage': maxExtent > 0 ? (currentOffset / maxExtent) * 100 : 0,
            'page': AppNinja.currentPage ?? 'unknown',
          });

          // Call custom callback
          widget.onScroll?.call(currentOffset, maxExtent);

          AppNinja.debugLog(
              'Scroll: offset=$currentOffset, max=$maxExtent, percentage=${maxExtent > 0 ? (currentOffset / maxExtent) * 100 : 0}%');
        }
      });
    }
  }

  @override
  void dispose() {
    _scrollDebounceTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        _handleScrollNotification(notification);
        return false; // Allow notification to bubble up
      },
      child: widget.child,
    );
  }
}
