import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:slotbooking/User/navbar/usernavbar.dart';
import 'package:slotbooking/data/theam/app_theam.dart';
import 'package:slotbooking/shared/widgets/apptext.dart';

class UserProfileScreen extends StatefulWidget {
  const UserProfileScreen({super.key});

  @override
  State<UserProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<UserProfileScreen>
    with SingleTickerProviderStateMixin {
  final _auth = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance;
  late AnimationController _avatarController;
  late Animation<double> _avatarScale;
  bool _isUploadingPhoto = false;

  @override
  void initState() {
    super.initState();
    _avatarController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _avatarScale = CurvedAnimation(
      parent: _avatarController,
      curve: Curves.elasticOut,
    );
    _avatarController.forward();
  }

  @override
  void dispose() {
    _avatarController.dispose();
    super.dispose();
  }

  User? get _user => _auth.currentUser;

  Stream<DocumentSnapshot<Map<String, dynamic>>> get _userStream =>
      _firestore.collection('users').doc(_user?.uid).snapshots();

  Future<void> _pickAndUploadPhoto() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 75,
    );
    if (picked == null || _user == null) return;

    setState(() => _isUploadingPhoto = true);
    try {
      final ref = FirebaseStorage.instance.ref().child(
        'profile_photos/${_user!.uid}.jpg',
      );
      await ref.putFile(File(picked.path));
      final url = await ref.getDownloadURL();
      await _user!.updatePhotoURL(url);
      await _firestore.collection('users').doc(_user!.uid).update({
        'photoUrl': url,
      });
      _avatarController
        ..reset()
        ..forward();
    } catch (e) {
      _showSnack('Failed to upload photo: $e');
    } finally {
      if (mounted) setState(() => _isUploadingPhoto = false);
    }
  }

  // ── Direct logout — no confirm dialog ─────────────────────────────────────
  Future<void> _signOut() async => await _auth.signOut();

  void _showSnack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<Map<String, int>> _fetchStats() async {
    final uid = _user?.uid;
    if (uid == null) return {'bookings': 0, 'spent': 0, 'grounds': 0};
    final snap = await _firestore
        .collection('user_bookings')
        .where('userId', isEqualTo: uid)
        .get();
    final total = snap.docs.fold<int>(0, (s, d) {
      final a = d.data()['amount'];
      if (a is int) return s + a;
      if (a is double) return s + a.toInt();
      return s + (int.tryParse('$a') ?? 0);
    });
    final grounds = snap.docs
        .map((d) => d.data()['groundId'] as String? ?? '')
        .toSet();
    return {
      'bookings': snap.docs.length,
      'spent': total,
      'grounds': grounds.length,
    };
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: _userStream,
        builder: (context, snapshot) {
          final userData = snapshot.data?.data() ?? {};
          final displayName =
              _user?.displayName ?? userData['name'] as String? ?? 'Player';
          final phone =
              _user?.phoneNumber ??
              userData['phone'] as String? ??
              userData['userPhone'] as String? ??
              'No phone';
          final email = _user?.email ?? userData['email'] as String? ?? '';
          final photoUrl = _user?.photoURL ?? userData['photoUrl'] as String?;

          return CustomScrollView(
            slivers: [
              // ── Header ─────────────────────────────────────────────────
              SliverAppBar(
                expandedHeight: 280,
                pinned: true,
                backgroundColor: AppTheme.primaryRed,
                foregroundColor: Colors.white,
                flexibleSpace: FlexibleSpaceBar(
                  background: _ProfileHeader(
                    displayName: displayName,
                    phone: phone,
                    email: email,
                    photoUrl: photoUrl,
                    avatarScale: _avatarScale,
                    isUploading: _isUploadingPhoto,
                    onTapPhoto: _pickAndUploadPhoto,
                  ),
                ),
              ),

              // ── Body ───────────────────────────────────────────────────
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Stats
                      FutureBuilder<Map<String, int>>(
                        future: _fetchStats(),
                        builder: (context, snap) {
                          final stats =
                              snap.data ??
                              {'bookings': 0, 'spent': 0, 'grounds': 0};
                          return _StatsRow(stats: stats);
                        },
                      ),

                      const SizedBox(height: 24),

                      // Account section
                      _SectionLabel(label: 'Account'),
                      const SizedBox(height: 10),
                      _MenuCard(
                        items: [
                          _MenuItem(
                            icon: Icons.person_outline_rounded,
                            label: 'Full Name',
                            trailing: displayName,
                          ),
                          _MenuItem(
                            icon: Icons.phone_outlined,
                            label: 'Phone',
                            trailing: phone,
                          ),
                          if (email.isNotEmpty)
                            _MenuItem(
                              icon: Icons.mail_outline_rounded,
                              label: 'Email',
                              trailing: email,
                            ),
                        ],
                      ),

                      const SizedBox(height: 20),

                      // More section
                      _SectionLabel(label: 'More'),
                      const SizedBox(height: 10),
                      _MenuCard(
                        items: [
                          _MenuItem(
                            icon: Icons.history_rounded,
                            label: 'Booking History',
                            showArrow: true,
                            onTap: () {},
                          ),
                          _MenuItem(
                            icon: Icons.receipt_long_rounded,
                            label: 'Transactions',
                            showArrow: true,
                            onTap: () {},
                          ),
                          _MenuItem(
                            icon: Icons.help_outline_rounded,
                            label: 'Help & Support',
                            showArrow: true,
                            onTap: () {},
                          ),
                          _MenuItem(
                            icon: Icons.info_outline_rounded,
                            label: 'About App',
                            showArrow: true,
                            onTap: () {},
                          ),
                        ],
                      ),

                      const SizedBox(height: 20),

                      // Log out button using AppButton.secondary style
                      _LogoutButton(onTap: _signOut),

                      const SizedBox(height: 28),

                      Center(
                        child: AppText.bodyMedium('Ground Booking • v1.0.0'),
                      ),
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
      bottomNavigationBar: const UserNavBar(currentIndex: 3),
    );
  }
}

// ─── Profile Header ───────────────────────────────────────────────────────────
class _ProfileHeader extends StatelessWidget {
  final String displayName;
  final String phone;
  final String email;
  final String? photoUrl;
  final Animation<double> avatarScale;
  final bool isUploading;
  final VoidCallback onTapPhoto;

  const _ProfileHeader({
    required this.displayName,
    required this.phone,
    required this.email,
    required this.photoUrl,
    required this.avatarScale,
    required this.isUploading,
    required this.onTapPhoto,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [AppTheme.darkRed, AppTheme.primaryRed, Color(0xFFE8354A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Stack(
        children: [
          // Decorative circles
          Positioned(
            top: -40,
            right: -40,
            child: Container(
              width: 180,
              height: 180,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.05),
              ),
            ),
          ),
          Positioned(
            bottom: 20,
            left: -30,
            child: Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.04),
              ),
            ),
          ),

          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(0, 16, 0, 20),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SizedBox(height: 8),

                  // Avatar
                  ScaleTransition(
                    scale: avatarScale,
                    child: GestureDetector(
                      onTap: onTapPhoto,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          Container(
                            width: 102,
                            height: 102,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: Colors.white.withOpacity(0.4),
                                width: 2,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.2),
                                  blurRadius: 20,
                                  spreadRadius: 2,
                                ),
                              ],
                            ),
                          ),
                          CircleAvatar(
                            radius: 46,
                            backgroundColor: Colors.white.withOpacity(0.2),
                            backgroundImage: photoUrl != null
                                ? NetworkImage(photoUrl!)
                                : null,
                            child: photoUrl == null
                                ? Text(
                                    displayName.isNotEmpty
                                        ? displayName[0].toUpperCase()
                                        : '?',
                                    style: const TextStyle(
                                      fontSize: 36,
                                      fontWeight: FontWeight.w800,
                                      color: Colors.white,
                                    ),
                                  )
                                : null,
                          ),
                          if (isUploading)
                            const CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          Positioned(
                            bottom: 2,
                            right: 2,
                            child: Container(
                              width: 26,
                              height: 26,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.15),
                                    blurRadius: 6,
                                  ),
                                ],
                              ),
                              child: const Icon(
                                Icons.camera_alt_rounded,
                                size: 14,
                                color: AppTheme.primaryRed,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 14),

                  Text(
                    displayName,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.3,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    phone,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.75),
                      fontSize: 14,
                    ),
                  ),
                  if (email.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      email,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.6),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Stats Row ────────────────────────────────────────────────────────────────
