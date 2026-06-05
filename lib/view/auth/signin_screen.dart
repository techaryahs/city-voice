import 'package:cityvoice/view/auth/signup_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
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
    } catch (e) {
      _showSnack("Error: $e");
    } finally {
      setState(() => _isLoading = false);
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
    } catch (e) {
      _showSnack("Error: $e");
    }
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg)));
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
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            children: [
              _buildNavBar(),
              _buildIllustration(),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  children: [
                    const SizedBox(height: 28),
                    _buildHeading(),
                    const SizedBox(height: 32),

                    _buildLabel('Email'),
                    const SizedBox(height: 8),
                    _buildEmailField(),

                    const SizedBox(height: 20),

                    _buildLabel('Password'),
                    const SizedBox(height: 8),
                    _buildPasswordField(),

                    const SizedBox(height: 12),
                    _buildForgotPassword(),

                    const SizedBox(height: 32),
                    _buildContinueButton(),

                    const SizedBox(height: 28),
                    _buildDivider(),

                    const SizedBox(height: 28),
                    _buildSignUpRow(),

                    const SizedBox(height: 18),

                    GestureDetector(
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

                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmailField() {
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
      child: TextField(
        controller: _emailController,
        keyboardType: TextInputType.emailAddress,
        style: GoogleFonts.inter(fontSize: 15, color: AppColors.textDark),
        decoration: InputDecoration(
          hintText: 'you@email.com',
          hintStyle:
          GoogleFonts.inter(fontSize: 15, color: AppColors.textLight),
          prefixIcon:
          Icon(Icons.mail_outline, color: AppColors.textLight, size: 20),
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
        color: AppColors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 8,
              offset: const Offset(0, 2))
        ],
      ),
      child: TextField(
        controller: _passwordController,
        obscureText: _obscurePassword,
        style: GoogleFonts.inter(fontSize: 15, color: AppColors.textDark),
        decoration: InputDecoration(
          hintText: 'At least 6 characters',
          prefixIcon:
          Icon(Icons.lock_outline, color: AppColors.textLight, size: 20),
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
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
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
              Text('CityVoice',
                  style: GoogleFonts.inter(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: Colors.black,
                  letterSpacing: -0.5,
                )),
            ],
          ),
          _buildLanguageChip(),
        ],
      ),
    );
  }

  Widget _buildLanguageChip() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(100),
        border: Border.all(color: const Color(0xFFD7E9FF)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0D6EFD).withOpacity(0.08),
            blurRadius: 10,
            offset: const Offset(0, 3),
          )
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.language_rounded,
            size: 16,
            color: Color(0xFF0052D4),
          ),
          const SizedBox(width: 6),
          DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _selectedLanguage,
              borderRadius: BorderRadius.circular(14),
              icon: const Icon(
                Icons.keyboard_arrow_down_rounded,
                size: 18,
                color: Color(0xFF0052D4),
              ),
              items: _languages
                  .map(
                    (language) => DropdownMenuItem<String>(
                      value: language,
                      child: Text(
                        language,
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
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

  Widget _buildIllustration() {
    return Image.asset(
      'assets/images/community.png',
      height: 200,
      fit: BoxFit.contain,
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
              letterSpacing: -0.5,
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
    return Text(
      text,
      style: GoogleFonts.inter(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: AppColors.textDark,
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
          colors: [Color(0xFF0052D4), Color(0xFF0D6EFD), Color(0xFF3F8CFF)],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.4),
            blurRadius: 20,
            offset: const Offset(0, 8),
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
