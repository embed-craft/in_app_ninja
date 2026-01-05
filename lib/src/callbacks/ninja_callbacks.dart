import '../models/ninja_callback_data.dart';

/// NinjaCallbackListener - Interface for listening to SDK events
///
/// Implement this interface in your widget state to receive callbacks
/// from the Ninja SDK for both CORE (lifecycle) and UI (interaction) events.
///
/// Example:
/// ```dart
/// class _HomePageState extends State<HomePage>
///     with SingleTickerProviderStateMixin implements NinjaCallbackListener {
///
///   @override
///   void initState() {
///     super.initState();
///     NinjaCallbackManager.registerListener(this);
///   }
///
///   @override
///   void dispose() {
///     NinjaCallbackManager.unregisterListener(this);
///     super.dispose();
///   }
///
///   @override
///   void onEvent(NinjaCallbackData event) {
///     print("callback event: ${event}");
///     switch (event.type) {
///       case "CORE":
///         // Handle core events
///         break;
///       case "UI":
///         // Handle UI events
///         break;
///     }
///   }
/// }
/// ```
abstract class NinjaCallbackListener {
  /// Called when an SDK event occurs
  ///
  /// [event] - The callback data containing type, action, method, and data
  void onEvent(NinjaCallbackData event);
}
