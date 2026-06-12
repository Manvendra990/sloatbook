import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:go_router/go_router.dart';
import 'package:slotbooking/data/theam/app_theam.dart';
import 'package:slotbooking/shared/widgets/app_button.dart';
import 'package:slotbooking/shared/widgets/apptext.dart';

class GroundDetailScreen extends StatefulWidget {
  final String groundId;
  const GroundDetailScreen({super.key, required this.groundId});

  @override
  State<GroundDetailScreen> createState() => _GroundDetailScreenState();
}

class _GroundDetailScreenState extends State<GroundDetailScreen> {
  int _currentImageIndex = 0;
  final PageController _pageController = PageController();

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  List<String> _parseImages(dynamic raw) {
    if (raw == null) return [];
    if (raw is String) {
      final url = raw.trim();
      return url.isNotEmpty ? [url] : [];
    }
    if (raw is List) {
      return raw
          .whereType<String>()
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .toList();
    }
    return [];
  }

  static const _sportIconMap = <String, IconData>{
    'Basketball': Icons.sports_basketball_rounded,
    'Football': Icons.sports_soccer_rounded,
    'Cricket': Icons.sports_cricket_rounded,
    'Tennis': Icons.sports_tennis_rounded,
    'Badminton': Icons.sports_rounded,
    'Volleyball': Icons.sports_volleyball_rounded,
  };

