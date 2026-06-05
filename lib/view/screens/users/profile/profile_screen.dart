import 'package:firebase_auth/firebase_auth.dart';
import 'all_posts_screen.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../models/post_model.dart';
import '../voices/post_detail_screen.dart';
import 'settings_page.dart';
import 'widgets/edit_profile_sheet.dart';
import 'widgets/vision_card.dart';

class ProfileScreen extends StatefulWidget {
  final bool readOnly;

  const ProfileScreen({super.key, this.readOnly = false});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  int _selectedTab = 0;

  // ── Firebase ──────────────────────────────────────────────────────────
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final DatabaseReference _usersRef =
      FirebaseDatabase.instance.ref().child('users');
  final DatabaseReference _postsRef =
      FirebaseDatabase.instance.ref().child('posts');

  // ── User state ────────────────────────────────────────────────────────
  bool _isLoading = true;
  bool _isBlocked = false;
  bool _isClaimSubmitting = false;
  String _name = '';
  String _email = '';
  String _location = '';
  int _voicesCount = 0;
  int _supportedCount = 0;
  int _repliesCount = 0;
  int _reportedCount = 0;

  List<Map<String, dynamic>> _myPostsList = [];
  List<Map<String, dynamic>> _supportedPostsList = [];
  List<Map<String, dynamic>> _respondedPostsList = [];
  List<Map<String, dynamic>> _reportedPostsList = [];

