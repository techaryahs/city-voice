import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../models/post_model.dart';
import 'post_detail_screen.dart';
import 'package:share_plus/share_plus.dart';
import 'package:readmore/readmore.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';

// ── Category colour helper ────────────────────────────────────────────────────

Color _catColor(String cat) {
  switch (cat.toLowerCase()) {
    case 'roads':
      return AppColors.primary;

    case 'footpath':
      return const Color(0xFF8E44AD);

    case 'public toilets':
      return const Color(0xFF16A085);

    case 'garbage':
      return const Color(0xFF2ECC71);

    case 'garden & trees':
      return const Color(0xFF27AE60);

    case 'water':
      return const Color(0xFF4A7BE8);

    case 'street lights':
      return const Color(0xFFF39C12);

    case 'other':
      return const Color(0xFF7F8C8D);

    default:
      return const Color(0xFF1ABCCD);
  }
}

Color _catBg(String cat) {
  switch (cat.toLowerCase()) {
    case 'roads':
      return const Color(0xFFFFF0EE);

    case 'footpath':
      return const Color(0xFFF5EEFF);

    case 'public toilets':
      return const Color(0xFFEEFFFB);

    case 'garbage':
      return const Color(0xFFEEFBF4);

    case 'garden & trees':
      return const Color(0xFFEFFAF1);

    case 'water':
      return const Color(0xFFEEF4FF);

    case 'street lights':
      return const Color(0xFFFFFAEE);

    case 'other':
      return const Color(0xFFF4F4F4);

    default:
      return const Color(0xFFEDF8FB);
  }
}

// ── Screen ────────────────────────────────────────────────────────────────────

class VoicesScreen extends StatefulWidget {
  final bool readOnly;

  const VoicesScreen({super.key, this.readOnly = false});

  @override
  State<VoicesScreen> createState() => _VoicesScreenState();
}

class _VoicesScreenState extends State<VoicesScreen> {
  final _postsRef  = FirebaseDatabase.instance.ref('posts');
  final _currentUid = FirebaseAuth.instance.currentUser?.uid ?? '';
  String _userLocation = 'Fetching location...';

  final TextEditingController _searchController =
  TextEditingController();

  String _searchQuery = '';

  String _selectedCategory = 'All';

  final List<String> _categories = [
    'All',
    'Roads',
    'Footpath',
    'Public Toilets',
    'Garbage',
    'Garden & Trees',
    'Water',
    'Street Lights',
    'Other',
  ];

  @override
  void initState() {
    super.initState();
    _getUserLocation();
  }

  // ── Support toggle ──────────────────────────────────────────────────────────

  Future<void> _toggleSupport(VoicePost post) async {
    if (widget.readOnly) {
      _showBlockedNotice();
      return;
    }

    if (_currentUid.isEmpty) return;

    final ref = _postsRef.child(post.key);

    await ref.runTransaction((object) {
      if (object == null) return Transaction.abort();

      final data = Map<String, dynamic>.from(object as Map);

      final supportedBy = data['supportedBy'] != null
          ? Map<String, dynamic>.from(data['supportedBy'])
          : {};

      if (supportedBy[_currentUid] == true) {
        // ❌ REMOVE SUPPORT → decrease
        supportedBy.remove(_currentUid);
        data['supports'] = ((data['supports'] ?? 0) - 1).clamp(0, 1000000);
      } else {
        // ✅ ADD SUPPORT → increase
        supportedBy[_currentUid] = true;
        data['supports'] = ((data['supports'] ?? 0) + 1).clamp(0, 1000000);
      }

      data['supportedBy'] = supportedBy;

      return Transaction.success(data);
    });
  }

  void _sharePost(VoicePost post) {
    if (widget.readOnly) {
      _showBlockedNotice();
      return;
    }

    Share.share(
      """
🚨 CityVoice Issue

${post.description}

Support this voice on CityVoice app.
""",
    );
  }

