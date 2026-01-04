import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'models/campaign.dart';
import 'models/ninja_region.dart';
import 'models/ninja_user.dart';
import 'renderers/campaign_renderer.dart';
import 'widgets/embed_widget_wrapper.dart'; // Import for type checking
import 'data/ninja_campaign_repository.dart';

/// AppNinja - Main SDK class for InAppNinja
///
/// Initialize once in your app with [init], then use [track], [identify], [fetchCampaigns]
///
/// Example:
/// ```dart
/// await AppNinja.init('your_api_key', baseUrl: 'https://your-server.com');
/// AppNinja.identify({'user_id': '123', 'email': 'user@example.com'});
/// AppNinja.track('button_clicked', properties: {'button_name': 'signup'});
/// ```
class AppNinja {
  static const String _prefsKeyUserId = 'ninja_user_id';
  static const String _prefsKeyCampaigns = 'ninja_campaigns_cache';
  static const String _prefsKeyQueue = 'ninja_event_queue';
  static const String _prefsKeyColors = 'ninja_colors';

  static String? _apiKey;
  // Default to Production URL (Render)
  static String _baseUrl = 'https://embed-backend-w9j0.onrender.com';
  static String get baseUrl => _baseUrl;
  static bool _initialized = false;
  static bool _debugMode = false;
  static String? _currentPage;
  static BuildContext? _appContext;
  static String _locale = 'en';
  static Map<String, String> _colorTheme = {};
  static NinjaRegion? _ninjaRegion; // Region enum support
  static String?
      _region; // Region support (US, EU, IN, etc.) - kept for backward compatibility
  static GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
  static GlobalKey? _screenshotKey; // Screenshot key
  static String? _externalId; // External user ID
  static String? _sessionId; // Session ID
  static Map<String, dynamic> _userProperties = {}; // User properties
  static NinjaUser? _currentUser; // Current user object

  static SharedPreferences? _prefs;

  // Auto-render settings
  static bool _autoRenderEnabled = false;
  static BuildContext? _globalContext;
  static StreamSubscription? _autoRenderSubscription;
  static String? _lastShownPipId; // Track last shown PIP to prevent duplicates
  static Set<String> _shownCampaignsThisSession =
      {}; // Track all shown campaigns in session
  static DateTime? _lastCampaignShownTime; // Track when last campaign was shown

  // Callbacks
  static Function(String eventName, Map<String, dynamic> properties)?
      _eventListener;
  static Function(Map<String, dynamic> properties)? _redirectListener;
  static Function(Map<String, dynamic> properties)? _notificationClickListener;
  static Function()? _initSuccessCallback;
  static Function(String error)? _initFailureCallback;
  static Function()? _refreshTokenCallback; // Token refresh callback
  static Function(String? key)? _authCallback; // Auth callback

  // Campaign stream
  static final StreamController<List<Campaign>> _campaignController =
      StreamController<List<Campaign>>.broadcast();

  /// Stream that emits whenever campaigns are fetched or updated
  static Stream<List<Campaign>> get onCampaigns => _campaignController.stream;

  /// Visibility tracking map for NinjaView widgets
  static Map<String, double> visibilityMap = {};

  // Configuration flags
  static bool _shouldDisableSdk = false;
  static bool _shouldDisableBackPressedListener = false;
  static bool _shouldCheckForParentWidget = true;
  static bool _shouldEnableFlutterWidgetTouch = false;

  // Element tracking
  static Map<String, Map<String, dynamic>> _elementPositions = {};
  
  // Navigation key for global context access
  static GlobalKey<NavigatorState>? _navigatorKey;

  /// Initialize the SDK
  ///
  /// [apiKey] - Your InAppNinja API key
  /// [userId] - Optional initial user ID
  /// [baseUrl] - Optional custom server URL
  /// [autoRender] - Enable automatic campaign rendering (default: false)
  /// [navigatorKey] - Required for auto-rendering modals/sheets without context
  static Future<void> init(String apiKey,
      {String userId = '',
      String? baseUrl,
      bool autoRender = false,
      GlobalKey<NavigatorState>? navigatorKey}) async {
    if (_initialized) {
      debugLog('AppNinja already initialized');
      return;
    }

    try {
      _apiKey = apiKey;
      if (navigatorKey != null) {
        AppNinja.navigatorKey = navigatorKey;
      }
      _navigatorKey = navigatorKey;
      
      // Override default URL only if a specific one is provided
      if (baseUrl != null && baseUrl.isNotEmpty) {
        _baseUrl = baseUrl;
      }

      _autoRenderEnabled = autoRender;

      _prefs = await SharedPreferences.getInstance();

      if (userId.isNotEmpty) {
        await _prefs?.setString(_prefsKeyUserId, userId);
      }

      _initialized = true;
      debugLog(
          'AppNinja initialized with baseUrl: $_baseUrl, autoRender: $autoRender, navigatorKey: ${_navigatorKey != null}');

      // Load cached campaigns via Repository & Listen for updates
      NinjaCampaignRepository().campaignsStream.listen((list) {
         _campaignController.add(list);
      });
      await NinjaCampaignRepository().loadFromCache();
      
      // Legacy cache loader removed
      // await _loadCachedCampaigns();

      // Flush queued events
      unawaited(_flushEventQueue());

      // Setup auto-rendering if enabled
      if (_autoRenderEnabled) {
        _setupAutoRendering();
      }

      // Initialize Capture Manager (Dev Tools)
      // We need context for this, which we might not have yet in init.
      // CaptureManager needs to listen to links.
      // Ideally this is called when UI is ready.
      // But we can start listening.
      // Wait, CaptureManager.init requires Context to show dialogs.
      // We can defer this until we have context via setContext or NinjaApp.
      
      _initSuccessCallback?.call();
    } catch (e) {
      debugPrint('Error in AppNinja.init: $e');
      _initFailureCallback?.call(e.toString());
    }
  }

