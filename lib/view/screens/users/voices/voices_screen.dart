import 'dart:async';
import 'dart:io';

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
      return const Color(0xFF1E4FD6);

    case 'footpath':
      return const Color(0xFF5B6274);

    case 'public toilets':
      return const Color(0xFF16A085);

    case 'garbage':
      return const Color(0xFF1FAE6E);

    case 'garden & trees':
      return const Color(0xFF27AE60);

    case 'water':
      return const Color(0xFF2F6BFF);

    case 'street lights':
      return const Color(0xFF1E4FD6);

    case 'other':
      return const Color(0xFF7F8C8D);

    default:
      return const Color(0xFF1ABCCD);
  }
}

class _Skyline extends StatelessWidget {
  final double width;
  final double height;

  const _Skyline({required this.width, required this.height});

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: 0.55,
      child: SizedBox(
        width: width,
        height: height,
        child: CustomPaint(painter: _SkylinePainter()),
      ),
    );
  }
}

class _SkylinePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = const Color(0xFFBDD8FF);
    final softPaint = Paint()..color = const Color(0xFFD7E8FF);
    final birdPaint = Paint()
      ..color = const Color(0xFF9BBFF2)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.3
      ..strokeCap = StrokeCap.round;

    final ground = size.height * 0.86;
    final unit = size.width / 14;
    final buildings = <Rect>[
      Rect.fromLTWH(unit * 5.0, ground - 20, unit * 0.9, 20),
      Rect.fromLTWH(unit * 6.0, ground - 45, unit * 1.2, 45),
      Rect.fromLTWH(unit * 7.45, ground - 58, unit * 1.0, 58),
      Rect.fromLTWH(unit * 8.8, ground - 32, unit * 1.0, 32),
      Rect.fromLTWH(unit * 10.0, ground - 50, unit * 1.1, 50),
      Rect.fromLTWH(unit * 11.35, ground - 28, unit * 0.85, 28),
    ];

    canvas.drawCircle(Offset(unit * 4.1, ground - 46), 3.2, softPaint);
    canvas.drawCircle(Offset(unit * 5.8, ground - 60), 2.2, softPaint);

    for (final rect in buildings) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(2)),
        paint,
      );
      for (double y = rect.top + 9; y < rect.bottom - 3; y += 11) {
        canvas.drawRect(
          Rect.fromLTWH(rect.left + rect.width * 0.25, y, 2, 3),
          softPaint,
        );
        canvas.drawRect(
          Rect.fromLTWH(rect.left + rect.width * 0.58, y, 2, 3),
          softPaint,
        );
      }
    }

    final base = Paint()
      ..color = const Color(0xFFE2F0FF)
      ..strokeWidth = 2;
    canvas.drawLine(
      Offset(unit * 4.5, ground),
      Offset(unit * 12.6, ground),
      base,
    );

    void drawBird(double x, double y, double scale) {
      final path = Path()
        ..moveTo(x, y)
        ..quadraticBezierTo(x + 4 * scale, y - 4 * scale, x + 8 * scale, y)
        ..moveTo(x + 8 * scale, y)
        ..quadraticBezierTo(x + 12 * scale, y - 4 * scale, x + 16 * scale, y);
      canvas.drawPath(path, birdPaint);
    }

    drawBird(unit * 3.2, size.height * 0.32, 0.45);
    drawBird(unit * 4.3, size.height * 0.23, 0.35);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

Color _catBg(String cat) {
  switch (cat.toLowerCase()) {
    case 'roads':
      return const Color(0xFFE9F0FF);

    case 'footpath':
      return const Color(0xFFF5EEFF);

    case 'public toilets':
      return const Color(0xFFEEFFFB);

    case 'garbage':
      return const Color(0xFFE5F7EE);

    case 'garden & trees':
      return const Color(0xFFEFFAF1);

    case 'water':
      return const Color(0xFFE9F0FF);

    case 'street lights':
      return const Color(0xFFE9F0FF);

    case 'other':
      return const Color(0xFFF4F4F4);

    default:
      return const Color(0xFFEDF8FB);
  }
}

// ── Screen ────────────────────────────────────────────────────────────────────

class VoicesScreen extends StatefulWidget {
  final bool readOnly;
  final int updatesBadgeCount;

  const VoicesScreen({
    super.key,
    this.readOnly = false,
    this.updatesBadgeCount = 0,
  });

  @override
  State<VoicesScreen> createState() => _VoicesScreenState();
}

