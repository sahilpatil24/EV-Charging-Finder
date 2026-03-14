import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class BookingService {
  static final _db = FirebaseFirestore.instance;

  // ── Ensure station document exists (upsert from OCM data) ─────────────────
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
        'isManuallyAdded': false,
        'createdAt': FieldValue.serverTimestamp(),
      });

      for (int i = 1; i <= 3; i++) {
        await ref.collection('slots').add({
          'slotNumber': i,
          'status': 'available',
          'connectorType': connector,
          'powerKW': power,
          'pricePerHour': 50.0,
        });
      }
    }

    return stationId;
  }

  // ── Fetch slots for a station ─────────────────────────────────────────────
  static Stream<QuerySnapshot> slotsStream(String stationId) {
    return _db
        .collection('stations')
        .doc(stationId)
        .collection('slots')
        .orderBy('slotNumber')
        .snapshots();
  }

  // ── Check if a slot is available for a given time window ──────────────────
  static Future<bool> isSlotAvailableAt({
    required String stationId,
    required String slotId,
    required DateTime startTime,
    required DateTime endTime,
  }) async {
    final snap = await _db
        .collection('bookings')
        .where('stationId', isEqualTo: stationId)
        .where('slotId', isEqualTo: slotId)
        .where('paymentStatus', isEqualTo: 'paid')
        .get();

    for (final doc in snap.docs) {
      final d = doc.data();
      final bookedStart = (d['startTime'] as Timestamp).toDate();
      final bookedEnd = (d['endTime'] as Timestamp).toDate();
      if (startTime.isBefore(bookedEnd) && endTime.isAfter(bookedStart)) {
        return false;
      }
    }
    return true;
  }

  // ── Book a slot with a scheduled start time ───────────────────────────────
  static Future<String> bookSlot({
    required String stationId,
    required String stationTitle,
    required String slotId,
    required int slotNumber,
    required double pricePerHour,
    required int durationHours,
    required String paymentIntentId,
    required DateTime scheduledStart,
  }) async {
    final user = FirebaseAuth.instance.currentUser!;
    final endTime = scheduledStart.add(Duration(hours: durationHours));
    final totalAmount = pricePerHour * durationHours;

    final available = await isSlotAvailableAt(
      stationId: stationId,
      slotId: slotId,
      startTime: scheduledStart,
      endTime: endTime,
    );
    if (!available) {
      throw Exception(
          'Slot is no longer available for the selected time. Please choose another slot or time.');
    }

    final bookingRef = await _db.collection('bookings').add({
      'userId': user.uid,
      'stationId': stationId,
      'stationTitle': stationTitle,
      'slotId': slotId,
      'slotNumber': slotNumber,
      'scheduledDate':
      '${scheduledStart.year}-${scheduledStart.month.toString().padLeft(2, '0')}-${scheduledStart.day.toString().padLeft(2, '0')}',
      'startTime': Timestamp.fromDate(scheduledStart),
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
        .orderBy('startTime', descending: true)
        .snapshots();
  }

  // ── Check if user is admin ────────────────────────────────────────────────
  static Future<bool> isAdmin() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return false;
    final doc = await _db.collection('admins').doc(uid).get();
    return doc.exists;
  }
}