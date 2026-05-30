import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../../core/constants/app_colors.dart';

class EditProfileSheet extends StatefulWidget {
  final String currentName;
  final String currentEmail;
  final String currentLocation;
  final Function(String name, String email, String location) onProfileUpdated;

  const EditProfileSheet({
    super.key,
    required this.currentName,
    required this.currentEmail,
    required this.currentLocation,
    required this.onProfileUpdated,
  });

  @override
  State<EditProfileSheet> createState() => _EditProfileSheetState();
}

class _EditProfileSheetState extends State<EditProfileSheet> {
  late final TextEditingController _nameController;
  late final TextEditingController _emailController;
  late final TextEditingController _locationController;
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _currentPasswordController = TextEditingController();

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final DatabaseReference _usersRef =
      FirebaseDatabase.instance.ref().child('users');

  bool _obscurePassword = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.currentName);
    _emailController = TextEditingController(text: widget.currentEmail);
    _locationController = TextEditingController(text: widget.currentLocation);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _locationController.dispose();
    _passwordController.dispose();
    _currentPasswordController.dispose();
    super.dispose();
  }

  Future<void> _saveChanges() async {
    setState(() {
      _isSaving = true;
    });

    try {
      final user = _auth.currentUser;
      if (user == null) {
        setState(() {
          _isSaving = false;
        });
        return;
      }

      // ── VALIDATION ─────────────────────────────
      if (_nameController.text.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Name cannot be empty'),
          ),
        );
        setState(() {
          _isSaving = false;
        });
        return;
      }

      // Require current password if changing email/password
      final isChangingSensitiveData =
          _emailController.text.trim() != user.email ||
              _passwordController.text.trim().isNotEmpty;

      if (isChangingSensitiveData &&
          _currentPasswordController.text.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Current password is required',
            ),
          ),
        );
        setState(() {
          _isSaving = false;
        });
        return;
      }

      // ── REAUTH ────────────────────────────────
      if (isChangingSensitiveData) {
        final credential = EmailAuthProvider.credential(
          email: user.email!,
          password: _currentPasswordController.text.trim(),
        );

        await user.reauthenticateWithCredential(credential);
      }

      final locationParts = _locationController.text.trim().split(',');
      final address = locationParts.isNotEmpty ? locationParts.first.trim() : '';
      final pincode = locationParts.length > 1 ? locationParts.last.trim() : '';

      // ── DATABASE UPDATE ──────────────────────
      await _usersRef.child(user.uid).update({
        'name': _nameController.text.trim(),
        'address': address,
        'pincode': pincode,
        'email': _emailController.text.trim(),
      });

      // ── EMAIL UPDATE ─────────────────────────
      if (_emailController.text.trim() != user.email) {
        await user.verifyBeforeUpdateEmail(
          _emailController.text.trim(),
        );
      }

      // ── PASSWORD UPDATE ──────────────────────
      if (_passwordController.text.trim().isNotEmpty) {
        await user.updatePassword(
          _passwordController.text.trim(),
        );
      }

      // Invoke callback to update parent state
      widget.onProfileUpdated(
        _nameController.text.trim(),
        _emailController.text.trim(),
        _locationController.text.trim(),
      );

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _emailController.text.trim() != user.email
                  ? 'Verification email sent. Please verify your new email.'
                  : 'Profile updated successfully',
              style: GoogleFonts.inter(),
            ),
          ),
        );
      }
    } on FirebaseAuthException catch (e) {
      String message = 'Something went wrong';

      if (e.code == 'wrong-password') {
        message = 'Current password is incorrect';
      } else if (e.code == 'weak-password') {
        message = 'Password should be at least 6 characters';
      } else if (e.code == 'email-already-in-use') {
        message = 'Email already in use';
      } else if (e.code == 'invalid-email') {
        message = 'Invalid email address';
      } else if (e.code == 'too-many-requests') {
        message = 'Too many attempts. Try again later.';
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(24),
          ),
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.black12,
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Edit Profile',
                style: GoogleFonts.inter(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 24),
              // NAME
              TextField(
                controller: _nameController,
                decoration: InputDecoration(
                  labelText: 'Name',
                  prefixIcon: const Icon(Icons.person_outline),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              // EMAIL
              TextField(
                controller: _emailController,
                decoration: InputDecoration(
                  labelText: 'Email',
                  prefixIcon: const Icon(Icons.email_outlined),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              // LOCATION
              TextField(
                controller: _locationController,
                decoration: InputDecoration(
                  labelText: 'Location',
                  prefixIcon: const Icon(Icons.location_on_outlined),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Colors.orange.withOpacity(0.25),
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.info_outline,
                      color: Colors.orange,
                      size: 18,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'For security reasons, your current password is required to change email or password.',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          height: 1.5,
                          color: Colors.orange.shade900,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              TextField(
                controller: _currentPasswordController,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: 'Current Password',
                  prefixIcon: const Icon(Icons.lock_clock_outlined),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              // PASSWORD
              TextField(
                controller: _passwordController,
                obscureText: _obscurePassword,
                decoration: InputDecoration(
                  labelText: 'New Password',
                  prefixIcon: const Icon(Icons.lock_outline),
                  suffixIcon: IconButton(
                    onPressed: () {
                      setState(() {
                        _obscurePassword = !_obscurePassword;
                      });
                    },
                    icon: Icon(
                      _obscurePassword
                          ? Icons.visibility_off
                          : Icons.visibility,
                    ),
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _saveChanges,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    disabledBackgroundColor: AppColors.primary.withOpacity(0.6),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(100),
                    ),
                  ),
                  child: _isSaving
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: Colors.white,
                          ),
                        )
                      : Text(
                          'Save Changes',
                          style: GoogleFonts.inter(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 10),
            ],
          ),
        ),
      ),
    );
  }
}
