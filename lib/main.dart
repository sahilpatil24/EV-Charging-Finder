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
import 'services/payment_service.dart';
import 'services/booking_service.dart';
import 'widgets/slot_booking_sheet.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  PaymentService.init();
  runApp(const MyApp());
}

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

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  static const String _ocmApiKey = "b158c085-25b6-423d-b166-afb61865b11a";

  GoogleMapController? _mapController;
  LatLng? _currentPosition;
  Set<Marker> _markers = {};
  int _selectedIndex = 0;

  Map<String, dynamic>? _selectedStation;
  bool _isFavorite = false;
  bool _cardVisible = false;

  late AnimationController _cardAnimController;
  late Animation<Offset> _cardSlide;
  late Animation<double> _cardFade;

  late AnimationController _pulseController;
  late Animation<double> _pulseAnim;

  @override
  void initState() {
    super.initState();

    _cardAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 450),
    );
    _cardSlide = Tween<Offset>(
      begin: const Offset(0, 1.2),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _cardAnimController,
      curve: Curves.easeOutCubic,
    ));
    _cardFade = CurvedAnimation(
      parent: _cardAnimController,
      curve: Curves.easeOut,
    );

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 0.95, end: 1.05).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _getCurrentLocation();
  }

  @override
  void dispose() {
    _cardAnimController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _selectStation(Map<String, dynamic> station) async {
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
      _cardVisible = true;
    });

    _cardAnimController.forward(from: 0);
  }

  void _closeCard() {
    _cardAnimController.reverse().then((_) {
      if (mounted) {
        setState(() {
          _selectedStation = null;
          _cardVisible = false;
        });
      }
    });
  }

  Future<void> fetchStations(double lat, double lon) async {
    final url = Uri.parse(
      "https://api.openchargemap.io/v3/poi/"
          "?output=json"
          "&latitude=$lat"
          "&longitude=$lon"
          "&distance=1500"
          "&distanceunit=KM"
          "&maxresults=20",
    );

    try {
      final response = await http.get(url, headers: {
        "X-API-Key": _ocmApiKey,
        "User-Agent": "EVChargingFinderApp/1.0",
      });

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
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
                icon: BitmapDescriptor.defaultMarkerWithHue(
                    BitmapDescriptor.hueGreen),
                onTap: () => _selectStation(station),
              ),
            );
          }
        }

        setState(() => _markers = newMarkers);

        if (_mapController != null && newMarkers.isNotEmpty) {
          _mapController!.animateCamera(
            CameraUpdate.newLatLngZoom(newMarkers.first.position, 13),
          );
        }
      }
    } catch (e) {
      debugPrint("Fetch error: $e");
    }
  }

  Future<void> _getCurrentLocation() async {
    await Permission.location.request();
    final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high);
    setState(() {
      _currentPosition = LatLng(position.latitude, position.longitude);
    });
    await fetchStations(position.latitude, position.longitude);
  }

  Future<void> _toggleFavorite() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || _selectedStation == null) return;

    final info = _selectedStation!["AddressInfo"];
    final connections = _selectedStation!["Connections"];
    String connector = "Unknown", power = "Unknown";
    if (connections != null && (connections as List).isNotEmpty) {
      connector = connections[0]["ConnectionType"]?["Title"] ?? "Unknown";
      power = connections[0]["PowerKW"]?.toString() ?? "Unknown";
    }

    final ref = FirebaseFirestore.instance
        .collection("users")
        .doc(user.uid)
        .collection("favorites")
        .doc(_selectedStation!["ID"].toString());

    if (_isFavorite) {
      await ref.delete();
      setState(() => _isFavorite = false);
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text("Removed from Favorites")));
      }
    } else {
      await ref.set({
        "title": info["Title"],
        "address": info["AddressLine1"],
        "latitude": info["Latitude"],
        "longitude": info["Longitude"],
        "connector": connector,
        "power": power,
        "createdAt": FieldValue.serverTimestamp(),
      });
      setState(() => _isFavorite = true);
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text("Added to Favorites ❤️")));
      }
    }
  }

  // ── THE FIXED BOOKING FLOW ─────────────────────────────────────────────────
  // Stage 1: init happens INSIDE the sheet (backend call + Stripe init)
  // Stage 2: sheet closes itself
  // Stage 3: onReadyToPay fires from HomeScreen (root context) → presentSheet()
  // Stage 4: Firestore write
  // Stage 5: confirmation screen
  // ──────────────────────────────────────────────────────────────────────────
  Future<void> _openBookingSheet() async {
    if (_selectedStation == null) return;

    final stationId = await BookingService.ensureStation(_selectedStation!);
    if (!mounted) return;

    // Keep a local copy — _selectedStation may change if user taps elsewhere
    final station = _selectedStation!;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.4,
        maxChildSize: 0.92,
        expand: false,
        builder: (_, __) => SlotBookingSheet(
          station: station,
          stationId: stationId,
          onReadyToPay: ({
            required String paymentIntentId,
            required String stationTitle,
            required String slotId,
            required int slotNumber,
            required double pricePerHour,
            required int durationHours,
          }) async {
            // Wait for bottom sheet dismiss animation to fully complete
            // before Stripe tries to present its native Activity on Android
            await Future.delayed(const Duration(milliseconds: 600));
            if (!mounted) return;

            debugPrint('💳 Presenting Stripe payment sheet...');
            // Stage 3 — Stripe sheet on root navigator (bottom sheet is gone)
            final paid = await PaymentService.presentSheet();
            debugPrint('💳 presentSheet returned: paid=$paid');
            if (!paid) return;

            // Stage 4 — Firestore
            await BookingService.bookSlot(
              stationId: stationId,
              stationTitle: stationTitle,
              slotId: slotId,
              slotNumber: slotNumber,
              pricePerHour: pricePerHour,
              durationHours: durationHours,
              paymentIntentId: paymentIntentId,
            );

            if (!mounted) return;

            // Stage 5 — confirmation screen
            await Navigator.of(context).push(
              PageRouteBuilder(
                opaque: false,
                barrierColor: Colors.black87,
                pageBuilder: (_, __, ___) => BookingConfirmationScreen(
                  stationTitle: stationTitle,
                  slotNumber: slotNumber,
                  duration: durationHours,
                  totalAmount: pricePerHour * durationHours,
                ),
                transitionsBuilder: (_, anim, __, child) =>
                    FadeTransition(opacity: anim, child: child),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildStationCard() {
    final info = _selectedStation!["AddressInfo"];
    final connections = _selectedStation!["Connections"];
    String connector = "Unknown", power = "Unknown";
    if (connections != null && (connections as List).isNotEmpty) {
      connector = connections[0]["ConnectionType"]?["Title"] ?? "Unknown";
      power = connections[0]["PowerKW"]?.toString() ?? "Unknown";
    }

    return SlideTransition(
      position: _cardSlide,
      child: FadeTransition(
        opacity: _cardFade,
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: const Color(0xFF0F172A),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
                color: const Color(0xFF00C853).withOpacity(0.25)),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF00C853).withOpacity(0.08),
                blurRadius: 24,
                spreadRadius: 2,
              ),
              BoxShadow(
                color: Colors.black.withOpacity(0.4),
                blurRadius: 16,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                height: 4,
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF00C853), Color(0xFF12B886)],
                  ),
                  borderRadius:
                  BorderRadius.vertical(top: Radius.circular(20)),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        ScaleTransition(
                          scale: _pulseAnim,
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: const Color(0xFF00C853).withOpacity(0.15),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(Icons.ev_station,
                                color: Color(0xFF00C853), size: 20),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            info["Title"] ?? "Charging Station",
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        IconButton(
                          onPressed: _closeCard,
                          icon: const Icon(Icons.close,
                              color: Colors.white54, size: 20),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        _InfoChip(
                            icon: Icons.cable_rounded, label: connector),
                        const SizedBox(width: 8),
                        _InfoChip(
                          icon: Icons.bolt_rounded,
                          label: "$power kW",
                          color: const Color(0xFFFFD600),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: _ActionButton(
                            icon: _isFavorite
                                ? Icons.favorite_rounded
                                : Icons.favorite_border_rounded,
                            label: _isFavorite ? "Saved" : "Save",
                            color: _isFavorite
                                ? Colors.redAccent
                                : Colors.white70,
                            onTap: _toggleFavorite,
                            filled: false,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          flex: 2,
                          child: _ActionButton(
                            icon: Icons.calendar_month_rounded,
                            label: "Book a Slot",
                            color: Colors.black,
                            onTap: _openBookingSheet,
                            filled: true,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: const Color(0xFF00C853).withOpacity(0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.electric_bolt,
                  color: Color(0xFF00C853), size: 18),
            ),
            const SizedBox(width: 8),
            const Text(
              "EV Finder",
              style: TextStyle(
                  color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.white70),
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
              if (mounted) {
                Navigator.pushReplacement(context,
                    MaterialPageRoute(builder: (_) => const LoginScreen()));
              }
            },
          ),
        ],
      ),
      body: _currentPosition == null
          ? const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: Color(0xFF00C853)),
            SizedBox(height: 16),
            Text("Finding nearby stations…",
                style: TextStyle(color: Colors.white54)),
          ],
        ),
      )
          : Stack(
        children: [
          GoogleMap(
            initialCameraPosition: CameraPosition(
              target: _currentPosition!,
              zoom: 15,
            ),
            myLocationEnabled: true,
            myLocationButtonEnabled: false,
            markers: _markers,
            onMapCreated: (c) => _mapController = c,
            onTap: (_) {
              if (_cardVisible) _closeCard();
            },
          ),
          Positioned(
            top: kToolbarHeight +
                MediaQuery.of(context).padding.top +
                8,
            left: 16,
            right: 16,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: const Color(0xFF0F172A).withOpacity(0.92),
                borderRadius: BorderRadius.circular(30),
                border: Border.all(color: Colors.white10),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Theme(
                data: Theme.of(context).copyWith(
                  inputDecorationTheme:
                  const InputDecorationTheme(filled: false),
                ),
                child: const TextField(
                  style: TextStyle(color: Colors.white),
                  cursorColor: Color(0xFF00C853),
                  decoration: InputDecoration(
                    hintText: "Search charging stations…",
                    hintStyle: TextStyle(
                        color: Colors.white38, fontSize: 14),
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    icon: Icon(Icons.search,
                        color: Color(0xFF00C853), size: 20),
                    isDense: true,
                    contentPadding:
                    EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            bottom: _cardVisible ? 200 : 100,
            right: 16,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              child: FloatingActionButton.small(
                backgroundColor: const Color(0xFF1E293B),
                onPressed: () {
                  if (_currentPosition != null) {
                    _mapController?.animateCamera(
                      CameraUpdate.newLatLngZoom(
                          _currentPosition!, 15),
                    );
                  }
                },
                child: const Icon(Icons.my_location,
                    color: Color(0xFF00C853)),
              ),
            ),
          ),
          if (_cardVisible && _selectedStation != null)
            Positioned(
              bottom: 20,
              left: 0,
              right: 0,
              child: _buildStationCard(),
            ),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        backgroundColor: const Color(0xFF0F172A),
        indicatorColor: const Color(0xFF00C853).withOpacity(0.2),
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) {
          setState(() => _selectedIndex = index);
          if (index == 1) {
            Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => const FavoritesScreen()));
          } else if (index == 2) {
            Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => const ProfileScreen()));
          }
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.map_outlined, color: Colors.white54),
            selectedIcon:
            Icon(Icons.map, color: Color(0xFF00C853)),
            label: 'Map',
          ),
          NavigationDestination(
            icon: Icon(Icons.favorite_border_rounded,
                color: Colors.white54),
            selectedIcon: Icon(Icons.favorite_rounded,
                color: Color(0xFF00C853)),
            label: 'Favorites',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline_rounded,
                color: Colors.white54),
            selectedIcon: Icon(Icons.person_rounded,
                color: Color(0xFF00C853)),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _InfoChip({
    required this.icon,
    required this.label,
    this.color = const Color(0xFF00C853),
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 13),
          const SizedBox(width: 5),
          Text(label,
              style: TextStyle(
                  color: color,
                  fontSize: 12,
                  fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  final bool filled;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
    required this.filled,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 11),
        decoration: BoxDecoration(
          color: filled
              ? const Color(0xFF00C853)
              : const Color(0xFF1E293B),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: filled ? Colors.transparent : Colors.white12,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 6),
            Text(label,
                style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.w600,
                    fontSize: 13)),
          ],
        ),
      ),
    );
  }
}