  static const _amenityIconMap = <String, IconData>{
    'Parking': Icons.local_parking_rounded,
    'Drinking Water': Icons.water_drop_outlined,
    'Floodlights': Icons.lightbulb_outline_rounded,
    'Washroom': Icons.wc_rounded,
    'Showers': Icons.shower_outlined,
    'Cafeteria': Icons.restaurant_outlined,
    'Changing Room': Icons.door_front_door_outlined,
    'First Aid': Icons.medical_services_outlined,
    'WiFi': Icons.wifi_rounded,
  };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('grounds')
            .doc(widget.groundId)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: AppTheme.primaryRed),
            );
          }
          if (!snapshot.hasData || !snapshot.data!.exists) {
            return Center(child: AppText.bodyMedium('Ground not found.'));
          }

          final data = snapshot.data!.data()!;
          final images = _parseImages(data['images']);
          final amenities = List<String>.from(data['amenities'] ?? []);
          final isActive = data['status'] == true;
          final name = data['name'] as String? ?? 'Ground';
          final address = data['address'] as String? ?? '';
          final city = data['city'] as String? ?? '';
          final sportType = data['sportType'] as String? ?? '';
          final adminName = data['adminName'] as String? ?? 'Ground Owner';
          final pricePerHour = data['pricePerHour'];
          final description = data['description'] as String?;
          final openingHours = data['openingHours'] as String?;
          final courtType = data['courtType'] as String?;
          final coachAvailability = data['coachAvailability'] as String?;
          final rating = data['rating'];
          final reviewCount = data['reviewCount'];
          final isPremium = data['isPremium'] == true;

          return Stack(
            children: [
              CustomScrollView(
                slivers: [
                  // ── Hero Image ─────────────────────────────────────────
                  SliverAppBar(
                    expandedHeight: 320,
                    pinned: true,
                    elevation: 0,
                    backgroundColor: Colors.black,
                    leading: GestureDetector(
                      onTap: () => context.pop(),
                      child: Container(
                        margin: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.4),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.arrow_back_ios_new_rounded,
                          color: Colors.white,
                          size: 18,
                        ),
                      ),
                    ),
                    actions: [
                      Container(
                        margin: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.4),
                          shape: BoxShape.circle,
                        ),
                        child: IconButton(
                          icon: const Icon(
                            Icons.favorite_border_rounded,
                            color: Colors.white,
                            size: 20,
                          ),
                          onPressed: () {},
                        ),
                      ),
                    ],
                    flexibleSpace: FlexibleSpaceBar(
                      background: Stack(
                        fit: StackFit.expand,
                        children: [
                          // Image carousel
                          images.isNotEmpty
                              ? PageView.builder(
                                  controller: _pageController,
                                  itemCount: images.length,
                                  onPageChanged: (i) =>
                                      setState(() => _currentImageIndex = i),
                                  itemBuilder: (context, i) =>
                                      CachedNetworkImage(
                                        imageUrl: images[i],
                                        fit: BoxFit.cover,
                                        placeholder: (_, __) => Container(
                                          color: Colors.grey.shade800,
                                        ),
                                        errorWidget: (_, __, ___) => Container(
                                          color: Colors.grey.shade800,
                                          child: const Icon(
                                            Icons.image_not_supported_outlined,
                                            color: Colors.grey,
                                            size: 48,
                                          ),
                                        ),
                                      ),
                                )
                              : Container(color: Colors.grey.shade800),

                          // Bottom gradient for text readability
                          Positioned(
                            bottom: 0,
                            left: 0,
                            right: 0,
                            height: 160,
                            child: Container(
                              decoration: const BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.bottomCenter,
                                  end: Alignment.topCenter,
                                  colors: [Colors.black, Colors.transparent],
                                ),
                              ),
                            ),
                          ),

                          // Premium badge + name + address
                          Positioned(
                            bottom: 20,
                            left: 20,
                            right: 20,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Premium / Active badge
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: isPremium
                                        ? AppTheme.primaryRed
                                        : (isActive
                                              ? AppTheme.success
                                              : AppTheme.warning),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    isPremium
                                        ? 'PREMIUM VENUE'
                                        : (isActive
                                              ? 'ACTIVE'
                                              : 'UNDER REVIEW'),
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: 1.2,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  name,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 22,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    const Icon(
                                      Icons.location_on_rounded,
                                      color: Colors.white70,
                                      size: 14,
                                    ),
                                    const SizedBox(width: 4),
                                    Expanded(
                                      child: Text(
                                        '$address, $city',
                                        style: const TextStyle(
                                          color: Colors.white70,
                                          fontSize: 13,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),

                          // Dot indicators
                          if (images.length > 1)
                            Positioned(
                              bottom: 12,
                              right: 20,
                              child: Row(
                                children: List.generate(
                                  images.length,
                                  (i) => AnimatedContainer(
                                    duration: const Duration(milliseconds: 200),
                                    margin: const EdgeInsets.only(left: 4),
                                    width: _currentImageIndex == i ? 18 : 5,
                                    height: 5,
                                    decoration: BoxDecoration(
                                      color: _currentImageIndex == i
                                          ? Colors.white
                                          : Colors.white38,
                                      borderRadius: BorderRadius.circular(3),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),

                  // ── Content ────────────────────────────────────────────
                  SliverToBoxAdapter(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // ── Activity + Rating card ────────────────────
                        Container(
                          margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                          padding: const EdgeInsets.symmetric(
                            vertical: 20,
                            horizontal: 20,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(14),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.05),
                                blurRadius: 10,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Row(
                            children: [
                              // Activity
                              Expanded(
                                child: Column(
                                  children: [
                                    _SectionLabel('ACTIVITY'),
                                    const SizedBox(height: 10),
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          _sportIconMap[sportType] ??
                                              Icons.sports_rounded,
                                          color: AppTheme.primaryRed,
                                          size: 20,
                                        ),
                                        const SizedBox(width: 6),
                                        Text(
                                          sportType,
                                          style: const TextStyle(
                                            fontSize: 15,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              // Divider
                              Container(
                                width: 1,
                                height: 48,
                                color: Colors.grey.shade200,
                              ),
                              // Rating
                              Expanded(
                                child: Column(
                                  children: [
                                    _SectionLabel('RATING'),
                                    const SizedBox(height: 10),
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        const Icon(
                                          Icons.star_rounded,
                                          color: AppTheme.primaryRed,
                                          size: 20,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          rating != null ? '$rating' : '—',
                                          style: const TextStyle(
                                            fontSize: 15,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                        if (reviewCount != null) ...[
                                          const SizedBox(width: 4),
                                          Text(
                                            '($reviewCount reviews)',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: Colors.grey.shade500,
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 24),

                        // ── Amenities ───────────────────────────────────
                        if (amenities.isNotEmpty) ...[
                          _SectionLabel(
                            'AMENITIES',
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                          ),
                          const SizedBox(height: 14),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: Wrap(
                              spacing: 10,
                              runSpacing: 10,
                              children: amenities
                                  .map(
                                    (a) => _AmenityChip(
                                      label: a,
                                      iconData:
                                          _amenityIconMap[a] ??
                                          Icons.check_circle_outline_rounded,
                                    ),
                                  )
                                  .toList(),
                            ),
                          ),
                          const SizedBox(height: 24),
                        ],

                        // ── Facility Overview ───────────────────────────
                        if (description != null && description.isNotEmpty) ...[
                          _SectionLabel(
                            'FACILITY OVERVIEW',
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                          ),
                          const SizedBox(height: 12),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            child: Text(
                              description,
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey.shade700,
                                height: 1.6,
                              ),
                            ),
                          ),
                          const SizedBox(height: 24),
                        ],

                        // ── Metadata rows ───────────────────────────────
                        if (openingHours != null ||
                            courtType != null ||
                            coachAvailability != null ||
                            pricePerHour != null) ...[
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            child: Column(
                              children: [
                                if (openingHours != null)
                                  _MetaRow(
                                    label: 'OPENING HOURS',
                                    value: openingHours,
                                  ),
                                if (courtType != null)
                                  _MetaRow(
                                    label: 'COURT TYPE',
                                    value: courtType,
                                  ),
                                if (coachAvailability != null)
                                  _MetaRow(
                                    label: 'COACH AVAILABILITY',
                                    value: coachAvailability,
                                  ),
                                if (pricePerHour != null)
                                  _MetaRow(
                                    label: 'PRICE PER HOUR',
                                    value: '₹$pricePerHour',
                                  ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 24),
                        ],

                        // ── Find Us ─────────────────────────────────────
                        if (images.isNotEmpty) ...[
                          _SectionLabel(
                            'FIND US',
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                          ),
                          const SizedBox(height: 14),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(14),
                              child: Stack(
                                children: [
                                  CachedNetworkImage(
                                    imageUrl: images[0],
                                    height: 160,
                                    width: double.infinity,
                                    fit: BoxFit.cover,
                                    errorWidget: (_, __, ___) => Container(
                                      height: 160,
                                      color: Colors.grey.shade300,
                                    ),
                                  ),
                                  // Dark overlay
                                  Container(
                                    height: 160,
                                    color: Colors.black.withOpacity(0.35),
                                  ),
                                  // Directions card
                                  Positioned(
                                    bottom: 16,
                                    left: 16,
                                    right: 16,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 16,
                                        vertical: 12,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Row(
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.all(8),
                                            decoration: BoxDecoration(
                                              color: AppTheme.primaryRed
                                                  .withOpacity(0.1),
                                              shape: BoxShape.circle,
                                            ),
                                            child: const Icon(
                                              Icons.location_on_rounded,
                                              color: AppTheme.primaryRed,
                                              size: 20,
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              const Text(
                                                'Get Directions',
                                                style: TextStyle(
                                                  fontWeight: FontWeight.w700,
                                                  fontSize: 14,
                                                ),
                                              ),
                                              Text(
                                                '$address, $city',
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  color: Colors.grey.shade500,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 24),
                        ],

                        // ── Managed by ──────────────────────────────────
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.person_outline_rounded,
                                size: 16,
                                color: Colors.grey,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'Managed by $adminName',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.grey.shade500,
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 100),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          );
        },
      ),

      // ── Book Slot Button ────────────────────────────────────────────────
      bottomNavigationBar: Container(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 12,
              offset: const Offset(0, -3),
            ),
          ],
        ),
        child: AppButton.primary(
          label: 'BOOK A SLOT',
          leadingIcon: const Icon(Icons.calendar_month_rounded),
          onPressed: () =>
              context.push('/user/slot?groundId=${widget.groundId}'),
        ),
      ),
    );
  }
}

// ── Section Label ─────────────────────────────────────────────────────────────
class _SectionLabel extends StatelessWidget {
  final String text;
  final EdgeInsets? padding;
  const _SectionLabel(this.text, {this.padding});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding ?? EdgeInsets.zero,
      child: Text(
        text,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.5,
          color: Colors.grey.shade500,
        ),
      ),
    );
  }
}

// ── Meta Row (left border accent) ─────────────────────────────────────────────
class _MetaRow extends StatelessWidget {
  final String label;
  final String value;
  const _MetaRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.only(left: 14),
      decoration: const BoxDecoration(
        border: Border(left: BorderSide(color: AppTheme.primaryRed, width: 3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.4,
              color: Colors.grey.shade500,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            value,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: Colors.black87,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Amenity Chip ──────────────────────────────────────────────────────────────
class _AmenityChip extends StatelessWidget {
  final String label;
  final IconData iconData;
  const _AmenityChip({required this.label, required this.iconData});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 6),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(iconData, size: 16, color: AppTheme.primaryRed),
          const SizedBox(width: 8),
          Text(
            label,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }
}
