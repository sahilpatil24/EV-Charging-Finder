import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class MyBookingsScreen extends StatelessWidget {
  const MyBookingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser!.uid;

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F172A),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              color: Colors.white70, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: const Color(0xFF00C853).withOpacity(0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.book_online_rounded,
                color: Color(0xFF00C853), size: 18),
          ),
          const SizedBox(width: 10),
          const Text('My Bookings',
              style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 17)),
        ]),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection("bookings")
            .where("userId", isEqualTo: uid)
            .orderBy("startTime", descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
                child: CircularProgressIndicator(
                    color: Color(0xFF00C853)));
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
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
                    child: const Icon(Icons.book_online_outlined,
                        color: Colors.white38, size: 48),
                  ),
                  const SizedBox(height: 16),
                  const Text('No bookings yet',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600)),
                  const SizedBox(height: 6),
                  const Text('Book your first EV charging slot on the map',
                      style:
                      TextStyle(color: Colors.white38, fontSize: 13)),
                ],
              ),
            );
          }

          final bookings = snapshot.data!.docs;
          final now = DateTime.now();

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: bookings.length,
            itemBuilder: (context, index) {
              final data =
              bookings[index].data() as Map<String, dynamic>;

              final stationTitle =
                  data["stationTitle"] as String? ?? 'Station';
              final slotNumber = data["slotNumber"];
              final amount = (data["totalAmount"] as num?)?.toDouble() ?? 0;
              final duration = data["durationHours"] as int? ?? 1;
              final start =
              (data["startTime"] as Timestamp).toDate();
              final end = (data["endTime"] as Timestamp).toDate();
              final isPaid = data["paymentStatus"] == "paid";
              final isUpcoming = start.isAfter(now);
              final isActive = start.isBefore(now) && end.isAfter(now);

              String statusLabel;
              Color statusColor;
              if (isActive) {
                statusLabel = 'Charging Now';
                statusColor = const Color(0xFF00C853);
              } else if (isUpcoming) {
                statusLabel = 'Upcoming';
                statusColor = const Color(0xFF42A5F5);
              } else {
                statusLabel = 'Completed';
                statusColor = Colors.white38;
              }

              return Container(
                margin: const EdgeInsets.only(bottom: 14),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E293B),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                      color: statusColor.withOpacity(
                          isActive || isUpcoming ? 0.4 : 0.1)),
                  boxShadow: isActive
                      ? [
                    BoxShadow(
                        color: const Color(0xFF00C853)
                            .withOpacity(0.15),
                        blurRadius: 12,
                        spreadRadius: 1)
                  ]
                      : [],
                ),
                child: Column(
                  children: [
                    // Status bar
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 9),
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.08),
                        borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(16)),
                      ),
                      child: Row(children: [
                        Container(
                          width: 7,
                          height: 7,
                          decoration: BoxDecoration(
                            color: statusColor,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 7),
                        Text(statusLabel,
                            style: TextStyle(
                                color: statusColor,
                                fontSize: 12,
                                fontWeight: FontWeight.w700)),
                        const Spacer(),
                        if (isPaid)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFF00C853)
                                  .withOpacity(0.12),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text('PAID',
                                style: TextStyle(
                                    color: Color(0xFF00C853),
                                    fontSize: 10,
                                    fontWeight: FontWeight.w800)),
                          ),
                      ]),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(children: [
                            const Icon(Icons.ev_station_rounded,
                                color: Color(0xFF00C853), size: 18),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(stationTitle,
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis),
                            ),
                          ]),
                          const SizedBox(height: 12),
                          Row(children: [
                            Expanded(
                              child: _BookingDetail(
                                icon: Icons.ev_station_rounded,
                                label: 'Slot',
                                value: '#$slotNumber',
                              ),
                            ),
                            Expanded(
                              child: _BookingDetail(
                                icon: Icons.timer_rounded,
                                label: 'Duration',
                                value:
                                '${duration}h',
                              ),
                            ),
                            Expanded(
                              child: _BookingDetail(
                                icon: Icons.currency_rupee_rounded,
                                label: 'Amount',
                                value:
                                '₹${amount.toStringAsFixed(0)}',
                                valueColor: const Color(0xFF00C853),
                              ),
                            ),
                          ]),
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: const Color(0xFF0F172A),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Row(children: [
                              const Icon(Icons.calendar_today_rounded,
                                  color: Colors.white38, size: 14),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  DateFormat('EEE, MMM d yyyy')
                                      .format(start),
                                  style: const TextStyle(
                                      color: Colors.white54,
                                      fontSize: 12),
                                ),
                              ),
                              const Icon(Icons.access_time_rounded,
                                  color: Colors.white38, size: 14),
                              const SizedBox(width: 6),
                              Text(
                                '${DateFormat('h:mm a').format(start)} – ${DateFormat('h:mm a').format(end)}',
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500),
                              ),
                            ]),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _BookingDetail extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color valueColor;

  const _BookingDetail({
    required this.icon,
    required this.label,
    required this.value,
    this.valueColor = Colors.white,
  });

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Icon(icon, color: Colors.white38, size: 16),
      const SizedBox(height: 4),
      Text(label,
          style: const TextStyle(color: Colors.white38, fontSize: 10)),
      const SizedBox(height: 2),
      Text(value,
          style: TextStyle(
              color: valueColor,
              fontWeight: FontWeight.w600,
              fontSize: 13)),
    ]);
  }
}