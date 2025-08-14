package com.example.busnap

import android.content.Intent
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.example.busnap/location_service"
    private val EVENT_CHANNEL = "com.example.busnap/location_events"
    
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        // Method channel for controlling the background service
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "startBackgroundTracking" -> {
                    val intent = Intent(this, LocationBackgroundService::class.java).apply {
                        action = "START_TRACKING"
                    }
                    startService(intent)
                    result.success(true)
                }
                "stopBackgroundTracking" -> {
                    val intent = Intent(this, LocationBackgroundService::class.java).apply {
                        action = "STOP_TRACKING"
                    }
                    startService(intent)
                    result.success(true)
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
        
        // Event channel for receiving location updates from the background service
        EventChannel(flutterEngine.dartExecutor.binaryMessenger, EVENT_CHANNEL).setStreamHandler(
            object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    LocationBackgroundService.eventSink = events
                }
                
                override fun onCancel(arguments: Any?) {
                    LocationBackgroundService.eventSink = null
                }
            }
        )
    }
}
