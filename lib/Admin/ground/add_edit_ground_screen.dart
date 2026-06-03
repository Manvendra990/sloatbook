import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:slotbooking/Admin/navbar/adminNavbar.dart';

class AddGroundScreen extends StatefulWidget {
  const AddGroundScreen({super.key});

  @override
  State<AddGroundScreen> createState() => _AddGroundScreenState();
}

class _AddGroundScreenState extends State<AddGroundScreen> {
  static const _green = Color(0xFF0D5C3A);
  static const _greenLight = Color(0xFFE8F5EE);
  static const _bg = Color(0xFFF0F3F0);

  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _cityCtrl = TextEditingController();

  String _sportType = 'Cricket';
  bool _isLoading = false;
  List<XFile> _pickedImages = [];

  final List<String> _sportTypes = [
    'Cricket',
    'Football',
    'Basketball',
    'Tennis',
    'Badminton',
    'Volleyball',
    'Hockey',
  ];

  final List<_AmenityOption> _amenities = [
    _AmenityOption(label: 'Parking', icon: Icons.local_parking_rounded),
    _AmenityOption(label: 'Drinking Water', icon: Icons.water_drop_outlined),
    _AmenityOption(label: 'Floodlights', icon: Icons.light_mode_outlined),
    _AmenityOption(label: 'Washroom', icon: Icons.wc_rounded),
    _AmenityOption(label: 'Cafeteria', icon: Icons.restaurant_outlined),
    _AmenityOption(label: 'First Aid', icon: Icons.medical_services_outlined),
    _AmenityOption(label: 'Free Wi-Fi', icon: Icons.wifi_rounded),
  ];

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    _addressCtrl.dispose();
    _cityCtrl.dispose();
    super.dispose();
  }

  List<String> get _selectedAmenities =>
      _amenities.where((a) => a.selected).map((a) => a.label).toList();

  // ── Pick images ────────────────────────────────────────────────────────────
  Future<void> _pickImages() async {
    final picker = ImagePicker();
    final picked = await picker.pickMultiImage(imageQuality: 70);
    if (picked.isNotEmpty) {
      setState(() {
        _pickedImages = [..._pickedImages, ...picked].take(4).toList();
      });
    }
  }

  // ── Upload images to Firebase Storage ─────────────────────────────────────
  Future<List<String>> _uploadImages(String groundId) async {
    final List<String> urls = [];
    for (int i = 0; i < _pickedImages.length; i++) {
      final file = File(_pickedImages[i].path);
      final ref = FirebaseStorage.instance.ref().child(
        'grounds/$groundId/image_$i.jpg',
      );
      await ref.putFile(file);
      final url = await ref.getDownloadURL();
      urls.add(url);
    }
    return urls;
  }

  // ── Save ground to Firestore ───────────────────────────────────────────────
  Future<void> _saveGround() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    try {
      final user = FirebaseAuth.instance.currentUser!;

      final adminDoc = await FirebaseFirestore.instance
          .collection('admin')
          .doc(user.uid)
          .get();
      final adminName = adminDoc.data()?['name'] ?? 'Ground Owner';

      await FirebaseFirestore.instance.collection('grounds').add({
        'name': _nameCtrl.text.trim(),
        'address': _addressCtrl.text.trim(),
        'city': _cityCtrl.text.trim(),
        'sportType': _sportType,
        'description': _descCtrl.text.trim(),
        'amenities': _selectedAmenities,
        'images': 'no_image', // ✅ plain string instead of upload
        'adminId': user.uid,
        'adminName': adminName,
        'status': false,
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;
      _showSuccessDialog();
    } catch (e) {
      if (!mounted) return;
      _showSnack('Failed to save ground: $e', Colors.red[700]!);
    } finally {
      if (mounted) setState(() => _isLoading = false);
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

  void _showSuccessDialog() {
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
              const Text(
                'Ground Added!',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF0E1A13),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Your ground has been saved and is pending review.',
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
                    context.go('/admin/grounds');
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
                    'View Grounds',
                    style: TextStyle(fontWeight: FontWeight.w700),
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
      backgroundColor: Colors.white,
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
                      color: Color(0xFF0D5C3A),
                    ),
                    onPressed: () => context.pop(),
                  ),
                  const Text(
                    'Add New\nGround',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF0D5C3A),
                      height: 1.2,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.notifications_none_rounded),
                    color: Colors.grey[700],
                    onPressed: () {},
                  ),
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.person_rounded,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                ],
              ),
            ),

            // ── Form ─────────────────────────────────────────────────────────
            Expanded(
              child: SingleChildScrollView(
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ── Gallery ────────────────────────────────────────────
                      _sectionLabel(
                        'GROUND GALLERY',
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                      ),
                      _buildGallery(),

                      // ── Location ───────────────────────────────────────────
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Location',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF0E1A13),
                              ),
                            ),
                            GestureDetector(
                              onTap: () {},
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.edit_location_alt_outlined,
                                    size: 16,
                                    color: _green,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    'Edit',
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: _green,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),

                      // Map placeholder
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            height: 140,
                            color: Colors.grey[200],
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                Icon(
                                  Icons.map_outlined,
                                  size: 60,
                                  color: Colors.grey[400],
                                ),
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: const BoxDecoration(
                                    color: _green,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.location_on,
                                    color: Colors.white,
                                    size: 20,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),

                      // Address fields
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Column(
                          children: [
                            _buildField(
                              controller: _addressCtrl,
                              hint: 'Civil Lines, Jhansi, Uttar Pradesh 284001',
                              validator: (v) => (v == null || v.trim().isEmpty)
                                  ? 'Address required'
                                  : null,
                            ),
                            const SizedBox(height: 10),
                            _buildField(
                              controller: _cityCtrl,
                              hint: 'City (e.g. Jhansi)',
                              validator: (v) => (v == null || v.trim().isEmpty)
                                  ? 'City required'
                                  : null,
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 16),
                      const Divider(height: 1, color: Color(0xFFF0F0F0)),
                      const SizedBox(height: 16),

                      // ── Ground Name ────────────────────────────────────────
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _fieldLabel('Ground Name'),
                            const SizedBox(height: 8),
                            _buildField(
                              controller: _nameCtrl,
                              hint: 'DDA Cricket Ground',
                              validator: (v) =>
                                  (v == null || v.trim().length < 3)
                                  ? 'Enter ground name'
                                  : null,
                            ),
                            const SizedBox(height: 14),

                            // ── Sport Type ─────────────────────────────────
                            _fieldLabel('Sport Type'),
                            const SizedBox(height: 8),
                            _buildDropdown(),
                          ],
                        ),
                      ),

                      const SizedBox(height: 20),
                      const Divider(height: 1, color: Color(0xFFF0F0F0)),
                      const SizedBox(height: 16),

                      // ── Amenities ──────────────────────────────────────────
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  'Amenities',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xFF0E1A13),
                                  ),
                                ),
                                Text(
                                  'Select all that apply',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey[500],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: _amenities.map((a) {
                                return GestureDetector(
                                  onTap: () =>
                                      setState(() => a.selected = !a.selected),
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 180),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 14,
                                      vertical: 10,
                                    ),
                                    decoration: BoxDecoration(
                                      color: a.selected
                                          ? _greenLight
                                          : Colors.white,
                                      borderRadius: BorderRadius.circular(30),
                                      border: Border.all(
                                        color: a.selected
                                            ? _green
                                            : Colors.grey[300]!,
                                        width: a.selected ? 1.5 : 1,
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          a.icon,
                                          size: 16,
                                          color: a.selected
                                              ? _green
                                              : Colors.grey[500],
                                        ),
                                        const SizedBox(width: 6),
                                        Text(
                                          a.label,
                                          style: TextStyle(
                                            fontSize: 13,
                                            fontWeight: a.selected
                                                ? FontWeight.w600
                                                : FontWeight.w400,
                                            color: a.selected
                                                ? _green
                                                : Colors.grey[600],
                                          ),
                                        ),
                                        if (a.selected) ...[
                                          const SizedBox(width: 6),
                                          const Icon(
                                            Icons.check_circle,
                                            size: 14,
                                            color: _green,
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 16),
                      const Divider(height: 1, color: Color(0xFFF0F0F0)),
                      const SizedBox(height: 16),

                      // ── Description ────────────────────────────────────────
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _fieldLabel('Ground Description'),
                            const SizedBox(height: 8),
                            TextFormField(
                              controller: _descCtrl,
                              maxLines: 4,
                              style: const TextStyle(fontSize: 14),
                              decoration: InputDecoration(
                                hintText:
                                    'A premium cricket facility located in the heart of Civil Lines...',
                                hintStyle: TextStyle(
                                  color: Colors.grey[400],
                                  fontSize: 13,
                                ),
                                filled: true,
                                fillColor: const Color(0xFFF8FAFB),
                                contentPadding: const EdgeInsets.all(14),
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
                          ],
                        ),
                      ),

                      const SizedBox(height: 16),

                      // ── Stats chips ────────────────────────────────────────
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Row(
                          children: [
                            Expanded(
                              child: _StatChip(
                                icon: Icons.trending_up_rounded,
                                label: 'ESTIMATED\nREACH',
                                value: '2.4k',
                                unit: 'Users/mo',
                                color: _green,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _StatChip(
                                icon: Icons.stars_rounded,
                                label: 'PLATFORM\nSCORE',
                                value: '98',
                                unit: '/100',
                                color: Colors.blue[700]!,
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 24),

                      // ── Save button ────────────────────────────────────────
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: SizedBox(
                          width: double.infinity,
                          height: 52,
                          child: ElevatedButton.icon(
                            onPressed: _isLoading ? null : _saveGround,
                            icon: _isLoading
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      color: Colors.white,
                                      strokeWidth: 2.5,
                                    ),
                                  )
                                : const Icon(Icons.save_rounded, size: 20),
                            label: Text(
                              _isLoading ? 'Saving...' : 'Save Details',
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
                              disabledBackgroundColor: _green.withOpacity(0.5),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),

                      // ── Discard ────────────────────────────────────────────
                      Center(
                        child: TextButton(
                          onPressed: () => context.pop(),
                          child: Text(
                            'Discard Changes',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[600],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              ),
            ),

            // ── Nav bar ──────────────────────────────────────────────────────
            // const AdminNavBar(currentIndex: 1),
          ],
        ),
      ),
    );
  }

  // ── Gallery widget ─────────────────────────────────────────────────────────
  Widget _buildGallery() {
    return Column(
      children: [
        // Main preview
        if (_pickedImages.isNotEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.file(
                File(_pickedImages[0].path),
                width: double.infinity,
                height: 180,
                fit: BoxFit.cover,
              ),
            ),
          )
        else
          GestureDetector(
            onTap: _pickImages,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Container(
                width: double.infinity,
                height: 180,
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Colors.grey[300]!,
                    style: BorderStyle.solid,
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.add_photo_alternate_outlined,
                      size: 44,
                      color: Colors.grey[400],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Tap to add ground photos',
                      style: TextStyle(fontSize: 13, color: Colors.grey[500]),
                    ),
                  ],
                ),
              ),
            ),
          ),
        const SizedBox(height: 10),

        // Thumbnails row
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              ...List.generate(_pickedImages.length.clamp(0, 3), (i) {
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.file(
                      File(_pickedImages[i].path),
                      width: 72,
                      height: 54,
                      fit: BoxFit.cover,
                    ),
                  ),
                );
              }),
              // Upload button
              GestureDetector(
                onTap: _pickImages,
                child: Container(
                  width: 72,
                  height: 54,
                  decoration: BoxDecoration(
                    color: Colors.grey[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: Colors.grey[300]!,
                      style: BorderStyle.solid,
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.camera_alt_outlined,
                        size: 18,
                        color: Colors.grey[500],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Upload',
                        style: TextStyle(fontSize: 10, color: Colors.grey[500]),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildField({
    required TextEditingController controller,
    required String hint,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      validator: validator,
      style: const TextStyle(fontSize: 14),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: Colors.grey[400], fontSize: 13),
        filled: true,
        fillColor: const Color(0xFFF8FAFB),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 13,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: Colors.grey[200]!, width: 1),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: Colors.grey[200]!, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: _green, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Colors.red),
        ),
      ),
    );
  }

  Widget _buildDropdown() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFB),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey[200]!, width: 1),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _sportType,
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
          items: _sportTypes
              .map((s) => DropdownMenuItem(value: s, child: Text(s)))
              .toList(),
          onChanged: (v) => setState(() => _sportType = v!),
        ),
      ),
    );
  }

  Widget _sectionLabel(String text, {EdgeInsets? padding}) {
    return Padding(
      padding: padding ?? EdgeInsets.zero,
      child: Text(
        text,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.4,
          color: Colors.grey[500],
        ),
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

// ── Amenity option model ──────────────────────────────────────────────────────
class _AmenityOption {
  final String label;
  final IconData icon;
  bool selected;
  _AmenityOption({
    required this.label,
    required this.icon,
    this.selected = false,
  });
}

// ── Stat chip ─────────────────────────────────────────────────────────────────
class _StatChip extends StatelessWidget {
  final IconData icon;
  final String label, value, unit;
  final Color color;

  const _StatChip({
    required this.icon,
    required this.label,
    required this.value,
    required this.unit,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withOpacity(0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: color),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8,
                  color: color.withOpacity(0.7),
                  height: 1.4,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                value,
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  color: color,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(width: 3),
              Text(
                unit,
                style: TextStyle(
                  fontSize: 11,
                  color: color.withOpacity(0.7),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
