import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../models/post_model.dart';


class PostDetailScreen extends StatefulWidget {
  final VoicePost post;
  final bool readOnly;

  const PostDetailScreen({
    super.key,
    required this.post,
    this.readOnly = false,
  });

  @override
  State<PostDetailScreen> createState() => _PostDetailScreenState();
}

class _PostDetailScreenState extends State<PostDetailScreen> {
  final TextEditingController _commentController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final DatabaseReference _dbRef = FirebaseDatabase.instance.ref();
  
  bool _isSubmitting = false;
  Set<String> _blockedUserIds = {};
  final Map<String, String> _profileImageCache = {};

  @override
  void initState() {
    super.initState();
    _listenToBlockedUsers();
  }

  @override
  void dispose() {
    _commentController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _listenToBlockedUsers() {
    final user = _auth.currentUser;
    if (user == null) return;

    _dbRef
        .child('users')
        .child(user.uid)
        .child('blockedUsers')
        .onValue
        .listen((event) {
      final blocked = <String>{};
      if (event.snapshot.value is Map) {
        final data = Map<String, dynamic>.from(event.snapshot.value as Map);
        for (final entry in data.entries) {
          if (entry.value == true || entry.value is Map) {
            blocked.add(entry.key);
          }
        }
      }
      if (mounted) {
        setState(() => _blockedUserIds = blocked);
      }
    });
  }

  Future<void> _submitReply() async {
    if (widget.readOnly) {
      _showBlockedNotice();
      return;
    }

    final text = _commentController.text.trim();
    if (text.isEmpty || _isSubmitting) return;

    final user = _auth.currentUser;
    if (user == null) return;

    setState(() => _isSubmitting = true);

    try {
      final String timestamp = DateTime.now().toIso8601String();
      
      // 1. Fetch user name from DB or Auth
      final userSnap = await _dbRef.child('users').child(user.uid).get();
      String userName = user.displayName?.trim() ?? '';
      if (userSnap.exists) {
        final userData = Map<String, dynamic>.from(userSnap.value as Map);
        userName = _firstText(
          userData,
          ['name', 'fullName', 'userName', 'displayName'],
          fallback: userName,
        );
      }
      if (userName.trim().isEmpty) {
        userName = user.email?.split('@').first.trim() ?? 'Anonymous';
      }

      // 2. Push reply
      final replyRef = _dbRef.child('replies').child(widget.post.key).push();
      await replyRef.set({
        'uid': user.uid,
        'name': userName,
        'text': text,
        'timestamp': timestamp,
      });

      // 3. Increment reply count on post without rewriting the whole post.
      await _dbRef.child('posts').child(widget.post.key).update({
        'replies': ServerValue.increment(1),
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

  String _firstText(
    Map<String, dynamic> data,
    List<String> keys, {
    String fallback = '',
  }) {
    for (final key in keys) {
      final text = data[key]?.toString().trim() ?? '';
      if (text.isNotEmpty) return text;
    }
    return fallback;
  }

  Future<void> _reportPost() async {
    if (widget.readOnly) {
      _showBlockedNotice();
      return;
    }

    final user = _auth.currentUser;
    if (user == null) return;

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
      final postRef = _dbRef.child('posts').child(widget.post.key);
      final reportRef = postRef.child('reports').child(user.uid);
      final existing = await reportRef.get();

      if (existing.exists) {
        _showSnack('You already reported this post.');
        return;
      }

      final userSnap = await _dbRef.child('users').child(user.uid).get();
      final userData = userSnap.value is Map
          ? Map<String, dynamic>.from(userSnap.value as Map)
          : <String, dynamic>{};

      final timestamp = DateTime.now().toIso8601String();
      final reportData = {
        'uid': user.uid,
        'reporterName': userData['name'] ?? user.displayName ?? 'User',
        'reporterEmail': userData['email'] ?? user.email ?? '',
        'reason': reportReason,
        'timestamp': timestamp,
        'postId': widget.post.key,
        'postOwnerUid': widget.post.uid,
        'postOwnerName': widget.post.name,
        'postDescription': widget.post.description,
        'postLocation': widget.post.location,
        'postImageUrl': widget.post.imageUrl,
      };

      await reportRef.set(reportData);
      await _dbRef
          .child('userReports')
          .child(user.uid)
          .child(widget.post.key)
          .set(reportData);

      await postRef.update({
        'reportCount': ServerValue.increment(1),
      });

      _showSnack('Post reported and added to your profile.');
    } catch (e) {
      _showSnack('Failed to report post: $e');
    }
  }

  Future<void> _toggleBlockPostOwner() async {
    if (widget.readOnly) {
      _showBlockedNotice();
      return;
    }

    final user = _auth.currentUser;
    if (user == null ||
        widget.post.uid.isEmpty ||
        widget.post.uid == user.uid) {
      return;
    }

    final bool isBlocked = _blockedUserIds.contains(widget.post.uid);
    final String action = isBlocked ? 'Unblock' : 'Block';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          '$action ${widget.post.name}',
          style: GoogleFonts.inter(fontWeight: FontWeight.w800),
        ),
        content: Text(
          isBlocked
              ? 'You will start seeing updates from this user again.'
              : 'You will stop seeing posts and responses from this user.',
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

    final ref = _dbRef
        .child('users')
        .child(user.uid)
        .child('blockedUsers')
        .child(widget.post.uid);
    final mirrorRef =
        _dbRef.child('userBlocks').child(user.uid).child(widget.post.uid);

    try {
      if (isBlocked) {
        await ref.remove();
        try {
          await mirrorRef.remove();
        } catch (_) {}
        _showSnack('${widget.post.name} unblocked.');
      } else {
        final blockData = {
          'uid': widget.post.uid,
          'name': widget.post.name,
          'blockedAt': DateTime.now().toIso8601String(),
        };
        await ref.set(blockData);
        try {
          await mirrorRef.set(blockData);
        } catch (_) {}
        _showSnack('${widget.post.name} blocked.');
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
                // Detailed Post header with authority and progress
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
                          'Responses',
                          style: GoogleFonts.inter(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textDark,
                            letterSpacing: -0.5,
                          ),
                        ),
                        const SizedBox(width: 8),
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
                                'No responses yet. Be the first to respond!',
                                style: GoogleFonts.inter(color: AppColors.textLight, fontSize: 13),
                              ),
                            ],
                          ),
                        ),
                      );
                    }