class _VoicesScreenState extends State<VoicesScreen> {
  final _postsRef = FirebaseDatabase.instance.ref('posts');
  final _usersRef = FirebaseDatabase.instance.ref('users');
  String get _currentUid => FirebaseAuth.instance.currentUser?.uid ?? '';
  String _userLocation = 'Fetching location...';
  Set<String> _blockedUserIds = {};
  Set<String> _existingUserIds = {};
  final Map<String, String> _profileImageCache = {};
  final Map<String, XFile> _shareImageCache = {};
  bool _hasLoadedUsers = false;
  StreamSubscription<DatabaseEvent>? _usersSubscription;
  Future<List<VoicePost>>? _visiblePostsFuture;
  String _visiblePostsKey = '';
  List<VoicePost>? _lastVisiblePosts;
  bool _isSharing = false;

  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _feedScrollController = ScrollController();
  bool _isSearching = false;

  String _selectedCategory = 'All';

  final List<String> _categories = [
    'All',
    'Roads',
    'Garbage',
    'Street Lights',
    'Water',
    'Garden & Trees',
    'Footpath',
    'Public Toilets',
    'Other',
  ];

  @override
  void initState() {
    super.initState();
    _getUserLocation();
    _listenToUsers();
  }

  @override
  void dispose() {
    _usersSubscription?.cancel();
    _searchController.dispose();
    _feedScrollController.dispose();
    super.dispose();
  }

  void _listenToUsers() {
    final currentUid = _currentUid;
    if (currentUid.isEmpty) return;

    _usersSubscription = _usersRef.onValue.listen((event) {
      final existingUsers = <String>{};
      final blocked = <String>{};
      final hasUsersMap = event.snapshot.value is Map;

      if (hasUsersMap) {
        final users = Map<String, dynamic>.from(event.snapshot.value as Map);
        for (final entry in users.entries) {
          if (_isVisibleUserRecord(entry.value)) {
            existingUsers.add(entry.key);
          }
        }

        final currentUser = users[currentUid];
        final blockedData = currentUser is Map
            ? Map<String, dynamic>.from(currentUser)['blockedUsers']
            : null;
        if (blockedData is Map) {
          final data = Map<String, dynamic>.from(blockedData);
          for (final entry in data.entries) {
            if (entry.value == true || entry.value is Map) {
              blocked.add(entry.key);
            }
          }
        }
      }

      if (mounted) {
        setState(() {
          _existingUserIds = existingUsers;
          _blockedUserIds = blocked;
          _hasLoadedUsers = hasUsersMap;
        });
      }
    });
  }

  Map<String, dynamic> _readSupportedBy(dynamic value) {
    if (value is Map) return Map<String, dynamic>.from(value);
    if (value is List) {
      return {
        for (final item in value)
          if (item != null && item.toString().trim().isNotEmpty)
            item.toString(): true,
      };
    }
    return <String, dynamic>{};
  }

  bool _isVisibleUserRecord(dynamic value) {
    if (value is! Map) return false;
    final user = Map<String, dynamic>.from(value);
    final status = (user['status'] ?? '').toString().trim().toLowerCase();
    final hiddenStatuses = {
      'deleted',
      'removed',
      'inactive',
      'deactivated',
      'disabled',
    };

    return user['deleted'] != true &&
        user['isDeleted'] != true &&
        user['removed'] != true &&
        user['accountDeleted'] != true &&
        user['disabled'] != true &&
        !hiddenStatuses.contains(status);
  }

  Future<List<VoicePost>> _filterVisibleOwnerPosts(
    List<VoicePost> posts,
  ) async {
    final filtered = <VoicePost>[];

    for (final post in posts) {
      final ownerUid = post.uid.trim();
      if (ownerUid.isEmpty) continue;

      if (_existingUserIds.contains(ownerUid)) {
        filtered.add(post);
        continue;
      }

      try {
        final ownerSnapshot = await _usersRef.child(ownerUid).get();
        if (ownerSnapshot.exists && _isVisibleUserRecord(ownerSnapshot.value)) {
          filtered.add(post);
        }
      } catch (_) {
        // If rules block this lookup, do not hide valid community posts.
        filtered.add(post);
      }
    }

    return filtered;
  }

  Future<List<VoicePost>> _visiblePostsFor(List<VoicePost> posts) {
    final key = posts.map((post) => '${post.key}:${post.timestamp}').join('|');
    if (_visiblePostsFuture != null && key == _visiblePostsKey) {
      return _visiblePostsFuture!;
    }

    _visiblePostsKey = key;
    _visiblePostsFuture = _filterVisibleOwnerPosts(posts).then((visiblePosts) {
      _lastVisiblePosts = visiblePosts;
      return visiblePosts;
    });
    return _visiblePostsFuture!;
  }

