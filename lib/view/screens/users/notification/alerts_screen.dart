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

  List<_AlertItem> _alerts = [];

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
      await _detectCurrentArea();

      final snapshot = await _postsRef.get();

      List<_AlertItem> loadedAlerts = [];

      if (snapshot.exists) {
        final raw =
            Map<String, dynamic>.from(snapshot.value as Map);

        raw.forEach((key, value) {
          final post =
              Map<String, dynamic>.from(value);

          final String location =
              (post['location'] ?? '')
                  .toString()
                  .toLowerCase();

          final String category =
              (post['category'] ?? 'Issue')
                  .toString();

          final String area =
              _currentArea.toLowerCase();

          // Match nearby area
          if (location.contains(area) ||
              area.contains(location)) {
            loadedAlerts.add(
              _AlertItem(
                icon: _getCategoryIcon(category),
                iconColor:
                    _getCategoryColor(category),
                iconBg:
                    _getCategoryBg(category),
                title:
                    '$category issue reported near ${post['location']}',
                timeAgo: 'Nearby Area',
              ),
            );
          }
        });
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
        return const Color(0xFF4A7BE8);

      case 'garbage':
        return const Color(0xFF2ECC71);

      case 'electricity':
        return const Color(0xFFF39C12);

      case 'safety':
        return const Color(0xFF9B59B6);

      default:
        return const Color(0xFF1ABCCD);
    }
  }

  Color _getCategoryBg(String cat) {
    switch (cat.toLowerCase()) {
      case 'roads':
        return const Color(0xFFFFF0EE);

      case 'water':
        return const Color(0xFFEEF4FF);

      case 'garbage':
        return const Color(0xFFEEFBF4);

      case 'electricity':
        return const Color(0xFFFFFAEE);

      case 'safety':
        return const Color(0xFFF5EEFF);

      default:
        return const Color(0xFFEDF8FB);
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
                ? 'Fetching nearby issues...'
                : 'Issues around $_currentArea',
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

  Widget _buildAlertCard(
      _AlertItem alert,
      int index,
      ) {
    final bool isUnread = index < 2;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius:
            BorderRadius.circular(16),
        border: isUnread
            ? Border.all(
                color: AppColors.primary
                    .withOpacity(0.15),
              )
            : null,
        boxShadow: [
          BoxShadow(
            color:
                Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius:
            BorderRadius.circular(16),
        child: InkWell(
          borderRadius:
              BorderRadius.circular(16),
          onTap: () {},
          child: Padding(
            padding:
                const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 14,
            ),
            child: Row(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: alert.iconBg,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    alert.icon,
                    color: alert.iconColor,
                    size: 20,
                  ),
                ),

                const SizedBox(width: 14),

                Expanded(
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment:
                            CrossAxisAlignment
                                .start,
                        children: [
                          Expanded(
                            child: Text(
                              alert.title,
                              style:
                                  GoogleFonts.inter(
                                fontSize: 14,
                                fontWeight:
                                    isUnread
                                        ? FontWeight
                                            .w600
                                        : FontWeight
                                            .w400,
                                color:
                                    AppColors
                                        .textDark,
                                height: 1.45,
                              ),
                            ),
                          ),

                          if (isUnread) ...[
                            const SizedBox(
                                width: 8),

                            Container(
                              width: 8,
                              height: 8,
                              margin:
                                  const EdgeInsets
                                      .only(
                                top: 4,
                              ),
                              decoration:
                                  const BoxDecoration(
                                color: AppColors
                                    .primary,
                                shape: BoxShape
                                    .circle,
                              ),
                            ),
                          ],
                        ],
                      ),

                      const SizedBox(height: 4),

                      Text(
                        alert.timeAgo,
                        style:
                            GoogleFonts.inter(
                          fontSize: 12,
                          color: AppColors
                              .textLight,
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
            'No nearby alerts',
            style: GoogleFonts.inter(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppColors.textDark,
            ),
          ),

          const SizedBox(height: 6),

          Text(
            'No issues were found\nnear your location.',
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