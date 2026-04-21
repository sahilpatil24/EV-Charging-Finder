import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

// ── Cancel booking function ───────────────────────────────────────────────────
Future<void> _cancelBooking({
  required BuildContext context,
  required String docId,
  required String stationTitle,
  required int slotNumber,
  required DateTime start,
  required DateTime end,
}) async {
  final confirmed = await showModalBottomSheet<bool>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (_) => _CancelConfirmSheet(
      stationTitle: stationTitle,
      slotNumber: slotNumber,
      start: start,
      end: end,
    ),
  );

  if (confirmed != true) return;

  try {
    await FirebaseFirestore.instance
        .collection('bookings')
        .doc(docId)
        .update({'status': 'cancelled'});

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(children: [
            Icon(Icons.check_circle_rounded, color: Colors.white, size: 18),
            SizedBox(width: 10),
            Text('Booking cancelled successfully'),
          ]),
          backgroundColor: const Color(0xFF1E293B),
          behavior: SnackBarBehavior.floating,
          shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          margin: const EdgeInsets.all(16),
        ),
      );
    }
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(children: [
            const Icon(Icons.error_outline_rounded,
                color: Colors.redAccent, size: 18),
            const SizedBox(width: 10),
            Text('Failed to cancel: $e'),
          ]),
          backgroundColor: const Color(0xFF1E293B),
          behavior: SnackBarBehavior.floating,
          shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          margin: const EdgeInsets.all(16),
        ),
      );
    }
  }
}

// ── Cancel confirmation bottom sheet ─────────────────────────────────────────
class _CancelConfirmSheet extends StatelessWidget {
  final String stationTitle;
  final int slotNumber;
  final DateTime start;
  final DateTime end;

  const _CancelConfirmSheet({
    required this.stationTitle,
    required this.slotNumber,
    required this.start,
    required this.end,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF1E293B),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(
          20, 16, 20, MediaQuery.of(context).viewInsets.bottom + 28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Handle bar
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Icon + title
          Row(children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.cancel_outlined,
                  color: Color(0xFFE24B4A), size: 22),
            ),
            const SizedBox(width: 12),
            const Text('Cancel this booking?',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.bold)),
          ]),
          const SizedBox(height: 16),

          // Booking detail pill
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF0F172A),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  const Icon(Icons.ev_station_rounded,
                      color: Color(0xFF42A5F5), size: 15),
                  const SizedBox(width: 7),
                  Expanded(
                    child: Text(stationTitle,
                        style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            fontSize: 13),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                  ),
                ]),
                const SizedBox(height: 8),
                Row(children: [
                  _SheetDetailChip(
                      icon: Icons.tag_rounded, text: 'Slot #$slotNumber'),
                  const SizedBox(width: 8),
                  _SheetDetailChip(
                      icon: Icons.calendar_today_rounded,
                      text: DateFormat('EEE, MMM d').format(start)),
                  const SizedBox(width: 8),
                  _SheetDetailChip(
                      icon: Icons.access_time_rounded,
                      text:
                      '${DateFormat('h:mm a').format(start)} – ${DateFormat('h:mm a').format(end)}'),
                ]),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Warning note
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFFE24B4A).withOpacity(0.07),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                  color: const Color(0xFFE24B4A).withOpacity(0.2)),
            ),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Icon(Icons.info_outline_rounded,
                  color: Color(0xFFF09595), size: 16),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'This action cannot be undone. A refund may take 5–7 business days depending on your payment method.',
                  style: TextStyle(
                      color: Color(0xFFF09595),
                      fontSize: 12,
                      height: 1.5),
                ),
              ),
            ]),
          ),
          const SizedBox(height: 20),

          // Action buttons
          Row(children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () => Navigator.pop(context, false),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Colors.white24),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: const Text('Keep booking',
                    style: TextStyle(
                        color: Colors.white70,
                        fontWeight: FontWeight.w600)),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                style: ElevatedButton.styleFrom(
                  backgroundColor:
                  const Color(0xFFE24B4A).withOpacity(0.15),
                  foregroundColor: const Color(0xFFE24B4A),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(
                        color: const Color(0xFFE24B4A).withOpacity(0.4)),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: const Text('Yes, cancel',
                    style: TextStyle(fontWeight: FontWeight.w700)),
              ),
            ),
          ]),
        ],
      ),
    );
  }
}

