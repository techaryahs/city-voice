import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/constants/app_colors.dart';
import 'app_info_page.dart';
import 'blocked_users_page.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final DatabaseReference _usersRef = FirebaseDatabase.instance.ref('users');

  List<Map<String, dynamic>> _blockedUsers = [];

  @override
  void initState() {
    super.initState();
    _listenToBlockedUsers();
  }

  void _listenToBlockedUsers() {
    final user = _auth.currentUser;
    if (user == null) return;

    _usersRef.child(user.uid).child('blockedUsers').onValue.listen((event) {
      final users = <Map<String, dynamic>>[];
      if (event.snapshot.value is Map) {
        final data = Map<String, dynamic>.from(event.snapshot.value as Map);
        for (final entry in data.entries) {
          if (entry.value is Map) {
            final record = Map<String, dynamic>.from(entry.value as Map);
            users.add({
              'uid': (record['uid'] ?? entry.key).toString(),
              'name': (record['name'] ?? 'CityVoice user').toString(),
            });
          }
        }
      }
      users.sort((a, b) => (a['name'] ?? '')
          .toString()
          .toLowerCase()
          .compareTo((b['name'] ?? '').toString().toLowerCase()));
      if (mounted) {
        setState(() => _blockedUsers = users);
      }
    });
  }
 
  // Opens the reusable detail page for About or Terms content.
  void _openInfoPage(AppInfoType type) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AppInfoPage(type: type),
      ),
    );
  }

  // Opens the full blocked-users manager page.
  void _openBlockedUsersPage() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const BlockedUsersPage(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: AppColors.textDark,
        title: Text(
          'Settings',
          style: GoogleFonts.inter(
            fontWeight: FontWeight.w800,
            color: AppColors.textDark,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 28),
        children: [
          _buildHeaderCard(),
          const SizedBox(height: 14),
          _buildBlockedUsersSection(),
          const SizedBox(height: 14),
          _buildInfoSection(),
        ],
      ),
    );
  }

  // Builds the professional top summary card.
  Widget _buildHeaderCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFD7E9FF)),
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: const BoxDecoration(
              color: Color(0xFFEAF3FF),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.settings_outlined,
              color: Color(0xFF0052D4),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Account Settings',
                  style: GoogleFonts.inter(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textDark,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Manage safety controls and app information.',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: AppColors.textMedium,
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Shows the safety setting and routes blocked users to its own page.
  Widget _buildBlockedUsersSection() {
    final blockedPreview = _blockedUsers
        .take(3)
        .map((user) => (user['name'] ?? 'CityVoice user').toString())
        .join(', ');

    return _settingsGroup(
      title: 'Safety',
      children: [
        _settingsTile(
          icon: Icons.person_off_outlined,
          title: 'Blocked Users',
          subtitle: _blockedUsers.isEmpty
              ? 'Manage hidden users and unblock them anytime.'
              : 'Blocked: $blockedPreview${_blockedUsers.length > 3 ? ' and ${_blockedUsers.length - 3} more' : ''}',
          onTap: _openBlockedUsersPage,
        ),
        if (_blockedUsers.isNotEmpty) ...[
          const SizedBox(height: 10),
          ..._blockedUsers.take(3).map(_blockedUserPreviewTile),
        ],
      ],
    );
  }

  // Shows blocked names directly on Settings before opening the full page.
  Widget _blockedUserPreviewTile(Map<String, dynamic> user) {
    final name = (user['name'] ?? 'CityVoice user').toString();

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: const BoxDecoration(
              color: Color(0xFFEAF3FF),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                name.isNotEmpty ? name[0].toUpperCase() : '?',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF0052D4),
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppColors.textDark,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Shows About and Terms entry points.
  Widget _buildInfoSection() {
    return _settingsGroup(
      title: 'App Information',
      children: [
        _settingsTile(
          icon: Icons.info_outline_rounded,
          title: 'About CityVoice India',
          subtitle: 'Mission, safety, moderation, and contact details.',
          onTap: () => _openInfoPage(AppInfoType.about),
        ),
        const SizedBox(height: 10),
        _settingsTile(
          icon: Icons.description_outlined,
          title: 'Terms & Conditions',
          subtitle: 'Platform rules, user conduct, and moderation policy.',
          onTap: () => _openInfoPage(AppInfoType.terms),
        ),
      ],
    );
  }

  // Shared white group container used by Settings sections.
  Widget _settingsGroup({
    required String title,
    required List<Widget> children,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: const Color(0xFF0052D4),
            ),
          ),
          const SizedBox(height: 14),
          ...children,
        ],
      ),
    );
  }

  // Shared tappable row used for each Settings destination.
  Widget _settingsTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Material(
      color: AppColors.background,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              _roundIcon(icon),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textDark,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: AppColors.textLight,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              const Icon(
                Icons.chevron_right_rounded,
                color: Color(0xFF8FA4BC),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Shared circular icon style for settings rows.
  Widget _roundIcon(IconData icon) {
    return Container(
      width: 40,
      height: 40,
      decoration: const BoxDecoration(
        color: Color(0xFFEAF3FF),
        shape: BoxShape.circle,
      ),
      child: Icon(
        icon,
        color: const Color(0xFF0052D4),
        size: 20,
      ),
    );
  }
}
