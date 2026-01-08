import 'package:flutter/material.dart';
import '../app_ninja.dart';

/// EmbedWidgetWrapper - Explicitly tag widgets for InAppNinja targeting
/// 
/// Usage:
/// ```dart
/// EmbedWidgetWrapper(
///   id: 'my_button_id',
///   child: ElevatedButton(...)
/// )
/// ```
class EmbedWidgetWrapper extends StatefulWidget {
  final String id;
  final Widget child;

  const EmbedWidgetWrapper({
    Key? key,
    required this.id,
    required this.child,
  }) : super(key: key);

  @override
  State<EmbedWidgetWrapper> createState() => _EmbedWidgetWrapperState();
}

class _EmbedWidgetWrapperState extends State<EmbedWidgetWrapper> {
  final LayerLink _link = LayerLink();

  @override
  void initState() {
    super.initState();
    // Register this widget as a target when it mounts
    AppNinja.registerTarget(widget.id, context, link: _link);
  }

  @override
  void didUpdateWidget(covariant EmbedWidgetWrapper oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Handle ID changes
    if (widget.id != oldWidget.id) {
      AppNinja.unregisterTarget(oldWidget.id);
      AppNinja.registerTarget(widget.id, context, link: _link);
    }
  }

  @override
  void dispose() {
    // Unregister when unmounting
    AppNinja.unregisterTarget(widget.id);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CompositedTransformTarget(
      link: _link,
      child: widget.child,
    );
  }
}