class _SheetDetailChip extends StatelessWidget {
  final IconData icon;
  final String text;
  const _SheetDetailChip({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.white12),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, color: Colors.white38, size: 11),
        const SizedBox(width: 4),
        Text(text,
            style: const TextStyle(color: Colors.white54, fontSize: 11)),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

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
            .collection('bookings')
            .where('userId', isEqualTo: uid)
            .orderBy('startTime', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
                child:
                CircularProgressIndicator(color: Color(0xFF00C853)));
          }
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text('Error: ${snapshot.error}',
                    style: const TextStyle(color: Colors.red),
                    textAlign: TextAlign.center),
              ),
            );
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
              final doc = bookings[index];
              final data = doc.data() as Map<String, dynamic>;

              final stationTitle =
                  data['stationTitle'] as String? ?? 'Station';
              final slotNumber = data['slotNumber'] as int? ?? 0;
              final amount =
                  (data['totalAmount'] as num?)?.toDouble() ?? 0;
              final duration = data['durationHours'] as int? ?? 1;
              final start =
              (data['startTime'] as Timestamp).toDate();
              final end = (data['endTime'] as Timestamp).toDate();
              final isPaid = data['paymentStatus'] == 'paid';
              final isCancelled = data['status'] == 'cancelled';

              // Skip already-cancelled bookings (or style them differently)
              if (isCancelled) return const SizedBox.shrink();

              final _BookingStatus status;
              if (now.isBefore(start)) {
                status = _BookingStatus.upcoming;
              } else if (now.isAfter(start) && now.isBefore(end)) {
                status = _BookingStatus.active;
              } else {
                status = _BookingStatus.expired;
              }

              return _BookingCard(
                docId: doc.id,
                stationTitle: stationTitle,
                slotNumber: slotNumber,
                amount: amount,
                duration: duration,
                start: start,
                end: end,
                isPaid: isPaid,
                status: status,
              );
            },
          );
        },
      ),
    );
  }
}

enum _BookingStatus { upcoming, active, expired }

class _BookingCard extends StatelessWidget {
  final String docId;
  final String stationTitle;
  final int slotNumber;
  final double amount;
  final int duration;
  final DateTime start;
  final DateTime end;
  final bool isPaid;
  final _BookingStatus status;

  const _BookingCard({
    required this.docId,
    required this.stationTitle,
    required this.slotNumber,
    required this.amount,
    required this.duration,
    required this.start,
    required this.end,
    required this.isPaid,
    required this.status,
  });

  Color get _statusColor {
    switch (status) {
      case _BookingStatus.active:
        return const Color(0xFF00C853);
      case _BookingStatus.upcoming:
        return const Color(0xFF42A5F5);
      case _BookingStatus.expired:
        return Colors.white38;
    }
  }

  IconData get _statusIcon {
    switch (status) {
      case _BookingStatus.active:
        return Icons.bolt_rounded;
      case _BookingStatus.upcoming:
        return Icons.schedule_rounded;
      case _BookingStatus.expired:
        return Icons.check_circle_outline_rounded;
    }
  }

  String get _statusLabel {
    switch (status) {
      case _BookingStatus.active:
        return 'Charging Now';
      case _BookingStatus.upcoming:
        return 'Upcoming';
      case _BookingStatus.expired:
        return 'Expired';
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _statusColor;
    final isActive = status == _BookingStatus.active;
    final isUpcoming = status == _BookingStatus.upcoming;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: color
                .withOpacity(isActive || isUpcoming ? 0.4 : 0.1)),
        boxShadow: isActive
            ? [
          BoxShadow(
              color: const Color(0xFF00C853).withOpacity(0.15),
              blurRadius: 12,
              spreadRadius: 1)
        ]
            : [],
      ),
      child: Column(children: [
        // ── Status bar ────────────────────────────────────────────────────
        Container(
          padding:
          const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          decoration: BoxDecoration(
            color: color.withOpacity(0.08),
            borderRadius:
            const BorderRadius.vertical(top: Radius.circular(16)),
          ),
          child: Row(children: [
            if (isActive)
              _PulseDot(color: color)
            else
              Icon(_statusIcon, color: color, size: 14),
            const SizedBox(width: 7),
            Text(_statusLabel,
                style: TextStyle(
                    color: color,
                    fontSize: 12,
                    fontWeight: FontWeight.w700)),
            const Spacer(),
            Container(
              padding:
              const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: color.withOpacity(0.12),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                if (isPaid) ...[
                  const Icon(Icons.verified_rounded,
                      color: Color(0xFF00C853), size: 11),
                  const SizedBox(width: 3),
                  const Text('PAID',
                      style: TextStyle(
                          color: Color(0xFF00C853),
                          fontSize: 10,
                          fontWeight: FontWeight.w800)),
                ],
              ]),
            ),
          ]),
        ),

