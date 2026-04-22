import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:latlong2/latlong.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../sample_data/voices_data.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final MapController _mapController = MapController();

  // User's current location (Navi Mumbai)
  final LatLng _userLocation = const LatLng(19.0330, 73.0297);

  // Issue markers mapped from dummy posts
  final List<_IssueMarker> _issues = [
    _IssueMarker(
      post: dummyVoicePosts[0],
      position: const LatLng(19.0215, 73.0490),
      category: 'Water',
      color: Color(0xFF4A7BE8),
      icon: Icons.water_drop_rounded,
    ),
    _IssueMarker(
      post: dummyVoicePosts[1],
      position: const LatLng(19.0450, 73.0680),
      category: 'Electricity',
      color: Color(0xFFE8C14A),
      icon: Icons.bolt_rounded,
    ),
    _IssueMarker(
      post: dummyVoicePosts[2],
      position: const LatLng(18.9894, 73.1175),
      category: 'Sanitation',
      color: Color(0xFF2ECC71),
      icon: Icons.delete_rounded,
    ),
    _IssueMarker(
      post: dummyVoicePosts[3],
      position: const LatLng(19.0760, 73.0050),
      category: 'Roads',
      color: Color(0xFFE8614A),
      icon: Icons.add_road_rounded,
    ),
    _IssueMarker(
      post: dummyVoicePosts[4],
      position: const LatLng(19.1490, 73.0150),
      category: 'Noise',
      color: Color(0xFFAA4AE8),
      icon: Icons.volume_up_rounded,
    ),
  ];

  _IssueMarker? _selectedIssue;
  String _selectedFilter = 'All';

  final List<String> _filters = [
    'All', 'Water', 'Electricity', 'Sanitation', 'Roads', 'Noise'
  ];

  List<_IssueMarker> get _filteredIssues => _selectedFilter == 'All'
      ? _issues
      : _issues.where((i) => i.category == _selectedFilter).toList();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Stack(
          children: [
            // ── Map ──────────────────────────────────────────────────
            FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: _userLocation,
                initialZoom: 11.5,
                onTap: (_, __) => setState(() => _selectedIssue = null),
              ),
              children: [
                // Tile layer
                TileLayer(
                  urlTemplate:
                  'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.cityvoice.app',
                ),

                // Issue markers
                MarkerLayer(
                  markers: [
                    // User location marker
                    Marker(
                      point: _userLocation,
                      width: 60,
                      height: 60,
                      child: _buildUserMarker(),
                    ),
                    // Issue markers
                    ..._filteredIssues.map((issue) => Marker(
                      point: issue.position,
                      width: 48,
                      height: 56,
                      child: GestureDetector(
                        onTap: () {
                          setState(() => _selectedIssue = issue);
                          _mapController.move(issue.position, 13.5);
                        },
                        child: _buildIssueMarker(issue),
                      ),
                    )),
                  ],
                ),
              ],
            ),

            // ── Header ───────────────────────────────────────────────
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: _buildHeader(),
            ),

            // ── Filter chips ─────────────────────────────────────────
            Positioned(
              top: 80,
              left: 0,
              right: 0,
              child: _buildFilterBar(),
            ),

            // ── Zoom controls ─────────────────────────────────────────
            Positioned(
              right: 16,
              bottom: _selectedIssue != null ? 300 : 100,
              child: _buildZoomControls(),
            ),

            // ── My location button ────────────────────────────────────
            Positioned(
              right: 16,
              bottom: _selectedIssue != null ? 240 : 40,
              child: _buildMyLocationBtn(),
            ),

            // ── Issue count badge ─────────────────────────────────────
            Positioned(
              left: 16,
              bottom: _selectedIssue != null ? 300 : 100,
              child: _buildIssueBadge(),
            ),

            // ── Bottom sheet ──────────────────────────────────────────
            if (_selectedIssue != null)
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: _buildBottomSheet(_selectedIssue!),
              ),
          ],
        ),
      ),
    );
  }

  // ── Header ────────────────────────────────────────────────────────────

  Widget _buildHeader() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(Icons.map_rounded, color: AppColors.primary, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Community Map',
                  style: GoogleFonts.inter(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textDark,
                  ),
                ),
                Text(
                  'Issues near Navi Mumbai',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    color: AppColors.textLight,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: AppColors.communityBg,
              borderRadius: BorderRadius.circular(100),
            ),
            child: Row(
              children: [
                Icon(Icons.circle, size: 7, color: AppColors.primary),
                const SizedBox(width: 5),
                Text(
                  'Live',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Filter Bar ────────────────────────────────────────────────────────

  Widget _buildFilterBar() {
    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: _filters.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final isActive = _selectedFilter == _filters[i];
          return GestureDetector(
            onTap: () => setState(() {
              _selectedFilter = _filters[i];
              _selectedIssue = null;
            }),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: isActive ? AppColors.primary : Colors.white,
                borderRadius: BorderRadius.circular(100),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.08),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Text(
                _filters[i],
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: isActive ? Colors.white : AppColors.textMedium,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // ── Markers ───────────────────────────────────────────────────────────

  Widget _buildUserMarker() {
    return Stack(
      alignment: Alignment.center,
      children: [
        // Pulse ring
        Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: const Color(0xFF4A7BE8).withOpacity(0.15),
          ),
        ),
        // Inner ring
        Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: const Color(0xFF4A7BE8).withOpacity(0.25),
          ),
        ),
        // Dot
        Container(
          width: 16,
          height: 16,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: const Color(0xFF4A7BE8),
            border: Border.all(color: Colors.white, width: 2.5),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF4A7BE8).withOpacity(0.5),
                blurRadius: 8,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildIssueMarker(_IssueMarker issue) {
    final isSelected = _selectedIssue == issue;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: isSelected ? 46 : 38,
          height: isSelected ? 46 : 38,
          decoration: BoxDecoration(
            color: issue.color,
            shape: BoxShape.circle,
            border: Border.all(
              color: Colors.white,
              width: isSelected ? 3 : 2,
            ),
            boxShadow: [
              BoxShadow(
                color: issue.color.withOpacity(0.5),
                blurRadius: isSelected ? 16 : 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Icon(issue.icon, color: Colors.white,
              size: isSelected ? 22 : 18),
        ),
        // Pin tail
        Container(
          width: 2,
          height: 8,
          color: issue.color,
        ),
      ],
    );
  }

  // ── Controls ──────────────────────────────────────────────────────────

  Widget _buildZoomControls() {
    return Column(
      children: [
        _mapControlBtn(
          icon: Icons.add_rounded,
          onTap: () {
            final zoom = _mapController.camera.zoom;
            _mapController.move(_mapController.camera.center, zoom + 1);
          },
        ),
        const SizedBox(height: 8),
        _mapControlBtn(
          icon: Icons.remove_rounded,
          onTap: () {
            final zoom = _mapController.camera.zoom;
            _mapController.move(_mapController.camera.center, zoom - 1);
          },
        ),
      ],
    );
  }

  Widget _buildMyLocationBtn() {
    return _mapControlBtn(
      icon: Icons.my_location_rounded,
      onTap: () => _mapController.move(_userLocation, 13),
      color: AppColors.primary,
      iconColor: Colors.white,
    );
  }

  Widget _mapControlBtn({
    required IconData icon,
    required VoidCallback onTap,
    Color color = Colors.white,
    Color iconColor = const Color(0xFF333333),
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.12),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Icon(icon, color: iconColor, size: 20),
      ),
    );
  }

  Widget _buildIssueBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(100),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.campaign_rounded, size: 15, color: AppColors.primary),
          const SizedBox(width: 6),
          Text(
            '${_filteredIssues.length} issue${_filteredIssues.length == 1 ? '' : 's'} nearby',
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.textDark,
            ),
          ),
        ],
      ),
    );
  }

  // ── Bottom Sheet ──────────────────────────────────────────────────────

  Widget _buildBottomSheet(_IssueMarker issue) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: Colors.black26,
            blurRadius: 20,
            offset: Offset(0, -4),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Handle
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.12),
                borderRadius: BorderRadius.circular(100),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Category chip
          Container(
            padding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
            decoration: BoxDecoration(
              color: issue.color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(100),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(issue.icon, size: 13, color: issue.color),
                const SizedBox(width: 5),
                Text(
                  issue.category,
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: issue.color,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // Author row
          Row(
            children: [
              // Avatar
              Container(
                width: 38,
                height: 38,
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
                    issue.post.name[0],
                    style: GoogleFonts.inter(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      issue.post.name,
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textDark,
                      ),
                    ),
                    Row(
                      children: [
                        Icon(Icons.location_on_outlined,
                            size: 11, color: AppColors.textLight),
                        const SizedBox(width: 2),
                        Expanded(
                          child: Text(
                            '${issue.post.location} • ${issue.post.timeAgo}',
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
            ],
          ),

          const SizedBox(height: 12),

          // Description
          Text(
            issue.post.description,
            style: GoogleFonts.inter(
              fontSize: 13,
              color: AppColors.textMedium,
              height: 1.55,
            ),
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),

          const SizedBox(height: 16),

          // Action row
          Row(
            children: [
              // Support chip
              _sheetActionChip(
                icon: Icons.favorite_border_rounded,
                label: '${issue.post.supports} Support',
                color: AppColors.primary,
                bg: AppColors.communityBg,
              ),
              const SizedBox(width: 10),
              _sheetActionChip(
                icon: Icons.chat_bubble_outline_rounded,
                label: '${issue.post.replies} Replies',
                color: AppColors.conversationalIcon,
                bg: AppColors.conversationalBg,
              ),
              const Spacer(),
              // View button
              GestureDetector(
                onTap: () {},
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFFF7B5F), AppColors.primary],
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                    ),
                    borderRadius: BorderRadius.circular(100),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withOpacity(0.35),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Text(
                    'View post',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _sheetActionChip({
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
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Data class ────────────────────────────────────────────────────────────

class _IssueMarker {
  final VoicePost post;
  final LatLng position;
  final String category;
  final Color color;
  final IconData icon;

  const _IssueMarker({
    required this.post,
    required this.position,
    required this.category,
    required this.color,
    required this.icon,
  });
}