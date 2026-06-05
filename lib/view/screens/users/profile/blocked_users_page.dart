import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/constants/app_colors.dart';

class BlockedUsersPage extends StatefulWidget {
  const BlockedUsersPage({super.key});

  @override
  State<BlockedUsersPage> createState() => _BlockedUsersPageState();
}

class _BlockedUsersPageState extends State<BlockedUsersPage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final DatabaseReference _usersRef = FirebaseDatabase.instance.ref('users');

  List<Map<String, dynamic>> _blockedUsers = [];

  @override
  void initState() {
    super.initState();
    _listenToBlockedUsers();
  }

  // Keeps the page synced with the current user's blocked-users list.
  void _listenToBlockedUsers() {
    final user = _auth.currentUser;
    if (user == null) return;

    _usersRef.child(user.uid).child('blockedUsers').onValue.listen((event) {
      _refreshBlockedUsers(user.uid, event.snapshot);
    });
  }

  // Combines primary and fallback block records, then resolves missing names.
  Future<void> _refreshBlockedUsers(String currentUid, DataSnapshot snap) async {
    final records = <String, Map<String, dynamic>>{};

    void collect(DataSnapshot snapshot) {
      if (snapshot.value is! Map) return;
      final data = Map<String, dynamic>.from(snapshot.value as Map);
      for (final entry in data.entries) {
        final value = entry.value;
        if (value is Map) {
          final blockedUser = Map<String, dynamic>.from(value);
          final uid = (blockedUser['uid'] ?? entry.key).toString();
          records[uid] = {
            'uid': uid,
            'name': (blockedUser['name'] ?? '').toString(),
            'blockedAt': blockedUser['blockedAt'],
          };
        } else if (value == true) {
          records[entry.key] = {
            'uid': entry.key,
            'name': '',
          };
        }
      }
    }

    collect(snap);

    try {
      final fallbackSnap = await FirebaseDatabase.instance
          .ref('userBlocks')
          .child(currentUid)
          .get();
      collect(fallbackSnap);
    } catch (_) {}

    for (final userRecord in records.values) {
      final currentName = (userRecord['name'] ?? '').toString().trim();
      if (currentName.isNotEmpty && currentName != 'CityVoice user') continue;

      final uid = (userRecord['uid'] ?? '').toString();
      if (uid.isEmpty) continue;

      try {
        final userSnap = await _usersRef.child(uid).get();
        if (userSnap.value is Map) {
          final userData = Map<String, dynamic>.from(userSnap.value as Map);
          final resolvedName = (userData['name'] ??
                  userData['fullName'] ??
                  userData['email'] ??
                  '')
              .toString()
              .trim();
          if (resolvedName.isNotEmpty) {
            userRecord['name'] = resolvedName;
          }
        }
      } catch (_) {}
      userRecord['name'] =
          (userRecord['name'] ?? '').toString().trim().isEmpty
              ? 'CityVoice user'
              : userRecord['name'];
    }

    final blockedUsers = records.values.toList()
      ..sort((a, b) => (a['name'] ?? '')
          .toString()
          .toLowerCase()
          .compareTo((b['name'] ?? '').toString().toLowerCase()));

    if (mounted) {
      setState(() {
        _blockedUsers = blockedUsers;
      });
    }
  }

  // Confirms and removes a user from the current user's blocked list.
  Future<void> _unblockUser(Map<String, dynamic> blockedUser) async {
    final user = _auth.currentUser;
    final blockedUid = (blockedUser['uid'] ?? '').toString();
    final blockedName = (blockedUser['name'] ?? 'User').toString();

    if (user == null || blockedUid.isEmpty) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Text(
          'Unblock $blockedName?',
          style: GoogleFonts.inter(fontWeight: FontWeight.w800),
        ),
        content: Text(
          'You will start seeing posts, replies, and alerts from this user again.',
          style: GoogleFonts.inter(
            fontSize: 13,
            color: AppColors.textMedium,
            height: 1.5,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'Cancel',
              style: GoogleFonts.inter(color: AppColors.textMedium),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              'Unblock',
              style: GoogleFonts.inter(
                color: const Color(0xFF0052D4),
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await _usersRef
          .child(user.uid)
          .child('blockedUsers')
          .child(blockedUid)
          .remove();
      await FirebaseDatabase.instance
          .ref('userBlocks')
          .child(user.uid)
          .child(blockedUid)
          .remove();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not unblock $blockedName: $e')),
      );
      return;
    }

    if (!mounted) return;
    setState(() {
      _blockedUsers = _blockedUsers
          .where((item) => (item['uid'] ?? '').toString() != blockedUid)
          .toList();
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$blockedName unblocked.')),
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
          'Blocked Users',
          style: GoogleFonts.inter(
            fontWeight: FontWeight.w800,
            color: AppColors.textDark,
          ),
        ),
      ),
      body: ListView.builder(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
        itemCount: _blockedUsers.isEmpty ? 2 : _blockedUsers.length + 1,
        itemBuilder: (context, index) {
          if (index == 0) {
            return _spaced(
              _lazyItem(index: 0, child: _buildHero()),
              bottom: 14,
            );
          }

          if (_blockedUsers.isEmpty) {
            return _lazyItem(index: 1, child: _buildEmptyState());
          }

          return _spaced(
            _lazyItem(
              index: index,
              child: _blockedUserTile(_blockedUsers[index - 1]),
            ),
            bottom: 10,
          );
        },
      ),
    );
  }

  // Adds consistent spacing around lazily built rows.
  Widget _spaced(Widget child, {required double bottom}) {
    return Padding(
      padding: EdgeInsets.only(bottom: bottom),
      child: child,
    );
  }

  // Gives blocked-user rows a soft animation as Flutter builds them.
  Widget _lazyItem({
    required int index,
    required Widget child,
  }) {
    return TweenAnimationBuilder<double>(
      key: ValueKey('blocked-$index-${_blockedUsers.length}'),
      tween: Tween(begin: 0, end: 1),
      duration: Duration(
        milliseconds: 260 + (index * 25).clamp(0, 180).toInt(),
      ),
      curve: Curves.easeOutCubic,
      builder: (context, value, _) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, 16 * (1 - value)),
            child: child,
          ),
        );
      },
      child: child,
    );
  }

  // Shows the page purpose and current blocked count.
  Widget _buildHero() {
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
            width: 50,
            height: 50,
            decoration: const BoxDecoration(
              color: Color(0xFFEAF3FF),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.person_off_outlined,
              color: Color(0xFF0052D4),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Manage Blocked Users',
                  style: GoogleFonts.inter(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textDark,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  _blockedUsers.isEmpty
                      ? 'No users are blocked right now.'
                      : '${_blockedUsers.length} user(s) hidden from your updates.',
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

  // Explains what blocking does when the list is empty.
  Widget _buildEmptyState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        children: [
          const Icon(
            Icons.verified_user_outlined,
            color: Color(0xFF0052D4),
            size: 34,
          ),
          const SizedBox(height: 12),
          Text(
            'Nothing to manage',
            style: GoogleFonts.inter(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: AppColors.textDark,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'When you block someone, their posts, replies, and alerts are hidden. You can unblock them from this page anytime.',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 12,
              color: AppColors.textMedium,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  // Builds each blocked-user row with an unblock action.
  Widget _blockedUserTile(Map<String, dynamic> user) {
    final name = (user['name'] ?? 'CityVoice user').toString();

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: const BoxDecoration(
              color: Color(0xFFEAF3FF),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                name.isNotEmpty ? name[0].toUpperCase() : '?',
                style: GoogleFonts.inter(
                  color: const Color(0xFF0052D4),
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: AppColors.textDark,
              ),
            ),
          ),
          TextButton(
            onPressed: () => _unblockUser(user),
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFF0052D4),
              padding: const EdgeInsets.symmetric(horizontal: 12),
            ),
            child: Text(
              'Unblock',
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }

}