  // TARGET REGISTRY (For Tooltips)
  static final Map<String, BuildContext> _targetRegistry = {};

  /// Register a widget target for finding tooltips
  static void registerTarget(String id, BuildContext context) {
    _targetRegistry[id] = context;
    debugLog('📍 Registered Target: $id');
  }

  /// Unregister a widget target
  static void unregisterTarget(String id) {
    if (_targetRegistry.containsKey(id)) {
      _targetRegistry.remove(id);
      debugLog('🗑️ Unregistered Target: $id');
    }
  }

  /// Get context for a target ID
  static BuildContext? getTargetContext(String id) {
    return _targetRegistry[id];
  }

  /// Track an event
  ///
  /// [eventName] - Name of the event (e.g., 'button_clicked')
  /// [properties] - Optional event properties
  static Future<void> track(String eventName,
      {Map<String, dynamic> properties = const {}}) async {
    _ensureInitialized();

    final userId = _prefs?.getString(_prefsKeyUserId) ?? 'anonymous';
    final event = {
      'event_id':
          '${userId}_${eventName}_${DateTime.now().millisecondsSinceEpoch}',
      'timestamp': DateTime.now().toIso8601String(),
      'userId': userId, // Changed to camelCase
      'action': eventName, // Changed to action (preferred by backend)
      'metadata': properties, // Changed to metadata
      'sdk_version': 'in_app_ninja_flutter_1.0.0',
      'page': _currentPage,
    };

    try {
      debugLog('📤 Sending track event: $eventName');
      final response = await _post('/api/v1/nudge/track', event); // Updated Endpoint

      // ⭐ REAL-TIME INTEGRATION: Process matched campaigns from track response
      if (response.statusCode == 200) {
        debugLog('✅ Track success: $eventName (200 OK)');
        try {
          final body = jsonDecode(response.body);

          // Backend returns {ok: true, matched: [...], event: {...}}
          if (body['matched'] != null && body['matched'] is List) {
            final matchedData = body['matched'] as List;

            if (matchedData.isNotEmpty) {
              debugLog(
                  '🎯 Event "$eventName" matched ${matchedData.length} campaign(s)');

              // Convert to Campaign objects
              final campaigns = matchedData
                  .map((c) => Campaign.fromJson(c as Map<String, dynamic>))
                  .toList();

              // Emit immediately to auto-render system
              _campaignController.add(campaigns);
              debugLog('✅ Real-time campaigns emitted for auto-render');
            } else {
              debugLog('ℹ️ Event "$eventName" matched 0 campaigns');
            }
          }
        } catch (parseError) {
          debugLog('⚠️ Failed to parse matched campaigns: $parseError');
          // Don't throw - event was still tracked successfully
        }
      }

      _eventListener?.call(eventName, properties);
    } catch (e) {
      debugLog('❌ Track failed, queuing: $e');
      await _queueEvent({'type': 'track', 'payload': event});
    }
  }

  /// Identify a user with attributes
  ///
  /// [attributes] - User attributes (must include 'user_id' or will use existing)
  static Future<void> identify(Map<String, dynamic> attributes) async {
    _ensureInitialized();

    final userId = attributes['user_id']?.toString() ??
        attributes['userId']?.toString() ??
        _prefs?.getString(_prefsKeyUserId);

    if (userId != null) {
      await _prefs?.setString(_prefsKeyUserId, userId);
    }

    final payload = {
      'userId': userId ?? 'anonymous', // CamelCase
      'traits': attributes,
      'timestamp': DateTime.now().toIso8601String(),
    };

    try {
      await _post('/api/v1/nudge/identify', payload); // Updated Endpoint
    } catch (e) {
      debugLog('Identify failed, queuing: $e');
      await _queueEvent({'type': 'identify', 'payload': payload});
    }
  }

  /// Fetch campaigns from server
  ///
  /// Returns list of campaigns targeted to the current user
  /// Fetch campaigns from server with retry logic
  ///
  /// Returns list of campaigns targeted to the current user
  static Future<List<Campaign>> fetchCampaigns(
      {String? userId, bool forceRefresh = false}) async {
    _ensureInitialized();
    final uid = userId ?? _prefs?.getString(_prefsKeyUserId) ?? 'anonymous';
    final screen = _currentPage ?? 'all';

    return await NinjaCampaignRepository().fetchAndSync(
      baseUrl: _baseUrl,
      userId: uid,
      screenName: screen,
      headers: await _getHeaders(),
    );
  }

