import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:slotbooking/Admin/admin_provide.dart';
import 'package:slotbooking/Admin/navbar/adminNavbar.dart';

import '../../../data/models/booking_model.dart';

class RevenueReportScreen extends ConsumerWidget {
  const RevenueReportScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filter = ref.watch(revenueFilterProvider);
    final revenueAsync = ref.watch(revenueDataProvider(filter));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Revenue report'),
        centerTitle: false,
        actions: [
          revenueAsync.maybeWhen(
            data: (bookings) => IconButton(
              icon: const Icon(Icons.download_outlined),
              tooltip: 'Export CSV',
              onPressed: () => _exportCsv(context, bookings),
            ),
            orElse: () => const SizedBox.shrink(),
          ),
        ],
      ),
      body: Column(
        children: [
          _FilterTabs(selected: filter, ref: ref),
          Expanded(
            child: revenueAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Error: $e')),
              data: (bookings) {
                final paid = bookings
                    .where((b) => b.paymentStatus == 'paid')
                    .toList();
                final total = paid.fold<double>(0, (s, b) => s + b.amount);
                return ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    _SummaryRow(total: total, count: paid.length),
                    const SizedBox(height: 20),
                    _BarChart(bookings: paid, filter: filter),
                    const SizedBox(height: 20),
                    const Text(
                      'Breakdown',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 10),
                    ...paid.map((b) => _RevenueRow(booking: b)),
                  ],
                );
              },
            ),
          ),
          const AdminNavBar(currentIndex: 4),
        ],
      ),
    );
  }

  Future<void> _exportCsv(
    BuildContext context,
    List<BookingModel> bookings,
  ) async {
    final rows = [
      ['Date', 'Ground', 'Time', 'Amount', 'Payment ID'],
      ...bookings.map(
        (b) => [
          DateFormat('yyyy-MM-dd').format(b.date),
          b.groundName,
          '${b.startTime}–${b.endTime}',
          b.amount.toStringAsFixed(2),
          b.razorpayPaymentId,
        ],
      ),
    ];
    final csv = rows.map((r) => r.join(',')).join('\n');
    final dir = await getApplicationDocumentsDirectory();
    final file = File(
      '${dir.path}/revenue_${DateTime.now().millisecondsSinceEpoch}.csv',
    );
    await file.writeAsString(csv);
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Saved to ${file.path}')));
    }
  }
}

class _FilterTabs extends StatelessWidget {
  final String selected;
  final WidgetRef ref;
  const _FilterTabs({required this.selected, required this.ref});

  @override
  Widget build(BuildContext context) {
    const filters = ['daily', 'weekly', 'monthly'];
    return Container(
      color: Theme.of(context).colorScheme.surface,
      child: Row(
        children: filters.map((f) {
          final sel = f == selected;
          return Expanded(
            child: GestureDetector(
              onTap: () => ref.read(revenueFilterProvider.notifier).state = f,
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: sel
                          ? Theme.of(context).colorScheme.primary
                          : Colors.transparent,
                      width: 2.5,
                    ),
                  ),
                ),
                alignment: Alignment.center,
                child: Text(
                  f[0].toUpperCase() + f.substring(1),
                  style: TextStyle(
                    fontWeight: sel ? FontWeight.w600 : FontWeight.normal,
                    color: sel
                        ? Theme.of(context).colorScheme.primary
                        : Colors.grey[600],
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  final double total;
  final int count;
  const _SummaryRow({required this.total, required this.count});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _MetricCard(
            label: 'Total revenue',
            value: '₹${total.toStringAsFixed(0)}',
            color: Colors.green,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _MetricCard(
            label: 'Paid bookings',
            value: count.toString(),
            color: Colors.blue,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _MetricCard(
            label: 'Avg per booking',
            value: count == 0 ? '₹0' : '₹${(total / count).toStringAsFixed(0)}',
            color: Colors.orange,
          ),
        ),
      ],
    );
  }
}

class _MetricCard extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _MetricCard({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 2),
          Text(label, style: TextStyle(fontSize: 11, color: Colors.grey[600])),
        ],
      ),
    );
  }
}

// Simple bar chart using only Flutter widgets
class _BarChart extends StatelessWidget {
  final List<BookingModel> bookings;
  final String filter;
  const _BarChart({required this.bookings, required this.filter});

  @override
  Widget build(BuildContext context) {
    if (bookings.isEmpty) return const SizedBox.shrink();

    // Group by day/week label
    final Map<String, double> grouped = {};
    for (final b in bookings) {
      final key = filter == 'daily'
          ? '${b.date.hour}:00'
          : filter == 'weekly'
          ? DateFormat('EEE').format(b.date)
          : DateFormat('d').format(b.date);
      grouped[key] = (grouped[key] ?? 0) + b.amount;
    }
    if (grouped.isEmpty) return const SizedBox.shrink();

    final maxVal = grouped.values.reduce((a, b) => a > b ? a : b);

    return Container(
      height: 160,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey[200]!),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: grouped.entries.map((e) {
          final ratio = maxVal > 0 ? e.value / maxVal : 0.0;
          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 3),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Container(
                    height: 100 * ratio,
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primary,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    e.key,
                    style: const TextStyle(fontSize: 9),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _RevenueRow extends StatelessWidget {
  final BookingModel booking;
  const _RevenueRow({required this.booking});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  booking.groundName,
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
                Text(
                  '${DateFormat('d MMM').format(booking.date)}  •  ${booking.startTime}',
                  style: TextStyle(color: Colors.grey[500], fontSize: 12),
                ),
              ],
            ),
          ),
          Text(
            '₹${booking.amount.toStringAsFixed(0)}',
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.green,
            ),
          ),
        ],
      ),
    );
  }
}
