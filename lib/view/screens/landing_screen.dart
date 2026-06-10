import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/constants/app_colors.dart';
import '../auth/signin_screen.dart';

class LandingScreen extends StatefulWidget {
  const LandingScreen({super.key});

  @override
  State<LandingScreen> createState() => _LandingScreenState();
}

class _LandingScreenState extends State<LandingScreen>
    with TickerProviderStateMixin {

  // ── Controllers ───────────────────────────────────────────────────────────
  late final AnimationController _navController;
  late final AnimationController _heroController;
  late final AnimationController _contentController;
  late final AnimationController _buttonController;
  late final AnimationController _gridController;

  // ── Nav bar ───────────────────────────────────────────────────────────────
  late final Animation<double> _navFade;
  late final Animation<Offset> _navSlide;

  // ── Badge + headline + subtitle ───────────────────────────────────────────
  late final Animation<double> _badgeFade;
  late final Animation<Offset> _badgeSlide;
  late final Animation<double> _headlineFade;
  late final Animation<Offset> _headlineSlide;
  late final Animation<double> _subtitleFade;

  // ── Illustration ──────────────────────────────────────────────────────────
  late final Animation<double> _illustrationFade;
  late final Animation<double> _illustrationScale;

  // ── Button ────────────────────────────────────────────────────────────────
  late final Animation<double> _buttonFade;
  late final Animation<double> _buttonScale;

  // ── Feature grid ──────────────────────────────────────────────────────────
  late final Animation<double> _gridFade;
  late final Animation<Offset> _gridSlide;

  @override
  void initState() {
    super.initState();

    // Nav — fastest, first to appear
    _navController = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 500),
    );
    _navFade  = CurvedAnimation(parent: _navController, curve: Curves.easeOut);
    _navSlide = Tween<Offset>(begin: const Offset(0, -0.4), end: Offset.zero)
        .animate(CurvedAnimation(parent: _navController, curve: Curves.easeOutCubic));

    // Badge + headline + subtitle — staggered
    _heroController = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 900),
    );
    _badgeFade = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _heroController, curve: const Interval(0.0, 0.45, curve: Curves.easeOut)),
    );
    _badgeSlide = Tween<Offset>(begin: const Offset(0, 0.35), end: Offset.zero).animate(
      CurvedAnimation(parent: _heroController, curve: const Interval(0.0, 0.45, curve: Curves.easeOutCubic)),
    );
    _headlineFade = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _heroController, curve: const Interval(0.2, 0.65, curve: Curves.easeOut)),
    );
    _headlineSlide = Tween<Offset>(begin: const Offset(0, 0.3), end: Offset.zero).animate(
      CurvedAnimation(parent: _heroController, curve: const Interval(0.2, 0.65, curve: Curves.easeOutCubic)),
    );
    _subtitleFade = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _heroController, curve: const Interval(0.45, 0.9, curve: Curves.easeOut)),
    );

    // Illustration — scale + fade
    _contentController = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 700),
    );
    _illustrationFade  = CurvedAnimation(parent: _contentController, curve: Curves.easeOut);
    _illustrationScale = Tween<double>(begin: 0.88, end: 1.0).animate(
      CurvedAnimation(parent: _contentController, curve: Curves.easeOutBack),
    );

    // Button — bounce in
    _buttonController = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 600),
    );
    _buttonFade  = CurvedAnimation(parent: _buttonController, curve: Curves.easeOut);
    _buttonScale = Tween<double>(begin: 0.82, end: 1.0).animate(
      CurvedAnimation(parent: _buttonController, curve: Curves.easeOutBack),
    );

    // Feature grid — slide up
    _gridController = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 600),
    );
    _gridFade  = CurvedAnimation(parent: _gridController, curve: Curves.easeOut);
    _gridSlide = Tween<Offset>(begin: const Offset(0, 0.25), end: Offset.zero).animate(
      CurvedAnimation(parent: _gridController, curve: Curves.easeOutCubic),
    );

    // ── Staggered sequence ────────────────────────────────────────────────
    _runSequence();
  }

  Future<void> _runSequence() async {
    await Future.delayed(const Duration(milliseconds: 80));
    _navController.forward();

    await Future.delayed(const Duration(milliseconds: 180));
    _heroController.forward();

    await Future.delayed(const Duration(milliseconds: 420));
    _contentController.forward();

    await Future.delayed(const Duration(milliseconds: 300));
    _buttonController.forward();

    await Future.delayed(const Duration(milliseconds: 180));
    _gridController.forward();
  }

  @override
  void dispose() {
    _navController.dispose();
    _heroController.dispose();
    _contentController.dispose();
    _buttonController.dispose();
    _gridController.dispose();
    super.dispose();
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F8FF),
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

  // ── Nav bar ───────────────────────────────────────────────────────────────

  Widget _buildNavBar(BuildContext context) {
    return FadeTransition(
      opacity: _navFade,
      child: SlideTransition(
        position: _navSlide,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.asset(
                    'assets/images/logo.jpeg',
                    width: 32, height: 32, fit: BoxFit.cover,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  'CityVoice',
                  style: GoogleFonts.inter(
                    fontSize: 22, fontWeight: FontWeight.w800,
                    color: Colors.black, letterSpacing: -0.5,
                  ),
                ),
              ],
            ),
            Container(
              decoration: BoxDecoration(
                color: AppColors.white,
                borderRadius: BorderRadius.circular(100),
                border: Border.all(
                  color: AppColors.primary.withOpacity(0.25), width: 1.2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 8, offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(100),
                  onTap: () => Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (_) => SignInScreen()),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 9),
                    child: Text(
                      'Sign in',
                      style: GoogleFonts.inter(
                        fontSize: 14, fontWeight: FontWeight.w600,
                        color: AppColors.primary,
                      ),
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

  // ── Badge ─────────────────────────────────────────────────────────────────

  Widget _buildBadge() {
    return FadeTransition(
      opacity: _badgeFade,
      child: SlideTransition(
        position: _badgeSlide,
        child: Container(
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
                  fontSize: 12, fontWeight: FontWeight.w500,
                  color: AppColors.textMedium,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Headline ──────────────────────────────────────────────────────────────

  Widget _buildHeadline() {
    return FadeTransition(
      opacity: _headlineFade,
      child: SlideTransition(
        position: _headlineSlide,
        child: RichText(
          textAlign: TextAlign.center,
          text: TextSpan(
            children: [
              TextSpan(
                text: 'Raise your voice.\n',
                style: GoogleFonts.inter(
                  fontSize: 34, fontWeight: FontWeight.w800,
                  color: AppColors.textDark, height: 1.2,
                ),
              ),
              TextSpan(
                text: 'Support your\nneighbors.',
                style: GoogleFonts.inter(
                  fontSize: 34, fontWeight: FontWeight.w800,
                  color: AppColors.primary, height: 1.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Subtitle ──────────────────────────────────────────────────────────────

  Widget _buildSubtitle() {
    return FadeTransition(
      opacity: _subtitleFade,
      child: Text(
        'Report local issues, support others, and\ncreate change — together, gently.',
        textAlign: TextAlign.center,
        style: GoogleFonts.inter(
          fontSize: 15, color: AppColors.textMedium, height: 1.6,
        ),
      ),
    );
  }

  // ── Illustration ──────────────────────────────────────────────────────────

  Widget _buildIllustration() {
    return FadeTransition(
      opacity: _illustrationFade,
      child: ScaleTransition(
        scale: _illustrationScale,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: Image.asset(
            'assets/images/community.png',
            width: double.infinity, fit: BoxFit.contain,
          ),
        ),
      ),
    );
  }

  // ── Get started button ────────────────────────────────────────────────────

  Widget _buildGetStartedButton(BuildContext context) {
    return FadeTransition(
      opacity: _buttonFade,
      child: ScaleTransition(
        scale: _buttonScale,
        child: Container(
          width: double.infinity,
          height: 56,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(100),
            gradient: const LinearGradient(
              colors: [Color(0xFF403DEB), AppColors.primary],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withOpacity(0.4),
                blurRadius: 20, offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(100),
              onTap: () => Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (_) => SignInScreen()),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Get started',
                    style: GoogleFonts.inter(
                      fontSize: 16, fontWeight: FontWeight.w700,
                      color: Colors.white, letterSpacing: 0.3,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    width: 26, height: 26,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.25),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.arrow_forward_rounded,
                      color: Colors.white, size: 15,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── Feature grid ──────────────────────────────────────────────────────────

  Widget _buildFeatureGrid() {
    final features = [
      _Feature(Icons.people_outline_rounded,        AppColors.communityIcon,      AppColors.communityBg,      'Community-\nled'),
      _Feature(Icons.location_on_outlined,          AppColors.hyperLocalIcon,     AppColors.hyperLocalBg,     'Hyper-\nlocal'),
      _Feature(Icons.favorite_border_rounded,       AppColors.supportiveIcon,     AppColors.supportiveBg,     'Supportive'),
      _Feature(Icons.chat_bubble_outline_rounded,   AppColors.conversationalIcon, AppColors.conversationalBg, 'Conversational'),
    ];

    return FadeTransition(
      opacity: _gridFade,
      child: SlideTransition(
        position: _gridSlide,
        child: GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 2.4,
          children: features
              .asMap()
              .entries
              .map((e) => _buildFeatureCard(e.value, e.key))
              .toList(),
        ),
      ),
    );
  }

  Widget _buildFeatureCard(_Feature f, int index) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: Duration(milliseconds: 400 + index * 80),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, 16 * (1 - value)),
            child: child,
          ),
        );
      },
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 8, offset: const Offset(0, 2),
            ),
          ],
        ),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 38, height: 38,
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
                  fontSize: 13, fontWeight: FontWeight.w600,
                  color: AppColors.textDark, height: 1.3,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Footer ────────────────────────────────────────────────────────────────

  Widget _buildFooter() {
    return FadeTransition(
      opacity: _gridFade,
      child: Text(
        'Built with care for the neighborhoods we live in.',
        style: GoogleFonts.inter(fontSize: 12, color: AppColors.textLight),
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