  // ── Support toggle ──────────────────────────────────────────────────────────

  Future<void> _toggleSupport(VoicePost post) async {
    if (widget.readOnly) {
      _showBlockedNotice();
      return;
    }

    if (_currentUid.isEmpty) return;

    final ref = _postsRef.child(post.key);

    final hasSupported = post.supportedBy.containsKey(_currentUid);

    try {
      await ref.update({
        'supportedBy/$_currentUid': hasSupported ? null : true,
        'supports': ServerValue.increment(hasSupported ? -1 : 1),
      });
    } catch (e) {
      _showSnack(
        e.toString().toLowerCase().contains('permission')
            ? 'Support is blocked by Firebase rules. Please update database rules.'
            : 'Could not update support. Please try again.',
      );
    }
  }

  Future<void> _sharePost(VoicePost post) async {
    if (widget.readOnly) {
      _showBlockedNotice();
      return;
    }
    if (_isSharing) return;
    _isSharing = true;

    const playStoreLink =
        'https://play.google.com/store/apps/details?id=com.amit.cityvoice';
    final shareText =
        '''
CityVoice Issue

${post.description}
Location: ${post.location}

Download CityVoice: $playStoreLink
Support this voice on CityVoice app.
''';

    try {
      final imageFile = await _downloadShareImage(post.imageUrl);
      await SharePlus.instance.share(
        ShareParams(
          text: shareText,
          subject: 'CityVoice Issue',
          files: imageFile == null ? null : [imageFile],
        ),
      );
    } catch (_) {
      await SharePlus.instance.share(
        ShareParams(text: shareText, subject: 'CityVoice Issue'),
      );
    } finally {
      _isSharing = false;
    }
  }

  Future<XFile?> _downloadShareImage(String imageUrl) async {
    final trimmedUrl = imageUrl.trim();
    final uri = Uri.tryParse(trimmedUrl);
    if (trimmedUrl.isEmpty || uri == null || !uri.hasScheme) {
      return null;
    }
    if (_shareImageCache.containsKey(trimmedUrl)) {
      return _shareImageCache[trimmedUrl];
    }

    final client = HttpClient();
    try {
      final request = await client.getUrl(uri).timeout(
            const Duration(seconds: 8),
          );
      final response = await request.close().timeout(
            const Duration(seconds: 12),
          );
      if (response.statusCode < 200 || response.statusCode >= 300) {
        return null;
      }

      final bytes = await response.fold<List<int>>(
        <int>[],
        (previous, element) => previous..addAll(element),
      );
      if (bytes.isEmpty) return null;

      final mimeType = response.headers.contentType?.mimeType;
      final extension = _shareImageExtension(uri, mimeType);
      final file = File(
        '${Directory.systemTemp.path}${Platform.pathSeparator}'
        'cityvoice_${DateTime.now().microsecondsSinceEpoch}$extension',
      );
      await file.writeAsBytes(bytes, flush: true);
      final xFile = XFile(file.path, mimeType: mimeType);
      _shareImageCache[trimmedUrl] = xFile;
      return xFile;
    } finally {
      client.close(force: true);
    }
  }

  String _shareImageExtension(Uri uri, String? mimeType) {
    final path = uri.path.toLowerCase();
    for (final extension in ['.jpg', '.jpeg', '.png', '.webp']) {
      if (path.endsWith(extension)) return extension;
    }

    switch (mimeType) {
      case 'image/png':
        return '.png';
      case 'image/webp':
        return '.webp';
      default:
        return '.jpg';
    }
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

    final reportReason = reason == 'Other'
        ? await _showOtherReportDialog()
        : reason;

    if (reportReason == null || reportReason.trim().isEmpty) return;

    try {
      final postRef = _postsRef.child(post.key);
      final reportRef = postRef.child('reports').child(_currentUid);
      final existing = await reportRef.get();

      if (existing.exists) {
        _showSnack('You already reported this post.');
        return;
      }

      final userSnap = await FirebaseDatabase.instance
          .ref('users')
          .child(_currentUid)
          .get();
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

      await postRef.update({'reportCount': ServerValue.increment(1)});

      _showSnack('Post reported and added to your profile.');
    } catch (e) {
      _showSnack('Failed to report post: $e');
    }
  }

