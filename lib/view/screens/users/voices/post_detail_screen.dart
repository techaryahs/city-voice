import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../models/post_model.dart';
import 'package:intl/intl.dart';

class PostDetailScreen extends StatefulWidget {
  final VoicePost post;

  const PostDetailScreen({super.key, required this.post});

  @override
  State<PostDetailScreen> createState() => _PostDetailScreenState();
}

class _PostDetailScreenState extends State<PostDetailScreen> {
  final TextEditingController _commentController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final DatabaseReference _dbRef = FirebaseDatabase.instance.ref();
  
  bool _isSubmitting = false;

  @override
  void dispose() {
    _commentController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _submitReply() async {
    final text = _commentController.text.trim();
    if (text.isEmpty || _isSubmitting) return;

    final user = _auth.currentUser;
    if (user == null) return;

    setState(() => _isSubmitting = true);

    try {
      final String timestamp = DateTime.now().toIso8601String();
      
      // 1. Fetch user name from DB or Auth
      final userSnap = await _dbRef.child('users').child(user.uid).get();
      String userName = user.displayName ?? 'User';
      if (userSnap.exists) {
        final userData = Map<String, dynamic>.from(userSnap.value as Map);
        userName = userData['name'] ?? userName;
      }

      // 2. Push reply
      final replyRef = _dbRef.child('replies').child(widget.post.key).push();
      await replyRef.set({
        'uid': user.uid,
        'name': userName,
        'text': text,
        'timestamp': timestamp,
      });

      // 3. Increment reply count on post
      await _dbRef.child('posts').child(widget.post.key).runTransaction((Object? post) {
        if (post == null) return Transaction.abort();
        Map<String, dynamic> postMap = Map<String, dynamic>.from(post as Map);
        postMap['replies'] = (postMap['replies'] ?? 0) + 1;
        return Transaction.success(postMap);
      });

      _commentController.clear();
      // Scroll to bottom
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent + 100,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to post reply: $e')),
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text(
          'Post Details',
          style: GoogleFonts.inter(
            color: AppColors.textDark,
            fontWeight: FontWeight.w700,
            fontSize: 16,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: AppColors.textDark, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: CustomScrollView(
              controller: _scrollController,
              slivers: [
                // Detailed Post header
                SliverToBoxAdapter(
                  child: _buildPostHeader(),
                ),
                
                // Replies Header
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
                    child: Row(
                      children: [
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
                          stream: _dbRef.child('posts').child(widget.post.key).child('replies').onValue,
                          builder: (context, snap) {
                            final count = snap.data?.snapshot.value ?? widget.post.replies;
                            return Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
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
                  ),
                ),

                // Replies List
                StreamBuilder<DatabaseEvent>(
                  stream: _dbRef.child('replies').child(widget.post.key).orderByChild('timestamp').onValue,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
                      return const SliverFillRemaining(
                        child: Center(child: CircularProgressIndicator(color: AppColors.primary)),
                      );
                    }

                    if (!snapshot.hasData || snapshot.data!.snapshot.value == null) {
                      return SliverFillRemaining(
                        hasScrollBody: false,
                        child: Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.chat_bubble_outline_rounded, size: 48, color: AppColors.textLight.withOpacity(0.5)),
                              const SizedBox(height: 16),
                              Text(
                                'No replies yet. Be the first to speak!',
                                style: GoogleFonts.inter(color: AppColors.textLight, fontSize: 13),
                              ),
                            ],
                          ),
                        ),
                      );
                    }

                    final rawData = Map<String, dynamic>.from(snapshot.data!.snapshot.value as Map);
                    final List<PostReply> replies = rawData.entries.map((e) => PostReply.fromMap(e.key, Map<String, dynamic>.from(e.value as Map))).toList();
                    
                    // Sort locally since Firebase ordering can be tricky with keys
                    replies.sort((a, b) => a.timestamp.compareTo(b.timestamp));

                    return SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) => _buildReplyTile(replies[index]),
                        childCount: replies.length,
                      ),
                    );
                  },
                ),
                
                const SliverPadding(padding: EdgeInsets.only(bottom: 100)),
              ],
            ),
          ),
          
          // Sticky Input field
          _buildInputArea(),
        ],
      ),
    );
  }

  Widget _buildPostHeader() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Author & Category
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                _buildAvatar(widget.post.name),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.post.name,
                        style: GoogleFonts.inter(fontWeight: FontWeight.w700, color: AppColors.textDark),
                      ),
                      Text(
                        widget.post.location,
                        style: GoogleFonts.inter(fontSize: 12, color: AppColors.textLight),
                      ),
                    ],
                  ),
                ),
                _buildCategoryBadge(widget.post.category),
              ],
            ),
          ),

          // Image
          if (widget.post.imageUrl.isNotEmpty)
            Image.network(
              widget.post.imageUrl,
              width: double.infinity,
              fit: BoxFit.cover,
            ),

          // Description
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: Text(
              widget.post.description,
              style: GoogleFonts.inter(
                fontSize: 15,
                color: AppColors.textMedium,
                height: 1.6,
              ),
            ),
          ),
          
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Text(
              _getTimeDisplay(widget.post.timestamp),
              style: GoogleFonts.inter(fontSize: 12, color: AppColors.textLight),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReplyTile(PostReply reply) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.black.withOpacity(0.04))),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildAvatar(reply.name, size: 34, fontSize: 13),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      reply.name,
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textDark,
                      ),
                    ),
                    Text(
                      _getTimeDisplay(reply.timestamp),
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        color: AppColors.textLight,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  reply.text,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: AppColors.textMedium,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInputArea() {
    return Container(
      padding: EdgeInsets.fromLTRB(16, 12, 16, MediaQuery.of(context).padding.bottom + 12),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(24),
              ),
              child: TextField(
                controller: _commentController,
                style: GoogleFonts.inter(fontSize: 14),
                decoration: InputDecoration(
                  hintText: 'Share your thoughts...',
                  hintStyle: GoogleFonts.inter(color: AppColors.textLight, fontSize: 14),
                  border: InputBorder.none,
                ),
                maxLines: null,
              ),
            ),
          ),
          const SizedBox(width: 12),
          GestureDetector(
            onTap: _submitReply,
            child: Container(
              width: 44,
              height: 44,
              decoration: const BoxDecoration(
                color: AppColors.primary,
                shape: BoxShape.circle,
              ),
              child: _isSubmitting 
                ? const Padding(
                    padding: EdgeInsets.all(12.0),
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                  )
                : const Icon(Icons.send_rounded, color: Colors.white, size: 20),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAvatar(String name, {double size = 42, double fontSize = 16}) {
    return Container(
      width: size, height: size,
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
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.communityBg,
        borderRadius: BorderRadius.circular(100),
      ),
      child: Text(
        category,
        style: GoogleFonts.inter(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: AppColors.primary,
        ),
      ),
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
    } catch (_) { return ''; }
  }
}
