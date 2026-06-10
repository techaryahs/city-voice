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
  _Category('Roads',         Icons.add_road_rounded,          Color(0xFF1A54C4), Color(0xFFEEF3FF)),
  _Category('Street Lights', Icons.lightbulb_outline_rounded, Color(0xFF1A54C4), Color(0xFFEEF3FF)),
  _Category('Garbage',       Icons.delete_outline_rounded,    Color(0xFF1A54C4), Color(0xFFEEF3FF)),
  _Category('Water',         Icons.water_drop_outlined,       Color(0xFF1A54C4), Color(0xFFEEF3FF)),
  _Category('Garden & Trees',Icons.park_rounded,              Color(0xFF1A54C4), Color(0xFFEEF3FF)),
  _Category('Footpath',      Icons.directions_walk_rounded,   Color(0xFF1A54C4), Color(0xFFEEF3FF)),
  _Category('Public Toilets',Icons.wc_rounded,                Color(0xFF1A54C4), Color(0xFFEEF3FF)),
  _Category('Other',         Icons.more_horiz_rounded,        Color(0xFF1A54C4), Color(0xFFEEF3FF)),
];

const _predictionApiUrl = 'https://city-voice.onrender.com/predict';

// ── Prediction model ──────────────────────────────────────────────────────────

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

