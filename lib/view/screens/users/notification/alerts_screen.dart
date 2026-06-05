import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/constants/app_colors.dart';

class AlertsScreen extends StatefulWidget {
  const AlertsScreen({super.key});

  @override
  State<AlertsScreen> createState() => _AlertsScreenState();
}

class _AlertsScreenState extends State<AlertsScreen> {
  final DatabaseReference _postsRef =
      FirebaseDatabase.instance.ref('posts');
  final DatabaseReference _notificationsRef =
      FirebaseDatabase.instance.ref('notifications');
  final DatabaseReference _usersRef =
      FirebaseDatabase.instance.ref('users');

  List<_AlertItem> _alerts = [];
  Set<String> _blockedUserIds = {};

  bool _isLoading = true;

  String _currentArea = '';

  @override
  void initState() {
    super.initState();
    _loadNearbyAlerts();
  }

  // ─────────────────────────────────────────────────────────────
  // Detect Current Area
  // ─────────────────────────────────────────────────────────────

  Future<void> _detectCurrentArea() async {
    bool serviceEnabled =
        await Geolocator.isLocationServiceEnabled();

    if (!serviceEnabled) {
      throw Exception("Location services disabled");
    }

    LocationPermission permission =
        await Geolocator.checkPermission();

    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.deniedForever ||
        permission == LocationPermission.denied) {
      throw Exception("Location permission denied");
    }

