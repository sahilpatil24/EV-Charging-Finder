import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';
import 'screens/login_screen.dart';
import 'screens/favorites_screen.dart';
import 'screens/profile_screen.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(const MyApp());
}

//
// class MyApp extends StatelessWidget {
//   const MyApp({super.key});
//
//   @override
//   Widget build(BuildContext context) {
//     return MaterialApp(
//       debugShowCheckedModeBanner: false,
//       theme: ThemeData(
//         primaryColor: const Color(0xFF087F5B),
//         colorScheme: ColorScheme.fromSeed(
//           seedColor: const Color(0xFF087F5B),
//         ),
//       ),
//       home: const LoginScreen(),
//     );
//   }
// }

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFF0F172A),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF00C853),
          brightness: Brightness.dark,
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color(0xFF1E293B),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide.none,
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF00C853),
            foregroundColor: Colors.black,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
        ),
      ),
      home: const LoginScreen(),
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
  List<Map<String, dynamic>> _favoriteStations = [];
  bool _isFavorite = false;
  GoogleMapController? _mapController;
  LatLng? _currentPosition;
  Set<Marker> _markers = {};
  int _selectedIndex = 0;

  //store selected station
  Map<String, dynamic>? _selectedStation;

  void _selectStation(Map<String, dynamic> station) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final doc = await FirebaseFirestore.instance
        .collection("users")
        .doc(user.uid)
        .collection("favorites")
        .doc(station["ID"].toString())
        .get();

    setState(() {
      _selectedStation = station;
      _isFavorite = doc.exists;
    });
  }


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
            "&distance=1500"
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

            // newMarkers.add(
            //   Marker(
            //     markerId: MarkerId(station["ID"].toString()),
            //     position: LatLng(
            //       (info["Latitude"] as num).toDouble(),
            //       (info["Longitude"] as num).toDouble(),
            //     ),
            //     infoWindow: InfoWindow(
            //       title: info["Title"] ?? "Charging Station",
            //       snippet: info["AddressLine1"] ?? "",
            //     ),
            //   ),
            // );
            newMarkers.add(
              Marker(
                markerId: MarkerId(station["ID"].toString()),
                position: LatLng(
                  (info["Latitude"] as num).toDouble(),
                  (info["Longitude"] as num).toDouble(),
                ),
                icon: BitmapDescriptor.defaultMarkerWithHue(
                  BitmapDescriptor.hueGreen,
                ),
                onTap: () {
                  _selectStation(station);
                },
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

  //station bottom card ui
  Widget _buildStationCard() {
    final info = _selectedStation!["AddressInfo"];
    final connections = _selectedStation!["Connections"];

    String connector = "Unknown";
    String power = "Unknown";

    if (connections != null && connections.isNotEmpty) {
      connector = connections[0]["ConnectionType"]?["Title"] ?? "Unknown";
      power = connections[0]["PowerKW"]?.toString() ?? "Unknown";
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 10,
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            info["Title"] ?? "Charging Station",
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text("Connector: $connector"),
          Text("Power: $power kW"),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [

              // ❤️ Add to Favorites
              ElevatedButton.icon(
                onPressed: _isFavorite
                    ? null
                    : () async {
                  final user = FirebaseAuth.instance.currentUser;
                  if (user == null) return;

                  final info = _selectedStation!["AddressInfo"];
                  final connections = _selectedStation!["Connections"];

                  String connector = "Unknown";
                  String power = "Unknown";

                  if (connections != null && connections.isNotEmpty) {
                    connector =
                        connections[0]["ConnectionType"]?["Title"] ?? "Unknown";
                    power = connections[0]["PowerKW"]?.toString() ?? "Unknown";
                  }

                  await FirebaseFirestore.instance
                      .collection("users")
                      .doc(user.uid)
                      .collection("favorites")
                      .doc(_selectedStation!["ID"].toString())
                      .set({
                    "title": info["Title"],
                    "address": info["AddressLine1"],
                    "latitude": info["Latitude"],
                    "longitude": info["Longitude"],
                    "connector": connector,
                    "power": power,
                    "createdAt": FieldValue.serverTimestamp(),
                  });

                  setState(() {
                    _isFavorite = true;
                  });

                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text("Added to Favorites ❤️"),
                    ),
                  );
                },
                icon: Icon(
                  _isFavorite ? Icons.favorite : Icons.favorite_border,
                ),
                label: Text(
                  _isFavorite ? "Added" : "Add to Favourites",
                ),
              ),

              // ❌ Close card
              IconButton(
                onPressed: () {
                  setState(() {
                    _selectedStation = null;
                  });
                },
                icon: const Icon(Icons.close),
              ),
            ],
          )
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // appBar: AppBar(
      //   backgroundColor: primaryGreen,
      //   title: const Text(
      //     '⚡ EV Charging Finder',
      //     style: TextStyle(color: Colors.white),
      //   ),
      //   elevation: 0,
      // ),
      appBar: AppBar(
        title: const Text("EV Charging Finder"),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (_) => const LoginScreen()),
              );
            },
          ),
        ],
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

          if (_selectedStation != null)
            Positioned(
              bottom: 20,
              left: 16,
              right: 16,
              child: _buildStationCard(),
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

                // 🔽 Remove this if you don’t like the shadow
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.15),
                    blurRadius: 15,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: Theme(
                data: Theme.of(context).copyWith(
                  inputDecorationTheme: const InputDecorationTheme(
                    filled: false,
                  ),
                ),
                child: const TextField(
                  style: TextStyle(color: Colors.black),
                  cursorColor: Colors.green,
                  decoration: InputDecoration(
                    hintText: "Search charging stations...",
                    hintStyle: TextStyle(color: Colors.grey),
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    icon: Icon(Icons.search, color: Colors.grey),
                    isDense: true,
                  ),
                ),
              ),
            ),
          )
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        selectedItemColor: primaryGreen,
        onTap: (index) {
          if (index == 1) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const FavoritesScreen(),
              ),
            );
          } else if (index == 2) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const ProfileScreen(),
              ),
            );
          }
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
