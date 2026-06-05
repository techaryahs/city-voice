import 'dart:convert';
import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:mailer/mailer.dart' hide Location;
import 'package:mailer/smtp_server.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import '../../../../core/constants/app_colors.dart';

// ── Category model ────────────────────────────────────────────────────────────
class _Category {
  final String label;
  final IconData icon;
  final Color color;
  final Color bg;
  const _Category(this.label, this.icon, this.color, this.bg);
}

const _categories = [

  _Category(
    'Roads',
    Icons.construction_rounded,
    Color(0xFF0052D4),
    Color(0xFFEAF3FF),
  ),

  _Category(
    'Footpath',
    Icons.directions_walk_rounded,
    Color(0xFF1A73E8),
    Color(0xFFD7E9FF),
  ),

  _Category(
    'Public Toilets',
    Icons.wc_rounded,
    Color(0xFF3F8CFF),
    Color(0xFFEAF3FF),
  ),

  _Category(
    'Garbage',
    Icons.delete_outline_rounded,
    Color(0xFF0052D4),
    Color(0xFFEAF3FF),
  ),

  _Category(
    'Garden & Trees',
    Icons.park_rounded,
    Color(0xFF1A73E8),
    Color(0xFFD7E9FF),
  ),

  _Category(
    'Water',
    Icons.water_drop_outlined,
    Color(0xFF4A7BE8),
    Color(0xFFEEF4FF),
  ),

  _Category(
    'Street Lights',
    Icons.lightbulb_outline_rounded,
    Color(0xFF3F8CFF),
    Color(0xFFEAF3FF),
  ),

  _Category(
    'Other',
    Icons.more_horiz_rounded,
    Color(0xFF7F8C8D),
    Color(0xFFF4F4F4),
  ),
];

const _predictionApiUrl = 'https://city-voice.onrender.com/predict';

class _CivicIssuePrediction {
  final bool isCivicIssue;
  final String label;
  final double? confidence;
  final String? description;
  final Map<String, dynamic> rawResponse;

  const _CivicIssuePrediction({
    required this.isCivicIssue,
    required this.label,
    required this.confidence,
    required this.description,
    required this.rawResponse,
  });
}


// ── Main widget ───────────────────────────────────────────────────────────────

class RaiseVoicePage extends StatefulWidget {
  const RaiseVoicePage({super.key});

  @override
  State<RaiseVoicePage> createState() => _RaiseVoicePageState();
}

class _RaiseVoicePageState extends State<RaiseVoicePage> {
  final _descController     = TextEditingController();
  final _locationController = TextEditingController();

  File?   _image;
  _CivicIssuePrediction? _prediction;
  String? _predictionError;
  int     _selectedCategory = 0;
  bool    _isLoading        = false;
  bool    _isPredictingImage = false;
  bool    _isFetchingLocation = false;
  
  double? _exactLat;
  double? _exactLng;
  String? _fetchedAddress;

