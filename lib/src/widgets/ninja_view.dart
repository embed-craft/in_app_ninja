import 'package:flutter/material.dart';
import 'package:visibility_detector/visibility_detector.dart';
import '../app_ninja.dart';

/// NinjaView - Visibility tracking wrapper for widgets
/// 
/// Wraps any widget to track its visibility. Used for targeting and analytics.
/// 
/// Example:
/// ```dart
/// NinjaView(
///   valueKey: 'signup_button',
///   child: ElevatedButton(
///     onPressed: () {},
///     child: Text('Sign Up'),
///   ),
/// )
/// ```
class NinjaView extends StatelessWidget {
  final Widget child;
  final String valueKey;
  final bool isWidget;

  const NinjaView({
    Key? key,
    required this.child,
    required this.valueKey,
    this.isWidget = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return VisibilityDetector(
      key: ValueKey(valueKey),
      onVisibilityChanged: (visibilityInfo) {
        final visiblePercentage = visibilityInfo.visibleFraction * 100;
        final referKey = _extractKeyValue(ValueKey(valueKey));
        AppNinja.debugLog('NinjaView visibility changed for $valueKey $referKey: $visiblePercentage');
        if (referKey != null) {
          AppNinja.visibilityMap[referKey] = visiblePercentage;
        }
      },
      child: child,
    );
  }

  static String? _extractKeyValue(Key? key) {
    if (key is ValueKey) {
      return "[<'${key.value.toString()}'>]";
    } else if (key != null) {
      return key.toString();
    }
    return null;
  }
}
