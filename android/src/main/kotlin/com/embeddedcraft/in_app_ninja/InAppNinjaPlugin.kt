package com.embeddedcraft.in_app_ninja

import io.flutter.embedding.engine.plugins.FlutterPlugin

class InAppNinjaPlugin : FlutterPlugin {
    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        binding
            .platformViewRegistry
            .registerViewFactory(
                "ninja_native_view",
                NinjaNativeViewFactory(binding.binaryMessenger)
            )
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        // Cleanup if needed
    }
}