  bool _isPrivateProfile = false;
  final TextEditingController _claimController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _tabController.addListener(() {
      if (mounted) setState(() => _selectedTab = _tabController.index);
    });
    _fetchUserData();
    _listenToMyPosts();
    _listenToSupportedPosts();
    _listenToRespondedPosts();
    _listenToReportedPosts();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _claimController.dispose();
    super.dispose();
  }

  // ── Live Data Listening ───────────────────────────────────────────────

  void _listenToMyPosts() {
    final user = _auth.currentUser;
    if (user == null) return;

    _postsRef.orderByChild('uid').equalTo(user.uid).onValue.listen((event) {
      if (event.snapshot.value != null) {
        final rawData = Map<String, dynamic>.from(event.snapshot.value as Map);
        final List<Map<String, dynamic>> loadedPosts = [];

        rawData.forEach((key, value) {
          final post = Map<String, dynamic>.from(value as Map);
          post['key'] = key;
          loadedPosts.add(post);
        });

        // Sort by timestamp newest first
        loadedPosts.sort((a, b) =>
            (b['timestamp'] ?? '').toString().compareTo((a['timestamp'] ?? '').toString()));

        if (mounted) {
          setState(() {
            _myPostsList = loadedPosts;
            _voicesCount = loadedPosts.length;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _myPostsList = [];
            _voicesCount = 0;
          });
        }
      }
    });
  }

  // ── Supported Posts ──────────────────────────────────────────────────

  void _listenToSupportedPosts() {
    final user = _auth.currentUser;
    if (user == null) return;

    // Query all posts where supportedBy contains the current user's uid
    _postsRef.orderByChild('supportedBy/${user.uid}').equalTo(true).onValue.listen((event) {
      if (event.snapshot.value != null) {
        final rawData = Map<String, dynamic>.from(event.snapshot.value as Map);
        final List<Map<String, dynamic>> loaded = [];
        rawData.forEach((key, value) {
          final post = Map<String, dynamic>.from(value as Map);
          post['key'] = key;
          loaded.add(post);
        });
        loaded.sort((a, b) =>
            (b['timestamp'] ?? '').toString().compareTo((a['timestamp'] ?? '').toString()));
        if (mounted) {
          setState(() {
            _supportedPostsList = loaded;
            _supportedCount = loaded.length;
          });
        }
      } else {
        if (mounted) setState(() { _supportedPostsList = []; _supportedCount = 0; });
      }
    });
  }

  // ── Responded Posts ──────────────────────────────────────────────────

  void _listenToRespondedPosts() {
    final user = _auth.currentUser;
    if (user == null) return;

    final repliesRef = FirebaseDatabase.instance.ref().child('replies');

    // Listen to the entire replies tree, find post keys where user replied
    repliesRef.onValue.listen((event) async {
      if (event.snapshot.value == null) {
        if (mounted) setState(() { _respondedPostsList = []; _repliesCount = 0; });
        return;
      }

      final allReplies = Map<String, dynamic>.from(event.snapshot.value as Map);
      final Set<String> repliedPostKeys = {};

      allReplies.forEach((postKey, repliesForPost) {
        if (repliesForPost is Map) {
          final repliesMap = Map<String, dynamic>.from(repliesForPost);
          repliesMap.forEach((replyKey, replyValue) {
            if (replyValue is Map) {
              final reply = Map<String, dynamic>.from(replyValue);
              if (reply['uid'] == user.uid) {
                repliedPostKeys.add(postKey);
              }
            }
          });
        }
      });

      if (repliedPostKeys.isEmpty) {
        if (mounted) setState(() { _respondedPostsList = []; _repliesCount = 0; });
        return;
      }

      // Fetch each post
      final List<Map<String, dynamic>> loaded = [];
      for (final postKey in repliedPostKeys) {
        try {
          final snap = await _postsRef.child(postKey).get();
          if (snap.exists && snap.value != null) {
            final post = Map<String, dynamic>.from(snap.value as Map);
            post['key'] = postKey;
            loaded.add(post);
          }
        } catch (_) {}
      }

      loaded.sort((a, b) =>
          (b['timestamp'] ?? '').toString().compareTo((a['timestamp'] ?? '').toString()));

      if (mounted) {
        setState(() {
          _respondedPostsList = loaded;
          _repliesCount = loaded.length;
        });
      }
    });
  }

  void _listenToReportedPosts() {
    final user = _auth.currentUser;
    if (user == null) return;

    FirebaseDatabase.instance
        .ref('userReports')
        .child(user.uid)
        .onValue
        .listen((event) async {
      if (event.snapshot.value == null) {
        final loaded = await _loadReportsFromPosts(user.uid);
        if (mounted) {
          setState(() {
            _reportedPostsList = loaded;
            _reportedCount = loaded.length;
          });
        }
        return;
      }

      final rawData = Map<String, dynamic>.from(event.snapshot.value as Map);
      final List<Map<String, dynamic>> loaded = [];

      for (final entry in rawData.entries) {
        final postKey = entry.key;
        if (entry.value is! Map) continue;

        final report = Map<String, dynamic>.from(entry.value as Map);
        Map<String, dynamic> post = {};

        try {
          final postSnap = await _postsRef.child(postKey).get();
          if (postSnap.exists && postSnap.value is Map) {
            post = Map<String, dynamic>.from(postSnap.value as Map);
          }
        } catch (_) {}

        post['key'] = postKey;
        post['myReport'] = report;
        post['description'] = post['description'] ?? report['postDescription'] ?? '';
        post['name'] = post['name'] ?? report['postOwnerName'] ?? 'User';
        post['uid'] = post['uid'] ?? report['postOwnerUid'] ?? '';
        post['location'] = post['location'] ?? report['postLocation'] ?? '';
        post['image_url'] = post['image_url'] ?? report['postImageUrl'] ?? '';
        loaded.add(post);
      }

      if (loaded.isEmpty) {
        loaded.addAll(await _loadReportsFromPosts(user.uid));
      }

      loaded.sort((a, b) {
        final aReport = a['myReport'] is Map
            ? Map<String, dynamic>.from(a['myReport'] as Map)
            : <String, dynamic>{};
        final bReport = b['myReport'] is Map
            ? Map<String, dynamic>.from(b['myReport'] as Map)
            : <String, dynamic>{};
        return (bReport['timestamp'] ?? '')
            .toString()
            .compareTo((aReport['timestamp'] ?? '').toString());
      });

      if (mounted) {
        setState(() {
          _reportedPostsList = loaded;
          _reportedCount = loaded.length;
        });
      }
    });
  }

  Future<List<Map<String, dynamic>>> _loadReportsFromPosts(String uid) async {
    final List<Map<String, dynamic>> loaded = [];
    final postsSnap = await _postsRef.get();

    if (postsSnap.exists && postsSnap.value is Map) {
      final postsRaw = Map<String, dynamic>.from(postsSnap.value as Map);
      postsRaw.forEach((key, value) {
        if (value is! Map) return;
        final post = Map<String, dynamic>.from(value);
        final reports = post['reports'] is Map
            ? Map<String, dynamic>.from(post['reports'] as Map)
            : <String, dynamic>{};
        final userReport = reports[uid];
        if (userReport is Map) {
          post['key'] = key;
          post['myReport'] = Map<String, dynamic>.from(userReport);
          loaded.add(post);
        }
      });
    }

    return loaded;
  }

  Future<void> _togglePrivateProfile(bool value) async {
    if (_isBlocked) {
      _showSnack('Your account is blocked. You can only view posts.');
      return;
    }

    try {
      final user = _auth.currentUser;
      if (user == null) return;

      await _usersRef.child(user.uid).update({
        'isPrivateProfile': value,
      });

      setState(() {
        _isPrivateProfile = value;
      });
    } catch (e) {
      debugPrint('Error updating private profile: $e');
    }
  }

  Future<void> _fetchUserData() async {
    
    try {
      final user = _auth.currentUser;
      if (user == null) return;

      final snapshot = await _usersRef.child(user.uid).get();
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
          _isPrivateProfile =
              (data['isPrivateProfile'] ?? false) == true;
          _isBlocked = widget.readOnly ||
              data['isBlocked'] == true ||
              data['blocked'] == true;
        });
      } else {
        setState(() {
          _email = user.email ?? '';
          _name = user.displayName ?? 'User';
          _isBlocked = widget.readOnly;
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
  }

  // ── Build Utility ─────────────────────────────────────────────────────

  String _getTimeAgo(String timestamp) {
    try {
      final dt = DateTime.parse(timestamp);
      final diff = DateTime.now().difference(dt);
      if (diff.inDays > 0) return '${diff.inDays}d ago';
      if (diff.inHours > 0) return '${diff.inHours}h ago';
      if (diff.inMinutes > 0) return '${diff.inMinutes}m ago';
      return 'Just now';
    } catch (_) {
      return '';
    }
  }

  void _showEditProfileSheet() {
    if (_isBlocked) {
      _showSnack('Your account is blocked. You can only view posts.');
      return;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => EditProfileSheet(
        currentName: _name,
        currentEmail: _email,
        currentLocation: _location,
        onProfileUpdated: (name, email, location) {
          setState(() {
            _name = name;
            _email = email;
            _location = location;
          });
        },
      ),
    );
  }

  Future<void> _submitBlockClaim() async {
    final message = _claimController.text.trim();
    final user = _auth.currentUser;

    if (user == null) return;
    if (message.isEmpty) {
      _showSnack('Please write your claim message.');
      return;
    }

    setState(() => _isClaimSubmitting = true);

    try {
      await FirebaseDatabase.instance.ref('blockClaims').child(user.uid).push().set({
        'uid': user.uid,
        'name': _name,
        'email': _email,
        'message': message,
        'status': 'pending',
        'timestamp': DateTime.now().toIso8601String(),
      });

      _claimController.clear();
      _showSnack('Your claim has been submitted to admin.');
    } catch (e) {
      _showSnack('Failed to submit claim: $e');
    } finally {
      if (mounted) setState(() => _isClaimSubmitting = false);
    }
  }

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
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
      body: NestedScrollView(
        headerSliverBuilder: (context, _) => [
          SliverToBoxAdapter(child: _buildHeaderAndProfileCard()),
          SliverToBoxAdapter(child: _buildStatsCard()),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
              child: _buildTabBar(),
            ),
          ),
        ],
        body: TabBarView(
          controller: _tabController,
          children: [
            _buildPostList(_myPostsList, "You haven't raised any voices yet.", "My Posts"),
            _buildPostList(_supportedPostsList, "You haven't supported any posts yet.", "Supported"),
            _buildPostList(_respondedPostsList, "You haven't responded to any posts yet.", "Responses"),
            _buildReportedPostList(),
          ],
        ),
      ),
    );
  }

  // ── Header & Profile Card ────────────────────────────────────────────

  Widget _buildHeaderAndProfileCard() {
    final double statusBarHeight = MediaQuery.of(context).padding.top;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        // Blue Gradient + Skyline Background
        Container(
          height: 180 + statusBarHeight,
          width: double.infinity,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF0052D4), Color(0xFF4364F7)],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
            image: DecorationImage(
              image: const NetworkImage('https://images.unsplash.com/photo-1519501025264-65ba15a82390?q=80&w=1000&auto=format&fit=crop'),
              fit: BoxFit.cover,
              colorFilter: ColorFilter.mode(
                const Color(0xFF0052D4).withOpacity(0.85),
                BlendMode.srcOver,
              ),
            ),
          ),
          padding: EdgeInsets.fromLTRB(20, statusBarHeight + 16, 20, 0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Logo & App Name
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
                      color: Colors.white,
                      letterSpacing: -0.5,
                    ),
                  ),
                ],
              ),
              // Header Controls (Bell and Gear)
              Row(
                children: [
                  GestureDetector(
                    onTap: _openSettingsPage,
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.95),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.settings_outlined,
                        color: Color(0xFF555555),
                        size: 20,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  GestureDetector(
                    onTap: _logout,
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.logout,
                        color: Color(0xFF555555),
                        size: 20,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        // White Card Content overlaying
        Padding(
          padding: EdgeInsets.only(top: statusBarHeight + 110),
          child: Container(
            width: double.infinity,
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(36)),
            ),
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
            child: Column(
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Avatar
                    Stack(
                      children: [
                        Container(
                          width: 90,
                          height: 90,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 3),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.08),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                            gradient: const LinearGradient(
                              colors: [Color(0xFF0052D4), Color(0xFF4364F7)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                          ),
                          child: Center(
                            child: Text(
                              _name.isNotEmpty ? _name[0].toUpperCase() : '?',
                              style: GoogleFonts.inter(
                                  fontSize: 36,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white),
                            ),
                          ),
                        ),
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: Container(
                            width: 28,
                            height: 28,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.black.withOpacity(0.1)),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.05),
                                  blurRadius: 4,
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.camera_alt_outlined,
                              size: 14,
                              color: Colors.grey,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(width: 20),
                    // Name, email, location & Edit Profile
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                _name,
                                style: GoogleFonts.inter(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w800,
                                  color: const Color(0xFF1A1A1A),
                                ),
                              ),
                              const SizedBox(width: 6),
                              const Icon(
                                Icons.verified,
                                color: Color(0xFF0D6EFD),
                                size: 18,
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _email,
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              color: const Color(0xFF757575),
                            ),
                          ),
                          const SizedBox(height: 6),
                          if (_location.isNotEmpty)
                            Row(
                              children: [
                                const Icon(
                                  Icons.location_on_outlined,
                                  size: 14,
                                  color: Color(0xFF0D6EFD),
                                ),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    _location,
                                    style: GoogleFonts.inter(
                                      fontSize: 13,
                                      color: const Color(0xFF757575),
                                      fontWeight: FontWeight.w500,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          const SizedBox(height: 12),
                          GestureDetector(
                            onTap: _showEditProfileSheet,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(100),
                                border: Border.all(color: const Color(0xFF0D6EFD).withOpacity(0.5)),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.edit_outlined,
                                      size: 14, color: Color(0xFF0D6EFD)),
                                  const SizedBox(width: 6),
                                  Text(
                                    'Edit Profile',
                                    style: GoogleFonts.inter(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: const Color(0xFF0D6EFD),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                _buildPrivateProfileCard(),
                if (_isBlocked) ...[
                  const SizedBox(height: 14),
                  _buildBlockedClaimCard(),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPrivateProfileCard() {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 12,
        vertical: 10,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFFF2F6FC),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFFE0EAFC),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: const BoxDecoration(
              color: Color(0xFFE3EDFA),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.verified_user_outlined,
              color: Color(0xFF0D6EFD),
              size: 18,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Private Profile',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF0D6EFD),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _isPrivateProfile
                      ? 'Your posts appear anonymously.'
                      : 'Your name is visible on posts.',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    color: const Color(0xFF555555),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          Switch(
            value: _isPrivateProfile,
            activeColor: Colors.white,
            activeTrackColor: const Color(0xFF0D6EFD),
            inactiveThumbColor: Colors.white,
            inactiveTrackColor: Colors.black26,
            onChanged: _isBlocked ? null : _togglePrivateProfile,
          ),
        ],
      ),
    );
  }

  Widget _buildBlockedClaimCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFEAF3FF),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF1A73E8).withOpacity(0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.block_rounded, color: Color(0xFF0052D4)),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Your account is blocked',
                  style: GoogleFonts.inter(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textDark,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'You can still view posts. If you think this is a mistake, submit a claim for admin review.',
            style: GoogleFonts.inter(
              fontSize: 12,
              color: AppColors.textMedium,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.black.withOpacity(0.06)),
            ),
            child: TextField(
              controller: _claimController,
              minLines: 2,
              maxLines: 4,
              decoration: InputDecoration(
                hintText: 'Write your claim...',
                hintStyle: GoogleFonts.inter(
                  fontSize: 13,
                  color: AppColors.textLight,
                ),
                border: InputBorder.none,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: ElevatedButton.icon(
              onPressed: _isClaimSubmitting ? null : _submitBlockClaim,
              icon: _isClaimSubmitting
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.gavel_outlined, size: 16),
              label: Text(
                _isClaimSubmitting ? 'Submitting...' : 'Submit Claim',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0D6EFD),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(100),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Opens the Settings hub for safety controls and app information.
  void _openSettingsPage() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const SettingsPage(),
      ),
    );
  }

  // ── Stats ─────────────────────────────────────────────────────────────

  Widget _buildStatsCard() {
    return Container(
      margin: const EdgeInsets.fromLTRB(24, 8, 24, 0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(vertical: 18),
      child: Row(
        children: [
          _buildStatItem(
            icon: Icons.campaign_outlined,
            iconColor: const Color(0xFF0052D4),
            iconBg: const Color(0xFFEAF3FF),
            count: _voicesCount,
            label: 'VOICES',
          ),
          _buildStatDivider(),
          _buildStatItem(
            icon: Icons.favorite_border_rounded,
            iconColor: const Color(0xFF0D6EFD),
            iconBg: const Color(0xFFD7E9FF),
            count: _supportedCount,
            label: 'SUPPORTED',
          ),
          _buildStatDivider(),
          _buildStatItem(
            icon: Icons.chat_bubble_outline_rounded,
            iconColor: const Color(0xFF3F8CFF),
            iconBg: const Color(0xFFEAF3FF),
            count: _repliesCount,
            label: 'RESPONSES',
          ),
          _buildStatDivider(),
          _buildStatItem(
            icon: Icons.flag_outlined,
            iconColor: const Color(0xFF0052D4),
            iconBg: const Color(0xFFD7E9FF),
            count: _reportedCount,
            label: 'REPORTED',
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
            width: 38,
            height: 38,
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
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: const Color(0xFF1A1A1A),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF757575),
              letterSpacing: 0.8,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatDivider() {
    return Container(
      width: 1,
      height: 42,
      color: const Color(0xFFE2E8F0),
    );
  }

  // ── Tab Bar ───────────────────────────────────────────────────────────

  Widget _buildTabBar() {
    final tabs = [
      {'label': 'My Posts', 'icon': Icons.campaign_outlined},
      {'label': 'Supported', 'icon': Icons.favorite_border_rounded},
      {'label': 'Responses', 'icon': Icons.chat_bubble_outline_rounded},
      {'label': 'Reported', 'icon': Icons.flag_outlined},
    ];
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(5),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: List.generate(tabs.length, (i) {
          final isActive = _selectedTab == i;
          final tab = tabs[i];
          return Padding(
            padding: EdgeInsets.only(right: i == tabs.length - 1 ? 0 : 6),
            child: GestureDetector(
              onTap: () {
                _tabController.animateTo(i);
                if (mounted) setState(() => _selectedTab = i);
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 132,
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: isActive ? const Color(0xFF0D6EFD) : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      tab['icon'] as IconData,
                      size: 16,
                      color: isActive ? Colors.white : const Color(0xFF757575),
                    ),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        tab['label'] as String,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: isActive ? Colors.white : const Color(0xFF757575),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }),
        ),
      ),
    );
  }

  // ── Post Lists ────────────────────────────────────────────────────────

  Widget _buildEmptyState(String message) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
      children: [
        SizedBox(
          height: 150,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.hourglass_empty_rounded,
                  size: 40, color: AppColors.textLight.withOpacity(0.5)),
              const SizedBox(height: 12),
              Text(
                message,
                style: GoogleFonts.inter(color: AppColors.textLight, fontSize: 13),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        const VisionCard(),
      ],
    );
  }

  Widget _buildPostList(List<Map<String, dynamic>> posts, String emptyMessage, String tabLabel) {
    if (posts.isEmpty) return _buildEmptyState(emptyMessage);

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 6, 20, 16),
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              tabLabel,
              style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: const Color(0xFF1A1A1A),
              ),
            ),
            GestureDetector(
              onTap: () {
                // Navigate to a screen showing all posts for this tab
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (c) => AllPostsScreen(
                      posts: posts,
                      title: tabLabel,
                      readOnly: _isBlocked,
                    ),
                  ),
                );
              },
              child: Text(
                'View All',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF0D6EFD),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        ...posts.take(5).map((p) => _buildPostItem(p)),
        const SizedBox(height: 16),
        const VisionCard(),
      ],
    );
  }

  Widget _buildReportedPostList() {
    if (_reportedPostsList.isEmpty) {
      return _buildEmptyState("You haven't reported any posts yet.");
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 6, 20, 16),
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Reported',
              style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: const Color(0xFF1A1A1A),
              ),
            ),
            Text(
              '$_reportedCount posts',
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppColors.primary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        ..._reportedPostsList.take(10).map((p) => _buildReportedPostItem(p)),
        const SizedBox(height: 16),
        const VisionCard(),
      ],
    );
  }

  Widget _buildReportedPostItem(Map<String, dynamic> post) {
    final report = post['myReport'] is Map
        ? Map<String, dynamic>.from(post['myReport'] as Map)
        : <String, dynamic>{};
    final String text = post['description'] ?? '';
    final String imageUrl = post['image_url'] ?? '';
    final String locationStr = post['location'] ?? 'Unknown Location';
    final String posterName = post['name'] ?? 'User';
    final String reason = report['reason'] ?? 'Reported';
    final String reportedAt = _getTimeAgo(report['timestamp'] ?? '');

    return GestureDetector(
      onTap: () {
        final voicePost = VoicePost.fromMap(post['key'] ?? '', post);
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (c) => PostDetailScreen(
              post: voicePost,
              readOnly: _isBlocked,
            ),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFF1A73E8).withOpacity(0.12)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.02),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: Container(
                width: 80,
                height: 80,
                color: const Color(0xFFEAF3FF),
                child: imageUrl.isNotEmpty
                    ? Image.network(
                        imageUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) =>
                            const Icon(Icons.flag_outlined, color: Color(0xFF0052D4), size: 24),
                      )
                    : const Icon(Icons.flag_outlined,
                        color: Color(0xFF0052D4), size: 24),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Reported $posterName',
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: const Color(0xFF1A1A1A),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEAF3FF),
                          borderRadius: BorderRadius.circular(100),
                        ),
                        child: Text(
                          'Reported',
                          style: GoogleFonts.inter(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: const Color(0xFF0052D4),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    text,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: AppColors.textMedium,
                      height: 1.4,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Reason: $reason',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF0052D4),
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Icon(Icons.location_on_outlined,
                          size: 12, color: Colors.grey),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          locationStr,
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            color: const Color(0xFF757575),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (reportedAt.isNotEmpty) ...[
                        const SizedBox(width: 8),
                        Text(
                          reportedAt,
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.chevron_right, color: Colors.black26),
          ],
        ),
      ),
    );
  }

  Widget _buildPostItem(Map<String, dynamic> post) {
    final String text = post['description'] ?? '';
    final String timestamp = post['timestamp'] ?? '';
    final String imageUrl = post['image_url'] ?? '';
    final String locationStr = post['location'] ?? 'Unknown Location';
    final String status = post['status'] ?? 'In Progress';

    // Status styling
    Color statusColor;
    Color statusBgColor;
    if (status.toLowerCase() == 'resolved') {
      statusColor = const Color(0xFF2ECC71);
      statusBgColor = const Color(0xFFEBF7EE);
    } else if (status.toLowerCase() == 'in progress') {
      statusColor = const Color(0xFF0D6EFD);
      statusBgColor = const Color(0xFFEFF4FC);
    } else {
      statusColor = const Color(0xFFF39C12);
      statusBgColor = const Color(0xFFFFFAEE);
    }

    return GestureDetector(
      onTap: () {
        final voicePost = VoicePost.fromMap(post['key'] ?? '', post);
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (c) => PostDetailScreen(
              post: voicePost,
              readOnly: _isBlocked,
            ),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.02),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            // Left: Post Image
            ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: Container(
                width: 80,
                height: 80,
                color: const Color(0xFFF5F0ED),
                child: imageUrl.isNotEmpty
                    ? Image.network(imageUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) =>
                            const Icon(Icons.image_outlined, color: Colors.grey, size: 24))
                    : const Icon(Icons.chat_bubble_outline_rounded,
                        color: Colors.grey, size: 24),
              ),
            ),
            const SizedBox(width: 14),
            // Middle: Details
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          text,
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF1A1A1A),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Status Badge
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: statusBgColor,
                          borderRadius: BorderRadius.circular(100),
                        ),
                        child: Text(
                          status,
                          style: GoogleFonts.inter(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: statusColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.location_on_outlined, size: 13, color: Colors.grey),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          locationStr,
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: const Color(0xFF757575),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.calendar_today_outlined, size: 11, color: Colors.grey),
                      const SizedBox(width: 4),
                      Text(
                        _getTimeAgo(timestamp),
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            // Right: Chevron arrow icon
            const Icon(
              Icons.chevron_right,
              color: Colors.black26,
            ),
          ],
        ),
      ),
    );
  }
}
