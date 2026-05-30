import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../models/post_model.dart';
import '../voices/post_detail_screen.dart';

class AllPostsScreen extends StatelessWidget {
  final List<Map<String, dynamic>> posts;
  final String title;

  const AllPostsScreen({
    Key? key,
    required this.posts,
    required this.title,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final double statusBarHeight = MediaQuery.of(context).padding.top;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(kToolbarHeight),
        child: Container(
          height: kToolbarHeight + statusBarHeight,
          padding: EdgeInsets.only(top: statusBarHeight),
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF0052D4), Color(0xFF4364F7)],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                onPressed: () => Navigator.pop(context),
              ),
              Expanded(
                child: Center(
                  child: Text(
                    title,
                    style: GoogleFonts.inter(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 48),
            ],
          ),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: ListView.separated(
          itemCount: posts.length,
          separatorBuilder: (_, __) => const SizedBox(height: 16),
          itemBuilder: (context, index) {
            final post = posts[index];
            final String text = post['description'] ?? '';
            final String timestamp = post['timestamp'] ?? '';
            final String imageUrl = post['image_url'] ?? '';
            final String locationStr = post['location'] ?? 'Unknown Location';
            final String status = post['status'] ?? 'In Progress';

            // Determine status colors
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
                  MaterialPageRoute(builder: (_) => PostDetailScreen(post: voicePost)),
                );
              },
              child: Container(
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
                    ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: Container(
                        width: 80,
                        height: 80,
                        color: const Color(0xFFF5F0ED),
                        child: imageUrl.isNotEmpty
                            ? Image.network(
                                imageUrl,
                                fit: BoxFit.cover,
                                errorBuilder: (ctx, err, stack) =>
                                    const Icon(Icons.image_outlined, color: Colors.grey, size: 24),
                              )
                            : const Icon(Icons.chat_bubble_outline_rounded, color: Colors.grey, size: 24),
                      ),
                    ),
                    const SizedBox(width: 14),
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
                                  style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF757575)),
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
                                _timeAgo(timestamp),
                                style: GoogleFonts.inter(fontSize: 11, color: Colors.grey),
                              ),
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
          },
        ),
      ),
    );
  }

  String _timeAgo(String timestamp) {
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
