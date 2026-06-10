import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/constants/app_colors.dart';

// ─────────────────────────────────────────────────────────────
// Filter
// ─────────────────────────────────────────────────────────────

enum _AlertFilter { all, updates, replies, system }

extension _AlertFilterLabel on _AlertFilter {
  String get label {
    switch (this) {
      case _AlertFilter.all:
        return 'All';
      case _AlertFilter.updates:
        return 'Updates';
      case _AlertFilter.replies:
        return 'Responses';
      case _AlertFilter.system:
        return 'System';
    }
  }
}

// ─────────────────────────────────────────────────────────────
// Alert Type
// ─────────────────────────────────────────────────────────────

enum _AlertType { update, reply, support, system }

extension _AlertTypeProps on _AlertType {
  String get label {
    switch (this) {
      case _AlertType.update:
        return 'Update';
      case _AlertType.reply:
        return 'Reply';
      case _AlertType.support:
        return 'Support';
      case _AlertType.system:
        return 'System';
    }
  }

  Color get color {
    switch (this) {
      case _AlertType.update:
        return const Color(0xFF1A54C4);
      case _AlertType.reply:
        return const Color(0xFFE65100);
      case _AlertType.support:
        return const Color(0xFF1A54C4);
      case _AlertType.system:
        return const Color(0xFF1A54C4);
    }
  }

  Color get bgColor {
    switch (this) {
      case _AlertType.update:
        return const Color(0xFFEEF3FF);
      case _AlertType.reply:
        return const Color(0xFFFFF3E0);
      case _AlertType.support:
        return const Color(0xFFEEF3FF);
      case _AlertType.system:
        return const Color(0xFFEEF3FF);
    }
  }

  IconData get icon {
    switch (this) {
      case _AlertType.update:
        return Icons.notifications_rounded;
      case _AlertType.reply:
        return Icons.chat_bubble_rounded;
      case _AlertType.support:
        return Icons.thumb_up_rounded;
      case _AlertType.system:
        return Icons.campaign_rounded;
    }
  }
}

// ─────────────────────────────────────────────────────────────
// Model
// ─────────────────────────────────────────────────────────────

class _AlertItem {
  final String id;
  final _AlertType type;
  final String title;
  final String? subtitle;
  final DateTime createdAt;
  final bool isRead;
  final String? thumbnailUrl;
  final bool isNew;

  // Legacy / explicit icon overrides (used by admin notices & nearby alerts)
  final IconData? icon;
  final Color? iconColor;
  final Color? iconBg;
  final String? imageAsset;

  const _AlertItem({
    required this.id,
    required this.type,
    required this.title,
    this.subtitle,
    required this.createdAt,
    this.isRead = false,
    this.thumbnailUrl,
    required this.isNew,
    this.icon,
    this.iconColor,
    this.iconBg,
    this.imageAsset,
  });
}