  Future<void> _toggleBlockUser(VoicePost post) async {
    if (widget.readOnly) {
      _showBlockedNotice();
      return;
    }

    final currentUid = _currentUid;
    if (currentUid.isEmpty || post.uid.isEmpty || post.uid == currentUid) {
      return;
    }

    final bool isBlocked = _blockedUserIds.contains(post.uid);
    final String action = isBlocked ? 'Unblock' : 'Block';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          '$action ${post.name}',
          style: GoogleFonts.inter(fontWeight: FontWeight.w800),
        ),
        content: Text(
          isBlocked
              ? 'You will start seeing updates from this user again.'
              : 'You will stop seeing posts and updates from this user.',
          style: GoogleFonts.inter(
            fontSize: 13,
            color: AppColors.textMedium,
            height: 1.5,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(action),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final ref = _usersRef
        .child(currentUid)
        .child('blockedUsers')
        .child(post.uid);
    final mirrorRef = FirebaseDatabase.instance
        .ref('userBlocks')
        .child(currentUid)
        .child(post.uid);

    try {
      if (isBlocked) {
        await ref.remove();
        try {
          await mirrorRef.remove();
        } catch (_) {}
        _showSnack('${post.name} unblocked.');
      } else {
        final blockData = {
          'uid': post.uid,
          'name': post.name,
          'blockedAt': DateTime.now().toIso8601String(),
        };
        await ref.set(blockData);
        try {
          await mirrorRef.set(blockData);
        } catch (_) {}
        _showSnack('${post.name} blocked.');
      }
    } catch (e) {
      _showSnack('Could not update blocked users: $e');
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
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
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
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _getUserLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();

      if (!serviceEnabled) return;

      LocationPermission permission = await Geolocator.checkPermission();

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
          _userLocation = '${place.locality}, ${place.administrativeArea}';
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
      resizeToAvoidBottomInset: false,
      backgroundColor: const Color(0xFFF5F8FE),
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
                      child: CircularProgressIndicator(
                        color: AppColors.primary,
                      ),
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
                      subtitle:
                          'Be the first to raise a voice\nin your community!',
                    );
                  }

                  // ── Parse posts (newest first) ───────────────────────────
                  final raw = Map<String, dynamic>.from(
                    event.snapshot.value as Map,
                  );
                  final posts =
                      raw.entries
                          .map(
                            (e) => VoicePost.fromSnapshot(
                              event.snapshot.child(e.key),
                            ),
                          )
                          .where((post) {
                            // ── SEARCH FILTER ───────────────────

                            final matchesSearch =
                                post.description.toLowerCase().contains(
                                  _searchQuery,
                                ) ||
                                post.category.toLowerCase().contains(
                                  _searchQuery,
                                ) ||
                                post.location.toLowerCase().contains(
                                  _searchQuery,
                                );

                            // ── CATEGORY FILTER ─────────────────

                            final category = post.category.toLowerCase();
                            final visibleCategories = {
                              'roads',
                              'garbage',
                              'street lights',
                              'water',
                              'garden & trees',
                              'footpath',
                              'public toilets',
                              'other',
                            };
                            final matchesCategory =
                                _selectedCategory == 'All' ||
                                (_selectedCategory == 'More'
                                    ? !visibleCategories.contains(category)
                                    : category ==
                                          _selectedCategory.toLowerCase());

                            final isBlockedUser =
                                post.uid != _currentUid &&
                                _blockedUserIds.contains(post.uid);

                            return matchesSearch &&
                                matchesCategory &&
                                !isBlockedUser;
                          })
                          .toList()
                        ..sort((a, b) => b.timestamp.compareTo(a.timestamp));

                  return FutureBuilder<List<VoicePost>>(
                    future: _visiblePostsFor(posts),
                    initialData: _lastVisiblePosts ?? posts,
                    builder: (context, ownerSnapshot) {
                      final visiblePosts =
                          ownerSnapshot.data ?? _lastVisiblePosts ?? posts;
                      if (ownerSnapshot.connectionState ==
                              ConnectionState.waiting &&
                          !ownerSnapshot.hasData) {
                        return const Center(
                          child: CircularProgressIndicator(
                            color: AppColors.primary,
                          ),
                        );
                      }

                      if (visiblePosts.isEmpty) {
                        return _buildEmptyState(
                          icon: Icons.campaign_outlined,
                          title: 'No voices yet',
                          subtitle: 'No active community voices to show.',
                        );
                      }

                      return ListView.builder(
                        key: const PageStorageKey<String>('voices-feed-list'),
                        controller: _feedScrollController,
                        padding: EdgeInsets.fromLTRB(
                          16,
                          8,
                          16,
                          MediaQuery.of(context).orientation ==
                                  Orientation.landscape
                              ? 76
                              : 100,
                        ),
                        itemCount: visiblePosts.length,
                        itemBuilder: (_, i) => _buildPostCard(visiblePosts[i]),
                      );
                    },
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
    final isLandscape =
        MediaQuery.of(context).orientation == Orientation.landscape;

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFFEAF2FF), Color(0xFFF7F9FC)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      padding: EdgeInsets.fromLTRB(18, isLandscape ? 6 : 12, 18, 0),
      child: SizedBox(
        height: isLandscape ? 42 : 56,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            const Positioned(
              top: -2,
              right: 46,
              child: _Skyline(width: 190, height: 68),
            ),
            Positioned(
              left: 0,
              right: 0,
              top: 0,
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Image.asset(
                      'assets/images/logo.jpeg',
                      width: 34,
                      height: 34,
                      fit: BoxFit.cover,
                    ),
                  ),
                  const SizedBox(width: 9),
                  RichText(
                    text: TextSpan(
                      style: GoogleFonts.inter(
                        fontSize: 19,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF151A24),
                      ),
                      children: const [
                        TextSpan(text: 'City'),
                        TextSpan(
                          text: 'Voice',
                          style: TextStyle(color: Color(0xFF2F6BFF)),
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  _buildNotificationBell(),
                  const SizedBox(width: 10),
                  GestureDetector(
                    onTap: () {
                      setState(() {
                        _isSearching = !_isSearching;
                        if (!_isSearching) {
                          _searchController.clear();
                          _searchQuery = '';
                        }
                      });
                    },
                    child: Icon(
                      _isSearching ? Icons.close_rounded : Icons.search_rounded,
                      color: const Color(0xFF3A3F4B),
                      size: 24,
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

  Widget _buildSearchAndFilters() {
    final isLandscape =
        MediaQuery.of(context).orientation == Orientation.landscape;

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF8FBFF),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF141E3C).withOpacity(0.035),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      padding: EdgeInsets.fromLTRB(14, 0, 14, isLandscape ? 8 : 18),

      child: Column(
        children: [
          // ── SEARCH BAR ───────────────────────────
          if (_isSearching) ...[
            _buildSearchField(),
            SizedBox(height: isLandscape ? 6 : 10),
          ],

          _buildLocationBar(),

          SizedBox(height: isLandscape ? 8 : 14),

          // ── CATEGORY FILTERS ─────────────────────
          SizedBox(
            height: isLandscape ? 44 : 70,

            child: ListView.separated(
              scrollDirection: Axis.horizontal,

              itemCount: _categories.length,

              separatorBuilder: (_, __) =>
                  SizedBox(width: isLandscape ? 8 : 10),

              itemBuilder: (_, index) {
                final category = _categories[index];

                final isSelected = _selectedCategory == category;

                return GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedCategory = category;
                    });
                  },

                  child: _buildCategoryTile(category, isSelected),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchField() {
    return Container(
      height: 44,
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF141E3C).withOpacity(0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: TextField(
        controller: _searchController,
        autofocus: true,
        onChanged: (value) {
          setState(() => _searchQuery = value.trim().toLowerCase());
        },
        decoration: InputDecoration(
          hintText: 'Search voices...',
          hintStyle: GoogleFonts.inter(
            fontSize: 13,
            color: const Color(0xFF9AA1B0),
          ),
          prefixIcon: const Icon(
            Icons.search_rounded,
            color: Color(0xFF2F6BFF),
            size: 20,
          ),
          suffixIcon: _searchQuery.isEmpty
              ? null
              : IconButton(
                  icon: const Icon(Icons.close_rounded, size: 18),
                  onPressed: () {
                    setState(() {
                      _searchController.clear();
                      _searchQuery = '';
                    });
                  },
                ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 12),
        ),
      ),
    );
  }

  Widget _buildLocationBar() {
    final isLandscape =
        MediaQuery.of(context).orientation == Orientation.landscape;

    return Container(
      height: isLandscape ? 36 : 48,
      padding: EdgeInsets.symmetric(horizontal: isLandscape ? 12 : 16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF141E3C).withOpacity(0.06),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          const Icon(
            Icons.location_on_rounded,
            color: Color(0xFF2F6BFF),
            size: 20,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _userLocation,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.inter(
                fontSize: 14.5,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF151A24),
              ),
            ),
          ),
          const Icon(
            Icons.keyboard_arrow_down_rounded,
            color: Color(0xFF9AA1B0),
            size: 18,
          ),
          const SizedBox(width: 10),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.my_location_rounded,
                color: Color(0xFF2F6BFF),
                size: 17,
              ),
              const SizedBox(width: 5),
              Text(
                'Near Me',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF2F6BFF),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryTile(String category, bool isSelected) {
    final isLandscape =
        MediaQuery.of(context).orientation == Orientation.landscape;
    final label = category == 'Street Lights' ? 'Streetlight' : category;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      width: isLandscape ? 92 : 68,
      height: isLandscape ? 38 : 60,
      padding: EdgeInsets.symmetric(
        horizontal: isLandscape ? 12 : 6,
        vertical: isLandscape ? 0 : 7,
      ),
      decoration: BoxDecoration(
        color: isSelected ? const Color(0xFF2F6BFF) : AppColors.white,
        borderRadius: BorderRadius.circular(13),
        border: Border.all(
          color: isSelected ? const Color(0xFF2F6BFF) : const Color(0xFFEAECF1),
        ),
        boxShadow: [
          BoxShadow(
            color: isSelected
                ? const Color(0xFF2F6BFF).withOpacity(0.35)
                : const Color(0xFF141E3C).withOpacity(0.05),
            blurRadius: isSelected ? 14 : 8,
            offset: Offset(0, isSelected ? 6 : 2),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (!isLandscape) ...[
            Icon(
              _categoryIcon(category),
              size: 18,
              color: isSelected ? Colors.white : const Color(0xFF5B6274),
            ),
            const SizedBox(height: 6),
          ],
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: isSelected ? Colors.white : const Color(0xFF5B6274),
            ),
          ),
        ],
      ),
    );
  }

  IconData _categoryIcon(String category) {
    switch (category.toLowerCase()) {
      case 'all':
        return Icons.dashboard_rounded;
      case 'roads':
        return Icons.add_road_rounded;
      case 'garbage':
        return Icons.delete_outline_rounded;
      case 'street lights':
        return Icons.lightbulb_outline_rounded;
      case 'water':
        return Icons.water_drop_outlined;
      case 'footpath':
        return Icons.directions_walk_rounded;
      case 'public toilets':
        return Icons.wc_rounded;
      case 'garden & trees':
        return Icons.park_outlined;
      default:
        return Icons.more_horiz_rounded;
    }
  }

  Widget _buildNotificationBell() {
    final badgeCount = widget.updatesBadgeCount;
    return Stack(
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: AppColors.white,
            shape: BoxShape.circle,
            border: Border.all(color: const Color(0xFFEAECF1)),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF141E3C).withOpacity(0.06),
                blurRadius: 3,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          child: const Icon(
            Icons.notifications_outlined,
            color: Color(0xFF3A3F4B),
            size: 19,
          ),
        ),
        if (badgeCount > 0)
          Positioned(
            right: -2,
            top: -2,
            child: Container(
              constraints: const BoxConstraints(minWidth: 16),
              height: 16,
              padding: const EdgeInsets.symmetric(horizontal: 4),
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(99),
                border: Border.all(color: const Color(0xFFEAF2FF), width: 2),
              ),
              child: Center(
                child: Text(
                  badgeCount > 99 ? '99+' : badgeCount.toString(),
                  style: GoogleFonts.inter(
                    color: Colors.white,
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  // ── Post card ────────────────────────────────────────────────────────────────

  Widget _buildPostCard(VoicePost post) {
    final isLandscape =
        MediaQuery.of(context).orientation == Orientation.landscape;
    final catColor = _catColor(post.category);
    final catBg = _catBg(post.category);
    final hasSupported = post.supportedBy.containsKey(_currentUid);

    return Container(
      margin: EdgeInsets.only(bottom: isLandscape ? 8 : 12),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF141E3C).withOpacity(0.06),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(
              14,
              isLandscape ? 10 : 14,
              14,
              isLandscape ? 4 : 6,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildAvatar(post.name, uid: post.uid),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        post.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textDark,
                        ),
                      ),
                      Text(
                        _getTimeAgo(post.timestamp),
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: const Color(0xFF667085),
                        ),
                      ),
                    ],
                  ),
                ),
                _buildCategoryBadge(post.category, catColor, catBg),
                const SizedBox(width: 8),
                _buildStatusBadge(post.status),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
            child: ReadMoreText(
              post.description,
              trimLines: 2,
              trimMode: TrimMode.Line,
              trimCollapsedText: ' See more',
              trimExpandedText: ' Show less',
              style: GoogleFonts.inter(
                fontSize: 14,
                color: const Color(0xFF111827),
                height: 1.45,
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
          if (post.imageUrl.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.network(
                  post.imageUrl,
                  height: isLandscape ? 96 : 150,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  loadingBuilder: (_, child, progress) => progress == null
                      ? child
                      : Container(
                                height: isLandscape ? 96 : 150,
                          color: AppColors.background,
                          child: const Center(
                            child: CircularProgressIndicator(
                              color: AppColors.primary,
                              strokeWidth: 2,
                            ),
                          ),
                        ),
                  errorBuilder: (_, __, ___) => Container(
                      height: isLandscape ? 96 : 150,
                    color: AppColors.background,
                    child: const Center(
                      child: Icon(
                        Icons.broken_image_outlined,
                        color: AppColors.textLight,
                        size: 32,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 8, 14, 10),
            child: Row(
              children: [
                const Icon(
                  Icons.location_on_rounded,
                  size: 14,
                  color: Color(0xFF667085),
                ),
                const SizedBox(width: 5),
                Expanded(
                  child: Text(
                    post.location,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF667085),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Container(
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: Color(0xFFF0F3F8))),
            ),
            child: Row(
              children: [
                _buildPostAction(
                  icon: hasSupported
                      ? Icons.thumb_up_alt_rounded
                      : Icons.thumb_up_alt_outlined,
                  label: 'Support',
                  count: _formatCount(post.supports),
                  color: hasSupported
                      ? AppColors.primary
                      : const Color(0xFF202A3A),
                  onTap: widget.readOnly ? null : () => _toggleSupport(post),
                ),
                _buildActionDivider(),
                _buildPostAction(
                  icon: Icons.chat_bubble_outline_rounded,
                  label: 'Respond',
                  count: _formatCount(post.replies),
                  color: const Color(0xFF202A3A),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (c) => PostDetailScreen(
                        post: post,
                        readOnly: widget.readOnly,
                      ),
                    ),
                  ),
                ),
                if (!widget.readOnly) _buildActionDivider(),
                if (!widget.readOnly)
                  _buildPostAction(
                    icon: Icons.share_outlined,
                    label: 'Share',
                    count: '',
                    color: const Color(0xFF202A3A),
                    onTap: () => _sharePost(post),
                  ),
                if (!widget.readOnly) _buildActionDivider(),
                if (!widget.readOnly)
                  _buildPostAction(
                    icon: Icons.flag_outlined,
                    label: 'Report',
                    count: '',
                    color: const Color(0xFFE53935),
                    onTap: () => _reportPost(post),
                  ),
                if (!widget.readOnly &&
                    post.uid.isNotEmpty &&
                    post.uid != _currentUid)
                  _buildActionDivider(),
                if (!widget.readOnly &&
                    post.uid.isNotEmpty &&
                    post.uid != _currentUid)
                  _buildPostAction(
                    icon: _blockedUserIds.contains(post.uid)
                        ? Icons.person_add_alt_1_outlined
                        : Icons.block_rounded,
                    label: _blockedUserIds.contains(post.uid)
                        ? 'Unblock'
                        : 'Block',
                    count: '',
                    color: const Color(0xFF202A3A),
                    onTap: () => _toggleBlockUser(post),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionDivider() {
    return Container(width: 1, height: 34, color: const Color(0xFFEFF3F8));
  }

  Widget _buildCategoryBadge(String category, Color color, Color bgColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(100),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(_categoryIcon(category), size: 14, color: color),
          const SizedBox(width: 5),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 82),
            child: Text(
              category,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    final isResolved = status.toLowerCase() == 'resolved';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: isResolved ? const Color(0xFFE9F9EE) : const Color(0xFFFFF4E5),
        borderRadius: BorderRadius.circular(100),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.circle,
            size: 7,
            color: isResolved
                ? const Color(0xFF1E9E57)
                : const Color(0xFFE69500),
          ),
          const SizedBox(width: 6),
          Text(
            isResolved ? 'Resolved' : 'Pending',
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: isResolved
                  ? const Color(0xFF1E9E57)
                  : const Color(0xFFE69500),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPostAction({
    required IconData icon,
    required String label,
    required String count,
    required Color color,
    required VoidCallback? onTap,
  }) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        child: Container(
          height: 50,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, size: 17, color: color),
                  const SizedBox(width: 5),
                  Text(
                    label,
                    style: GoogleFonts.inter(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: color,
                    ),
                  ),
                ],
              ),
              if (count.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(
                  count,
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: AppColors.primary,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  String _formatCount(int value) {
    if (value >= 1000000) return '${(value / 1000000).toStringAsFixed(1)}M';
    if (value >= 1000) return '${(value / 1000).toStringAsFixed(1)}K';
    return value.toString();
  }

  Widget buildPostCardLegacy(VoicePost post) {
    final catColor = _catColor(post.category);
    final catBg = _catBg(post.category);

    // ✅ IMPORTANT: check if current user supported
    final hasSupported = post.supportedBy.containsKey(_currentUid);

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (c) =>
              PostDetailScreen(post: post, readOnly: widget.readOnly),
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
                  _buildAvatar(post.name, uid: post.uid),
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
                            Icon(
                              Icons.location_on_outlined,
                              size: 11,
                              color: AppColors.textLight,
                            ),
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
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
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
                loadingBuilder: (_, child, progress) => progress == null
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
                    child: Icon(
                      Icons.broken_image_outlined,
                      color: AppColors.textLight,
                      size: 32,
                    ),
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

                  if (!widget.readOnly &&
                      post.uid.isNotEmpty &&
                      post.uid != _currentUid)
                    GestureDetector(
                      onTap: () => _toggleBlockUser(post),
                      child: Container(
                        margin: const EdgeInsets.only(right: 8),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 7,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEAF3FF),
                          borderRadius: BorderRadius.circular(100),
                          border: Border.all(
                            color: const Color(0xFF1A73E8).withOpacity(0.18),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              _blockedUserIds.contains(post.uid)
                                  ? Icons.person_add_alt_1_outlined
                                  : Icons.person_off_outlined,
                              color: const Color(0xFF0052D4),
                              size: 16,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              _blockedUserIds.contains(post.uid)
                                  ? 'Unblock'
                                  : 'Block',
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: const Color(0xFF0052D4),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                  if (!widget.readOnly)
                    GestureDetector(
                      onTap: () => _reportPost(post),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 7,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEAF3FF),
                          borderRadius: BorderRadius.circular(100),
                          border: Border.all(
                            color: const Color(0xFF1A73E8).withOpacity(0.18),
                          ),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.flag_outlined,
                              color: Color(0xFF0052D4),
                              size: 16,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Report',
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: const Color(0xFF0052D4),
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

  Widget _buildAvatar(String name, {String? uid}) {
    final userId = uid?.trim() ?? '';
    if (userId.isNotEmpty) {
      if (_profileImageCache.containsKey(userId)) {
        return _buildAvatarContent(
          name,
          imageUrl: _profileImageCache[userId] ?? '',
        );
      }

      return FutureBuilder<String>(
        future: _resolveProfileImageUrl(userId),
        builder: (context, snapshot) {
          final imageUrl = snapshot.data?.trim() ?? '';
          return _buildAvatarContent(name, imageUrl: imageUrl);
        },
      );
    }

    return _buildAvatarContent(name);
  }

  Future<String> _resolveProfileImageUrl(String uid) async {
    if (_profileImageCache.containsKey(uid)) {
      return _profileImageCache[uid] ?? '';
    }

    try {
      final snapshot = await _usersRef.child(uid).get();
      if (snapshot.value is Map) {
        final data = Map<String, dynamic>.from(snapshot.value as Map);
        for (final key in [
          'profileImageUrl',
          'profile_image_url',
          'photoUrl',
          'photoURL',
        ]) {
          final url = data[key]?.toString().trim() ?? '';
          if (url.isNotEmpty) {
            _profileImageCache[uid] = url;
            return url;
          }
        }
      }
    } catch (_) {}
    _profileImageCache[uid] = '';
    return '';
  }

  Widget _buildAvatarContent(String name, {String imageUrl = ''}) {
    return Container(
      width: 36,
      height: 36,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF2F6BFF), Color(0xFF1E4FD6)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        shape: BoxShape.circle,
      ),
      clipBehavior: Clip.antiAlias,
      child: imageUrl.isNotEmpty
          ? Image.network(
              imageUrl,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => _buildAvatarInitial(name),
            )
          : _buildAvatarInitial(name),
    );
  }

  Widget _buildAvatarInitial(String name) {
    return Center(
      child: Text(
        name.isNotEmpty ? name[0].toUpperCase() : '?',
        style: GoogleFonts.inter(
          fontSize: 16,
          fontWeight: FontWeight.w700,
          color: Colors.white,
        ),
      ),
    );
  }

  Widget buildActionChipLegacy({
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
            width: 72,
            height: 72,
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