  /// Clear all cached campaigns and force fresh fetch on next request
  /// Useful during development when testing campaign changes
  static Future<void> clearCampaignCache() async {
    _ensureInitialized();
    await _prefs?.remove(_prefsKeyCampaigns);
    debugLog('🗑️ Campaign cache cleared');
  }

  /// Track page view
  ///
  /// [pageName] - Name of the page/screen
  /// [context] - BuildContext for tracking (will be stored for widget detection)
  static void trackPage(String pageName, BuildContext context) {
    _ensureInitialized();
    _currentPage = pageName;
    _appContext = context;
    debugLog('trackPage: $pageName');
    track('page_view', properties: {'page': pageName});
  }

  /// Set user locale
  static void setLocale(String locale) {
    _ensureInitialized();
    _locale = locale;
    debugLog('Locale set to: $locale');
  }

  /// Set color theme for nudges
  ///
  /// [colors] - Map of color keys to hex values (e.g., {'background': '#ffffff'})
  static Future<void> setColor(Map<String, String> colors) async {
    _ensureInitialized();
    _colorTheme = colors;
    await _prefs?.setString(_prefsKeyColors, jsonEncode(colors));
    debugLog('Color theme updated');
  }

  /// Enable or disable debug mode
  static void debug(bool enable) {
    _debugMode = enable;
    debugLog('Debug mode: $enable');
  }

  /// Show mock study (for testing nudges)
  static void showMockStudy() {
    debugLog(
        'showMockStudy called (pure Flutter implementation - use fetchCampaigns)');
    // In pure Flutter, this triggers a campaign fetch
    fetchCampaigns();
  }

