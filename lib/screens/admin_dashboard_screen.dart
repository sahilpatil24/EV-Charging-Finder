import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  AdminDashboardScreen
//
//  Access control: only users with Firestore doc admins/{uid} are allowed in.
//  Check this before navigating here.
//
//  Tabs:
//  1. Alerts   — post/edit/delete station alerts
//  2. Requests — review user station-add requests, approve/reject
//  3. Stations — view all manually added stations
// ─────────────────────────────────────────────────────────────────────────────

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
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
        title: const Text('Admin Dashboard',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        bottom: TabBar(
          controller: _tabs,
          indicatorColor: const Color(0xFF00C853),
          labelColor: const Color(0xFF00C853),
          unselectedLabelColor: Colors.white38,
          tabs: const [
            Tab(text: 'Alerts'),
            Tab(text: 'Requests'),
            Tab(text: 'Stations'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: const [
          _AlertsTab(),
          _RequestsTab(),
          _StationsTab(),
        ],
      ),
      floatingActionButton: AnimatedBuilder(
        animation: _tabs,
        builder: (_, __) {
          if (_tabs.index == 0) {
            return FloatingActionButton.extended(
              backgroundColor: const Color(0xFF00C853),
              foregroundColor: Colors.black,
              onPressed: () => _showAddAlertDialog(context),
              icon: const Icon(Icons.add_alert_rounded),
              label: const Text('Post Alert', style: TextStyle(fontWeight: FontWeight.bold)),
            );
          }
          return const SizedBox.shrink();
        },
      ),
    );
  }

  void _showAddAlertDialog(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _AddAlertSheet(),
    );
  }
}

