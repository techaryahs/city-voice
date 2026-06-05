import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/constants/app_colors.dart';

class EmailOtpScreen extends StatefulWidget {
  final String email;
  final String otp;
  final Future<String> Function() onResendOtp;
  final Future<void> Function() onVerified;

  const EmailOtpScreen({
    super.key,
    required this.email,
    required this.otp,
    required this.onResendOtp,
    required this.onVerified,
  });

  @override
  State<EmailOtpScreen> createState() => _EmailOtpScreenState();
}

class _EmailOtpScreenState extends State<EmailOtpScreen> {
  final TextEditingController _otpController = TextEditingController();

  late String _activeOtp;
  bool _isVerifying = false;
  bool _isResending = false;

  @override
  void initState() {
    super.initState();
    _activeOtp = widget.otp;
  }

  @override
  void dispose() {
    _otpController.dispose();
    super.dispose();
  }

  // Validates the code entered by the user before completing signup.
  Future<void> _verifyOtp() async {
    final enteredOtp = _otpController.text.trim();

    if (enteredOtp.length != 6) {
      _showSnack('Enter the 6-digit OTP sent to your email');
      return;
    }

    if (enteredOtp != _activeOtp) {
      _showSnack('Invalid OTP. Please check your email and try again.');
      return;
    }

    setState(() => _isVerifying = true);
    try {
      await widget.onVerified();
      if (mounted) Navigator.pop(context);
    } finally {
      if (mounted) setState(() => _isVerifying = false);
    }
  }

  // Sends a fresh OTP and replaces the active code.
  Future<void> _resendOtp() async {
    setState(() => _isResending = true);
    try {
      final newOtp = await widget.onResendOtp();
      _otpController.clear();
      setState(() => _activeOtp = newOtp);
      _showSnack('A new OTP has been sent.');
    } catch (e) {
      _showSnack('Could not resend OTP: $e');
    } finally {
      if (mounted) setState(() => _isResending = false);
    }
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        foregroundColor: AppColors.textDark,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const Spacer(),
              Container(
                width: 74,
                height: 74,
                decoration: const BoxDecoration(
                  color: Color(0xFFEAF3FF),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.mark_email_read_outlined,
                  color: Color(0xFF0052D4),
                  size: 34,
                ),
              ),
              const SizedBox(height: 22),
              Text(
                'Verify your email',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textDark,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'Enter the 6-digit OTP sent to\n${widget.email}',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color: AppColors.textMedium,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 30),
              _buildOtpField(),
              const SizedBox(height: 22),
              _buildVerifyButton(),
              const SizedBox(height: 18),
              TextButton(
                onPressed: _isResending ? null : _resendOtp,
                child: Text(
                  _isResending ? 'Sending...' : 'Resend OTP',
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.w800,
                    color: AppColors.primary,
                  ),
                ),
              ),
              const Spacer(flex: 2),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOtpField() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: TextField(
        controller: _otpController,
        keyboardType: TextInputType.number,
        textAlign: TextAlign.center,
        inputFormatters: [
          FilteringTextInputFormatter.digitsOnly,
          LengthLimitingTextInputFormatter(6),
        ],
        style: GoogleFonts.inter(
          fontSize: 22,
          fontWeight: FontWeight.w800,
          letterSpacing: 8,
          color: AppColors.textDark,
        ),
        decoration: InputDecoration(
          hintText: '000000',
          hintStyle: GoogleFonts.inter(
            fontSize: 22,
            letterSpacing: 8,
            color: AppColors.textLight,
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 18),
        ),
      ),
    );
  }

  Widget _buildVerifyButton() {
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
            color: AppColors.primary.withOpacity(0.35),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(100),
          onTap: _isVerifying ? null : _verifyOtp,
          child: Center(
            child: _isVerifying
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: Colors.white,
                    ),
                  )
                : Text(
                    'Verify and create account',
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}
