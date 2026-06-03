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

  final DatabaseReference _usersRef =
      FirebaseDatabase.instance.ref().child('users');

  List<Widget> _screens(bool isBlocked) => [
        VoicesScreen(readOnly: isBlocked),
        MapScreen(readOnly: isBlocked),
        const AlertsScreen(),
        ProfileScreen(readOnly: isBlocked),
      ];

  @override
  void initState() {
    super.initState();
    _requestLocationPermission();
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
          backgroundColor: AppColors.background,
          body: _screens(isBlocked)[_currentIndex],
          floatingActionButton: _buildFAB(isBlocked),
          floatingActionButtonLocation:
              FloatingActionButtonLocation.centerDocked,
          bottomNavigationBar: _buildBottomBar(),
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
        color: const Color(0xFFFFF0EE),
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
    return Container(
      width: 58,
      height: 58,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const LinearGradient(
          colors: [Color(0xFF4364F7), AppColors.primary],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.45),
            blurRadius: 18,
            offset: const Offset(0, 6),
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
                  content: Text('Your account is blocked. You can only view posts.'),
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
          child: const Icon(Icons.add_rounded, color: Colors.white, size: 28),
        ),
      ),
    );
  }

  Widget _buildBottomBar() {
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
          height: 64,
          child: Row(
            children: [
              _buildNavItem(0, Icons.home_rounded, Icons.home_outlined, 'Voices'),
              _buildNavItem(1, Icons.map_rounded, Icons.map_outlined, 'Map'),
              const Expanded(child: SizedBox()),
              _buildNavItem(
                2,
                Icons.notifications_rounded,
                Icons.notifications_outlined,
                'Alerts',
              ),
              _buildNavItem(
                3,
                Icons.person_rounded,
                Icons.person_outlined,
                'Profile',
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
    String label,
  ) {
    final isActive = _currentIndex == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _currentIndex = index),
        behavior: HitTestBehavior.opaque,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isActive ? activeIcon : inactiveIcon,
              color: isActive ? AppColors.primary : AppColors.textLight,
              size: 24,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
                color: isActive ? AppColors.primary : AppColors.textLight,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
