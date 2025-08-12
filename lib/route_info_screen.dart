import 'package:flutter/material.dart';
import 'services/distance_service.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

class RouteInfoScreen extends StatefulWidget {
  const RouteInfoScreen({super.key});

  @override
  RouteInfoScreenState createState() => RouteInfoScreenState();
}

class RouteInfoScreenState extends State<RouteInfoScreen> {
  String distance = "";
  String duration = "";

  @override
  void initState() {
    super.initState();
    fetchRouteInfo();
  }

  Future<void> fetchRouteInfo() async {
    final service = DistanceService();

    try {
      final result = await service.getRouteData(
        startLat: 11.2270917,
        startLng: 75.7967367,
        endLat: 11.1337937,
        endLng: 76.0349269,
      );
      setState(() {
        distance = "${result['distance_km']} km";
        duration = "${result['duration_min']} min";
      });
    } catch (e) {
      setState(() {
        distance = "Error";
        duration = "Error";
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.all(8),
              child: Icon(
                FontAwesomeIcons.route,
                color: Colors.green.shade600,
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            const Text("Route Info"),
          ],
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
        child: Center(
          child: Card(
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Icon(
                    FontAwesomeIcons.route,
                    color: Colors.green.shade600,
                    size: 40,
                  ),
                  const SizedBox(height: 24),
                  Text(
                    "Road Distance",
                    style: TextStyle(
                      fontSize: 18,
                      color: Colors.grey.shade700,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    distance,
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    "Estimated Duration",
                    style: TextStyle(
                      fontSize: 18,
                      color: Colors.grey.shade700,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    duration,
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