class _RaiseVoicePageState extends State<RaiseVoicePage>
    with SingleTickerProviderStateMixin {
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

  // ── Animation ──────────────────────────────────────────────────────────────
  late final AnimationController _pulseController;
  late final Animation<double>   _pulseAnim;
  late final Animation<double>   _shimmerAnim;
  bool _wasReady = false;

  final _auth       = FirebaseAuth.instance;
  final _dbRef      = FirebaseDatabase.instance.ref('posts');
  final _usersRef   = FirebaseDatabase.instance.ref('users');
  final _storageRef = FirebaseStorage.instance.ref();

  static const _kBlue      = Color(0xFF1A54C4);
  static const _kBlueBg    = Color(0xFFEEF3FF);
  static const _kPageBg    = Color(0xFFF5F6FA);
  static const _kTextDark  = Color(0xFF111827);
  static const _kTextGrey  = Color(0xFF6B7280);
  static const _kBorder    = Color(0xFFE5E7EB);
  static const _kWhite     = Colors.white;

  // Returns true when the minimum required fields are all filled
  bool get _isFormReady =>
      _image != null &&
      !_isPredictingImage &&
      _predictionError == null &&
      (_prediction == null || _prediction!.isCivicIssue) &&
      _descController.text.trim().isNotEmpty &&
      _locationController.text.trim().isNotEmpty;

  @override
  void initState() {
    super.initState();
    _getCurrentLocation();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );

    _pulseAnim = Tween<double>(begin: 1.0, end: 1.035).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _shimmerAnim = Tween<double>(begin: -1.5, end: 2.5).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    // Listen to text fields to re-evaluate form readiness
    _descController.addListener(_onFormChanged);
    _locationController.addListener(_onFormChanged);
  }

  void _onFormChanged() {
    final ready = _isFormReady;
    if (ready != _wasReady) {
      _wasReady = ready;
      if (ready) {
        _pulseController.repeat(reverse: true);
      } else {
        _pulseController.stop();
        _pulseController.reset();
      }
      setState(() {});
    }
  }

  // ── Location ────────────────────────────────────────────────────────────────

  Future<void> _getCurrentLocation() async {
    setState(() => _isFetchingLocation = true);
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return;

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) return;

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      final placemarks = await placemarkFromCoordinates(
        position.latitude, position.longitude,
      );

      if (placemarks.isNotEmpty && mounted) {
        final place = placemarks.first;
        final parts = [place.subLocality, place.locality, place.administrativeArea]
            .where((p) => p != null && p!.isNotEmpty)
            .toList();
        setState(() {
          _exactLat = position.latitude;
          _exactLng = position.longitude;
          _fetchedAddress = parts.join(', ');
          _locationController.text = _fetchedAddress!;
        });
      }
    } catch (e) {
      debugPrint('Location error: $e');
    } finally {
      if (mounted) setState(() => _isFetchingLocation = false);
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _descController.removeListener(_onFormChanged);
    _locationController.removeListener(_onFormChanged);
    _descController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  // ── Image & AI prediction ───────────────────────────────────────────────────

  Future<void> _pickImage(ImageSource source) async {
    final picked = await ImagePicker().pickImage(
      source: source, imageQuality: 75, maxWidth: 1200,
    );
    if (picked != null) {
      setState(() {
        _image = File(picked.path);
        _prediction = null;
        _predictionError = null;
      });
      _onFormChanged();
      await _verifySelectedImage();
    }
  }

  Future<_CivicIssuePrediction> _predictCivicIssue(File image) async {
    final request = http.MultipartRequest('POST', Uri.parse(_predictionApiUrl));
    request.files.add(await http.MultipartFile.fromPath('file', image.path));
    final streamed  = await request.send().timeout(const Duration(seconds: 45));
    final response  = await http.Response.fromStream(streamed);

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Image verification failed (${response.statusCode})');
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! Map) throw Exception('Image verification returned an invalid response');

    final data        = Map<String, dynamic>.from(decoded);
    final isCivicIssue = _readCivicIssueFlag(data);
    if (isCivicIssue == null) throw Exception('Image verification returned an unexpected response');

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
      'is_civic_issue','contains_civic_issue','civic_issue','is_civic',
      'is_issue','valid','result','prediction','label','class','category',
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
    if (value is Map) return _readCivicIssueFlag(Map<String, dynamic>.from(value));

    final text = value?.toString().toLowerCase().trim();
    if (text == null || text.isEmpty) return null;

    const neg = [
      'not civic','non civic','non-civic','non_civic','no civic','no_civic',
      'not an issue','no issue','no_issue','irrelevant','normal','plain road',
      'plain_road','clean road','clean_road','clean dustbin','clean_dustbin',
      'working streetlight','working_streetlight','working street light',
      'working_street_light','false','0',
    ];
    if (neg.any(text.contains)) return false;

    const pos = [
      'civic issue','civic','issue','pothole','garbage','water','waterlogging',
      'water logging','street light','streetlight','road','crack','damaged',
      'damage','manhole','tree','footpath','toilet','drainage','true','1',
    ];
    if (pos.any(text.contains)) return true;

    return null;
  }

  String _readPredictionLabel(Map<String, dynamic> data) {
    for (final key in ['label','prediction','class','category','result']) {
      final v = data[key];
      if (v != null && v.toString().trim().isNotEmpty) return v.toString();
    }
    return 'unknown';
  }

  double? _readPredictionConfidence(Map<String, dynamic> data) {
    for (final key in ['confidence','score','probability']) {
      final v = data[key];
      if (v is num) return v.toDouble();
      if (v is String) return double.tryParse(v);
    }
    return null;
  }

  String? _readPredictionDescription(Map<String, dynamic> data) {
    for (final key in ['description','message','details']) {
      final v = data[key];
      if (v != null && v.toString().trim().isNotEmpty) return v.toString();
    }
    return null;
  }

  String _formatPredictionLabel(String label) {
    return label.replaceAll('_',' ').split(' ')
        .where((w) => w.isNotEmpty)
        .map((w) => '${w[0].toUpperCase()}${w.substring(1)}')
        .join(' ');
  }

  String _formatConfidence(double confidence) {
    final n = confidence <= 1 ? confidence * 100 : confidence;
    return '${n.toStringAsFixed(1)}%';
  }

  void _applyAiPredictionToForm(_CivicIssuePrediction p) {
    if (!p.isCivicIssue) return;
    final idx = _categoryIndexForPrediction(p);
    if (idx != null) setState(() => _selectedCategory = idx);
    final desc = p.description?.trim();
    if (desc != null && desc.isNotEmpty) _descController.text = desc;
  }

  int? _categoryIndexForPrediction(_CivicIssuePrediction p) {
    if (!p.isCivicIssue) return null;
    final text = [p.label, p.description, p.rawResponse['prediction'],
        p.rawResponse['class'], p.rawResponse['category']]
        .whereType<Object>()
        .map((v) => v.toString().toLowerCase().replaceAll('_',' '))
        .join(' ');

    bool has(List<String> kws) => kws.any(text.contains);
    int? idx(String lbl) {
      final i = _categories.indexWhere((c) => c.label == lbl);
      return i == -1 ? null : i;
    }

    if (has(['streetlight','street light','light pole','damaged light','broken light'])) return idx('Street Lights');
    if (has(['fallen tree','tree branch','fallen branch','tree','garden'])) return idx('Garden & Trees');
    if (has(['waterlogging','water logging','waterlogged','flood','leakage','water'])) return idx('Water');
    if (has(['footpath','sidewalk','pavement'])) return idx('Footpath');
    if (has(['public toilet','toilet','wc'])) return idx('Public Toilets');
    if (has(['garbage'])) return idx('Garbage');
    if (has(['pothole','crack road','road crack','cracked road','damaged road','manhole','road'])) return idx('Roads');
    return idx('Other');
  }

  Future<void> _verifySelectedImage() async {
    final image = _image;
    if (image == null) return;
    setState(() { _isPredictingImage = true; _prediction = null; _predictionError = null; });
    try {
      final prediction = await _predictCivicIssue(image);
      if (!mounted) return;
      setState(() { _prediction = prediction; _applyAiPredictionToForm(prediction); });
      _onFormChanged();
    } catch (e) {
      if (!mounted) return;
      setState(() => _predictionError = e.toString().replaceFirst('Exception: ', ''));
      _onFormChanged();
    } finally {
      if (mounted) setState(() => _isPredictingImage = false);
    }
  }

  Future<Location> _resolveLocationCoordinates(String location) async {
    final matches = await locationFromAddress(location);
    if (matches.isEmpty) throw Exception('Could not find coordinates for this location');
    return matches.first;
  }

  // ── Bottom sheet: image options ─────────────────────────────────────────────

  void _showImageOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        margin: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: _kWhite, borderRadius: BorderRadius.circular(20)),
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
              _sheetOption(icon: Icons.camera_alt_outlined, label: 'Take a photo',
                  onTap: () { Navigator.pop(context); _pickImage(ImageSource.camera); }),
              _sheetOption(icon: Icons.photo_library_outlined, label: 'Choose from gallery',
                  onTap: () { Navigator.pop(context); _pickImage(ImageSource.gallery); }),
              if (_image != null)
                _sheetOption(icon: Icons.delete_outline_rounded, label: 'Remove photo',
                    color: Colors.redAccent,
                    onTap: () { Navigator.pop(context); setState(() => _image = null); }),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sheetOption({required IconData icon, required String label,
      required VoidCallback onTap, Color? color}) {
    return ListTile(
      leading: Container(
        width: 40, height: 40,
        decoration: BoxDecoration(
          color: (color ?? _kBlue).withOpacity(0.1), shape: BoxShape.circle,
        ),
        child: Icon(icon, color: color ?? _kBlue, size: 20),
      ),
      title: Text(label, style: GoogleFonts.inter(
        fontSize: 15, fontWeight: FontWeight.w600, color: color ?? _kTextDark,
      )),
      onTap: onTap,
    );
  }

  // ── Upload & save ───────────────────────────────────────────────────────────

  Future<void> _sendEmailNotification(
      String posterName, String category, String location, String desc) async {
    const username = 'cityvoiceofficial@gmail.com';
    const password = 'nzrdrnffjaojwpxg';
    final smtpServer = gmail(username, password);
    final message = Message()
      ..from = const Address(username, 'CityVoice App')
      ..recipients.add(username)
      ..subject = 'New Voice Raised: $category at $location'
      ..text = 'A new voice has been raised by $posterName.\n\n'
          'Category: $category\nLocation: $location\nDescription:\n$desc';
    try {
      await send(message, smtpServer);
    } catch (e) {
      debugPrint('Email error: $e');
    }
  }

  Future<void> _uploadPost() async {
    final desc     = _descController.text.trim();
    final location = _locationController.text.trim();

    if (_image == null)         { _showSnack('Please add a photo so we can verify the issue'); return; }
    if (_isPredictingImage)     { _showSnack('Please wait while we verify the photo'); return; }
    if (desc.isEmpty)           { _showSnack('Please describe the issue'); return; }
    if (location.isEmpty)       { _showSnack('Please add a location'); return; }
    if (_predictionError != null) { _showSnack(_predictionError!); return; }
    if (_prediction != null && !_prediction!.isCivicIssue) {
      _showSnack('This photo does not look like a civic issue'); return;
    }

    setState(() => _isLoading = true);
    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception('Not logged in');

      final prediction = _prediction ?? await _predictCivicIssue(_image!);
      if (!prediction.isCivicIssue) {
        _showSnack('This photo does not look like a civic issue'); return;
      }

      String posterName      = 'Anonymous';
      bool   isPrivateProfile = false;

      final userSnap = await _usersRef.child(user.uid).get();
      if (userSnap.exists) {
        final data = Map<String, dynamic>.from(userSnap.value as Map);
        if (data['isBlocked'] == true || data['blocked'] == true) {
          throw Exception('Your account is blocked. You can only view posts.');
        }
        isPrivateProfile = (data['isPrivateProfile'] ?? false) == true;
        if (!isPrivateProfile) posterName = (data['name'] ?? 'Anonymous').toString();
      }

      String? imageUrl;
      if (_image != null) {
        final fileName = '${user.uid}_${DateTime.now().millisecondsSinceEpoch}';
        final ref  = _storageRef.child('posts/$fileName.jpg');
        final task = await ref.putFile(_image!);
        imageUrl   = await task.ref.getDownloadURL();
      }

      double? lat = _exactLat;
      double? lng = _exactLng;
      if (lat == null || lng == null) {
        final resolved = await _resolveLocationCoordinates(location);
        lat = resolved.latitude;
        lng = resolved.longitude;
      }

      await _dbRef.push().set({
        'uid':                   user.uid,
        'name':                  posterName,
        'isAnonymous':           isPrivateProfile,
        'description':           desc,
        'location':              location,
        'latitude':              lat,
        'longitude':             lng,
        'category':              _categories[_selectedCategory].label,
        'image_url':             imageUrl ?? '',
        'ai_prediction':         prediction.label,
        'ai_prediction_response': prediction.rawResponse,
        'timestamp':             DateTime.now().toIso8601String(),
        'supports':              0,
        'replies':               0,
      });

      final actualName = (userSnap.value as Map)['name'] ?? 'Unknown';
      await _sendEmailNotification(
        actualName.toString(), _categories[_selectedCategory].label, location, desc,
      );

      if (!mounted) return;
      _showSuccessSheet();
    } catch (e) {
      _showSnack('Error: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ── Success sheet ───────────────────────────────────────────────────────────

  void _showSuccessSheet() {
    showModalBottomSheet(
      context: context,
      isDismissible: false,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.all(28),
        decoration: BoxDecoration(color: _kWhite, borderRadius: BorderRadius.circular(24)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72, height: 72,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Color(0xFF1A54C4),
              ),
              child: const Icon(Icons.check_rounded, color: Colors.white, size: 36),
            ),
            const SizedBox(height: 20),
            Text('Voice Raised! 🎉', style: GoogleFonts.inter(
              fontSize: 22, fontWeight: FontWeight.w800, color: _kTextDark,
            )),
            const SizedBox(height: 10),
            Text(
              'Your issue has been posted.\nThe community will support you.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(fontSize: 14, color: _kTextGrey, height: 1.6),
            ),
            const SizedBox(height: 28),
            SizedBox(
              width: double.infinity, height: 52,
              child: ElevatedButton(
                onPressed: () { Navigator.pop(context); Navigator.pop(context); },
                style: ElevatedButton.styleFrom(
                  backgroundColor: _kBlue,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(100)),
                  elevation: 0,
                ),
                child: Text('Back to Voices', style: GoogleFonts.inter(
                  fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white,
                )),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: GoogleFonts.inter()),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ));
  }

  // ── BUILD ───────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kPageBg,
      body: SafeArea(
        child: Column(
          children: [
            _buildTopBar(),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Hero banner ──────────────────────────────────────
                    _buildHeroBanner(),
                    const SizedBox(height: 24),

                    // ── Page title ───────────────────────────────────────
                    Text('Raise Your Voice', style: GoogleFonts.inter(
                      fontSize: 22, fontWeight: FontWeight.w800, color: _kTextDark,
                      letterSpacing: -0.4,
                    )),
                    const SizedBox(height: 4),
                    Text('Report issues, support others and create real change.',
                      style: GoogleFonts.inter(fontSize: 13, color: _kTextGrey, height: 1.5)),
                    const SizedBox(height: 28),

                    // ── Step 1 · Photo ───────────────────────────────────
                    _buildStepHeader(1, 'Add Photo / Video', 'A clear photo helps authorities understand the issue better.'),
                    const SizedBox(height: 12),
                    _buildPhotoSection(),

                    const SizedBox(height: 28),

                    // ── Step 2 · Category ────────────────────────────────
                    _buildStepHeader(2, 'Select Issue Type', 'Choose the category that best describes the issue.'),
                    const SizedBox(height: 12),
                    _buildCategoryGrid(),

                    const SizedBox(height: 28),

                    // ── Step 3 · Location ────────────────────────────────
                    _buildStepHeader(3, 'Location', 'We will detect your location automatically.'),
                    const SizedBox(height: 12),
                    _buildLocationCard(),

                    const SizedBox(height: 28),

                    // ── Step 4 · Description ─────────────────────────────
                    _buildStepHeader(4, 'Describe the Issue', 'Provide a short description about the issue.'),
                    const SizedBox(height: 12),
                    _buildDescriptionField(),

                    const SizedBox(height: 24),

                    // ── Trust badge ──────────────────────────────────────
                    _buildTrustBadge(),

                    const SizedBox(height: 24),

                    // ── Submit ───────────────────────────────────────────
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
      color: _kWhite,
      padding: const EdgeInsets.fromLTRB(4, 10, 16, 10),
      child: Row(
        children: [
          // Back button
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
            color: _kTextDark,
          ),

          // CityVoice logo + wordmark — centred
          Expanded(
            child: Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.asset(
                      'assets/images/logo.jpeg',
                      width: 32,
                      height: 32,
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
                ],
              ),
            ),
          ),         
        ],
      ),
    );
  }

  // ── Hero banner ─────────────────────────────────────────────────────────────

  Widget _buildHeroBanner() {
    return Container(
      margin: const EdgeInsets.only(top: 18),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF8EE),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFFD080), width: 1),
      ),
      child: Row(
        children: [
          Container(
            width: 40, height: 40,
            decoration: BoxDecoration(
              color: const Color(0xFFFFF0CC),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.warning_amber_rounded,
                color: Color(0xFFF5A623), size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('See something wrong?', style: GoogleFonts.inter(
                  fontSize: 14, fontWeight: FontWeight.w700,
                  color: const Color(0xFFD48A00),
                )),
                const SizedBox(height: 2),
                Text('Raise your voice and help make our city better.',
                  style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF996600), height: 1.4)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Step header ─────────────────────────────────────────────────────────────

  Widget _buildStepHeader(int step, String title, String subtitle) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 28, height: 28,
          decoration: const BoxDecoration(color: _kBlue, shape: BoxShape.circle),
          child: Center(
            child: Text('$step', style: GoogleFonts.inter(
              fontSize: 13, fontWeight: FontWeight.w700, color: Colors.white,
            )),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(title, style: GoogleFonts.inter(
                    fontSize: 15, fontWeight: FontWeight.w700, color: _kTextDark,
                  )),
                  const SizedBox(width: 4),
                  const Text('*', style: TextStyle(color: Colors.red, fontSize: 14, fontWeight: FontWeight.bold)),
                ],
              ),
              const SizedBox(height: 2),
              Text(subtitle, style: GoogleFonts.inter(fontSize: 12, color: _kTextGrey, height: 1.4)),
            ],
          ),
        ),
      ],
    );
  }

  // ── Photo section ────────────────────────────────────────────────────────────

  Widget _buildPhotoSection() {
    return Column(
      children: [
        GestureDetector(
          onTap: _showImageOptions,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            height: _image != null ? 200 : 100,
            width: double.infinity,
            decoration: BoxDecoration(
              color: _kWhite,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: _image != null ? _kBlue.withOpacity(0.4) : _kBorder,
                width: 1.5,
                style: _image != null ? BorderStyle.solid : BorderStyle.solid,
              ),
            ),
            child: _image == null
                ? Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 52, height: 52,
                        decoration: const BoxDecoration(color: _kBlueBg, shape: BoxShape.circle),
                        child: const Icon(Icons.camera_alt_outlined, color: _kBlue, size: 24),
                      ),
                      const SizedBox(width: 14),
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Tap to upload', style: GoogleFonts.inter(
                            fontSize: 14, fontWeight: FontWeight.w600, color: _kTextDark,
                          )),
                          Text('or take a photo', style: GoogleFonts.inter(
                            fontSize: 13, color: _kTextGrey,
                          )),
                        ],
                      ),
                      const Spacer(),
                      Padding(
                        padding: const EdgeInsets.only(right: 16),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: _kBlueBg,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.photo_library_outlined, size: 14, color: _kBlue),
                              const SizedBox(width: 4),
                              Text('Gallery', style: GoogleFonts.inter(
                                fontSize: 12, fontWeight: FontWeight.w600, color: _kBlue,
                              )),
                            ],
                          ),
                        ),
                      ),
                    ],
                  )
                : Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(13),
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
        ),
        if (_image != null) ...[
          const SizedBox(height: 10),
          _buildPredictionPanel(),
        ],
      ],
    );
  }

  // ── AI Prediction panel ──────────────────────────────────────────────────────

  Widget _buildPredictionPanel() {
    final prediction = _prediction;
    final isRejected = prediction != null && !prediction.isCivicIssue;

    if (_isPredictingImage) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: _kBlueBg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _kBlue.withOpacity(0.2)),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 16, height: 16,
              child: CircularProgressIndicator(strokeWidth: 2, color: _kBlue),
            ),
            const SizedBox(width: 10),
            Text('Verifying photo with AI…', style: GoogleFonts.inter(
              fontSize: 13, fontWeight: FontWeight.w500, color: _kBlue,
            )),
          ],
        ),
      );
    }

    if (_predictionError != null) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFFFFF0F0),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.redAccent.withOpacity(0.25)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.error_outline_rounded, color: Colors.redAccent, size: 18),
            const SizedBox(width: 8),
            Expanded(child: Text(_predictionError!, style: GoogleFonts.inter(
              fontSize: 13, color: Colors.redAccent, height: 1.4,
            ))),
          ],
        ),
      );
    }

    if (prediction == null) return const SizedBox.shrink();

    final accent = isRejected ? Colors.redAccent : _kBlue;
    final bgColor = isRejected ? const Color(0xFFFFF0F0) : _kBlueBg;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: accent.withOpacity(0.22)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isRejected ? Icons.warning_amber_rounded : Icons.verified_rounded,
                color: accent, size: 18,
              ),
              const SizedBox(width: 6),
              Text('AI Verification', style: GoogleFonts.inter(
                fontSize: 13, fontWeight: FontWeight.w700, color: _kTextDark,
              )),
            ],
          ),
          const SizedBox(height: 10),
          _predictionRow('Prediction', _formatPredictionLabel(prediction.label)),
          if (prediction.confidence != null)
            _predictionRow('Confidence', _formatConfidence(prediction.confidence!)),
          if (prediction.description != null)
            _predictionRow('Details', prediction.description!),
        ],
      ),
    );
  }

  Widget _predictionRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(label, style: GoogleFonts.inter(
              fontSize: 12, fontWeight: FontWeight.w600, color: _kTextGrey,
            )),
          ),
          Expanded(child: Text(value, style: GoogleFonts.inter(
            fontSize: 13, fontWeight: FontWeight.w600, color: _kTextDark, height: 1.35,
          ))),
        ],
      ),
    );
  }

  // ── Category grid ────────────────────────────────────────────────────────────

  Widget _buildCategoryGrid() {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: 0.85,
      ),
      itemCount: _categories.length,
      itemBuilder: (_, i) {
        final cat      = _categories[i];
        final isActive = _selectedCategory == i;

        return GestureDetector(
          onTap: () => setState(() => _selectedCategory = i),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            decoration: BoxDecoration(
              color: isActive ? cat.color : _kWhite,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isActive ? cat.color : _kBorder,
                width: isActive ? 1.5 : 1,
              ),
              boxShadow: isActive
                  ? [BoxShadow(color: cat.color.withOpacity(0.22), blurRadius: 8, offset: const Offset(0, 3))]
                  : [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 4, offset: const Offset(0, 1))],
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 38, height: 38,
                  decoration: BoxDecoration(
                    color: isActive ? Colors.white.withOpacity(0.22) : cat.bg,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(cat.icon, size: 20, color: isActive ? Colors.white : cat.color),
                ),
                const SizedBox(height: 6),
                Text(
                  cat.label,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: isActive ? Colors.white : _kTextDark,
                    height: 1.25,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ── Location card ─────────────────────────────────────────────────────────────

  Widget _buildLocationCard() {
    return Container(
      decoration: BoxDecoration(
        color: _kWhite,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _kBorder),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
            child: Row(
              children: [
                Container(
                  width: 34, height: 34,
                  decoration: const BoxDecoration(color: _kBlueBg, shape: BoxShape.circle),
                  child: const Icon(Icons.location_on_rounded, color: _kBlue, size: 18),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _locationController,
                    style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: _kTextDark),
                    decoration: InputDecoration(
                      hintText: 'e.g. Shivaji Nagar, Pune',
                      hintStyle: GoogleFonts.inter(fontSize: 14, color: _kTextGrey),
                      isDense: true,
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                ),
                GestureDetector(
                  onTap: _isFetchingLocation ? null : _getCurrentLocation,
                  child: Text(
                    _isFetchingLocation ? 'Detecting…' : 'Change',
                    style: GoogleFonts.inter(
                      fontSize: 13, fontWeight: FontWeight.w600, color: _kBlue,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Container(height: 1, color: _kBorder),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 8, 14, 8),
            child: Row(
              children: [
                Icon(Icons.public_rounded, size: 13, color: _kTextGrey),
                const SizedBox(width: 5),
                Text('Location will be visible to public',
                  style: GoogleFonts.inter(fontSize: 11.5, color: _kTextGrey)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Description field ────────────────────────────────────────────────────────

  Widget _buildDescriptionField() {
    return Container(
      decoration: BoxDecoration(
        color: _kWhite,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _kBorder),
      ),
      child: TextField(
        controller: _descController,
        maxLines: 4,
        maxLength: 300,
        style: GoogleFonts.inter(fontSize: 14, color: _kTextDark),
        decoration: InputDecoration(
          hintText: "E.g. Open manhole without cover near the school gate. It's dangerous…",
          hintStyle: GoogleFonts.inter(fontSize: 13, color: _kTextGrey, height: 1.5),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.all(14),
          counterStyle: GoogleFonts.inter(fontSize: 11, color: _kTextGrey),
        ),
      ),
    );
  }

  // ── Trust badge ───────────────────────────────────────────────────────────────

  Widget _buildTrustBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: _kBlueBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _kBlue.withOpacity(0.15)),
      ),
      child: Row(
        children: [
          Container(
            width: 30, height: 30,
            decoration: const BoxDecoration(color: _kBlue, shape: BoxShape.circle),
            child: const Icon(Icons.shield_rounded, color: Colors.white, size: 16),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Your voice is important. All reports are reviewed by our team.',
              style: GoogleFonts.inter(fontSize: 12.5, color: _kBlue, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }

  // ── Submit button ─────────────────────────────────────────────────────────────

  Widget _buildSubmitButton() {
    final ready = _isFormReady && !_isLoading;

    return AnimatedBuilder(
      animation: _pulseController,
      builder: (context, child) {
        final scale  = ready ? _pulseAnim.value : 1.0;
        final shimmerPos = ready ? _shimmerAnim.value : -1.5;

        return Transform.scale(
          scale: scale,
          child: GestureDetector(
            onTap: _isLoading ? null : _uploadPost,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 350),
              curve: Curves.easeOutCubic,
              width: double.infinity,
              height: 54,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                color: ready ? _kBlue : const Color(0xFFB0BEC5),
                boxShadow: ready
                    ? [
                        BoxShadow(
                          color: _kBlue.withOpacity(0.38 + 0.14 * (_pulseAnim.value - 1.0) / 0.035),
                          blurRadius: 18 + 10 * (_pulseAnim.value - 1.0) / 0.035,
                          spreadRadius: 1,
                          offset: const Offset(0, 5),
                        ),
                      ]
                    : [],
              ),
              clipBehavior: Clip.antiAlias,
              child: Stack(
                children: [
                  // ── Shimmer sweep (only when ready) ───────────────────
                  if (ready)
                    Positioned.fill(
                      child: Transform.translate(
                        offset: Offset(shimmerPos * 400, 0),
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                Colors.white.withOpacity(0.0),
                                Colors.white.withOpacity(0.18),
                                Colors.white.withOpacity(0.0),
                              ],
                              stops: const [0.0, 0.5, 1.0],
                            ),
                          ),
                        ),
                      ),
                    ),

                  // ── Button content ────────────────────────────────────
                  Center(
                    child: _isLoading
                        ? const SizedBox(
                            width: 22, height: 22,
                            child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                          )
                        : Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              AnimatedSwitcher(
                                duration: const Duration(milliseconds: 300),
                                child: Icon(
                                  ready ? Icons.campaign_rounded : Icons.lock_outline_rounded,
                                  key: ValueKey(ready),
                                  color: Colors.white,
                                  size: 20,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Raise Voice',
                                style: GoogleFonts.inter(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                  letterSpacing: 0.2,
                                ),
                              ),
                              if (ready) ...[
                                const SizedBox(width: 8),
                                AnimatedOpacity(
                                  opacity: ready ? 1.0 : 0.0,
                                  duration: const Duration(milliseconds: 400),
                                  child: const Icon(Icons.arrow_forward_rounded,
                                      color: Colors.white, size: 18),
                                ),
                              ],
                            ],
                          ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}