# Changelog

All notable changes to InAppNinja will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.0] - 2025-11-08

### Added
- Initial release of InAppNinja SDK
- Core functionality:
  - `AppNinja.init()` for SDK initialization
  - `AppNinja.track()` for event tracking
  - `AppNinja.identify()` for user identification
  - `AppNinja.userIdentifier()` for enhanced user identification (nudgecore_v2 style)
  - `AppNinja.fetchCampaigns()` for campaign retrieval
  - Campaign stream (`AppNinja.onCampaigns`)
  - Offline event queue with auto-retry
  - SharedPreferences caching for campaigns
- Widgets:
  - `NinjaWidget` for inline campaign embedding with dynamic sizing
  - `NinjaAppComponent` for component-based nudge placement (nudgecore_v2 inspired)
  - `NinjaStories` for Instagram-style story nudges (nudgecore_v2 inspired)
  - `NinjaTrackedView` for automatic widget tracking (nudgecore_v2 inspired)
  - `NinjaView` for visibility tracking
  - `NinjaWrapper` for scroll event detection
- Extensions:
  - `ninjaLabel()` and `ninjaWidgetLabel()` extensions for inline widget tracking
  - `NinjaTrackX` extension on Widget for tracking
- Observers:
  - `NinjaRouteObserver` for automatic page tracking
- Models:
  - `Campaign` - Campaign data model
  - `NudgeConfig` - Configuration model
  - `NinjaReferralLead` - Referral lead data
  - `NinjaCallbackData` - Structured callback events
  - `NinjaRegion` - Type-safe region enum (US, EU, IN, AU, SG, UK)
  - `NinjaUser` - Complete user data model
  - `NinjaWidgetDetails` - Widget tracking details with position/size
- Callbacks:
  - `NinjaCallbackManager` - Centralized event dispatcher (nudgecore_v2 inspired)
  - `NinjaCallbackListener` - Listener interface
  - Typed callbacks: `NinjaStoriesCallback`, `NinjaQuizCallback`, `NinjaSurveyCallback`, `NinjaGamificationCallback`, `NinjaModalsCallback`, `NinjaLeaderboardCallback`, etc.
  - Deep link handling - Automatic URL launching from CTAs
  - Internal error handling with SDK auto-disable
- Tracking & Analytics:
  - `NinjaWidgetTracker` for managing widget registrations
  - Element tracking system:
    - `getAllElements()` for widget tree traversal
    - `areViewsPresent()` to check element existence
    - `getViewPosition()` for element position tracking
    - `recurseKey()` and `findViewByKey()` for element lookup
    - `isWithinBounds()` for boundary checking
    - `getTopmostContext()` for context utilities
    - `extractKeyValue()` for key extraction
- SDK configuration:
  - `config()` to configure navigator and screenshot keys (nudgecore_v2 inspired)
  - `screenshotKey` getter - Access to screenshot key (nudgecore_v2 compatibility)
  - `setShouldDisableNinja()` to enable/disable SDK
  - `setShouldDisableBackPressedListener()` for back button control
  - `setShouldCheckForParentWidget()` for parent widget checking
  - `setShouldEnableFlutterWidgetTouch()` for touch event handling
  - `setRegion()` for multi-region support (string-based, backward compatible)
  - `setNinjaRegion()` for multi-region support (enum-based, type-safe)
  - `ninjaRegion` getter - Get current region as enum
- Story features:
  - `showStory()` to display specific stories
  - `showMockStudy()` for testing nudges
- Session management:
  - `startSession()` and `endSession()` for session tracking
  - `sessionId` property and getter
- User management:
  - `getUserDetails()` to retrieve current user information
  - `userSignOut()` for user logout
  - `externalId` support and getter
  - User properties tracking
  - `currentUser` getter - Access to NinjaUser object
- Referral system:
  - `NinjaReferralLead` model for referral leads
  - `addLeads()` to submit referral leads
- Push notification support:
  - `requestPushPermission()` for permission handling
  - `setFcmToken()` for FCM integration
  - `showNotification()` for notification display
- Event listeners:
  - `setEventsListener()` to track all events
  - `setRedirectListener()` for redirect handling
  - `setNotificationClickListener()` for notification clicks
  - `registerInitCallback()` for init success/failure handling
  - `registerRefreshToken()` for token refresh callbacks (nudgecore_v2 inspired)
  - `registerAuth()` for auth key callbacks (nudgecore_v2 inspired)
- Campaign management:
  - `clearNudges()` to remove all active nudges
  - `retryQueuedEvents()` to manually retry failed events
- Feature flags support:
  - `isFeatureEnabled()` to check feature status
  - `getFeatureFlag()` to get feature flag values
  - `getFeatureFlagPayload()` to get feature flag payloads
- Custom color themes:
  - `setColor()` to configure color schemes
  - `colorTheme` getter
- Locale support:
  - `setLocale()` to set user locale
  - `locale` getter
- Debug mode:
  - `debug()` to enable/disable debug logging
  - `debugLog()` for internal logging
- Getters for state inspection:
  - `isInitialized` - Check SDK initialization status
  - `isSdkDisabled` - Check if SDK is disabled
  - `isBackPressedListenerDisabled` - Check back button listener status
  - `shouldCheckForParentWidget` - Check parent widget flag
  - `isFlutterWidgetTouchEnabled` - Check Flutter touch flag
  - `appContext` - Get current app context
  - `currentPage` - Get current page name
  - `navigatorKey` - Access to navigator key
  - `visibilityMap` - Widget visibility tracking
- Helper methods:
  - `setContext()` - Set current context
  - `triggerRedirect()` - Trigger redirect events
  - `triggerRefreshToken()` - Trigger token refresh
  - `triggerAuth()` - Trigger auth callback
  - `dispose()` - Clean up resources
- Comprehensive README and documentation
- Feature comparison with plotline_engage and nudgecore_v2
- Missing features analysis documentation
- Example app demonstrating all features

### Technical Details
- Pure Flutter implementation (100% Dart, cross-platform)
- No native code dependencies
- Works on iOS, Android, Web, and Desktop
- HTTP-based API communication
- Local caching with SharedPreferences
- Offline event queue with automatic retry
- Stream-based campaign updates
- Visibility detection using VisibilityDetector
- Widget tree traversal for element tracking
- Type-safe region support with enum
- Structured models for all data types

### Features Roadmap (v1.1+)
- [ ] Bottom sheet nudge renderer
- [ ] Modal dialog nudge renderer
- [ ] Picture-in-picture floating widget
- [ ] Scratch card interactive widget
- [ ] Banner nudge renderer
- [ ] Tooltip nudge renderer
- [ ] Story carousel renderer
- [ ] A/B testing support
- [ ] Local targeting rule evaluation
- [ ] Analytics dashboard integration
- [ ] Push notification integration

## [Unreleased]

Features planned for future releases will be listed here.