// ── ALERTS TAB ────────────────────────────────────────────────────────────────
class _AlertsTab extends StatelessWidget {
  const _AlertsTab();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('alerts')
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, snap) {
        if (!snap.hasData) return const Center(child: CircularProgressIndicator(color: Color(0xFF00C853)));
        final docs = snap.data!.docs;
        if (docs.isEmpty) {
          return const Center(child: Text('No alerts posted yet', style: TextStyle(color: Colors.white38)));
        }
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: docs.length,
          itemBuilder: (ctx, i) {
            final d = docs[i].data() as Map<String, dynamic>;
            final id = docs[i].id;
            final isActive = d['isActive'] as bool? ?? true;
            final severityColor = d['severity'] == 'critical'
                ? const Color(0xFFEF5350)
                : d['severity'] == 'warning'
                ? const Color(0xFFFFB300)
                : const Color(0xFF42A5F5);

            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: severityColor.withOpacity(0.25)),
              ),
              child: ListTile(
                contentPadding: const EdgeInsets.fromLTRB(14, 8, 8, 8),
                leading: Container(
                  width: 40, height: 40,
                  decoration: BoxDecoration(
                    color: severityColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    d['severity'] == 'critical' ? Icons.error_rounded
                        : d['severity'] == 'warning' ? Icons.warning_rounded
                        : Icons.info_rounded,
                    color: severityColor, size: 20,
                  ),
                ),
                title: Text(d['title'] ?? '',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14)),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 3),
                    Text(d['stationTitle'] ?? '',
                        style: const TextStyle(color: Colors.white38, fontSize: 12)),
                    const SizedBox(height: 2),
                    Row(children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: isActive ? Colors.green.withOpacity(0.15) : Colors.red.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(isActive ? 'Active' : 'Inactive',
                            style: TextStyle(
                                color: isActive ? Colors.green : Colors.red,
                                fontSize: 10, fontWeight: FontWeight.w600)),
                      ),
                    ]),
                  ],
                ),
                trailing: PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert, color: Colors.white38),
                  color: const Color(0xFF1E293B),
                  onSelected: (v) async {
                    if (v == 'toggle') {
                      await FirebaseFirestore.instance
                          .collection('alerts').doc(id)
                          .update({'isActive': !isActive});
                    } else if (v == 'delete') {
                      await FirebaseFirestore.instance
                          .collection('alerts').doc(id).delete();
                    }
                  },
                  itemBuilder: (_) => [
                    PopupMenuItem(value: 'toggle',
                        child: Text(isActive ? 'Deactivate' : 'Activate',
                            style: const TextStyle(color: Colors.white))),
                    const PopupMenuItem(value: 'delete',
                        child: Text('Delete', style: TextStyle(color: Color(0xFFEF5350)))),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

// ── REQUESTS TAB ──────────────────────────────────────────────────────────────
class _RequestsTab extends StatelessWidget {
  const _RequestsTab();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('station_requests')
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, snap) {
        if (!snap.hasData) return const Center(child: CircularProgressIndicator(color: Color(0xFF00C853)));
        final docs = snap.data!.docs;
        if (docs.isEmpty) {
          return const Center(child: Text('No requests yet', style: TextStyle(color: Colors.white38)));
        }
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: docs.length,
          itemBuilder: (ctx, i) {
            final d = docs[i].data() as Map<String, dynamic>;
            final id = docs[i].id;
            final status = d['status'] as String? ?? 'pending';
            final statusColor = status == 'approved'
                ? const Color(0xFF00C853)
                : status == 'rejected'
                ? const Color(0xFFEF5350)
                : const Color(0xFFFFB300);

            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: statusColor.withOpacity(0.2)),
              ),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Expanded(
                        child: Text(d['stationName'] ?? 'Unnamed',
                            style: const TextStyle(color: Colors.white,
                                fontWeight: FontWeight.bold, fontSize: 15)),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: statusColor.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(status.toUpperCase(),
                            style: TextStyle(color: statusColor, fontSize: 10,
                                fontWeight: FontWeight.w800)),
                      ),
                    ]),
                    const SizedBox(height: 6),
                    Text(d['address'] ?? '', style: const TextStyle(color: Colors.white54, fontSize: 13)),
                    const SizedBox(height: 4),
                    Row(children: [
                      _MiniChip(label: d['connectorType'] ?? '', color: const Color(0xFF00C853)),
                      const SizedBox(width: 6),
                      _MiniChip(label: '${d['powerKW']} kW', color: const Color(0xFFFFD600)),
                    ]),
                    if ((d['notes'] as String?)?.isNotEmpty == true) ...[
                      const SizedBox(height: 8),
                      Text(d['notes'], style: const TextStyle(color: Colors.white38, fontSize: 12, fontStyle: FontStyle.italic)),
                    ],
                    const SizedBox(height: 4),
                    Text('By: ${d['userName'] ?? 'Unknown'}',
                        style: const TextStyle(color: Colors.white24, fontSize: 11)),
                    if (status == 'pending') ...[
                      const SizedBox(height: 12),
                      Row(children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => _rejectRequest(id),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFFEF5350),
                              side: const BorderSide(color: Color(0xFFEF5350)),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                            child: const Text('Reject'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () => _approveRequest(context, id, d),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF00C853),
                              foregroundColor: Colors.black,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                            child: const Text('Approve', style: TextStyle(fontWeight: FontWeight.bold)),
                          ),
                        ),
                      ]),
                    ],
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _rejectRequest(String requestId) async {
    final admin = FirebaseAuth.instance.currentUser!;
    await FirebaseFirestore.instance.collection('station_requests').doc(requestId).update({
      'status': 'rejected',
      'reviewedAt': FieldValue.serverTimestamp(),
      'reviewedBy': admin.uid,
    });
  }

  Future<void> _approveRequest(BuildContext context, String requestId, Map<String, dynamic> d) async {
    final admin = FirebaseAuth.instance.currentUser!;
    final batch = FirebaseFirestore.instance.batch();

    // 1. Create station in stations collection
    final stationRef = FirebaseFirestore.instance.collection('stations').doc();
    batch.set(stationRef, {
      'title': d['stationName'],
      'address': d['address'],
      'latitude': d['latitude'],
      'longitude': d['longitude'],
      'connectorType': d['connectorType'],
      'powerKW': d['powerKW'],
      'isManuallyAdded': true,
      'createdAt': FieldValue.serverTimestamp(),
    });

    // 2. Seed 3 slots
    for (int i = 1; i <= 3; i++) {
      final slotRef = stationRef.collection('slots').doc();
      batch.set(slotRef, {
        'slotNumber': i, 'status': 'available',
        'connectorType': d['connectorType'],
        'powerKW': d['powerKW'], 'pricePerHour': 50.0,
      });
    }

    // 3. Update request status
    final reqRef = FirebaseFirestore.instance.collection('station_requests').doc(requestId);
    batch.update(reqRef, {
      'status': 'approved',
      'approvedStationId': stationRef.id,
      'reviewedAt': FieldValue.serverTimestamp(),
      'reviewedBy': admin.uid,
    });

    await batch.commit();

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✅ Station approved and added!'),
              backgroundColor: Color(0xFF00C853)));
    }
  }
}

// ── STATIONS TAB ──────────────────────────────────────────────────────────────
class _StationsTab extends StatelessWidget {
  const _StationsTab();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('stations')
          .where('isManuallyAdded', isEqualTo: true)
          .snapshots(),
      builder: (context, snap) {
        if (!snap.hasData) return const Center(child: CircularProgressIndicator(color: Color(0xFF00C853)));
        final docs = snap.data!.docs;
        if (docs.isEmpty) {
          return const Center(child: Text('No manually added stations',
              style: TextStyle(color: Colors.white38)));
        }
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: docs.length,
          itemBuilder: (ctx, i) {
            final d = docs[i].data() as Map<String, dynamic>;
            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFF00C853).withOpacity(0.15)),
              ),
              child: Row(children: [
                const Icon(Icons.ev_station_rounded, color: Color(0xFF00C853), size: 22),
                const SizedBox(width: 12),
                Expanded(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(d['title'] ?? '', style: const TextStyle(
                        color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14)),
                    const SizedBox(height: 3),
                    Text(d['address'] ?? '', style: const TextStyle(
                        color: Colors.white38, fontSize: 12)),
                    const SizedBox(height: 4),
                    Row(children: [
                      _MiniChip(label: d['connectorType'] ?? '', color: const Color(0xFF00C853)),
                      const SizedBox(width: 6),
                      _MiniChip(label: '${d['powerKW']} kW', color: const Color(0xFFFFD600)),
                    ]),
                  ],
                )),
              ]),
            );
          },
        );
      },
    );
  }
}