class _StatsRow extends StatelessWidget {
  final Map<String, int> stats;
  const _StatsRow({required this.stats});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _StatTile(
          icon: Icons.event_available_rounded,
          value: '${stats['bookings']}',
          label: 'Bookings',
          iconColor: AppTheme.primaryRed,
          iconBg: AppTheme.lightRed,
        ),
        const SizedBox(width: 10),
        _StatTile(
          icon: Icons.currency_rupee_rounded,
          value: '${stats['spent']}',
          label: 'Total Spent',
          iconColor: AppTheme.success,
          iconBg: const Color(0xFFDCFCE7),
        ),
        const SizedBox(width: 10),
        _StatTile(
          icon: Icons.sports_soccer_rounded,
          value: '${stats['grounds']}',
          label: 'Grounds',
          iconColor: const Color(0xFFD97706),
          iconBg: const Color(0xFFFEF3C7),
        ),
      ],
    );
  }
}

class _StatTile extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final Color iconColor;
  final Color iconBg;

  const _StatTile({
    required this.icon,
    required this.value,
    required this.label,
    required this.iconColor,
    required this.iconBg,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.shade100),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: iconBg,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, size: 20, color: iconColor),
            ),
            const SizedBox(height: 8),
            AppText(value, variant: AppTextVariant.headlineMedium),
            const SizedBox(height: 2),
            AppText.bodyMedium(label),
          ],
        ),
      ),
    );
  }
}

