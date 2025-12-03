import 'package:flutter/material.dart';
import '../app_ninja.dart';

/// NinjaApp Wrapper Widget
///
/// Wrap your app's home widget with this to enable auto-rendering
/// This widget automatically provides context to the SDK for showing campaigns
///
/// Example:
/// ```dart
/// MaterialApp(
///   home: NinjaApp(
///     child: MyHomePage(),
///   ),
/// )
/// ```
class NinjaApp extends StatefulWidget {
  final Widget child;

  const NinjaApp({
    Key? key,
    required this.child,
  }) : super(key: key);

  @override
  State<NinjaApp> createState() => _NinjaAppState();
}

class _NinjaAppState extends State<NinjaApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // Set context after first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      AppNinja.setGlobalContext(context);
      print('✅ NinjaApp: Global context set for auto-rendering');
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    // Update context when dependencies change
    AppNinja.setGlobalContext(context);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // App resumed, refresh campaigns
      print('📱 App resumed, refreshing campaigns...');
      AppNinja.autoFetchCampaigns();
    }
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}
