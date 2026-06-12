import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:slotbooking/data/datasources/slot_remote_datasource.dart';
import 'package:slotbooking/data/models/slot_model.dart';
import 'package:slotbooking/data/theam/app_theam.dart';
import 'package:slotbooking/shared/widgets/app_button.dart';
import 'package:slotbooking/shared/widgets/apptext.dart';

class SlotBookingScreen extends StatefulWidget {
  final String groundId;
  const SlotBookingScreen({super.key, required this.groundId});

  @override
  State<SlotBookingScreen> createState() => _SlotBookingScreenState();
}

class _SlotBookingScreenState extends State<SlotBookingScreen> {
  final _repo = SlotRepository();

  DateTime _selectedDate = DateTime.now();
  SlotModel? _selectedSlot;
  bool _isBooking = false;

  String get _dateKey => DateFormat('yyyy-MM-dd').format(_selectedDate);

  int _parsePrice(dynamic raw) {
    if (raw == null) return 0;
    if (raw is int) return raw;
    if (raw is double) return raw.toInt();
    if (raw is String) return int.tryParse(raw) ?? 0;
    return 0;
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 30)),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.light(
            primary: AppTheme.primaryRed,
            onPrimary: Colors.white,
            surface: Colors.white,
            onSurface: AppTheme.textPrimary,
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() {
        _selectedDate = picked;
        _selectedSlot = null;
      });
    }
  }

  Future<void> _bookSlot(Map<String, dynamic> groundData) async {
    if (_selectedSlot == null) return;
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _showSnack('Please login to book a slot.');
      return;
    }

    final slot = _selectedSlot!;
    final amount = slot.amount > 0
        ? slot.amount
        : _parsePrice(groundData['pricePerHour']);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: AppText.titleLarge('Confirm Booking'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _ConfirmRow(
              icon: Icons.calendar_today_outlined,
              label: 'Date',
              value: DateFormat('EEE, MMM d yyyy').format(_selectedDate),
            ),
            const SizedBox(height: 8),
            _ConfirmRow(
              icon: Icons.access_time_rounded,
              label: 'Slot',
              value: slot.label,
            ),
            const SizedBox(height: 8),
            _ConfirmRow(
              icon: Icons.payments_outlined,
              label: 'Amount',
              value: '₹$amount',
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: AppText.bodyMedium('Cancel'),
          ),
          AppButton.primary(
            label: 'Continue to Payment',
            width: null,
            height: 44,
            onPressed: () => Navigator.pop(ctx, true),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;
    context.go(
      '/user/payment',
      extra: slot.toPaymentPayload(
        groundId: widget.groundId,
        groundName: groundData['name'] as String? ?? '',
        userId: user.uid,
        userPhone: user.phoneNumber ?? '',
        date: _dateKey,
      ),
    );
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: AppTheme.error,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      // ── AppBar — matches image: back + title + bell ───────────────────────
      appBar: AppBar(
        backgroundColor: AppTheme.background,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: GestureDetector(
          onTap: () => context.pop(),
          child: const Icon(
            Icons.arrow_back,
            color: AppTheme.textPrimary,
            size: 24,
          ),
        ),
        title: const Text(
          'Book a Slot',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: AppTheme.textPrimary,
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Icon(
              Icons.notifications_outlined,
              color: AppTheme.textPrimary,
              size: 24,
            ),
          ),
        ],
      ),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: _repo.groundStream(widget.groundId),
        builder: (context, groundSnap) {
          if (!groundSnap.hasData) {
            return const Center(
              child: CircularProgressIndicator(color: AppTheme.primaryRed),
            );
          }
          final groundData = groundSnap.data!.data() ?? {};
          final pricePerHour = _parsePrice(groundData['pricePerHour']);

          return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: _repo.bookingsStream(widget.groundId),
            builder: (context, bookingSnap) {
              if (bookingSnap.connectionState == ConnectionState.waiting &&
                  !bookingSnap.hasData) {
                return const Center(
                  child: CircularProgressIndicator(color: AppTheme.primaryRed),
                );
              }

              final slots = _repo.mergeSlots(
                selectedDate: _selectedDate,
                bookingDocs: bookingSnap.data?.docs ?? [],
                pricePerHour: pricePerHour,
              );

              return Column(
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildGroundCard(groundData),
                          const SizedBox(height: 24),
                          _buildDateSection(),
                          const SizedBox(height: 20),
                          _buildLegend(),
                          const SizedBox(height: 14),
                          _buildSlotGrid(slots),
                          const SizedBox(height: 20),
                          _buildGroundBanner(groundData),
                          const SizedBox(height: 20),
                        ],
                      ),
                    ),
                  ),
                  _buildBottomBar(groundData),
                ],
              );
            },
          );
        },
      ),
    );
  }

  // ── Ground card — matches image layout ────────────────────────────────────
  Widget _buildGroundCard(Map<String, dynamic> data) {
    final price = _parsePrice(data['pricePerHour']);
    final name = data['name'] as String? ?? 'Ground';
    final address = data['address'] as String? ?? '';
    final city = data['city'] as String? ?? '';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          // Icon badge
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: AppTheme.lightRed,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.sports_cricket_rounded,
              color: AppTheme.primaryRed,
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          // Name + address
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '$address, $city'.toUpperCase(),
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5,
                    color: AppTheme.textSecondary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          // Price
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '₹$price',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.primaryRed,
                ),
              ),
              Text(
                'per hour',
                style: TextStyle(fontSize: 10, color: AppTheme.textSecondary),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Date section — header row + horizontal scroller ───────────────────────
  Widget _buildDateSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // "Select Date" + "Pick Date" on same row
        Row(
          children: [
            const Text(
              'Select Date',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppTheme.textPrimary,
              ),
            ),
            const Spacer(),
            GestureDetector(
              onTap: _pickDate,
              child: Row(
                children: [
                  Icon(
                    Icons.calendar_month_rounded,
                    size: 16,
                    color: AppTheme.primaryRed,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Pick Date',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.primaryRed,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // Horizontal date list
        SizedBox(
          height: 76,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: 14,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (context, i) {
              final date = DateTime.now().add(Duration(days: i));
              final isSelected =
                  _dateKey == DateFormat('yyyy-MM-dd').format(date);
              final isToday = i == 0;

              return GestureDetector(
                onTap: () => setState(() {
                  _selectedDate = date;
                  _selectedSlot = null;
                }),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  width: 56,
                  decoration: BoxDecoration(
                    color: isSelected ? AppTheme.primaryRed : AppTheme.surface,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: isSelected
                          ? AppTheme.primaryRed
                          : Colors.grey.shade200,
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        DateFormat('EEE').format(date),
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: isSelected
                              ? Colors.white.withOpacity(0.85)
                              : AppTheme.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        DateFormat('d').format(date),
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: isSelected
                              ? Colors.white
                              : AppTheme.textPrimary,
                        ),
                      ),
                      if (isToday)
                        Container(
                          width: 4,
                          height: 4,
                          decoration: BoxDecoration(
                            color: isSelected
                                ? Colors.white
                                : AppTheme.primaryRed,
                            shape: BoxShape.circle,
                          ),
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),

        const SizedBox(height: 10),

        // Full date label
        Row(
          children: [
            Icon(
              Icons.calendar_today_outlined,
              size: 14,
              color: AppTheme.textSecondary,
            ),
            const SizedBox(width: 6),
            Text(
              DateFormat('EEEE, MMMM d, yyyy').format(_selectedDate),
              style: TextStyle(
                fontSize: 13,
                color: AppTheme.textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ── Legend — circle icons matching image ──────────────────────────────────
  Widget _buildLegend() {
    return Row(
      children: [
        // Available — empty circle
        _LegendItem(
          child: Container(
            width: 16,
            height: 16,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Colors.grey.shade400, width: 1.5),
            ),
          ),
          label: 'Available',
        ),
        const SizedBox(width: 16),
        // Selected — filled red circle
        _LegendItem(
          child: Container(
            width: 16,
            height: 16,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: AppTheme.primaryRed,
            ),
          ),
          label: 'Selected',
        ),
        const SizedBox(width: 16),
        // Booked — filled grey circle
        _LegendItem(
          child: Container(
            width: 16,
            height: 16,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.grey.shade300,
            ),
          ),
          label: 'Booked',
        ),
      ],
    );
  }

  // ── Slot grid — matches image exactly ────────────────────────────────────
  Widget _buildSlotGrid(List<SlotModel> slots) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: 2.0,
      ),
      itemCount: slots.length,
      itemBuilder: (context, i) {
        final slot = slots[i];
        final isSelected = _selectedSlot?.slotId == slot.slotId;
        final isBooked = !slot.isAvailable;
        final isPast = slot.isPast;
        final disabled = slot.isDisabled;

        // ── Colors per state ──────────────────────────────────────────────
        Color bgColor, borderColor;
        Color timeColor, priceColor, durationColor;

        if (isPast && slot.isAvailable) {
          // past-available: greyed text, no border highlight
          bgColor = AppTheme.surface;
          borderColor = Colors.grey.shade200;
          timeColor = Colors.grey.shade400;
          priceColor = Colors.grey.shade400;
          durationColor = Colors.grey.shade400;
        } else if (isBooked) {
          bgColor = AppTheme.surface;
          borderColor = Colors.grey.shade200;
          timeColor = Colors.grey.shade400;
          priceColor = Colors.grey.shade400;
          durationColor = Colors.grey.shade400;
        } else if (isSelected) {
          bgColor = AppTheme.surface;
          borderColor = AppTheme.primaryRed;
          timeColor = AppTheme.textPrimary;
          priceColor = AppTheme.primaryRed;
          durationColor = AppTheme.textSecondary;
        } else {
          bgColor = AppTheme.surface;
          borderColor = Colors.grey.shade200;
          timeColor = AppTheme.textPrimary;
          priceColor = AppTheme.textSecondary;
          durationColor = AppTheme.textSecondary;
        }

        return GestureDetector(
          onTap: disabled
              ? null
              : () => setState(() {
                  _selectedSlot = isSelected ? null : slot;
                }),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: borderColor,
                width: isSelected ? 1.5 : 1,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Time label — bold
                Text(
                  slot.label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: timeColor,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 6),
                // Price + duration row
                Row(
                  children: [
                    Text(
                      isBooked ? '' : '₹${slot.amount}',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: priceColor,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      slot.durationLabel,
                      style: TextStyle(fontSize: 12, color: durationColor),
                    ),
                    // Red dot when selected
                    if (isSelected) ...[
                      const Spacer(),
                      Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: AppTheme.primaryRed,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ── Ground banner image at bottom ─────────────────────────────────────────
  Widget _buildGroundBanner(Map<String, dynamic> data) {
    // final images = data['images'];
    // String? imageUrl;
    // if (images is String && images.isNotEmpty) {
    //   imageUrl = images;
    // } else if (images is List && images.isNotEmpty) {
    //   imageUrl = images.first as String?;
    // }

    final tagline =
        data['tagline'] as String? ??
        'Professional Turf • Floodlights included';

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Stack(
        children: [
          // Image or placeholder
          Image.asset(
            'assets/images/turfground.png',
            width: double.infinity,
            height: 160,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => _bannerPlaceholder(),
          ),

          // Dark gradient overlay
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.transparent, Colors.black.withOpacity(0.7)],
                ),
              ),
            ),
          ),

          // Tagline text
          Positioned(
            bottom: 14,
            left: 14,
            right: 14,
            child: Text(
              tagline,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _bannerPlaceholder() => Container(
    width: double.infinity,
    height: 160,
    decoration: BoxDecoration(
      color: Colors.grey.shade800,
      borderRadius: BorderRadius.circular(16),
    ),
    child: Center(
      child: Icon(Icons.stadium_rounded, size: 48, color: Colors.grey.shade600),
    ),
  );

  // ── Bottom bar ─────────────────────────────────────────────────────────────
  Widget _buildBottomBar(Map<String, dynamic> groundData) {
    final price = _parsePrice(groundData['pricePerHour']);
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.07),
            blurRadius: 12,
            offset: const Offset(0, -3),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_selectedSlot != null) ...[
            Row(
              children: [
                Icon(
                  Icons.access_time_rounded,
                  size: 16,
                  color: AppTheme.primaryRed,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    _selectedSlot!.label,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                ),
                Text(
                  '₹${_selectedSlot!.amount > 0 ? _selectedSlot!.amount : price}',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.primaryRed,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
          ],
          AppButton.primary(
            label: _selectedSlot == null
                ? 'Select a Slot to Continue'
                : 'Proceed to Payment',
            isLoading: _isBooking,
            disabled: _selectedSlot == null,
            onPressed: _selectedSlot == null
                ? null
                : () => _bookSlot(groundData),
          ),
        ],
      ),
    );
  }
}

// ── Legend item helper ────────────────────────────────────────────────────────
class _LegendItem extends StatelessWidget {
  final Widget child;
  final String label;
  const _LegendItem({required this.child, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        child,
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: AppTheme.textSecondary,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

// ── Confirm row ───────────────────────────────────────────────────────────────
class _ConfirmRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _ConfirmRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 16, color: AppTheme.primaryRed),
        const SizedBox(width: 8),
        AppText.bodyMedium('$label: '),
        Expanded(child: AppText.bodyLarge(value)),
      ],
    );
  }
}
