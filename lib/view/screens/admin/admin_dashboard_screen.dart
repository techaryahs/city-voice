import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/constants/app_colors.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  int _selectedNav = 0;
  
  // ── Firebase ──────────────────────────────────────────────────────────
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final DatabaseReference _postsRef = FirebaseDatabase.instance.ref('posts');
  final DatabaseReference _usersRef = FirebaseDatabase.instance.ref('users');

  // ── Admin Stats ───────────────────────────────────────────────────────
  int _totalUsers = 0;
  int _totalPosts = 0;
  int _resolvedPosts = 0; // Future: track status
  List<Map<String, dynamic>> _recentPosts = [];
  bool _isLoading = true;

  final List<_NavItem> _navItems = const [
    _NavItem(Icons.dashboard_rounded, 'Dashboard'),
    _NavItem(Icons.people_alt_rounded, 'User Management'),
    _NavItem(Icons.bar_chart_rounded, 'Reports'),
    _NavItem(Icons.account_tree_rounded, 'Authority Mapping'),
    _NavItem(Icons.shield_rounded, 'Content Moderation'),
    _NavItem(Icons.settings_rounded, 'Settings'),
  ];

  @override
  void initState() {
    super.initState();
    _fetchAdminData();
  }

  void _fetchAdminData() {
    // 1. Listen to Users count
    _usersRef.onValue.listen((event) {
      if (mounted && event.snapshot.value != null) {
        final data = Map<String, dynamic>.from(event.snapshot.value as Map);
        setState(() => _totalUsers = data.length);
      }
    });

    // 2. Listen to Posts
    _postsRef.onValue.listen((event) {
      if (mounted && event.snapshot.value != null) {
        final data = Map<String, dynamic>.from(event.snapshot.value as Map);
        final List<Map<String, dynamic>> loaded = [];
        
        data.forEach((key, value) {
          final p = Map<String, dynamic>.from(value as Map);
          p['key'] = key;
          loaded.add(p);
        });

        // Sort newest first
        loaded.sort((a, b) => 
          (b['timestamp'] ?? '').toString().compareTo((a['timestamp'] ?? '').toString()));

        setState(() {
          _totalPosts = loaded.length;
          _recentPosts = loaded.take(5).toList();
          _isLoading = false;
        });
      } else {
        if (mounted) setState(() { _totalPosts = 0; _recentPosts = []; _isLoading = false; });
      }
    });
  }

  Future<void> _logout() async {
    await _auth.signOut();
  }

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width > 700;

    return Scaffold(
      backgroundColor: const Color(0xFFF0F2F5),
      appBar: _buildAppBar(isWide),
      drawer: isWide ? null : _buildDrawer(),
      body: isWide
          ? Row(
        children: [
          _buildSidebar(),
          Expanded(child: _buildBody()),
        ],
      )
          : _buildBody(),
    );
  }

  // ── AppBar ────────────────────────────────────────────────────────────

  PreferredSizeWidget _buildAppBar(bool isWide) {
    return AppBar(
      backgroundColor: const Color(0xFF1B2A4A),
      elevation: 0,
      leading: isWide
          ? Padding(
        padding: const EdgeInsets.all(10),
        child: _buildLogo(),
      )
          : Builder(
        builder: (ctx) => IconButton(
          icon: const Icon(Icons.menu_rounded, color: Colors.white),
          onPressed: () => Scaffold.of(ctx).openDrawer(),
        ),
      ),
      leadingWidth: isWide ? 220 : 56,
      title: isWide
          ? null
          : Row(
        children: [
          _buildLogo(),
          const SizedBox(width: 8),
          Text('CityVoice',
              style: GoogleFonts.inter(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 18)),
        ],
      ),
      actions: [
        Stack(
          children: [
            IconButton(
              icon: const Icon(Icons.notifications_outlined,
                  color: Colors.white, size: 24),
              onPressed: () {},
            ),
            Positioned(
              right: 8,
              top: 8,
              child: Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                    color: AppColors.primary, shape: BoxShape.circle),
              ),
            ),
          ],
        ),
        IconButton(
          icon: const Icon(Icons.settings_outlined,
              color: Colors.white, size: 24),
          onPressed: () {},
        ),
        Padding(
          padding: const EdgeInsets.only(right: 16, left: 4),
          child: Row(
            children: [
              CircleAvatar(
                radius: 17,
                backgroundColor: AppColors.primary,
                child: Text('A',
                    style: GoogleFonts.inter(
                        color: Colors.white, fontWeight: FontWeight.w700)),
              ),
              const SizedBox(width: 4),
              const Icon(Icons.keyboard_arrow_down_rounded,
                  color: Colors.white, size: 18),
            ],
          ),
        ),
      ],
    );
  }

  // ── Sidebar ───────────────────────────────────────────────────────────

  Widget _buildLogo() {
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF4A90D9), Color(0xFF1B5FA8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(10),
      ),
      child: const Icon(Icons.location_city_rounded,
          color: Colors.white, size: 20),
    );
  }

  Widget _buildSidebar() {
    return Container(
      width: 220,
      color: const Color(0xFF1B2A4A),
      child: Column(
        children: [
          // Logo area
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
            child: Row(
              children: [
                _buildLogo(),
                const SizedBox(width: 10),
                Text('CityVoice',
                    style: GoogleFonts.inter(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 18,
                      letterSpacing: -0.3,
                    )),
              ],
            ),
          ),
          // Nav items
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              itemCount: _navItems.length,
              itemBuilder: (_, i) => _buildNavTile(i),
            ),
          ),
          // Logout
          Padding(
            padding: const EdgeInsets.all(16),
            child: _buildLogoutBtn(),
          ),
        ],
      ),
    );
  }

  Widget _buildDrawer() {
    return Drawer(
      backgroundColor: const Color(0xFF1B2A4A),
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
              child: Row(
                children: [
                  _buildLogo(),
                  const SizedBox(width: 10),
                  Text('CityVoice',
                      style: GoogleFonts.inter(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 18)),
                ],
              ),
            ),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                itemCount: _navItems.length,
                itemBuilder: (_, i) => _buildNavTile(i),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: _buildLogoutBtn(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNavTile(int i) {
    final isActive = _selectedNav == i;
    return GestureDetector(
      onTap: () => setState(() {
        _selectedNav = i;
        if (MediaQuery.of(context).size.width <= 700) Navigator.pop(context);
      }),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        margin: const EdgeInsets.only(bottom: 4),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: isActive
              ? AppColors.primary.withOpacity(0.85)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(_navItems[i].icon,
                color: isActive ? Colors.white : Colors.white54, size: 20),
            const SizedBox(width: 12),
            Text(
              _navItems[i].label,
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight:
                isActive ? FontWeight.w600 : FontWeight.w400,
                color: isActive ? Colors.white : Colors.white60,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLogoutBtn() {
    return GestureDetector(
      onTap: _logout,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.07),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            const Icon(Icons.logout_rounded, color: Colors.white60, size: 20),
            const SizedBox(width: 12),
            Text('Logout',
                style: GoogleFonts.inter(
                    fontSize: 14,
                    color: Colors.white60,
                    fontWeight: FontWeight.w500)),
          ],
        ),
      ),
    );
  }

  // ── Body ──────────────────────────────────────────────────────────────

  Widget _buildBody() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildPageTitle(),
          const SizedBox(height: 16),
          _buildStatCards(),
          const SizedBox(height: 16),
          _buildChartsRow(),
          const SizedBox(height: 16),
          _buildFounderCard(),
          const SizedBox(height: 16),
          _buildBottomRow(),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildPageTitle() {
    return Text(
      'Admin Dashboard',
      style: GoogleFonts.inter(
        fontSize: 22,
        fontWeight: FontWeight.w800,
        color: const Color(0xFF1B2A4A),
        letterSpacing: -0.4,
      ),
    );
  }

  // ── Stat Cards ────────────────────────────────────────────────────────

  Widget _buildStatCards() {
    final stats = [
      _StatCard('Total Users', '$_totalUsers', Icons.people_alt_rounded,
          const Color(0xFF4A7BE8), const Color(0xFFDEEAFF)),
      _StatCard('Active Reports', '$_totalPosts', Icons.bar_chart_rounded,
          const Color(0xFFE8914A), const Color(0xFFFFEEDD)),
      _StatCard('Resolved Reports', '0', Icons.check_circle_rounded,
          const Color(0xFF2ECC71), const Color(0xFFE6FAF0)),
      _StatCard('Pending Reports', '$_totalPosts', Icons.cancel_rounded,
          AppColors.primary, AppColors.communityBg),
    ];

    return LayoutBuilder(builder: (context, constraints) {
      final crossAxis = constraints.maxWidth > 500 ? 4 : 2;
      return GridView.count(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisCount: crossAxis,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: constraints.maxWidth > 500 ? 1.6 : 1.5,
        children: stats.map((s) => _buildStatCard(s)).toList(),
      );
    });
  }

  Widget _buildStatCard(_StatCard s) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 2))
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Text(s.label,
                    style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textMedium),
                    maxLines: 2),
              ),
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                    color: s.iconBg, shape: BoxShape.circle),
                child: Icon(s.icon, color: s.color, size: 18),
              ),
            ],
          ),
          Text(s.value,
              style: GoogleFonts.inter(
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  color: s.color,
                  letterSpacing: -0.5)),
        ],
      ),
    );
  }

  // ── Charts Row ────────────────────────────────────────────────────────

  Widget _buildChartsRow() {
    return LayoutBuilder(builder: (context, constraints) {
      if (constraints.maxWidth > 600) {
        return Row(
          children: [
            Expanded(child: _buildReportsChart()),
            const SizedBox(width: 12),
            Expanded(child: _buildUserActivityChart()),
          ],
        );
      }
      return Column(
        children: [
          _buildReportsChart(),
          const SizedBox(height: 12),
          _buildUserActivityChart(),
        ],
      );
    });
  }

  Widget _buildReportsChart() {
    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun'];
    final newR = [20, 15, 37, 14, 16, 16];
    final resolved = [10, 22, 12, 22, 8, 14];
    final pending = [20, 22, 14, 33, 33, 33];
    final maxVal = 40.0;

    return _buildChartCard(
      title: 'Reports Overview',
      legend: [
        _Legend(const Color(0xFF4A7BE8), 'New Reports'),
        _Legend(const Color(0xFF2ECC71), 'Resolved'),
        _Legend(AppColors.primary, 'Pending'),
      ],
      chart: SizedBox(
        height: 160,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: List.generate(months.length, (i) {
            return Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  // Bars
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      _bar(newR[i], maxVal, const Color(0xFF4A7BE8)),
                      const SizedBox(width: 2),
                      _bar(resolved[i], maxVal, const Color(0xFF2ECC71)),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(months[i],
                      style: GoogleFonts.inter(
                          fontSize: 10, color: AppColors.textLight)),
                ],
              ),
            );
          }),
        ),
      ),
    );
  }

  Widget _bar(int val, double maxVal, Color color) {
    return Container(
      width: 10,
      height: (val / maxVal) * 120,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(3),
      ),
    );
  }

  Widget _buildUserActivityChart() {
    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun'];
    final newUsers = [15.0, 20.0, 18.0, 16.0, 19.0, 25.0];
    final activeUsers = [10.0, 16.0, 20.0, 22.0, 28.0, 38.0];
    final maxVal = 40.0;

    return _buildChartCard(
      title: 'User Activity',
      legend: [
        _Legend(const Color(0xFF2ECC71), 'New Users'),
        _Legend(const Color(0xFF4A7BE8), 'Active Users'),
      ],
      chart: SizedBox(
        height: 160,
        child: CustomPaint(
          painter: _LineChartPainter(
            newUsers: newUsers,
            activeUsers: activeUsers,
            maxVal: maxVal,
            months: months,
          ),
          size: const Size(double.infinity, 160),
        ),
      ),
    );
  }

  Widget _buildChartCard({
    required String title,
    required Widget chart,
    required List<_Legend> legend,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 2))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF1B2A4A))),
          const SizedBox(height: 12),
          chart,
          const SizedBox(height: 12),
          Wrap(
            spacing: 14,
            runSpacing: 6,
            children: legend
                .map((l) => Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                        color: l.color, shape: BoxShape.circle)),
                const SizedBox(width: 5),
                Text(l.label,
                    style: GoogleFonts.inter(
                        fontSize: 11,
                        color: AppColors.textMedium)),
              ],
            ))
                .toList(),
          ),
        ],
      ),
    );
  }

  // ── Founder Card ──────────────────────────────────────────────────────

  Widget _buildFounderCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 2))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title row
          Row(
            children: [
              Expanded( // ✅ IMPORTANT FIX
                child: Text(
                  "Founder's Address",
                  style: GoogleFonts.inter(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF1B2A4A),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Wrap(
                spacing: 8,
                children: [
                  _buildOutlineBtn('Edit Address', Icons.edit_outlined),
                  _buildOutlineBtn('Change Photo', Icons.image_outlined),
                ],
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Founder info
          LayoutBuilder(builder: (ctx, constraints) {
            final isWide = constraints.maxWidth > 400;
            final content = Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'CityVoice is built to give power to your voice.',
                  style: GoogleFonts.inter(
                      fontSize: 14,
                      color: AppColors.textDark,
                      height: 1.6),
                ),
                const SizedBox(height: 6),
                Text(
                  'This is a platform where people come together, support each other, and make real change happen.',
                  style: GoogleFonts.inter(
                      fontSize: 14,
                      color: AppColors.textMedium,
                      height: 1.6),
                ),
                const SizedBox(height: 6),
                RichText(
                  text: TextSpan(
                    children: [
                      TextSpan(
                        text: 'Speak up',
                        style: GoogleFonts.inter(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textDark),
                      ),
                      TextSpan(
                        text:
                        ' — because together, our voices are stronger.',
                        style: GoogleFonts.inter(
                            fontSize: 14,
                            color: AppColors.textMedium,
                            height: 1.6),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.bottomRight,
                  child: Text(
                    'Last Updated : July 15, 2021  ▾',
                    style: GoogleFonts.inter(
                        fontSize: 12, color: AppColors.textLight),
                  ),
                ),
              ],
            );

            final avatar = Column(
              children: [
                CircleAvatar(
                  radius: 44,
                  backgroundColor: AppColors.communityBg,
                  child: Text('A',
                      style: GoogleFonts.inter(
                          fontSize: 32,
                          fontWeight: FontWeight.w800,
                          color: AppColors.primary)),
                ),
                const SizedBox(height: 8),
                Text('Abhijit Polke',
                    style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textDark)),
                Text('Founder, CityVoice',
                    style: GoogleFonts.inter(
                        fontSize: 11, color: AppColors.textLight)),
              ],
            );

            return isWide
                ? Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                avatar,
                const SizedBox(width: 20),
                Expanded(child: content),
              ],
            )
                : Column(
              children: [avatar, const SizedBox(height: 16), content],
            );
          }),
        ],
      ),
    );
  }

  Widget _buildOutlineBtn(String label, IconData icon) {
    return OutlinedButton.icon(
      onPressed: () {},
      icon: Icon(icon, size: 14, color: AppColors.textMedium),
      label: Text(label,
          style: GoogleFonts.inter(
              fontSize: 12,
              color: AppColors.textMedium,
              fontWeight: FontWeight.w500)),
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        side: BorderSide(color: Colors.black.withOpacity(0.15)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  // ── Bottom Row ────────────────────────────────────────────────────────

  Widget _buildBottomRow() {
    return LayoutBuilder(builder: (context, constraints) {
      if (constraints.maxWidth > 600) {
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(flex: 2, child: _buildRecentReports()),
            const SizedBox(width: 12),
            Expanded(flex: 2, child: _buildAuthorityMapping()),
            const SizedBox(width: 12),
            Expanded(flex: 1, child: _buildAnnouncements()),
          ],
        );
      }
      return Column(
        children: [
          _buildRecentReports(),
          const SizedBox(height: 12),
          _buildAuthorityMapping(),
          const SizedBox(height: 12),
          _buildAnnouncements(),
        ],
      );
    });
  }

  Widget _buildRecentReports() {
    if (_recentPosts.isEmpty) {
      return _buildSectionCard(
        title: 'Recent Reports',
        child: Center(child: Text('No reports yet.', style: GoogleFonts.inter(fontSize: 12, color: AppColors.textLight))),
      );
    }

    return _buildSectionCard(
      title: 'Recent Reports',
      child: Column(
        children: _recentPosts
            .map((r) => Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Row(
            children: [
              Expanded(
                child: Text(r['description'] ?? 'No text',
                    style: GoogleFonts.inter(
                        fontSize: 13,
                        color: AppColors.textDark,
                        fontWeight: FontWeight.w500),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
              ),
              const SizedBox(width: 8),
              _statusChip(r['category'] ?? 'General', AppColors.primary),
            ],
          ),
        ))
            .toList(),
      ),
    );
  }

  Widget _statusChip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(100),
      ),
      child: Text(label,
          style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: Colors.white)),
    );
  }

  Widget _buildAuthorityMapping() {
    final authorities = ['Ward A BMC', 'Ward C–1 BMC', 'Mumbai Police Zone 3'];

    return _buildSectionCard(
      title: 'Authority Mapping',
      child: Column(
        children: authorities
            .map((a) => Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(a,
                    style: GoogleFonts.inter(
                        fontSize: 13,
                        color: AppColors.textDark,
                        fontWeight: FontWeight.w500)),
              ),
              OutlinedButton(
                onPressed: () {},
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 6),
                  side: BorderSide(
                      color: Colors.black.withOpacity(0.2)),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Text('Edit',
                    style: GoogleFonts.inter(
                        fontSize: 12,
                        color: AppColors.textDark,
                        fontWeight: FontWeight.w500)),
              ),
            ],
          ),
        ))
            .toList(),
      ),
    );
  }

  Widget _buildAnnouncements() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF8E6),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFFD866).withOpacity(0.5)),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 10,
              offset: const Offset(0, 2))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                    color: const Color(0xFFFFD866),
                    borderRadius: BorderRadius.circular(8)),
                child: const Icon(Icons.campaign_rounded,
                    size: 16, color: Color(0xFF8B6000)),
              ),
              const SizedBox(width: 8),
              Text('Announcements',
                  style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF8B6000))),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('•',
                  style: TextStyle(
                      color: Color(0xFF8B6000), fontSize: 14)),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'System maintenance on August 5th, 2021',
                  style: GoogleFonts.inter(
                      fontSize: 12,
                      color: const Color(0xFF7A5500),
                      height: 1.5),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSectionCard({required String title, required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 2))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF1B2A4A))),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}

