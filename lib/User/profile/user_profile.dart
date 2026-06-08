import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:slotbooking/User/navbar/usernavbar.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  UserProfileScreen
//
//  Pass a [themeNotifier] (ValueNotifier<ThemeMode>) from your MaterialApp so
//  the dark/light toggle updates the whole app instantly.
//
//  Usage:
//    UserProfileScreen(themeNotifier: myThemeNotifier)
// ─────────────────────────────────────────────────────────────────────────────

class UserProfileScreen extends StatefulWidget {
  final ValueNotifier<ThemeMode> themeNotifier;

  const UserProfileScreen({super.key, required this.themeNotifier});

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
  bool get _isDark => widget.themeNotifier.value == ThemeMode.dark;

  // ─── Colors scoped to current theme ────────────────────────────────────────
  Color _bg(BuildContext ctx) => Theme.of(ctx).scaffoldBackgroundColor;
  Color _card(BuildContext ctx) => Theme.of(ctx).cardColor;
  Color _text(BuildContext ctx) => Theme.of(ctx).colorScheme.onSurface;
  Color _sub(BuildContext ctx) =>
      Theme.of(ctx).colorScheme.onSurface.withOpacity(0.55);

  static const _green = Color(0xFF0D5C3A);
  static const _greenLight = Color(0xFF1A8A57);
  static const _greenSoft = Color(0xFFE8F5EE);

  // ─── Firestore user doc ─────────────────────────────────────────────────────
  Stream<DocumentSnapshot<Map<String, dynamic>>> get _userStream =>
      _firestore.collection('users').doc(_user?.uid).snapshots();

  // ─── Pick & upload avatar ───────────────────────────────────────────────────
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