    Position position = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.best,
    );

    List<Placemark> placemarks =
        await placemarkFromCoordinates(
      position.latitude,
      position.longitude,
    );

    if (placemarks.isNotEmpty) {
      final place = placemarks.first;

      _currentArea =
          place.subLocality?.trim() ??
          place.locality?.trim() ??
          '';

      debugPrint("Current Area: $_currentArea");
    }
  }

  // ─────────────────────────────────────────────────────────────
  // Load Nearby Alerts
  // ─────────────────────────────────────────────────────────────

  Future<void> _loadNearbyAlerts() async {
    try {
      if (mounted) {
        setState(() {
          _isLoading = true;
        });
      }

      final List<_AlertItem> loadedAlerts =
          await _loadAdminNotifications();
      _blockedUserIds = await _loadBlockedUserIds();

      try {
        await _detectCurrentArea();
      } catch (e) {
        debugPrint("Error detecting alert area: $e");
      }

      if (_currentArea.isNotEmpty) {
        final snapshot = await _postsRef.get();

        if (snapshot.exists && snapshot.value is Map) {
          final raw =
              Map<String, dynamic>.from(snapshot.value as Map);

          raw.forEach((key, value) {
            if (value is! Map) return;

            final post =
                Map<String, dynamic>.from(value);

            final String location =
                (post['location'] ?? '')
                    .toString()
                    .toLowerCase();

            final String category =
                (post['category'] ?? 'Issue')
                    .toString();
            final String ownerUid =
                (post['uid'] ?? '').toString();

            final String area =
                _currentArea.toLowerCase();

            if (_blockedUserIds.contains(ownerUid)) return;

            if (location.contains(area) || area.contains(location)) {
              final String status =
                  (post['status'] ?? '').toString().toLowerCase();
              if (post['resolved'] != true && status != 'resolved') {
                loadedAlerts.add(_AlertItem(
                  id: key.toString(),
                  icon: _getCategoryIcon(category),
                  iconColor: _getCategoryColor(category),
                  iconBg: _getCategoryBg(category),
                  title: '$category issue reported near ${post['location']}',
                  timeAgo: 'Nearby Area',
                ));
              }
            }
          });
        }
      }

      if (mounted) {
        setState(() {
          _alerts = loadedAlerts;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Error loading alerts: $e");

      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<List<_AlertItem>> _loadAdminNotifications() async {
    final List<_AlertItem> notices = [];
    final snapshot = await _notificationsRef.get();

    if (!snapshot.exists || snapshot.value is! Map) {
      return notices;
    }

    final raw = Map<String, dynamic>.from(snapshot.value as Map);
    final DateTime now = DateTime.now();

    for (final entry in raw.entries) {
      if (entry.value is! Map) continue;

      final notification =
          Map<String, dynamic>.from(entry.value as Map);
      final String type =
          (notification['type'] ?? '').toString();

      if (type != 'admin_notify') continue;

      final DateTime? expiresAt =
          _parseDateTime(notification['expiresAt']);
      if (expiresAt != null && !expiresAt.isAfter(now)) {
        await _notificationsRef.child(entry.key).remove();
        continue;
      }

      final DateTime? createdAt =
          _parseDateTime(notification['createdAt']);
      final String title =
          _firstText(notification, ['title', 'heading', 'subject']) ??
              'CityVoice notice';
      final String? body =
          _firstText(notification, ['message', 'body', 'description', 'text']);

      notices.add(_AlertItem(
        id: entry.key,
        icon: Icons.campaign_rounded,
        iconColor: const Color(0xFF0052D4),
        iconBg: const Color(0xFFEAF3FF),
        title: title,
        body: body,
        timeAgo: createdAt == null ? 'Admin notice' : _timeAgo(createdAt),
        imageAsset: 'assets/images/logo.jpeg',
        isAdminNotice: true,
        createdAt: createdAt,
      ));
    }

    notices.sort((a, b) {
      final DateTime aDate =
          a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      final DateTime bDate =
          b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      return bDate.compareTo(aDate);
    });

    return notices;
  }

  Future<Set<String>> _loadBlockedUserIds() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return {};

    final snapshot = await _usersRef.child(uid).child('blockedUsers').get();
    if (!snapshot.exists || snapshot.value is! Map) {
      return {};
    }

    final data = Map<String, dynamic>.from(snapshot.value as Map);
    return data.keys.toSet();
  }

  DateTime? _parseDateTime(dynamic value) {
    if (value == null) return null;
    if (value is int) {
      return DateTime.fromMillisecondsSinceEpoch(value);
    }
    if (value is double) {
      return DateTime.fromMillisecondsSinceEpoch(value.round());
    }
    final String text = value.toString().trim();
    if (text.isEmpty) return null;
    final int? millis = int.tryParse(text);
    if (millis != null) {
      return DateTime.fromMillisecondsSinceEpoch(millis);
    }
    return DateTime.tryParse(text)?.toLocal();
  }

  String? _firstText(Map<String, dynamic> data, List<String> keys) {
    for (final key in keys) {
      final value = data[key];
      if (value == null) continue;
      final text = value.toString().trim();
      if (text.isNotEmpty) return text;
    }
    return null;
  }

  String _timeAgo(DateTime dateTime) {
    final Duration diff = DateTime.now().difference(dateTime);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  // ─────────────────────────────────────────────────────────────
  // Category Styling
  // ─────────────────────────────────────────────────────────────

  IconData _getCategoryIcon(String cat) {
    switch (cat.toLowerCase()) {
      case 'roads':
        return Icons.add_road_rounded;

      case 'water':
        return Icons.water_drop_rounded;

      case 'garbage':
        return Icons.delete_outline_rounded;

      case 'electricity':
        return Icons.bolt_rounded;

      case 'safety':
        return Icons.shield_rounded;

      default:
        return Icons.campaign_rounded;
    }
  }

  Color _getCategoryColor(String cat) {
    switch (cat.toLowerCase()) {
      case 'roads':
        return AppColors.primary;

      case 'water':
        return const Color(0xFF1A73E8);

      case 'garbage':
        return const Color(0xFF0052D4);

      case 'electricity':
      case 'street lights':
        return const Color(0xFF3F8CFF);

      case 'safety':
        return const Color(0xFF0D6EFD);

      default:
        return const Color(0xFF0052D4);
    }
  }

  Color _getCategoryBg(String cat) {
    switch (cat.toLowerCase()) {
      case 'roads':
        return const Color(0xFFEAF3FF);

      case 'water':
        return const Color(0xFFEFF6FF);

      case 'garbage':
        return const Color(0xFFDDEEFF);

      case 'electricity':
      case 'street lights':
        return const Color(0xFFEAF3FF);

      case 'safety':
        return const Color(0xFFE6F1FF);

      default:
        return const Color(0xFFEAF3FF);
    }
  }

  // ─────────────────────────────────────────────────────────────
  // UI
  // ─────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            _buildHeader(),

            const SizedBox(height: 8),

            Expanded(
              child: _isLoading
                  ? const Center(
                      child:
                          CircularProgressIndicator(),
                    )
                  : _alerts.isEmpty
                      ? _buildEmptyState()
                      : ListView.builder(
                          padding:
                              const EdgeInsets.fromLTRB(
                            16,
                            8,
                            16,
                            100,
                          ),
                          itemCount: _alerts.length,
                          itemBuilder:
                              (context, index) =>
                                  _buildAlertCard(
                            _alerts[index],
                            index,
                          ),
                        ),
            ),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────

  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      color: AppColors.white,
      padding:
          const EdgeInsets.fromLTRB(20, 20, 20, 18),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Text(
            'Nearby Alerts',
            style: GoogleFonts.inter(
              fontSize: 26,
              fontWeight: FontWeight.w800,
              color: AppColors.textDark,
              letterSpacing: -0.5,
            ),
          ),

          const SizedBox(height: 4),

          Text(
            _currentArea.isEmpty
                ? 'Admin notices and nearby issues'
                : 'Admin notices and issues around $_currentArea',
            style: GoogleFonts.inter(
              fontSize: 13,
              color: AppColors.textLight,
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────

  Widget _buildAlertCard(_AlertItem alert, int index) {
    return SizedBox(
      width: double.infinity,
      height: 132,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(18),
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
          borderRadius: BorderRadius.circular(18),
          child: InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: () {
              // TODO: navigate or other action
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildAlertIcon(alert),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (alert.isAdminNotice) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFEAF3FF),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              'CityVoice Notice',
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: const Color(0xFF0052D4),
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                        ],
                        Text(
                          alert.title,
                          style: GoogleFonts.inter(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textDark,
                            height: 1.35,
                          ),
                          maxLines: alert.body == null ? 2 : 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (alert.body != null) ...[
                          const SizedBox(height: 6),
                          Text(
                            alert.body!,
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              color: AppColors.textMedium,
                              height: 1.45,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                        const Spacer(),
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
      ),
    );
  }

  Widget _buildAlertIcon(_AlertItem alert) {
    if (alert.imageAsset != null) {
      return Container(
        width: 48,
        height: 48,
        padding: const EdgeInsets.all(5),
        decoration: const BoxDecoration(
          color: Color(0xFFEAF3FF),
          shape: BoxShape.circle,
        ),
        child: ClipOval(
          child: Image.asset(
            alert.imageAsset!,
            fit: BoxFit.cover,
          ),
        ),
      );
    }

    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: alert.iconBg,
        shape: BoxShape.circle,
      ),
      child: Icon(alert.icon, color: alert.iconColor, size: 22),
    );
  }

  // ─────────────────────────────────────────────────────────────

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment:
            MainAxisAlignment.center,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: AppColors.communityBg,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.notifications_off_outlined,
              size: 32,
              color: AppColors.primary,
            ),
          ),

          const SizedBox(height: 16),

          Text(
            'No alerts yet',
            style: GoogleFonts.inter(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppColors.textDark,
            ),
          ),

          const SizedBox(height: 6),

          Text(
            'Admin notices and nearby issues\nwill appear here.',
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

// ─────────────────────────────────────────────────────────────

class _AlertItem {
  final String id;
  final IconData icon;
  final Color iconColor;
  final Color iconBg;
  final String title;
  final String? body;
  final String timeAgo;
  final String? imageAsset;
  final bool isAdminNotice;
  final DateTime? createdAt;

  const _AlertItem({
    required this.id,
    required this.icon,
    required this.iconColor,
    required this.iconBg,
    required this.title,
    this.body,
    required this.timeAgo,
    this.imageAsset,
    this.isAdminNotice = false,
    this.createdAt,
  });
}
