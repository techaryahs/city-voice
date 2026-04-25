import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../core/constants/app_colors.dart';

// ── Category model ────────────────────────────────────────────────────────────
class _Category {
  final String label;
  final IconData icon;
  final Color color;
  final Color bg;
  const _Category(this.label, this.icon, this.color, this.bg);
}

const _categories = [
  _Category('Garbage',     Icons.delete_outline_rounded,      Color(0xFF2ECC71), Color(0xFFEEFBF4)),
  _Category('Roads',       Icons.construction_rounded,         Color(0xFFE8614A), Color(0xFFFFF0EE)),
  _Category('Water',       Icons.water_drop_outlined,          Color(0xFF4A7BE8), Color(0xFFEEF4FF)),
  _Category('Electricity', Icons.bolt_outlined,                Color(0xFFF39C12), Color(0xFFFFFAEE)),
  _Category('Safety',      Icons.shield_outlined,              Color(0xFF9B59B6), Color(0xFFF5EEFF)),
  _Category('Other',       Icons.more_horiz_rounded,           Color(0xFF1ABCCD), Color(0xFFEDF8FB)),
];

// ── Main widget ───────────────────────────────────────────────────────────────

class RaiseVoicePage extends StatefulWidget {
  const RaiseVoicePage({super.key});

  @override
  State<RaiseVoicePage> createState() => _RaiseVoicePageState();
}

class _RaiseVoicePageState extends State<RaiseVoicePage> {
  final _descController     = TextEditingController();
  final _locationController = TextEditingController();

  File?   _image;
  int     _selectedCategory = 0;
  bool    _isLoading        = false;

  // Firebase refs
  final _auth       = FirebaseAuth.instance;
  final _dbRef      = FirebaseDatabase.instance.ref('posts');
  final _usersRef   = FirebaseDatabase.instance.ref('users');
  final _storageRef = FirebaseStorage.instance.ref();