// ── ADD ALERT BOTTOM SHEET ────────────────────────────────────────────────────
class _AddAlertSheet extends StatefulWidget {
  const _AddAlertSheet();

  @override
  State<_AddAlertSheet> createState() => _AddAlertSheetState();
}

class _AddAlertSheetState extends State<_AddAlertSheet> {
  final _formKey = GlobalKey<FormState>();
  final _titleCtrl = TextEditingController();
  final _messageCtrl = TextEditingController();
  final _stationTitleCtrl = TextEditingController();
  final _latCtrl = TextEditingController();
  final _lngCtrl = TextEditingController();
  String _severity = 'warning';
  bool _submitting = false;

  @override
  void dispose() {
    _titleCtrl.dispose(); _messageCtrl.dispose();
    _stationTitleCtrl.dispose(); _latCtrl.dispose(); _lngCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _submitting = true);
    try {
      final admin = FirebaseAuth.instance.currentUser!;
      await FirebaseFirestore.instance.collection('alerts').add({
        'title': _titleCtrl.text.trim(),
        'message': _messageCtrl.text.trim(),
        'stationTitle': _stationTitleCtrl.text.trim(),
        'stationLat': double.tryParse(_latCtrl.text.trim()) ?? 0.0,
        'stationLng': double.tryParse(_lngCtrl.text.trim()) ?? 0.0,
        'severity': _severity,
        'isActive': true,
        'createdAt': FieldValue.serverTimestamp(),
        'createdBy': admin.uid,
        'stationId': '',
      });
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        setState(() => _submitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red.shade700));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF0F172A),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(20, 20, 20,
          MediaQuery.of(context).viewInsets.bottom + 28),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(child: Container(width: 40, height: 4,
                  decoration: BoxDecoration(color: Colors.white24,
                      borderRadius: BorderRadius.circular(2)))),
              const SizedBox(height: 16),
              const Text('Post Station Alert',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 17)),
              const SizedBox(height: 20),

              // Severity selector
              Row(
                children: ['info', 'warning', 'critical'].map((s) {
                  final selected = _severity == s;
                  final color = s == 'critical'
                      ? const Color(0xFFEF5350)
                      : s == 'warning' ? const Color(0xFFFFB300)
                      : const Color(0xFF42A5F5);
                  return Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _severity = s),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        margin: const EdgeInsets.only(right: 8),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          color: selected ? color.withOpacity(0.15) : const Color(0xFF1E293B),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: selected ? color : Colors.white12),
                        ),
                        child: Center(child: Text(s.toUpperCase(),
                            style: TextStyle(color: selected ? color : Colors.white38,
                                fontSize: 11, fontWeight: FontWeight.w700))),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 14),

              _field(_titleCtrl, 'Alert Title', 'e.g. Station Offline',
                  validator: (v) => v!.trim().isEmpty ? 'Required' : null),
              const SizedBox(height: 10),
              _field(_messageCtrl, 'Message', 'Describe the issue…',
                  maxLines: 3,
                  validator: (v) => v!.trim().isEmpty ? 'Required' : null),
              const SizedBox(height: 10),
              _field(_stationTitleCtrl, 'Station Name', 'Station display name',
                  validator: (v) => v!.trim().isEmpty ? 'Required' : null),
              const SizedBox(height: 10),
              Row(children: [
                Expanded(child: _field(_latCtrl, 'Latitude', '12.9716')),
                const SizedBox(width: 10),
                Expanded(child: _field(_lngCtrl, 'Longitude', '77.5946')),
              ]),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _submitting ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF00C853),
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: _submitting
                      ? const SizedBox(width: 20, height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                      : const Text('Post Alert', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _field(TextEditingController c, String label, String hint,
      {String? Function(String?)? validator, int maxLines = 1}) {
    return TextFormField(
      controller: c,
      validator: validator,
      maxLines: maxLines,
      style: const TextStyle(color: Colors.white, fontSize: 13),
      cursorColor: const Color(0xFF00C853),
      decoration: InputDecoration(
        labelText: label, hintText: hint,
        labelStyle: const TextStyle(color: Colors.white38, fontSize: 12),
        hintStyle: const TextStyle(color: Colors.white24, fontSize: 12),
        filled: true, fillColor: const Color(0xFF1E293B),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: Color(0xFF00C853))),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        errorStyle: const TextStyle(color: Color(0xFFEF5350), fontSize: 10),
      ),
    );
  }
}

class _MiniChip extends StatelessWidget {
  final String label;
  final Color color;
  const _MiniChip({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(label, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600)),
    );
  }
}