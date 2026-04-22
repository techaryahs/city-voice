import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/constants/app_colors.dart';
import '../auth/signin_screen.dart';

class LandingScreen extends StatelessWidget {
  const LandingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 16),
              _buildNavBar(context),
              const SizedBox(height: 28),
              _buildBadge(),
              const SizedBox(height: 20),
              _buildHeadline(),
              const SizedBox(height: 16),
              _buildSubtitle(),
              const SizedBox(height: 16),
              _buildIllustration(),
              const SizedBox(height: 36),
              _buildGetStartedButton(context),
              const SizedBox(height: 20),
              _buildFeatureGrid(),
              const SizedBox(height: 24),
              _buildFooter(),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavBar(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        // Logo
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
            Text(
              'CityVoice',
              style: GoogleFonts.inter(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: AppColors.textDark,
                letterSpacing: -0.3,
              ),
            ),
          ],
        ),

        // Sign in button
        Container(
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(100),
            border: Border.all(
              color: AppColors.primary.withOpacity(0.25),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 8,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(100),
              onTap: () {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (context) => SignInScreen(),
                  ),
                );
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 9),
                child: Text(
                  'Sign in',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primary,
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(100),
        border: Border.all(color: AppColors.primary.withOpacity(0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.favorite_border_rounded, size: 14, color: AppColors.primary),
          const SizedBox(width: 6),
          Text(
            'A peaceful civic community',
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: AppColors.textMedium,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeadline() {
    return RichText(
      textAlign: TextAlign.center,
      text: TextSpan(
        children: [
          TextSpan(
            text: 'Raise your voice.\n',
            style: GoogleFonts.inter(
              fontSize: 34,
              fontWeight: FontWeight.w800,
              color: AppColors.textDark,
              height: 1.2,
            ),
          ),
          TextSpan(
            text: 'Support your\nneighbors.',
            style: GoogleFonts.inter(
              fontSize: 34,
              fontWeight: FontWeight.w800,
              color: AppColors.primary,
              height: 1.2,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubtitle() {
    return Text(
      'Report local issues, support others, and\ncreate change — together, gently.',
      textAlign: TextAlign.center,
      style: GoogleFonts.inter(
        fontSize: 15,
        color: AppColors.textMedium,
        height: 1.6,
      ),
    );
  }

  Widget _buildIllustration() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: Image.asset(
        'assets/images/community.png',
        width: double.infinity,
        fit: BoxFit.contain,
      ),
    );
  }

  Widget _buildGetStartedButton(BuildContext context) {
    return Container(
      width: double.infinity,
      height: 56,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(100),
        gradient: LinearGradient(
          colors: [
            Color(0xFFFF7B5F),
            AppColors.primary,
          ],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.4),
            blurRadius: 20,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(100),
          onTap: () {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (context) => SignInScreen(),
              ),
            );
          },
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Get started',
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                  letterSpacing: 0.3,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                width: 26,
                height: 26,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.25),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.arrow_forward_rounded,
                  color: Colors.white,
                  size: 15,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFeatureGrid() {
    final features = [
      _Feature(Icons.people_outline_rounded,   AppColors.communityIcon,      AppColors.communityBg,      'Community-\nled'),
      _Feature(Icons.location_on_outlined,     AppColors.hyperLocalIcon,     AppColors.hyperLocalBg,     'Hyper-\nlocal'),
      _Feature(Icons.favorite_border_rounded,  AppColors.supportiveIcon,     AppColors.supportiveBg,     'Supportive'),
      _Feature(Icons.chat_bubble_outline_rounded, AppColors.conversationalIcon, AppColors.conversationalBg, 'Conversational'),
    ];

    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: 2.4,
      children: features.map((f) => _buildFeatureCard(f)).toList(),
    );
  }

  Widget _buildFeatureCard(_Feature f) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: f.iconBg,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(f.icon, color: f.iconColor, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              f.label,
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.textDark,
                height: 1.3,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFooter() {
    return Text(
      'Built with care for the neighborhoods we live in.',
      style: GoogleFonts.inter(
        fontSize: 12,
        color: AppColors.textLight,
      ),
    );
  }
}

class _Feature {
  final IconData icon;
  final Color iconColor;
  final Color iconBg;
  final String label;
  const _Feature(this.icon, this.iconColor, this.iconBg, this.label);
}