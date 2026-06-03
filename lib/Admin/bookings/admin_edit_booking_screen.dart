import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:slotbooking/Admin/navbar/adminNavbar.dart';

class AddSlotScreen extends StatefulWidget {
  const AddSlotScreen({super.key});

  @override
  State<AddSlotScreen> createState() => _AddSlotScreenState();
}

class _AddSlotScreenState extends State<AddSlotScreen> {
  static const _green = Color(0xFF0D5C3A);
  static const _greenLight = Color(0xFFE8F5EE);

  bool _isLoading = false;
  bool _isSaving = false;

  // Form state
  String? _selectedGroundId;
  String? _selectedGroundName;
  DateTime _slotDate = DateTime.now();
  TimeOfDay _startTime = const TimeOfDay(hour: 6, minute: 0);
  TimeOfDay _endTime = const TimeOfDay(hour: 7, minute: 0);
  final _amountCtrl = TextEditingController();

  List<Map<String, dynamic>> _grounds = [];

  // Slots created in this session
  final List<_SlotEntry> _createdSlots = [];

  @override
  void initState() {
    super.initState();
    _loadGrounds();
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    super.dispose();
  }

  // ── Load admin's grounds ───────────────────────────────────────────────────
  Future<void> _loadGrounds() async {
    setState(() => _isLoading = true);
    try {
      final uid = FirebaseAuth.instance.currentUser!.uid;
      final snap = await FirebaseFirestore.instance
          .collection('grounds')
          .where('adminId', isEqualTo: uid)
          .get();

      setState(() {
        _grounds = snap.docs
            .map((d) => {'id': d.id, 'name': d.data()['name'] ?? 'Ground'})
            .toList();
        if (_grounds.isNotEmpty) {
          _selectedGroundId = _grounds[0]['id'];
          _selectedGroundName = _grounds[0]['name'];
        }
      });
    } catch (e) {
      _showSnack('Failed to load grounds: $e', Colors.red[700]!);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ── Pick date ──────────────────────────────────────────────────────────────
  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _slotDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 90)),
      builder: (ctx, child) => Theme(
        data: Theme.of(
          ctx,
        ).copyWith(colorScheme: const ColorScheme.light(primary: _green)),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _slotDate = picked);
  }

  // ── Pick time ──────────────────────────────────────────────────────────────
  Future<void> _pickTime({required bool isStart}) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: isStart ? _startTime : _endTime,
      builder: (ctx, child) => Theme(
        data: Theme.of(
          ctx,
        ).copyWith(colorScheme: const ColorScheme.light(primary: _green)),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() {
        if (isStart) {
          _startTime = picked;
        } else {
          _endTime = picked;
        }
      });
    }
  }

  // ── Validate slot ──────────────────────────────────────────────────────────
  bool _validateSlot() {
    if (_selectedGroundId == null) {
      _showSnack('Please select a ground.', Colors.orange[700]!);
      return false;
    }
    if (_amountCtrl.text.trim().isEmpty) {
      _showSnack('Please enter slot amount.', Colors.orange[700]!);
      return false;
    }
    final startMinutes = _startTime.hour * 60 + _startTime.minute;
    final endMinutes = _endTime.hour * 60 + _endTime.minute;
    if (endMinutes <= startMinutes) {
      _showSnack('End time must be after start time.', Colors.orange[700]!);
      return false;
    }
    return true;
  }

  // ── Build DateTime from date + TimeOfDay ───────────────────────────────────
  DateTime _toDateTime(DateTime date, TimeOfDay time) {
    return DateTime(date.year, date.month, date.day, time.hour, time.minute);
  }

  // ── Add slot to session list ───────────────────────────────────────────────
  void _addToList() {
    if (!_validateSlot()) return;
    setState(() {
      _createdSlots.add(
        _SlotEntry(
          groundId: _selectedGroundId!,
          groundName: _selectedGroundName!,
          date: _slotDate,
          startTime: _startTime,
          endTime: _endTime,
          amount: int.tryParse(_amountCtrl.text.trim()) ?? 0,
        ),
      );
      // Reset time fields for next slot
      _startTime = _endTime;
      _endTime = TimeOfDay(
        hour: (_endTime.hour + 1).clamp(0, 23),
        minute: _endTime.minute,
      );
      _amountCtrl.clear();
    });
  }

  // ── Save all slots to Firestore ────────────────────────────────────────────
  Future<void> _saveSlots() async {
    if (_createdSlots.isEmpty) {
      _showSnack('Add at least one slot before saving.', Colors.orange[700]!);
      return;
    }
    setState(() => _isSaving = true);
    try {
      final uid = FirebaseAuth.instance.currentUser!.uid;
      final batch = FirebaseFirestore.instance.batch();

      for (final slot in _createdSlots) {
        final ref = FirebaseFirestore.instance.collection('bookings').doc();
        batch.set(ref, {
          'adminId': uid,
          'groundId': slot.groundId,
          'slotDate': Timestamp.fromDate(slot.date),
          'startTime': Timestamp.fromDate(
            _toDateTime(slot.date, slot.startTime),
          ),
          'endTime': Timestamp.fromDate(_toDateTime(slot.date, slot.endTime)),
          'amount': slot.amount,
          'bookingStatus': 'available',
          'paymentStatus': 'unpaid',
          'userId': '',
          'createdAt': FieldValue.serverTimestamp(),
        });
      }

      await batch.commit();

      if (!mounted) return;
      _showSuccessDialog(_createdSlots.length);
    } catch (e) {
      if (!mounted) return;
      _showSnack('Failed to save slots: $e', Colors.red[700]!);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _showSnack(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  void _showSuccessDialog(int count) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: const BoxDecoration(
                  color: _greenLight,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check_circle_rounded,
                  color: _green,
                  size: 42,
                ),
              ),
              const SizedBox(height: 18),
              Text(
                '$count Slot${count > 1 ? 's' : ''} Created!',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF0E1A13),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Your slots have been saved and are now available for booking.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey[600],
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                    setState(() => _createdSlots.clear());
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _green,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(50),
                    ),
                  ),
                  child: const Text(
                    'Add More Slots',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              TextButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  context.go('/admin/bookings');
                },
                child: Text(
                  'View Bookings',
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F3F0),
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // ── App bar ──────────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 8, 16, 4),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(
                      Icons.arrow_back_ios_new_rounded,
                      color: _green,
                    ),
                    onPressed: () => context.pop(),
                  ),
                  const Text(
                    'Manage Slots',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF0E1A13),
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.notifications_none_rounded),
                    color: Colors.grey[700],
                    onPressed: () {},
                  ),
                ],
              ),
            ),

            // ── Body ─────────────────────────────────────────────────────────
            Expanded(
              child: _isLoading
                  ? const Center(
                      child: CircularProgressIndicator(color: _green),
                    )
                  : SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // ── Create slot card ─────────────────────────────
                          _Card(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: _greenLight,
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: const Icon(
                                        Icons.add_circle_outline_rounded,
                                        color: _green,
                                        size: 20,
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    const Text(
                                      'Create New Slot',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w800,
                                        color: Color(0xFF0E1A13),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 18),

                                // Ground picker
                                _fieldLabel('Select Ground'),
                                const SizedBox(height: 8),
                                _grounds.isEmpty
                                    ? Container(
                                        padding: const EdgeInsets.all(14),
                                        decoration: BoxDecoration(
                                          color: Colors.orange[50],
                                          borderRadius: BorderRadius.circular(
                                            10,
                                          ),
                                          border: Border.all(
                                            color: Colors.orange[200]!,
                                          ),
                                        ),
                                        child: Row(
                                          children: [
                                            Icon(
                                              Icons.warning_amber_rounded,
                                              color: Colors.orange[700],
                                              size: 18,
                                            ),
                                            const SizedBox(width: 8),
                                            Expanded(
                                              child: Text(
                                                'No grounds found. Add a ground first.',
                                                style: TextStyle(
                                                  fontSize: 13,
                                                  color: Colors.orange[800],
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      )
                                    : _buildGroundDropdown(),

                                const SizedBox(height: 14),

                                // Date picker
                                _fieldLabel('Slot Date'),
                                const SizedBox(height: 8),
                                _buildDateTile(),
                                const SizedBox(height: 14),

                                // Time pickers
                                _fieldLabel('Time Range'),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    Expanded(
                                      child: _buildTimeTile(
                                        label: 'Start',
                                        time: _startTime,
                                        onTap: () => _pickTime(isStart: true),
                                      ),
                                    ),
                                    Padding(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                      ),
                                      child: Icon(
                                        Icons.arrow_forward_rounded,
                                        color: Colors.grey[400],
                                        size: 18,
                                      ),
                                    ),
                                    Expanded(
                                      child: _buildTimeTile(
                                        label: 'End',
                                        time: _endTime,
                                        onTap: () => _pickTime(isStart: false),
                                      ),
                                    ),
                                  ],
                                ),

                                const SizedBox(height: 14),

                                // Amount
                                _fieldLabel('Amount (₹)'),
                                const SizedBox(height: 8),
                                TextFormField(
                                  controller: _amountCtrl,
                                  keyboardType: TextInputType.number,
                                  style: const TextStyle(fontSize: 15),
                                  decoration: InputDecoration(
                                    hintText: 'e.g. 600',
                                    hintStyle: TextStyle(
                                      color: Colors.grey[400],
                                      fontSize: 14,
                                    ),
                                    prefixIcon: const Icon(
                                      Icons.currency_rupee_rounded,
                                      size: 18,
                                      color: _green,
                                    ),
                                    filled: true,
                                    fillColor: const Color(0xFFF8FAFB),
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 14,
                                      vertical: 13,
                                    ),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(10),
                                      borderSide: BorderSide(
                                        color: Colors.grey[200]!,
                                        width: 1,
                                      ),
                                    ),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(10),
                                      borderSide: BorderSide(
                                        color: Colors.grey[200]!,
                                        width: 1,
                                      ),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(10),
                                      borderSide: const BorderSide(
                                        color: _green,
                                        width: 1.5,
                                      ),
                                    ),
                                  ),
                                ),

                                const SizedBox(height: 16),

                                // Duration preview
                                _buildDurationPreview(),

                                const SizedBox(height: 16),

                                // Add to list button
                                SizedBox(
                                  width: double.infinity,
                                  height: 48,
                                  child: OutlinedButton.icon(
                                    onPressed: _addToList,
                                    icon: const Icon(
                                      Icons.add_rounded,
                                      size: 18,
                                    ),
                                    label: const Text(
                                      'Add to List',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: _green,
                                      side: const BorderSide(
                                        color: _green,
                                        width: 1.5,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),

                          // ── Pending slots list ───────────────────────────
                          if (_createdSlots.isNotEmpty) ...[
                            const SizedBox(height: 16),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Slots to Save (${_createdSlots.length})',
                                  style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF0E1A13),
                                  ),
                                ),
                                GestureDetector(
                                  onTap: () =>
                                      setState(() => _createdSlots.clear()),
                                  child: Text(
                                    'Clear all',
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: Colors.red[400],
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            ..._createdSlots.asMap().entries.map((e) {
                              final i = e.key;
                              final slot = e.value;
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: _SlotListItem(
                                  slot: slot,
                                  index: i,
                                  onDelete: () =>
                                      setState(() => _createdSlots.removeAt(i)),
                                ),
                              );
                            }),

                            const SizedBox(height: 16),

                            // Save all
                            SizedBox(
                              width: double.infinity,
                              height: 52,
                              child: ElevatedButton.icon(
                                onPressed: _isSaving ? null : _saveSlots,
                                icon: _isSaving
                                    ? const SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                          color: Colors.white,
                                          strokeWidth: 2.5,
                                        ),
                                      )
                                    : const Icon(
                                        Icons.cloud_upload_rounded,
                                        size: 20,
                                      ),
                                label: Text(
                                  _isSaving
                                      ? 'Saving...'
                                      : 'Save ${_createdSlots.length} Slot${_createdSlots.length > 1 ? 's' : ''}',
                                  style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: _green,
                                  foregroundColor: Colors.white,
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  disabledBackgroundColor: _green.withOpacity(
                                    0.5,
                                  ),
                                ),
                              ),
                            ),
                          ],

                          const SizedBox(height: 16),
                        ],
                      ),
                    ),
            ),

            // ── Nav bar ──────────────────────────────────────────────────────
            const AdminNavBar(currentIndex: 2),
          ],
        ),
      ),
    );
  }

  Widget _buildGroundDropdown() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFB),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey[200]!, width: 1),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _selectedGroundId,
          isExpanded: true,
          icon: Icon(
            Icons.keyboard_arrow_down_rounded,
            color: Colors.grey[500],
          ),
          style: const TextStyle(
            fontSize: 14,
            color: Color(0xFF0E1A13),
            fontWeight: FontWeight.w500,
          ),
          items: _grounds
              .map(
                (g) => DropdownMenuItem<String>(
                  value: g['id'] as String,
                  child: Text(g['name'] as String),
                ),
              )
              .toList(),
          onChanged: (v) {
            setState(() {
              _selectedGroundId = v;
              _selectedGroundName = _grounds.firstWhere(
                (g) => g['id'] == v,
              )['name'];
            });
          },
        ),
      ),
    );
  }

  Widget _buildDateTile() {
    return GestureDetector(
      onTap: _pickDate,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFB),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.grey[200]!, width: 1),
        ),
        child: Row(
          children: [
            const Icon(Icons.calendar_today_rounded, size: 18, color: _green),
            const SizedBox(width: 10),
            Text(
              DateFormat('EEE, dd MMM yyyy').format(_slotDate),
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Color(0xFF0E1A13),
              ),
            ),
            const Spacer(),
            Icon(Icons.chevron_right_rounded, color: Colors.grey[400]),
          ],
        ),
      ),
    );
  }

  Widget _buildTimeTile({
    required String label,
    required TimeOfDay time,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFB),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.grey[200]!, width: 1),
        ),
        child: Row(
          children: [
            Icon(Icons.access_time_rounded, size: 16, color: _green),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(fontSize: 10, color: Colors.grey[500]),
                ),
                Text(
                  time.format(context),
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF0E1A13),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDurationPreview() {
    final startMinutes = _startTime.hour * 60 + _startTime.minute;
    final endMinutes = _endTime.hour * 60 + _endTime.minute;
    final diffMinutes = endMinutes - startMinutes;
    final isValid = diffMinutes > 0;

    final hours = diffMinutes ~/ 60;
    final mins = diffMinutes % 60;
    final durationText = isValid
        ? (hours > 0 ? '${hours}h ${mins > 0 ? '${mins}m' : ''}' : '${mins}m')
        : 'Invalid time range';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: isValid ? _greenLight : Colors.red[50],
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(
            isValid ? Icons.timer_outlined : Icons.error_outline_rounded,
            size: 18,
            color: isValid ? _green : Colors.red[400],
          ),
          const SizedBox(width: 10),
          Text(
            isValid ? 'Duration: $durationText' : durationText,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: isValid ? _green : Colors.red[600],
            ),
          ),
          if (isValid && _amountCtrl.text.isNotEmpty) ...[
            const Spacer(),
            Text(
              '₹${_amountCtrl.text}',
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: _green,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _fieldLabel(String text) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: Colors.grey[700],
      ),
    );
  }
}

