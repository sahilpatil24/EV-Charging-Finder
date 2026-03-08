
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// ─────────────────────────────────────────────
///  FIRESTORE SCHEMA
/// ─────────────────────────────────────────────
///
///  stations/{stationId}                        ← mirrored from OpenChargeMap
///    - title          : String
///    - address        : String
///    - latitude       : double
///    - longitude      : double
///    - connectorType  : String
///    - powerKW        : String
///    - createdAt      : Timestamp
///
///  stations/{stationId}/slots/{slotId}
///    - slotNumber     : int      (1, 2, 3 …)
///    - status         : String   ('available' | 'booked' | 'maintenance')
///    - connectorType  : String
///    - powerKW        : String
///    - pricePerHour   : double   (e.g. 50.0 = ₹50/hr)
///
///  bookings/{bookingId}
///    - userId         : String
///    - stationId      : String
///    - stationTitle   : String
///    - slotId         : String
///    - slotNumber     : int
///    - startTime      : Timestamp
///    - endTime        : Timestamp
///    - durationHours  : int
///    - totalAmount    : double
///    - paymentStatus  : String  ('pending' | 'paid' | 'failed')
///    - paymentIntentId: String  (from Stripe backend — set after payment)
///    - createdAt      : Timestamp
/// ─────────────────────────────────────────────

class BookingService {
  static final _db = FirebaseFirestore.instance;

  // ── Ensure station document exists (upsert) ──────────────────────────────
  static Future<String> ensureStation(Map<String, dynamic> station) async {
    final stationId = station['ID'].toString();
    final info = station['AddressInfo'];
    final connections = station['Connections'];

    String connector = 'Unknown';
    String power = 'Unknown';
    if (connections != null && (connections as List).isNotEmpty) {
      connector = connections[0]['ConnectionType']?['Title'] ?? 'Unknown';
      power = connections[0]['PowerKW']?.toString() ?? 'Unknown';
    }

    final ref = _db.collection('stations').doc(stationId);
    final doc = await ref.get();

    if (!doc.exists) {
      await ref.set({
        'title': info['Title'] ?? 'Charging Station',
        'address': info['AddressLine1'] ?? '',
        'latitude': (info['Latitude'] as num).toDouble(),
        'longitude': (info['Longitude'] as num).toDouble(),
        'connectorType': connector,
        'powerKW': power,
        'createdAt': FieldValue.serverTimestamp(),
      });

      // Seed 3 default slots
      for (int i = 1; i <= 3; i++) {
        await ref.collection('slots').add({
          'slotNumber': i,
          'status': 'available',
          'connectorType': connector,
          'powerKW': power,
          'pricePerHour': 50.0, // ₹50 default
        });
      }
    }

    return stationId;
  }

  // ── Fetch slots for a station (real-time stream) ─────────────────────────
  static Stream<QuerySnapshot> slotsStream(String stationId) {
    return _db
        .collection('stations')
        .doc(stationId)
        .collection('slots')
        .orderBy('slotNumber')
        .snapshots();
  }

  // ── Book a slot ───────────────────────────────────────────────────────────
  static Future<String> bookSlot({
    required String stationId,
    required String stationTitle,
    required String slotId,
    required int slotNumber,
    required double pricePerHour,
    required int durationHours,
    required String paymentIntentId,
  }) async {
    final user = FirebaseAuth.instance.currentUser!;
    final now = DateTime.now();
    final endTime = now.add(Duration(hours: durationHours));
    final totalAmount = pricePerHour * durationHours;

    // 1. Mark slot as booked
    await _db
        .collection('stations')
        .doc(stationId)
        .collection('slots')
        .doc(slotId)
        .update({'status': 'booked'});

    // 2. Create booking document
    final bookingRef = await _db.collection('bookings').add({
      'userId': user.uid,
      'stationId': stationId,
      'stationTitle': stationTitle,
      'slotId': slotId,
      'slotNumber': slotNumber,
      'startTime': Timestamp.fromDate(now),
      'endTime': Timestamp.fromDate(endTime),
      'durationHours': durationHours,
      'totalAmount': totalAmount,
      'paymentStatus': 'paid',
      'paymentIntentId': paymentIntentId,
      'createdAt': FieldValue.serverTimestamp(),
    });

    return bookingRef.id;
  }

  // ── Fetch current user's bookings ─────────────────────────────────────────
  static Stream<QuerySnapshot> myBookingsStream() {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    return _db
        .collection('bookings')
        .where('userId', isEqualTo: uid)
        .orderBy('createdAt', descending: true)
        .snapshots();
  }
}