  Future<void> _reportPost(VoicePost post) async {
    if (widget.readOnly) {
      _showBlockedNotice();
      return;
    }

    if (_currentUid.isEmpty) return;

    final reason = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Report post',
          style: GoogleFonts.inter(fontWeight: FontWeight.w800),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _reportReasonTile('Fake or misleading'),
            _reportReasonTile('Spam'),
            _reportReasonTile('Offensive content'),
            _reportReasonTile('Not a civic issue'),
            _reportReasonTile('Other'),
          ],
        ),
      ),
    );

    if (reason == null) return;

    final reportReason =
        reason == 'Other' ? await _showOtherReportDialog() : reason;

    if (reportReason == null || reportReason.trim().isEmpty) return;

    try {
      final postRef = _postsRef.child(post.key);
      final reportRef = postRef.child('reports').child(_currentUid);
      final existing = await reportRef.get();

      if (existing.exists) {
        _showSnack('You already reported this post.');
        return;
      }

      final userSnap =
          await FirebaseDatabase.instance.ref('users').child(_currentUid).get();
      final userData = userSnap.value is Map
          ? Map<String, dynamic>.from(userSnap.value as Map)
          : <String, dynamic>{};

      final timestamp = DateTime.now().toIso8601String();
      final reportData = {
        'uid': _currentUid,
        'reporterName': userData['name'] ?? 'User',
        'reporterEmail': userData['email'] ?? '',
        'reason': reportReason,
        'timestamp': timestamp,
        'postId': post.key,
        'postOwnerUid': post.uid,
        'postOwnerName': post.name,
        'postDescription': post.description,
        'postLocation': post.location,
        'postImageUrl': post.imageUrl,
      };

      await reportRef.set(reportData);
      await FirebaseDatabase.instance
          .ref('userReports')
          .child(_currentUid)
          .child(post.key)
          .set(reportData);

      await postRef.runTransaction((object) {
        if (object == null) return Transaction.abort();
        final data = Map<String, dynamic>.from(object as Map);
        data['reportCount'] = ((data['reportCount'] as num?)?.toInt() ?? 0) + 1;
        return Transaction.success(data);
      });

      _showSnack('Post reported. Thank you for helping keep CityVoice safe.');
    } catch (e) {
      _showSnack('Failed to report post: $e');
    }
  }

  Widget _reportReasonTile(String reason) {
    return ListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      leading: const Icon(Icons.flag_outlined, color: AppColors.primary),
      title: Text(reason, style: GoogleFonts.inter(fontSize: 14)),
      onTap: () => Navigator.pop(context, reason),
    );
  }

  Future<String?> _showOtherReportDialog() async {
    final controller = TextEditingController();

    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Other reason',
          style: GoogleFonts.inter(fontWeight: FontWeight.w800),
        ),
        content: TextField(
          controller: controller,
          minLines: 3,
          maxLines: 5,
          decoration: InputDecoration(
            hintText: 'Write why you are reporting this post...',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Submit'),
          ),
        ],
      ),
    );

    return result;
  }

  void _showBlockedNotice() {
    _showSnack('Your account is blocked. You can only view posts.');
  }

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<void> _getUserLocation() async {
    try {
      bool serviceEnabled =
      await Geolocator.isLocationServiceEnabled();

      if (!serviceEnabled) return;

      LocationPermission permission =
      await Geolocator.checkPermission();

      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.deniedForever) {
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      final placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );

      if (placemarks.isNotEmpty) {
        final place = placemarks.first;

        setState(() {
          _userLocation =
          '${place.locality}, ${place.administrativeArea}';
        });
      }
    } catch (e) {
      debugPrint('Location Error: $e');
    }
  }

  // ── Build ───────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            _buildSearchAndFilters(),
            Expanded(
              child: StreamBuilder<DatabaseEvent>(
                stream: _postsRef.orderByChild('timestamp').onValue,
                builder: (context, snapshot) {
                  // ── Loading ──────────────────────────────────────────────
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(
                      child: CircularProgressIndicator(color: AppColors.primary),
                    );
                  }

                  // ── Error ────────────────────────────────────────────────
                  if (snapshot.hasError) {
                    return _buildEmptyState(
                      icon: Icons.wifi_off_rounded,
                      title: 'Connection error',
                      subtitle: 'Check internet and try again.',
                    );
                  }

                  // ── No data ──────────────────────────────────────────────
                  final event = snapshot.data;
                  if (event == null || event.snapshot.value == null) {
                    return _buildEmptyState(
                      icon: Icons.campaign_outlined,
                      title: 'No voices yet',
                      subtitle: 'Be the first to raise a voice\nin your community!',
                    );
                  }

                  // ── Parse posts (newest first) ───────────────────────────
                  final raw    = Map<String, dynamic>.from(event.snapshot.value as Map);
                  final posts = raw.entries
                      .map((e) => VoicePost.fromSnapshot(
                    event.snapshot.child(e.key),
                  ))
                      .where((post) {

                    // ── SEARCH FILTER ───────────────────

                    final matchesSearch =

                        post.description
                            .toLowerCase()
                            .contains(_searchQuery)

                            ||

                            post.category
                                .toLowerCase()
                                .contains(_searchQuery)

                            ||

                            post.location
                                .toLowerCase()
                                .contains(_searchQuery);

                    // ── CATEGORY FILTER ─────────────────

                    final matchesCategory =

                        _selectedCategory == 'All'

                            ||

                            post.category.toLowerCase() ==
                                _selectedCategory.toLowerCase();

                    return matchesSearch &&
                        matchesCategory;
                  })
                      .toList()

                    ..sort((a, b) =>
                        b.timestamp.compareTo(a.timestamp));

                  return ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                    itemCount: posts.length,
                    itemBuilder: (_, i) => _buildPostCard(posts[i]),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Header ──────────────────────────────────────────────────────────────────

  Widget _buildHeader() {
    return Container(
      color: AppColors.white,
      padding: const EdgeInsets.fromLTRB(20, 16, 16, 14),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Voices',
                style: GoogleFonts.inter(
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textDark,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 2),
              Row(
                children: [
                  Icon(Icons.location_on_rounded, size: 13, color: AppColors.primary),
                  const SizedBox(width: 3),
                  Text(
                    _userLocation,
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: AppColors.primary,
                    ),
                  ),
                ],
              ),
            ],
          ),
          // _buildNotificationBell(),
        ],
      ),
    );
  }

  Widget _buildSearchAndFilters() {

    return Container(
      color: AppColors.white,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),

      child: Column(
        children: [

          // ── SEARCH BAR ───────────────────────────

          TextField(
            controller: _searchController,

            onChanged: (value) {
              setState(() {
                _searchQuery = value.toLowerCase();
              });
            },

            decoration: InputDecoration(

              hintText: 'Search voices...',

              hintStyle: GoogleFonts.inter(
                fontSize: 13,
                color: AppColors.textLight,
              ),

              prefixIcon: const Icon(
                Icons.search_rounded,
                color: AppColors.textMedium,
              ),

              filled: true,
              fillColor: AppColors.background,

              contentPadding: const EdgeInsets.symmetric(
                vertical: 0,
                horizontal: 14,
              ),

              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
            ),
          ),

          const SizedBox(height: 14),

          // ── CATEGORY FILTERS ─────────────────────

          SizedBox(
            height: 38,

            child: ListView.separated(
              scrollDirection: Axis.horizontal,

              itemCount: _categories.length,

              separatorBuilder: (_, __) =>
              const SizedBox(width: 10),

              itemBuilder: (_, index) {

                final category = _categories[index];

                final isSelected =
                    _selectedCategory == category;

                return GestureDetector(

                  onTap: () {

                    setState(() {
                      _selectedCategory = category;
                    });
                  },

                  child: AnimatedContainer(

                    duration:
                    const Duration(milliseconds: 200),

                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),

                    decoration: BoxDecoration(

                      color: isSelected
                          ? AppColors.primary
                          : AppColors.background,

                      borderRadius:
                      BorderRadius.circular(100),

                      border: Border.all(
                        color: isSelected
                            ? AppColors.primary
                            : Colors.black.withOpacity(0.06),
                      ),
                    ),

                    child: Center(
                      child: Text(

                        category,

                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,

                          color: isSelected
                              ? Colors.white
                              : AppColors.textMedium,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationBell() {
    return Stack(
      children: [
        Container(
          width: 44, height: 44,
          decoration: BoxDecoration(
            color: AppColors.background,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.black.withOpacity(0.07)),
          ),
          child: const Icon(Icons.notifications_outlined,
              color: AppColors.textDark, size: 22),
        ),
        Positioned(
          right: 8, top: 8,
          child: Container(
            width: 8, height: 8,
            decoration: const BoxDecoration(
              color: AppColors.primary,
              shape: BoxShape.circle,
            ),
          ),
        ),
      ],
    );
  }

  // ── Post card ────────────────────────────────────────────────────────────────

  Widget _buildPostCard(VoicePost post) {
    final catColor = _catColor(post.category);
    final catBg = _catBg(post.category);

    // ✅ IMPORTANT: check if current user supported
    final hasSupported = post.supportedBy.containsKey(_currentUid);

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (c) => PostDetailScreen(
            post: post,
            readOnly: widget.readOnly,
          ),
        ),
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 12,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Author row ─────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
              child: Row(
                children: [
                  _buildAvatar(post.name),
                  const SizedBox(width: 12),

                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          post.name,
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textDark,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Row(
                          children: [
                            Icon(Icons.location_on_outlined,
                                size: 11, color: AppColors.textLight),
                            const SizedBox(width: 2),
                            Expanded(
                              child: Text(
                                '${post.location} • ${_getTimeAgo(post.timestamp)}',
                                style: GoogleFonts.inter(
                                  fontSize: 11,
                                  color: AppColors.textLight,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  // ── Category badge ─────────────────────────────
                  Container(
                    padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: catBg,
                      borderRadius: BorderRadius.circular(100),
                    ),
                    child: Text(
                      post.category,
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: catColor,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // ── STATUS BADGE ─────────────────────────────
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: post.status.toLowerCase() == 'resolved'
                          ? const Color(0xFFE9F9EE)
                          : const Color(0xFFFFF4E5),
                      borderRadius: BorderRadius.circular(100),
                    ),
                    child: Text(
                      post.status.toLowerCase() == 'resolved'
                          ? 'Resolved'
                          : 'Pending',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: post.status.toLowerCase() == 'resolved'
                            ? const Color(0xFF1E9E57)
                            : const Color(0xFFE69500),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // ── Image ─────────────────────────────────────────────
            if (post.imageUrl.isNotEmpty)
              Image.network(
                post.imageUrl,
                height: 190,
                width: double.infinity,
                fit: BoxFit.cover,
                loadingBuilder: (_, child, progress) =>
                progress == null
                    ? child
                    : Container(
                  height: 190,
                  color: AppColors.background,
                  child: const Center(
                    child: CircularProgressIndicator(
                      color: AppColors.primary,
                      strokeWidth: 2,
                    ),
                  ),
                ),
                errorBuilder: (_, __, ___) => Container(
                  height: 100,
                  color: AppColors.background,
                  child: const Center(
                    child: Icon(Icons.broken_image_outlined,
                        color: AppColors.textLight, size: 32),
                  ),
                ),
              ),

            // ── Description ───────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: ReadMoreText(
                post.description,
                trimLines: 2,
                trimMode: TrimMode.Line,
                trimCollapsedText: ' See more',
                trimExpandedText: ' Show less',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color: AppColors.textMedium,
                  height: 1.55,
                ),
                moreStyle: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primary,
                ),
                lessStyle: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primary,
                ),
              ),
            ),

            // ── Actions ───────────────────────────────────────────
            // ── Actions ───────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
              child: Row(
                children: [

                  // ❤️ SUPPORT
                  GestureDetector(
                    onTap: widget.readOnly ? null : () => _toggleSupport(post),
                    child: Row(
                      children: [
                        Icon(
                          hasSupported
                              ? Icons.favorite_rounded
                              : Icons.favorite_border_rounded,
                          color: hasSupported ? Colors.red : AppColors.textDark,
                          size: 24,
                        ),
                        const SizedBox(width: 5),
                        Text(
                          '${post.supports}',
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textDark,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(width: 22),

                  // 💬 RESPONSES
                  GestureDetector(
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (c) => PostDetailScreen(
                          post: post,
                          readOnly: widget.readOnly,
                        ),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.chat_bubble_outline_rounded,
                          color: AppColors.textDark,
                          size: 22,
                        ),
                        const SizedBox(width: 5),
                        Text(
                          '${post.replies}',
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textDark,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(width: 22),

                  // 📤 SHARE
                  if (!widget.readOnly)
                    GestureDetector(
                      onTap: () => _sharePost(post),
                      child: Icon(
                        Icons.send_rounded,
                        color: AppColors.textDark,
                        size: 22,
                      ),
                    ),

                  const Spacer(),

                  if (!widget.readOnly)
                    GestureDetector(
                      onTap: () => _reportPost(post),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 7,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFF0EE),
                          borderRadius: BorderRadius.circular(100),
                          border: Border.all(
                            color: AppColors.primary.withOpacity(0.18),
                          ),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.flag_outlined,
                              color: AppColors.primary,
                              size: 16,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Report',
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: AppColors.primary,
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
      ),
    );
  }

  Widget _buildAvatar(String name) {
    return Container(
      width: 42, height: 42,
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
          name.isNotEmpty ? name[0].toUpperCase() : '?',
          style: GoogleFonts.inter(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
      ),
    );
  }

  Widget _buildActionChip({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.circular(100),
          border: Border.all(color: Colors.black.withOpacity(0.07)),
        ),
        child: Row(
          children: [
            Icon(icon, size: 15, color: color),
            const SizedBox(width: 5),
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: AppColors.textMedium,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Empty / error state ──────────────────────────────────────────────────────

  Widget _buildEmptyState({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 72, height: 72,
            decoration: const BoxDecoration(
              color: AppColors.communityBg,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: AppColors.primary, size: 32),
          ),
          const SizedBox(height: 18),
          Text(
            title,
            style: GoogleFonts.inter(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: AppColors.textDark,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 14,
              color: AppColors.textMedium,
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }
  String _getTimeAgo(String timestamp) {
    try {
      final dt = DateTime.parse(timestamp);
      final diff = DateTime.now().difference(dt);
      if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
      if (diff.inHours < 24) return '${diff.inHours}h ago';
      if (diff.inDays < 30) return '${diff.inDays}d ago';
      return '${(diff.inDays / 30).floor()}mo ago';
    } catch (_) {
      return '';
    }
  }
}
