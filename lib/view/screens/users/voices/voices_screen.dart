import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../models/post_model.dart';
import 'post_detail_screen.dart';

// ── Category colour helper ────────────────────────────────────────────────────

Color _catColor(String cat) {
  switch (cat.toLowerCase()) {
    case 'garbage':     return const Color(0xFF2ECC71);
    case 'roads':       return AppColors.primary;
    case 'water':       return const Color(0xFF4A7BE8);
    case 'electricity': return const Color(0xFFF39C12);
    case 'safety':      return const Color(0xFF9B59B6);
    default:            return const Color(0xFF1ABCCD);
  }
}

Color _catBg(String cat) {
  switch (cat.toLowerCase()) {
    case 'garbage':     return const Color(0xFFEEFBF4);
    case 'roads':       return const Color(0xFFFFF0EE);
    case 'water':       return const Color(0xFFEEF4FF);
    case 'electricity': return const Color(0xFFFFFAEE);
    case 'safety':      return const Color(0xFFF5EEFF);
    default:            return const Color(0xFFEDF8FB);
  }
}

// ── Screen ────────────────────────────────────────────────────────────────────

class VoicesScreen extends StatefulWidget {
  const VoicesScreen({super.key});

  @override
  State<VoicesScreen> createState() => _VoicesScreenState();
}

class _VoicesScreenState extends State<VoicesScreen> {
  final _postsRef  = FirebaseDatabase.instance.ref('posts');
  final _currentUid = FirebaseAuth.instance.currentUser?.uid ?? '';

  // ── Support toggle ──────────────────────────────────────────────────────────

  Future<void> _toggleSupport(VoicePost post) async {
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

  // ── Build ───────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
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
                  final posts  = raw.entries
                      .map((e) => VoicePost.fromSnapshot(
                            event.snapshot.child(e.key),
                          ))
                      .toList()
                    ..sort((a, b) => b.timestamp.compareTo(a.timestamp));

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
                    'Near You',
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
          _buildNotificationBell(),
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
        MaterialPageRoute(builder: (c) => PostDetailScreen(post: post)),
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
              child: Text(
                post.description,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color: AppColors.textMedium,
                  height: 1.55,
                ),
              ),
            ),

            // ── Actions ───────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 14),
              child: Row(
                children: [
                  // ❤️ SUPPORT BUTTON (FIXED)
                  _buildActionChip(
                    icon: hasSupported
                        ? Icons.favorite_rounded
                        : Icons.favorite_border_rounded,
                    label: '${post.supports} Support',
                    color: hasSupported ? Colors.red : AppColors.primary,
                    onTap: () => _toggleSupport(post),
                  ),

                  const SizedBox(width: 10),

                  _buildActionChip(
                    icon: Icons.chat_bubble_outline_rounded,
                    label: '${post.replies} Replies',
                    color: AppColors.conversationalIcon,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (c) => PostDetailScreen(post: post)),
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