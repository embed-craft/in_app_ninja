package com.embeddedcraft.in_app_ninja

import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Handler
import android.os.Looper
import android.view.View
import android.webkit.JavascriptInterface
import android.webkit.WebView
import android.webkit.WebViewClient
import android.webkit.WebSettings
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.platform.PlatformView
import org.json.JSONObject

class NinjaNativeView(
    private val context: Context,
    private val id: Int,
    private val creationParams: Map<String, Any>?,
    messenger: BinaryMessenger
) : PlatformView {

    private val methodChannel: MethodChannel = MethodChannel(messenger, "ninja_native_view_$id")
    private val webView: WebView = WebView(context).apply {
        settings.javaScriptEnabled = true
        settings.domStorageEnabled = true
        settings.cacheMode = WebSettings.LOAD_NO_CACHE
        settings.useWideViewPort = false  // CHANGED: Disable wide viewport
        settings.loadWithOverviewMode = false  // CHANGED: Disable overview mode
        settings.setSupportZoom(false)
        setInitialScale(100)  // ADDED: Force 100% scale
        setBackgroundColor(0)
        webViewClient = WebViewClient()
        webChromeClient = android.webkit.WebChromeClient() // ✅ ENABLE ALERTS
        addJavascriptInterface(NinjaBridge(), "NinjaBridge")
    }

    init {
        WebView.setWebContentsDebuggingEnabled(true)
        val configJson = creationParams?.get("config") as? String ?: "{}"
        
        // Generate HTML with embedded logic
        val html = generateRendererHTML(configJson)
        
        webView.loadDataWithBaseURL(
            "about:blank",
            html,
            "text/html",
            "UTF-8",
            null
        )
    }

    override fun getView(): View = webView

    override fun dispose() {
        webView.destroy()
        methodChannel.setMethodCallHandler(null)
    }

    // Bridge for JS -> Native communication
    private inner class NinjaBridge {
        @JavascriptInterface
        fun postMessage(message: String) {
            Handler(Looper.getMainLooper()).post {
                handleJsMessage(message)
            }
        }
    }

    private fun handleJsMessage(message: String) {
        try {
            val json = JSONObject(message)
            val type = json.optString("type")
            
            when (type) {
                "close", "dismiss" -> {
                    methodChannel.invokeMethod("onDismiss", null)
                }
                "deeplink" -> {
                    val url = json.optString("url")
                    if (url.isNotEmpty()) {
                        try {
                            val intent = Intent(Intent.ACTION_VIEW, Uri.parse(url))
                            intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                            context.startActivity(intent)
                        } catch (e: Exception) {
                            e.printStackTrace()
                        }
                    }
                }
                "navigate" -> {
                    val screenName = json.optString("screenName")
                    if (screenName.isNotEmpty()) {
                        methodChannel.invokeMethod("onNavigate", screenName)
                    }
                }
                "custom" -> {
                    val eventName = json.optString("eventName")
                    val eventData = json.optJSONObject("data")?.toString()
                    methodChannel.invokeMethod("onCustomEvent", mapOf("name" to eventName, "data" to eventData))
                }
            }
        } catch (e: Exception) {
            e.printStackTrace()
        }
    }

    private fun generateRendererHTML(configJson: String): String {
        val safeConfigJson = configJson.replace("/", "\\/")
        val js = """
const config = $safeConfigJson;

// DEBUG: Verify settings reach the device (Unconditional)
console.log("Config received:", JSON.stringify(config));
alert("DEBUG CONFIG: " + JSON.stringify(config)); 

// BRIDGE: Send action to Android Native
const handleAction = (action) => {
    if (!action) return;
    console.log('Action:', JSON.stringify(action));
    
    // Call Native Bridge if available
    if (window.NinjaBridge && window.NinjaBridge.postMessage) {
        window.NinjaBridge.postMessage(JSON.stringify(action));
    } else {
        console.warn('NinjaBridge not found');
    }
};

// GLOBAL SCALING LOGIC
const designWidth = 375;
const deviceWidth = window.innerWidth;
const scale = deviceWidth / designWidth;

const safeScale = (vals, factor) => {
    if (vals == null) return null;
    const val = vals.toString();
    if (val.endsWith('%')) return val;
    const num = parseFloat(val);
    if (isNaN(num)) return val;
    return (num * factor) + 'px';
};

const getNum = (val) => {
    if (typeof val === 'number') return val;
    if (typeof val === 'string' && val.endsWith('px')) return parseFloat(val);
    return parseFloat(val) || 0;
}

const styleTag = document.createElement('style');
styleTag.innerHTML = 
    '.layer { position: relative; margin-bottom: ' + safeScale(10, scale) + '; } ' +
    '.layer.absolute { position: absolute; margin-bottom: 0; }';
document.head.appendChild(styleTag);

function renderBottomSheet() {
    let layers = [];
    if (config.components && config.components.length > 0) {
        layers = config.components;
    } else if (config.layers) {
        layers = config.layers;
    }
    
    const root = document.getElementById('root');
    const sheet = document.createElement('div');
    sheet.className = 'bottom-sheet';
    
    const bgColor = config.backgroundColor || 'white';
    const borderRadius = config.borderRadius || {};
    const padding = config.padding || {};

    // SDK PARITY: Check for Full Page Mode Layer
    const fullPageLayer = layers.find(l => l.type === 'custom_html' && l.content && l.content.fullPageMode === true);
    const isFullPage = !!fullPageLayer;

    // Logic: If Full Page, force transparent background, 100% height, no shadow, no padding
    const activeBgColor = isFullPage ? 'transparent' : (bgColor === 'transparent' || bgColor === '#00000000' ? 'transparent' : bgColor);
    const activeBoxShadow = isFullPage 
        ? 'none' 
        : (config.boxShadow || 'none');
    const activeHeight = isFullPage ? '100%' : (config.height || 'auto');
    const activePadding = isFullPage ? '0px' : ((padding.top || 0) + 'px ' + (padding.right || 0)  + 'px ' + (padding.bottom || 0) + 'px ' + (padding.left || 0) + 'px');
    const activeRadius = isFullPage ? '0px' : ((borderRadius.topLeft || 16) + 'px'); // Simplified for brevity, matches logic

    sheet.style.cssText = 
        'background-color: ' + activeBgColor + ';' +
        'border-top-left-radius: ' + (isFullPage ? 0 : (borderRadius.topLeft || 16)) + 'px;' +
        'border-top-right-radius: ' + (isFullPage ? 0 : (borderRadius.topRight || 16)) + 'px;' +
        'padding: ' + activePadding + ';' +
        'box-shadow: ' + activeBoxShadow + ';' +
        'min-height: 100px;' +
        'height: ' + activeHeight + ';';
    
    if (config.dragHandle) {
        const handle = document.createElement('div');
        handle.style.cssText = 'width: 40px; height: 4px; background-color: #e5e7eb; border-radius: 2px; margin: 0 auto 16px auto; flex-shrink: 0;';
        sheet.appendChild(handle);
    }
    
    if (config.showCloseButton) {
        const closeBtn = document.createElement('button');
        closeBtn.innerHTML = '×';
        closeBtn.style.cssText = 'position: absolute; top: 16px; right: 16px; width: 28px; height: 28px; border-radius: 50%; background-color: rgba(0,0,0,0.05); border: none; font-size: 20px; display: flex; align-items: center; justify-content: center; cursor: pointer; z-index: 10;';
        // Add Close Action
        closeBtn.onclick = function(e) {
            e.stopPropagation();
            handleAction({ type: 'close' });
        };
        sheet.appendChild(closeBtn);
    }
    
    // Create layers map for easy lookup
    const layersMap = {};
    layers.forEach(function(l) { layersMap[l.id] = l; });
    
    // FLATTEN: Extract all layers including children from containers
    const allRenderableLayers = [];
    layers.forEach(function(layer) {
        if (layer.type === 'container' && layer.children && layer.children.length > 0) {
            // Skip the container itself, add its children directly
            layer.children.forEach(function(child) {
                const childLayer = typeof child === 'string' ? layersMap[child] : child;
                if (childLayer && childLayer.visible !== false) {
                    allRenderableLayers.push(childLayer);
                }
            });
        } else if (layer.type !== 'container') {
            // Add non-container layers
            if (layer.visible !== false) {
                allRenderableLayers.push(layer);
            }
        }
    });
    
    // SPLIT LAYERS: Relative (Scrollable) vs Absolute (Fixed/Overlay)
    const contentArea = document.createElement('div');
    contentArea.className = 'content-area';
    
    // Apply background from config - use contain to show full image
    if (config.backgroundImageUrl) {
        sheet.style.backgroundImage = 'url(' + config.backgroundImageUrl + ')';
        sheet.style.backgroundSize = config.backgroundSize || 'contain';  // Use contain to show full image
        sheet.style.backgroundPosition = 'bottom center';
        sheet.style.backgroundRepeat = 'no-repeat';
    }
    
    // 1. Render RELATIVE layers into the scrollable content area
    allRenderableLayers.forEach(function(layer) {
        const style = layer.style || {};
        const isAbsolute = style.position === 'absolute' || style.position === 'fixed';
        
        if (!isAbsolute) {
            const el = renderLayer(layer, layersMap);
            if (el) {
                contentArea.appendChild(el);
            }
        }
    });
    
    sheet.appendChild(contentArea);
    
    // 2. Render ABSOLUTE layers directly into the sheet (Overlay/Fixed content)
    allRenderableLayers.forEach(function(layer) {
        const style = layer.style || {};
        const isAbsolute = style.position === 'absolute' || style.position === 'fixed';
        if (isAbsolute) {
            const el = renderLayer(layer, layersMap);
            if (el) sheet.appendChild(el);
        }
    });

    // 3. OVERLAY (Scrim) - Rendered BEHIND the Bottom Sheet
    if (config.overlay && config.overlay.enabled) {
        const overlay = document.createElement('div');
        const opacity = config.overlay.opacity != null ? config.overlay.opacity : 0.5;
        const color = config.overlay.color || '#000000';
        
        overlay.style.cssText = 
            'position: absolute; top: 0; left: 0; right: 0; bottom: 0;' +
            'background-color: ' + color + ';' +
            'opacity: ' + opacity + ';' +
            'z-index: 99;'; // Below Sheet (100)
            
        if (config.overlay.dismissOnClick) {
            overlay.onclick = function() {
                handleAction({ type: 'dismiss' });
            };
        }
        root.appendChild(overlay);
    }

    root.appendChild(sheet);
}

function renderModal() {
    // Helper to check multiple property keys (camelCase vs snake_case)
    function getProp(keys, defaultValue) {
        if (!Array.isArray(keys)) keys = [keys];
        for (var i = 0; i < keys.length; i++) {
            if (config[keys[i]] !== undefined) return config[keys[i]];
        }
        return defaultValue;
    }

    let layers = [];
    if (config.components && config.components.length > 0) {
        layers = config.components;
    } else if (config.layers) {
        layers = config.layers;
    }

    const root = document.getElementById('root');
    
    // Config Values with Fallbacks
    const overlayConfig = getProp(['overlay']) || {};
    const overlayEnabled = overlayConfig.enabled !== false; // Default true if object exists? No, check enabled prop. 
    // Actually safer to check config.overlay directly or via getProp paths if needed, but usually overlay object has consistent keys. 
    // Let's assume overlay object itself is consistent, but the key 'overlay' might be stable.
    
    // 1. OVERLAY (Scrim)
    if (overlayConfig && overlayConfig.enabled) {
        const overlay = document.createElement('div');
        const opacity = overlayConfig.opacity != null ? overlayConfig.opacity : 0.5;
        const color = overlayConfig.color || '#000000';
        
        overlay.style.cssText = 
            'position: absolute; top: 0; left: 0; right: 0; bottom: 0;' +
            'background-color: ' + color + ';' +
            'opacity: ' + opacity + ';' +
            'z-index: 99;'; // Behind Modal
            
        if (overlayConfig.dismissOnClick) {
            overlay.onclick = function() {
                handleAction({ type: 'dismiss' });
            };
        }
        root.appendChild(overlay);
    }

    // 2. MODAL BOX (Positioning Context)
    const modal = document.createElement('div');
    modal.className = 'modal-box';
    
    // Fetch Properties
    const width = getProp(['width']) || '90%';
    const height = getProp(['height']) || 'auto';
    const bgColor = getProp(['backgroundColor', 'background_color']) || '#FFFFFF';
    
    // Robust Border Radius
    let borderRadius = 16;
    const rawRadius = getProp(['borderRadius', 'border_radius']);
    if (typeof rawRadius === 'number') {
        borderRadius = rawRadius;
    } else if (rawRadius && typeof rawRadius === 'object') {
        borderRadius = rawRadius.topLeft || rawRadius.top_left || 16;
    }

    // Box Shadow
    const elevation = getProp(['elevation']);
    const rawShadow = getProp(['boxShadow', 'box_shadow']);
    const boxShadow = rawShadow || (elevation ? '0 4px 12px rgba(0,0,0,0.15)' : 'none');
    
    // Background handling
    const bgUrl = getProp(['backgroundImageUrl', 'background_image_url', 'backgroundImage', 'background_image']);
    const bgSize = getProp(['backgroundSize', 'background_size']) || 'cover';
    const bgPos = getProp(['backgroundPosition', 'background_position']) || 'center';

    // Construct CSS string
    let css = 'position: absolute; top: 50%; left: 50%; transform: translate(-50%, -50%);';
    css += 'width: ' + getNum(width) + (typeof width === 'string' && width.endsWith('%') ? '%' : 'px') + ';';
    css += 'max-width: 400px;';
    css += 'height: ' + (height === 'auto' ? 'auto' : getNum(height) + 'px') + ';';
    css += 'background-color: ' + bgColor + ';';
    css += 'border-radius: ' + borderRadius + 'px;';
    css += 'box-shadow: ' + boxShadow + ';';
    css += 'padding: 0;'; // FORCE 0 padding for coordinate accuracy
    css += 'z-index: 100;';
    css += 'overflow: visible;'; // Allow absolute children to pop
    css += 'min-height: 100px;';   // Prevent collapse

    if (bgUrl) {
         css += "background-image: url('" + bgUrl + "');";
         css += 'background-size: ' + bgSize + ';';
         css += 'background-position: ' + bgPos + ';';
         css += 'background-repeat: no-repeat;';
    }

    modal.style.cssText = css;

    // 3. INNER WRAPPER (Relative Flow + Padding)
    const contentWrapper = document.createElement('div');
    const p = getProp(['padding']) || {};
    const paddingStr = (p.top || 0) + 'px ' + (p.right || 0) + 'px ' + (p.bottom || 0) + 'px ' + (p.left || 0) + 'px';
    
    contentWrapper.style.cssText = 
        'position: relative; ' +
        'width: 100%; height: 100%; ' +
        'display: flex; flex-direction: column; ' +
        'padding: ' + paddingStr + ';';
        
    // Create layers map
    const layersMap = {};
    layers.forEach(function(l) { layersMap[l.id] = l; });
    
    // Flatten logic
    const allRenderableLayers = [];
    layers.forEach(function(layer) {
        if (layer.type === 'container' && layer.children && layer.children.length > 0) {
            layer.children.forEach(function(child) {
                const childLayer = typeof child === 'string' ? layersMap[child] : child;
                if (childLayer && childLayer.visible !== false) {
                    allRenderableLayers.push(childLayer);
                }
            });
        } else if (layer.type !== 'container') {
            if (layer.visible !== false) {
                allRenderableLayers.push(layer);
            }
        }
    });

    // Render RELATIVE layers -> contentWrapper
    allRenderableLayers.forEach(function(layer) {
        const style = layer.style || {};
        const isAbsolute = style.position === 'absolute' || style.position === 'fixed';
        if (!isAbsolute) {
            const el = renderLayer(layer, layersMap);
            if (el) contentWrapper.appendChild(el);
        }
    });

    modal.appendChild(contentWrapper);

    // Render ABSOLUTE layers -> modal (Directly, using 0,0 origin)
    allRenderableLayers.forEach(function(layer) {
        const style = layer.style || {};
        const isAbsolute = style.position === 'absolute' || style.position === 'fixed';
        if (isAbsolute) {
            const el = renderLayer(layer, layersMap);
            if (el) modal.appendChild(el);
        }
    });

    // Close Button
    const showClose = getProp(['showCloseButton', 'show_close_button']);
    if (showClose) {
        const closeBtn = document.createElement('button');
        closeBtn.innerHTML = '×';
        closeBtn.style.cssText = 'position: absolute; top: 12px; right: 12px; width: 28px; height: 28px; border-radius: 50%; background-color: rgba(0,0,0,0.05); border: none; font-size: 20px; display: flex; align-items: center; justify-content: center; cursor: pointer; z-index: 10;';
        closeBtn.onclick = function(e) {
            e.stopPropagation();
            handleAction({ type: 'close' });
        };
        modal.appendChild(closeBtn);
    }

    root.appendChild(modal);
}

function renderLayer(layer, layersMap) {
    const style = layer.style || {};
    const content = layer.content || {};
    const size = layer.size || {};
    const layerType = layer.type;
    
    const wrapper = document.createElement('div');
    wrapper.className = 'layer';
    
    const isAbsolute = style.position === 'absolute' || style.position === 'fixed';
    if (isAbsolute) wrapper.classList.add('absolute');
    
    // Click Handling Logic
    if (content.action) {
        wrapper.onclick = function(e) {
            e.stopPropagation();
            handleAction(content.action);
        };
        wrapper.style.cursor = 'pointer';
    }
    
    let cssText = '';
    
    // 1. POSITIONING
    if (style.top != null) cssText += 'top: ' + safeScale(style.top, scale) + '; ';
    if (style.bottom != null) cssText += 'bottom: ' + safeScale(style.bottom, scale) + '; ';
    
    if (style.left != null) cssText += 'left: ' + safeScale(style.left, scale) + '; ';
    if (style.right != null) cssText += 'right: ' + safeScale(style.right, scale) + '; ';
    
    // 2. DIMENSIONS
    const w = style.width || size.width;
    const h = style.height || size.height;
    if (w) cssText += 'width: ' + safeScale(w, scale) + '; ';
    if (h) cssText += 'height: ' + safeScale(h, scale) + '; ';
    
    // 3. TRANSFORM (Critical for Centering) - Do NOT scale, usually % based
    if (style.transform) cssText += 'transform: ' + style.transform + '; ';
    
    // 4. MARGINS (Critical for Relative Layouts)
    if (style.margin) {
        // Handle "0 auto" or complex margins. If string contains space, pass raw.
        if (typeof style.margin === 'string' && style.margin.includes(' ')) {
             cssText += 'margin: ' + style.margin + '; ';
        } else {
             cssText += 'margin: ' + safeScale(style.margin, scale) + '; ';
        }
    } else {
        // Default margin for relative layers if not specified
        if (!isAbsolute) {
             cssText += 'margin-bottom: ' + safeScale(10, scale) + '; ';
        }
    }
    if (style.marginTop) cssText += 'margin-top: ' + safeScale(style.marginTop, scale) + '; ';
    if (style.marginBottom) cssText += 'margin-bottom: ' + safeScale(style.marginBottom, scale) + '; ';
    if (style.marginLeft) cssText += 'margin-left: ' + safeScale(style.marginLeft, scale) + '; ';
    if (style.marginRight) cssText += 'margin-right: ' + safeScale(style.marginRight, scale) + '; ';

    // 5. VISUALS (Border, Shadow, Opacity)
    if (style.zIndex) cssText += 'z-index: ' + style.zIndex + '; ';
    if (style.backgroundColor) cssText += 'background-color: ' + style.backgroundColor + '; ';
    
    // Background Image
    if (style.backgroundImage) {
        cssText += 'background-image: url(' + style.backgroundImage + '); ';
        cssText += 'background-size: ' + (style.backgroundSize || 'cover') + '; ';
        cssText += 'background-position: ' + (style.backgroundPosition || 'center') + '; ';
        cssText += 'background-repeat: ' + (style.backgroundRepeat || 'no-repeat') + '; ';
    }
    
    if (style.borderRadius) {
        if (typeof style.borderRadius === 'object') {
             const br = style.borderRadius;
             const tl = safeScale(br.topLeft || 0, scale);
             const tr = safeScale(br.topRight || 0, scale);
             const br_r = safeScale(br.bottomRight || 0, scale);
             const bl = safeScale(br.bottomLeft || 0, scale);
             cssText += 'border-radius: ' + tl + ' ' + tr + ' ' + br_r + ' ' + bl + '; ';
        } else {
             cssText += 'border-radius: ' + safeScale(style.borderRadius, scale) + '; ';
        }
    }
    if (style.boxShadow) cssText += 'box-shadow: ' + style.boxShadow + '; '; // Complex string, usually px hardcoded in dash, might need scaling logic later but pass raw for now
    if (style.border) cssText += 'border: ' + style.border + '; ';
    if (style.opacity != null) cssText += 'opacity: ' + style.opacity + '; ';
    if (style.display) cssText += 'display: ' + style.display + '; ';
    if (style.flexDirection) cssText += 'flex-direction: ' + style.flexDirection + '; ';
    if (style.justifyContent) cssText += 'justify-content: ' + style.justifyContent + '; ';
    if (style.alignItems) cssText += 'align-items: ' + style.alignItems + '; ';

    wrapper.style.cssText = cssText;
    
    let innerElement;
    switch (layerType) {
        case 'text':
            innerElement = document.createElement('div');
            // Allow wrapping
            innerElement.style.whiteSpace = 'pre-wrap';
            innerElement.innerText = content.text || '';
            if (content.fontSize) innerElement.style.fontSize = safeScale(content.fontSize, scale);
            if (content.textColor) innerElement.style.color = content.textColor;
            // Font Weight (Numeric or String fallbacks)
            if (content.fontWeight) innerElement.style.fontWeight = content.fontWeight;
            if (content.textAlign) innerElement.style.textAlign = content.textAlign;
            
            // Custom Font Support
            if (content.fontFamily) innerElement.style.fontFamily = "'" + content.fontFamily + "', sans-serif";
            
            // Text Shadow Support
            if (content.textShadowX != null || content.textShadowY != null || content.textShadowBlur != null) {
                const tsX = content.textShadowX || 0;
                const tsY = content.textShadowY || 0;
                const tsB = content.textShadowBlur || 0;
                const tsC = content.textShadowColor || '#000000';
                innerElement.style.textShadow = safeScale(tsX, scale) + ' ' + safeScale(tsY, scale) + ' ' + safeScale(tsB, scale) + ' ' + tsC;
            }

            // Inject Font URL if present (SDK Scoped)
            if (content.fontUrl) {
                const link = document.createElement('link');
                link.rel = 'stylesheet';
                link.href = content.fontUrl;
                document.head.appendChild(link);
            }
            break;
        case 'image':
        case 'media':
            innerElement = document.createElement('img');
            innerElement.src = content.imageUrl || content.url || '';
            innerElement.style.cssText = 
                'width: 100%; height: 100%; ' +
                'object-fit: ' + (style.objectFit || 'cover') + '; ' +
                'border-radius: ' + safeScale(style.borderRadius || 0, scale) + ';';
            break;
        case 'button':
            innerElement = document.createElement('button');
            innerElement.textContent = content.label || content.text || 'Button';
            innerElement.style.cssText = 
                'width: 100%; height: 100%; ' +
                'padding: ' + safeScale(10, scale) + ' ' + safeScale(20, scale) + '; ' +
                'background-color: transparent; ' +
                'color: ' + (content.textColor || style.color || '#fff') + '; ' +
                'border: none; ' +
                'border-radius: inherit; ' + 
                'font-size: ' + safeScale(content.fontSize || style.fontSize || 14, scale) + '; ' +
                'font-weight: ' + (style.fontWeight || 600) + '; ' +
                'cursor: pointer; display: flex; align-items: center; justify-content: center;';
            break;
        case 'custom_html':
            innerElement = document.createElement('div');
            innerElement.innerHTML = content.html || '';
            
            // SDK PARITY: Force Full Page Coordinates
            if (content.fullPageMode === true) {
                wrapper.style.cssText += 'position: absolute; top: 0; left: 0; right: 0; bottom: 0; width: 100%; height: 100%; margin: 0;';
            }
            break;
        case 'container':
            // Container layer - renders as a div container with its children
            innerElement = document.createElement('div');
            innerElement.style.cssText = 'width: 100%; height: 100%;';
            

            
            // Recursively render children if they exist
            if (layer.children && layer.children.length > 0) {
                layer.children.forEach(function(child) {
                    // Handle both array of IDs (strings) and array of objects
                    let childLayer;
                    if (typeof child === 'string') {
                        // Child is an ID, look it up in layersMap
                        childLayer = layersMap ? layersMap[child] : null;
                    } else {
                        // Child is already a full object
                        childLayer = child;
                    }
                    
                    if (childLayer && childLayer.visible !== false) {

                        const childEl = renderLayer(childLayer, layersMap);
                        if (childEl) innerElement.appendChild(childEl);
                    }
                });
            }
            break;
        default:
            innerElement = document.createElement('div');
            innerElement.textContent = 'Unknown: ' + layer.type;
            innerElement.style.cssText = 'padding: 4px; border: 1px dashed #ccc;';
    }
    
    if (innerElement) wrapper.appendChild(innerElement);
    return wrapper;
}

window.addEventListener('DOMContentLoaded', function() {
    // Dispatch based on Type
    if (config.nudgeType === 'modal' || config.type === 'modal') {
        renderModal();
    } else {
        // Default to BottomSheet
        renderBottomSheet();
    }
});
"""

        return """
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0, minimum-scale=1.0, maximum-scale=1.0, user-scalable=no">
    <style>
        * { margin: 0; padding: 0; box-sizing: border-box; }
        body { 
            width: 100%; height: 100vh; overflow: hidden; 
            -webkit-tap-highlight-color: transparent;
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
            font-size: 16px; 
            line-height: 1.5;
            -webkit-font-smoothing: antialiased;
            color: #111827;
        }
        button { font-family: inherit; line-height: inherit; }
        #root { width: 100%; height: 100%; position: relative; }
        .bottom-sheet {
            position: absolute; left: 0; right: 0; bottom: 0;
            display: flex; flex-direction: column;
            box-shadow: 0 -4px 12px rgba(0,0,0,0.15);
            z-index: 100;
        }
        .content-area { flex: 1; overflow-y: auto; }
    </style>
</head>
<body>
    <div id="root"></div>
    <script>$js</script>
</body>
</html>
        """.trimIndent()
    }
}
