import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/constants/app_colors.dart';

class AlertsScreen extends StatelessWidget {
  const AlertsScreen({super.key});

  final List<_AlertItem> _alerts = const [
    _AlertItem(
      icon: Icons.favorite_rounded,
      iconColor: AppColors.primary,
      iconBg: Color(0xFFFFF0EE),
      title: 'Jayesh Thakare supported your voice',
      timeAgo: '22h ago',
    ),
    _AlertItem(
      icon: Icons.notifications_rounded,
      iconColor: Color(0xFF2ECC71),
      iconBg: Color(0xFFEEFBF4),
      title: 'Welcome to CityVoice! Test broadcast from admin..',
      timeAgo: '1d ago',
    ),
    _AlertItem(
      icon: Icons.chat_bubble_rounded,
      iconColor: Color(0xFF1ABCCD),
      iconBg: Color(0xFFEDF8FB),
      title: 'Priya Sharma replied to your voice',
      timeAgo: '2d ago',
    ),
    _AlertItem(
      icon: Icons.campaign_rounded,
      iconColor: Color(0xFF4A7BE8),
      iconBg: Color(0xFFEEF4FF),
      title: 'Your issue has been marked as resolved by admin',
      timeAgo: '3d ago',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(),
            const SizedBox(height: 8),
            Expanded(
              child: _alerts.isEmpty
                  ? _buildEmptyState()
                  : ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                itemCount: _alerts.length,
                itemBuilder: (context, index) =>
                    _buildAlertCard(_alerts[index], index),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      color: AppColors.white,
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Notifications',
            style: GoogleFonts.inter(
              fontSize: 26,
              fontWeight: FontWeight.w800,
              color: AppColors.textDark,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Echoes from your community',
            style: GoogleFonts.inter(
              fontSize: 13,
              color: AppColors.textLight,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAlertCard(_AlertItem alert, int index) {
    final bool isUnread = index < 2; // first two are unread

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        border: isUnread
            ? Border.all(color: AppColors.primary.withOpacity(0.15))
            : null,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {},
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Icon
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: alert.iconBg,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(alert.icon, color: alert.iconColor, size: 20),
                ),

                const SizedBox(width: 14),

                // Text
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              alert.title,
                              style: GoogleFonts.inter(
                                fontSize: 14,
                                fontWeight: isUnread
                                    ? FontWeight.w600
                                    : FontWeight.w400,
                                color: AppColors.textDark,
                                height: 1.45,
                              ),
                            ),
                          ),
                          if (isUnread) ...[
                            const SizedBox(width: 8),
                            Container(
                              width: 8,
                              height: 8,
                              margin: const EdgeInsets.only(top: 4),
                              decoration: const BoxDecoration(
                                color: AppColors.primary,
                                shape: BoxShape.circle,
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        alert.timeAgo,
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
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: AppColors.communityBg,
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.notifications_off_outlined,
                size: 32, color: AppColors.primary),
          ),
          const SizedBox(height: 16),
          Text(
            'No notifications yet',
            style: GoogleFonts.inter(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppColors.textDark,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'When someone supports or replies\nto your voice, it shows up here.',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 13,
              color: AppColors.textLight,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _AlertItem {
  final IconData icon;
  final Color iconColor;
  final Color iconBg;
  final String title;
  final String timeAgo;

  const _AlertItem({
    required this.icon,
    required this.iconColor,
    required this.iconBg,
    required this.title,
    required this.timeAgo,
  });
}