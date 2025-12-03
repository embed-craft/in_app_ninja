import 'package:flutter/material.dart';

/// NinjaTarget - Wrap widgets with this to enable tooltip anchoring
///
/// Usage:
/// ```dart
/// NinjaTarget(
///   id: 'my-button',
///   child: ElevatedButton(onPressed: () {}, child: Text('Click Me')),
/// )
/// ```
class NinjaTarget extends StatefulWidget {
  final String id;
  final Widget child;

  const NinjaTarget({
    Key? key,
    required this.id,
    required this.child,
  }) : super(key: key);

  // Registry of active LayerLinks
  static final Map<String, LayerLink> _links = {};

  /// Get LayerLink for a target ID
  static LayerLink? getLink(String id) => _links[id];

  @override
  State<NinjaTarget> createState() => _NinjaTargetState();
}

class _NinjaTargetState extends State<NinjaTarget> {
  final LayerLink _link = LayerLink();

  @override
  void initState() {
    super.initState();
    NinjaTarget._links[widget.id] = _link;
  }

  @override
  void didUpdateWidget(NinjaTarget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.id != widget.id) {
      NinjaTarget._links.remove(oldWidget.id);
      NinjaTarget._links[widget.id] = _link;
    }
  }

  @override
  void dispose() {
    NinjaTarget._links.remove(widget.id);
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
