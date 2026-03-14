import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  AlertsScreen — shows admin-posted alerts for stations within 150 km
//
//  Firestore schema:
//  alerts/{alertId}
//    - stationId      : String
//    - stationTitle   : String
//    - stationLat     : double
//    - stationLng     : double
//    - title          : String   (e.g. "Station Offline")
//    - message        : String
//    - severity       : String   ('info' | 'warning' | 'critical')
//    - createdAt      : Timestamp
//    - createdBy      : String   (admin uid)
//    - isActive       : bool
// ─────────────────────────────────────────────────────────────────────────────

class AlertsScreen extends StatefulWidget {
  const AlertsScreen({super.key});

  @override
  State<AlertsScreen> createState() => _AlertsScreenState();
}

class _AlertsScreenState extends State<AlertsScreen> {
  Position? _position;
  bool _loadingLocation = true;
  static const double _radiusKm = 150.0;

  @override
  void initState() {
    super.initState();
    _loadLocation();
  }

  Future<void> _loadLocation() async {
    try {
      final pos = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.low);
      if (mounted) setState(() { _position = pos; _loadingLocation = false; });
    } catch (_) {
      if (mounted) setState(() => _loadingLocation = false);
    }
  }

  bool _isWithinRadius(double alertLat, double alertLng) {
    if (_position == null) return true; // show all if location unavailable
    final distM = Geolocator.distanceBetween(
      _position!.latitude, _position!.longitude, alertLat, alertLng,
    );
    return distM / 1000 <= _radiusKm;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F172A),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white70, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: const Color(0xFFFFB300).withOpacity(0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.notifications_active_rounded,
                  color: Color(0xFFFFB300), size: 18),
            ),
            const SizedBox(width: 10),
            const Text('Station Alerts',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 17)),
          ],
        ),
      ),
      body: _loadingLocation
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF00C853)))
          : StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('alerts')
            .where('isActive', isEqualTo: true)
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(
                child: CircularProgressIndicator(color: Color(0xFF00C853)));
          }
          if (snap.hasError) {
            return Center(
                child: Text('Error: ${snap.error}',
                    style: const TextStyle(color: Colors.red)));
          }

          final allAlerts = snap.data?.docs ?? [];
          final nearby = allAlerts.where((doc) {
            final d = doc.data() as Map<String, dynamic>;
            final lat = (d['stationLat'] as num?)?.toDouble() ?? 0.0;
            final lng = (d['stationLng'] as num?)?.toDouble() ?? 0.0;
            return _isWithinRadius(lat, lng);
          }).toList();

          if (nearby.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E293B),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Icon(Icons.check_circle_outline_rounded,
                        color: Color(0xFF00C853), size: 48),
                  ),
                  const SizedBox(height: 16),
                  const Text('No alerts in your area',
                      style: TextStyle(
                          color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 6),
                  Text('All stations within ${_radiusKm.toInt()} km are operating normally',
                      style: const TextStyle(color: Colors.white38, fontSize: 13),
                      textAlign: TextAlign.center),
                ],
              ),
            );
          }

          return Column(
            children: [
              // Radius badge
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                child: Row(
                  children: [
                    const Icon(Icons.radar_rounded,
                        color: Colors.white38, size: 14),
                    const SizedBox(width: 6),
                    Text(
                      'Showing ${nearby.length} alert${nearby.length != 1 ? 's' : ''} within ${_radiusKm.toInt()} km',
                      style: const TextStyle(color: Colors.white38, fontSize: 12),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: nearby.length,
                  itemBuilder: (ctx, i) {
                    final d = nearby[i].data() as Map<String, dynamic>;
                    return _AlertCard(data: d);
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _AlertCard extends StatelessWidget {
  final Map<String, dynamic> data;
  const _AlertCard({required this.data});

  Color get _severityColor {
    switch (data['severity']) {
      case 'critical': return const Color(0xFFEF5350);
      case 'warning':  return const Color(0xFFFFB300);
      default:         return const Color(0xFF42A5F5);
    }
  }

  IconData get _severityIcon {
    switch (data['severity']) {
      case 'critical': return Icons.error_rounded;
      case 'warning':  return Icons.warning_amber_rounded;
      default:         return Icons.info_rounded;
    }
  }

  String get _severityLabel {
    switch (data['severity']) {
      case 'critical': return 'CRITICAL';
      case 'warning':  return 'WARNING';
      default:         return 'INFO';
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _severityColor;
    final ts = data['createdAt'] as Timestamp?;
    final timeStr = ts != null
        ? DateFormat('MMM d, h:mm a').format(ts.toDate())
        : '';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.3)),
        boxShadow: [
          BoxShadow(color: color.withOpacity(0.06), blurRadius: 12, spreadRadius: 1),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Severity header bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: Row(
              children: [
                Icon(_severityIcon, color: color, size: 16),
                const SizedBox(width: 7),
                Text(_severityLabel,
                    style: TextStyle(
                        color: color, fontSize: 11,
                        fontWeight: FontWeight.w800, letterSpacing: 1.0)),
                const Spacer(),
                Text(timeStr,
                    style: const TextStyle(color: Colors.white38, fontSize: 11)),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(data['title'] ?? 'Alert',
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 15)),
                const SizedBox(height: 6),
                Text(data['message'] ?? '',
                    style: const TextStyle(color: Colors.white60, fontSize: 13, height: 1.4)),
                const SizedBox(height: 10),
                Row(
                  children: [
                    const Icon(Icons.ev_station_rounded,
                        color: Colors.white38, size: 13),
                    const SizedBox(width: 5),
                    Expanded(
                      child: Text(data['stationTitle'] ?? 'Unknown Station',
                          style: const TextStyle(color: Colors.white38, fontSize: 12),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}