  @override
  void dispose() {
    _descController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  // ── Pick image ──────────────────────────────────────────────────────────────

  Future<void> _pickImage(ImageSource source) async {
    final picked = await ImagePicker().pickImage(
      source: source,
      imageQuality: 75,
      maxWidth: 1200,
    );
    if (picked != null) setState(() => _image = File(picked.path));
  }

  void _showImageOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        margin: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(20),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 8),
              Container(
                width: 36, height: 4,
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),
              _sheetOption(
                icon: Icons.camera_alt_outlined,
                label: 'Take a photo',
                onTap: () { Navigator.pop(context); _pickImage(ImageSource.camera); },
              ),
              _sheetOption(
                icon: Icons.photo_library_outlined,
                label: 'Choose from gallery',
                onTap: () { Navigator.pop(context); _pickImage(ImageSource.gallery); },
              ),
              if (_image != null)
                _sheetOption(
                  icon: Icons.delete_outline_rounded,
                  label: 'Remove photo',
                  color: Colors.redAccent,
                  onTap: () { Navigator.pop(context); setState(() => _image = null); },
                ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sheetOption({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    Color? color,
  }) {
    return ListTile(
      leading: Container(
        width: 40, height: 40,
        decoration: BoxDecoration(
          color: (color ?? AppColors.primary).withOpacity(0.1),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: color ?? AppColors.primary, size: 20),
      ),
      title: Text(
        label,
        style: GoogleFonts.inter(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          color: color ?? AppColors.textDark,
        ),
      ),
      onTap: onTap,
    );
  }

  // ── Upload & save post ──────────────────────────────────────────────────────

  Future<void> _uploadPost() async {
    final desc     = _descController.text.trim();
    final location = _locationController.text.trim();

    if (desc.isEmpty) {
      _showSnack('Please describe the issue 📝');
      return;
    }
    if (location.isEmpty) {
      _showSnack('Please add a location 📍');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception('Not logged in');

      // ── 1. Fetch poster's name from DB ───────────────────────────────────
      String posterName = 'Anonymous';
      final userSnap = await _usersRef.child(user.uid).get();
      if (userSnap.exists) {
        final data = Map<String, dynamic>.from(userSnap.value as Map);
        posterName = (data['name'] ?? 'Anonymous').toString();
      }

      // ── 2. Upload image (optional) ───────────────────────────────────────
      String? imageUrl;
      if (_image != null) {
        final fileName = '${user.uid}_${DateTime.now().millisecondsSinceEpoch}';
        final ref = _storageRef.child('posts/$fileName.jpg');
        final task = await ref.putFile(_image!);
        imageUrl = await task.ref.getDownloadURL();
      }

      // ── 3. Save post to Realtime Database ────────────────────────────────
      await _dbRef.push().set({
        'uid':         user.uid,
        'name':        posterName,
        'description': desc,
        'location':    location,
        'category':    _categories[_selectedCategory].label,
        'image_url':   imageUrl ?? '',
        'timestamp':   DateTime.now().toIso8601String(),
        'supports':    0,
        'replies':     0,
      });

      // ── 4. Success ───────────────────────────────────────────────────────
      if (!mounted) return;
      _showSuccessSheet();
    } catch (e) {
      _showSnack('Error: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showSuccessSheet() {
    showModalBottomSheet(
      context: context,
      isDismissible: false,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.all(28),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72, height: 72,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [Color(0xFFFF7B5F), AppColors.primary],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: const Icon(Icons.check_rounded, color: Colors.white, size: 36),
            ),
            const SizedBox(height: 20),
            Text(
              'Voice Raised! 🎉',
              style: GoogleFonts.inter(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: AppColors.textDark,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Your issue has been posted.\nThe community will support you.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 14,
                color: AppColors.textMedium,
                height: 1.6,
              ),
            ),
            const SizedBox(height: 28),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(100),
                  gradient: const LinearGradient(
                    colors: [Color(0xFFFF7B5F), AppColors.primary],
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                  ),
                ),
                child: TextButton(
                  onPressed: () {
                    Navigator.pop(context); // close sheet
                    Navigator.pop(context); // go back to Voices
                  },
                  child: Text(
                    'Back to Voices',
                    style: GoogleFonts.inter(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: GoogleFonts.inter()),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  // ── UI ──────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            _buildTopBar(),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 24),
                    _buildSectionLabel('Category'),
                    const SizedBox(height: 12),
                    _buildCategoryPicker(),
                    const SizedBox(height: 24),
                    _buildSectionLabel('Describe the issue'),
                    const SizedBox(height: 10),
                    _buildDescriptionField(),
                    const SizedBox(height: 24),
                    _buildSectionLabel('Add a photo  (optional)'),
                    const SizedBox(height: 10),
                    _buildImagePicker(),
                    const SizedBox(height: 24),
                    _buildSectionLabel('Location'),
                    const SizedBox(height: 10),
                    _buildLocationField(),
                    const SizedBox(height: 36),
                    _buildSubmitButton(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Top bar ─────────────────────────────────────────────────────────────────

  Widget _buildTopBar() {
    return Container(
      color: AppColors.white,
      padding: const EdgeInsets.fromLTRB(8, 12, 20, 12),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
            color: AppColors.textDark,
          ),
          Expanded(
            child: Text(
              'Raise a Voice',
              style: GoogleFonts.inter(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: AppColors.textDark,
                letterSpacing: -0.3,
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.communityBg,
              borderRadius: BorderRadius.circular(100),
            ),
            child: Row(
              children: [
                Icon(Icons.campaign_rounded, size: 14, color: AppColors.primary),
                const SizedBox(width: 5),
                Text(
                  'Community',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Section label ────────────────────────────────────────────────────────────

  Widget _buildSectionLabel(String text) {
    return Text(
      text,
      style: GoogleFonts.inter(
        fontSize: 13,
        fontWeight: FontWeight.w700,
        color: AppColors.textDark,
        letterSpacing: 0.2,
      ),
    );
  }

  // ── Category picker ──────────────────────────────────────────────────────────

  Widget _buildCategoryPicker() {
    return SizedBox(
      height: 82,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _categories.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (context, i) {
          final cat      = _categories[i];
          final isActive = _selectedCategory == i;
          return GestureDetector(
            onTap: () => setState(() => _selectedCategory = i),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 76,
              decoration: BoxDecoration(
                color: isActive ? cat.color : AppColors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isActive ? cat.color : Colors.black.withOpacity(0.07),
                  width: 1.5,
                ),
                boxShadow: isActive
                    ? [BoxShadow(color: cat.color.withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 4))]
                    : [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 6, offset: const Offset(0, 2))],
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    cat.icon,
                    size: 22,
                    color: isActive ? Colors.white : cat.color,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    cat.label,
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: isActive ? Colors.white : AppColors.textMedium,
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

  // ── Description field ────────────────────────────────────────────────────────

  Widget _buildDescriptionField() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 2)),
        ],
      ),
      child: TextField(
        controller: _descController,
        maxLines: 4,
        maxLength: 300,
        style: GoogleFonts.inter(fontSize: 15, color: AppColors.textDark),
        decoration: InputDecoration(
          hintText: "What's the issue? Describe clearly so the community can understand and support...",
          hintStyle: GoogleFonts.inter(fontSize: 14, color: AppColors.textLight, height: 1.5),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.all(16),
          counterStyle: GoogleFonts.inter(fontSize: 11, color: AppColors.textLight),
        ),
      ),
    );
  }

  // ── Image picker ─────────────────────────────────────────────────────────────

  Widget _buildImagePicker() {
    return GestureDetector(
      onTap: _showImageOptions,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        height: _image != null ? 200 : 110,
        width: double.infinity,
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: _image != null ? AppColors.primary.withOpacity(0.3) : Colors.black.withOpacity(0.08),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 2)),
          ],
        ),
        child: _image == null
            ? Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 48, height: 48,
                    decoration: const BoxDecoration(
                      color: AppColors.communityBg,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.add_a_photo_outlined, color: AppColors.primary, size: 22),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Tap to add a photo',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textMedium,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    'Camera or Gallery',
                    style: GoogleFonts.inter(fontSize: 11, color: AppColors.textLight),
                  ),
                ],
              )
            : Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(15),
                    child: Image.file(_image!, width: double.infinity, height: 200, fit: BoxFit.cover),
                  ),
                  Positioned(
                    top: 8, right: 8,
                    child: GestureDetector(
                      onTap: _showImageOptions,
                      child: Container(
                        width: 32, height: 32,
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.55),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.edit_rounded, color: Colors.white, size: 16),
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  // ── Location field ───────────────────────────────────────────────────────────

  Widget _buildLocationField() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 2)),
        ],
      ),
      child: TextField(
        controller: _locationController,
        style: GoogleFonts.inter(fontSize: 15, color: AppColors.textDark),
        decoration: InputDecoration(
          hintText: 'e.g. Shivaji Nagar, Pune',
          hintStyle: GoogleFonts.inter(fontSize: 14, color: AppColors.textLight),
          prefixIcon: const Icon(Icons.location_on_outlined, color: AppColors.primary, size: 20),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        ),
      ),
    );
  }

  // ── Submit button ────────────────────────────────────────────────────────────

  Widget _buildSubmitButton() {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(100),
          gradient: _isLoading
              ? const LinearGradient(colors: [Color(0xFFCCCCCC), Color(0xFFBBBBBB)])
              : const LinearGradient(
                  colors: [Color(0xFFFF7B5F), AppColors.primary],
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                ),
          boxShadow: _isLoading
              ? []
              : [
                  BoxShadow(
                    color: AppColors.primary.withOpacity(0.4),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
        ),
        child: TextButton(
          onPressed: _isLoading ? null : _uploadPost,
          style: TextButton.styleFrom(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(100)),
          ),
          child: _isLoading
              ? const SizedBox(
                  width: 22, height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                )
              : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.campaign_rounded, color: Colors.white, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      'Raise Voice',
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}