# Missing Features Analysis - InAppNinja vs Reference SDKs

## Plotline Engage 5.0.3 - Method-by-Method Comparison

### ✅ IMPLEMENTED in InAppNinja:
1. `init()` - SDK initialization
2. `track()` - Event tracking
3. `identify()` - User identification
4. `setLocale()` - Locale setting
5. `setColor()` - Color theme
6. `debug()` - Debug mode
7. `isFeatureEnabled()` - Feature flags
8. `getFeatureFlag()` - Feature flag values
9. `getFeatureFlagPayload()` - Feature flag payload
10. `setShouldEnableFlutterWidgetTouch()` - Flutter touch handling
11. `isWithinBounds()` - Boundary checking
12. `extractKeyValue()` - Key extraction
13. `recurseKey()` - Widget tree traversal
14. `findViewByKey()` - Find widget by key
15. `showMockStudy()` - Mock study
16. `getTopmostContext()` - Context navigation
17. `trackPage()` - Page tracking
18. `showStory()` - Story display
19. `setShouldDisablePlotline()` → `setShouldDisableNinja()`
20. `setShouldDisableBackPressedListener()` - Back button
21. `getAllElements()` - Element positions
22. `areViewsPresent()` - Element checking
23. `getViewPosition()` - Element position
24. `logout()` - User logout
25. `setPlotlineEventsListener()` → `setEventsListener()`
26. `setPlotlineNotificationClickListener()` → `setNotificationClickListener()`
27. `setPlotlineRedirectListener()` → `setRedirectListener()`
28. `registerInitCallback()` - Init callbacks
29. `plotlineDebugLog()` → `debugLog()`
30. `requestPushPermission()` - Push permissions
31. `setFcmToken()` - FCM token
32. `showNotification()` - Notification display
33. `setShouldCheckForParentWidget()` - Parent widget check

### ❌ MISSING in InAppNinja:

**NONE - ALL PLOTLINE FEATURES IMPLEMENTED!** ✅

---

## Nudgecore V2 6.1.2 - Method-by-Method Comparison

### ✅ IMPLEMENTED in InAppNinja:
1. `Nudge()` factory → `AppNinja.init()`
2. `getInstance()` - Not needed (static class)
3. `setContext()` - Context management
4. `track()` - Event tracking
5. `userIdentifier()` - Enhanced user ID
6. `userSignOut()` - Sign out
7. `clearNudges()` - Clear campaigns
8. `getUserDetails()` - User info
9. `registerRefreshToken()` - Token refresh
10. `registerAuth()` - Auth callback
11. `addLeads()` - Referral leads
12. `config()` - Navigator/screenshot keys

### ❌ MISSING in InAppNinja:

1. **`disableNudge(bool value)`** - Instance method to disable/enable SDK
   - InAppNinja has `setShouldDisableNinja()` but it's different
   
2. **Region enum** - Type-safe region constants
   - InAppNinja uses string, nudgecore uses enum
   
3. **`nudgeNavigatorKey` getter** - Static access to navigator key
   - InAppNinja has `navigatorKey` getter ✅
   
4. **`screenshotKey` getter** - Static access to screenshot key
   - **MISSING** ❌
   
5. **`currentContext` getter** - Static access to current context
   - InAppNinja has `appContext` getter ✅

---

## Widget & Model Comparison

### Plotline Widgets:
- ✅ `PlotlineWidget` → `NinjaWidget` (implemented)
- ✅ `PlotlineWrapper` → `NinjaWrapper` (implemented)
- ✅ `PView` → `NinjaView` (implemented)
- ✅ `PlotlineNavigationObserver` → `NinjaRouteObserver` (implemented)

### Nudgecore Widgets:
- ✅ `NudgeAppComponent` → `NinjaAppComponent` (implemented)
- ✅ `NudgeStories` → `NinjaStories` (implemented)
- ✅ `NudgeTrackedView` → `NinjaTrackedView` (implemented)
- ❌ `NudgeProvider` - **MISSING** (deprecated but exists)

### Models:
- ✅ `NudgeReferralLead` → `NinjaReferralLead` (implemented)
- ✅ `NudgeCallbackData` → `NinjaCallbackData` (implemented)
- ❌ `User` model - **MISSING**
- ❌ `WidgetDetails` model - **MISSING**

---

## Callback System Comparison

### Plotline Callbacks:
- ✅ All event listeners implemented

### Nudgecore Callbacks:
- ✅ `NudgeCallbackManager` → `NinjaCallbackManager` (implemented)
- ✅ `NudgeCallbackListener` → `NinjaCallbackListener` (implemented)
- ✅ All callback types (Stories, Quiz, Survey, etc.) - implemented

---

## Summary of ACTUAL Missing Features

### Critical Missing:
1. **`screenshotKey` static getter** - Need to expose screenshot key
2. **Region enum** - Should use enum instead of string
3. **User model** - Structured user data model
4. **WidgetDetails model** - Widget tracking details

### Nice to Have:
1. **NudgeProvider widget** - Deprecated but could add for compatibility
2. **More granular error handling** - nudgecore has detailed error callbacks

---

## Action Items

1. Add `screenshotKey` getter to AppNinja ✅
2. Create Region enum 
3. Create User model
4. Create WidgetDetails model
5. Update region handling to use enum
6. Update CHANGELOG with all features
