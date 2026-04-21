import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';
import 'screens/login_screen.dart';
import 'screens/favorites_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/my_bookings_screen.dart';
import 'screens/alerts_screen.dart';
import 'screens/request_station_screen.dart';
import 'screens/admin_dashboard_screen.dart';
import 'screens/station_reviews_screen.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'services/payment_service.dart';
import 'services/booking_service.dart';
import 'services/places_service.dart';
import 'widgets/slot_booking_sheet.dart';
import 'widgets/nearby_places_widget.dart';

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

// ─────────────────────────────────────────────────────────────────────────────
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  static const String _ocmApiKey = "b158c085-25b6-423d-b166-afb61865b11a";

  GoogleMapController? _mapController;
  LatLng? _currentPosition;
  // Full list of all stations — used for search filtering
  List<Map<String, dynamic>> _allOcmStations = [];
  List<Map<String, dynamic>> _allManualStations = [];
  Set<Marker> _markers = {};
  int _selectedIndex = 0;
  bool _isAdmin = false;

  Map<String, dynamic>? _selectedStation;
  bool _isFavorite = false;

  int _unreadAlerts = 0;

  // Search
  final TextEditingController _searchCtrl = TextEditingController();
  String _searchQuery = '';

  Future<List<NearbyPlace>>? _placesFuture;

  late AnimationController _pulseController;
  late Animation<double> _pulseAnim;

  final DraggableScrollableController _sheetController =
  DraggableScrollableController();
  bool _sheetVisible = false;

  @override
  void initState() {
    super.initState();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 0.92, end: 1.08).animate(
        CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut));

    _searchCtrl.addListener(_onSearchChanged);
    _getCurrentLocation();
    _checkAdminStatus();
    _listenAlertCount();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _sheetController.dispose();
    _searchCtrl.removeListener(_onSearchChanged);
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _checkAdminStatus() async {
    final admin = await BookingService.isAdmin();
    if (mounted) setState(() => _isAdmin = admin);
  }

  void _listenAlertCount() {
    FirebaseFirestore.instance
        .collection('alerts')
        .where('isActive', isEqualTo: true)
        .snapshots()
        .listen((snap) {
      if (mounted) setState(() => _unreadAlerts = snap.docs.length);
    });
  }

  // ── Search logic ───────────────────────────────────────────────────────────
  void _onSearchChanged() {
    setState(() => _searchQuery = _searchCtrl.text.trim().toLowerCase());
    _rebuildMarkers();
  }

  void _rebuildMarkers() {
    final Set<Marker> newMarkers = {};
    final query = _searchQuery;

    for (final station in _allOcmStations) {
      final info = station["AddressInfo"] as Map?;
      if (info == null) continue;
      final title = (info["Title"] as String? ?? '').toLowerCase();
      final address = (info["AddressLine1"] as String? ?? '').toLowerCase();
      if (query.isNotEmpty &&
          !title.contains(query) &&
          !address.contains(query)) continue;

      final lat = (info["Latitude"] as num?)?.toDouble();
      final lng = (info["Longitude"] as num?)?.toDouble();
      if (lat == null || lng == null) continue;

      newMarkers.add(Marker(
        markerId: MarkerId(station["ID"].toString()),
        position: LatLng(lat, lng),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
        onTap: () => _selectStation(station),
      ));
    }

    for (final d in _allManualStations) {
      final title = (d['title'] as String? ?? '').toLowerCase();
      final address = (d['address'] as String? ?? '').toLowerCase();
      if (query.isNotEmpty &&
          !title.contains(query) &&
          !address.contains(query)) continue;

      final mlat = (d['latitude'] as num?)?.toDouble();
      final mlng = (d['longitude'] as num?)?.toDouble();
      if (mlat == null || mlng == null) continue;

      newMarkers.add(Marker(
        markerId: MarkerId('manual_${d['_docId']}'),
        position: LatLng(mlat, mlng),
        // Sky blue for manually added stations
        icon: BitmapDescriptor.defaultMarkerWithHue(198),
        onTap: () => _selectManualStation(d['_docId'] as String, d),
      ));
    }

    setState(() => _markers = newMarkers);

    // If only 1 result, pan to it
    if (newMarkers.length == 1 && _mapController != null) {
      _mapController!.animateCamera(
          CameraUpdate.newLatLngZoom(newMarkers.first.position, 15));
    }
  }

  // ── Station selection ──────────────────────────────────────────────────────
  Future<void> _selectStation(Map<String, dynamic> station) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final doc = await FirebaseFirestore.instance
        .collection("users")
        .doc(user.uid)
        .collection("favorites")
        .doc(station["ID"].toString())
        .get();

    final info = station["AddressInfo"];
    final lat = (info["Latitude"] as num?)?.toDouble();
    final lng = (info["Longitude"] as num?)?.toDouble();

    setState(() {
      _selectedStation = station;
      _isFavorite = doc.exists;
      _sheetVisible = true;
      _placesFuture = (lat != null && lng != null)
          ? PlacesService.fetchNearby(lat: lat, lng: lng)
          : Future.value([]);
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_sheetController.isAttached) {
        _sheetController.animateTo(
          0.38,
          duration: const Duration(milliseconds: 380),
          curve: Curves.easeOutCubic,
        );
      }
    });
  }

  void _closeSheet() {
    if (_sheetController.isAttached) {
      _sheetController
          .animateTo(0.0,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInCubic)
          .then((_) {
        if (mounted) {
          setState(() {
            _selectedStation = null;
            _sheetVisible = false;
            _placesFuture = null;
          });
        }
      });
    } else {
      setState(() {
        _selectedStation = null;
        _sheetVisible = false;
        _placesFuture = null;
      });
    }
  }

  void _selectManualStation(String docId, Map<String, dynamic> d) {
    final synthetic = {
      'ID': docId,
      'AddressInfo': {
        'Title': d['title'],
        'AddressLine1': d['address'],
        'Latitude': d['latitude'],
        'Longitude': d['longitude'],
      },
      'Connections': [
        {
          'ConnectionType': {'Title': d['connectorType'] ?? 'Unknown'},
          'PowerKW': d['powerKW'] ?? 'Unknown',
        }
      ],
      '_isManual': true,
    };
    _selectStation(synthetic);
  }

  // ── Fetch stations ─────────────────────────────────────────────────────────
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
        final data = jsonDecode(response.body) as List;
        _allOcmStations = data.cast<Map<String, dynamic>>();
      }
    } catch (e) {
      debugPrint("OCM Fetch error: $e");
    }

    // Fetch ALL Firestore stations (both manually added and admin-approved)
    // FIX: Do NOT filter by isManuallyAdded — also fetch approved request stations
    // which may not have that field set. Fetch all docs with lat/lng fields.
    try {
      final manualSnap = await FirebaseFirestore.instance
          .collection('stations')
          .get();

      _allManualStations = [];
      for (final doc in manualSnap.docs) {
        final d = doc.data();
        // Skip OCM-mirrored stations (they have numeric IDs matching OCM)
        // We show them if they have a title and coords but skip ones already
        // covered by OCM by checking if the doc ID is a pure number
        final docId = doc.id;
        final isNumericId = int.tryParse(docId) != null;
        if (isNumericId) continue; // already shown via OCM

        final mlat = (d['latitude'] as num?)?.toDouble();
        final mlng = (d['longitude'] as num?)?.toDouble();
        if (mlat == null || mlng == null) continue;

        _allManualStations.add({
          ...d,
          '_docId': docId,
        });
      }
    } catch (e) {
      debugPrint("Firestore stations fetch error: $e");
    }

    _rebuildMarkers();

    if (_mapController != null && _markers.isNotEmpty) {
      _mapController!.animateCamera(
          CameraUpdate.newLatLngZoom(_markers.first.position, 13));
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

  // ── Favourite toggle ───────────────────────────────────────────────────────
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
      if (mounted) {
        setState(() => _isFavorite = false);
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Removed from Favorites")));
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
      if (mounted) {
        setState(() => _isFavorite = true);
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Added to Favorites ❤️")));
      }
    }
  }

  // ── Navigate ────────────────────────────────────────────────────────────────
  Future<void> _navigateToStation() async {
    if (_selectedStation == null) return;
    final info = _selectedStation!["AddressInfo"];
    final lat = (info["Latitude"] as num?)?.toDouble();
    final lng = (info["Longitude"] as num?)?.toDouble();
    if (lat == null || lng == null) return;

    final gmapsUri = Uri.parse(
        'https://www.google.com/maps/dir/?api=1&destination=$lat,$lng&travelmode=driving');

    if (await canLaunchUrl(gmapsUri)) {
      await launchUrl(gmapsUri, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Could not open Maps')));
      }
    }
  }

  // ── Booking sheet ──────────────────────────────────────────────────────────
  Future<void> _openBookingSheet() async {
    if (_selectedStation == null) return;

    final stationId = await BookingService.ensureStation(_selectedStation!);
    if (!mounted) return;

    final station = _selectedStation!;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.65,
        minChildSize: 0.4,
        maxChildSize: 0.95,
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
            required DateTime scheduledStart,
          }) async {
            await Future.delayed(const Duration(milliseconds: 600));
            if (!mounted) return;

            final paid = await PaymentService.presentSheet();
            if (!paid) return;

            await BookingService.bookSlot(
              stationId: stationId,
              stationTitle: stationTitle,
              slotId: slotId,
              slotNumber: slotNumber,
              pricePerHour: pricePerHour,
              durationHours: durationHours,
              paymentIntentId: paymentIntentId,
              scheduledStart: scheduledStart,
            );

            if (!mounted) return;

            await Navigator.of(context).push(PageRouteBuilder(
              opaque: false,
              barrierColor: Colors.black87,
              pageBuilder: (_, __, ___) => BookingConfirmationScreen(
                stationTitle: stationTitle,
                slotNumber: slotNumber,
                duration: durationHours,
                totalAmount: pricePerHour * durationHours,
                scheduledStart: scheduledStart,
              ),
              transitionsBuilder: (_, anim, __, child) =>
                  FadeTransition(opacity: anim, child: child),
            ));
          },
        ),
      ),
    );
  }

  // ── BUILD ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            // FIX 4: dark gradient so icons/title are always visible over map
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color(0xDD0F172A), // ~87% opacity
                Color(0x880F172A), // ~53% opacity
                Colors.transparent,
              ],
              stops: [0.0, 0.65, 1.0],
            ),
          ),
        ),
        title: Row(children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: const Color(0xFF00C853).withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
              border:
              Border.all(color: const Color(0xFF00C853).withOpacity(0.3)),
            ),
            child: const Icon(Icons.electric_bolt,
                color: Color(0xFF00C853), size: 18),
          ),
          const SizedBox(width: 8),
          const Text("EV Finder",
              style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  shadows: [
                    Shadow(color: Colors.black54, blurRadius: 4)
                  ])),
        ]),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_location_alt_rounded),
            color: Colors.white,
            tooltip: 'Request a Station',
            onPressed: () => Navigator.push(context,
                MaterialPageRoute(
                    builder: (_) => const RequestStationScreen())),
          ),
          if (_isAdmin)
            IconButton(
              icon: const Icon(Icons.admin_panel_settings_rounded,
                  color: Color(0xFF00C853)),
              tooltip: 'Admin Dashboard',
              onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const AdminDashboardScreen())),
            ),
          IconButton(
            icon: const Icon(Icons.logout),
            color: Colors.white,
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
          // ── Map ──────────────────────────────────────────────────────
          GoogleMap(
            initialCameraPosition:
            CameraPosition(target: _currentPosition!, zoom: 15),
            myLocationEnabled: true,
            myLocationButtonEnabled: false,
            markers: _markers,
            onMapCreated: (c) => _mapController = c,
            onTap: (_) {
              if (_sheetVisible) _closeSheet();
            },
          ),

          // ── Search bar (dynamic) ─────────────────────────────────────
          Positioned(
            top: kToolbarHeight +
                MediaQuery.of(context).padding.top +
                8,
            left: 16,
            right: 16,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: const Color(0xFF0F172A).withOpacity(0.95),
                borderRadius: BorderRadius.circular(30),
                border: Border.all(color: Colors.white12),
                boxShadow: [
                  BoxShadow(
                      color: Colors.black.withOpacity(0.35),
                      blurRadius: 14,
                      offset: const Offset(0, 4)),
                ],
              ),
              child: Theme(
                data: Theme.of(context).copyWith(
                    inputDecorationTheme: const InputDecorationTheme(
                        filled: false)),
                child: TextField(
                  controller: _searchCtrl,
                  style: const TextStyle(color: Colors.white),
                  cursorColor: const Color(0xFF00C853),
                  decoration: InputDecoration(
                    hintText: "Search charging stations…",
                    hintStyle: const TextStyle(
                        color: Colors.white38, fontSize: 14),
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    icon: const Icon(Icons.search,
                        color: Color(0xFF00C853), size: 20),
                    isDense: true,
                    contentPadding:
                    const EdgeInsets.symmetric(vertical: 14),
                    // Clear button when typing
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                      icon: const Icon(Icons.clear,
                          color: Colors.white38, size: 18),
                      onPressed: () {
                        _searchCtrl.clear();
                      },
                    )
                        : null,
                  ),
                ),
              ),
            ),
          ),

          // ── Search results count overlay ─────────────────────────────
          if (_searchQuery.isNotEmpty)
            Positioned(
              top: kToolbarHeight +
                  MediaQuery.of(context).padding.top +
                  62,
              left: 20,
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E293B),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                      color: const Color(0xFF00C853).withOpacity(0.3)),
                ),
                child: Text(
                  '${_markers.length} result${_markers.length != 1 ? 's' : ''}',
                  style: const TextStyle(
                      color: Color(0xFF00C853),
                      fontSize: 11,
                      fontWeight: FontWeight.w600),
                ),
              ),
            ),

          // ── My Location FAB ──────────────────────────────────────────
          Positioned(
            bottom: _sheetVisible ? 240 : 100,
            right: 16,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              child: FloatingActionButton.small(
                backgroundColor: const Color(0xFF1E293B),
                onPressed: () {
                  if (_currentPosition != null) {
                    _mapController?.animateCamera(
                        CameraUpdate.newLatLngZoom(
                            _currentPosition!, 15));
                  }
                },
                child: const Icon(Icons.my_location,
                    color: Color(0xFF00C853)),
              ),
            ),
          ),

          // ── Swipeable Station Sheet ──────────────────────────────────
          if (_sheetVisible && _selectedStation != null)
            _StationBottomSheet(
              station: _selectedStation!,
              isFavorite: _isFavorite,
              placesFuture: _placesFuture ?? Future.value([]),
              pulseAnim: _pulseAnim,
              sheetController: _sheetController,
              onClose: _closeSheet,
              onToggleFavorite: _toggleFavorite,
              onNavigate: _navigateToStation,
              onBookSlot: _openBookingSheet,
              onViewReviews: () {
                final stationId =
                    _selectedStation!["ID"]?.toString() ?? '';
                final stationTitle = (_selectedStation!["AddressInfo"]
                as Map?)?["Title"] as String? ??
                    'Station';
                Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => StationReviewsScreen(
                            stationId: stationId,
                            stationTitle: stationTitle)));
              },
            ),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        backgroundColor: const Color(0xFF0F172A),
        indicatorColor: const Color(0xFF00C853).withOpacity(0.2),
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) {
          if (index == _selectedIndex && index == 0) return;
          setState(() => _selectedIndex = index);

          if (index == 1) {
            Navigator.push(context,
                MaterialPageRoute(builder: (_) => const MyBookingsScreen()))
                .then((_) => setState(() => _selectedIndex = 0));
          } else if (index == 2) {
            Navigator.push(context,
                MaterialPageRoute(builder: (_) => const AlertsScreen()))
                .then((_) => setState(() => _selectedIndex = 0));
          } else if (index == 3) {
            Navigator.push(context,
                MaterialPageRoute(builder: (_) => const FavoritesScreen()))
                .then((_) => setState(() => _selectedIndex = 0));
          } else if (index == 4) {
            Navigator.push(context,
                MaterialPageRoute(builder: (_) => const ProfileScreen()))
                .then((_) => setState(() => _selectedIndex = 0));
          }
        },
        destinations: [
          const NavigationDestination(
            icon: Icon(Icons.map_outlined, color: Colors.white54),
            selectedIcon: Icon(Icons.map, color: Color(0xFF00C853)),
            label: 'Map',
          ),
          const NavigationDestination(
            icon: Icon(Icons.book_online_outlined, color: Colors.white54),
            selectedIcon: Icon(Icons.book_online, color: Color(0xFF00C853)),
            label: 'Bookings',
          ),
          NavigationDestination(
            icon: Badge(
              isLabelVisible: _unreadAlerts > 0,
              label: Text('$_unreadAlerts'),
              child: const Icon(Icons.notifications_outlined,
                  color: Colors.white54),
            ),
            selectedIcon: Badge(
              isLabelVisible: _unreadAlerts > 0,
              label: Text('$_unreadAlerts'),
              child: const Icon(Icons.notifications_active_rounded,
                  color: Color(0xFFFFB300)),
            ),
            label: 'Alerts',
          ),
          const NavigationDestination(
            icon: Icon(Icons.favorite_border_rounded, color: Colors.white54),
            selectedIcon:
            Icon(Icons.favorite_rounded, color: Color(0xFF00C853)),
            label: 'Favorites',
          ),
          const NavigationDestination(
            icon: Icon(Icons.person_outline_rounded, color: Colors.white54),
            selectedIcon:
            Icon(Icons.person_rounded, color: Color(0xFF00C853)),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  _StationBottomSheet — Uber-style swipeable sheet with reviews
// ─────────────────────────────────────────────────────────────────────────────
class _StationBottomSheet extends StatelessWidget {
  final Map<String, dynamic> station;
  final bool isFavorite;
  final Future<List<NearbyPlace>> placesFuture;
  final Animation<double> pulseAnim;
  final DraggableScrollableController sheetController;
  final VoidCallback onClose;
  final VoidCallback onToggleFavorite;
  final VoidCallback onNavigate;
  final VoidCallback onBookSlot;
  final VoidCallback onViewReviews;

  const _StationBottomSheet({
    required this.station,
    required this.isFavorite,
    required this.placesFuture,
    required this.pulseAnim,
    required this.sheetController,
    required this.onClose,
    required this.onToggleFavorite,
    required this.onNavigate,
    required this.onBookSlot,
    required this.onViewReviews,
  });

  @override
  Widget build(BuildContext context) {
    final info = station["AddressInfo"] as Map<String, dynamic>? ?? {};
    final connections = station["Connections"] as List?;
    String connector = "Unknown", power = "Unknown";
    if (connections != null && connections.isNotEmpty) {
      connector =
          connections[0]["ConnectionType"]?["Title"] as String? ?? "Unknown";
      power = connections[0]["PowerKW"]?.toString() ?? "Unknown";
    }
    final title = info["Title"] as String? ?? "Charging Station";
    final address = info["AddressLine1"] as String? ?? "";
    final stationId = station["ID"]?.toString() ?? '';

    return DraggableScrollableSheet(
      controller: sheetController,
      initialChildSize: 0.0,
      minChildSize: 0.0,
      maxChildSize: 0.92,
      snap: true,
      snapSizes: const [0.0, 0.40, 0.88],
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: Color(0xFF0F172A),
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            boxShadow: [
              BoxShadow(
                  color: Colors.black54, blurRadius: 20, spreadRadius: 4)
            ],
          ),
          child: ListView(
            controller: scrollController,
            padding: EdgeInsets.zero,
            physics: const ClampingScrollPhysics(),
            children: [
              // ── Drag handle ─────────────────────────────────────────────
              Center(
                child: Container(
                  margin: const EdgeInsets.only(top: 12, bottom: 4),
                  width: 44,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              // ── Header ──────────────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 16, 0),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ScaleTransition(
                      scale: pulseAnim,
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFF00C853).withOpacity(0.15),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.ev_station_rounded,
                            color: Color(0xFF00C853), size: 22),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(title,
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 17,
                                  fontWeight: FontWeight.bold),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis),
                          if (address.isNotEmpty) ...[
                            const SizedBox(height: 3),
                            Text(address,
                                style: const TextStyle(
                                    color: Colors.white38, fontSize: 12),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis),
                          ],
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: onClose,
                      icon: const Icon(Icons.close_rounded,
                          color: Colors.white38, size: 20),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
              ),

              // ── Info chips + rating badge ────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    _Chip(
                        icon: Icons.cable_rounded,
                        label: connector,
                        color: const Color(0xFF00C853)),
                    _Chip(
                        icon: Icons.bolt_rounded,
                        label: "$power kW",
                        color: const Color(0xFFFFD600)),
                    // Tappable rating badge
                    GestureDetector(
                      onTap: onViewReviews,
                      child: StationRatingBadge(stationId: stationId),
                    ),
                  ],
                ),
              ),

              // ── Divider ──────────────────────────────────────────────────
              Container(
                margin: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                height: 1,
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [
                    const Color(0xFF00C853).withOpacity(0.6),
                    Colors.transparent,
                  ]),
                ),
              ),

              // ── 4 action buttons ─────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                child: Row(
                  children: [
                    Expanded(
                      child: _SheetButton(
                        icon: isFavorite
                            ? Icons.favorite_rounded
                            : Icons.favorite_border_rounded,
                        label: isFavorite ? "Saved" : "Save",
                        color:
                        isFavorite ? Colors.redAccent : Colors.white70,
                        filled: false,
                        onTap: onToggleFavorite,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _SheetButton(
                        icon: Icons.navigation_rounded,
                        label: "Navigate",
                        color: const Color(0xFF42A5F5),
                        filled: false,
                        onTap: onNavigate,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _SheetButton(
                        icon: Icons.star_rounded,
                        label: "Review",
                        color: const Color(0xFFFFD600),
                        filled: false,
                        onTap: onViewReviews,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 2,
                      child: _SheetButton(
                        icon: Icons.calendar_month_rounded,
                        label: "Book Slot",
                        color: Colors.black,
                        filled: true,
                        onTap: onBookSlot,
                      ),
                    ),
                  ],
                ),
              ),

              // ── Nearby Places ────────────────────────────────────────────
              const Padding(
                padding: EdgeInsets.fromLTRB(20, 24, 20, 10),
                child: Row(children: [
                  Icon(Icons.place_rounded,
                      color: Color(0xFF00C853), size: 16),
                  SizedBox(width: 8),
                  Text(
                    "NEARBY PLACES",
                    style: TextStyle(
                        color: Colors.white38,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.2),
                  ),
                ]),
              ),

              NearbyPlacesWidget(placesFuture: placesFuture),

              const SizedBox(height: 32),
            ],
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Shared small widgets
// ─────────────────────────────────────────────────────────────────────────────
class _Chip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _Chip({required this.icon, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, color: color, size: 13),
        const SizedBox(width: 5),
        Text(label,
            style: TextStyle(
                color: color, fontSize: 12, fontWeight: FontWeight.w600)),
      ]),
    );
  }
}

class _SheetButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final bool filled;
  final VoidCallback onTap;

  const _SheetButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.filled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: 11),
        decoration: BoxDecoration(
          color: filled ? const Color(0xFF00C853) : const Color(0xFF1E293B),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: filled ? Colors.transparent : Colors.white12),
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(height: 3),
          Text(label,
              style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.w600,
                  fontSize: 10)),
        ]),
      ),
    );
  }
}