import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:app_links/app_links.dart';
import 'package:screenshot/screenshot.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:flutter/scheduler.dart';
import '../app_ninja.dart';

class CaptureManager {
  static StreamSubscription? _sub;
  // Remove static controller. user registerScreenshotCallback instead.
  // static ScreenshotController screenshotController = ScreenshotController();
  
  static Future<Uint8List?> Function(Duration delay, double pixelRatio)? _captureCallback;

  static void registerScreenshotCallback(Future<Uint8List?> Function(Duration, double) callback) {
    _captureCallback = callback;
  }

  static final _appLinks = AppLinks();
  // static OverlayEntry? _overlayEntry; // REMOVED: Using Stack/Notifier instead
  static String? _sessionToken;
  
  // Controls visibility of the Capture Button in NinjaApp
  static final ValueNotifier<bool> showCaptureUi = ValueNotifier(false);

  // Initialize Deep Link Listener
  static void init(BuildContext context) {
    // 1. Check initial link
    _appLinks.getInitialLink().then((uri) {
      if (uri != null) _handleLink(uri, context);
    });

    // 2. Listen for incoming links
    _sub = _appLinks.uriLinkStream.listen((Uri uri) {
      _handleLink(uri, context);
    }, onError: (err) {
      debugPrint('Deep Link Error: $err');
    });
  }

  static void dispose() {
    _sub?.cancel();
    showCaptureUi.value = false;
  }