        // ── Body ─────────────────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Icon(Icons.ev_station_rounded, color: color, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                      child: Text(stationTitle,
                          style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 14),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis)),
                ]),
                const SizedBox(height: 12),

                Row(children: [
                  Expanded(
                      child: _Detail(
                          icon: Icons.ev_station_rounded,
                          label: 'Slot',
                          value: '#$slotNumber')),
                  Expanded(
                      child: _Detail(
                          icon: Icons.timer_rounded,
                          label: 'Duration',
                          value: '${duration}h')),
                  Expanded(
                      child: _Detail(
                          icon: Icons.currency_rupee_rounded,
                          label: 'Amount',
                          value: '₹${amount.toStringAsFixed(0)}',
                          valueColor: const Color(0xFF00C853))),
                ]),
                const SizedBox(height: 12),

                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0F172A),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                        color: color
                            .withOpacity(isActive ? 0.3 : 0.05)),
                  ),
                  child: Row(children: [
                    Icon(Icons.calendar_today_rounded,
                        color: color.withOpacity(0.7), size: 14),
                    const SizedBox(width: 8),
                    Expanded(
                        child: Text(
                          DateFormat('EEE, MMM d yyyy').format(start),
                          style: const TextStyle(
                              color: Colors.white54, fontSize: 12),
                        )),
                    Icon(Icons.access_time_rounded,
                        color: color.withOpacity(0.7), size: 14),
                    const SizedBox(width: 6),
                    Text(
                      '${DateFormat('h:mm a').format(start)} – ${DateFormat('h:mm a').format(end)}',
                      style: TextStyle(
                          color: isActive
                              ? Colors.white
                              : Colors.white70,
                          fontSize: 12,
                          fontWeight: FontWeight.w500),
                    ),
                  ]),
                ),

                if (isActive) ...[
                  const SizedBox(height: 10),
                  _ChargingProgress(start: start, end: end),
                ],

                // ── Cancel button (upcoming only) ─────────────────────
                if (isUpcoming) ...[
                  const SizedBox(height: 12),
                  _CancelButton(
                    onTap: () => _cancelBooking(
                      context: context,
                      docId: docId,
                      stationTitle: stationTitle,
                      slotNumber: slotNumber,
                      start: start,
                      end: end,
                    ),
                  ),
                ],
              ]),
        ),
      ]),
    );
  }
}

// ── Cancel button widget ──────────────────────────────────────────────────────
class _CancelButton extends StatelessWidget {
  final VoidCallback onTap;
  const _CancelButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFFE24B4A).withOpacity(0.08),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
              color: const Color(0xFFE24B4A).withOpacity(0.3)),
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.cancel_outlined,
                color: Color(0xFFE24B4A), size: 15),
            SizedBox(width: 7),
            Text('Cancel Booking',
                style: TextStyle(
                    color: Color(0xFFE24B4A),
                    fontSize: 13,
                    fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}

// ── Charging progress bar ─────────────────────────────────────────────────────
class _ChargingProgress extends StatelessWidget {
  final DateTime start;
  final DateTime end;
  const _ChargingProgress({required this.start, required this.end});

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final total = end.difference(start).inSeconds.toDouble();
    final elapsed = now.difference(start).inSeconds.toDouble();
    final progress = (elapsed / total).clamp(0.0, 1.0);
    final remaining = end.difference(now);
    final remStr = remaining.inMinutes > 60
        ? '${remaining.inHours}h ${remaining.inMinutes.remainder(60)}m left'
        : '${remaining.inMinutes}m left';

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        const Text('Charging progress',
            style: TextStyle(color: Colors.white38, fontSize: 11)),
        const Spacer(),
        Text(remStr,
            style: const TextStyle(
                color: Color(0xFF00C853),
                fontSize: 11,
                fontWeight: FontWeight.w600)),
      ]),
      const SizedBox(height: 6),
      ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: LinearProgressIndicator(
          value: progress,
          backgroundColor:
          const Color(0xFF00C853).withOpacity(0.15),
          valueColor: const AlwaysStoppedAnimation<Color>(
              Color(0xFF00C853)),
          minHeight: 6,
        ),
      ),
    ]);
  }
}

class _PulseDot extends StatefulWidget {
  final Color color;
  const _PulseDot({required this.color});
  @override
  State<_PulseDot> createState() => _PulseDotState();
}

class _PulseDotState extends State<_PulseDot>
    with SingleTickerProviderStateMixin {
  late AnimationController _c;
  late Animation<double> _a;
  @override
  void initState() {
    super.initState();
    _c = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 900))
      ..repeat(reverse: true);
    _a = Tween<double>(begin: 0.4, end: 1.0)
        .animate(CurvedAnimation(parent: _c, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _a,
      child: Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
              color: widget.color, shape: BoxShape.circle)),
    );
  }
}

class _Detail extends StatelessWidget {
  final IconData icon;
  final String label, value;
  final Color? valueColor;
  const _Detail(
      {required this.icon,
        required this.label,
        required this.value,
        this.valueColor});

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
              color: valueColor ?? Colors.white,
              fontWeight: FontWeight.w600,
              fontSize: 13)),
    ]);
  }
}