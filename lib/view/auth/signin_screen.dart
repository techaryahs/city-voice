import 'package:cityvoice/view/auth/signup_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show FilteringTextInputFormatter;
import 'package:google_fonts/google_fonts.dart';
import '../../../core/constants/app_colors.dart';
import '../screens/admin/admin_dashboard_screen.dart';
import '../screens/users/main_screen.dart';

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

  final FirebaseAuth _auth = FirebaseAuth.instance;

  final DatabaseReference _dbRef =
  FirebaseDatabase.instance.ref().child("users");

  // ✅ LOGIN FUNCTION
  void _loginUser() async {
    String email = _emailController.text.trim();
    String password = _passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      _showSnack("Enter email and password");
      return;
    }

    if (!email.contains("@")) {
      _showSnack("Enter valid email");
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
              Container(
                width: 42, // 🔥 increased size
                height: 42,
                child: Image.asset(
                  'assets/images/Icon.png',
                  fit: BoxFit.contain,
                ),
              ),
              const SizedBox(width: 10),
              Text('CityVoice',
                  style: GoogleFonts.inter(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textDark,
                      letterSpacing: -0.3)),
            ],
          ),
          _buildLanguageChip(),
        ],
      ),
    );
  }

  Widget _buildLanguageChip() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(100),
        border: Border.all(color: Colors.black.withOpacity(0.08)),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 6,
              offset: const Offset(0, 2))
        ],
      ),
      child: Row(
        children: [
          Icon(Icons.language_rounded, size: 15, color: AppColors.textMedium),
          const SizedBox(width: 5),
          Text('English',
              style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textDark)),
          const SizedBox(width: 3),
          Icon(Icons.keyboard_arrow_down_rounded,
              size: 16, color: AppColors.textMedium),
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
          colors: [Color(0xFFFF7B5F), AppColors.primary],
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