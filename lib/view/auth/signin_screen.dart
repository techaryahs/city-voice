import 'package:cityvoice/view/auth/signup_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show FilteringTextInputFormatter;
import 'package:google_fonts/google_fonts.dart';
import '../../../core/constants/app_colors.dart';
import '../screens/admin/admin_dashboard_screen.dart';
import '../screens/users/main_screen.dart';
import 'package:url_launcher/url_launcher.dart';

class SignInScreen extends StatefulWidget {
  const SignInScreen({super.key});

  @override
  State<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends State<SignInScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _obscurePassword = true;
  bool _isLoading = false;
  String _selectedLanguage = 'English';
  final List<String> _languages = ['English', 'मराठी', 'हिन्दी'];

  final FirebaseAuth _auth = FirebaseAuth.instance;

  final DatabaseReference _dbRef =
  FirebaseDatabase.instance.ref().child("users");

  // ✅ LOGIN FUNCTION
  void _loginUser() async {
    String email = _emailController.text.trim();
    String password = _passwordController.text.trim();
    final emailRegex = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');

    if (email.isEmpty || password.isEmpty) {
      _showSnack("Enter email and password");
      return;
    }

    if (!emailRegex.hasMatch(email)) {
      _showSnack("Enter a valid email address");
      return;
    }

    setState(() => _isLoading = true);

    try {
      UserCredential userCredential =
      await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      String uid = userCredential.user!.uid;

      // ✅ OPTIONAL: Fetch user data
      final snapshot = await _dbRef.child(uid).get();
      final userData = snapshot.value is Map
          ? Map<String, dynamic>.from(snapshot.value as Map)
          : <String, dynamic>{};
      final isEmailVerified = userData['emailVerified'] == true;

      if (!snapshot.exists) {
        _showSnack("User data not found");
        return;
      }

      // ✅ Admin check
      if (email == "admin@cityvoice.com") {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const AdminDashboardScreen()),
        );
      } else {
        if (!isEmailVerified) {
          await _auth.signOut();
          _showSnack("Please verify your email before signing in");
          return;
        }

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const MainScreen()),
        );
      }
    } on FirebaseAuthException catch (e) {
      if (e.code == 'user-not-found') {
        _showSnack("User not found");
      } else if (e.code == 'wrong-password') {
        _showSnack("Wrong password");
      } else if (e.code == 'invalid-email') {
        _showSnack("Invalid email format");
      } else if (e.code == 'network-request-failed') {
        _showSnack("Check internet connection");
      } else {
        _showSnack("Login Error: ${e.message}");
      }
    } on FirebaseException catch (e) {
      _showSnack(_friendlyFirebaseMessage(e));
    } catch (e) {
      _showSnack(_friendlyErrorMessage(e));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ✅ RESET PASSWORD
  void _resetPassword() async {
    String email = _emailController.text.trim();

    if (email.isEmpty) {
      _showSnack("Enter your email first");
      return;
    }

    try {
      await _auth.sendPasswordResetEmail(email: email);
      _showSnack("Password reset email sent");
    } on FirebaseAuthException catch (e) {
      _showSnack(_friendlyAuthMessage(e));
    } catch (e) {
      _showSnack(_friendlyErrorMessage(e));
    }
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        content: Text(
          msg,
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }

  String _friendlyAuthMessage(FirebaseAuthException e) {
    if (e.code == 'user-not-found') return 'User not found';
    if (e.code == 'wrong-password') return 'Wrong password';
    if (e.code == 'invalid-email') return 'Invalid email format';
    if (e.code == 'network-request-failed') return 'Check internet connection';
    return e.message ?? 'Could not complete sign in. Please try again.';
  }

  String _friendlyFirebaseMessage(FirebaseException e) {
    final text = e.toString().toLowerCase();
    if (e.code == 'permission-denied' || text.contains('permission denied')) {
      return 'Database permission denied. Please check your account access.';
    }
    if (e.code == 'network-error' || text.contains('network')) {
      return 'Check internet connection';
    }
    return 'Could not load account data. Please try again.';
  }

  String _friendlyErrorMessage(Object error) {
    final text = error.toString().toLowerCase();
    if (text.contains('permission denied')) {
      return 'Database permission denied. Please check your account access.';
    }
    if (text.contains('network')) return 'Check internet connection';
    return 'Something went wrong. Please try again.';
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _openPrivacyPolicy() async {
    final Uri url = Uri.parse(
      'https://techaryahs.github.io/cityvoiceurl/privacy-policy.html',
    );

    if (!await launchUrl(
      url,
      mode: LaunchMode.externalApplication,
    )) {
      _showSnack("Could not open Privacy Policy");
    }
  }

  // ================= UI =================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFEAF3FF), Color(0xFFF7FAFF), Colors.white],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: const EdgeInsets.only(bottom: 24),
            child: Column(
              children: [
                _buildNavBar(),
                _buildHeroPanel(),
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.fromLTRB(20, 18, 20, 0),
                  padding: const EdgeInsets.fromLTRB(20, 24, 20, 22),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.96),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.white),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF0D6EFD).withOpacity(0.10),
                        blurRadius: 28,
                        offset: const Offset(0, 14),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildHeading(),
                      const SizedBox(height: 26),

                      _buildLabel('Email'),
                      const SizedBox(height: 8),
                      _buildEmailField(),

                      const SizedBox(height: 18),

                      _buildLabel('Password'),
                      const SizedBox(height: 8),
                      _buildPasswordField(),

                      const SizedBox(height: 12),
                      _buildForgotPassword(),

                      const SizedBox(height: 26),
                      _buildContinueButton(),

                      const SizedBox(height: 24),
                      _buildDivider(),

                      const SizedBox(height: 22),
                      _buildSignUpRow(),

                      const SizedBox(height: 18),

                      Center(
                        child: GestureDetector(
                          onTap: _openPrivacyPolicy,
                          child: Text(
                            'Privacy Policy',
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              color: AppColors.primary,
                              decoration: TextDecoration.underline,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmailField() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFF),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE2ECFF)),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 10,
              offset: const Offset(0, 4))
        ],
      ),
      child: TextField(
        controller: _emailController,
        keyboardType: TextInputType.emailAddress,
        style: GoogleFonts.inter(fontSize: 15, color: AppColors.textDark),
        decoration: InputDecoration(
          hintText: 'you@email.com',
          hintStyle:
          GoogleFonts.inter(fontSize: 15, color: AppColors.textLight),
          prefixIcon:
          const Icon(Icons.mail_outline, color: Color(0xFF6D8BBD), size: 20),
          border: InputBorder.none,
          contentPadding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        ),
      ),
    );
  }

  Widget _buildPasswordField() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFF),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE2ECFF)),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 10,
              offset: const Offset(0, 4))
        ],
      ),
      child: TextField(
        controller: _passwordController,
        obscureText: _obscurePassword,
        style: GoogleFonts.inter(fontSize: 15, color: AppColors.textDark),
        decoration: InputDecoration(
          hintText: 'At least 6 characters',
          prefixIcon:
          const Icon(Icons.lock_outline, color: Color(0xFF6D8BBD), size: 20),
          suffixIcon: IconButton(
            icon: Icon(
              _obscurePassword
                  ? Icons.visibility_off_outlined
                  : Icons.visibility_outlined,
              color: AppColors.textLight,
            ),
            onPressed: () =>
                setState(() => _obscurePassword = !_obscurePassword),
          ),
          border: InputBorder.none,
          contentPadding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        ),
      ),
    );
  }

  Widget _buildNavBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.asset(
                  'assets/images/logo.jpeg',
                  width: 32,
                  height: 32,
                  fit: BoxFit.cover,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'CityVoice',
                style: GoogleFonts.inter(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: Colors.black,
                  letterSpacing: 0,
                ),
              ),
            ],
          ),
          _buildLanguageChip(),
        ],
      ),
    );
  }

  Widget _buildLanguageChip() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.9),
        borderRadius: BorderRadius.circular(100),
        border: Border.all(color: const Color(0xFFD7E9FF)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0D6EFD).withOpacity(0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          )
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.language_rounded,
            size: 14,
            color: Color(0xFF0052D4),
          ),
          const SizedBox(width: 3),
          DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _selectedLanguage,
              isDense: true,
              borderRadius: BorderRadius.circular(14),
              icon: const Icon(
                Icons.keyboard_arrow_down_rounded,
                size: 16,
                color: Color(0xFF0052D4),
              ),
              selectedItemBuilder: (context) {
                return _languages
                    .map(
                      (language) => Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          _languageShortLabel(language),
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textDark,
                          ),
                        ),
                      ),
                    )
                    .toList();
              },
              items: _languages
                  .map(
                    (language) => DropdownMenuItem<String>(
                      value: language,
                      child: Text(
                        language,
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: AppColors.textDark,
                        ),
                      ),
                    ),
                  )
                  .toList(),
              onChanged: (value) {
                if (value != null) {
                  setState(() => _selectedLanguage = value);
                }
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeroPanel() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
      child: Column(
        children: [
          Image.asset(
            'assets/images/community.png',
            height: 176,
            fit: BoxFit.contain,
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildTrustChip(Icons.verified_user_outlined, 'Verified voices'),
              const SizedBox(width: 8),
              _buildTrustChip(Icons.location_on_outlined, 'Local updates'),
            ],
          ),
        ],
      ),
    );
  }

  String _languageShortLabel(String language) {
    final index = _languages.indexOf(language);
    if (index == 1) return 'MR';
    if (index == 2) return 'HI';
    return 'EN';
  }

  Widget _buildTrustChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.85),
        borderRadius: BorderRadius.circular(100),
        border: Border.all(color: const Color(0xFFD7E9FF)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: AppColors.primary),
          const SizedBox(width: 6),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: AppColors.textDark,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeading() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(
          width: double.infinity,
          child: Text(
            'Welcome back',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 28,
              fontWeight: FontWeight.w800,
              color: AppColors.textDark,
              letterSpacing: 0,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'A peaceful place to raise your voice and support neighbors.',
          textAlign: TextAlign.center,
          style: GoogleFonts.inter(
            fontSize: 14,
            color: AppColors.textMedium,
            height: 1.5,
          ),
        ),
      ],
    );
  }

  Widget _buildLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(left: 2),
      child: Text(
        text,
        style: GoogleFonts.inter(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: AppColors.textDark,
        ),
      ),
    );
  }

  Widget _buildPhoneField() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 8,
              offset: const Offset(0, 2))
        ],
      ),
      child: Row(
        children: [
          // Country code
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
            decoration: BoxDecoration(
              border: Border(
                  right: BorderSide(color: Colors.black.withOpacity(0.08))),
            ),
            child: Row(
              children: [
                Text('🇮🇳', style: const TextStyle(fontSize: 18)),
                const SizedBox(width: 4),
                Text('+91',
                    style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textDark)),
                const SizedBox(width: 2),
                Icon(Icons.keyboard_arrow_down_rounded,
                    size: 16, color: AppColors.textMedium),
              ],
            ),
          ),
          // Phone input
          Expanded(
            child: TextField(
              controller: _emailController,
              keyboardType: TextInputType.phone,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              style: GoogleFonts.inter(
                  fontSize: 15, color: AppColors.textDark),
              decoration: InputDecoration(
                hintText: 'Mobile number',
                hintStyle: GoogleFonts.inter(
                    fontSize: 15, color: AppColors.textLight),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(horizontal: 14),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildForgotPassword() {
    return Align(
      alignment: Alignment.centerRight,
      child: GestureDetector(
        onTap: _resetPassword,
        child: Text(
          'Forgot password?',
          style: GoogleFonts.inter(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: AppColors.primary,
          ),
        ),
      ),
    );
  }

  Widget _buildContinueButton() {
    return Container(
      width: double.infinity,
      height: 56,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(100),
        gradient: const LinearGradient(
          colors: [Color(0xFF0087FF), Color(0xFF006BFF), Color(0xFF0052D4)],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.4),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(100),
            onTap: _isLoading ? null : _loginUser,
          child: Center(
            child: _isLoading
                ? const SizedBox(
              height: 22,
              width: 22,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                color: Colors.white,
              ),
            )
                : Text(
              'Continue',
              style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDivider() {
    return Row(
      children: [
        Expanded(child: Divider(color: Colors.black.withOpacity(0.1))),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text('or',
              style: GoogleFonts.inter(
                  fontSize: 13, color: AppColors.textLight)),
        ),
        Expanded(child: Divider(color: Colors.black.withOpacity(0.1))),
      ],
    );
  }

  Widget _buildSignUpRow() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text("Don't have an account? ",
            style: GoogleFonts.inter(
                fontSize: 14, color: AppColors.textMedium)),
        GestureDetector(
          onTap: () {
            Navigator.push(context,
                MaterialPageRoute(builder: (_) => const SignUpScreen()));
          },
          child: Text('Sign up',
              style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primary)),
        ),
      ],
    );
  }
}