  static void _handleLink(Uri uri, BuildContext context) {
    debugPrint('🔗 Deep Link received: $uri');
    
    if (uri.scheme == 'embeddedcraft' && uri.host == 'capture') {
      final token = uri.queryParameters['token'];
      if (token != null) {
        _sessionToken = token;
        
        // Enable Capture UI
        showCaptureUi.value = true;
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('📸 Capture Mode Enabled'), backgroundColor: Colors.green),
        );
      }
    }
  }

  // Called by the Button in NinjaApp
  static Future<void> startCaptureFlow(BuildContext context) async {
    debugPrint('📸 Capture Flow Started');
    
    // 1. Hide Button
    showCaptureUi.value = false; 

    // 2. Wait for UI to settle
    debugPrint('⏳ UI Settling (500ms)...');
    await Future.delayed(const Duration(milliseconds: 500));

    try {
      debugPrint('📸 Requesting Capture (via callback)...');
      
      if (_captureCallback == null) {
        throw Exception('No Capture Callback registered!');
      }

      Uint8List? imageBytes;
      int attempts = 0;
      while (attempts < 3) {
        try {
          attempts++;
          imageBytes = await _captureCallback!(
            const Duration(milliseconds: 100), 
            MediaQuery.of(context).devicePixelRatio
          );
          if (imageBytes != null) break; 
        } catch (e) {
          debugPrint('⚠️ Capture Attempt #$attempts failed: $e');
          if (attempts >= 3) rethrow;
          await Future.delayed(const Duration(milliseconds: 500));
        }
      }
      
      if (imageBytes == null) throw Exception('Screenshot returned null bytes');
      debugPrint('✅ Screenshot captured (${imageBytes.length} bytes)');

      // 3. Data Mining
      debugPrint('⛏️ Starting Data Mining...');
      final size = MediaQuery.of(context).size;
      final elements = AppNinja.getAllElements(
        'capture_${DateTime.now().millisecondsSinceEpoch}',
        MediaQuery.of(context).devicePixelRatio,
        size.width,
        size.height,
      );

      // 4. Show Name Dialog
      // Use Global Navigator Key for context if available, else fall back
      final navContext = AppNinja.navigatorKey.currentContext ?? context;

      if (navContext.mounted) {
         // Check if Navigator calls are safe
         if (Navigator.maybeOf(navContext) != null) {
            _showNameDialog(navContext, imageBytes, elements);
         } else {
            debugPrint('❌ Capture Error: Context found, but NO Navigator available.');
            // Try to warn using ScaffoldMessenger if possible
            try {
              ScaffoldMessenger.of(navContext).showSnackBar(
                const SnackBar(
                  content: Text('⚠️ Config Error: No Navigator found! Set AppNinja.navigatorKey in MaterialApp.'),
                  backgroundColor: Colors.orange,
                  duration: Duration(seconds: 5),
                ),
              );
            } catch (_) {}
            showCaptureUi.value = true;
         }
      } else {
         debugPrint('❌ No valid context found for Dialog');
         showCaptureUi.value = true;
      }

    } catch (e) {
      debugPrint('❌ Capture Error: $e');
      final navContext = AppNinja.navigatorKey.currentContext ?? context;
      if (navContext.mounted) {
        try {
          ScaffoldMessenger.of(navContext).showSnackBar(
            SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
          );
        } catch (_) {}
      }
      showCaptureUi.value = true;
    }
  }

  static void closeCaptureMode() {
    showCaptureUi.value = false;
  }

  static void _showNameDialog(BuildContext context, dynamic imageBytes, List<Map<String, dynamic>> elements) {
    final nameController = TextEditingController();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('Save Page'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: 'Page Name',
                hintText: 'e.g. Checkout Screen',
                border: OutlineInputBorder(),
              ),
              autofocus: true,
            ),
            const SizedBox(height: 10),
            Text('${elements.length} interactable elements found.', style: const TextStyle(fontSize: 12, color: Colors.grey)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              showCaptureUi.value = true; // Restore button
            },
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (nameController.text.isEmpty) return;
              Navigator.pop(ctx);
              _uploadCapture(context, imageBytes, elements, nameController.text);
            },
            child: const Text('Save & Upload'),
          ),
        ],
      ),
    );
  }

  static Future<void> _uploadCapture(
    BuildContext context, 
    dynamic imageBytes, 
    List<Map<String, dynamic>> elements,
    String pageName
  ) async {
    // Show Loading
    showDialog(context: context, barrierDismissible: false, builder: (_) => const Center(child: CircularProgressIndicator()));

    try {
      final tempDir = await getTemporaryDirectory();
      final file = await File('${tempDir.path}/screenshot.png').create();
      await file.writeAsBytes(imageBytes);

      final metadata = {
        'deviceType': Platform.isAndroid ? 'Android' : 'iOS',
        'width': MediaQuery.of(context).size.width,
        'height': MediaQuery.of(context).size.height,
        'density': MediaQuery.of(context).devicePixelRatio,
        'orientation': MediaQuery.of(context).orientation.name,
      };

      await _upload(file, _sessionToken!, metadata, elements, pageName);

      Navigator.pop(context); // Remove Loading
      showCaptureUi.value = false; // Disable mode after success
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('✅ Page Uploaded Successfully! Check Dashboard.'), backgroundColor: Colors.green),
      );

    } catch (e) {
      Navigator.pop(context); // Remove Loading
      debugPrint('Upload Error: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Upload Failed: $e'), backgroundColor: Colors.red),
      );
      showCaptureUi.value = true; // Restore UI to try again
    }
  }

  static Future<void> _upload(
    File imageFile, 
    String token, 
    Map metadata, 
    List<Map<String, dynamic>> elements,
    String pageName
  ) async {
    String uploadUrl = '${AppNinja.baseUrl}/api/pages/upload'; 

    var request = http.MultipartRequest('POST', Uri.parse(uploadUrl));

    request.headers['Authorization'] = 'Bearer $token';
    request.files.add(await http.MultipartFile.fromPath('screenshot', imageFile.path));
    
    request.fields['name'] = pageName;
    request.fields['pageTag'] = pageName.toLowerCase().replaceAll(' ', '_');
    request.fields['deviceMetadata'] = jsonEncode(metadata);
    request.fields['elements'] = jsonEncode(elements); 

    final response = await request.send();
    
    if (response.statusCode == 401) {
      throw Exception('Session Expired ⏳. Please refresh Dashboard & Scan New QR.');
    }
    
    if (response.statusCode != 200 && response.statusCode != 201) {
      throw Exception('Server Error: ${response.statusCode}');
    }
  }
}
