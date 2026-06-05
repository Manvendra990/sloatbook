import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:slotbooking/Admin/admin_provide.dart';

// import '../../../data/models/ground_model.dart';
import '../../../data/models/slot_model.dart';

class SlotManagementScreen extends ConsumerWidget {
  const SlotManagementScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final groundsAsync = ref.watch(adminGroundsProvider);
    final selectedGroundId = ref.watch(selectedGroundForSlotsProvider);
    final selectedDate = ref.watch(slotDateProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Slots & pricing'), centerTitle: false),
      body: Column(
        children: [
          // Ground picker
          groundsAsync.when(
            loading: () => const LinearProgressIndicator(),
            error: (e, _) => const SizedBox.shrink(),
            data: (grounds) => Container(
              height: 56,
              color: Theme.of(context).colorScheme.surface,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                itemCount: grounds.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (_, i) {
                  final g = grounds[i];
                  final selected = g.id == selectedGroundId;
                  return ChoiceChip(
                    label: Text(g.name),
                    selected: selected,
                    onSelected: (_) =>
                        ref
                                .read(selectedGroundForSlotsProvider.notifier)
                                .state =
                            g.id,
                  );
                },
              ),
            ),
          ),
          // Date picker strip
          _DateStrip(
            selected: selectedDate,
            onSelect: (d) => ref.read(slotDateProvider.notifier).state = d,
          ),
          const Divider(height: 1),
          // Slot grid
          Expanded(
            child: selectedGroundId == null
                ? const _NoGroundSelected()
                : _SlotGrid(groundId: selectedGroundId),
          ),
        ],
      ),
      floatingActionButton: selectedGroundId == null
          ? null
          : FloatingActionButton.extended(
              onPressed: () =>
                  _showAddSlotsSheet(context, ref, selectedGroundId),
              icon: const Icon(Icons.add),
              label: const Text('Generate slots'),
            ),
    );
  }

  void _showAddSlotsSheet(
    BuildContext context,
    WidgetRef ref,
    String groundId,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _GenerateSlotsSheet(groundId: groundId, ref: ref),
    );
  }
}

class _DateStrip extends StatelessWidget {
  final DateTime selected;
  final void Function(DateTime) onSelect;

  const _DateStrip({required this.selected, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    final days = List.generate(14, (i) {
      return DateTime.now().add(Duration(days: i));
    });
    return SizedBox(
      height: 72,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        itemCount: days.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final day = days[i];
          final isSelected =
              day.day == selected.day &&
              day.month == selected.month &&
              day.year == selected.year;
          final isToday = day.day == DateTime.now().day;
          return GestureDetector(
            onTap: () => onSelect(day),
            child: Container(
              width: 48,
              decoration: BoxDecoration(
                color: isSelected
                    ? Theme.of(context).colorScheme.primary
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(10),
                border: isSelected
                    ? null
                    : Border.all(color: Colors.grey[300]!),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    _weekday(day),
                    style: TextStyle(
                      fontSize: 10,
                      color: isSelected ? Colors.white : Colors.grey[500],
                    ),
                  ),
                  Text(
                    day.day.toString(),
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: isSelected ? Colors.white : null,
                    ),
                  ),
                  if (isToday)
                    Container(
                      width: 4,
                      height: 4,
                      decoration: BoxDecoration(
                        color: isSelected
                            ? Colors.white
                            : Theme.of(context).colorScheme.primary,
                        shape: BoxShape.circle,
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  String _weekday(DateTime d) {
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return days[d.weekday - 1];
  }
}

class _SlotGrid extends ConsumerWidget {
  final String groundId;
  const _SlotGrid({required this.groundId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final slotsAsync = ref.watch(slotsProvider);

    return slotsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (slots) => slots.isEmpty
          ? const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.schedule_outlined, size: 52, color: Colors.grey),
                  SizedBox(height: 8),
                  Text('No slots for this date'),
                  Text(
                    'Tap "Generate slots" to add',
                    style: TextStyle(color: Colors.grey, fontSize: 13),
                  ),
                ],
              ),
            )
          : GridView.builder(
              padding: const EdgeInsets.all(16),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
                childAspectRatio: 1.1,
              ),
              itemCount: slots.length,
              itemBuilder: (_, i) => _SlotTile(slot: slots[i], ref: ref),
            ),
    );
  }
}

class _SlotTile extends StatelessWidget {
  final SlotModel slot;
  final WidgetRef ref;
  const _SlotTile({required this.slot, required this.ref});