                    final rawData = Map<String, dynamic>.from(snapshot.data!.snapshot.value as Map);
                    final List<PostReply> replies = rawData.entries
                        .map((e) => PostReply.fromMap(
                              e.key,
                              Map<String, dynamic>.from(e.value as Map),
                            ))
                        .where((reply) =>
                            reply.uid == _auth.currentUser?.uid ||
                            !_blockedUserIds.contains(reply.uid))
                        .toList();
                    
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
          
          if (widget.readOnly) _buildReadOnlyBar() else _buildInputArea(),
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

        // IMAGE + BACK BUTTON
        Stack(
          children: [

            // IMAGE
            if (widget.post.imageUrl.isNotEmpty)
              ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  bottom: Radius.circular(24),
                ),
                child: Image.network(
                  widget.post.imageUrl,
                  width: double.infinity,
                  height: 280,
                  fit: BoxFit.cover,
                ),
              )
            else
              Container(
                height: 220,
                width: double.infinity,
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Color(0xFFFF7B5F),
                      AppColors.primary,
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.vertical(
                    bottom: Radius.circular(24),
                  ),
                ),
              ),

            // DARK OVERLAY
            Container(
              height: widget.post.imageUrl.isNotEmpty ? 280 : 220,
              decoration: BoxDecoration(
                borderRadius: const BorderRadius.vertical(
                  bottom: Radius.circular(24),
                ),
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withOpacity(0.45),
                    Colors.transparent,
                  ],
                ),
              ),
            ),

            // BACK BUTTON
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
                child: Row(
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.35),
                        shape: BoxShape.circle,
                      ),
                      child: IconButton(
                        icon: const Icon(
                          Icons.arrow_back,
                          color: Colors.white,
                        ),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ),
                    const Spacer(),
                    if (!widget.readOnly)
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.35),
                          shape: BoxShape.circle,
                        ),
                        child: IconButton(
                          icon: const Icon(
                            Icons.flag_outlined,
                            color: Colors.white,
                          ),
                          onPressed: _reportPost,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),

        const SizedBox(height: 16),

        // AUTHOR & CATEGORY
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              _buildAvatar(widget.post.name, uid: widget.post.uid),
              const SizedBox(width: 12),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.post.name,
                      style: GoogleFonts.inter(
                        fontWeight: FontWeight.w700,
                        color: AppColors.textDark,
                      ),
                    ),

                    Text(
                      widget.post.location,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: AppColors.textLight,
                      ),
                    ),
                  ],
                ),
              ),

              _buildCategoryBadge(widget.post.category),
            ],
          ),
        ),

        if (!widget.readOnly)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
            child: Align(
              alignment: Alignment.centerRight,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (widget.post.uid.isNotEmpty &&
                      widget.post.uid != _auth.currentUser?.uid) ...[
                    GestureDetector(
                      onTap: _toggleBlockPostOwner,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
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
                              _blockedUserIds.contains(widget.post.uid)
                                  ? Icons.person_add_alt_1_outlined
                                  : Icons.person_off_outlined,
                              color: const Color(0xFF0052D4),
                              size: 16,
                            ),
                            const SizedBox(width: 5),
                            Text(
                              _blockedUserIds.contains(widget.post.uid)
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
                    const SizedBox(width: 8),
                  ],
                  GestureDetector(
                    onTap: _reportPost,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
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
                          const Icon(
                            Icons.flag_outlined,
                            color: Color(0xFF0052D4),
                            size: 16,
                          ),
                          const SizedBox(width: 5),
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
          ),

        // DESCRIPTION
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 18, 16, 0),
          child: Text(
            widget.post.description,
            style: GoogleFonts.inter(
              fontSize: 15,
              color: AppColors.textMedium,
              height: 1.7,
            ),
          ),
        ),

        // AUTHORITY CARD
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 14,
          ),
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.communityBg,
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  const Icon(
                    Icons.notifications_active,
                    color: AppColors.primary,
                    size: 20,
                  ),

                  const SizedBox(width: 10),

                  Expanded(
                    child: Text(
                      'Authorities have been notified about this issue.',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        color: AppColors.textDark,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // SUPPORTS & REPLIES
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 16),
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [

                  Expanded(
                    child: Column(
                      children: [
                        Text(
                          '${widget.post.supports}',
                          style: GoogleFonts.inter(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: AppColors.primary,
                          ),
                        ),

                        const SizedBox(height: 4),

                        Text(
                          'Supports',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: AppColors.textLight,
                          ),
                        ),
                      ],
                    ),
                  ),

                  Container(
                    width: 1,
                    height: 36,
                    color: Colors.grey.shade300,
                  ),

                  Expanded(
                    child: Column(
                      children: [
                        Text(
                          '${widget.post.replies}',
                          style: GoogleFonts.inter(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: AppColors.primary,
                          ),
                        ),

                        const SizedBox(height: 4),

                        Text(
                          'Replies',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: AppColors.textLight,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // TIME
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
            child: Text(
              _getTimeDisplay(widget.post.timestamp),
              style: GoogleFonts.inter(
                fontSize: 12,
                color: AppColors.textLight,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReplyTile(PostReply reply) {
    final savedName = reply.name.trim();

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 2,
      child: FutureBuilder<String>(
        future: _resolveReplyUserName(reply),
        initialData: _isGenericName(savedName) ? 'Loading...' : savedName,
        builder: (context, snapshot) {
          final displayName = snapshot.data?.trim().isNotEmpty == true
              ? snapshot.data!.trim()
              : 'Anonymous';

          return Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildAvatar(
                  displayName,
                  uid: reply.uid,
                  size: 34,
                  fontSize: 13,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Flexible(
                            child: Text(
                              displayName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textDark,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
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
        },
      ),
    );
  }

  Future<String> _resolveReplyUserName(PostReply reply) async {
    final savedName = reply.name.trim();
    if (!_isGenericName(savedName)) return savedName;

    final uid = reply.uid.trim();
    if (uid.isEmpty) return savedName.isEmpty ? 'Anonymous' : savedName;

    try {
      final snap = await _dbRef.child('users').child(uid).get();
      if (snap.value is Map) {
        final userData = Map<String, dynamic>.from(snap.value as Map);
        final resolvedName = _firstText(
          userData,
          ['name', 'fullName', 'userName', 'displayName', 'email'],
        );
        if (!_isGenericName(resolvedName)) return resolvedName;
      }
    } catch (_) {}

    return savedName.isEmpty ? 'Anonymous' : savedName;
  }

  bool _isGenericName(String name) {
    final normalized = name.trim().toLowerCase();
    return normalized.isEmpty ||
        normalized == 'user' ||
        normalized == 'anonymous' ||
        normalized == 'loading...';
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

  Widget _buildReadOnlyBar() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(
        16,
        12,
        16,
        MediaQuery.of(context).padding.bottom + 12,
      ),
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
      child: Text(
        'Your account is blocked. You can only view this post.',
        textAlign: TextAlign.center,
        style: GoogleFonts.inter(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: AppColors.textDark,
        ),
      ),
    );
  }

  Widget _buildAvatar(
    String name, {
    String? uid,
    double size = 42,
    double fontSize = 16,
  }) {
    final userId = uid?.trim() ?? '';
    if (userId.isNotEmpty) {
      return FutureBuilder<String>(
        future: _resolveProfileImageUrl(userId),
        builder: (context, snapshot) {
          final imageUrl = snapshot.data?.trim() ?? '';
          return _buildAvatarContent(
            name,
            imageUrl: imageUrl,
            size: size,
            fontSize: fontSize,
          );
        },
      );
    }

    return _buildAvatarContent(name, size: size, fontSize: fontSize);
  }

  Future<String> _resolveProfileImageUrl(String uid) async {
    if (_profileImageCache.containsKey(uid)) {
      return _profileImageCache[uid] ?? '';
    }

    try {
      final snap = await _dbRef.child('users').child(uid).get();
      if (snap.value is Map) {
        final data = Map<String, dynamic>.from(snap.value as Map);
        final imageUrl = _firstText(
          data,
          ['profileImageUrl', 'profile_image_url', 'photoUrl', 'photoURL'],
        );
        if (imageUrl.isNotEmpty) {
          _profileImageCache[uid] = imageUrl;
          return imageUrl;
        }
      }
    } catch (_) {}
    _profileImageCache[uid] = '';
    return '';
  }

  Widget _buildAvatarContent(
    String name, {
    String imageUrl = '',
    double size = 42,
    double fontSize = 16,
  }) {
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
      clipBehavior: Clip.antiAlias,
      child: imageUrl.isNotEmpty
          ? Image.network(
              imageUrl,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) =>
                  _buildAvatarInitial(name, fontSize: fontSize),
            )
          : _buildAvatarInitial(name, fontSize: fontSize),
    );
  }

  Widget _buildAvatarInitial(String name, {double fontSize = 16}) {
    return Center(
      child: Text(
        name.isNotEmpty ? name[0].toUpperCase() : '?',
        style: GoogleFonts.inter(
          fontSize: fontSize,
          fontWeight: FontWeight.w700,
          color: Colors.white,
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
