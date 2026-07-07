import 'dart:async';

import 'package:cityvoice/view/screens/users/profile/profile_screen.dart';
import 'package:cityvoice/view/screens/users/raise_voice/raise_voice_page.dart';
import 'package:cityvoice/view/screens/users/voices/voices_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/constants/app_colors.dart';
import 'maps/map_screen.dart';
import 'notification/alerts_screen.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;
  bool _hasUpdatesDot = false;
  int _updatesBadgeCount = 0;
  DateTime? _latestAdminNoticeAt;

  final DatabaseReference _usersRef =
      FirebaseDatabase.instance.ref().child('users');
  final DatabaseReference _notificationsRef =
      FirebaseDatabase.instance.ref().child('notifications');
  StreamSubscription<DatabaseEvent>? _notificationsSubscription;

  List<Widget> _screens(bool isBlocked) => [
        VoicesScreen(
          readOnly: isBlocked,
          updatesBadgeCount: _updatesBadgeCount,
        ),
        MapScreen(readOnly: isBlocked),
        const AlertsScreen(),
        ProfileScreen(readOnly: isBlocked),
      ];

  @override
  void initState() {
    super.initState();
    _requestLocationPermission();
    _listenForUpdateDot();
  }

  @override
  void dispose() {
    _notificationsSubscription?.cancel();
    super.dispose();
  }

  void _listenForUpdateDot() {
    _notificationsSubscription = _notificationsRef.onValue.listen((event) async {
      DateTime? latestNoticeAt;
      final activeNoticeDates = <DateTime>[];
      final now = DateTime.now();
      if (event.snapshot.value is Map) {
        final raw = Map<String, dynamic>.from(event.snapshot.value as Map);
        for (final value in raw.values) {
          if (value is! Map) continue;
          final notice = Map<String, dynamic>.from(value);
          if ((notice['type'] ?? '').toString() != 'admin_notify') continue;

          final expiresAt = DateTime.tryParse(
            (notice['expiresAt'] ?? '').toString(),
          );
          if (expiresAt != null && !expiresAt.isAfter(now)) continue;

          final createdAt = DateTime.tryParse(
            (notice['createdAt'] ?? '').toString(),
          ) ?? now;
          if (latestNoticeAt == null || createdAt.isAfter(latestNoticeAt)) {
            latestNoticeAt = createdAt;
          }
          activeNoticeDates.add(createdAt);
        }
      }

      _latestAdminNoticeAt = latestNoticeAt;
      final lastSeenAt = await _loadLastSeenAdminNoticeAt();
      final unseenCount = activeNoticeDates
          .where((date) => lastSeenAt == null || date.isAfter(lastSeenAt))
          .length;
      final hasActiveNotice = unseenCount > 0;

      if (mounted &&
          (_hasUpdatesDot != hasActiveNotice ||
              _updatesBadgeCount != unseenCount)) {
        setState(() {
          _hasUpdatesDot = hasActiveNotice;
          _updatesBadgeCount = unseenCount;
        });
      }
    });
  }

  Future<DateTime?> _loadLastSeenAdminNoticeAt() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return null;

    final snapshot =
        await _usersRef.child(uid).child('lastSeenAdminNoticeAt').get();
    return DateTime.tryParse((snapshot.value ?? '').toString());
  }

  Future<void> _markUpdatesSeen() async {
    if (_currentIndex == 2) return;

    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null && _latestAdminNoticeAt != null) {
      await _usersRef
          .child(uid)
          .child('lastSeenAdminNoticeAt')
          .set(DateTime.now().toIso8601String());
    }

    if (mounted && (_hasUpdatesDot || _updatesBadgeCount != 0)) {
      setState(() {
        _hasUpdatesDot = false;
        _updatesBadgeCount = 0;
      });
    }
  }

  Future<void> _requestLocationPermission() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return;

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;

    if (uid == null) {
      return const Scaffold(
        backgroundColor: AppColors.background,
        body: Center(child: CircularProgressIndicator(color: AppColors.primary)),
      );
    }

    return StreamBuilder<DatabaseEvent>(
      stream: _usersRef.child(uid).onValue,
      builder: (context, snapshot) {
        final userData = snapshot.data?.snapshot.value is Map
            ? Map<String, dynamic>.from(snapshot.data!.snapshot.value as Map)
            : <String, dynamic>{};
        final isBlocked =
            userData['isBlocked'] == true || userData['blocked'] == true;

        return Scaffold(
          resizeToAvoidBottomInset: false,
          backgroundColor: AppColors.background,
          body: _screens(isBlocked)[_currentIndex],
          bottomNavigationBar: _buildBottomBar(isBlocked),
        );
      },
    );
  }

  Widget _buildBlockedBanner() {
    return SafeArea(
      bottom: false,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(18, 14, 18, 14),
        color: const Color(0xFFEAF3FF),
        child: Row(
          children: [
            const Icon(Icons.block_rounded, color: AppColors.primary, size: 22),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Your account is blocked. You can only view posts.',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textDark,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFAB(bool isBlocked) {
    final isLandscape =
        MediaQuery.of(context).orientation == Orientation.landscape;

    return SizedBox(
      width: isLandscape ? 62 : 78,
      height: isLandscape ? 48 : 72,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: isLandscape ? 42 : 50,
            height: isLandscape ? 42 : 50,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                colors: [Color(0xFF2F6BFF), Color(0xFF006FFB)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF2F6BFF).withOpacity(0.36),
                  blurRadius: 18,
                  offset: const Offset(0, 7),
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              shape: const CircleBorder(),
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: () {
                  if (isBlocked) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Your account is blocked. You can only view posts.',
                        ),
                      ),
                    );
                    return;
                  }

                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const RaiseVoicePage(),
                    ),
                  );
                },
                child: Icon(
                  Icons.add_rounded,
                  color: Colors.white,
                  size: isLandscape ? 26 : 30,
                ),
              ),
            ),
          ),
          if (!isLandscape) ...[
            const SizedBox(height: 2),
            Text(
              'Raise Issue',
              style: GoogleFonts.inter(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF1E4FD6),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildBottomBar(bool isBlocked) {
    final isLandscape =
        MediaQuery.of(context).orientation == Orientation.landscape;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.07),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        child: SizedBox(
          height: isLandscape ? 54 : 78,
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.topCenter,
            children: [
              Row(
                children: [
                  _buildNavItem(0, Icons.home_rounded, Icons.home_outlined, 'Home'),
                  _buildNavItem(1, Icons.map_rounded, Icons.map_outlined, 'Map'),
                  const Expanded(child: SizedBox()),
                  _buildNavItem(
                    2,
                    Icons.article_rounded,
                    Icons.article_outlined,
                    'Updates',
                    showDot: _hasUpdatesDot,
                  ),
                  _buildNavItem(
                    3,
                    Icons.person_rounded,
                    Icons.person_outlined,
                    'Profile',
                  ),
                ],
              ),
              Positioned(
                top: isLandscape ? -16 : -28,
                child: _buildFAB(isBlocked),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(
    int index,
    IconData activeIcon,
    IconData inactiveIcon,
    String label, {
    bool showDot = false,
  }) {
    final isActive = _currentIndex == index;
    final isLandscape =
        MediaQuery.of(context).orientation == Orientation.landscape;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          if (index == 2) {
            _markUpdatesSeen();
          }
          setState(() => _currentIndex = index);
        },
        behavior: HitTestBehavior.opaque,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Icon(
                  isActive ? activeIcon : inactiveIcon,
                  color: isActive
                      ? const Color(0xFF2F6BFF)
                      : const Color(0xFF5B6274),
                  size: isLandscape ? 21 : 24,
                ),
                if (showDot)
                  Positioned(
                    top: -2,
                    right: -3,
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: Color(0xFFE53935),
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
              ],
            ),
            SizedBox(height: isLandscape ? 1 : 4),
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: isLandscape ? 9 : 11,
                fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                color: isActive
                    ? const Color(0xFF2F6BFF)
                    : const Color(0xFF5B6274),
              ),
            ),
            if (!isLandscape && isActive && index == 0) ...[
              const SizedBox(height: 5),
              Container(
                width: 28,
                height: 3,
                decoration: BoxDecoration(
                  color: const Color(0xFF2F6BFF),
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