  @override
  Widget build(BuildContext context) {
    final color = switch (slot.status) {
      'available' => Colors.green,
      'booked' => Colors.grey,
      'blocked' => Colors.red,
      _ => Colors.grey,
    };

    return GestureDetector(
      onLongPress: () => _showSlotActions(context),
      child: Container(
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          border: Border.all(color: color.withOpacity(0.4)),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              slot.startTime,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: color,
                fontSize: 13,
              ),
            ),
            Text(
              slot.endTime,
              style: TextStyle(color: color.withOpacity(0.7), fontSize: 11),
            ),
            const SizedBox(height: 4),
            Text(
              '₹${slot.price.toStringAsFixed(0)}',
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showSlotActions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '${slot.startTime} – ${slot.endTime}',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 16),
            if (slot.status != 'booked') ...[
              ListTile(
                leading: const Icon(Icons.block, color: Colors.red),
                title: Text(slot.isBlocked ? 'Unblock slot' : 'Block slot'),
                onTap: () async {
                  Navigator.pop(context);
                  await ref
                      .read(slotDatasourceProvider)
                      .updateSlotStatus(
                        slot.id,
                        slot.isBlocked ? 'available' : 'blocked',
                      );
                },
              ),
            ],
            ListTile(
              leading: const Icon(Icons.delete_outline, color: Colors.red),
              title: const Text('Delete slot'),
              onTap: () async {
                Navigator.pop(context);
                await ref.read(slotDatasourceProvider).deleteSlot(slot.id);
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _GenerateSlotsSheet extends StatefulWidget {
  final String groundId;
  final WidgetRef ref;
  const _GenerateSlotsSheet({required this.groundId, required this.ref});

  @override
  State<_GenerateSlotsSheet> createState() => _GenerateSlotsSheetState();
}

class _GenerateSlotsSheetState extends State<_GenerateSlotsSheet> {
  int _startHour = 6;
  int _endHour = 22;
  int _slotDuration = 60; // minutes
  final _priceCtrl = TextEditingController(text: '500');
  bool _loading = false;

  Future<void> _generate() async {
    setState(() => _loading = true);
    final date = widget.ref.read(slotDateProvider);
    final slots = <SlotModel>[];
    var current = DateTime(date.year, date.month, date.day, _startHour);
    final end = DateTime(date.year, date.month, date.day, _endHour);

    while (current.isBefore(end)) {
      final next = current.add(Duration(minutes: _slotDuration));
      if (next.isAfter(end)) break;
      slots.add(
        SlotModel(
          id: '',
          groundId: widget.groundId,
          date: date,
          startTime:
              '${current.hour.toString().padLeft(2, '0')}:${current.minute.toString().padLeft(2, '0')}',
          endTime:
              '${next.hour.toString().padLeft(2, '0')}:${next.minute.toString().padLeft(2, '0')}',
          price: double.tryParse(_priceCtrl.text) ?? 500,
          status: 'available',
        ),
      );
      current = next;
    }

    await widget.ref.read(slotDatasourceProvider).bulkAddSlots(slots);
    setState(() => _loading = false);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        16,
        16,
        16,
        MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Generate slots',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<int>(
                  value: _startHour,
                  decoration: _decor('Start hour'),
                  items: List.generate(18, (i) => i + 5)
                      .map(
                        (h) => DropdownMenuItem(
                          value: h,
                          child: Text('${h.toString().padLeft(2, '0')}:00'),
                        ),
                      )
                      .toList(),
                  onChanged: (v) => setState(() => _startHour = v!),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: DropdownButtonFormField<int>(
                  value: _endHour,
                  decoration: _decor('End hour'),
                  items: List.generate(18, (i) => i + 5)
                      .map(
                        (h) => DropdownMenuItem(
                          value: h,
                          child: Text('${h.toString().padLeft(2, '0')}:00'),
                        ),
                      )
                      .toList(),
                  onChanged: (v) => setState(() => _endHour = v!),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<int>(
            value: _slotDuration,
            decoration: _decor('Slot duration'),
            items: const [
              DropdownMenuItem(value: 30, child: Text('30 minutes')),
              DropdownMenuItem(value: 60, child: Text('1 hour')),
              DropdownMenuItem(value: 90, child: Text('1.5 hours')),
              DropdownMenuItem(value: 120, child: Text('2 hours')),
            ],
            onChanged: (v) => setState(() => _slotDuration = v!),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _priceCtrl,
            keyboardType: TextInputType.number,
            decoration: _decor('Price per slot (₹)'),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            height: 46,
            child: ElevatedButton(
              onPressed: _loading ? null : _generate,
              child: _loading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Generate'),
            ),
          ),
        ],
      ),
    );
  }

  InputDecoration _decor(String label) => InputDecoration(
    labelText: label,
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
  );
}

class _NoGroundSelected extends StatelessWidget {
  const _NoGroundSelected();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.touch_app_outlined, size: 52, color: Colors.grey),
          SizedBox(height: 8),
          Text('Select a ground above'),
        ],
      ),
    );
  }
}
