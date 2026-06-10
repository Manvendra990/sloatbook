import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:slotbooking/User/navbar/usernavbar.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // ── Theme tokens ────────────────────────────────────────────────────────────
  static const _red = Color(0xFFD0021B);
  static const _redDark = Color(0xFF9B001A);
  static const _bg = Color(0xFFF6F6F6);
  static const _white = Colors.white;
  static const _textDark = Color(0xFF111111);
  static const _textMid = Color(0xFF555555);

  // ── State ───────────────────────────────────────────────────────────────────
  String _selectedSport = 'All';
  String? _detectedCity;
  bool _locationLoading = true;
  String _searchQuery = '';
  final TextEditingController _searchCtrl = TextEditingController();

  static const _sports = [
    {'label': 'All', 'icon': Icons.sports},
    {'label': 'Cricket', 'icon': Icons.sports_cricket},
    {'label': 'Football', 'icon': Icons.sports_soccer},
    {'label': 'Tennis', 'icon': Icons.sports_tennis},
    {'label': 'Swimming', 'icon': Icons.pool},
    {'label': 'Badminton', 'icon': Icons.sports_kabaddi},
    {'label': 'Basketball', 'icon': Icons.sports_basketball},
  ];

  @override
  void initState() {
    super.initState();
    _detectLocation();
    _searchCtrl.addListener(() {
      setState(() => _searchQuery = _searchCtrl.text.toLowerCase().trim());
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  // ── Location ─────────────────────────────────────────────────────────────────
  Future<void> _detectLocation() async {
    setState(() => _locationLoading = true);
    try {
      LocationPermission perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.denied ||
          perm == LocationPermission.deniedForever) {
        setState(() {
          _detectedCity = null;
          _locationLoading = false;
        });
        return;
      }
      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.low,
      );
      final marks = await placemarkFromCoordinates(pos.latitude, pos.longitude);
      if (marks.isNotEmpty) {
        setState(() {
          _detectedCity =
              marks.first.locality ??
              marks.first.subAdministrativeArea ??
              'Your City';
          _locationLoading = false;
        });
      }
    } catch (_) {
      setState(() {
        _detectedCity = null;
        _locationLoading = false;
      });
    }
  }

  // ── Firestore query ──────────────────────────────────────────────────────────
  Query<Map<String, dynamic>> _buildQuery() {
    Query<Map<String, dynamic>> q = FirebaseFirestore.instance.collection(
      'grounds',
    );
    if (_selectedSport != 'All') {
      q = q.where('sportType', isEqualTo: _selectedSport);
    }
    return q;
  }

  // ── Build ────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: Column(
          children: [
            _Header(
              city: _detectedCity,
              locationLoading: _locationLoading,
              onRefresh: _detectLocation,
            ),
            _SearchBar(controller: _searchCtrl),
            _SportSelector(
              sports: _sports,
              selected: _selectedSport,
              onSelect: (s) => setState(() => _selectedSport = s),
            ),
            Expanded(
              child: _GroundsList(
                query: _buildQuery(),
                searchQuery: _searchQuery,
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: const UserNavBar(currentIndex: 0),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Header
// ─────────────────────────────────────────────────────────────────────────────
class _Header extends StatelessWidget {
  final String? city;
  final bool locationLoading;
  final VoidCallback onRefresh;

  static const _red = Color(0xFFD0021B);
  static const _white = Colors.white;

  const _Header({
    required this.city,
    required this.locationLoading,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: _white,
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top row: location  +  bell
          Row(
            children: [
              GestureDetector(
                onTap: onRefresh,
                child: Row(
                  children: [
                    const Icon(
                      Icons.location_on_rounded,
                      size: 18,
                      color: _red,
                    ),
                    const SizedBox(width: 4),
                    locationLoading
                        ? const SizedBox(
                            width: 13,
                            height: 13,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: _red,
                            ),
                          )
                        : Text(
                            city != null ? '$city, IN' : 'Location off',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF111111),
                            ),
                          ),
                    const SizedBox(width: 4),
                    const Icon(
                      Icons.keyboard_arrow_down_rounded,
                      size: 18,
                      color: Color(0xFF111111),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              Stack(
                children: [
                  const Icon(
                    Icons.notifications_outlined,
                    size: 26,
                    color: Color(0xFF333333),
                  ),
                  Positioned(
                    top: 2,
                    right: 2,
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: _red,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Greeting
          const Text(
            'Hello, Player! 👋',
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w900,
              color: Color(0xFF111111),
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 2),
          const Text(
            'Ready to play today?',
            style: TextStyle(fontSize: 14, color: Color(0xFF777777)),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Search bar
// ─────────────────────────────────────────────────────────────────────────────
class _SearchBar extends StatelessWidget {
  final TextEditingController controller;
  static const _red = Color(0xFFD0021B);

  const _SearchBar({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 14),
      child: Row(
        children: [
          Expanded(
            child: Container(
              height: 46,
              decoration: BoxDecoration(
                color: const Color(0xFFF2F2F2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: TextField(
                controller: controller,
                style: const TextStyle(fontSize: 14),
                decoration: InputDecoration(
                  hintText: 'Search venues, sports, or areas...',
                  hintStyle: TextStyle(fontSize: 13, color: Colors.grey[400]),
                  prefixIcon: Icon(
                    Icons.search,
                    size: 20,
                    color: Colors.grey[400],
                  ),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 13),
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: _red,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.tune_rounded,
              color: Colors.white,
              size: 22,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Horizontal sport selector (icon circles)
// ─────────────────────────────────────────────────────────────────────────────
class _SportSelector extends StatelessWidget {
  final List<Map<String, dynamic>> sports;
  final String selected;
  final ValueChanged<String> onSelect;

  static const _red = Color(0xFFD0021B);

  const _SportSelector({
    required this.sports,
    required this.selected,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      child: Column(
        children: [
          const Divider(height: 1, color: Color(0xFFEEEEEE)),
          SizedBox(
            height: 88,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              itemCount: sports.length,
              separatorBuilder: (_, __) => const SizedBox(width: 18),
              itemBuilder: (context, i) {
                final s = sports[i];
                final label = s['label'] as String;
                final icon = s['icon'] as IconData;
                final isSelected = selected == label;
                return GestureDetector(
                  onTap: () => onSelect(label),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        width: 46,
                        height: 46,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isSelected ? _red : const Color(0xFFF2F2F2),
                          boxShadow: isSelected
                              ? [
                                  BoxShadow(
                                    color: _red.withOpacity(0.35),
                                    blurRadius: 8,
                                    offset: const Offset(0, 3),
                                  ),
                                ]
                              : [],
                        ),
                        child: Icon(
                          icon,
                          size: 22,
                          color: isSelected ? Colors.white : Colors.grey[600],
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        label,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: isSelected
                              ? FontWeight.w700
                              : FontWeight.w500,
                          color: isSelected ? _red : Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          const Divider(height: 1, color: Color(0xFFEEEEEE)),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Grounds list (StreamBuilder)
// ─────────────────────────────────────────────────────────────────────────────
class _GroundsList extends StatelessWidget {
  final Query<Map<String, dynamic>> query;
  final String searchQuery;

  static const _red = Color(0xFFD0021B);

  const _GroundsList({required this.query, required this.searchQuery});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: query.snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: _red));
        }
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        var docs = snapshot.data?.docs ?? [];

        // Client-side text search
        if (searchQuery.isNotEmpty) {
          docs = docs.where((d) {
            final data = d.data();
            final name = (data['name'] as String? ?? '').toLowerCase();
            final address = (data['address'] as String? ?? '').toLowerCase();
            final city = (data['city'] as String? ?? '').toLowerCase();
            final sport = (data['sportType'] as String? ?? '').toLowerCase();
            return name.contains(searchQuery) ||
                address.contains(searchQuery) ||
                city.contains(searchQuery) ||
                sport.contains(searchQuery);
          }).toList();
        }

        if (docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.search_off_rounded,
                  size: 56,
                  color: Colors.grey[300],
                ),
                const SizedBox(height: 12),
                Text(
                  'No grounds found',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey[400],
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
          itemCount: docs.length,
          separatorBuilder: (_, __) => const SizedBox(height: 16),
          itemBuilder: (context, i) {
            final data = docs[i].data();
            final groundId = docs[i].id;
            return _GroundCard(
              groundId: groundId,
              data: data,
              onTap: () =>
                  context.push('/user/ground_details?groundId=$groundId'),
            );
          },
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Ground card  (red-accented, reference-style)
// ─────────────────────────────────────────────────────────────────────────────
class _GroundCard extends StatelessWidget {
  final String groundId;
  final Map<String, dynamic> data;
  final VoidCallback onTap;

  static const _red = Color(0xFFD0021B);
  static const _redDark = Color(0xFF9B001A);

  const _GroundCard({
    required this.groundId,
    required this.data,
    required this.onTap,
  });

  List<String> _parseImages(dynamic raw) {
    if (raw is List) return List<String>.from(raw);
    if (raw is String && raw.isNotEmpty) return [raw];
    return [];
  }

  double _parsePrice(dynamic raw) {
    if (raw is num) return raw.toDouble();
    if (raw is String) return double.tryParse(raw) ?? 0;
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final images = _parseImages(data['images']);
    final imageUrl = images.isNotEmpty ? images[0] : null;
    final name = data['name'] as String? ?? 'Ground';
    final sport = data['sportType'] as String? ?? 'Sport';
    final address = data['address'] as String? ?? '';
    final city = data['city'] as String? ?? '';
    final price = _parsePrice(data['pricePerHour']);
    final amenities = (data['amenities'] as List?)?.length ?? 0;
    final isActive = data['status'] == true;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.07),
              blurRadius: 14,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            // ── Thumbnail ──────────────────────────────────────────────────
            ClipRRect(
              borderRadius: const BorderRadius.horizontal(
                left: Radius.circular(16),
              ),
              child: SizedBox(
                width: 120,
                height: 120,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    imageUrl != null
                        ? CachedNetworkImage(
                            imageUrl: imageUrl,
                            fit: BoxFit.cover,
                            placeholder: (_, __) => Container(
                              color: Colors.grey[200],
                              child: const Center(
                                child: CircularProgressIndicator(
                                  color: _red,
                                  strokeWidth: 2,
                                ),
                              ),
                            ),
                            errorWidget: (_, __, ___) => Container(
                              color: Colors.grey[200],
                              child: const Icon(
                                Icons.image_not_supported_outlined,
                                color: Colors.grey,
                              ),
                            ),
                          )
                        : Container(
                            color: Colors.grey[200],
                            child: const Icon(
                              Icons.sports_outlined,
                              size: 40,
                              color: Colors.grey,
                            ),
                          ),
                    // Instant book tag
                    if (isActive)
                      Positioned(
                        bottom: 10,
                        left: 0,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: _red,
                            borderRadius: const BorderRadius.horizontal(
                              right: Radius.circular(8),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: const [
                              Icon(Icons.bolt, size: 11, color: Colors.white),
                              SizedBox(width: 2),
                              Text(
                                'INSTANT BOOK',
                                style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
                                  letterSpacing: 0.4,
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
            // ── Info ───────────────────────────────────────────────────────
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF111111),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(Icons.sports, size: 13, color: _red),
                        const SizedBox(width: 4),
                        Text(
                          sport,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: _red,
                          ),
                        ),
                        const Text(' · ', style: TextStyle(color: Colors.grey)),
                        Expanded(
                          child: Text(
                            city,
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.grey,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Icon(
                          Icons.location_on_outlined,
                          size: 12,
                          color: Colors.grey[400],
                        ),
                        const SizedBox(width: 3),
                        Expanded(
                          child: Text(
                            address.isNotEmpty ? address : 'Address not listed',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey[400],
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        if (amenities > 0)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 7,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFECEE),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              '$amenities amenities',
                              style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: _red,
                              ),
                            ),
                          ),
                        const Spacer(),
                        if (price > 0) ...[
                          Text(
                            '₹${price.toStringAsFixed(0)}',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                              color: _red,
                            ),
                          ),
                          const Text(
                            ' /hr',
                            style: TextStyle(fontSize: 11, color: Colors.grey),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