  // ─── Sign out ────────────────────────────────────────────────────────────────
  Future<void> _signOut() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Log out?',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        content: const Text('You will be signed out of your account.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade600,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text('Log out', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirm == true) await _auth.signOut();
  }

  void _showSnack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  // ─── Stats from Firestore ───────────────────────────────────────────────────
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
    final isDark = _isDark;

    return ValueListenableBuilder<ThemeMode>(
      valueListenable: widget.themeNotifier,
      builder: (context, mode, _) {
        return Scaffold(
          backgroundColor: _bg(context),
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
              final photoUrl =
                  _user?.photoURL ?? userData['photoUrl'] as String?;

              return CustomScrollView(
                slivers: [
                  // ── Sliver AppBar with hero header ─────────────────────
                  SliverAppBar(
                    expandedHeight: 280,
                    pinned: true,
                    backgroundColor: _green,
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
                        isDark: mode == ThemeMode.dark,
                        onToggleTheme: () {
                          widget.themeNotifier.value = mode == ThemeMode.dark
                              ? ThemeMode.light
                              : ThemeMode.dark;
                        },
                      ),
                    ),
                  ),

                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // ── Stats row ─────────────────────────────────
                          FutureBuilder<Map<String, int>>(
                            future: _fetchStats(),
                            builder: (context, snap) {
                              final stats =
                                  snap.data ??
                                  {'bookings': 0, 'spent': 0, 'grounds': 0};
                              return _StatsRow(
                                stats: stats,
                                cardColor: _card(context),
                              );
                            },
                          ),

                          const SizedBox(height: 24),

                          // ── Account section ───────────────────────────
                          _SectionLabel(
                            label: 'Account',
                            subColor: _sub(context),
                          ),
                          const SizedBox(height: 10),
                          _MenuCard(
                            cardColor: _card(context),
                            items: [
                              _MenuItem(
                                icon: Icons.person_outline_rounded,
                                label: 'Full Name',
                                trailing: displayName,
                                trailingColor: _sub(context),
                              ),
                              _MenuItem(
                                icon: Icons.phone_outlined,
                                label: 'Phone',
                                trailing: phone,
                                trailingColor: _sub(context),
                              ),
                              if (email.isNotEmpty)
                                _MenuItem(
                                  icon: Icons.mail_outline_rounded,
                                  label: 'Email',
                                  trailing: email,
                                  trailingColor: _sub(context),
                                ),
                            ],
                            textColor: _text(context),
                          ),

                          const SizedBox(height: 20),

                          // ── Preferences section ───────────────────────
                          _SectionLabel(
                            label: 'Preferences',
                            subColor: _sub(context),
                          ),
                          const SizedBox(height: 10),
                          _ThemeToggleCard(
                            isDark: mode == ThemeMode.dark,
                            cardColor: _card(context),
                            textColor: _text(context),
                            subColor: _sub(context),
                            onToggle: (val) {
                              widget.themeNotifier.value = val
                                  ? ThemeMode.dark
                                  : ThemeMode.light;
                            },
                          ),

                          const SizedBox(height: 20),

                          // ── More section ──────────────────────────────
                          _SectionLabel(label: 'More', subColor: _sub(context)),
                          const SizedBox(height: 10),
                          _MenuCard(
                            cardColor: _card(context),
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
                            textColor: _text(context),
                          ),

                          const SizedBox(height: 20),

                          // ── Logout button ─────────────────────────────
                          _LogoutButton(onTap: _signOut),

                          const SizedBox(height: 32),

                          // ── Version tag ───────────────────────────────
                          Center(
                            child: Text(
                              'Ground Booking • v1.0.0',
                              style: TextStyle(
                                fontSize: 11,
                                color: _sub(context),
                                letterSpacing: 0.5,
                              ),
                            ),
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
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Profile Header (inside SliverAppBar)
// ─────────────────────────────────────────────────────────────────────────────

class _ProfileHeader extends StatelessWidget {
  final String displayName;
  final String phone;
  final String email;
  final String? photoUrl;
  final Animation<double> avatarScale;
  final bool isUploading;
  final bool isDark;
  final VoidCallback onTapPhoto;
  final VoidCallback onToggleTheme;

  const _ProfileHeader({
    required this.displayName,
    required this.phone,
    required this.email,
    required this.photoUrl,
    required this.avatarScale,
    required this.isUploading,
    required this.isDark,
    required this.onTapPhoto,
    required this.onToggleTheme,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF0A4429), Color(0xFF0D5C3A), Color(0xFF1A8A57)],
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

          // Theme toggle top-right
          Positioned(
            top: 52,
            right: 16,
            child: GestureDetector(
              onTap: onToggleTheme,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                width: 56,
                height: 28,
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.white.withOpacity(0.25)
                      : Colors.white.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.4),
                    width: 1.5,
                  ),
                ),
                child: Stack(
                  children: [
                    AnimatedAlign(
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeInOut,
                      alignment: isDark
                          ? Alignment.centerRight
                          : Alignment.centerLeft,
                      child: Container(
                        width: 22,
                        height: 22,
                        margin: const EdgeInsets.all(3),
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          isDark
                              ? Icons.dark_mode_rounded
                              : Icons.light_mode_rounded,
                          size: 13,
                          color: isDark
                              ? const Color(0xFF0D5C3A)
                              : const Color(0xFFFF9800),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Main content
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
                          // Glow ring
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
                          // Camera badge
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
                                color: Color(0xFF0D5C3A),
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

// ─────────────────────────────────────────────────────────────────────────────
//  Stats Row
// ─────────────────────────────────────────────────────────────────────────────

class _StatsRow extends StatelessWidget {
  final Map<String, int> stats;
  final Color cardColor;

  const _StatsRow({required this.stats, required this.cardColor});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _StatTile(
          cardColor: cardColor,
          icon: Icons.event_available_rounded,
          value: '${stats['bookings']}',
          label: 'Bookings',
          iconColor: const Color(0xFF0D5C3A),
        ),
        const SizedBox(width: 10),
        _StatTile(
          cardColor: cardColor,
          icon: Icons.currency_rupee_rounded,
          value: '${stats['spent']}',
          label: 'Total Spent',
          iconColor: Colors.blue.shade600,
        ),
        const SizedBox(width: 10),
        _StatTile(
          cardColor: cardColor,
          icon: Icons.sports_soccer_rounded,
          value: '${stats['grounds']}',
          label: 'Grounds',
          iconColor: Colors.orange.shade600,
        ),
      ],
    );
  }
}

class _StatTile extends StatelessWidget {
  final Color cardColor;
  final IconData icon;
  final String value;
  final String label;
  final Color iconColor;

  const _StatTile({
    required this.cardColor,
    required this.icon,
    required this.value,
    required this.label,
    required this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
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
                color: iconColor.withOpacity(0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, size: 20, color: iconColor),
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: const TextStyle(fontSize: 11, color: Color(0xFF6E7D72)),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Section Label
// ─────────────────────────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final String label;
  final Color subColor;

  const _SectionLabel({required this.label, required this.subColor});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(
        label.toUpperCase(),
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          color: subColor,
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Menu Card
// ─────────────────────────────────────────────────────────────────────────────

class _MenuCard extends StatelessWidget {
  final List<_MenuItem> items;
  final Color cardColor;
  final Color textColor;

  const _MenuCard({
    required this.items,
    required this.cardColor,
    required this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
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
              _MenuItemTile(item: item, textColor: textColor),
              if (i < items.length - 1)
                Divider(
                  height: 1,
                  indent: 54,
                  color: textColor.withOpacity(0.08),
                ),
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
  final Color? trailingColor;
  final bool showArrow;
  final VoidCallback? onTap;

  const _MenuItem({
    required this.icon,
    required this.label,
    this.trailing,
    this.trailingColor,
    this.showArrow = false,
    this.onTap,
  });
}

class _MenuItemTile extends StatelessWidget {
  final _MenuItem item;
  final Color textColor;

  const _MenuItemTile({required this.item, required this.textColor});

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
                color: const Color(0xFF0D5C3A).withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(item.icon, size: 18, color: const Color(0xFF0D5C3A)),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                item.label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: textColor,
                ),
              ),
            ),
            // if (item.trailing != null)
            //   Flexible(
            //     child: Text(
            //       item.trailing!,
            //       style: TextStyle(
            //         fontSize: 13,
            //         color: item.trailingColor ?? textColor,
            //       ),
            //       overflow: TextOverflow.ellipsis,
            //       textAlign: TextAlign.right,
            //     ),
            //   ),
            // if (item.showArrow)
            //   Icon(
            //     Icons.chevron_right_rounded,
            //     size: 20,
            //     color: textColor.withOpacity(0.4),
            //   ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Theme Toggle Card
// ─────────────────────────────────────────────────────────────────────────────

class _ThemeToggleCard extends StatelessWidget {
  final bool isDark;
  final Color cardColor;
  final Color textColor;
  final Color subColor;
  final ValueChanged<bool> onToggle;

  const _ThemeToggleCard({
    required this.isDark,
    required this.cardColor,
    required this.textColor,
    required this.subColor,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Light mode button
          Expanded(
            child: GestureDetector(
              onTap: () => onToggle(false),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                margin: const EdgeInsets.symmetric(vertical: 8),
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: !isDark
                      ? const Color(0xFFFF9800).withOpacity(0.15)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                  border: !isDark
                      ? Border.all(
                          color: const Color(0xFFFF9800).withOpacity(0.4),
                        )
                      : null,
                ),
                child: Column(
                  children: [
                    Icon(
                      Icons.light_mode_rounded,
                      color: !isDark ? const Color(0xFFFF9800) : subColor,
                      size: 22,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Light',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: !isDark ? const Color(0xFFFF9800) : subColor,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          const SizedBox(width: 8),

          // Dark mode button
          Expanded(
            child: GestureDetector(
              onTap: () => onToggle(true),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                margin: const EdgeInsets.symmetric(vertical: 8),
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xFF3D5AFE).withOpacity(0.15)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                  border: isDark
                      ? Border.all(
                          color: const Color(0xFF3D5AFE).withOpacity(0.4),
                        )
                      : null,
                ),
                child: Column(
                  children: [
                    Icon(
                      Icons.dark_mode_rounded,
                      color: isDark ? const Color(0xFF3D5AFE) : subColor,
                      size: 22,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Dark',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: isDark ? const Color(0xFF3D5AFE) : subColor,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Logout Button
// ─────────────────────────────────────────────────────────────────────────────

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
          color: Colors.red.shade50,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.red.shade200),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.logout_rounded, color: Colors.red.shade600, size: 20),
            const SizedBox(width: 10),
            Text(
              'Log Out',
              style: TextStyle(
                color: Colors.red.shade600,
                fontWeight: FontWeight.w700,
                fontSize: 15,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
