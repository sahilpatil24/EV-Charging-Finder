import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class AlertsScreen extends StatefulWidget {
  const AlertsScreen({super.key});

  @override
  State<AlertsScreen> createState() => _AlertsScreenState();
}

class _AlertsScreenState extends State<AlertsScreen> {
  @override
  Widget build(BuildContext context) {
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
              color: const Color(0xFFFFB300).withOpacity(0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.notifications_active_rounded,
                color: Color(0xFFFFB300), size: 18),
          ),
          const SizedBox(width: 10),
          const Text('Station Alerts',
              style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 17)),
        ]),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('alerts')
            .where('isActive', isEqualTo: true)
            .snapshots(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(
                child: CircularProgressIndicator(color: Color(0xFF00C853)));
          }
          if (snap.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline_rounded,
                          color: Colors.red, size: 48),
                      const SizedBox(height: 12),
                      Text('Error: ${snap.error}',
                          style: const TextStyle(color: Colors.red),
                          textAlign: TextAlign.center),
                    ]),
              ),
            );
          }

          final allDocs = snap.data?.docs ?? [];

          // Sort by createdAt descending client-side
          final alerts = allDocs.toList()
            ..sort((a, b) {
              final at = (a.data() as Map)['createdAt'] as Timestamp?;
              final bt = (b.data() as Map)['createdAt'] as Timestamp?;
              if (at == null || bt == null) return 0;
              return bt.compareTo(at);
            });

          if (alerts.isEmpty) {
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
                  const Text('No active alerts',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600)),
                  const SizedBox(height: 6),
                  const Text(
                    'All stations are operating normally',
                    style: TextStyle(color: Colors.white38, fontSize: 13),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            );
          }

          return Column(children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: Row(children: [
                const Icon(Icons.list_alt_rounded,
                    color: Colors.white38, size: 14),
                const SizedBox(width: 6),
                Text(
                  'Showing ${alerts.length} active alert${alerts.length != 1 ? 's' : ''}',
                  style: const TextStyle(color: Colors.white38, fontSize: 12),
                ),
              ]),
            ),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: alerts.length,
                itemBuilder: (ctx, i) {
                  final d = alerts[i].data() as Map<String, dynamic>;
                  return _AlertCard(data: d);
                },
              ),
            ),
          ]);
        },
      ),
    );
  }
}

class _AlertCard extends StatelessWidget {
  final Map<String, dynamic> data;
  const _AlertCard({required this.data});

  Color get _color {
    switch (data['severity']) {
      case 'critical':
        return const Color(0xFFEF5350);
      case 'warning':
        return const Color(0xFFFFB300);
      default:
        return const Color(0xFF42A5F5);
    }
  }

  IconData get _icon {
    switch (data['severity']) {
      case 'critical':
        return Icons.error_rounded;
      case 'warning':
        return Icons.warning_amber_rounded;
      default:
        return Icons.info_rounded;
    }
  }

  String get _label {
    switch (data['severity']) {
      case 'critical':
        return 'CRITICAL';
      case 'warning':
        return 'WARNING';
      default:
        return 'INFO';
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _color;
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
          BoxShadow(
              color: color.withOpacity(0.06), blurRadius: 12, spreadRadius: 1)
        ],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
          ),
          child: Row(children: [
            Icon(_icon, color: color, size: 16),
            const SizedBox(width: 7),
            Text(_label,
                style: TextStyle(
                    color: color,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.0)),
            const Spacer(),
            Text(timeStr,
                style: const TextStyle(color: Colors.white38, fontSize: 11)),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.all(14),
          child:
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(data['title'] ?? 'Alert',
                style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 15)),
            const SizedBox(height: 6),
            Text(data['message'] ?? '',
                style: const TextStyle(
                    color: Colors.white60, fontSize: 13, height: 1.4)),
            const SizedBox(height: 10),
            Row(children: [
              const Icon(Icons.ev_station_rounded,
                  color: Colors.white38, size: 13),
              const SizedBox(width: 5),
              Expanded(
                  child: Text(data['stationTitle'] ?? 'Unknown Station',
                      style:
                      const TextStyle(color: Colors.white38, fontSize: 12),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis)),
            ]),
          ]),
        ),
      ]),
    );
  }
}