// ─────────────────────────────────────────────────────────────
// Screen
// ─────────────────────────────────────────────────────────────

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
  _AlertFilter _selectedFilter = _AlertFilter.all;
  final Set<String> _expandedIds = {};

  static const _kBlue     = Color(0xFF1A54C4);
  static const _kBlueBg   = Color(0xFFEEF3FF);
  static const _kPageBg   = Color(0xFFF5F6FA);
  static const _kWhite    = Colors.white;
  static const _kTextDark = Color(0xFF111827);

  @override
  void initState() {
    super.initState();
    _loadAlerts();
  }

  // ── Location ────────────────────────────────────────────────

  Future<void> _detectCurrentArea() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) throw Exception('Location services disabled');

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.deniedForever ||
        permission == LocationPermission.denied) {
      throw Exception('Location permission denied');
    }

    final position = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.best,
    );
    final placemarks =
        await placemarkFromCoordinates(position.latitude, position.longitude);

    if (placemarks.isNotEmpty) {
      final place = placemarks.first;
      _currentArea =
          place.subLocality?.trim() ?? place.locality?.trim() ?? '';
    }
  }

  // ── Data ────────────────────────────────────────────────────

  Future<void> _loadAlerts() async {
    try {
      if (mounted) setState(() => _isLoading = true);

      final List<_AlertItem> loaded = [];
      _blockedUserIds = await _loadBlockedUserIds();

      try {
        await _detectCurrentArea();
      } catch (e) {
        debugPrint('Location error: $e');
      }

      loaded.addAll(await _loadAdminNotifications());

      if (_currentArea.isNotEmpty) {
        final snapshot = await _postsRef.get();
        if (snapshot.exists && snapshot.value is Map) {
          final raw =
              Map<String, dynamic>.from(snapshot.value as Map);
          final now = DateTime.now();

          raw.forEach((key, value) {
            if (value is! Map) return;
            final post = Map<String, dynamic>.from(value);
            final String location =
                (post['location'] ?? '').toString().toLowerCase();
            final String category =
                (post['category'] ?? 'Issue').toString();
            final String ownerUid = (post['uid'] ?? '').toString();
            final String area = _currentArea.toLowerCase();

            if (_blockedUserIds.contains(ownerUid)) return;
            if (!(location.contains(area) || area.contains(location))) return;

            final String status =
                (post['status'] ?? '').toString().toLowerCase();
            if (post['resolved'] == true || status == 'resolved') return;

            final DateTime createdAt =
                _parseDateTime(post['timestamp']) ?? now;
            final bool isNew = now.difference(createdAt).inHours < 24;

            loaded.add(_AlertItem(
              id: key.toString(),
              type: _AlertType.update,
              title: '$category issue reported near ${post['location']}',
              subtitle: post['description']?.toString(),
              createdAt: createdAt,
              isNew: isNew,
              icon: _getCategoryIcon(category),
              iconColor: _getCategoryColor(category),
              iconBg: _getCategoryBg(category),
            ));
          });
        }
      }

      // System notices first, then by newest timestamp
      loaded.sort((a, b) {
        if (a.type == _AlertType.system && b.type != _AlertType.system) return -1;
        if (a.type != _AlertType.system && b.type == _AlertType.system) return 1;
        return b.createdAt.compareTo(a.createdAt);
      });

      if (mounted) {
        setState(() {
          _alerts = loaded;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading alerts: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<List<_AlertItem>> _loadAdminNotifications() async {
    final List<_AlertItem> notices = [];
    final snapshot = await _notificationsRef.get();
    if (!snapshot.exists || snapshot.value is! Map) return notices;

    final raw = Map<String, dynamic>.from(snapshot.value as Map);
    final now = DateTime.now();

    for (final entry in raw.entries) {
      if (entry.value is! Map) continue;
      final notification =
          Map<String, dynamic>.from(entry.value as Map);
      final String type = (notification['type'] ?? '').toString();
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
      final String? body = _firstText(
          notification, ['message', 'body', 'description', 'text']);
      final bool isNew =
          createdAt == null || now.difference(createdAt).inHours < 24;

      notices.add(_AlertItem(
        id: entry.key,
        type: _AlertType.system,
        title: title,
        subtitle: body,
        createdAt: createdAt ?? now,
        isNew: isNew,
        icon: Icons.campaign_rounded,
        iconColor: const Color(0xFF0052D4),
        iconBg: const Color(0xFFEAF3FF),
        imageAsset: 'assets/images/logo.jpeg',
      ));
    }

    return notices;
  }

  Future<Set<String>> _loadBlockedUserIds() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return {};
    final snapshot =
        await _usersRef.child(uid).child('blockedUsers').get();
    if (!snapshot.exists || snapshot.value is! Map) return {};
    final data = Map<String, dynamic>.from(snapshot.value as Map);
    return data.keys.toSet();
  }

  // ── Category helpers (from old version) ─────────────────────

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

  // ── Helpers ─────────────────────────────────────────────────

  DateTime? _parseDateTime(dynamic value) {
    if (value == null) return null;
    if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
    if (value is double) {
      return DateTime.fromMillisecondsSinceEpoch(value.round());
    }
    final String text = value.toString().trim();
    if (text.isEmpty) return null;
    final int? millis = int.tryParse(text);
    if (millis != null) return DateTime.fromMillisecondsSinceEpoch(millis);
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

  List<_AlertItem> get _filteredAlerts {
    if (_selectedFilter == _AlertFilter.all) return _alerts;
    return _alerts.where((a) {
      switch (_selectedFilter) {
        case _AlertFilter.updates:
          return a.type == _AlertType.update;
        case _AlertFilter.replies:
          return a.type == _AlertType.reply;
        case _AlertFilter.system:
          return a.type == _AlertType.system;
        default:
          return true;
      }
    }).toList();
  }

  // ── Build ────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kPageBg,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildTopBar(),
            _buildHeaderSection(),
            _buildFilterTabs(),
            Expanded(
              child: _isLoading
                  ? const Center(
                      child: CircularProgressIndicator(
                        color: _kBlue,
                        strokeWidth: 2.5,
                      ),
                    )
                  : _filteredAlerts.isEmpty
                      ? _buildEmptyState()
                      : _buildAlertsList(),
            ),
          ],
        ),
      ),
    );
  }

  // ── Top bar ──────────────────────────────────────────────────

  Widget _buildTopBar() {
    return Container(
      color: _kWhite,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.asset(
              'assets/images/logo.jpeg',
              width: 30,
              height: 30,
              fit: BoxFit.cover,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            'CityVoice',
            style: GoogleFonts.inter(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: _kBlue,
              letterSpacing: -0.4,
            ),
          ),
          const Spacer(),
          Container(
            width: 38,
            height: 38,
            decoration: const BoxDecoration(
              color: _kBlueBg,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.notifications_rounded,
              color: _kBlue,
              size: 20,
            ),
          ),
        ],
      ),
    );
  }

  // ── Header section ───────────────────────────────────────────

  Widget _buildHeaderSection() {
    return Container(
      color: _kWhite,
      padding: const EdgeInsets.fromLTRB(20, 6, 16, 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Alerts',
                  style: GoogleFonts.inter(
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF111827),
                    letterSpacing: -0.6,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _currentArea.isEmpty
                      ? 'Stay updated. Stay involved.'
                      : 'Issues and updates around $_currentArea',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: const Color(0xFF6B7280),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(
            width: 52,
            height: 40,
            child: Stack(
              clipBehavior: Clip.hardEdge,
              children: [
                Positioned(
                  left: 0,
                  bottom: 0,
                  child: Icon(
                    Icons.campaign_rounded,
                    size: 28,
                    color: _kBlue.withOpacity(0.18),
                  ),
                ),
                Positioned(
                  right: 0,
                  top: 0,
                  child: Icon(
                    Icons.campaign_rounded,
                    size: 20,
                    color: _kBlue.withOpacity(0.45),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Filter tabs ──────────────────────────────────────────────

  Widget _buildFilterTabs() {
    final filters = _AlertFilter.values;
    return Container(
      color: _kWhite,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
      child: Row(
        children: List.generate(filters.length, (i) {
          final filter = filters[i];
          final bool isSelected = _selectedFilter == filter;
          final bool isLast = i == filters.length - 1;
          return Expanded(
            child: Padding(
              padding: EdgeInsets.only(right: isLast ? 0 : 8),
              child: GestureDetector(
                onTap: () => setState(() => _selectedFilter = filter),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  curve: Curves.easeInOut,
                  height: 38,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: isSelected ? _kBlue : const Color(0xFFF0F4F8),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    filter.label,
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight:
                          isSelected ? FontWeight.w700 : FontWeight.w500,
                      color: isSelected ? _kWhite : const Color(0xFF6B7280),
                    ),
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  // ── Alerts list ──────────────────────────────────────────────
  // System (admin) notices are pinned at the top.
  // Nearby alerts follow, sorted newest first.

  Widget _buildAlertsList() {
    final systemAlerts = _filteredAlerts
        .where((a) => a.type == _AlertType.system)
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    final otherAlerts = _filteredAlerts
        .where((a) => a.type != _AlertType.system)
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    final bool hasBothSections =
        systemAlerts.isNotEmpty && otherAlerts.isNotEmpty;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
      children: [
        if (systemAlerts.isNotEmpty) ...[
          if (hasBothSections) ...[
            _buildSectionLabel('Notices'),
            const SizedBox(height: 10),
          ],
          ...systemAlerts.map(_buildAlertCard),
          if (hasBothSections) const SizedBox(height: 8),
        ],
        if (otherAlerts.isNotEmpty) ...[
          if (hasBothSections) ...[
            _buildSectionLabel('Nearby'),
            const SizedBox(height: 10),
          ],
          ...otherAlerts.map(_buildAlertCard),
        ],
      ],
    );
  }

  Widget _buildSectionLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Text(
        label,
        style: GoogleFonts.inter(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: const Color(0xFF6B7280),
          letterSpacing: 0.1,
        ),
      ),
    );
  }

  // ── Alert card ───────────────────────────────────────────────

  Widget _buildAlertCard(_AlertItem alert) {
    final bool isExpanded = _expandedIds.contains(alert.id);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeInOut,
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: _kWhite,
        borderRadius: BorderRadius.circular(16),
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
          onTap: () {
            setState(() {
              if (isExpanded) {
                _expandedIds.remove(alert.id);
              } else {
                _expandedIds.add(alert.id);
              }
            });
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 14,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Icon / avatar ──────────────────────────────
                _buildAlertIcon(alert),
                const SizedBox(width: 12),

                // ── Content ────────────────────────────────────
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Type label + time + chevron row
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          // If admin notice show pill badge
                          if (alert.type == _AlertType.system)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 3),
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
                            )
                          else
                            Text(
                              alert.type.label,
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: alert.iconColor ?? alert.type.color,
                              ),
                            ),
                          const SizedBox(width: 5),
                          Text(
                            '•',
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              color: const Color(0xFF9CA3AF),
                            ),
                          ),
                          const SizedBox(width: 5),
                          Expanded(
                            child: Text(
                              _timeAgo(alert.createdAt),
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                color: const Color(0xFF9CA3AF),
                              ),
                            ),
                          ),
                          // Chevron toggle
                          AnimatedRotation(
                            turns: isExpanded ? 0.5 : 0.0,
                            duration: const Duration(milliseconds: 220),
                            child: const Icon(
                              Icons.keyboard_arrow_down_rounded,
                              size: 20,
                              color: Color(0xFF9CA3AF),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 5),

                      // Title — always fully visible
                      Text(
                        alert.title,
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF111827),
                          height: 1.4,
                        ),
                        maxLines: isExpanded ? null : 2,
                        overflow: isExpanded
                            ? TextOverflow.visible
                            : TextOverflow.ellipsis,
                      ),

                      // Subtitle — collapsed: 1 line, expanded: full
                      if (alert.subtitle != null &&
                          alert.subtitle!.trim().isNotEmpty) ...[
                        const SizedBox(height: 4),
                        AnimatedCrossFade(
                          duration: const Duration(milliseconds: 220),
                          crossFadeState: isExpanded
                              ? CrossFadeState.showSecond
                              : CrossFadeState.showFirst,
                          firstChild: Text(
                            alert.subtitle!,
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              color: const Color(0xFF6B7280),
                              height: 1.4,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          secondChild: Text(
                            alert.subtitle!,
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              color: const Color(0xFF6B7280),
                              height: 1.55,
                            ),
                          ),
                        ),
                      ],

                      // "Tap to collapse" hint when expanded
                      if (isExpanded) ...[
                        const SizedBox(height: 10),
                        Text(
                          'Tap to collapse',
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            color: const Color(0xFFB0B8C1),
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ],
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

  /// Renders the left-side icon for a card.
  /// Priority: imageAsset → explicit iconColor/iconBg/icon → type defaults.
  Widget _buildAlertIcon(_AlertItem alert) {
    // Logo image (admin notices)
    if (alert.imageAsset != null) {
      return Container(
        width: 44,
        height: 44,
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: alert.iconBg ?? const Color(0xFFEAF3FF),
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

    // Explicit icon override (nearby category alerts)
    if (alert.icon != null) {
      return Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: alert.iconBg ?? alert.type.bgColor,
          shape: BoxShape.circle,
        ),
        child: Icon(
          alert.icon,
          color: alert.iconColor ?? alert.type.color,
          size: 20,
        ),
      );
    }

    // Default: fall back to _AlertType icon
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: alert.type.bgColor,
        shape: BoxShape.circle,
      ),
      child: Icon(
        alert.type.icon,
        color: alert.type.color,
        size: 20,
      ),
    );
  }

  // ── Empty state ──────────────────────────────────────────────

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: const BoxDecoration(
              color: _kBlueBg,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.notifications_off_outlined,
              size: 32,
              color: _kBlue,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'No alerts yet',
            style: GoogleFonts.inter(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF111827),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Updates, responses, and notices\nwill appear here.',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 13,
              color: const Color(0xFF6B7280),
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}