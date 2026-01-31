import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primaryColor: const Color(0xFF087F5B),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF087F5B),
        ),
      ),
      home: const HomeScreen(),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  static const LatLng _center = LatLng(19.0760, 72.8777); // Mumbai

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('EV Charging Finder'),
        backgroundColor: const Color(0xFF087F5B),
      ),
      body: GoogleMap(
        initialCameraPosition: const CameraPosition(
          target: _center,
          zoom: 12,
        ),
        markers: {
          const Marker(
            markerId: MarkerId('mumbai'),
            position: _center,
            infoWindow: InfoWindow(title: 'Mumbai'),
          ),
        },
      ),
    );
  }
}
