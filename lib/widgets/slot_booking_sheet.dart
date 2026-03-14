import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../services/booking_service.dart';
import '../services/payment_service.dart';

class SlotBookingSheet extends StatefulWidget {
  final Map<String, dynamic> station;
  final String stationId;
  final Future<void> Function({
  required String paymentIntentId,
  required String stationTitle,
  required String slotId,
  required int slotNumber,
  required double pricePerHour,
  required int durationHours,
  required DateTime scheduledStart,
  }) onReadyToPay;

  const SlotBookingSheet({
    super.key,
    required this.station,
    required this.stationId,
    required this.onReadyToPay,
  });

  @override
  State<SlotBookingSheet> createState() => _SlotBookingSheetState();
}

class _SlotBookingSheetState extends State<SlotBookingSheet>
    with SingleTickerProviderStateMixin {
  String? _selectedSlotId;
  int? _selectedSlotNumber;
  double _selectedPrice = 0;
  int _selectedDuration = 1;
  bool _isProcessing = false;
  bool _checkingAvailability = false;

  DateTime _selectedDate = DateTime.now();
  TimeOfDay _selectedTime = TimeOfDay.now();

  late AnimationController _animController;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selectedDate = now;
    _selectedTime = TimeOfDay(hour: (now.hour + 1) % 24, minute: 0);

    _animController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 400));
    _fadeAnim =
        CurvedAnimation(parent: _animController, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.15),
      end: Offset.zero,
    ).animate(CurvedAnimation(
        parent: _animController, curve: Curves.easeOutCubic));
    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  String get _stationTitle =>
      widget.station['AddressInfo']?['Title'] ?? 'Charging Station';

  double get _totalAmount => _selectedPrice * _selectedDuration;

  DateTime get _scheduledStart => DateTime(
    _selectedDate.year,
    _selectedDate.month,
    _selectedDate.day,
    _selectedTime.hour,
    _selectedTime.minute,
  );

  DateTime get _scheduledEnd =>
      _scheduledStart.add(Duration(hours: _selectedDuration));

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 30)),
      builder: (context, child) => Theme(
        data: ThemeData.dark().copyWith(
          colorScheme: const ColorScheme.dark(
            primary: Color(0xFF00C853),
            surface: Color(0xFF1E293B),
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _selectedDate = picked);
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime,
      builder: (context, child) => Theme(
        data: ThemeData.dark().copyWith(
          colorScheme: const ColorScheme.dark(
            primary: Color(0xFF00C853),
            surface: Color(0xFF1E293B),
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _selectedTime = picked);
  }

  Future<void> _handleBooking() async {
    if (_selectedSlotId == null) return;

    if (_scheduledStart.isBefore(DateTime.now())) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a future date and time'),
          backgroundColor: Color(0xFFFFB300),
        ),
      );
      return;
    }

    setState(() => _isProcessing = true);

    try {
      setState(() => _checkingAvailability = true);
      final available = await BookingService.isSlotAvailableAt(
        stationId: widget.stationId,
        slotId: _selectedSlotId!,
        startTime: _scheduledStart,
        endTime: _scheduledEnd,
      );
      setState(() => _checkingAvailability = false);

      if (!available) {
        if (mounted) {
          setState(() => _isProcessing = false);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Slot already booked for this time. Pick another.'),
              backgroundColor: Color(0xFFFFB300),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
        return;
      }

      debugPrint('🔑 Calling backend to create payment intent...');
      final paymentIntentId = await PaymentService.createAndInitPaymentSheet(
        amountInPaise: (_totalAmount * 100).toInt(),
        currency: 'inr',
        description:
        'Slot #$_selectedSlotNumber – $_stationTitle (${DateFormat('MMM d, h:mm a').format(_scheduledStart)})',
      );

      if (!mounted) return;

      final slotId = _selectedSlotId!;
      final slotNumber = _selectedSlotNumber!;
      final price = _selectedPrice;
      final duration = _selectedDuration;
      final title = _stationTitle;
      final scheduledStart = _scheduledStart;
      final callback = widget.onReadyToPay;

      Navigator.of(context).pop();

      await callback(
        paymentIntentId: paymentIntentId,
        stationTitle: title,
        slotId: slotId,
        slotNumber: slotNumber,
        pricePerHour: price,
        durationHours: duration,
        scheduledStart: scheduledStart,
      );
    } catch (e) {
      debugPrint('❌ Booking error: $e');
      if (mounted) {
        setState(() {
          _isProcessing = false;
          _checkingAvailability = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Error: $e'),
              backgroundColor: Colors.red.shade700,
              behavior: SnackBarBehavior.floating),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fadeAnim,
      child: SlideTransition(
        position: _slideAnim,
        child: Container(
          decoration: const BoxDecoration(
            color: Color(0xFF0F172A),
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                margin: const EdgeInsets.only(top: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(2)),
              ),
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        Container(
                          padding: const EdgeInsets.all(9),
                          decoration: BoxDecoration(
                            color:
                            const Color(0xFF00C853).withOpacity(0.15),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.ev_station,
                              color: Color(0xFF00C853), size: 20),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(_stationTitle,
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 15),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis),
                              const Text('Select a slot & schedule',
                                  style: TextStyle(
                                      color: Colors.white38, fontSize: 12)),
                            ],
                          ),
                        ),
                      ]),

                      const SizedBox(height: 22),
                      _SectionLabel(label: 'Available Slots'),
                      const SizedBox(height: 12),

                      StreamBuilder<QuerySnapshot>(
                        stream:
                        BookingService.slotsStream(widget.stationId),
                        builder: (context, snap) {
                          if (snap.connectionState ==
                              ConnectionState.waiting) {
                            return const Padding(
                              padding: EdgeInsets.symmetric(vertical: 24),
                              child: Center(
                                  child: CircularProgressIndicator(
                                      color: Color(0xFF00C853))),
                            );
                          }
                          final slots = snap.data?.docs ?? [];
                          if (slots.isEmpty) {
                            return const Center(
                                child: Text('No slots found',
                                    style: TextStyle(
                                        color: Colors.white38)));
                          }
                          return GridView.builder(
                            shrinkWrap: true,
                            physics:
                            const NeverScrollableScrollPhysics(),
                            gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 3,
                              crossAxisSpacing: 10,
                              mainAxisSpacing: 10,
                              childAspectRatio: 1.05,
                            ),
                            itemCount: slots.length,
                            itemBuilder: (context, i) {
                              final data = slots[i].data()
                              as Map<String, dynamic>;
                              final slotId = slots[i].id;
                              final isBooked =
                                  data['status'] == 'booked';
                              final isMaintenance =
                                  data['status'] == 'maintenance';
                              final isSelected =
                                  _selectedSlotId == slotId;
                              final price =
                                  (data['pricePerHour'] as num?)
                                      ?.toDouble() ??
                                      50.0;
                              return _SlotTile(
                                slotNumber:
                                data['slotNumber'] ?? i + 1,
                                powerKW:
                                data['powerKW']?.toString() ?? '–',
                                price: price,
                                isBooked: isBooked,
                                isMaintenance: isMaintenance,
                                isSelected: isSelected,
                                onTap: isBooked || isMaintenance
                                    ? null
                                    : () => setState(() {
                                  _selectedSlotId = slotId;
                                  _selectedSlotNumber =
                                  data['slotNumber'];
                                  _selectedPrice = price;
                                }),
                              );
                            },
                          );
                        },
                      ),

                      AnimatedSize(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeOutCubic,
                        child: _selectedSlotId == null
                            ? const SizedBox.shrink()
                            : Column(
                          crossAxisAlignment:
                          CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 24),
                            _SectionLabel(
                                label: 'Schedule Booking'),
                            const SizedBox(height: 10),
                            Row(children: [
                              Expanded(
                                child: _PickerButton(
                                  icon: Icons
                                      .calendar_today_rounded,
                                  label: DateFormat('EEE, MMM d')
                                      .format(_selectedDate),
                                  onTap: _pickDate,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: _PickerButton(
                                  icon:
                                  Icons.access_time_rounded,
                                  label: _selectedTime
                                      .format(context),
                                  onTap: _pickTime,
                                ),
                              ),
                            ]),
                            const SizedBox(height: 20),
                            _SectionLabel(label: 'Duration'),
                            const SizedBox(height: 10),
                            _buildDurationPicker(),
                            const SizedBox(height: 20),
                            _buildSummaryCard(),
                            const SizedBox(height: 20),
                            _buildPayButton(),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDurationPicker() {
    return Row(
      children: [1, 2, 3, 4].map((h) {
        final selected = _selectedDuration == h;
        return GestureDetector(
          onTap: () => setState(() => _selectedDuration = h),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            margin: const EdgeInsets.only(right: 10),
            padding:
            const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            decoration: BoxDecoration(
              color: selected
                  ? const Color(0xFF00C853)
                  : const Color(0xFF1E293B),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                  color: selected
                      ? const Color(0xFF00C853)
                      : Colors.white12),
            ),
            child: Text('${h}h',
                style: TextStyle(
                    color: selected ? Colors.black : Colors.white70,
                    fontWeight: FontWeight.bold,
                    fontSize: 14)),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildSummaryCard() {
    final startStr =
    DateFormat('MMM d, h:mm a').format(_scheduledStart);
    final endStr = DateFormat('h:mm a').format(_scheduledEnd);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
            color: const Color(0xFF00C853).withOpacity(0.3)),
      ),
      child: Row(children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                  'Slot #$_selectedSlotNumber  •  ${_selectedDuration}h',
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 14)),
              const SizedBox(height: 4),
              Text('$startStr → $endStr',
                  style: const TextStyle(
                      color: Colors.white38, fontSize: 12)),
            ],
          ),
        ),
        Text('₹${_totalAmount.toStringAsFixed(0)}',
            style: const TextStyle(
                color: Color(0xFF00C853),
                fontSize: 24,
                fontWeight: FontWeight.bold)),
      ]),
    );
  }

  Widget _buildPayButton() {
    final statusText = _checkingAvailability
        ? 'Checking availability…'
        : 'Preparing payment…';
    return SizedBox(
      width: double.infinity,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 250),
        child: _isProcessing
            ? Container(
          key: const ValueKey('loading'),
          height: 54,
          decoration: BoxDecoration(
              color: const Color(0xFF1E293B),
              borderRadius: BorderRadius.circular(14)),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                      color: Color(0xFF00C853), strokeWidth: 2.5)),
              const SizedBox(width: 12),
              Text(statusText,
                  style: const TextStyle(
                      color: Colors.white54, fontSize: 14)),
            ],
          ),
        )
            : ElevatedButton.icon(
          key: const ValueKey('pay'),
          onPressed: _handleBooking,
          icon: const Icon(Icons.lock_rounded, size: 18),
          label: Text(
              'Pay ₹${_totalAmount.toStringAsFixed(0)} & Book',
              style: const TextStyle(
                  fontWeight: FontWeight.bold, fontSize: 15)),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF00C853),
            foregroundColor: Colors.black,
            minimumSize: const Size.fromHeight(54),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14)),
          ),
        ),
      ),
    );
  }
}