  // Firebase refs
  final _auth       = FirebaseAuth.instance;
  final _dbRef      = FirebaseDatabase.instance.ref('posts');
  final _usersRef   = FirebaseDatabase.instance.ref('users');
  final _storageRef = FirebaseStorage.instance.ref();

  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
  }

  Future<void> _getCurrentLocation() async {
    setState(() => _isFetchingLocation = true);
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return;

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
        return;
      }

      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      List<Placemark> placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );

      if (placemarks.isNotEmpty) {
        final place = placemarks.first;
        final parts = [place.subLocality, place.locality, place.administrativeArea]
            .where((p) => p != null && p!.isNotEmpty)
            .toList();
        
        final address = parts.join(', ');
        
        if (mounted) {
          setState(() {
            _exactLat = position.latitude;
            _exactLng = position.longitude;
            _fetchedAddress = address;
            _locationController.text = address;
          });
        }
      }
    } catch (e) {
      debugPrint('Error getting location: $e');
    } finally {
      if (mounted) setState(() => _isFetchingLocation = false);
    }
  }

  @override
  void dispose() {
    _descController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  // ── Pick image ──────────────────────────────────────────────────────────────

  Future<void> _pickImage(ImageSource source) async {
    final picked = await ImagePicker().pickImage(
      source: source,
      imageQuality: 75,
      maxWidth: 1200,
    );
    if (picked != null) {
      setState(() {
        _image = File(picked.path);
        _prediction = null;
        _predictionError = null;
      });
      await _verifySelectedImage();
    }
  }

  Future<_CivicIssuePrediction> _predictCivicIssue(File image) async {
    final request = http.MultipartRequest(
      'POST',
      Uri.parse(_predictionApiUrl),
    );

    request.files.add(await http.MultipartFile.fromPath('file', image.path));

    final streamedResponse = await request.send().timeout(
      const Duration(seconds: 45),
    );
    final response = await http.Response.fromStream(streamedResponse);

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Image verification failed (${response.statusCode})');
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! Map) {
      throw Exception('Image verification returned an invalid response');
    }

    final data = Map<String, dynamic>.from(decoded);
    final isCivicIssue = _readCivicIssueFlag(data);
    if (isCivicIssue == null) {
      throw Exception('Image verification returned an unexpected response');
    }

    return _CivicIssuePrediction(
      isCivicIssue: isCivicIssue,
      label: _readPredictionLabel(data),
      confidence: _readPredictionConfidence(data),
      description: _readPredictionDescription(data),
      rawResponse: data,
    );
  }

  bool? _readCivicIssueFlag(Map<String, dynamic> data) {
    const keys = [
      'is_civic_issue',
      'contains_civic_issue',
      'civic_issue',
      'is_civic',
      'is_issue',
      'valid',
      'result',
      'prediction',
      'label',
      'class',
      'category',
    ];

    for (final key in keys) {
      if (data.containsKey(key)) {
        final value = _parseCivicIssueValue(data[key]);
        if (value != null) return value;
      }
    }

    for (final value in data.values) {
      final parsed = _parseCivicIssueValue(value, parseNumbers: false);
      if (parsed != null) return parsed;
    }

    return null;
  }

  bool? _parseCivicIssueValue(dynamic value, {bool parseNumbers = true}) {
    if (value is bool) return value;
    if (value is num && parseNumbers) return value > 0;
    if (value is Map) {
      return _readCivicIssueFlag(Map<String, dynamic>.from(value));
    }

    final text = value?.toString().toLowerCase().trim();
    if (text == null || text.isEmpty) return null;

    const negativeSignals = [
      'not civic',
      'non civic',
      'non-civic',
      'non_civic',
      'no civic',
      'no_civic',
      'not an issue',
      'no issue',
      'no_issue',
      'irrelevant',
      'normal',
      'plain road',
      'plain_road',
      'clean road',
      'clean_road',
      'clean dustbin',
      'clean_dustbin',
      'working streetlight',
      'working_streetlight',
      'working street light',
      'working_street_light',
      'false',
      '0',
    ];
    if (negativeSignals.any(text.contains)) return false;

    const positiveSignals = [
      'civic issue',
      'civic',
      'issue',
      'pothole',
      'garbage',
      'water',
      'waterlogging',
      'water logging',
      'street light',
      'streetlight',
      'road',
      'crack',
      'damaged',
      'damage',
      'manhole',
      'tree',
      'footpath',
      'toilet',
      'drainage',
      'true',
      '1',
    ];
    if (positiveSignals.any(text.contains)) return true;

    return null;
  }

  String _readPredictionLabel(Map<String, dynamic> data) {
    for (final key in ['label', 'prediction', 'class', 'category', 'result']) {
      final value = data[key];
      if (value != null && value.toString().trim().isNotEmpty) {
        return value.toString();
      }
    }
    return 'unknown';
  }

  double? _readPredictionConfidence(Map<String, dynamic> data) {
    for (final key in ['confidence', 'score', 'probability']) {
      final value = data[key];
      if (value is num) return value.toDouble();
      if (value is String) return double.tryParse(value);
    }
    return null;
  }

  String? _readPredictionDescription(Map<String, dynamic> data) {
    for (final key in ['description', 'message', 'details']) {
      final value = data[key];
      if (value != null && value.toString().trim().isNotEmpty) {
        return value.toString();
      }
    }
    return null;
  }

  String _formatPredictionLabel(String label) {
    return label
        .replaceAll('_', ' ')
        .split(' ')
        .where((word) => word.isNotEmpty)
        .map((word) => '${word[0].toUpperCase()}${word.substring(1)}')
        .join(' ');
  }

  String _formatConfidence(double confidence) {
    final normalized = confidence <= 1 ? confidence * 100 : confidence;
    return '${normalized.toStringAsFixed(1)}%';
  }

  void _applyAiPredictionToForm(_CivicIssuePrediction prediction) {
    if (!prediction.isCivicIssue) return;

    final categoryIndex = _categoryIndexForPrediction(prediction);
    if (categoryIndex != null) {
      _selectedCategory = categoryIndex;
    }

    final description = prediction.description?.trim();
    if (description != null && description.isNotEmpty) {
      _descController.text = description;
    }
  }

  int? _categoryIndexForPrediction(_CivicIssuePrediction prediction) {
    if (!prediction.isCivicIssue) return null;

    final text = _predictionSearchText(prediction);

    if (_hasAny(text, [
      'streetlight',
      'street light',
      'light pole',
      'damaged light',
      'broken light',
      'not working light',
      'faulty light',
    ])) {
      return _indexOfCategory('Street Lights');
    }

    if (_hasAny(text, [
      'fallen tree',
      'fallen_tree',
      'tree fallen',
      'tree branch',
      'fallen branch',
      'tree',
      'garden',
    ])) {
      return _indexOfCategory('Garden & Trees');
    }

    if (_hasAny(text, [
      'waterlogging',
      'water logging',
      'water_logged',
      'waterlogged',
      'flood',
      'leakage',
      'water',
    ])) {
      return _indexOfCategory('Water');
    }

    if (_hasAny(text, [
      'footpath',
      'sidewalk',
      'pavement',
    ])) {
      return _indexOfCategory('Footpath');
    }

    if (_hasAny(text, [
      'public toilet',
      'public_toilet',
      'toilet',
      'wc',
    ])) {
      return _indexOfCategory('Public Toilets');
    }

    if (_hasAny(text, ['garbage'])) {
      return _indexOfCategory('Garbage');
    }

    if (_hasAny(text, [
      'pothole',
      'crack road',
      'road crack',
      'cracked road',
      'damage road',
      'damaged road',
      'road damage',
      'road damaged',
      'open manhole',
      'open_manhole',
      'manhole',
      'road',
    ])) {
      return _indexOfCategory('Roads');
    }

    return _indexOfCategory('Other');
  }

  String _predictionSearchText(_CivicIssuePrediction prediction) {
    return [
      prediction.label,
      prediction.description,
      prediction.rawResponse['prediction'],
      prediction.rawResponse['class'],
      prediction.rawResponse['category'],
    ]
        .whereType<Object>()
        .map((value) => value.toString().toLowerCase().replaceAll('_', ' '))
        .join(' ');
  }

  bool _hasAny(String text, List<String> keywords) {
    return keywords.any((keyword) => text.contains(keyword));
  }

  int? _indexOfCategory(String label) {
    final index = _categories.indexWhere((category) => category.label == label);
    return index == -1 ? null : index;
  }

  Future<void> _verifySelectedImage() async {
    final image = _image;
    if (image == null) return;

    setState(() {
      _isPredictingImage = true;
      _prediction = null;
      _predictionError = null;
    });

    try {
      final prediction = await _predictCivicIssue(image);
      if (!mounted) return;
      setState(() {
        _prediction = prediction;
        _applyAiPredictionToForm(prediction);
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _predictionError = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _isPredictingImage = false);
    }
  }

  Future<Location> _resolveLocationCoordinates(String location) async {
    final matches = await locationFromAddress(location);
    if (matches.isEmpty) {
      throw Exception('Could not find coordinates for this location');
    }
    return matches.first;
  }

  void _showImageOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        margin: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(20),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 8),
              Container(
                width: 36, height: 4,
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),
              _sheetOption(
                icon: Icons.camera_alt_outlined,
                label: 'Take a photo',
                onTap: () { Navigator.pop(context); _pickImage(ImageSource.camera); },
              ),
              _sheetOption(
                icon: Icons.photo_library_outlined,
                label: 'Choose from gallery',
                onTap: () { Navigator.pop(context); _pickImage(ImageSource.gallery); },
              ),
              if (_image != null)
                _sheetOption(
                  icon: Icons.delete_outline_rounded,
                  label: 'Remove photo',
                  color: const Color(0xFF0052D4),
                  onTap: () { Navigator.pop(context); setState(() => _image = null); },
                ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sheetOption({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    Color? color,
  }) {
    return ListTile(
      leading: Container(
        width: 40, height: 40,
        decoration: BoxDecoration(
          color: (color ?? AppColors.primary).withOpacity(0.1),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: color ?? AppColors.primary, size: 20),
      ),
      title: Text(
        label,
        style: GoogleFonts.inter(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          color: color ?? AppColors.textDark,
        ),
      ),
      onTap: onTap,
    );
  }

  // ── Upload & save post ──────────────────────────────────────────────────────

  Future<void> _sendEmailNotification(String posterName, String category, String location, String desc) async {
    const String username = 'cityvoiceofficial@gmail.com';
    // Use the 16-character app password (stripped trailing dot if any)
    const String password = 'nzrdrnffjaojwpxg';

    final smtpServer = gmail(username, password);

    final message = Message()
      ..from = const Address(username, 'CityVoice App')
      ..recipients.add(username)
      ..subject = 'New Voice Raised: $category at $location'
      ..text = 'A new voice has been raised by $posterName.\n\nCategory: $category\nLocation: $location\nDescription:\n$desc';

    try {
      await send(message, smtpServer);
    } catch (e) {
      debugPrint('Error sending email: $e');
    }
  }

  Future<void> _uploadPost() async {
    final desc     = _descController.text.trim();
    final location = _locationController.text.trim();

    if (desc.isEmpty) {
      _showSnack('Please describe the issue 📝');
      return;
    }
    if (location.isEmpty) {
      _showSnack('Please add a location 📍');
      return;
    }

    if (_image == null) {
      _showSnack('Please add a photo so we can verify the issue');
      return;
    }
    if (_isPredictingImage) {
      _showSnack('Please wait while we verify the photo');
      return;
    }
    if (_predictionError != null) {
      _showSnack(_predictionError!);
      return;
    }
    if (_prediction != null && !_prediction!.isCivicIssue) {
      _showSnack('This photo does not look like a civic issue');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception('Not logged in');

      final prediction = _prediction ?? await _predictCivicIssue(_image!);
      if (!prediction.isCivicIssue) {
        _showSnack('This photo does not look like a civic issue');
        return;
      }

      // ── 1. Fetch poster's name from DB ───────────────────────────────────
      String posterName = 'Anonymous';
      bool isPrivateProfile = false;

      final userSnap = await _usersRef.child(user.uid).get();

      if (userSnap.exists) {
        final data = Map<String, dynamic>.from(userSnap.value as Map);

        if (data['isBlocked'] == true || data['blocked'] == true) {
          throw Exception('Your account is blocked. You can only view posts.');
        }

        isPrivateProfile = (data['isPrivateProfile'] ?? false) == true;

        if (!isPrivateProfile) {
          posterName = (data['name'] ?? 'Anonymous').toString();
        }
      }

      // ── 2. Upload image (optional) ───────────────────────────────────────
      String? imageUrl;
      if (_image != null) {
        final fileName = '${user.uid}_${DateTime.now().millisecondsSinceEpoch}';
        final ref = _storageRef.child('posts/$fileName.jpg');
        final task = await ref.putFile(_image!);
        imageUrl = await task.ref.getDownloadURL();
      }

      // ── 2.5 Geocode location ────────────────────────────────────────────
      double? lat = _exactLat;
      double? lng = _exactLng;
      if (lat == null || lng == null) {
        final resolvedLocation = await _resolveLocationCoordinates(location);
        lat = resolvedLocation.latitude;
        lng = resolvedLocation.longitude;
        //throw Exception("Unable to fetch precise GPS location");
      }

      // ── 3. Save post to Realtime Database ────────────────────────────────
      await _dbRef.push().set({
        'uid':         user.uid,
        'name':        posterName,
        'isAnonymous': isPrivateProfile,
        'description': desc,
        'location':    location,
        'latitude':    lat,
        'longitude':   lng,
        'category':    _categories[_selectedCategory].label,
        'image_url':   imageUrl ?? '',
        'ai_prediction': prediction.label,
        'ai_prediction_response': prediction.rawResponse,
        'timestamp':   DateTime.now().toIso8601String(),
        'supports':    0,
        'replies':     0,
      });

      // ── Send Email ───────────────────────────────────────────────────────
      final actualName = (userSnap.value as Map)['name'] ?? 'Unknown';
      await _sendEmailNotification(
        actualName.toString(),
        _categories[_selectedCategory].label,
        location,
        desc,
      );

      // ── 4. Success ───────────────────────────────────────────────────────
      if (!mounted) return;
      _showSuccessSheet();
    } catch (e) {
      _showSnack('Error: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showSuccessSheet() {
    showModalBottomSheet(
      context: context,
      isDismissible: false,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.all(28),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72, height: 72,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [Color(0xFF0052D4), Color(0xFF0D6EFD), Color(0xFF3F8CFF)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: const Icon(Icons.check_rounded, color: Colors.white, size: 36),
            ),
            const SizedBox(height: 20),
            Text(
              'Voice Raised! 🎉',
              style: GoogleFonts.inter(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: AppColors.textDark,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Your issue has been posted.\nThe community will support you.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 14,
                color: AppColors.textMedium,
                height: 1.6,
              ),
            ),
            const SizedBox(height: 28),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(100),
                  gradient: const LinearGradient(
                    colors: [Color(0xFF0052D4), Color(0xFF0D6EFD), Color(0xFF3F8CFF)],
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                  ),
                ),
                child: TextButton(
                  onPressed: () {
                    Navigator.pop(context); // close sheet
                    Navigator.pop(context); // go back to Voices
                  },
                  child: Text(
                    'Back to Voices',
                    style: GoogleFonts.inter(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: GoogleFonts.inter()),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  // ── UI ──────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            _buildTopBar(),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 24),
                    _buildSectionLabel('Category'),
                    const SizedBox(height: 12),
                    _buildCategoryPicker(),
                    const SizedBox(height: 24),
                    _buildSectionLabel('Describe the issue'),

                    const SizedBox(height: 6),

                    Text(
                      'Please post only relevant civic or community issues. Unnecessary or fake voices are not allowed.',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: const Color(0xFF0052D4),
                        height: 1.5,
                        fontWeight: FontWeight.w500,
                      ),
                    ),

                    const SizedBox(height: 10),

                    _buildDescriptionField(),
                    const SizedBox(height: 24),
                    _buildSectionLabel('Add a photo'),
                    const SizedBox(height: 10),
                    _buildImagePicker(),
                    if (_image != null) ...[
                      const SizedBox(height: 12),
                      _buildPredictionPanel(),
                    ],
                    const SizedBox(height: 24),
                    _buildSectionLabel('Location'),
                    const SizedBox(height: 10),
                    _buildLocationField(),
                    const SizedBox(height: 36),
                    _buildSubmitButton(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Top bar ─────────────────────────────────────────────────────────────────

  Widget _buildTopBar() {
    return Container(
      color: AppColors.white,
      padding: const EdgeInsets.fromLTRB(8, 12, 20, 12),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
            color: AppColors.textDark,
          ),
          Expanded(
            child: Text(
              'Raise a Voice',
              style: GoogleFonts.inter(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: AppColors.textDark,
                letterSpacing: -0.3,
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.communityBg,
              borderRadius: BorderRadius.circular(100),
            ),
            child: Row(
              children: [
                Icon(Icons.campaign_rounded, size: 14, color: AppColors.primary),
                const SizedBox(width: 5),
                Text(
                  'Community',
                  style: GoogleFonts.inter(
                    fontSize: 12,
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

  // ── Section label ────────────────────────────────────────────────────────────

  Widget _buildSectionLabel(String text) {
    return Text(
      text,
      style: GoogleFonts.inter(
        fontSize: 13,
        fontWeight: FontWeight.w700,
        color: AppColors.textDark,
        letterSpacing: 0.2,
      ),
    );
  }

  // ── Category picker ──────────────────────────────────────────────────────────

  Widget _buildCategoryPicker() {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: List.generate(_categories.length, (i) {

        final cat = _categories[i];
        final isActive = _selectedCategory == i;

        return GestureDetector(
          onTap: () {
            setState(() => _selectedCategory = i);
          },

          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),

            padding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 10,
            ),

            decoration: BoxDecoration(
              color: isActive ? cat.color : Colors.white,

              borderRadius: BorderRadius.circular(14),

              border: Border.all(
                color: isActive
                    ? cat.color
                    : Colors.black.withOpacity(0.06),
              ),

              boxShadow: [
                BoxShadow(
                  color: isActive
                      ? cat.color.withOpacity(0.20)
                      : Colors.black.withOpacity(0.03),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
            ),

            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [

                Icon(
                  cat.icon,
                  size: 16,
                  color: isActive
                      ? Colors.white
                      : cat.color,
                ),

                const SizedBox(width: 6),

                Text(
                  cat.label,
                  style: GoogleFonts.inter(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: isActive
                        ? Colors.white
                        : AppColors.textDark,
                  ),
                ),
              ],
            ),
          ),
        );
      }),
    );
  }

  // ── Description field ────────────────────────────────────────────────────────

  Widget _buildDescriptionField() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 2)),
        ],
      ),
      child: TextField(
        controller: _descController,
        maxLines: 4,
        maxLength: 300,
        style: GoogleFonts.inter(fontSize: 15, color: AppColors.textDark),
        decoration: InputDecoration(
          hintText: "What's the issue? Describe clearly so the community can understand and support...",
          hintStyle: GoogleFonts.inter(fontSize: 14, color: AppColors.textLight, height: 1.5),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.all(16),
          counterStyle: GoogleFonts.inter(fontSize: 11, color: AppColors.textLight),
        ),
      ),
    );
  }

  // ── Image picker ─────────────────────────────────────────────────────────────

  Widget _buildImagePicker() {
    return GestureDetector(
      onTap: _showImageOptions,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        height: _image != null ? 200 : 110,
        width: double.infinity,
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: _image != null ? AppColors.primary.withOpacity(0.3) : Colors.black.withOpacity(0.08),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 2)),
          ],
        ),
        child: _image == null
            ? Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 48, height: 48,
                    decoration: const BoxDecoration(
                      color: AppColors.communityBg,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.add_a_photo_outlined, color: AppColors.primary, size: 22),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Tap to add a photo',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textMedium,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    'Camera or Gallery',
                    style: GoogleFonts.inter(fontSize: 11, color: AppColors.textLight),
                  ),
                ],
              )
            : Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(15),
                    child: Image.file(_image!, width: double.infinity, height: 200, fit: BoxFit.cover),
                  ),
                  Positioned(
                    top: 8, right: 8,
                    child: GestureDetector(
                      onTap: _showImageOptions,
                      child: Container(
                        width: 32, height: 32,
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.55),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.edit_rounded, color: Colors.white, size: 16),
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  // ── Location field ───────────────────────────────────────────────────────────

    Widget _buildPredictionPanel() {
    final prediction = _prediction;
    final isRejected = prediction != null && !prediction.isCivicIssue;
    final accent = isRejected ? Colors.redAccent : AppColors.primary;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: accent.withOpacity(0.18)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: _isPredictingImage
          ? Row(
              children: [
                const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2.2),
                ),
                const SizedBox(width: 10),
                Text(
                  'Checking photo...',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textMedium,
                  ),
                ),
              ],
            )
          : _predictionError != null
              ? Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.error_outline_rounded, color: Colors.redAccent, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _predictionError!,
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Colors.redAccent,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                )
              : prediction == null
                  ? const SizedBox.shrink()
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              isRejected
                                  ? Icons.warning_amber_rounded
                                  : Icons.verified_rounded,
                              color: accent,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'AI Check',
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                                color: AppColors.textDark,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        _predictionRow(
                          'Prediction',
                          _formatPredictionLabel(prediction.label),
                        ),
                        if (prediction.confidence != null)
                          _predictionRow(
                            'Confidence',
                            _formatConfidence(prediction.confidence!),
                          ),
                        if (prediction.description != null)
                          _predictionRow('Description', prediction.description!),
                      ],
                    ),
    );
  }

  Widget _predictionRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 86,
            child: Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppColors.textLight,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppColors.textDark,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLocationField() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 2)),
        ],
      ),
      child: TextField(
        controller: _locationController,
        style: GoogleFonts.inter(fontSize: 15, color: AppColors.textDark),
        decoration: InputDecoration(
          hintText: 'e.g. Shivaji Nagar, Pune',
          hintStyle: GoogleFonts.inter(fontSize: 14, color: AppColors.textLight),
          prefixIcon: const Icon(Icons.location_on_outlined, color: AppColors.primary, size: 20),
          suffixIcon: IconButton(
            icon: _isFetchingLocation 
                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.my_location_rounded, color: AppColors.primary, size: 20),
            onPressed: _isFetchingLocation ? null : _getCurrentLocation,
            tooltip: 'Use current location',
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        ),
      ),
    );
  }

  // ── Submit button ────────────────────────────────────────────────────────────

  Widget _buildSubmitButton() {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(100),
          gradient: _isLoading
              ? const LinearGradient(colors: [Color(0xFFCCCCCC), Color(0xFFBBBBBB)])
              : const LinearGradient(
                  colors: [Color(0xFF0052D4), Color(0xFF0D6EFD), Color(0xFF3F8CFF)],
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                ),
          boxShadow: _isLoading
              ? []
              : [
                  BoxShadow(
                    color: AppColors.primary.withOpacity(0.4),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
        ),
        child: TextButton(
          onPressed: _isLoading ? null : _uploadPost,
          style: TextButton.styleFrom(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(100)),
          ),
          child: _isLoading
              ? const SizedBox(
                  width: 22, height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                )
              : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.campaign_rounded, color: Colors.white, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      'Raise Voice',
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}
