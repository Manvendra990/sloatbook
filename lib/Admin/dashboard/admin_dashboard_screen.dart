import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:slotbooking/Admin/navbar/adminNavbar.dart';
import 'package:slotbooking/Admin/header/admin_header.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  bool _isMonthly = true;

  // hellooo
  static const _green = Color(0xFF0D5C3A);
  static const _greenLight = Color(0xFFE8F5EE);
  static const _bg = Color(0xFFF0F3F0);

  // ── Booking trend data ────────────────────────────────────────────────────
  final List<FlSpot> _weeklySpots = const [
    FlSpot(0, 8),
    FlSpot(1, 14),
    FlSpot(2, 10),
    FlSpot(3, 18),
    FlSpot(4, 22),
    FlSpot(5, 16),
    FlSpot(6, 24),
  ];
  final List<String> _weekLabels = const [
    'Mon',
    'Tue',
    'Wed',
    'Thu',
    'Fri',
    'Sat',
    'Sun',
  ];

  final List<FlSpot> _monthlySpots = const [
    FlSpot(0, 10),
    FlSpot(1, 18),
    FlSpot(2, 14),
    FlSpot(3, 22),
    FlSpot(4, 28),
    FlSpot(5, 24),
    FlSpot(6, 30),
    FlSpot(7, 26),
    FlSpot(8, 34),
    FlSpot(9, 38),
    FlSpot(10, 32),
    FlSpot(11, 44),
  ];
  final List<String> _monthLabels = const [
    'Oct 01',
    'Oct 07',
    'Oct 14',
    'Oct 21',
    'Oct 28',
  ];

  // ── Recent bookings data ──────────────────────────────────────────────────
  final List<_BookingItem> _bookings = const [
    _BookingItem(
      name: 'Alex Johnson',
      subtitle: 'Turf A • 5:00 PM',
      amount: '\$45.00',
      status: 'Confirmed',
      avatarColor: Color(0xFF4A90D9),
      initials: 'AJ',
    ),
    _BookingItem(
      name: 'Sarah Miller',
      subtitle: 'Court 3 • 6:30 PM',
      amount: '\$30.00',
      status: 'Pending',
      avatarColor: Color(0xFF9B59B6),
      initials: 'SM',
    ),
    _BookingItem(
      name: 'David Chen',
      subtitle: 'Arena 1 • 8:00 PM',
      amount: '\$120.00',
      status: 'Confirmed',
      avatarColor: Color(0xFF2ECC71),
      initials: 'DC',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // ── Top bar ────────────────────────────────────────────────────
            // _buildTopBar(context),
            AdminHeader(title: "KINETIC"),

            // ── Scrollable content ─────────────────────────────────────────
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Overview title
                    const Text(
                      'Overview',
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF0E1A13),
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Real-time performance metrics',
                      style: TextStyle(fontSize: 13, color: Colors.grey[500]),
                    ),
                    const SizedBox(height: 20),

                    // ── Metric cards ───────────────────────────────────────
                    _MetricCard(
                      label: 'TODAY BOOKINGS',
                      icon: Icons.calendar_today_rounded,
                      value: '24',
                      sub: '+12% vs yesterday',
                      subColor: _green,
                    ),
                    const SizedBox(height: 12),
                    _MetricCard(
                      label: 'MONTHLY REVENUE',
                      icon: Icons.attach_money_rounded,
                      value: '\$12.5k',
                      sub: 'On track',
                      subColor: _green,
                    ),
                    const SizedBox(height: 12),
                    _OccupancyCard(),
                    const SizedBox(height: 12),

                    // ── Booking trends chart ───────────────────────────────
                    _buildTrendsCard(),
                    const SizedBox(height: 16),

                    // ── Action buttons
                    //
                    // ─────────────────────────────────────
                    Row(
                      children: [
                        Expanded(
                          child: _ActionButton(
                            label: 'Add Ground',
                            icon: Icons.add_circle_outline_rounded,
                            backgroundColor: _green,
                            textColor: Colors.white,
                            onTap: () => context.go('/admin/addgrounds'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _ActionButton(
                            label: 'Create Slots',
                            icon: Icons.block_rounded,
                            backgroundColor: const Color(0xFFEAEEF5),
                            textColor: const Color(0xFF2C3E50),
                            onTap: () => context.go('/admin/slotmanagement'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // ── Recent bookings ────────────────────────────────────
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Recent Bookings',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF0E1A13),
                          ),
                        ),
                        GestureDetector(
                          onTap: () => context.go('/admin/bookings'),
                          child: Text(
                            'See all',
                            style: TextStyle(
                              fontSize: 13,
                              color: _green,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Container(
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
                      child: Column(
                        children: List.generate(_bookings.length, (i) {
                          return Column(
                            children: [
                              _BookingRow(item: _bookings[i]),
                              if (i < _bookings.length - 1)
                                Divider(
                                  height: 1,
                                  color: Colors.grey[100],
                                  indent: 16,
                                  endIndent: 16,
                                ),
                            ],
                          );
                        }),
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),

            // ── Bottom nav ─────────────────────────────────────────────────
            const AdminNavBar(currentIndex: 0),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Row(
        children: [
          // Avatar
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2),
            ),
            child: const Icon(
              Icons.person_rounded,
              color: Colors.white,
              size: 24,
            ),
          ),
          const Spacer(),

          // Logo
          const Text(
            'KINETIC',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w900,
              letterSpacing: 3,
              color: Color(0xFF0D5C3A),
            ),
          ),
          const Spacer(),

          // Bell
          Stack(
            children: [
              IconButton(
                icon: const Icon(Icons.notifications_none_rounded),
                color: Colors.grey[700],
                onPressed: () {},
              ),
              Positioned(
                right: 10,
                top: 10,
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: Colors.red,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTrendsCard() {
    final spots = _isMonthly ? _monthlySpots : _weeklySpots;
    final labels = _isMonthly ? _monthLabels : _weekLabels;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                'Booking\nTrends',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF0E1A13),
                  height: 1.3,
                ),
              ),
              const Spacer(),
              _ToggleChip(
                label: 'Week',
                isActive: !_isMonthly,
                onTap: () => setState(() => _isMonthly = false),
              ),
              const SizedBox(width: 8),
              _ToggleChip(
                label: 'Month',
                isActive: _isMonthly,
                onTap: () => setState(() => _isMonthly = true),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 180,
            child: LineChart(
              LineChartData(
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: 10,
                  getDrawingHorizontalLine: (v) =>
                      FlLine(color: Colors.grey[100]!, strokeWidth: 1),
                ),
                titlesData: FlTitlesData(
                  leftTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 28,
                      interval: _isMonthly ? 2 : 1,
                      getTitlesWidget: (value, meta) {
                        final idx = value.toInt();
                        if (_isMonthly) {
                          final labelIdx = (idx / 2).round();
                          if (labelIdx < labels.length && idx % 2 == 0) {
                            return Text(
                              labels[labelIdx],
                              style: TextStyle(
                                fontSize: 10,
                                color: Colors.grey[500],
                              ),
                            );
                          }
                        } else {
                          if (idx >= 0 && idx < labels.length) {
                            return Text(
                              labels[idx],
                              style: TextStyle(
                                fontSize: 10,
                                color: Colors.grey[500],
                              ),
                            );
                          }
                        }
                        return const SizedBox.shrink();
                      },
                    ),
                  ),
                ),
                borderData: FlBorderData(show: false),
                lineBarsData: [
                  LineChartBarData(
                    spots: spots,
                    isCurved: true,
                    color: const Color(0xFF0D5C3A),
                    barWidth: 2.5,
                    isStrokeCapRound: true,
                    dotData: const FlDotData(show: false),
                    belowBarData: BarAreaData(
                      show: true,
                      color: const Color(0xFF0D5C3A).withOpacity(0.08),
                    ),
                  ),
                ],
                lineTouchData: LineTouchData(
                  touchTooltipData: LineTouchTooltipData(
                    getTooltipColor: (_) => const Color(0xFF0D5C3A),
                    getTooltipItems: (spots) => spots
                        .map(
                          (s) => LineTooltipItem(
                            '${s.y.toInt()}',
                            const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        )
                        .toList(),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Metric Card ───────────────────────────────────────────────────────────────

class _MetricCard extends StatelessWidget {
  final String label, value, sub;
  final IconData icon;
  final Color subColor;

  const _MetricCard({
    required this.label,
    required this.value,
    required this.sub,
    required this.icon,
    required this.subColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 18),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.2,
                  color: Colors.grey[500],
                ),
              ),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFE8F5EE),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 18, color: const Color(0xFF0D5C3A)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                value,
                style: const TextStyle(
                  fontSize: 34,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF0E1A13),
                  letterSpacing: -1,
                ),
              ),
              const SizedBox(width: 10),
              Text(
                sub,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: subColor,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Occupancy Card ────────────────────────────────────────────────────────────

class _OccupancyCard extends StatelessWidget {
  static const _green = Color(0xFF0D5C3A);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 18),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'OCCUPANCY',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.2,
                  color: Colors.grey[500],
                ),
              ),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFE8F5EE),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.bar_chart_rounded,
                  size: 18,
                  color: _green,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          const Text(
            '88%',
            style: TextStyle(
              fontSize: 34,
              fontWeight: FontWeight.w800,
              color: Color(0xFF0E1A13),
              letterSpacing: -1,
            ),
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(100),
            child: LinearProgressIndicator(
              value: 0.88,
              minHeight: 8,
              backgroundColor: Colors.grey[200],
              valueColor: const AlwaysStoppedAnimation<Color>(_green),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Action Button ─────────────────────────────────────────────────────────────

class _ActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color backgroundColor, textColor;
  final VoidCallback onTap;

  const _ActionButton({
    required this.label,
    required this.icon,
    required this.backgroundColor,
    required this.textColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 100,
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 28, color: textColor),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: textColor,
                letterSpacing: 0.2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Toggle Chip ───────────────────────────────────────────────────────────────

class _ToggleChip extends StatelessWidget {
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  static const _green = Color(0xFF0D5C3A);

  const _ToggleChip({
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: isActive ? _green : Colors.grey[100],
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: isActive ? Colors.white : Colors.grey[600],
          ),
        ),
      ),
    );
  }
}

// ── Booking Row ───────────────────────────────────────────────────────────────

class _BookingRow extends StatelessWidget {
  final _BookingItem item;
  const _BookingRow({required this.item});

  @override
  Widget build(BuildContext context) {
    final isConfirmed = item.status == 'Confirmed';
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          // Avatar
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: item.avatarColor,
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Text(
              item.initials,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 12),

          // Name + subtitle
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.name,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF0E1A13),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  item.subtitle,
                  style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                ),
              ],
            ),
          ),

          // Amount
          Text(
            item.amount,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: Color(0xFF0E1A13),
            ),
          ),
          const SizedBox(width: 10),

          // Status badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: isConfirmed ? const Color(0xFFE8F5EE) : Colors.orange[50],
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: isConfirmed
                        ? const Color(0xFF0D5C3A)
                        : Colors.orange[600],
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 5),
                Text(
                  item.status,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: isConfirmed
                        ? const Color(0xFF0D5C3A)
                        : Colors.orange[700],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Data model ────────────────────────────────────────────────────────────────

class _BookingItem {
  final String name, subtitle, amount, status, initials;
  final Color avatarColor;
  const _BookingItem({
    required this.name,
    required this.subtitle,
    required this.amount,
    required this.status,
    required this.initials,
    required this.avatarColor,
  });
}
