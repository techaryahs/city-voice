import 'dart:math';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mailer/mailer.dart';
import 'package:mailer/smtp_server.dart';
import '../../../core/constants/app_colors.dart';
import 'email_otp_screen.dart';
import 'package:url_launcher/url_launcher.dart';

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final _nameController       = TextEditingController();
  final _phoneController      = TextEditingController();
  final _emailController      = TextEditingController();
  final _addressController    = TextEditingController();
  final _pincodeController    = TextEditingController();
  final _passwordController   = TextEditingController();
  final _confirmController    = TextEditingController();

  bool _obscurePassword = true;
  bool _obscureConfirm  = true;
  bool _isLoading = false;
  bool _acceptPolicy = false;
  String _verifiedEmail = '';
  String _selectedLanguage = 'English';
  final List<String> _languages = ['English', 'मराठी', 'हिन्दी'];

  final DatabaseReference _dbRef =
  FirebaseDatabase.instance.ref().child("users");

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _addressController.dispose();
    _pincodeController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  final FirebaseAuth _auth = FirebaseAuth.instance;

  void _createAccount() async {
    String name = _nameController.text.trim();
    String phone = _phoneController.text.trim();
    String email = _emailController.text.trim();
    String address = _addressController.text.trim();
    String pincode = _pincodeController.text.trim();
    String password = _passwordController.text.trim();
    String confirm = _confirmController.text.trim();
    final emailRegex = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');
    final hasLetter = RegExp(r'[A-Za-z]').hasMatch(password);
    final hasNumber = RegExp(r'\d').hasMatch(password);

    // ✅ Validation
    if (name.isEmpty ||
        phone.isEmpty ||
        email.isEmpty ||
        address.isEmpty ||
        pincode.isEmpty ||
        password.isEmpty ||
        confirm.isEmpty) {
      _showSnack("Please fill all fields");
      return;
    }

    if (!emailRegex.hasMatch(email)) {
      _showSnack("Enter a valid email address");
      return;
    }

    if (phone.length != 10) {
      _showSnack("Enter valid mobile number");
      return;
    }

    if (pincode.length != 6) {
      _showSnack("Enter valid pin code");
      return;
    }

    if (password.length < 6 || !hasLetter || !hasNumber) {
      _showSnack("Password must be 6+ characters with letters and numbers");
      return;
    }

    if (password != confirm) {
      _showSnack("Passwords do not match");
      return;
    }

    if (!_acceptPolicy) {
      _showSnack("Please accept Privacy Policy");
      return;
    }

    if (_verifiedEmail != email) {
      setState(() => _isLoading = true);
      try {
        final otp = await _sendSignupOtp(email);
        if (!mounted) return;
        setState(() => _isLoading = false);

        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => EmailOtpScreen(
              email: email,
              otp: otp,
              onResendOtp: () => _sendSignupOtp(email),
              onVerified: () async {
                if (mounted) setState(() => _verifiedEmail = email);
              },
            ),
          ),
        );

        if (mounted && _verifiedEmail == email) {
          _createAccount();
        }
      } catch (e) {
        _showSnack("Could not send OTP: $e");
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
      return;
    }

    setState(() => _isLoading = true);

    try {
      // 🔐 STEP 1: Create user in Firebase Auth
      UserCredential userCredential =
      await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      String userId = userCredential.user!.uid;

      // 🗂️ STEP 2: Save extra data in Realtime DB
      await _dbRef.child(userId).set({
        "id": userId,
        "name": name,
        "phone": phone,
        "email": email,
        "address": address,
        "pincode": pincode,
        "emailVerified": true,
        "emailVerifiedAt": DateTime.now().toIso8601String(),
        "isBlocked": false,
        "createdAt": DateTime.now().toIso8601String(),
      });

      _showSnack("Account created successfully ✅");

      Navigator.pop(context);
    } on FirebaseAuthException catch (e) {
      if (e.code == 'email-already-in-use') {
        _showSnack("Email already registered");
      } else if (e.code == 'invalid-email') {
        _showSnack("Invalid email format");
      } else if (e.code == 'weak-password') {
        _showSnack("Weak password");
      } else if (e.code == 'network-request-failed') {
        _showSnack("Check your internet connection");
      } else {
        _showSnack("Auth Error: ${e.message}");
      }
    } catch (e) {
      _showSnack("Error: $e");
    }
    finally {
      setState(() => _isLoading = false);
    }
  }

  // Sends a six-digit signup OTP to the user's email address.
  Future<String> _sendSignupOtp(String email) async {
    final otp = (100000 + Random.secure().nextInt(900000)).toString();
    const username = 'cityvoiceofficial@gmail.com';
    const password = 'nzrdrnffjaojwpxg';
    final smtpServer = gmail(username, password);

    final message = Message()
      ..from = const Address(username, 'CityVoice India')
      ..recipients.add(email)
      ..subject = 'Your CityVoice email verification OTP'
      ..text =
          'Your CityVoice India verification OTP is $otp.\n\nThis code is required to create your account. If you did not request this, please ignore this email.';

    await send(message, smtpServer);
    return otp;
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
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
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 28),
                    _buildHeading(),
                    const SizedBox(height: 32),

                    _buildLabel('Name'),
                    const SizedBox(height: 8),
                    _buildTextField(
                      controller: _nameController,
                      hint: 'How should we call you?',
                      icon: Icons.person_outline_rounded,
                    ),
                    const SizedBox(height: 20),

                    _buildLabel('Mobile Number'),
                    const SizedBox(height: 8),
                    _buildPhoneField(),
                    const SizedBox(height: 20),

                    _buildLabel('Email'),
                    const SizedBox(height: 8),
                    _buildTextField(
                      controller: _emailController,
                      hint: 'you@neighborhood.com',
                      icon: Icons.mail_outline_rounded,
                      keyboardType: TextInputType.emailAddress,
                    ),
                    const SizedBox(height: 20),

                    _buildLabel('Address'),
                    const SizedBox(height: 8),
                    _buildTextField(
                      controller: _addressController,
                      hint: 'Street, area, city',
                      icon: Icons.home_outlined,
                      maxLines: 2,
                    ),
                    const SizedBox(height: 20),

                    _buildLabel('Pin Code'),
                    const SizedBox(height: 8),
                    _buildTextField(
                      controller: _pincodeController,
                      hint: '6-digit pin code',
                      icon: Icons.pin_drop_outlined,
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(6),
                      ],
                    ),
                    const SizedBox(height: 20),

                    _buildLabel('Password'),
                    const SizedBox(height: 8),
                    _buildPasswordField(
                      controller: _passwordController,
                      hint: 'At least 6 characters',
                      obscure: _obscurePassword,
                      onToggle: () => setState(
                              () => _obscurePassword = !_obscurePassword),
                    ),
                    const SizedBox(height: 20),

                    _buildLabel('Confirm Password'),
                    const SizedBox(height: 8),
                    _buildPasswordField(
                      controller: _confirmController,
                      hint: 'Re-enter your password',
                      obscure: _obscureConfirm,
                      onToggle: () =>
                          setState(() => _obscureConfirm = !_obscureConfirm),
                    ),
                    const SizedBox(height: 32),

                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Checkbox(
                          value: _acceptPolicy,
                          activeColor: AppColors.primary,
                          onChanged: (value) {
                            setState(() {
                              _acceptPolicy = value!;
                            });
                          },
                        ),

                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.only(top: 12),
                            child: Wrap(
                              children: [
                                Text(
                                  'I agree to the ',
                                  style: GoogleFonts.inter(
                                    fontSize: 13,
                                    color: AppColors.textMedium,
                                  ),
                                ),

                                GestureDetector(
                                  onTap: _openPrivacyPolicy,
                                  child: Text(
                                    'Privacy Policy',
                                    style: GoogleFonts.inter(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.primary,
                                      decoration: TextDecoration.underline,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 16),

                    _buildCreateAccountButton(),
                    const SizedBox(height: 28),
                    _buildSignInRow(),
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
              Text(
                'CityVoice',
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
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: AppColors.white,
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
            size: 15,
            color: Color(0xFF0052D4),
          ),
          const SizedBox(width: 5),
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

  Widget _buildIllustration() {
    return Image.asset(
      'assets/images/community.png',
      height: 180,
      fit: BoxFit.contain,
    );
  }

  Widget _buildHeading() {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          child: Text(
            'Join the community',
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

  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    List<TextInputFormatter>? inputFormatters,
    int maxLines = 1,
  }) {
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
        controller: controller,
        keyboardType: keyboardType,
        inputFormatters: inputFormatters,
        maxLines: maxLines,
        style: GoogleFonts.inter(fontSize: 15, color: AppColors.textDark),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle:
          GoogleFonts.inter(fontSize: 15, color: AppColors.textLight),
          prefixIcon: Icon(icon, color: AppColors.textLight, size: 20),
          border: InputBorder.none,
          contentPadding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
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
          Container(
            padding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
            decoration: BoxDecoration(
              border: Border(
                  right: BorderSide(color: Colors.black.withOpacity(0.08))),
            ),
            child: Row(
              children: [
                const Text('🇮🇳', style: TextStyle(fontSize: 18)),
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
          Expanded(
            child: TextField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(10),
              ],
              style: GoogleFonts.inter(
                  fontSize: 15, color: AppColors.textDark),
              decoration: InputDecoration(
                hintText: '10-digit mobile number',
                hintStyle: GoogleFonts.inter(
                    fontSize: 15, color: AppColors.textLight),
                border: InputBorder.none,
                contentPadding:
                const EdgeInsets.symmetric(horizontal: 14),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPasswordField({
    required TextEditingController controller,
    required String hint,
    required bool obscure,
    required VoidCallback onToggle,
  }) {
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
        controller: controller,
        obscureText: obscure,
        style: GoogleFonts.inter(fontSize: 15, color: AppColors.textDark),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle:
          GoogleFonts.inter(fontSize: 15, color: AppColors.textLight),
          prefixIcon: Icon(Icons.lock_outline_rounded,
              color: AppColors.textLight, size: 20),
          suffixIcon: IconButton(
            icon: Icon(
              obscure
                  ? Icons.visibility_off_outlined
                  : Icons.visibility_outlined,
              color: AppColors.textLight,
              size: 20,
            ),
            onPressed: onToggle,
          ),
          border: InputBorder.none,
          contentPadding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        ),
      ),
    );
  }

  Widget _buildCreateAccountButton() {
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

          // ✅ Disable click when loading
          onTap: _isLoading ? null : _createAccount,

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
              'Create account',
              style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: Colors.white,
                letterSpacing: 0.3,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSignInRow() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text('Already have an account? ',
            style: GoogleFonts.inter(
                fontSize: 14, color: AppColors.textMedium)),
        GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Text('Sign in',
              style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primary)),
        ),
      ],
    );
  }
}
