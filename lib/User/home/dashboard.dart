import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:slotbooking/User/navbar/usernavbar.dart';
import 'package:slotbooking/shared/widgets/carosol.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  static const _red = Color(0xFFD0021B);
  static const _bg = Color(0xFFF6F6F6);

  String _selectedSport = 'All';
  String? _detectedCity;
  bool _locationLoading = true;
  String _searchQuery = '';
  final TextEditingController _searchCtrl = TextEditingController();

  // Banner carousel
  final PageController _bannerCtrl = PageController();
  int _bannerPage = 0;

  static const _sports = [
    {'label': 'All', 'icon': Icons.sports},
    {'label': 'Cricket', 'icon': Icons.sports_cricket},
    {'label': 'Football', 'icon': Icons.sports_soccer},
    {'label': 'Tennis', 'icon': Icons.sports_tennis},
    {'label': 'Swimming', 'icon': Icons.pool},
    {'label': 'Badminton', 'icon': Icons.sports_kabaddi},
    {'label': 'Basketball', 'icon': Icons.sports_basketball},
  ];

  static const _banners = [
    {
      'tag': 'LIMITED OFFER',
      'title': '30% off your\nfirst booking',
      'sub': 'On selected grounds this week',
      'color': Color(0xFF9B001A),
    },
    {
      'tag': 'NEW',
      'title': 'Premium slots\nnow available',
      'sub': 'Book floodlit evening slots',
      'color': Color(0xFF0D5C3A),
    },
    {
      'tag': 'HOT',
      'title': 'Weekend\nspecial deals',
      'sub': 'Save up to ₹500 on weekends',
      'color': Color(0xFF1A237E),
    },
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
    _bannerCtrl.dispose();
    super.dispose();
  }

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

  Query<Map<String, dynamic>> _buildQuery() {
    Query<Map<String, dynamic>> q = FirebaseFirestore.instance.collection(
      'grounds',
    );
    if (_selectedSport != 'All') {
      q = q.where('sportType', isEqualTo: _selectedSport);
    }
    return q;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: Column(
          children: [
            // ── Fixed top section ──────────────────────────────────────────
            Container(
              color: Colors.white,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildHeader(),
                  _buildSearchBar(),
                  _buildSportSelector(),
                  const Divider(height: 1, color: Color(0xFFEEEEEE)),
                ],
              ),
            ),
            // ── Scrollable content ─────────────────────────────────────────
            Expanded(child: _buildScrollableBody()),
          ],
        ),
      ),
      bottomNavigationBar: const UserNavBar(currentIndex: 0),
    );
  }

  // ── Header ──────────────────────────────────────────────────────────────────
  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 10),
      child: Row(
        children: [
          // Location
          GestureDetector(
            onTap: _detectLocation,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.location_on_rounded,
                  size: 17,
                  color: Color(0xFFD0021B),
                ),
                const SizedBox(width: 4),
                _locationLoading
                    ? const SizedBox(
                        width: 12,
                        height: 12,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Color(0xFFD0021B),
                        ),
                      )
                    : Text(
                        _detectedCity != null
                            ? '$_detectedCity, IN'
                            : 'Location off',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF111111),
                        ),
                      ),
                const SizedBox(width: 3),
                const Icon(
                  Icons.keyboard_arrow_down_rounded,
                  size: 16,
                  color: Color(0xFF111111),
                ),
              ],
            ),
          ),
          const Spacer(),
          // Bell
          Stack(
            children: [
              const Icon(
                Icons.notifications_outlined,
                size: 25,
                color: Color(0xFF333333),
              ),
              Positioned(
                top: 2,
                right: 2,
                child: Container(
                  width: 7,
                  height: 7,
                  decoration: const BoxDecoration(
                    color: Color(0xFFD0021B),
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

  // ── Search bar ───────────────────────────────────────────────────────────────
  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
      child: Row(
        children: [
          Expanded(
            child: Container(
              height: 44,
              decoration: BoxDecoration(
                color: const Color(0xFFF2F2F2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: TextField(
                controller: _searchCtrl,
                style: const TextStyle(fontSize: 14),
                decoration: InputDecoration(
                  hintText: 'Search venues, sports, areas...',
                  hintStyle: TextStyle(fontSize: 13, color: Colors.grey[400]),
                  prefixIcon: Icon(
                    Icons.search,
                    size: 19,
                    color: Colors.grey[400],
                  ),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: const Color(0xFFD0021B),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.tune_rounded,
              color: Colors.white,
              size: 20,
            ),
          ),
        ],
      ),
    );
  }

  // ── Sport selector ───────────────────────────────────────────────────────────
  // FIX: use compact icon-only circles with label below, proper height
  Widget _buildSportSelector() {
    return SizedBox(
      height: 82,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        itemCount: _sports.length,
        itemBuilder: (context, i) {
          final s = _sports[i];
          final label = s['label'] as String;
          final icon = s['icon'] as IconData;
          final isSelected = _selectedSport == label;
          return GestureDetector(
            onTap: () => setState(() => _selectedSport = label),
            child: Container(
              margin: const EdgeInsets.only(right: 12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isSelected
                          ? const Color(0xFFD0021B)
                          : const Color(0xFFF2F2F2),
                      boxShadow: isSelected
                          ? [
                              BoxShadow(
                                color: const Color(0xFFD0021B).withOpacity(0.3),
                                blurRadius: 6,
                                offset: const Offset(0, 2),
                              ),
                            ]
                          : [],
                    ),
                    child: Icon(
                      icon,
                      size: 20,
                      color: isSelected ? Colors.white : Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: isSelected
                          ? FontWeight.w700
                          : FontWeight.w500,
                      color: isSelected
                          ? const Color(0xFFD0021B)
                          : Colors.grey[600],
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

  // ── Scrollable body (banner + grounds list) ──────────────────────────────────
  Widget _buildScrollableBody() {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _buildQuery().snapshots(),
      builder: (context, snapshot) {
        var docs = snapshot.data?.docs ?? [];

        if (_searchQuery.isNotEmpty) {
          docs = docs.where((d) {
            final data = d.data();
            final name = (data['name'] as String? ?? '').toLowerCase();
            final address = (data['address'] as String? ?? '').toLowerCase();
            final city = (data['city'] as String? ?? '').toLowerCase();
            final sport = (data['sportType'] as String? ?? '').toLowerCase();
            return name.contains(_searchQuery) ||
                address.contains(_searchQuery) ||
                city.contains(_searchQuery) ||
                sport.contains(_searchQuery);
          }).toList();
        }

        return CustomScrollView(
          slivers: [
            // ── Banner carousel ──────────────────────────────────────────
            SliverToBoxAdapter(child: BannerCarousel()),

            // ── Section header ───────────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
                child: Row(
                  children: [
                    const Text(
                      'Nearby Grounds',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF111111),
                      ),
                    ),
                    const Spacer(),
                    if (snapshot.connectionState == ConnectionState.waiting)
                      const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Color(0xFFD0021B),
                        ),
                      ),
                  ],
                ),
              ),
            ),

            // ── Grounds ──────────────────────────────────────────────────
            if (snapshot.hasError)
              SliverToBoxAdapter(
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(40),
                    child: Text('Error: ${snapshot.error}'),
                  ),
                ),
              )
            else if (docs.isEmpty &&
                snapshot.connectionState != ConnectionState.waiting)
              SliverToBoxAdapter(
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 60),
                    child: Column(
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
                  ),
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate((context, i) {
                    final data = docs[i].data();
                    final groundId = docs[i].id;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: _GroundCard(
                        groundId: groundId,
                        data: data,
                        onTap: () => context.push(
                          '/user/ground_details?groundId=$groundId',
                        ),
                      ),
                    );
                  }, childCount: docs.length),
                ),
              ),
          ],
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Ground Card
// ─────────────────────────────────────────────────────────────────────────────
class _GroundCard extends StatelessWidget {
  final String groundId;
  final Map<String, dynamic> data;
  final VoidCallback onTap;

  static const _red = Color(0xFFD0021B);

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
            // Thumbnail
            ClipRRect(
              borderRadius: const BorderRadius.horizontal(
                left: Radius.circular(16),
              ),
              child: SizedBox(
                width: 115,
                height: 115,
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
                              size: 38,
                              color: Colors.grey,
                            ),
                          ),
                    if (isActive)
                      Positioned(
                        bottom: 8,
                        left: 0,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 3,
                          ),
                          decoration: const BoxDecoration(
                            color: _red,
                            borderRadius: BorderRadius.horizontal(
                              right: Radius.circular(6),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: const [
                              Icon(Icons.bolt, size: 10, color: Colors.white),
                              SizedBox(width: 2),
                              Text(
                                'INSTANT BOOK',
                                style: TextStyle(
                                  fontSize: 8,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
                                  letterSpacing: 0.3,
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
            // Info
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF111111),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        Icon(Icons.sports, size: 12, color: _red),
                        const SizedBox(width: 3),
                        Flexible(
                          child: Text(
                            sport,
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: _red,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const Text(
                          ' · ',
                          style: TextStyle(color: Colors.grey, fontSize: 11),
                        ),
                        Flexible(
                          child: Text(
                            city,
                            style: const TextStyle(
                              fontSize: 11,
                              color: Colors.grey,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(
                          Icons.location_on_outlined,
                          size: 11,
                          color: Colors.grey[400],
                        ),
                        const SizedBox(width: 2),
                        Expanded(
                          child: Text(
                            address.isNotEmpty ? address : 'Address not listed',
                            style: TextStyle(
                              fontSize: 10,
                              color: Colors.grey[400],
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        if (amenities > 0)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFECEE),
                              borderRadius: BorderRadius.circular(5),
                            ),
                            child: Text(
                              '$amenities amenities',
                              style: const TextStyle(
                                fontSize: 9,
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
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                              color: _red,
                            ),
                          ),
                          const Text(
                            '/hr',
                            style: TextStyle(fontSize: 10, color: Colors.grey),
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
