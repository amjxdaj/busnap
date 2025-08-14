import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';

class ConnectivityService {
  static final ConnectivityService _instance = ConnectivityService._internal();
  factory ConnectivityService() => _instance;
  ConnectivityService._internal();

  final Connectivity _connectivity = Connectivity();

  /// Check if device has internet connectivity
  Future<bool> hasInternetConnection() async {
    try {
      final connectivityResult = await _connectivity.checkConnectivity();
      return connectivityResult != ConnectivityResult.none;
    } catch (e) {
      return false;
    }
  }

  /// Stream of connectivity changes
  Stream<ConnectivityResult> get connectivityStream =>
      _connectivity.onConnectivityChanged;

  /// Show dialog to user when internet is not available
  Future<void> showNoInternetDialog(BuildContext context) async {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Row(
            children: [
              Icon(Icons.wifi_off, color: Colors.red.shade600, size: 28),
              const SizedBox(width: 12),
              const Text('No Internet Connection'),
            ],
          ),
          content: const Text(
            'This app requires an internet connection to calculate routes and provide real-time updates. Please turn on your internet connection and try again.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.of(context).pop();
                // Try to open WiFi settings
                await _openWifiSettings();
              },
              child: const Text('Open Settings'),
            ),
          ],
        );
      },
    );
  }

  /// Request user to turn on internet
  Future<bool> requestInternetConnection(BuildContext context) async {
    if (!await hasInternetConnection()) {
      // Check if context is still valid before showing dialog
      if (context.mounted) {
        await showNoInternetDialog(context);
      }
      return false;
    }
    return true;
  }

  /// Open WiFi settings (Android only)
  Future<void> _openWifiSettings() async {
    // This would require platform-specific implementation
    // For now, we'll just show a message
    // In a real app, you might want to use url_launcher or similar
  }
}