  /// Check if a feature is enabled
  static Future<bool> isFeatureEnabled(String featureKey) async {
    _ensureInitialized();
    try {
      final response = await http
          .get(
            Uri.parse('$_baseUrl/v1/features/$featureKey'),
            headers: await _getHeaders(),
          )
          .timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        return body['enabled'] == true;
      }
    } catch (e) {
      debugLog('isFeatureEnabled error: $e');
    }
    return false;
  }

  /// Get feature flag value
  static Future<String?> getFeatureFlag(String featureKey) async {
    _ensureInitialized();
    try {
      final response = await http
          .get(
            Uri.parse('$_baseUrl/v1/features/$featureKey/value'),
            headers: await _getHeaders(),
          )
          .timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        return body['value']?.toString();
      }
    } catch (e) {
      debugLog('getFeatureFlag error: $e');
    }
    return null;
  }

  /// Get feature flag payload
  static Future<String?> getFeatureFlagPayload(String featureKey) async {
    _ensureInitialized();
    try {
      final response = await http
          .get(
            Uri.parse('$_baseUrl/v1/features/$featureKey/payload'),
            headers: await _getHeaders(),
          )
          .timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        return response.body;
      }
    } catch (e) {
      debugLog('getFeatureFlagPayload error: $e');
    }
    return null;
  }

  /// Logout current user
  static Future<void> logout() async {
    _ensureInitialized();
    await _prefs?.remove(_prefsKeyUserId);
    await _prefs?.remove(_prefsKeyCampaigns);
    debugLog('User logged out');
  }

  /// Set event listener
  static void setEventsListener(
      Function(String eventName, Map<String, dynamic> properties) callback) {
    _eventListener = callback;
  }

  /// Set redirect listener
  static void setRedirectListener(
      Function(Map<String, dynamic> properties) callback) {
    _redirectListener = callback;
  }

  /// Set notification click listener
  static void setNotificationClickListener(
      Function(Map<String, dynamic> properties) callback) {
    _notificationClickListener = callback;
  }

  /// Register init callbacks
  static void registerInitCallback(
      Function() onSuccess, Function(String error) onFailure) {
    _initSuccessCallback = onSuccess;
    _initFailureCallback = onFailure;
  }

  /// Show a specific story
  static void showStory(String storyId, String slideId) {
    debugLog('showStory: $storyId, slide: $slideId');
    // Pure Flutter implementation - trigger campaign fetch and filter
    fetchCampaigns().then((campaigns) {
      final story = campaigns
          .where((c) => c.id == storyId && c.type == 'story')
          .firstOrNull;
      if (story != null) {
        _campaignController.add([story]);
      }
    });
  }

  /// Retry queued events
  static Future<void> retryQueuedEvents() async {
    _ensureInitialized();
    await _flushEventQueue();
  }

  // ========== NUDGECORE_V2 INSPIRED FEATURES ==========

  /// Configure SDK with navigator key and optional screenshot key
  ///
  /// Similar to nudgecore_v2's config() method
  static Future<void> config({
    required GlobalKey<NavigatorState> navigatorKey,
    GlobalKey? screenshotKey,
  }) async {
    navigatorKey = navigatorKey;
    _screenshotKey = screenshotKey;
    debugLog('SDK configured with navigator key and screenshot key');
  }

  /// Identify user with enhanced attributes (nudgecore_v2 style)
  ///
  /// Similar to nudgecore_v2's userIdentifier() method
  static Future<void> userIdentifier({
    required String? externalId,
    String? name,
    String? email,
    String? phoneNumber,
    String? referralCode,
    Map<String, dynamic>? properties,
  }) async {
    _ensureInitialized();

    _externalId = externalId;
    _userProperties = {
      if (name != null) 'name': name,
      if (email != null) 'email': email,
      if (phoneNumber != null) 'phone_number': phoneNumber,
      if (referralCode != null) 'referral_code': referralCode,
      ...?properties,
    };

    final payload = {
      'external_id': externalId,
      'userId': // CamelCase
          _prefs?.getString(_prefsKeyUserId) ?? externalId ?? 'anonymous',
      'traits': _userProperties,
      'timestamp': DateTime.now().toIso8601String(),
    };

    try {
      await _post('/v1/identify', payload);
    } catch (e) {
      debugLog('userIdentifier failed, queuing: $e');
      await _queueEvent({'type': 'identify', 'payload': payload});
    }
  }

  /// Get current user details
  ///
  /// Similar to nudgecore_v2's getUserDetails() method
  static Future<Map<String, dynamic>?> getUserDetails() async {
    _ensureInitialized();

    return {
      'user_id': _prefs?.getString(_prefsKeyUserId),
      'external_id': _externalId,
      'session_id': _sessionId,
      'properties': _userProperties,
      'locale': _locale,
    };
  }

  /// Sign out the current user
  ///
  /// Similar to nudgecore_v2's userSignOut() method
  static Future<void> userSignOut() async {
    await logout();
  }

  /// Set region for SDK (using enum)
  ///
  /// Regions: NinjaRegion.US, NinjaRegion.EU, NinjaRegion.IN, etc.
  static void setNinjaRegion(NinjaRegion region) {
    _ninjaRegion = region;
    _region = region.value;
    debugLog('Region set to: ${region.name} (${region.value})');
  }

  /// Set region for SDK (using string - backward compatibility)
  ///
  /// Regions: 'US', 'EU', 'IN', 'AU', etc.
  static void setRegion(String region) {
    _region = region;
    _ninjaRegion = parseNinjaRegion(region);
    debugLog('Region set to: $region');
  }

  /// Register refresh token callback
  ///
  /// Similar to nudgecore_v2's registerRefreshToken() method
  static Future<void> registerRefreshToken(Function() callback) async {
    _refreshTokenCallback = callback;
    debugLog('Refresh token callback registered');
  }

  /// Register auth callback for handling static keys
  ///
  /// Similar to nudgecore_v2's registerAuth() method
  static Future<void> registerAuth(Function(String? key) callback) async {
    _authCallback = callback;
    debugLog('Auth callback registered');
  }

  /// Clear all nudges for current screen
  ///
  /// Similar to nudgecore_v2's clearNudges() method
  static Future<void> clearNudges() async {
    _campaignController.add([]);
    debugLog('All nudges cleared');
  }

  /// Add referral leads
  ///
  /// Similar to nudgecore_v2's addLeads() method
  static Future<void> addLeads(
      {required List<Map<String, dynamic>> leads}) async {
    _ensureInitialized();

    try {
      await _post('/api/v1/nudge/leads', {'leads': leads});
      debugLog('Added ${leads.length} referral leads');
    } catch (e) {
      debugLog('addLeads failed: $e');
    }
  }

  /// Set context (for widget tracking)
  ///
  /// Similar to nudgecore_v2's setContext() method
  static void setContext(BuildContext context) {
    _appContext = context;
  }

  /// Start a new session
  static Future<void> startSession() async {
    _sessionId =
        '${DateTime.now().millisecondsSinceEpoch}_${_prefs?.getString(_prefsKeyUserId) ?? 'anonymous'}';
    debugLog('Session started: $_sessionId');
    track('session_start', properties: {'session_id': _sessionId});
  }

  /// End current session
  static Future<void> endSession() async {
    if (_sessionId != null) {
      track('session_end', properties: {'session_id': _sessionId});
      debugLog('Session ended: $_sessionId');
      _sessionId = null;
    }
  }

  /// Enable or disable the SDK completely
  static void setShouldDisableNinja(bool disable) {
    _shouldDisableSdk = disable;
    debugLog('SDK disabled: $disable');
  }

  /// Enable or disable back button listener
  static void setShouldDisableBackPressedListener(bool disable) {
    _shouldDisableBackPressedListener = disable;
    debugLog('Back pressed listener disabled: $disable');
  }

  /// Enable or disable parent widget check
  static void setShouldCheckForParentWidget(bool enable) {
    _shouldCheckForParentWidget = enable;
    debugLog('Check for parent widget: $enable');
  }

  /// Enable or disable Flutter widget touch
  static void setShouldEnableFlutterWidgetTouch(bool enable) {
    _shouldEnableFlutterWidgetTouch = enable;
    debugLog('Flutter widget touch enabled: $enable');
  }

  /// Request push notification permission (placeholder for pure Flutter)
  static Future<bool> requestPushPermission() async {
    debugLog(
        'requestPushPermission called (integrate firebase_messaging for real implementation)');
    // In a real app, integrate firebase_messaging:
    // final messaging = FirebaseMessaging.instance;
    // final settings = await messaging.requestPermission();
    // return settings.authorizationStatus == AuthorizationStatus.authorized;
    return false;
  }

  /// Set FCM token for push notifications
  static void setFcmToken(String token) {
    debugLog('FCM token set: ${token.substring(0, 10)}...');
    // Store token and send to backend
    _prefs?.setString('ninja_fcm_token', token);
    track('fcm_token_set', properties: {'token': token});
  }

  /// Show notification (placeholder for pure Flutter)
  static void showNotification(Map<String, dynamic> remoteMessage) {
    debugLog('showNotification: $remoteMessage');
    _notificationClickListener?.call(remoteMessage);
    // In a real app, use flutter_local_notifications to show the notification
  }

  /// Get all elements with their positions
  ///
  /// [listenerId] - Unique listener ID
  /// [pixRatio] - Device pixel ratio
  /// [screenWidth] - Screen width in pixels
  /// [screenHeight] - Screen height in pixels
  static List<Map<String, dynamic>> getAllElements(String listenerId,
      double pixRatio, double screenWidth, double screenHeight) {
    debugLog('getAllElements: Starting with listeners=$listenerId');

    if (_appContext == null) {
      debugLog('getAllElements: _appContext is NULL. Aborting.');
      return [];
    }
    debugLog('getAllElements: _appContext found.');

    final elements = <Map<String, dynamic>>[];

    // Traverse widget tree and collect elements
    void recurse(Element element) {
      try {
        if (element.widget.key is ValueKey) {
          final key = (element.widget.key as ValueKey).value.toString();
          // debugLog('Found Element: $key'); // Too verbose?
          final renderObject = element.renderObject;

          if (renderObject is RenderBox && renderObject.hasSize) {
            final offset = renderObject.localToGlobal(Offset.zero);
            final size = renderObject.size;

            elements.add({
              'id': key,
              'type': element.widget.runtimeType.toString(),
              'rect': {
                'x': offset.dx * pixRatio,
                'y': offset.dy * pixRatio,
                'width': size.width * pixRatio,
                'height': size.height * pixRatio,
              },
              'inViewport': _isElementVisible(offset, size, screenWidth / pixRatio, screenHeight / pixRatio),
            });

            _elementPositions[key] = {
              'x': offset.dx,
              'y': offset.dy,
              'width': size.width,
              'height': size.height,
            };
          }
        }
        element.visitChildren(recurse);
      } catch (e) {
        // Skip elements that throw errors
      }
    }

    try {
      debugLog('getAllElements: Visiting child elements...');
      int visitedCount = 0;
      int keyCount = 0;
      int visibleCount = 0;

      void recurse(Element element) {
        visitedCount++;
        try {
          String? foundId;
          
          // 1. Check for EmbedWidgetWrapper (User Preferred)
          if (element.widget is EmbedWidgetWrapper) {
            foundId = (element.widget as EmbedWidgetWrapper).id;
          } 
          // 2. Fallback to ValueKey (Legacy/Internal)
          else if (element.widget.key is ValueKey) {
             // Only use string keys to avoid confusion
             final val = (element.widget.key as ValueKey).value;
             if (val is String) foundId = val;
          }

          if (foundId != null) {
            final key = foundId;
            final renderObject = element.renderObject;
            
            debugLog('🔍 Found ID: $key (${element.widget.runtimeType})');

            if (renderObject is RenderBox && renderObject.hasSize) {
              final offset = renderObject.localToGlobal(Offset.zero);
              final size = renderObject.size;
              
              // 1. Check if element is on the CURRENT ROUTE
              bool isCurrentRoute = true;
              try {
                final route = ModalRoute.of(element);
                if (route != null) {
                  isCurrentRoute = route.isCurrent;
                }
              } catch (e) {
                // Ignore errors finding route
              }

              if (!isCurrentRoute) {
                 debugLog('   - SKIPPED: Background Route ($key)');
              } else {
                final isVisible = _isElementVisible(offset, size, screenWidth / pixRatio, screenHeight / pixRatio);
                
                // FORCE ADD if on current route, even if geometry check fails slightly
                // This ensures we capture all user-tagged elements on the active page.
                visibleCount++;
                elements.add({
                  'id': key,
                  'type': element.widget.runtimeType.toString(),
                  'rect': {
                    'x': offset.dx * pixRatio,
                    'y': offset.dy * pixRatio,
                    'width': size.width * pixRatio,
                    'height': size.height * pixRatio,
                  },
                  'inViewport': isVisible, 
                });

                _elementPositions[key] = {
                  'x': offset.dx,
                  'y': offset.dy,
                  'width': size.width,
                  'height': size.height,
                };
              }
            } else {
               debugLog('   - SKIPPED: No RenderBox or No Size (RO: $renderObject)');
            }
          }
          element.visitChildren(recurse);
        } catch (e) {
          debugLog('Error visiting element: $e');
        }
      }

      // Use _appContext (NinjaApp Root) if available, as it covers everything.
      // Fallback to Navigator Key (Active Page) if not.
      final rootContext = _appContext ?? navigatorKey.currentContext;
      
      if (rootContext == null) {
        debugLog('❌ getAllElements: No context available');
        return [];
      }
      
      rootContext.visitChildElements(recurse);
      debugLog('getAllElements: Scanned $visitedCount elements. Found $keyCount ValueKeys. valid & visible: $visibleCount.');
      
    } catch (e) {
      debugLog('Error in getAllElements tree traversal: $e');
    }

    return elements;
  }

  static bool _isElementVisible(Offset offset, Size size, double screenWidth, double screenHeight) {
    final centerX = offset.dx + size.width / 2;
    final centerY = offset.dy + size.height / 2;
    return centerX >= 0 && centerX <= screenWidth && centerY >= 0 && centerY <= screenHeight;
  }

  /// Check if views with given keys are present
  static bool areViewsPresent(List<String> keys) {
    for (final key in keys) {
      if (!_elementPositions.containsKey(key)) {
        return false;
      }
    }
    return true;
  }

  /// Get position of a view by key
  static Map<String, dynamic>? getViewPosition(String key) {
    return _elementPositions[key];
  }

  /// Recursively traverse widget tree and collect element positions
  ///
  /// This matches Plotline's recurseKey signature
  static List<Map<String, dynamic>> recurseKey(BuildContext element,
      double pixRatio, int screenWidth, int screenHeight) {
    List<Map<String, dynamic>> list = [];

    try {
      debugLog(
          "recurseKey called with pixRatio: $pixRatio, screenWidth: $screenWidth, screenHeight: $screenHeight");

      element.visitChildElements((element) {
        try {
          String? key = extractKeyValue(element);
          debugLog("Visited Raw Element: $key, ${element.widget.runtimeType}");

          if (key != null && key.isNotEmpty && visibilityMap[key] == 100.0) {
            debugLog("Visited Element: $key");
            RenderBox? box = element.renderObject as RenderBox?;

            if (box != null && box.hasSize) {
              Offset position = box.localToGlobal(Offset.zero);

              if (isWithinBoundsContext(
                  element, position, pixRatio, screenWidth, screenHeight)) {
                debugLog("Element within Bounds: $key");

                Map<String, dynamic> newPosition = {};
                Map<String, dynamic> elementObj = {};

                newPosition['x'] = ((position.dx * pixRatio) + 0.6).round();
                newPosition['y'] = ((position.dy * pixRatio) + 0.6).round();
                newPosition['width'] = ((box.size.width) * pixRatio).round();
                newPosition['height'] = ((box.size.height) * pixRatio).round();

                elementObj['position'] = newPosition;
                elementObj['clientElementId'] = key;
                elementObj['isWidget'] = false;

                list.add(elementObj);
              }
            }
          }

          list.addAll(recurseKey(element, pixRatio, screenWidth, screenHeight));
        } catch (e) {
          debugLog("Error in visitChildElements: $e");
        }
      });
    } catch (e) {
      debugLog("Error in recurseKey: $e");
    }

    return list;
  }

  /// Find view by key value
  static BuildContext? findViewByKey(String key, BuildContext context) {
    BuildContext? result;
    final visitedElements = <Element>{};

    void searchForWidget(Element element) {
      try {
        if (!visitedElements.contains(element)) {
          visitedElements.add(element);
          String? widgetKey = extractKeyValue(element);

          if (widgetKey != null && widgetKey == key) {
            result = element;
            return;
          }

          element.visitChildElements(searchForWidget);
        }
      } catch (e) {
        debugLog("Error in searchForWidget: $e");
      }
    }

    context.visitChildElements(searchForWidget);
    return result;
  }

  /// Extract key value from element
  static String? extractKeyValue(Element element) {
    final key = element.widget.key;
    if (key is ValueKey) {
      return key.value.toString();
    }
    return null;
  }

  /// Check if a point is within bounds (simple version)
  static bool isWithinBounds(double x, double y, double left, double top,
      double right, double bottom) {
    return x >= left && x <= right && y >= top && y <= bottom;
  }

  /// Check if element is within screen bounds (BuildContext version)
  static bool isWithinBoundsContext(BuildContext element, Offset position,
      double pixRatio, int screenWidth, int screenHeight) {
    try {
      final renderBox = element.findRenderObject() as RenderBox?;
      if (renderBox == null) return false;

      int x = ((position.dx * pixRatio)).round();
      int y = ((position.dy * pixRatio)).round();
      int width = ((renderBox.size.width) * pixRatio).round();
      int height = ((renderBox.size.height) * pixRatio).round();

      return x >= 0 &&
          y >= 0 &&
          (x + width) <= screenWidth &&
          (y + height) <= screenHeight &&
          width > 0 &&
          height > 0;
    } catch (e) {
      debugLog("Error in isWithinBoundsContext: $e");
      return false;
    }
  }

  /// Get the topmost context from a widget tree
  static BuildContext? getTopmostContext(BuildContext context) {
    if (!_shouldCheckForParentWidget) {
      return context;
    }

    BuildContext? topmost = context;

    void findTopmost(Element element) {
      topmost = element;
      element.visitAncestorElements((ancestor) {
        topmost = ancestor;
        return true;
      });
    }

    context.visitChildElements(findTopmost);
    return topmost;
  }

  // PRIVATE METHODS

  static Future<Map<String, String>> _getHeaders() async {
    return {
      'Content-Type': 'application/json',
      if (_apiKey != null) 'x-api-key': _apiKey!,
    };
  }

  static void _ensureInitialized() {
    if (!_initialized || _prefs == null) {
      throw StateError('AppNinja not initialized. Call AppNinja.init() first.');
    }
  }

  static Future<http.Response> _post(
      String path, Map<String, dynamic> body) async {
    final url = '$_baseUrl$path';
    debugLog('🌐 POST Request to: $url (Timeout: 60s)');
    final response = await http
        .post(
          Uri.parse(url),
          headers: await _getHeaders(),
          body: jsonEncode(body),
        )
        .timeout(const Duration(seconds: 60));

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('POST $path failed with status ${response.statusCode}');
    }

    return response;
  }

  static Future<void> _queueEvent(Map<String, dynamic> event) async {
    final queue = _prefs?.getStringList(_prefsKeyQueue) ?? <String>[];
    queue.add(jsonEncode(event));
    await _prefs?.setStringList(_prefsKeyQueue, queue);
    debugLog('Event queued, total: ${queue.length}');
  }

  static Future<void> _flushEventQueue() async {
    final queue = _prefs?.getStringList(_prefsKeyQueue) ?? <String>[];
    if (queue.isEmpty) return;

    final remaining = <String>[];
    for (final eventStr in queue) {
      try {
        final event = jsonDecode(eventStr) as Map<String, dynamic>;
        final type = event['type'];
        final payload = event['payload'] as Map<String, dynamic>;

        if (type == 'track') {
          await _post('/api/v1/nudge/track', payload);
        } else if (type == 'identify') {
          await _post('/api/v1/nudge/identify', payload);
        }
      } catch (e) {
        debugLog('Failed to flush event: $e');
        remaining.add(eventStr);
      }
      await Future.delayed(const Duration(milliseconds: 150));
    }

    await _prefs?.setStringList(_prefsKeyQueue, remaining);
    debugLog('Event queue flushed, remaining: ${remaining.length}');
  }

  static Future<List<Campaign>> _loadCachedCampaigns() async {
    final cached = _prefs?.getString(_prefsKeyCampaigns);
    if (cached != null) {
      try {
        final list = jsonDecode(cached) as List;
        final campaigns = list
            .map((c) => Campaign.fromJson(c as Map<String, dynamic>))
            .toList();
        _campaignController.add(campaigns);
        return campaigns;
      } catch (e) {
        debugLog('Error loading cached campaigns: $e');
      }
    }
    return [];
  }

  static void debugLog(String message) {
    // if (_debugMode) { // 🔥 FORCE LOGS
      debugPrint('InAppNinja: $message');
    // }
  }

  /// Get current app context (for widget detection)
  static BuildContext? get appContext => _appContext;

  /// Get current page name
  static String? get currentPage => _currentPage;

  /// Get current locale
  static String get locale => _locale;

  /// Get color theme
  static Map<String, String> get colorTheme => _colorTheme;

  /// Check if initialized
  static bool get isInitialized => _initialized;

  /// Check if SDK is disabled
  static bool get isSdkDisabled => _shouldDisableSdk;

  /// Check if back pressed listener is disabled
  static bool get isBackPressedListenerDisabled =>
      _shouldDisableBackPressedListener;

  /// Check if should check for parent widget
  static bool get shouldCheckForParentWidget => _shouldCheckForParentWidget;

  /// Check if Flutter widget touch is enabled
  static bool get isFlutterWidgetTouchEnabled =>
      _shouldEnableFlutterWidgetTouch;

  /// Get current region
  static String? get region => _region;

  /// Get current region as enum
  static NinjaRegion? get ninjaRegion => _ninjaRegion;



  /// Get screenshot key (nudgecore_v2 compatibility)
  static GlobalKey? get screenshotKey => _screenshotKey;

  /// Get external user ID
  static String? get externalId => _externalId;

  /// Get current session ID
  static String? get sessionId => _sessionId;

  /// Get user properties
  static Map<String, dynamic> get userProperties => _userProperties;

  /// Get current user object
  static NinjaUser? get currentUser => _currentUser;

  /// Trigger redirect event
  static void triggerRedirect(Map<String, dynamic> properties) {
    _redirectListener?.call(properties);
  }

  /// Trigger refresh token callback
  static void triggerRefreshToken() {
    _refreshTokenCallback?.call();
  }

  /// Trigger auth callback
  static void triggerAuth(String? key) {
    _authCallback?.call(key);
  }

  // ========== AUTO-RENDER FEATURES ==========

  /// Set global context for auto-rendering campaigns
  ///
  /// This should be called by NinjaApp wrapper widget automatically
  static void setGlobalContext(BuildContext context) {
    _globalContext = context;
    debugLog('🌍 Global context set for auto-rendering');
  }

  /// Auto-fetch campaigns (called by NinjaApp on app resume)
  static Future<void> autoFetchCampaigns() async {
    if (!_autoRenderEnabled) return;

    try {
      debugLog('🔄 Auto-fetching campaigns...');
      await fetchCampaigns();
    } catch (e) {
      debugLog('❌ Auto-fetch campaigns failed: $e');
    }
  }

  /// Setup auto-rendering system
  ///
  /// Listens to campaign stream and automatically shows campaigns when they arrive
  static final Map<String, VoidCallback> _activeCampaignDismissals = {};

  /// Auto-show campaign (universal renderer for all types)
  static void _autoShowCampaign(Campaign campaign) {
    // Resolve context: Prefer Navigator's OVERLAY context (child of Navigator) 
    // This ensures Navigator.of(context) finds the navigator itself, instead of looking above it.
    final context = _navigatorKey?.currentState?.overlay?.context ?? 
                   _navigatorKey?.currentContext ?? 
                   _globalContext;

    if (context == null) {
      debugLog('❌ Cannot auto-show campaign: No valid context (Global or Navigator)');
      return;
    }

    // Prevent duplicates - check if this campaign was already shown in this session
    // EXCEPTION: If it is currently active, we might want to refresh it? 
    // For now, let's treat "Active" as "Shown".
    if (_shownCampaignsThisSession.contains(campaign.id) && !_activeCampaignDismissals.containsKey(campaign.id)) {
      debugLog(
          'ℹ️ Campaign ${campaign.id} already shown this session, skipping auto-render');
      return;
    }

    final campaignType = campaign.type.toLowerCase();
    debugLog(
        '🚀 Auto-showing $campaignType campaign: ${campaign.title} (${campaign.id})');

    // Dismiss this specific campaign if already active (Refresh)
    if (_activeCampaignDismissals.containsKey(campaign.id)) {
      debugLog('🔄 Refreshing existing campaign ${campaign.id}');
      _activeCampaignDismissals[campaign.id]?.call();
      _activeCampaignDismissals.remove(campaign.id);
    }

    // Mark campaign as shown in this session
    _shownCampaignsThisSession.add(campaign.id);
    _lastShownPipId = campaign.id;
    _lastCampaignShownTime = DateTime.now();

    try {
      // Use NinjaCampaignRenderer to show the campaign
      final dismissCallback = NinjaCampaignRenderer.show(
        campaign: campaign,
        context: context,
        overlayState: _navigatorKey?.currentState?.overlay, // Pass direct overlay state
        onImpression: () {
          debugLog('👁️ Auto-tracked impression: ${campaign.id}');
          track('campaign_viewed', properties: {
            'campaign_id': campaign.id,
            'campaign_name': campaign.title,
            'campaign_type': campaign.type,
            'auto_rendered': true,
            'timestamp': DateTime.now().toIso8601String(),
          });
        },
        onDismiss: () {
          debugLog('❌ Auto-rendered campaign dismissed: ${campaign.id}');
          track('campaign_dismissed', properties: {
            'campaign_id': campaign.id,
            'campaign_name': campaign.title,
          });
          
          // Clean up dismissal registry
          _activeCampaignDismissals.remove(campaign.id);
          
          if (_lastShownPipId == campaign.id) {
             _lastShownPipId = null;
          }
        },
        onCTAClick: (action, data) {
          debugLog('🎯 Auto-rendered CTA clicked: $action');
          track('campaign_clicked', properties: {
            'campaign_id': campaign.id,
            'campaign_name': campaign.title,
            'action': action,
            'button_text': data?['button_text'],
          });
        },
      );
      
      if (dismissCallback != null) {
         _activeCampaignDismissals[campaign.id] = dismissCallback;
      }

      debugLog('✅ Campaign auto-rendered successfully: ${campaign.title}');
    } catch (e) {
      debugLog('❌ Auto-show campaign failed: $e');
      debugPrint('Auto-render error stack: ${StackTrace.current}');
    }
  }

  /// Setup auto-rendering system
  ///
  /// Listens to campaign stream and automatically shows campaigns when they arrive
  static void _setupAutoRendering() {
    debugLog('🎯 Setting up auto-rendering system');

    // Cancel existing subscription if any
    _autoRenderSubscription?.cancel();

    // Listen to campaigns and auto-show them
    _autoRenderSubscription = onCampaigns.listen((campaigns) {
      // Use navigator context if available, fallback to global
      final hasContext = _navigatorKey?.currentContext != null || _globalContext != null;
      
      if (!_autoRenderEnabled || !hasContext) {
        debugLog('⚠️ Auto-render disabled or no context available');
        return;
      }

      debugLog('📦 Auto-render received ${campaigns.length} campaigns');

      // 🔥 SUPPORT MULTIPLE SIMULTANEOUS CAMPAIGNS
      // Instead of picking one, we iterate and show ALL eligible ones.
      // We rely on _autoShowCampaign to handle duplicates/refresh.
      
      for (final campaign in campaigns) {
         debugLog('🔍 Processing campaign for auto-render: ${campaign.id} - ${campaign.title}');
         // Optional: Add logic here to prevent Modal overlap if necessary.
         // For now, we trust the user's setup (don't trigger 2 modals at once).
         _autoShowCampaign(campaign);
      }
    });

    // Auto-fetch campaigns on startup (after init completes)
    Future.delayed(const Duration(milliseconds: 500), () {
      autoFetchCampaigns();
    });
  }

  /// Dispose resources
  static Future<void> dispose() async {
    _autoRenderSubscription?.cancel();
    await _campaignController.close();
    _initialized = false;
  }
}
