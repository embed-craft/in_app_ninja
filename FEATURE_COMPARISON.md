# Feature Comparison: InAppNinja vs Plotline

## ✅ Complete Feature Parity

InAppNinja has **100% feature parity** with Plotline SDK plus additional enhancements.

## Core SDK Methods

| Feature | Plotline | AppNinja | Notes |
|---------|----------|----------|-------|
| **Initialization** | | | |
| `init(apiKey, userId, endpoint)` | ✅ | ✅ | Full compatibility |
| Init success callback | ✅ | ✅ | `registerInitCallback()` |
| Init failure callback | ✅ | ✅ | `registerInitCallback()` |
| **Event Tracking** | | | |
| `track(eventName, properties)` | ✅ | ✅ | Full compatibility |
| `identify(attributes)` | ✅ | ✅ | Full compatibility |
| `trackPage(pageName, context)` | ✅ | ✅ | Full compatibility |
| Event listener callback | ✅ | ✅ | `setEventsListener()` |
| **Configuration** | | | |
| `setLocale(locale)` | ✅ | ✅ | Full compatibility |
| `setColor(colors)` | ✅ | ✅ | Full compatibility |
| `debug(enable)` | ✅ | ✅ | Full compatibility |
| Debug logging | ✅ | ✅ | `plotlineDebugLog` → `debugLog` |
| **Feature Flags** | | | |
| `isFeatureEnabled(key)` | ✅ | ✅ | Full compatibility |
| `getFeatureFlag(key)` | ✅ | ✅ | Full compatibility |
| `getFeatureFlagPayload(key)` | ✅ | ✅ | Full compatibility |
| **SDK Controls** | | | |
| `setShouldDisablePlotline()` | ✅ | ✅ | Named `setShouldDisableNinja()` |
| `setShouldDisableBackPressedListener()` | ✅ | ✅ | Full compatibility |
| `setShouldCheckForParentWidget()` | ✅ | ✅ | Full compatibility |
| `setShouldEnableFlutterWidgetTouch()` | ✅ | ✅ | Full compatibility |

## Widget & Element Tracking

| Feature | Plotline | AppNinja | Notes |
|---------|----------|----------|-------|
| **Element Tracking** | | | |
| `getAllElements(id, pixRatio, w, h)` | ✅ | ✅ | Full compatibility |
| `areViewsPresent(id, keys, ...)` | ✅ | ✅ | Full compatibility |
| `getViewPosition(id, key, ...)` | ✅ | ✅ | Full compatibility |
| `recurseKey(context, pixRatio, w, h)` | ✅ | ✅ | Returns element tree with positions |
| `findViewByKey(key, context)` | ✅ | ✅ | Full compatibility |
| `extractKeyValue(element)` | ✅ | ✅ | Full compatibility |
| `isWithinBounds(...)` | ✅ | ✅ | Multiple overloads |
| `getTopmostContext(context)` | ✅ | ✅ | Full compatibility |
| **Visibility Tracking** | | | |
| `visibilityMap` | ✅ | ✅ | Shared map for visibility percentages |
| `PView` widget | ✅ | ✅ | Named `NinjaView` |
| **Scroll Detection** | | | |
| `PlotlineWrapper` widget | ✅ | ✅ | Named `NinjaWrapper` |
| Throttled scroll events (250ms) | ✅ | ✅ | Full compatibility |

## Stories & Content

| Feature | Plotline | AppNinja | Notes |
|---------|----------|----------|-------|
| `showMockStudy()` | ✅ | ✅ | Full compatibility |
| `showStory(storyId, slideId)` | ✅ | ✅ | Full compatibility |

## Push Notifications

| Feature | Plotline | AppNinja | Notes |
|---------|----------|----------|-------|
| `requestPushPermission()` | ✅ | ✅ | Returns Future<bool> in AppNinja |
| `setFcmToken(token)` | ✅ | ✅ | Full compatibility |
| `showNotification(remoteMessage)` | ✅ | ✅ | Full compatibility |
| Notification click listener | ✅ | ✅ | `setNotificationClickListener()` |

## User Management

| Feature | Plotline | AppNinja | Notes |
|---------|----------|----------|-------|
| `logout()` | ✅ | ✅ | Full compatibility |

## Event Listeners & Callbacks

| Feature | Plotline | AppNinja | Notes |
|---------|----------|----------|-------|
| `setPlotlineEventsListener()` | ✅ | ✅ | Named `setEventsListener()` |
| `setPlotlineRedirectListener()` | ✅ | ✅ | Named `setRedirectListener()` |
| `setPlotlineNotificationClickListener()` | ✅ | ✅ | Named `setNotificationClickListener()` |
| `registerInitCallback()` | ✅ | ✅ | Full compatibility |

## 🚀 InAppNinja Exclusive Features

| Feature | Description |
|---------|-------------|
| **Campaign Management** | |
| `fetchCampaigns({userId})` | Fetch campaigns from backend with caching |
| `onCampaigns` stream | Real-time campaign updates stream |
| **Offline Support** | |
| Event queue | Auto-queue failed events |
| `retryQueuedEvents()` | Manual retry of queued events |
| Campaign caching | SharedPreferences-based caching |
| **Widgets** | |
| `NinjaWidget` | Inline campaign embedding widget |
| `NinjaRouteObserver` | Automatic page tracking observer |
| **Additional APIs** | |
| `triggerRedirect()` | Programmatic redirect trigger |
| `dispose()` | Clean resource disposal |
| **Getters** | |
| `appContext` | Current app BuildContext |
| `currentPage` | Current page name |
| `locale` | Current locale |
| `colorTheme` | Current color theme |
| `isInitialized` | Initialization status |
| `isSdkDisabled` | SDK disable status |
| `isBackPressedListenerDisabled` | Back button listener status |
| `shouldCheckForParentWidget` | Parent widget check status |
| `isFlutterWidgetTouchEnabled` | Flutter touch status |

## Architecture Differences

| Aspect | Plotline | AppNinja |
|--------|----------|----------|
| **Platform** | Native (iOS/Android) with MethodChannel | Pure Flutter (cross-platform) |
| **Native Code** | Required | None - 100% Dart |
| **Backend Communication** | Through native SDKs | Direct HTTP with http package |
| **Widget Rendering** | AndroidView/UiKitView | Pure Flutter widgets |
| **Platform Support** | iOS, Android | iOS, Android, Web, Desktop |
| **Campaign Delivery** | Native SDK pull | HTTP REST API |
| **Offline Support** | Native queue | Dart queue with SharedPreferences |

## Summary

✅ **All Plotline features implemented**  
✅ **Pure Flutter architecture (no native code)**  
✅ **Additional campaign management features**  
✅ **Offline event queue & retry**  
✅ **Campaign caching**  
✅ **Stream-based architecture**  
✅ **Cross-platform support (beyond iOS/Android)**

InAppNinja provides **complete feature parity** with Plotline while offering a **pure Flutter implementation** and **additional features** for better developer experience.
