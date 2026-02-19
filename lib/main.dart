import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;


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
  static const String apiKey = "b158c085-25b6-423d-b166-afb61865b11a";
  GoogleMapController? _mapController;
  LatLng? _currentPosition;
  Set<Marker> _markers = {};
  int _selectedIndex = 0;

  final Color primaryGreen = const Color(0xFF12B886);

  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
  }
  Future<void> fetchStations(double lat, double lon) async {
    final url = Uri.parse(
        "https://api.openchargemap.io/v3/poi/"
            "?output=json"
            "&latitude=$lat"
            "&longitude=$lon"
            "&distance=15"
            "&distanceunit=KM"
            "&maxresults=20"
    );

    try {
      final response = await http.get(
        url,
        headers: {
          "X-API-Key": apiKey,
          "User-Agent": "EVChargingFinderApp/1.0 (Flutter)",
        },
      );

      print("STATUS: ${response.statusCode}");

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        print("Stations found: ${data.length}");

        Set<Marker> newMarkers = {};

        for (var station in data) {
          final info = station["AddressInfo"];

          if (info != null &&
              info["Latitude"] != null &&
              info["Longitude"] != null) {

            newMarkers.add(
              Marker(
                markerId: MarkerId(station["ID"].toString()),
                position: LatLng(
                  (info["Latitude"] as num).toDouble(),
                  (info["Longitude"] as num).toDouble(),
                ),
                infoWindow: InfoWindow(
                  title: info["Title"] ?? "Charging Station",
                  snippet: info["AddressLine1"] ?? "",
                ),
              ),
            );
          }
        }

        setState(() {
          _markers = newMarkers;
          print("Markers added: ${_markers.length}");

        });

        if (_mapController != null && newMarkers.isNotEmpty) {
          _mapController!.animateCamera(
            CameraUpdate.newLatLngZoom(
              newMarkers.first.position,
              13,
            ),
          );
        }
      } else {
        print(response.body);
      }
    } catch (e) {
      print("ERROR: $e");
    }
  }

  // Future<void> fetchStations(double lat, double lon) async {
  //
  //   final url = Uri.parse(
  //       "https://api.openchargemap.io/v3/poi/"
  //           "?output=json"
  //           "&latitude=$lat"
  //           "&longitude=$lon"
  //           "&distance=5"
  //           "&distanceunit=KM"
  //           "&maxresults=20"
  //   );
  //
  //   final response = await http.get(
  //     url,
  //     headers: {
  //       "X-API-Key": apiKey,
  //       "Content-Type": "application/json",
  //     },
  //   );
  //
  //   if (response.statusCode == 200) {
  //     final data = jsonDecode(response.body);
  //
  //     Set<Marker> newMarkers = {};
  //
  //     for (var station in data) {
  //       final info = station["AddressInfo"];
  //       if (info != null &&
  //           info["Latitude"] != null &&
  //           info["Longitude"] != null) {
  //
  //         newMarkers.add(
  //           Marker(
  //             markerId: MarkerId(info["Title"] ?? "Station"),
  //             position: LatLng(
  //               info["Latitude"],
  //               info["Longitude"],
  //             ),
  //             infoWindow: InfoWindow(
  //               title: info["Title"] ?? "Charging Station",
  //               snippet: info["AddressLine1"] ?? "No address",
  //             ),
  //             icon: BitmapDescriptor.defaultMarkerWithHue(
  //               BitmapDescriptor.hueGreen,
  //             ),
  //           ),
  //         );
  //       }
  //     }
  //
  //     setState(() {
  //       _markers = newMarkers;
  //     });
  //     print("Stations count: ${data.length}");
  //
  //   }
  // }

  Future<void> _getCurrentLocation() async {
    await Permission.location.request();

    Position position = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );

    setState(() {
      _currentPosition =
          LatLng(position.latitude, position.longitude);
    });

    // 🔥 CALL API HERE
    await fetchStations(position.latitude, position.longitude);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: primaryGreen,
        title: const Text(
          '⚡ EV Charging Finder',
          style: TextStyle(color: Colors.white),
        ),
        elevation: 0,
      ),
      body: _currentPosition == null
          ? const Center(child: CircularProgressIndicator())
          : Stack(
        children: [
          GoogleMap(
            initialCameraPosition: CameraPosition(
              target: _currentPosition!,
              zoom: 15,
            ),
            myLocationEnabled: true,
            myLocationButtonEnabled: true,
            markers: _markers,

            // markers: {

            //   Marker(
            //     markerId: const MarkerId('station1'),
            //     position: LatLng(
            //       _currentPosition!.latitude + 0.002,
            //       _currentPosition!.longitude + 0.002,
            //     ),
            //     icon: BitmapDescriptor.defaultMarkerWithHue(
            //         BitmapDescriptor.hueGreen),
            //     infoWindow: const InfoWindow(
            //       title: "EV Charging Station",
            //     ),
            //   ),
            // },
            onMapCreated: (controller) {
              _mapController = controller;
            },
          ),

          /// 🔍 Dummy Search Bar
          Positioned(
            top: 20,
            left: 16,
            right: 16,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(30),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.15),
                    blurRadius: 8,
                  )
                ],
              ),
              child: const TextField(
                decoration: InputDecoration(
                  hintText: "Search charging stations...",
                  border: InputBorder.none,
                  icon: Icon(Icons.search),
                ),
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        selectedItemColor: primaryGreen,
        onTap: (index) {
          setState(() {
            _selectedIndex = index;
          });
        },
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.map),
            label: 'Map',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.favorite),
            label: 'Favorites',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}