class _PickerButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _PickerButton(
      {required this.icon, required this.label, required this.onTap});
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding:
        const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFF1E293B),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: const Color(0xFF00C853).withOpacity(0.3)),
        ),
        child: Row(children: [
          Icon(icon, color: const Color(0xFF00C853), size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(label,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w500),
                overflow: TextOverflow.ellipsis),
          ),
        ]),
      ),
    );
  }
}

class _SlotTile extends StatelessWidget {
  final int slotNumber;
  final String powerKW;
  final double price;
  final bool isBooked;
  final bool isMaintenance;
  final bool isSelected;
  final VoidCallback? onTap;
  const _SlotTile({
    required this.slotNumber,
    required this.powerKW,
    required this.price,
    required this.isBooked,
    required this.isMaintenance,
    required this.isSelected,
    this.onTap,
  });
  @override
  Widget build(BuildContext context) {
    Color bg, border, textColor;
    String label;
    IconData icon;
    if (isSelected) {
      bg = const Color(0xFF00C853).withOpacity(0.15);
      border = const Color(0xFF00C853);
      textColor = const Color(0xFF00C853);
      label = 'Selected';
      icon = Icons.check_circle_rounded;
    } else if (isBooked) {
      bg = Colors.red.withOpacity(0.07);
      border = Colors.red.withOpacity(0.25);
      textColor = Colors.red.shade300;
      label = 'Booked';
      icon = Icons.block_rounded;
    } else if (isMaintenance) {
      bg = Colors.orange.withOpacity(0.07);
      border = Colors.orange.withOpacity(0.25);
      textColor = Colors.orange;
      label = 'N/A';
      icon = Icons.build_rounded;
    } else {
      bg = const Color(0xFF1E293B);
      border = Colors.white12;
      textColor = Colors.white;
      label = '₹${price.toStringAsFixed(0)}/h';
      icon = Icons.ev_station_rounded;
    }
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: border, width: isSelected ? 1.8 : 1),
          boxShadow: isSelected
              ? [
            BoxShadow(
                color: const Color(0xFF00C853).withOpacity(0.2),
                blurRadius: 8,
                spreadRadius: 1)
          ]
              : [],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: textColor, size: 22),
            const SizedBox(height: 5),
            Text('Slot $slotNumber',
                style: TextStyle(
                    color: textColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 12)),
            Text(label,
                style: TextStyle(
                    color: textColor.withOpacity(0.65), fontSize: 10)),
          ],
        ),
      ),
    );
  }
}

