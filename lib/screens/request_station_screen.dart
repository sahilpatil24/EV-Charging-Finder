import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geolocator/geolocator.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  RequestStationScreen — user submits a request to add a missing station
//
//  Firestore schema:
//  station_requests/{requestId}
//    - userId        : String
//    - userName      : String
//    - stationName   : String
//    - address       : String
//    - latitude      : double
//    - longitude     : double
//    - connectorType : String
//    - powerKW       : String
//    - notes         : String   (optional details)
//    - status        : String   ('pending' | 'approved' | 'rejected')
//    - createdAt     : Timestamp
//    - reviewedAt    : Timestamp? (set when admin acts)
//    - reviewedBy    : String?   (admin uid)
// ─────────────────────────────────────────────────────────────────────────────

class RequestStationScreen extends StatefulWidget {
  const RequestStationScreen({super.key});

  @override
  State<RequestStationScreen> createState() => _RequestStationScreenState();
}

class _RequestStationScreenState extends State<RequestStationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _latCtrl = TextEditingController();
  final _lngCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();

  String _selectedConnector = 'Type 2';
  String _selectedPower = '22';
  bool _submitting = false;
  bool _fetchingLocation = false;

  final List<String> _connectors = [
    'Type 2', 'CCS2', 'CHAdeMO', 'Type 1', 'GB/T AC', 'GB/T DC', 'Other'
  ];
  final List<String> _powers = ['3.3', '7.2', '11', '22', '50', '100', '150', '350'];

  @override
  void dispose() {
    _nameCtrl.dispose();
    _addressCtrl.dispose();
    _latCtrl.dispose();
    _lngCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _useCurrentLocation() async {
    setState(() => _fetchingLocation = true);
    try {
      final pos = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high);
      _latCtrl.text = pos.latitude.toStringAsFixed(6);
      _lngCtrl.text = pos.longitude.toStringAsFixed(6);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Could not get location: $e'),
                backgroundColor: Colors.red.shade700));
      }
    }
    if (mounted) setState(() => _fetchingLocation = false);
  }

  Future<void> _submitRequest() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _submitting = true);

    try {
      final user = FirebaseAuth.instance.currentUser!;
      await FirebaseFirestore.instance.collection('station_requests').add({
        'userId': user.uid,
        'userName': user.displayName ?? user.email ?? 'Unknown',
        'stationName': _nameCtrl.text.trim(),
        'address': _addressCtrl.text.trim(),
        'latitude': double.tryParse(_latCtrl.text.trim()) ?? 0.0,
        'longitude': double.tryParse(_lngCtrl.text.trim()) ?? 0.0,
        'connectorType': _selectedConnector,
        'powerKW': _selectedPower,
        'notes': _notesCtrl.text.trim(),
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Request submitted! Admin will review shortly.'),
            backgroundColor: Color(0xFF00C853),
          ),
        );
      }
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
                color: const Color(0xFF00C853).withOpacity(0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.add_location_alt_rounded,
                  color: Color(0xFF00C853), size: 18),
            ),
            const SizedBox(width: 10),
            const Text('Request a Station',
                style: TextStyle(
                    color: Colors.white, fontWeight: FontWeight.bold, fontSize: 17)),
          ],
        ),
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Info banner
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFF00C853).withOpacity(0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF00C853).withOpacity(0.2)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.info_outline_rounded,
                        color: Color(0xFF00C853), size: 18),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Can\'t find a station on the map? Request it here and our admin will review and add it.',
                        style: TextStyle(color: Colors.white70, fontSize: 12, height: 1.4),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              _SectionLabel(label: 'Station Details'),
              const SizedBox(height: 12),
              _buildField(
                controller: _nameCtrl,
                label: 'Station Name',
                hint: 'e.g. EV Charging Hub, MG Road',
                icon: Icons.ev_station_rounded,
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 12),
              _buildField(
                controller: _addressCtrl,
                label: 'Address',
                hint: 'Full address including city',
                icon: Icons.location_on_rounded,
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 20),

              _SectionLabel(label: 'Location Coordinates'),
              const SizedBox(height: 8),
              // Use my location button
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _fetchingLocation ? null : _useCurrentLocation,
                  icon: _fetchingLocation
                      ? const SizedBox(width: 14, height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF00C853)))
                      : const Icon(Icons.my_location_rounded, size: 16),
                  label: const Text('Use My Current Location'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF00C853),
                    side: const BorderSide(color: Color(0xFF00C853), width: 1),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _buildField(
                      controller: _latCtrl,
                      label: 'Latitude',
                      hint: '12.9716',
                      icon: Icons.explore_rounded,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) return 'Required';
                        if (double.tryParse(v.trim()) == null) return 'Invalid';
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildField(
                      controller: _lngCtrl,
                      label: 'Longitude',
                      hint: '77.5946',
                      icon: Icons.explore_rounded,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) return 'Required';
                        if (double.tryParse(v.trim()) == null) return 'Invalid';
                        return null;
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              _SectionLabel(label: 'Connector & Power'),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _buildDropdown(
                      label: 'Connector Type',
                      value: _selectedConnector,
                      items: _connectors,
                      onChanged: (v) => setState(() => _selectedConnector = v!),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildDropdown(
                      label: 'Power (kW)',
                      value: _selectedPower,
                      items: _powers,
                      onChanged: (v) => setState(() => _selectedPower = v!),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              _SectionLabel(label: 'Additional Notes (Optional)'),
              const SizedBox(height: 12),
              _buildField(
                controller: _notesCtrl,
                label: 'Notes',
                hint: 'Operating hours, access info, number of chargers, etc.',
                icon: Icons.notes_rounded,
                maxLines: 3,
              ),
              const SizedBox(height: 28),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _submitting ? null : _submitRequest,
                  icon: _submitting
                      ? const SizedBox(width: 18, height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                      : const Icon(Icons.send_rounded, size: 18),
                  label: Text(_submitting ? 'Submitting…' : 'Submit Request'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF00C853),
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    String? Function(String?)? validator,
    TextInputType? keyboardType,
    int maxLines = 1,
  }) {
    return TextFormField(
      controller: controller,
      validator: validator,
      keyboardType: keyboardType,
      maxLines: maxLines,
      style: const TextStyle(color: Colors.white, fontSize: 14),
      cursorColor: const Color(0xFF00C853),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        labelStyle: const TextStyle(color: Colors.white38, fontSize: 13),
        hintStyle: const TextStyle(color: Colors.white24, fontSize: 13),
        prefixIcon: Icon(icon, color: Colors.white38, size: 18),
        filled: true,
        fillColor: const Color(0xFF1E293B),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF00C853), width: 1.5),
        ),
        errorStyle: const TextStyle(color: Color(0xFFEF5350), fontSize: 11),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
    );
  }

  Widget _buildDropdown({
    required String label,
    required String value,
    required List<String> items,
    required void Function(String?) onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(12),
      ),
      child: DropdownButtonFormField<String>(
        value: value,
        onChanged: onChanged,
        dropdownColor: const Color(0xFF1E293B),
        style: const TextStyle(color: Colors.white, fontSize: 13),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(color: Colors.white38, fontSize: 12),
          border: InputBorder.none,
          isDense: true,
        ),
        items: items
            .map((e) => DropdownMenuItem(value: e, child: Text(e)))
            .toList(),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String label;
  const _SectionLabel({required this.label});
  @override
  Widget build(BuildContext context) {
    return Text(label.toUpperCase(),
        style: const TextStyle(
            color: Colors.white38,
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.1));
  }
}