// ─── Section Label ────────────────────────────────────────────────────────────
class _SectionLabel extends StatelessWidget {
  final String label;
  const _SectionLabel({required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Row(
        children: [
          Container(
            width: 3,
            height: 14,
            decoration: BoxDecoration(
              color: AppTheme.primaryRed,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 8),
          AppText.label(label.toUpperCase(), color: AppTheme.textSecondary),
        ],
      ),
    );
  }
}

// ─── Menu Card ────────────────────────────────────────────────────────────────
class _MenuCard extends StatelessWidget {
  final List<_MenuItem> items;
  const _MenuCard({required this.items});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade100),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: items.asMap().entries.map((entry) {
          final i = entry.key;
          final item = entry.value;
          return Column(
            children: [
              _MenuItemTile(item: item),
              if (i < items.length - 1)
                Divider(height: 1, indent: 54, color: Colors.grey.shade100),
            ],
          );
        }).toList(),
      ),
    );
  }
}

class _MenuItem {
  final IconData icon;
  final String label;
  final String? trailing;
  final bool showArrow;
  final VoidCallback? onTap;

  const _MenuItem({
    required this.icon,
    required this.label,
    this.trailing,
    this.showArrow = false,
    this.onTap,
  });
}

class _MenuItemTile extends StatelessWidget {
  final _MenuItem item;
  const _MenuItemTile({required this.item});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: item.onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: AppTheme.lightRed,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(item.icon, size: 18, color: AppTheme.primaryRed),
            ),
            const SizedBox(width: 14),
            Expanded(child: AppText.bodyLarge(item.label)),
            if (item.trailing != null)
              Flexible(
                child: AppText.bodyMedium(
                  item.trailing!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            if (item.showArrow)
              Icon(
                Icons.chevron_right_rounded,
                size: 20,
                color: AppTheme.textSecondary.withOpacity(0.5),
              ),
          ],
        ),
      ),
    );
  }
}

// ─── Logout Button ────────────────────────────────────────────────────────────
class _LogoutButton extends StatelessWidget {
  final VoidCallback onTap;
  const _LogoutButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: AppTheme.lightRed,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.primaryRed.withOpacity(0.3)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.logout_rounded,
              color: AppTheme.primaryRed,
              size: 20,
            ),
            const SizedBox(width: 10),
            AppText.bodyLarge('Log Out', color: AppTheme.primaryRed),
          ],
        ),
      ),
    );
  }
}
