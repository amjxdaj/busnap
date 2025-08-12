import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'services/distance_service.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'alarm_settings_screen.dart';
import 'dart:async';
import 'package:audioplayers/audioplayers.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  runApp(const BusnapApp());
}

class BusnapApp extends StatelessWidget {
  const BusnapApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Busnap',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.green,
          primary: Colors.green.shade600,
          secondary: Colors.greenAccent,
          surface: Colors.white,
        ),
        useMaterial3: true,
        fontFamily: 'Roboto',
        scaffoldBackgroundColor: Colors.white,
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,
          elevation: 0,
          centerTitle: true,
          titleTextStyle: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 24,
            color: Colors.black,
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.green.shade600,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            elevation: 0,
            textStyle: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            foregroundColor: Colors.green.shade600,
            side: BorderSide(color: Colors.green.shade600, width: 2),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            textStyle: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.grey.shade100,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
          contentPadding: const EdgeInsets.symmetric(
            vertical: 18,
            horizontal: 20,
          ),
        ),
      ),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage>
    with SingleTickerProviderStateMixin {
  final TextEditingController destinationController = TextEditingController();
  String? latLngResult = '';
  String? liveLatLngResult = '';
  late AnimationController _controller;
  late Animation<double> _animation;
  LatLng? _currentLatLng;
  LatLng? _destinationLatLng;
  Stream<Position>? _positionStream;
  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();
  List<LatLng> _routePolyline = [];
  final Set<int> _alertedThresholds = {};
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _isAlarmPlaying = false;
  String? _customAlarmName;
  Timer? _alarmTimer;
  Timer? _journeyOverviewTimer;
  bool _showJourneyOverview = true;

  // Journey state
  bool _journeyStarted = false;
  Stopwatch? _journeyTimer;
  String _timerDisplay = '';
  double? _lastDistanceToDest;
  LatLng? _lastTrackedLatLng;
  StreamSubscription<Position>? _journeyPositionSub;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _animation = CurvedAnimation(parent: _controller, curve: Curves.easeInOut);
    _controller.forward();
    _startLocationStream();
    _initializeNotifications();
    _loadCustomAlarmInfo();

    // Hide Journey Overview after 45 seconds
    _journeyOverviewTimer = Timer(const Duration(seconds: 45), () {
      setState(() {
        _showJourneyOverview = false;
      });
    });
  }

  void _startLocationStream() async {
    LocationPermission permission = await Geolocator.requestPermission();
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      // Handle permission denied
      return;
    }
    _positionStream = Geolocator.getPositionStream(
      locationSettings: LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10,
      ),
    );
    _positionStream!.listen((Position position) {
      final latLng = LatLng(position.latitude, position.longitude);
      setState(() {
        _currentLatLng = latLng;
      });
    });
  }

  Future<void> _initializeNotifications() async {
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    final InitializationSettings initializationSettings =
        InitializationSettings(
          android: initializationSettingsAndroid,
          iOS: DarwinInitializationSettings(),
        );
    await flutterLocalNotificationsPlugin.initialize(initializationSettings);
  }

  Future<void> _loadCustomAlarmInfo() async {
    final prefs = await SharedPreferences.getInstance();
    final customAlarmName = prefs.getString('alarm_file_name');
    setState(() {
      _customAlarmName = customAlarmName;
    });
  }

  Future<void> _showAlertNotification(int km) async {
    const AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
          'busnap_alerts',
          'Busnap Alerts',
          channelDescription: 'Alerts when you are close to your stop',
          importance: Importance.max,
          priority: Priority.high,
          playSound: true,
          enableVibration: true,
        );
    const NotificationDetails platformChannelSpecifics = NotificationDetails(
      android: androidPlatformChannelSpecifics,
      iOS: DarwinNotificationDetails(presentSound: true),
    );
    await flutterLocalNotificationsPlugin.show(
      km, // unique id per threshold
      km == 1
          ? 'Wake up! You are almost at your stop!'
          : 'Approaching your stop',
      km == 1
          ? 'You are within 1 km of your destination!'
          : 'You are within $km km of your destination.',
      platformChannelSpecifics,
    );

    // Start alarm looping for 1 minute
    _startAlarmLoop();
  }

  Future<void> _startAlarmLoop() async {
    setState(() {
      _isAlarmPlaying = true;
    });

    // Cancel any existing timer
    _alarmTimer?.cancel();

    try {
      // Check if custom alarm is set
      final prefs = await SharedPreferences.getInstance();
      final customAlarmPath = prefs.getString('alarm_file_path');

      // Set up alarm completion listener for looping
      _audioPlayer.onPlayerComplete.listen((_) {
        if (_isAlarmPlaying) {
          // Loop the alarm if still playing
          _playAlarmSound(customAlarmPath);
        }
      });

      // Start playing the alarm
      await _playAlarmSound(customAlarmPath);

      // Set timer to stop after 1 minute
      _alarmTimer = Timer(const Duration(minutes: 1), () {
        if (_isAlarmPlaying) {
          _stopAlarm();
        }
      });
    } catch (e) {
      // Fallback to default alarm if custom alarm fails
      try {
        _audioPlayer.onPlayerComplete.listen((_) {
          if (_isAlarmPlaying) {
            // Loop the default alarm if still playing
            _playAlarmSound(null);
          }
        });

        await _playAlarmSound(null);

        // Set timer to stop after 1 minute
        _alarmTimer = Timer(const Duration(minutes: 1), () {
          if (_isAlarmPlaying) {
            _stopAlarm();
          }
        });
      } catch (fallbackError) {
        setState(() {
          _isAlarmPlaying = false;
        });
      }
    }
  }

  Future<void> _playAlarmSound(String? customAlarmPath) async {
    try {
      if (customAlarmPath != null) {
        // Play custom alarm sound
        await _audioPlayer.play(DeviceFileSource(customAlarmPath));
      } else {
        // Play default alarm sound
        await _audioPlayer.play(AssetSource('alarm.mp3'));
      }
    } catch (e) {
      // If custom alarm fails, try default
      if (customAlarmPath != null) {
        try {
          await _audioPlayer.play(AssetSource('alarm.mp3'));
        } catch (fallbackError) {
          _stopAlarm();
        }
      } else {
        _stopAlarm();
      }
    }
  }

  void _stopAlarm() {
    _audioPlayer.stop();
    _alarmTimer?.cancel();
    setState(() {
      _isAlarmPlaying = false;
    });
  }

  void _startJourneyOverviewTimer() {
    // Cancel any existing timer
    _journeyOverviewTimer?.cancel();

    // Reset the flag to show journey overview
    setState(() {
      _showJourneyOverview = true;
    });

    // Start timer to hide journey overview after 1 minute
    _journeyOverviewTimer = Timer(const Duration(minutes: 1), () {
      if (mounted) {
        setState(() {
          _showJourneyOverview = false;
        });
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    destinationController.dispose();
    _journeyPositionSub?.cancel();
    _audioPlayer.dispose();
    _alarmTimer?.cancel();
    _journeyOverviewTimer?.cancel();
    super.dispose();
  }

  Future<void> convertToCoordinates(String placeName) async {
    try {
      List<Location> locations = await locationFromAddress(placeName);
      if (locations.isNotEmpty) {
        final lat = locations[0].latitude;
        final lng = locations[0].longitude;

        setState(() {
          latLngResult = 'Latitude: $lat, Longitude: $lng';
          _destinationLatLng = LatLng(lat, lng);
        });

        getCurrentLocationAndCompare(lat, lng);
      } else {
        setState(() {
          latLngResult = 'No coordinates found.';
          _destinationLatLng = null;
        });
      }
      if (_destinationLatLng != null) {
        _startJourney();
        _startJourneyOverviewTimer();
      }
    } catch (e) {
      setState(() {
        latLngResult = 'Error: Could not find location.';
        _destinationLatLng = null;
      });
    }
  }

  Future<void> getCurrentLocationAndCompare(
    double destLat,
    double destLng,
  ) async {
    var status = await Permission.location.request();
    if (!status.isGranted) {
      setState(() {
        latLngResult = "Location permission denied";
        _routePolyline = [];
      });
      return;
    }

    Position position = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
    );

    double userLat = position.latitude;
    double userLng = position.longitude;

    final distanceService = DistanceService();
    try {
      final routeData = await distanceService.getRouteData(
        startLat: userLat,
        startLng: userLng,
        endLat: destLat,
        endLng: destLng,
      );
      setState(() {
        latLngResult =
            "\u{1F6A9} Road Distance: ${routeData['distance_km']} km\n\u{23F1} Duration: ${routeData['duration_min']} min";
        _routePolyline = List<LatLng>.from(routeData['route_points']);
        _lastDistanceToDest = double.tryParse(routeData['distance_km']);
      });
      double distanceKm = double.tryParse(routeData['distance_km']) ?? 0;
      for (final threshold in [5, 2, 1]) {
        if (distanceKm <= threshold &&
            !_alertedThresholds.contains(threshold)) {
          debugPrint(
            'Triggering notification for $threshold km, current distance: $distanceKm',
          );
          _showAlertNotification(threshold);
          _alertedThresholds.add(threshold);
        }
      }
    } catch (e) {
      setState(() {
        latLngResult = "Error fetching route data.";
        _routePolyline = [];
      });
    }
  }

  void _startJourney() {
    setState(() {
      _journeyStarted = true;
      _timerDisplay = '00:00:00';
      _journeyTimer = Stopwatch()..start();
      _lastTrackedLatLng = _currentLatLng;
    });
    _startJourneyTimer();
    _startLiveDistanceTracking();
  }

  void _startJourneyTimer() {
    Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!_journeyStarted ||
          _journeyTimer == null ||
          !_journeyTimer!.isRunning) {
        timer.cancel();
        return;
      }
      final elapsed = _journeyTimer!.elapsed;
      setState(() {
        _timerDisplay =
            '${elapsed.inHours.toString().padLeft(2, '0')}:${(elapsed.inMinutes % 60).toString().padLeft(2, '0')}:${(elapsed.inSeconds % 60).toString().padLeft(2, '0')}';
      });
    });
  }

  void _startLiveDistanceTracking() {
    _journeyPositionSub?.cancel();
    _journeyPositionSub =
        Geolocator.getPositionStream(
          locationSettings: LocationSettings(
            accuracy: LocationAccuracy.high,
            distanceFilter: 10,
          ),
        ).listen((Position position) async {
          if (!_journeyStarted) return;
          final latLng = LatLng(position.latitude, position.longitude);
          setState(() {
            _currentLatLng = latLng;
          });
          if (_destinationLatLng != null && _lastTrackedLatLng != null) {
            final kmMoved = const Distance().as(
              LengthUnit.Kilometer,
              _lastTrackedLatLng!,
              latLng,
            );
            if (kmMoved >= 0.1) {
              // 100 metres
              // Update distance to destination
              final distanceService = DistanceService();
              final routeData = await distanceService.getRouteData(
                startLat: latLng.latitude,
                startLng: latLng.longitude,
                endLat: _destinationLatLng!.latitude,
                endLng: _destinationLatLng!.longitude,
              );
              setState(() {
                liveLatLngResult =
                    "${routeData['distance_km']} km | ${routeData['duration_min']} min";
                _routePolyline = List<LatLng>.from(routeData['route_points']);
                _lastDistanceToDest = double.tryParse(routeData['distance_km']);
                _lastTrackedLatLng = latLng;
              });
              // Notification threshold check (5km, 2km, 1km)
              double distanceKm =
                  double.tryParse(routeData['distance_km']) ?? 0;
              for (final threshold in [5, 2, 1]) {
                if (distanceKm <= threshold &&
                    !_alertedThresholds.contains(threshold)) {
                  debugPrint(
                    'Triggering notification for $threshold km, current distance: $distanceKm',
                  );
                  _showAlertNotification(threshold);
                  _alertedThresholds.add(threshold);
                }
              }
            }
          }
        });
  }

  void _stopJourney() {
    setState(() {
      _journeyStarted = false;
      _journeyTimer?.stop();
      _journeyTimer = null;
      _timerDisplay = '';
      _showJourneyOverview =
          true; // Reset to show journey overview when journey ends
    });
    _journeyPositionSub?.cancel();
    _journeyOverviewTimer?.cancel();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.all(4),
              child: Image.asset(
                'assets/logo.png',
                height: 32,
                width: 32,
                fit: BoxFit.contain,
              ),
            ),
            const SizedBox(width: 12),
            const Text('Busnap'),
          ],
        ),
        actions: [
          if (_customAlarmName != null)
            Container(
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.green.shade100,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.green.shade300),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.music_note,
                    color: Colors.green.shade700,
                    size: 16,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Custom',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.green.shade700,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          IconButton(
            icon: const Icon(Icons.settings, color: Colors.black),
            tooltip: 'Alarm Settings',
            onPressed: () async {
              await Navigator.of(context).push(
                MaterialPageRoute(builder: (context) => AlarmSettingsScreen()),
              );
              // Reload custom alarm info when returning from settings
              _loadCustomAlarmInfo();
            },
          ),
        ],
      ),
      body: FadeTransition(
        opacity: _animation,
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  margin: EdgeInsets.zero,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: 32,
                      horizontal: 24,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          'Where do you want to stop?',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w600,
                            color: Colors.black,
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: destinationController,
                          decoration: InputDecoration(
                            hintText: 'Enter destination place name',
                            prefixIcon: Icon(
                              Icons.place,
                              color: Colors.green.shade600,
                            ),
                            suffixIcon: IconButton(
                              icon: const Icon(Icons.search),
                              onPressed: () {
                                FocusScope.of(context).unfocus();
                                String place = destinationController.text;
                                convertToCoordinates(place);
                              },
                            ),
                          ),
                          style: const TextStyle(fontSize: 16),
                          onSubmitted: (value) {
                            FocusScope.of(context).unfocus();
                            convertToCoordinates(value);
                          },
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          icon: const Icon(Icons.flag),
                          label: const Text('Set Destination'),
                          onPressed: () {
                            FocusScope.of(context).unfocus();
                            String place = destinationController.text;
                            convertToCoordinates(place);
                          },
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 600),
                  child: latLngResult != null && latLngResult!.isNotEmpty
                      ? Column(
                          children: [
                            if (_showJourneyOverview)
                              Card(
                                key: ValueKey(latLngResult),
                                elevation: 3,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                margin: EdgeInsets.zero,
                                child: Container(
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(20),
                                    gradient: LinearGradient(
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                      colors: [
                                        Colors.blue.shade50,
                                        Colors.blue.shade100,
                                      ],
                                    ),
                                  ),
                                  child: Padding(
                                    padding: const EdgeInsets.all(24.0),
                                    child: Column(
                                      children: [
                                        Row(
                                          children: [
                                            Container(
                                              padding: const EdgeInsets.all(12),
                                              decoration: BoxDecoration(
                                                color: Colors.blue.shade600,
                                                borderRadius:
                                                    BorderRadius.circular(12),
                                              ),
                                              child: Icon(
                                                FontAwesomeIcons.route,
                                                color: Colors.white,
                                                size: 24,
                                              ),
                                            ),
                                            const SizedBox(width: 16),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    'Journey Overview',
                                                    style: TextStyle(
                                                      fontSize: 18,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      color:
                                                          Colors.blue.shade900,
                                                    ),
                                                  ),
                                                  const SizedBox(height: 4),
                                                  Text(
                                                    'Initial route calculation',
                                                    style: TextStyle(
                                                      fontSize: 14,
                                                      color:
                                                          Colors.blue.shade700,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 20),
                                        Row(
                                          children: [
                                            Expanded(
                                              child: Container(
                                                padding: const EdgeInsets.all(
                                                  16,
                                                ),
                                                decoration: BoxDecoration(
                                                  color: Colors.white
                                                      .withValues(alpha: 0.8),
                                                  borderRadius:
                                                      BorderRadius.circular(12),
                                                  border: Border.all(
                                                    color: Colors.blue.shade200,
                                                    width: 1,
                                                  ),
                                                ),
                                                child: Column(
                                                  children: [
                                                    Icon(
                                                      FontAwesomeIcons.road,
                                                      color:
                                                          Colors.blue.shade600,
                                                      size: 20,
                                                    ),
                                                    const SizedBox(height: 8),
                                                    Text(
                                                      'Distance',
                                                      style: TextStyle(
                                                        fontSize: 12,
                                                        color: Colors
                                                            .blue
                                                            .shade700,
                                                        fontWeight:
                                                            FontWeight.w500,
                                                      ),
                                                    ),
                                                    const SizedBox(height: 4),
                                                    Text(
                                                      latLngResult!.contains(
                                                            'Road Distance:',
                                                          )
                                                          ? '${latLngResult!.split('Road Distance:')[1].split(' km')[0].trim()} km'
                                                          : 'Calculating...',
                                                      style: const TextStyle(
                                                        fontSize: 16,
                                                        fontWeight:
                                                            FontWeight.bold,
                                                        color: Colors.black87,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 12),
                                            Expanded(
                                              child: Container(
                                                padding: const EdgeInsets.all(
                                                  16,
                                                ),
                                                decoration: BoxDecoration(
                                                  color: Colors.white
                                                      .withValues(alpha: 0.8),
                                                  borderRadius:
                                                      BorderRadius.circular(12),
                                                  border: Border.all(
                                                    color: Colors.blue.shade200,
                                                    width: 1,
                                                  ),
                                                ),
                                                child: Column(
                                                  children: [
                                                    Icon(
                                                      FontAwesomeIcons.clock,
                                                      color:
                                                          Colors.blue.shade600,
                                                      size: 20,
                                                    ),
                                                    const SizedBox(height: 8),
                                                    Text(
                                                      'Duration',
                                                      style: TextStyle(
                                                        fontSize: 12,
                                                        color: Colors
                                                            .blue
                                                            .shade700,
                                                        fontWeight:
                                                            FontWeight.w500,
                                                      ),
                                                    ),
                                                    const SizedBox(height: 4),
                                                    Text(
                                                      latLngResult!.contains(
                                                            'Duration:',
                                                          )
                                                          ? '${latLngResult!.split('Duration:')[1].split(' min')[0].trim()} min'
                                                          : 'Calculating...',
                                                      style: const TextStyle(
                                                        fontSize: 16,
                                                        fontWeight:
                                                            FontWeight.bold,
                                                        color: Colors.black87,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            Padding(
                              padding: const EdgeInsets.only(bottom: 12.0),
                              child: Card(
                                key: ValueKey(liveLatLngResult),
                                elevation: 3,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                margin: EdgeInsets.zero,
                                child: Container(
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(20),
                                    gradient: LinearGradient(
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                      colors: [
                                        Colors.green.shade50,
                                        Colors.green.shade100,
                                      ],
                                    ),
                                  ),
                                  child: Padding(
                                    padding: const EdgeInsets.all(24.0),
                                    child: Column(
                                      children: [
                                        Row(
                                          children: [
                                            Container(
                                              padding: const EdgeInsets.all(12),
                                              decoration: BoxDecoration(
                                                color: Colors.green.shade600,
                                                borderRadius:
                                                    BorderRadius.circular(12),
                                              ),
                                              child: Icon(
                                                FontAwesomeIcons.locationArrow,
                                                color: Colors.white,
                                                size: 24,
                                              ),
                                            ),
                                            const SizedBox(width: 16),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    'Live Journey Tracking',
                                                    style: TextStyle(
                                                      fontSize: 18,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      color:
                                                          Colors.green.shade900,
                                                    ),
                                                  ),
                                                  const SizedBox(height: 4),
                                                  Text(
                                                    'Real-time updates',
                                                    style: TextStyle(
                                                      fontSize: 14,
                                                      color:
                                                          Colors.green.shade700,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 20),
                                        Row(
                                          children: [
                                            Expanded(
                                              child: Container(
                                                padding: const EdgeInsets.all(
                                                  16,
                                                ),
                                                decoration: BoxDecoration(
                                                  color: Colors.white
                                                      .withValues(alpha: 0.8),
                                                  borderRadius:
                                                      BorderRadius.circular(12),
                                                  border: Border.all(
                                                    color:
                                                        Colors.green.shade200,
                                                    width: 1,
                                                  ),
                                                ),
                                                child: Column(
                                                  children: [
                                                    Icon(
                                                      FontAwesomeIcons.road,
                                                      color:
                                                          Colors.green.shade600,
                                                      size: 20,
                                                    ),
                                                    const SizedBox(height: 8),
                                                    Text(
                                                      'Remaining',
                                                      style: TextStyle(
                                                        fontSize: 12,
                                                        color: Colors
                                                            .green
                                                            .shade700,
                                                        fontWeight:
                                                            FontWeight.w500,
                                                      ),
                                                    ),
                                                    const SizedBox(height: 4),
                                                    Text(
                                                      '${liveLatLngResult!.split(' km')[0].trim()} km',
                                                      style: const TextStyle(
                                                        fontSize: 16,
                                                        fontWeight:
                                                            FontWeight.bold,
                                                        color: Colors.black87,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 12),
                                            Expanded(
                                              child: Container(
                                                padding: const EdgeInsets.all(
                                                  16,
                                                ),
                                                decoration: BoxDecoration(
                                                  color: Colors.white
                                                      .withValues(alpha: 0.8),
                                                  borderRadius:
                                                      BorderRadius.circular(12),
                                                  border: Border.all(
                                                    color:
                                                        Colors.green.shade200,
                                                    width: 1,
                                                  ),
                                                ),
                                                child: Column(
                                                  children: [
                                                    Icon(
                                                      FontAwesomeIcons.clock,
                                                      color:
                                                          Colors.green.shade600,
                                                      size: 20,
                                                    ),
                                                    const SizedBox(height: 8),
                                                    Text(
                                                      'ETA',
                                                      style: TextStyle(
                                                        fontSize: 12,
                                                        color: Colors
                                                            .green
                                                            .shade700,
                                                        fontWeight:
                                                            FontWeight.w500,
                                                      ),
                                                    ),
                                                    const SizedBox(height: 4),
                                                    Text(
                                                      liveLatLngResult!
                                                              .contains('|')
                                                          ? liveLatLngResult!
                                                                .split('|')[1]
                                                                .trim()
                                                          : 'Calculating...',
                                                      style: const TextStyle(
                                                        fontSize: 16,
                                                        fontWeight:
                                                            FontWeight.bold,
                                                        color: Colors.black87,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            if (!_journeyStarted &&
                                _destinationLatLng != null &&
                                _lastDistanceToDest != null)
                              Column(
                                children: [
                                  Text(
                                    'Alerts at: 5km, 2km, 1km',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey.shade600,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  ElevatedButton.icon(
                                    icon: const Icon(Icons.directions_bus),
                                    label: const Text('Start Journey'),
                                    onPressed: _startJourney,
                                  ),
                                ],
                              ),
                            if (_journeyStarted)
                              Column(
                                children: [
                                  Text(
                                    'Journey Timer: $_timerDisplay',
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.green,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  OutlinedButton.icon(
                                    icon: const Icon(Icons.stop),
                                    label: const Text('Stop Journey'),
                                    onPressed: _stopJourney,
                                  ),
                                  const SizedBox(height: 6),
                                  if (_isAlarmPlaying)
                                    ElevatedButton.icon(
                                      icon: const Icon(Icons.stop),
                                      label: const Text('Stop Alarm'),
                                      onPressed: _stopAlarm,
                                    ),
                                ],
                              ),
                          ],
                        )
                      : const SizedBox.shrink(),
                ),
                const SizedBox(height: 20),
                if (_currentLatLng != null)
                  Card(
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    margin: EdgeInsets.zero,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: SizedBox(
                        height: 240,
                        child: FlutterMap(
                          options: MapOptions(
                            initialCenter: _currentLatLng!,
                            initialZoom: 15.0,
                            maxZoom: 18.0,
                            minZoom: 3.0,
                            interactionOptions: const InteractionOptions(
                              flags: InteractiveFlag.all,
                            ),
                          ),
                          children: [
                            TileLayer(
                              urlTemplate:
                                  'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
                              subdomains: ['a', 'b', 'c'],
                              userAgentPackageName: 'com.example.busnap',
                            ),
                            PolylineLayer(
                              polylines: _routePolyline.isNotEmpty
                                  ? [
                                      Polyline(
                                        points: _routePolyline,
                                        color: Colors.green.shade600,
                                        strokeWidth: 5.0,
                                      ),
                                    ]
                                  : [],
                            ),
                            MarkerLayer(
                              markers: [
                                Marker(
                                  width: 48.0,
                                  height: 48.0,
                                  point: _currentLatLng!,
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: Colors.green.shade600,
                                      shape: BoxShape.circle,
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.green.shade100,
                                          blurRadius: 8,
                                          spreadRadius: 2,
                                        ),
                                      ],
                                    ),
                                    child: const Icon(
                                      Icons.my_location,
                                      color: Colors.white,
                                      size: 28,
                                    ),
                                  ),
                                ),
                                if (_destinationLatLng != null)
                                  Marker(
                                    width: 48.0,
                                    height: 48.0,
                                    point: _destinationLatLng!,
                                    child: Container(
                                      decoration: BoxDecoration(
                                        color: Colors.red.shade600,
                                        shape: BoxShape.circle,
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.red.shade100,
                                            blurRadius: 8,
                                            spreadRadius: 2,
                                          ),
                                        ],
                                      ),
                                      child: const Icon(
                                        Icons.flag,
                                        color: Colors.white,
                                        size: 28,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                const SizedBox(height: 40),
                Center(
                  child: AnimatedContainer(
                    duration: const Duration(seconds: 2),
                    curve: Curves.easeInOut,
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.grey.shade100,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.grey.shade200,
                          blurRadius: 16,
                          spreadRadius: 4,
                        ),
                      ],
                    ),
                    child: Center(
                      child: Icon(
                        FontAwesomeIcons.busSimple,
                        color: Colors.green.shade600,
                        size: 44,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
