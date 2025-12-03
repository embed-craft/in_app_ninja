/// InAppNinja SDK - Powerful in-app engagement and nudges for Flutter apps
///
/// Main exports:
/// - [AppNinja] - Core SDK class for initialization, tracking, and campaigns
/// - [NinjaApp] - Wrapper widget for auto-rendering campaigns (ZERO CODE INTEGRATION)
/// - [NinjaAutoObserver] - Auto screen tracking observer (ZERO CODE INTEGRATION)
/// - [NinjaWidget] - Inline widget for embedding campaigns
/// - [NinjaAppComponent] - Component-based nudge placement (nudgecore_v2 style)
/// - [NinjaStories] - Story-based nudge carousel (Instagram-style)
/// - [NinjaTrackedView] - Widget wrapper for automatic tracking
/// - [NinjaWrapper] - Scroll detection wrapper
/// - [NinjaRouteObserver] - Auto page tracking for navigation
/// - [NinjaView] - Visibility tracking wrapper
/// - [NinjaCallbackManager] - Event listener registration system
library in_app_ninja;

export 'src/app_ninja.dart';
export 'src/widgets/ninja_app.dart'; // NEW: Auto-render wrapper
export 'src/observers/ninja_auto_observer.dart'; // NEW: Auto screen tracking
export 'src/widgets/ninja_widget.dart';
export 'src/widgets/ninja_app_component.dart';
export 'src/widgets/ninja_stories.dart';
export 'src/widgets/ninja_tracked_view.dart'
    hide NinjaTrackedView, NinjaWidgetTracker, NinjaTrackX;
export 'src/widgets/ninja_tracked_view_new.dart'; // Enhanced version with all features
export 'src/widgets/ninja_wrapper.dart';
export 'src/observers/ninja_route_observer.dart';
export 'src/observers/ninja_tracker_observer.dart'; // NEW: Widget tracking observer
export 'src/widgets/ninja_view.dart';
export 'src/models/campaign.dart';
export 'src/models/nudge_config.dart';
export 'src/models/ninja_referral_lead.dart';
export 'src/models/ninja_callback_data.dart';
export 'src/models/ninja_region.dart';
export 'src/models/ninja_user.dart';
export 'src/models/ninja_widget_details.dart';
export 'src/callbacks/ninja_callback_manager.dart';
export 'src/callbacks/ninja_callbacks.dart';
export 'src/renderers/campaign_renderer.dart'; // For showing PIP and overlay campaigns