// ── Line Chart Painter ────────────────────────────────────────────────────

class _LineChartPainter extends CustomPainter {
  final List<double> newUsers;
  final List<double> activeUsers;
  final double maxVal;
  final List<String> months;

  _LineChartPainter({
    required this.newUsers,
    required this.activeUsers,
    required this.maxVal,
    required this.months,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final chartH = size.height - 24;
    final stepX = size.width / (newUsers.length - 1);

    _drawLine(canvas, size, newUsers, stepX, chartH,
        const Color(0xFF2ECC71));
    _drawLine(canvas, size, activeUsers, stepX, chartH,
        const Color(0xFF4A7BE8));

    // Month labels
    final tp = TextPainter(textDirection: TextDirection.ltr);
    for (int i = 0; i < months.length; i++) {
      tp.text = TextSpan(
        text: months[i],
        style: const TextStyle(
            fontSize: 10, color: Color(0xFF999999)),
      );
      tp.layout();
      tp.paint(canvas,
          Offset(stepX * i - tp.width / 2, chartH + 6));
    }
  }

  void _drawLine(Canvas canvas, Size size, List<double> data, double stepX,
      double chartH, Color color) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final path = Path();
    for (int i = 0; i < data.length; i++) {
      final x = stepX * i;
      final y = chartH - (data[i] / maxVal) * chartH;
      i == 0 ? path.moveTo(x, y) : path.lineTo(x, y);

      // Dot
      canvas.drawCircle(
          Offset(x, y),
          3.5,
          Paint()
            ..color = Colors.white
            ..style = PaintingStyle.fill);
      canvas.drawCircle(
          Offset(x, y),
          3.5,
          Paint()
            ..color = color
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2);
    }
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ── Data classes ──────────────────────────────────────────────────────────

class _NavItem {
  final IconData icon;
  final String label;
  const _NavItem(this.icon, this.label);
}

class _StatCard {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final Color iconBg;
  const _StatCard(this.label, this.value, this.icon, this.color, this.iconBg);
}

class _Report {
  final String title;
  final String currentStatus;
  final String newStatus;
  final Color currentColor;
  final Color newColor;
  const _Report(this.title, this.currentStatus, this.newStatus,
      this.currentColor, this.newColor);
}

class _Legend {
  final Color color;
  final String label;
  const _Legend(this.color, this.label);
}