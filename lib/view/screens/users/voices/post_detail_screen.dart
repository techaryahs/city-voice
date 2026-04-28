import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../models/post_model.dart';

class PostDetailScreen extends StatefulWidget {
  final VoicePost post;

  const PostDetailScreen({super.key, required this.post});

  @override
  State<PostDetailScreen> createState() => _PostDetailScreenState();
}

class _PostDetailScreenState extends State<PostDetailScreen> {
  final TextEditingController _commentController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _focusNode = FocusNode();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final DatabaseReference _dbRef = FirebaseDatabase.instance.ref();

  bool _isSubmitting = false;
  bool _isInputFocused = false;

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(() {
      setState(() => _isInputFocused = _focusNode.hasFocus);
    });
  }

  @override
  void dispose() {
    _commentController.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  // ── ALL BACKEND UNTOUCHED ─────────────────────────────────────────────

  Future<void> _submitReply() async {
    final text = _commentController.text.trim();
    if (text.isEmpty || _isSubmitting) return;

    final user = _auth.currentUser;
    if (user == null) return;

    setState(() => _isSubmitting = true);

    try {
      final String timestamp = DateTime.now().toIso8601String();

      final userSnap = await _dbRef.child('users').child(user.uid).get();
      String userName = user.displayName ?? 'User';
      if (userSnap.exists) {
        final userData = Map<String, dynamic>.from(userSnap.value as Map);
        userName = userData['name'] ?? userName;
      }

      final replyRef =
      _dbRef.child('replies').child(widget.post.key).push();
      await replyRef.set({
        'uid': user.uid,
        'name': userName,
        'text': text,
        'timestamp': timestamp,
      });

      await _dbRef
          .child('posts')
          .child(widget.post.key)
          .runTransaction((Object? post) {
        if (post == null) return Transaction.abort();
        Map<String, dynamic> postMap =
        Map<String, dynamic>.from(post as Map);
        postMap['replies'] = (postMap['replies'] ?? 0) + 1;
        return Transaction.success(postMap);
      });

      _commentController.clear();
      _focusNode.unfocus();
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent + 100,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to post reply: $e'),
          backgroundColor: AppColors.primary,
          behavior: SnackBarBehavior.floating,
          shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  // ── BUILD ─────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          Expanded(
            child: CustomScrollView(
              controller: _scrollController,
              slivers: [
                _buildSliverAppBar(),
                SliverToBoxAdapter(child: _buildPostBody()),
                SliverToBoxAdapter(child: _buildRepliesHeader()),
                _buildRepliesList(),
                const SliverPadding(
                    padding: EdgeInsets.only(bottom: 120)),
              ],
            ),
          ),
          _buildInputArea(),
        ],
      ),
    );
  }

  // ── Sliver App Bar (collapses image) ──────────────────────────────────

  Widget _buildSliverAppBar() {
    final hasImage = widget.post.imageUrl.isNotEmpty;

    return SliverAppBar(
      expandedHeight: hasImage ? 260 : 0,
      pinned: true,
      backgroundColor: Colors.white,
      elevation: 0,
      leading: Padding(
        padding: const EdgeInsets.all(8),
        child: GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withOpacity(0.12),
                    blurRadius: 8,
                    offset: const Offset(0, 2))
              ],
            ),
            child: const Icon(Icons.arrow_back_ios_new_rounded,
                size: 18, color: AppColors.textDark),
          ),
        ),
      ),
      title: Text(
        'Post Details',
        style: GoogleFonts.inter(
          color: AppColors.textDark,
          fontWeight: FontWeight.w700,
          fontSize: 16,
        ),
      ),
      centerTitle: true,
      actions: [
        Padding(
          padding: const EdgeInsets.only(right: 8),
          child: IconButton(
            icon: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: AppColors.background,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.black.withOpacity(0.07)),
              ),
              child: const Icon(Icons.more_horiz_rounded,
                  size: 18, color: AppColors.textDark),
            ),
            onPressed: () => _showOptionsSheet(),
          ),
        ),
      ],
      flexibleSpace: hasImage
          ? FlexibleSpaceBar(
        background: Stack(
          fit: StackFit.expand,
          children: [
            Image.network(
              widget.post.imageUrl,
              fit: BoxFit.cover,
            ),
            // Bottom gradient
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                height: 80,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [
                      Colors.white,
                      Colors.white.withOpacity(0),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      )
          : null,
    );
  }

  // ── Post Body ─────────────────────────────────────────────────────────

  Widget _buildPostBody() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Author row + category
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildAvatar(widget.post.name, size: 46, fontSize: 18),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.post.name,
                      style: GoogleFonts.inter(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textDark,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        Icon(Icons.location_on_outlined,
                            size: 12, color: AppColors.textLight),
                        const SizedBox(width: 3),
                        Expanded(
                          child: Text(
                            widget.post.location,
                            style: GoogleFonts.inter(
                                fontSize: 12, color: AppColors.textLight),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              _buildCategoryBadge(widget.post.category),
            ],
          ),

          const SizedBox(height: 18),

          // Description
          Text(
            widget.post.description,
            style: GoogleFonts.inter(
              fontSize: 15,
              color: AppColors.textDark,
              height: 1.65,
            ),
          ),

          const SizedBox(height: 16),

          // Timestamp
          Row(
            children: [
              Icon(Icons.access_time_rounded,
                  size: 13, color: AppColors.textLight),
              const SizedBox(width: 4),
              Text(
                _getTimeDisplay(widget.post.timestamp),
                style: GoogleFonts.inter(
                    fontSize: 12, color: AppColors.textLight),
              ),
            ],
          ),

          const SizedBox(height: 20),

          // Divider
          Divider(color: Colors.black.withOpacity(0.06)),

          const SizedBox(height: 16),

          // Support + Replies stats
          Row(
            children: [
              _buildStatPill(
                icon: Icons.favorite_rounded,
                label: '${widget.post.supports} Supports',
                color: AppColors.primary,
                bg: AppColors.communityBg,
              ),
              const SizedBox(width: 10),
              StreamBuilder<DatabaseEvent>(
                stream: _dbRef
                    .child('posts')
                    .child(widget.post.key)
                    .child('replies')
                    .onValue,
                builder: (context, snap) {
                  final count =
                      snap.data?.snapshot.value ?? widget.post.replies;
                  return _buildStatPill(
                    icon: Icons.chat_bubble_rounded,
                    label: '$count Replies',
                    color: AppColors.conversationalIcon,
                    bg: AppColors.conversationalBg,
                  );
                },
              ),
              const Spacer(),
              // Share button
              GestureDetector(
                onTap: () {},
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    borderRadius: BorderRadius.circular(100),
                    border:
                    Border.all(color: Colors.black.withOpacity(0.08)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.share_outlined,
                          size: 14, color: AppColors.textMedium),
                      const SizedBox(width: 5),
                      Text(
                        'Share',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textMedium,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Replies Header ────────────────────────────────────────────────────

  Widget _buildRepliesHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 8),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 18,
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(100),
            ),
          ),
          const SizedBox(width: 10),
          Text(
            'Replies',
            style: GoogleFonts.inter(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: AppColors.textDark,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(width: 8),
          StreamBuilder<DatabaseEvent>(
            stream: _dbRef
                .child('posts')
                .child(widget.post.key)
                .child('replies')
                .onValue,
            builder: (context, snap) {
              final count =
                  snap.data?.snapshot.value ?? widget.post.replies;
              return Container(
                padding:
                const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.communityBg,
                  borderRadius: BorderRadius.circular(100),
                ),
                child: Text(
                  '$count',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary,
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  // ── Replies List ──────────────────────────────────────────────────────

  Widget _buildRepliesList() {
    return StreamBuilder<DatabaseEvent>(
      stream: _dbRef
          .child('replies')
          .child(widget.post.key)
          .orderByChild('timestamp')
          .onValue,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return const SliverFillRemaining(
            child: Center(
              child: CircularProgressIndicator(
                  color: AppColors.primary, strokeWidth: 2),
            ),
          );
        }

        if (!snapshot.hasData ||
            snapshot.data!.snapshot.value == null) {
          return SliverFillRemaining(
            hasScrollBody: false,
            child: _buildEmptyReplies(),
          );
        }

        final rawData = Map<String, dynamic>.from(
            snapshot.data!.snapshot.value as Map);
        final List<PostReply> replies = rawData.entries
            .map((e) => PostReply.fromMap(
            e.key, Map<String, dynamic>.from(e.value as Map)))
            .toList();
        replies.sort((a, b) => a.timestamp.compareTo(b.timestamp));

        return SliverList(
          delegate: SliverChildBuilderDelegate(
                (context, index) => _buildReplyTile(replies[index], index),
            childCount: replies.length,
          ),
        );
      },
    );
  }

  Widget _buildEmptyReplies() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: AppColors.conversationalBg,
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.chat_bubble_outline_rounded,
                size: 28, color: AppColors.conversationalIcon),
          ),
          const SizedBox(height: 14),
          Text(
            'No replies yet',
            style: GoogleFonts.inter(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: AppColors.textDark,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Be the first to speak up!',
            style: GoogleFonts.inter(
                fontSize: 13, color: AppColors.textLight),
          ),
        ],
      ),
    );
  }

  // ── Reply Tile ────────────────────────────────────────────────────────

  Widget _buildReplyTile(PostReply reply, int index) {
    final isCurrentUser = _auth.currentUser?.uid == reply.uid;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      decoration: BoxDecoration(
        color: isCurrentUser
            ? AppColors.communityBg
            : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: isCurrentUser
            ? Border.all(color: AppColors.primary.withOpacity(0.2))
            : null,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildAvatar(reply.name, size: 36, fontSize: 13),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Text(
                          reply.name,
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textDark,
                          ),
                        ),
                        if (isCurrentUser) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.primary,
                              borderRadius: BorderRadius.circular(100),
                            ),
                            child: Text(
                              'You',
                              style: GoogleFonts.inter(
                                fontSize: 9,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    Text(
                      _getTimeDisplay(reply.timestamp),
                      style: GoogleFonts.inter(
                          fontSize: 11, color: AppColors.textLight),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  reply.text,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: AppColors.textMedium,
                    height: 1.55,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Input Area ────────────────────────────────────────────────────────

  Widget _buildInputArea() {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
        border: _isInputFocused
            ? Border(
            top: BorderSide(
                color: AppColors.primary.withOpacity(0.3), width: 1.5))
            : Border(
            top: BorderSide(
                color: Colors.black.withOpacity(0.06), width: 1)),
      ),
      padding: EdgeInsets.fromLTRB(
          16, 12, 16, MediaQuery.of(context).padding.bottom + 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // Avatar
          _buildAvatar(
            _auth.currentUser?.displayName ?? 'U',
            size: 36,
            fontSize: 13,
          ),
          const SizedBox(width: 10),

          // Text field
          Expanded(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: _isInputFocused
                      ? AppColors.primary.withOpacity(0.4)
                      : Colors.transparent,
                  width: 1.5,
                ),
              ),
              padding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: TextField(
                controller: _commentController,
                focusNode: _focusNode,
                style: GoogleFonts.inter(
                    fontSize: 14, color: AppColors.textDark),
                decoration: InputDecoration(
                  hintText: 'Share your thoughts...',
                  hintStyle: GoogleFonts.inter(
                      color: AppColors.textLight, fontSize: 14),
                  border: InputBorder.none,
                  isDense: true,
                  contentPadding:
                  const EdgeInsets.symmetric(vertical: 10),
                ),
                maxLines: 4,
                minLines: 1,
                textCapitalization: TextCapitalization.sentences,
              ),
            ),
          ),
          const SizedBox(width: 10),

          // Send button
          GestureDetector(
            onTap: _submitReply,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                gradient: _commentController.text.trim().isNotEmpty
                    ? const LinearGradient(
                  colors: [Color(0xFFFF7B5F), AppColors.primary],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
                    : null,
                color: _commentController.text.trim().isEmpty
                    ? AppColors.background
                    : null,
                shape: BoxShape.circle,
                boxShadow: _commentController.text.trim().isNotEmpty
                    ? [
                  BoxShadow(
                    color: AppColors.primary.withOpacity(0.35),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  )
                ]
                    : [],
              ),
              child: _isSubmitting
                  ? const Padding(
                padding: EdgeInsets.all(12),
                child: CircularProgressIndicator(
                    color: Colors.white, strokeWidth: 2),
              )
                  : Icon(
                Icons.send_rounded,
                color: _commentController.text.trim().isNotEmpty
                    ? Colors.white
                    : AppColors.textLight,
                size: 20,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Helpers ───────────────────────────────────────────────────────────

  Widget _buildAvatar(String name,
      {double size = 42, double fontSize = 16}) {
    return Container(
      width: size,
      height: size,
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
            fontSize: fontSize,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryBadge(String category) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.communityBg,
        borderRadius: BorderRadius.circular(100),
        border: Border.all(color: AppColors.primary.withOpacity(0.2)),
      ),
      child: Text(
        category,
        style: GoogleFonts.inter(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: AppColors.primary,
        ),
      ),
    );
  }

  Widget _buildStatPill({
    required IconData icon,
    required String label,
    required Color color,
    required Color bg,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(100),
      ),
      child: Row(
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 5),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  void _showOptionsSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.12),
                borderRadius: BorderRadius.circular(100),
              ),
            ),
            const SizedBox(height: 20),
            _optionTile(Icons.share_outlined, 'Share post', AppColors.hyperLocalIcon),
            _optionTile(Icons.flag_outlined, 'Report post', AppColors.primary),
            _optionTile(Icons.copy_outlined, 'Copy link', AppColors.supportiveIcon),
          ],
        ),
      ),
    );
  }

  Widget _optionTile(IconData icon, String label, Color color) {
    return ListTile(
      leading: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: color, size: 18),
      ),
      title: Text(label,
          style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.textDark)),
      onTap: () => Navigator.pop(context),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    );
  }

  String _getTimeDisplay(String timestamp) {
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
}