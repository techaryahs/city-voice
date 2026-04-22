import 'package:cityvoice/view/auth/signin_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/constants/app_colors.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  int _selectedTab = 0;

  // ── Firebase ──────────────────────────────────────────────────────────
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final DatabaseReference _dbRef =
      FirebaseDatabase.instance.ref().child('users');

  // ── User state ────────────────────────────────────────────────────────
  bool _isLoading = true;
  String _name = '';
  String _email = '';
  String _location = '';   // built from address + pincode
  int _voicesCount = 0;
  int _supportedCount = 0;
  int _repliesCount = 0;

  // ── Post lists (still static until you wire them to Firebase) ─────────
  final List<_PostItem> _myPosts = [
    _PostItem(
      text: 'Garbage has been piling up in this area for several days and is not bein...',
      timeAgo: '22h ago',
      hasImage: true,
    ),
  ];

  final List<_PostItem> _supportedPosts = [
    _PostItem(
      text: 'Streetlights on the main road have not been working for over 2 weeks now...',
      timeAgo: '3h ago',
      hasImage: false,
    ),
    _PostItem(
      text: 'There is a continuous water leakage from a damaged pipeline in this area...',
      timeAgo: '21h ago',
      hasImage: true,
    ),
  ];

  final List<_PostItem> _replies = [
    _PostItem(
      text: 'Totally agree, this needs immediate attention from the authorities.',
      timeAgo: '1d ago',
      hasImage: false,
    ),
  ];

  // ── Lifecycle ─────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      setState(() => _selectedTab = _tabController.index);
    });
    _fetchUserData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // ── Data fetching ─────────────────────────────────────────────────────

  Future<void> _fetchUserData() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;

      final snapshot = await _dbRef.child(user.uid).get();
      if (!mounted) return;

      if (snapshot.exists) {
        final data = Map<String, dynamic>.from(snapshot.value as Map);

        final address = (data['address'] ?? '').toString().trim();
        final pincode = (data['pincode'] ?? '').toString().trim();

        setState(() {
          _name = (data['name'] ?? 'User').toString();
          _email = (data['email'] ?? user.email ?? '').toString();
          _location = [address, pincode]
              .where((s) => s.isNotEmpty)
              .join(', ');
        });
      } else {
        // Fallback to auth email if DB record missing
        setState(() {
          _email = user.email ?? '';
          _name = user.displayName ?? 'User';
        });
      }
    } catch (e) {
      debugPrint('ProfileScreen: failed to fetch user data — $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ── Logout ────────────────────────────────────────────────────────────

  Future<void> _logout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Log out?',
          style: GoogleFonts.inter(fontWeight: FontWeight.w700),
        ),
        content: Text(
          'Are you sure you want to sign out?',
          style: GoogleFonts.inter(color: AppColors.textMedium),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              'Cancel',
              style: GoogleFonts.inter(color: AppColors.textMedium),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              'Log out',
              style: GoogleFonts.inter(
                color: Colors.redAccent,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    await _auth.signOut();

    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const SignInScreen()),
      (route) => false,
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: AppColors.background,
        body: Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: NestedScrollView(
          headerSliverBuilder: (context, _) => [
            SliverToBoxAdapter(child: _buildProfileHeader()),
            SliverToBoxAdapter(child: _buildStatsCard()),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                child: _buildTabBar(),
              ),
            ),
          ],
          body: TabBarView(
            controller: _tabController,
            children: [
              _buildPostList(_myPosts),
              _buildPostList(_supportedPosts),
              _buildPostList(_replies),
            ],
          ),
        ),
      ),
    );
  }

  // ── Header ───────────────────────────────────────────────────────────

  Widget _buildProfileHeader() {
    return Container(
      color: AppColors.white,
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      child: Column(
        children: [
          // Logout button top right
          Align(
            alignment: Alignment.centerRight,
            child: GestureDetector(
              onTap: _logout,
              child: Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: AppColors.background,
                  shape: BoxShape.circle,
                  border:
                      Border.all(color: Colors.black.withOpacity(0.07)),
                ),
                child: Icon(Icons.logout_rounded,
                    size: 18, color: AppColors.textMedium),
              ),
            ),
          ),

          const SizedBox(height: 4),

          // Avatar
          Container(
            width: 84,
            height: 84,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFFF7B5F), AppColors.primary],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withOpacity(0.35),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Center(
              child: Text(
                _name.isNotEmpty ? _name[0].toUpperCase() : '?',
                style: GoogleFonts.inter(
                  fontSize: 34,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
            ),
          ),

          const SizedBox(height: 14),

          // Name
          Text(
            _name,
            style: GoogleFonts.inter(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: AppColors.textDark,
              letterSpacing: -0.4,
            ),
          ),

          const SizedBox(height: 4),

          // Email
          Text(
            _email,
            style: GoogleFonts.inter(
              fontSize: 13,
              color: AppColors.textLight,
            ),
          ),

          if (_location.isNotEmpty) ...[
            const SizedBox(height: 6),

            // Location
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.location_on_outlined,
                    size: 13, color: AppColors.primary),
                const SizedBox(width: 3),
                Text(
                  _location,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: AppColors.textMedium,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ],

          const SizedBox(height: 14),

          // Edit profile button
          GestureDetector(
            onTap: () {},
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(100),
                border: Border.all(
                    color: AppColors.primary.withOpacity(0.3)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.edit_outlined,
                      size: 14, color: AppColors.primary),
                  const SizedBox(width: 6),
                  Text(
                    'Edit Profile',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Stats ─────────────────────────────────────────────────────────────

  Widget _buildStatsCard() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Row(
        children: [
          _buildStatItem(
            icon: Icons.campaign_outlined,
            iconColor: AppColors.primary,
            iconBg: AppColors.communityBg,
            count: _voicesCount,
            label: 'VOICES',
          ),
          _buildStatDivider(),
          _buildStatItem(
            icon: Icons.favorite_border_rounded,
            iconColor: AppColors.supportiveIcon,
            iconBg: AppColors.supportiveBg,
            count: _supportedCount,
            label: 'SUPPORTED',
          ),
          _buildStatDivider(),
          _buildStatItem(
            icon: Icons.chat_bubble_outline_rounded,
            iconColor: AppColors.conversationalIcon,
            iconBg: AppColors.conversationalBg,
            count: _repliesCount,
            label: 'REPLIES',
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem({
    required IconData icon,
    required Color iconColor,
    required Color iconBg,
    required int count,
    required String label,
  }) {
    return Expanded(
      child: Column(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: iconBg,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 18, color: iconColor),
          ),
          const SizedBox(height: 8),
          Text(
            '$count',
            style: GoogleFonts.inter(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: AppColors.textDark,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: AppColors.textLight,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatDivider() {
    return Container(
      width: 1,
      height: 48,
      color: Colors.black.withOpacity(0.07),
    );
  }

  // ── Tab Bar ───────────────────────────────────────────────────────────

  Widget _buildTabBar() {
    final tabs = ['My Posts', 'Supported', 'Replies'];
    return Container(
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(100),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(4),
      child: Row(
        children: List.generate(tabs.length, (i) {
          final isActive = _selectedTab == i;
          return Expanded(
            child: GestureDetector(
              onTap: () {
                _tabController.animateTo(i);
                setState(() => _selectedTab = i);
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: isActive ? AppColors.textDark : Colors.transparent,
                  borderRadius: BorderRadius.circular(100),
                ),
                child: Text(
                  tabs[i],
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: isActive ? AppColors.white : AppColors.textLight,
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  // ── Post List ─────────────────────────────────────────────────────────

  Widget _buildPostList(List<_PostItem> posts) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      children: [
        ...posts.map((p) => _buildPostItem(p)),
        const SizedBox(height: 16),
        _buildVisionCard(),
      ],
    );
  }

  Widget _buildPostItem(_PostItem post) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Thumbnail
          ClipRRect(
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(16),
              bottomLeft: Radius.circular(16),
            ),
            child: Container(
              width: 80,
              height: 80,
              color: post.hasImage
                  ? const Color(0xFFB5C4A0)
                  : AppColors.background,
              child: post.hasImage
                  ? Icon(Icons.image_outlined,
                      color: Colors.white.withOpacity(0.6), size: 28)
                  : Icon(Icons.chat_bubble_outline_rounded,
                      color: AppColors.textLight, size: 24),
            ),
          ),

          // Text
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    post.text,
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      color: AppColors.textDark,
                      height: 1.5,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    post.timeAgo,
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      color: AppColors.textLight,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Vision Card ───────────────────────────────────────────────────────

  Widget _buildVisionCard() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Our Vision heading
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppColors.hyperLocalBg,
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.hub_outlined,
                    size: 18, color: AppColors.hyperLocalIcon),
              ),
              const SizedBox(width: 10),
              Text(
                'Our Vision',
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textDark,
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          Text(
            'A world where every neighborhood has a calm, trusted voice for the change it wants to see.',
            style: GoogleFonts.inter(
              fontSize: 14,
              color: AppColors.textMedium,
              height: 1.6,
            ),
          ),

          const SizedBox(height: 20),

          // Divider
          Divider(color: Colors.black.withOpacity(0.07)),

          const SizedBox(height: 14),

          // Founder note
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFFFF7B5F), AppColors.primary],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    'A',
                    style: GoogleFonts.inter(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'A note from our founder',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textDark,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '"Change starts with listening."',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        color: AppColors.textMedium,
                        fontStyle: FontStyle.italic,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Founders address
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.black.withOpacity(0.06)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'TEAM CITYVOICE',
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Pune, Maharashtra, India\nBuilt with care for neighborhoods we live in.',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: AppColors.textMedium,
                    height: 1.6,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PostItem {
  final String text;
  final String timeAgo;
  final bool hasImage;

  const _PostItem({
    required this.text,
    required this.timeAgo,
    required this.hasImage,
  });
}