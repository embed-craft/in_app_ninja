# InAppNinja SDK

[![pub package](https://img.shields.io/pub/v/in_app_ninja.svg)](https://pub.dev/packages/in_app_ninja)

A powerful Flutter SDK for in-app nudges, campaigns, and user engagement. Build engaging experiences with bottom sheets, modals, floating widgets, scratch cards, stories, banners, and more — all powered by your backend.

## Features

✨ **Rich Nudge Types**
- 📱 Bottom Sheets
- 🎯 Modal Dialogs
- 🎈 Picture-in-Picture (floating widgets)
- 🎫 Scratch Cards
- 📣 Banners (top/bottom)
- 💡 Tooltips
- 📖 Stories (Instagram-style)
- 📌 Inline Widgets

🚀 **Core SDK Features**
- Event tracking (`track`)
- User identification (`identify`, `userIdentifier`)
- Campaign fetching with caching
- Offline event queue with auto-retry
- Auto page tracking with `NinjaRouteObserver`
- Visibility detection for targeting
- Element position tracking
- Scroll event tracking with `NinjaWrapper`
- Feature flags support
- Push notification support (FCM integration)
- Story display
- Session management
- Region support (US, EU, IN, etc.)
- Referral leads tracking
- Auth & refresh token callbacks
- Debug mode
- SDK configuration (disable, back button handling, touch events)

🎨 **Customization**
- Custom color themes
- Locale support
- Custom widget builders
- Event listeners

## Installation

Add to your `pubspec.yaml`:

```yaml
dependencies:
  in_app_ninja: ^1.0.0
```

Then run:
```bash
flutter pub get
```

## Quick Start

### 1. Initialize the SDK

```dart
import 'package:in_app_ninja/in_app_ninja.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize AppNinja
  await AppNinja.init(
    'your_api_key',
    baseUrl: 'https://your-server.com',  // optional
  );
  
  runApp(MyApp());
}
```

### 2. Track Events

```dart
// Track custom events
AppNinja.track('button_clicked', properties: {
  'button_name': 'signup',
  'screen': 'home',
});

// Identify users
AppNinja.identify({
  'user_id': 'user_123',
  'email': 'user@example.com',
  'plan': 'premium',
});
```

### 3. Auto Page Tracking

Add `NinjaRouteObserver` to your app:

```dart
MaterialApp(
  navigatorObservers: [NinjaRouteObserver()],
  // ...
)
```

### 4. Embed Inline Campaigns

```dart
// Place NinjaWidget anywhere in your UI
NinjaWidget(
  valueKey: 'home_banner',
  defaultMargin: 16.0,
)
```

### 5. Fetch and Display Campaigns

```dart
// Fetch campaigns manually
final campaigns = await AppNinja.fetchCampaigns();

// Or listen to campaign updates
AppNinja.onCampaigns.listen((campaigns) {
  // Handle campaign display
});
```

### 6. Track Element Visibility

Wrap widgets with `NinjaView` for visibility-based targeting:

```dart
NinjaView(
  valueKey: 'signup_button',
  child: ElevatedButton(
    onPressed: () {},
    child: Text('Sign Up'),
  ),
)
```

### 7. Detect Scroll Events

Wrap scrollable content with `NinjaWrapper`:

```dart
NinjaWrapper(
  child: ListView(
    children: [
      // Your list items
    ],
  ),
)
```

## Advanced Usage

### Element Position Tracking

```dart
// Get all visible elements with positions
final pixelRatio = MediaQuery.of(context).devicePixelRatio;
final screenWidth = MediaQuery.of(context).size.width;
final screenHeight = MediaQuery.of(context).size.height;

final elements = AppNinja.getAllElements(
  'listener_id',
  pixelRatio,
  screenWidth,
  screenHeight,
);

// Check if specific views are present
final isPresent = AppNinja.areViewsPresent(['button_1', 'banner_top']);

// Get position of a specific view
final position = AppNinja.getViewPosition('signup_button');
```

### Push Notifications (FCM)

```dart
// Request push permission
final granted = await AppNinja.requestPushPermission();

// Set FCM token
AppNinja.setFcmToken(fcmToken);

// Handle notification display
AppNinja.showNotification(remoteMessage);
```

### Story Display

```dart
// Show a specific story
AppNinja.showStory('story_id_123', 'slide_id_1');

// Show mock study for testing
AppNinja.showMockStudy();
```

### SDK Configuration

```dart
// Disable SDK completely
AppNinja.setShouldDisableNinja(true);

// Disable back button listener
AppNinja.setShouldDisableBackPressedListener(true);

// Enable Flutter widget touch events
AppNinja.setShouldEnableFlutterWidgetTouch(true);

// Control parent widget checking
AppNinja.setShouldCheckForParentWidget(false);
```

### Custom Color Theme

```dart
await AppNinja.setColor({
  'background': '#ffffff',
  'title': '#000000',
  'description': '#666666',
  'buttonBackground': '#007AFF',
  'buttonText': '#ffffff',
});
```

### Event Listeners

```dart
// Track all events
AppNinja.setEventsListener((eventName, properties) {
  print('Event tracked: $eventName with $properties');
});

// Handle redirects
AppNinja.setRedirectListener((properties) {
  print('Redirect: $properties');
});

// Handle notification clicks
AppNinja.setNotificationClickListener((properties) {
  print('Notification clicked: $properties');
});

// Handle init callbacks
AppNinja.registerInitCallback(
  () => print('SDK initialized successfully'),
  (error) => print('SDK init failed: $error'),
);
```

### Feature Flags

```dart
// Check if feature is enabled
final isEnabled = await AppNinja.isFeatureEnabled('new_checkout');

// Get feature flag value
final flagValue = await AppNinja.getFeatureFlag('discount_percentage');
```

### Debug Mode

```dart
AppNinja.debug(true);  // Enable debug logging
```

## API Reference

### AppNinja

Main SDK class. All methods are static.

#### Initialization
- `init(String apiKey, {String userId, String baseUrl})` - Initialize SDK

#### Tracking
- `track(String eventName, {Map<String, dynamic> properties})` - Track event
- `identify(Map<String, dynamic> attributes)` - Identify user
- `trackPage(String pageName, BuildContext context)` - Track page view

#### Campaigns
- `fetchCampaigns({String? userId})` - Fetch campaigns from server
- `onCampaigns` (Stream) - Listen for campaign updates

#### Configuration
- `setLocale(String locale)` - Set user locale
- `setColor(Map<String, String> colors)` - Set color theme
- `debug(bool enable)` - Enable/disable debug mode
- `setShouldDisableNinja(bool disable)` - Enable/disable SDK
- `setShouldDisableBackPressedListener(bool disable)` - Control back button handling
- `setShouldCheckForParentWidget(bool enable)` - Control parent widget checking
- `setShouldEnableFlutterWidgetTouch(bool enable)` - Enable Flutter widget touch

#### Element Tracking
- `getAllElements(String listenerId, double pixRatio, double screenWidth, double screenHeight)` - Get all visible elements with positions
- `areViewsPresent(List<String> keys)` - Check if views with given keys are present
- `getViewPosition(String key)` - Get position of a view by key
- `recurseKey(BuildContext context, String keyValue)` - Find element by key recursively
- `findViewByKey(BuildContext context, String keyValue)` - Find view by key value
- `extractKeyValue(Element element)` - Extract key value from element
- `isWithinBounds(double x, double y, double left, double top, double right, double bottom)` - Check if point is within bounds
- `getTopmostContext(BuildContext context)` - Get topmost context in widget tree

#### Stories & Notifications
- `showStory(String storyId, String slideId)` - Show a specific story
- `showMockStudy()` - Show mock study for testing
- `requestPushPermission()` - Request push notification permission
- `setFcmToken(String token)` - Set FCM token for push notifications
- `showNotification(Map<String, dynamic> remoteMessage)` - Show notification

#### Callbacks
- `setEventsListener(Function callback)` - Listen to all tracked events
- `setRedirectListener(Function callback)` - Listen to redirect events
- `setNotificationClickListener(Function callback)` - Listen to notification clicks
- `registerInitCallback(Function onSuccess, Function onFailure)` - Register init callbacks

#### Feature Flags
- `isFeatureEnabled(String featureKey)` - Check if feature is enabled
- `getFeatureFlag(String featureKey)` - Get feature flag value
- `getFeatureFlagPayload(String featureKey)` - Get feature flag payload

#### User Management
- `logout()` - Clear user session

### Widgets

#### NinjaWidget
Inline widget for embedding campaigns.

```dart
NinjaWidget(
  valueKey: 'banner_1',
  defaultMargin: 16.0,
  customBuilder: (campaign) => YourCustomWidget(campaign),
)
```

#### NinjaView
Visibility tracking wrapper.

```dart
NinjaView(
  valueKey: 'element_id',
  child: YourWidget(),
)
```

### Observers

#### NinjaRouteObserver
Auto page tracking for navigation.

```dart
MaterialApp(
  navigatorObservers: [NinjaRouteObserver()],
)
```

## Server Integration

InAppNinja expects your backend to provide:

### API Endpoints

**POST /v1/identify**
```json
{
  "user_id": "user_123",
  "traits": {"email": "user@example.com"},
  "timestamp": "2025-11-08T12:00:00Z"
}
```

**POST /v1/track**
```json
{
  "event_id": "evt_123",
  "user_id": "user_123",
  "event": "button_clicked",
  "properties": {"button_name": "signup"},
  "timestamp": "2025-11-08T12:00:00Z"
}
```

**GET /v1/campaigns?user_id=user_123**

Response:
```json
{
  "campaigns": [
    {
      "id": "camp_1",
      "title": "Welcome Offer",
      "description": "Get 20% off",
      "type": "modal",
      "config": {
        "image": "https://...",
        "button": "Claim Now"
      }
    }
  ]
}
```

## Example

See the [example](example/) directory for a complete sample app.

## Contributing

Contributions are welcome! Please read our [contributing guide](CONTRIBUTING.md).

## License

MIT License - see [LICENSE](LICENSE) file.

## Support

- 📧 Email: support@yourcompany.com
- 🐛 Issues: [GitHub Issues](https://github.com/yourusername/in_app_ninja/issues)
- 📖 Docs: [Documentation](https://github.com/yourusername/in_app_ninja#readme)
#   i n _ a p p _ n i n j a  
 