// ── Slot list item ────────────────────────────────────────────────────────────
class _SlotListItem extends StatelessWidget {
  final _SlotEntry slot;
  final int index;
  final VoidCallback onDelete;

  const _SlotListItem({
    required this.slot,
    required this.index,
    required this.onDelete,
  });

  static const _green = Color(0xFF0D5C3A);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE8F5EE), width: 1.5),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: const BoxDecoration(
              color: Color(0xFFE8F5EE),
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Text(
              '${index + 1}',
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: _green,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  slot.groundName,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF0E1A13),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${DateFormat('dd MMM').format(slot.date)}  •  ${slot.startTime.format(context)} – ${slot.endTime.format(context)}',
                  style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                ),
              ],
            ),
          ),
          Text(
            '₹${slot.amount}',
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: _green,
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: onDelete,
            child: Icon(Icons.close_rounded, size: 18, color: Colors.red[400]),
          ),
        ],
      ),
    );
  }
}

// ── Card wrapper ──────────────────────────────────────────────────────────────
class _Card extends StatelessWidget {
  final Widget child;
  const _Card({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );
  }
}

// ── Slot entry model ──────────────────────────────────────────────────────────
class _SlotEntry {
  final String groundId;
  final String groundName;
  final DateTime date;
  final TimeOfDay startTime;
  final TimeOfDay endTime;
  final int amount;

  const _SlotEntry({
    required this.groundId,
    required this.groundName,
    required this.date,
    required this.startTime,
    required this.endTime,
    required this.amount,
  });
}
