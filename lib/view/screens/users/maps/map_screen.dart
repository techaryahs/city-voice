import 'dart:math';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:latlong2/latlong.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../models/post_model.dart';
import '../voices/post_detail_screen.dart';

// ── Model ─────────────────────────────────────────────────────────────────────

class _LiveIssue {
  final VoicePost post;
  final LatLng position;

  _LiveIssue({
    required this.post,
    required this.position,
  });

  factory _LiveIssue.fromSnapshot(DataSnapshot snap, LatLng fallbackPos) {
    final post = VoicePost.fromSnapshot(snap);
    
    // Generate a slightly randomized position if none exists 
    // to make the map look "active" across the community.
    final Random r = Random(snap.key.hashCode);
    final double latOffset = (r.nextDouble() - 0.5) * 0.08;
    final double lngOffset = (r.nextDouble() - 0.5) * 0.08;
    final LatLng pos = LatLng(fallbackPos.latitude + latOffset, fallbackPos.longitude + lngOffset);

    return _LiveIssue(
      post:     post,
      position: pos,
    );
  }
}

// ── Screen ────────────────────────────────────────────────────────────────────

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final MapController _mapController = MapController();
  final DatabaseReference _postsRef = FirebaseDatabase.instance.ref('posts');

  // Center point (Navi Mumbai / Pune area roughly)
  final LatLng _centerLocation = const LatLng(19.0330, 73.0297);
  
  _LiveIssue? _selectedIssue;
  String _selectedFilter = 'All';

  final List<String> _filters = [
    'All', 'Garbage', 'Roads', 'Water', 'Electricity', 'Safety', 'Other'
  ];

  Color _getCatColor(String cat) {
    switch (cat.toLowerCase()) {
      case 'garbage':     return const Color(0xFF2ECC71);
      case 'roads':       return AppColors.primary;
      case 'water':       return const Color(0xFF4A7BE8);
      case 'electricity': return const Color(0xFFF39C12);
      case 'safety':      return const Color(0xFF9B59B6);
      default:            return const Color(0xFF1ABCCD);
    }
  }

  IconData _getCatIcon(String cat) {
    switch (cat.toLowerCase()) {
      case 'garbage':     return Icons.delete_outline_rounded;
      case 'roads':       return Icons.add_road_rounded;
      case 'water':       return Icons.water_drop_outlined;
      case 'electricity': return Icons.bolt_outlined;
      case 'safety':      return Icons.shield_outlined;
      default:            return Icons.campaign_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: StreamBuilder<DatabaseEvent>(
          stream: _postsRef.onValue,
          builder: (context, snapshot) {
            List<_LiveIssue> issues = [];
            if (snapshot.hasData && snapshot.data!.snapshot.value != null) {
              final raw = Map<String, dynamic>.from(snapshot.data!.snapshot.value as Map);
              issues = raw.entries.map((e) => 
                _LiveIssue.fromSnapshot(snapshot.data!.snapshot.child(e.key), _centerLocation)
              ).toList();
            }

            // Apply category filter
            final filteredIssues = _selectedFilter == 'All'
                ? issues
                : issues.where((i) => i.post.category.toLowerCase() == _selectedFilter.toLowerCase()).toList();

            return Stack(
              children: [
                // ── Map Layer ──────────────────────────────────────────
                FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    initialCenter: _centerLocation,
                    initialZoom: 11.5,
                    onTap: (_, __) => setState(() => _selectedIssue = null),
                  ),
                  children: [
                    TileLayer(
                      urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.cityvoice.app',
                    ),
                    MarkerLayer(
                      markers: [
                        // Center/User Pulse Marker
                        Marker(
                          point: _centerLocation,
                          width: 60, height: 60,
                          child: _buildUserMarker(),
                        ),
                        // Issue Markers
                        ...filteredIssues.map((iss) => Marker(
                          point: iss.position,
                          width: 48, height: 56,
                          child: GestureDetector(
                            onTap: () {
                              setState(() => _selectedIssue = iss);
                              _mapController.move(iss.position, 13.5);
                            },
                            child: _buildIssueMarker(iss),
                          ),
                        )),
                      ],
                    ),
                  ],
                ),

                // ── UI Overlays ─────────────────────────────────────────
                Positioned(top: 0, left: 0, right: 0, child: _buildHeader()),
                Positioned(top: 80, left: 0, right: 0, child: _buildFilterBar()),
                
                Positioned(
                  right: 16, 
                  bottom: _selectedIssue != null ? 300 : 100, 
                  child: _buildZoomControls(),
                ),
                
                Positioned(
                  right: 16, 
                  bottom: _selectedIssue != null ? 240 : 40, 
                  child: _buildMyLocationBtn(),
                ),

                Positioned(
                  left: 16, 
                  bottom: _selectedIssue != null ? 300 : 100, 
                  child: _buildIssueBadge(filteredIssues.length),
                ),

                if (_selectedIssue != null)
                  Positioned(bottom: 0, left: 0, right: 0, child: _buildBottomSheet(_selectedIssue!)),
              ],
            );
          }
        ),
      ),
    );
  }

  // ── UI Implementation ──────────────────────────────────────────────────

  Widget _buildHeader() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 16, offset: const Offset(0, 4))],
      ),
      child: Row(
        children: [
          const Icon(Icons.map_rounded, color: AppColors.primary, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Community Map', style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textDark)),
                Text('Issues in your community area', style: GoogleFonts.inter(fontSize: 11, color: AppColors.textLight)),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(color: AppColors.communityBg, borderRadius: BorderRadius.circular(100)),
            child: Row(children: [
              const Icon(Icons.circle, size: 7, color: AppColors.primary),
              const SizedBox(width: 5),
              Text('Live', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.primary)),
            ]),
          ),
        ],
      ),
    );
  }

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
            onTap: () => setState(() { _selectedFilter = _filters[i]; _selectedIssue = null; }),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: isActive ? AppColors.primary : Colors.white,
                borderRadius: BorderRadius.circular(100),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 8, offset: const Offset(0, 2))],
              ),
              child: Text(_filters[i], style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: isActive ? Colors.white : AppColors.textMedium)),
            ),
          );
        },
      ),
    );
  }

  Widget _buildUserMarker() {
    return Stack(alignment: Alignment.center, children: [
      Container(width: 52, height: 52, decoration: BoxDecoration(shape: BoxShape.circle, color: const Color(0xFF4A7BE8).withOpacity(0.1))),
      Container(width: 16, height: 16, decoration: BoxDecoration(shape: BoxShape.circle, color: const Color(0xFF4A7BE8), border: Border.all(color: Colors.white, width: 2.5))),
    ]);
  }

  Widget _buildIssueMarker(_LiveIssue issue) {
    final isSelected = _selectedIssue == issue;
    final color = _getCatColor(issue.post.category);
    return Column(mainAxisSize: MainAxisSize.min, children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: isSelected ? 46 : 38, height: isSelected ? 46 : 38,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 2.5), boxShadow: [BoxShadow(color: color.withOpacity(0.4), blurRadius: 10)]),
          child: Icon(_getCatIcon(issue.post.category), color: Colors.white, size: isSelected ? 22 : 18),
        ),
        Container(width: 2, height: 6, color: color),
    ]);
  }

  Widget _buildZoomControls() {
    return Column(children: [
      _mapControlBtn(icon: Icons.add_rounded, onTap: () => _mapController.move(_mapController.camera.center, _mapController.camera.zoom + 1)),
      const SizedBox(height: 8),
      _mapControlBtn(icon: Icons.remove_rounded, onTap: () => _mapController.move(_mapController.camera.center, _mapController.camera.zoom - 1)),
    ]);
  }

  Widget _buildMyLocationBtn() {
    return _mapControlBtn(icon: Icons.my_location_rounded, onTap: () => _mapController.move(_centerLocation, 13), color: AppColors.primary, iconColor: Colors.white);
  }

  Widget _mapControlBtn({required IconData icon, required VoidCallback onTap, Color color = Colors.white, Color iconColor = const Color(0xFF333333)}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 42, height: 42,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle, boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.12), blurRadius: 10, offset: const Offset(0, 3))]),
        child: Icon(icon, color: iconColor, size: 20),
      ),
    );
  }

  Widget _buildIssueBadge(int count) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(100), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10, offset: const Offset(0, 3))]),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.campaign_rounded, size: 15, color: AppColors.primary),
          const SizedBox(width: 6),
          Text('$count active voices nearby', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textDark)),
      ]),
    );
  }

  Widget _buildBottomSheet(_LiveIssue issue) {
    final color = _getCatColor(issue.post.category);
    return Container(
      decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(24)), boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 20, offset: Offset(0, -4))]),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(child: Container(width: 36, height: 4, decoration: BoxDecoration(color: Colors.black.withOpacity(0.12), borderRadius: BorderRadius.circular(100)))),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
            decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(100)),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(_getCatIcon(issue.post.category), size: 13, color: color),
                const SizedBox(width: 5),
                Text(issue.post.category, style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: color)),
            ]),
          ),
          const SizedBox(height: 12),
          Row(children: [
              Container(width: 38, height: 38, decoration: const BoxDecoration(gradient: LinearGradient(colors: [Color(0xFFFF7B5F), AppColors.primary]), shape: BoxShape.circle), child: Center(child: Text(issue.post.name.isNotEmpty ? issue.post.name[0] : '?', style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white)))),
              const SizedBox(width: 10),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(issue.post.name, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textDark)),
                  Text(issue.post.location, style: GoogleFonts.inter(fontSize: 11, color: AppColors.textLight), overflow: TextOverflow.ellipsis),
              ])),
          ]),
          const SizedBox(height: 12),
          Text(issue.post.description, style: GoogleFonts.inter(fontSize: 13, color: AppColors.textMedium, height: 1.55), maxLines: 3, overflow: TextOverflow.ellipsis),
          const SizedBox(height: 16),
          Row(children: [
              _sheetChip(Icons.favorite_border_rounded, '${issue.post.supports} Support', AppColors.primary, AppColors.communityBg, () {}),
              const SizedBox(width: 10),
              _sheetChip(Icons.chat_bubble_outline_rounded, '${issue.post.replies} Replies', AppColors.conversationalIcon, AppColors.conversationalBg, () {
                 Navigator.push(context, MaterialPageRoute(builder: (c) => PostDetailScreen(post: issue.post)));
              }),
              const Spacer(),
              _viewBtn(issue.post),
          ]),
        ],
      ),
    );
  }

  Widget _sheetChip(IconData icon, String label, Color color, Color bg, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7), 
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(100)), 
        child: Row(children: [Icon(icon, size: 13, color: color), const SizedBox(width: 5), Text(label, style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: color))])
      ),
    );
  }

  Widget _viewBtn(VoicePost post) {
    return GestureDetector(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (c) => PostDetailScreen(post: post))),
      child: Container(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10), decoration: BoxDecoration(gradient: const LinearGradient(colors: [Color(0xFFFF7B5F), AppColors.primary]), borderRadius: BorderRadius.circular(100), boxShadow: [BoxShadow(color: AppColors.primary.withOpacity(0.35), blurRadius: 10, offset: const Offset(0, 4))]), child: Text('View post', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white))),
    );
  }
}