class BookingConfirmationScreen extends StatefulWidget {
  final String stationTitle;
  final int slotNumber;
  final int duration;
  final double totalAmount;
  final DateTime scheduledStart;

  const BookingConfirmationScreen({
    super.key,
    required this.stationTitle,
    required this.slotNumber,
    required this.duration,
    required this.totalAmount,
    required this.scheduledStart,
  });

  @override
  State<BookingConfirmationScreen> createState() =>
      _BookingConfirmationScreenState();
}

class _BookingConfirmationScreenState
    extends State<BookingConfirmationScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scaleAnim;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 600));
    _scaleAnim =
        CurvedAnimation(parent: _ctrl, curve: Curves.elasticOut);
    _fadeAnim = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final endTime =
    widget.scheduledStart.add(Duration(hours: widget.duration));
    final dateStr =
    DateFormat('EEE, MMM d yyyy').format(widget.scheduledStart);
    final timeStr =
        '${DateFormat('h:mm a').format(widget.scheduledStart)} – ${DateFormat('h:mm a').format(endTime)}';

    return Scaffold(
      backgroundColor: Colors.black87,
      body: Center(
        child: FadeTransition(
          opacity: _fadeAnim,
          child: ScaleTransition(
            scale: _scaleAnim,
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 28),
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: const Color(0xFF0F172A),
                borderRadius: BorderRadius.circular(28),
                border: Border.all(
                    color: const Color(0xFF00C853).withOpacity(0.3)),
                boxShadow: [
                  BoxShadow(
                      color: const Color(0xFF00C853).withOpacity(0.1),
                      blurRadius: 40,
                      spreadRadius: 4),
                  BoxShadow(
                      color: Colors.black.withOpacity(0.5),
                      blurRadius: 20),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color:
                      const Color(0xFF00C853).withOpacity(0.12),
                      shape: BoxShape.circle,
                      border: Border.all(
                          color:
                          const Color(0xFF00C853).withOpacity(0.4),
                          width: 2),
                    ),
                    child: const Icon(Icons.check_rounded,
                        color: Color(0xFF00C853), size: 44),
                  ),
                  const SizedBox(height: 20),
                  const Text('Booking Confirmed!',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Text(widget.stationTitle,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          color: Colors.white54, fontSize: 13),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 24),
                  _ConfirmRow(
                      icon: Icons.ev_station_rounded,
                      label: 'Slot',
                      value: '#${widget.slotNumber}'),
                  const SizedBox(height: 10),
                  _ConfirmRow(
                      icon: Icons.calendar_today_rounded,
                      label: 'Date',
                      value: dateStr),
                  const SizedBox(height: 10),
                  _ConfirmRow(
                      icon: Icons.access_time_rounded,
                      label: 'Time',
                      value: timeStr),
                  const SizedBox(height: 10),
                  _ConfirmRow(
                    icon: Icons.currency_rupee_rounded,
                    label: 'Paid',
                    value:
                    '₹${widget.totalAmount.toStringAsFixed(0)}',
                    valueColor: const Color(0xFF00C853),
                  ),
                  const SizedBox(height: 28),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF00C853),
                        foregroundColor: Colors.black,
                        padding:
                        const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                      ),
                      child: const Text('Done',
                          style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ConfirmRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color valueColor;
  const _ConfirmRow(
      {required this.icon,
        required this.label,
        required this.value,
        this.valueColor = Colors.white});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding:
      const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
          color: const Color(0xFF1E293B),
          borderRadius: BorderRadius.circular(10)),
      child: Row(children: [
        Icon(icon, color: Colors.white38, size: 18),
        const SizedBox(width: 10),
        Text(label,
            style:
            const TextStyle(color: Colors.white54, fontSize: 13)),
        const Spacer(),
        Text(value,
            style: TextStyle(
                color: valueColor,
                fontWeight: FontWeight.w600,
                fontSize: 13)),
      ]),
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
            letterSpacing: 1.2));
  }
}