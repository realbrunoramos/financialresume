/// ScanFileScreen — professional document scanner with:
///   • Live blur / darkness / stability detection via camera stream
///   • Auto-capture when stable + sharp for 1.5 s
///   • Animated scanner overlay with quality-driven bracket colours
///   • Tap-to-focus with visual indicator
///   • Auto-contrast + noise-reduction + sharpening pipeline
///   • 7 named filters with real-time thumbnail strip
///   • Manual 4-corner perspective crop with magnifier
///   • Multi-page accumulation
///   • ML Kit OCR → Gemini AI field extraction
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:http/http.dart' as http;
import 'package:image/image.dart' as imge;
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';

import '../l10n/app_localizations.dart';
import '../screens/manual_crop_screen.dart';
import '../services/database_service.dart';
import '../services/image_pipeline_service.dart';
import '../services/ocr_parser_service.dart';
import '../services/secure_storage_service.dart';
import '../theme/app_tokens.dart';
import '../theme/colors.dart';

// ── Quality thresholds ─────────────────────────────────────────────────────────
const double _kBlurMin    = 90.0;  // Laplacian variance — below = blurry
const double _kDarkMax    = 38.0;  // Average Y luma  — below = too dark
const double _kDiffMax    = 6.0;   // Frame difference — above = moving
const int    _kStableReq  = 5;     // Consecutive stable frames before auto-capture

// ══════════════════════════════════════════════════════════════════════════════
// TextBasedDocumentImageProcessor
// Handles ML Kit OCR + rotation correction + text-boundary crop.
// The colour filter / enhancement is delegated to ImagePipelineService.
// ══════════════════════════════════════════════════════════════════════════════

class TextBasedDocumentImageProcessor {
  final File _imageFile;

  imge.Image? originalImage;
  imge.Image? modifiedImage;

  final TextRecognizer _recognizer = TextRecognizer();
  RecognizedText?       _ocr;
  List<TextBlock>       _group = [];

  TextBasedDocumentImageProcessor(this._imageFile);

  String          get extractedText     => _ocr?.text          ?? '';
  int             get detectedBlockCount => _ocr?.blocks.length ?? 0;
  RecognizedText? get ocr               => _ocr;

  // ── Initialise: OCR → rotate → crop ───────────────────────────────────────

  Future<void> initialize() async {
    final bytes = _imageFile.readAsBytesSync();
    originalImage = imge.decodeImage(bytes);
    if (originalImage == null) throw Exception('Cannot decode image');

    await _runOcr(_imageFile.path);

    // Rotation correction
    final angle = _mostFreqAngle();
    if (angle != null && angle.abs() > 0.5) {
      modifiedImage = imge.copyRotate(originalImage!, angle: -angle);
      // Re-run OCR on rotated version
      final dir     = await getTemporaryDirectory();
      final rotPath = '${dir.path}/rot_${DateTime.now().millisecondsSinceEpoch}.jpg';
      File(rotPath).writeAsBytesSync(imge.encodeJpg(modifiedImage!));
      await _runOcr(rotPath);
    } else {
      modifiedImage = originalImage;
    }

    // Crop to text bounding box
    final corners = _documentCorners();
    if (corners != null) {
      final cropped = _cropToCorners(corners);
      if (cropped != null) modifiedImage = cropped;
    }
  }

  Future<void> _runOcr(String path) async {
    try {
      final input = InputImage.fromFilePath(path);
      _ocr = await _recognizer.processImage(input);
      _group = _selectGroup();
    } catch (_) {
      _ocr   = null;
      _group = [];
    }
  }

  double? _mostFreqAngle() {
    if (_ocr == null || _ocr!.blocks.isEmpty) return null;
    final freq = <double, int>{};
    for (final b in _ocr!.blocks) {
      if (b.cornerPoints.length < 2) continue;
      final p1 = b.cornerPoints[0], p2 = b.cornerPoints[1];
      double a = math.atan2((p2.y - p1.y).toDouble(), (p2.x - p1.x).toDouble()) * 180 / math.pi;
      if (a > 90) a -= 180;
      if (a < -90) a += 180;
      a = (a * 10).round() / 10.0;
      freq[a] = (freq[a] ?? 0) + 1;
    }
    if (freq.isEmpty) return null;
    return freq.entries.reduce((a, b) => a.value > b.value ? a : b).key;
  }

  List<TextBlock> _selectGroup() {
    if (_ocr == null) return [];
    const tol = 5.0;
    final angle = _mostFreqAngle() ?? 0;
    return _ocr!.blocks.where((b) {
      if (b.cornerPoints.length < 2) return false;
      final p1 = b.cornerPoints[0], p2 = b.cornerPoints[1];
      double a = math.atan2((p2.y - p1.y).toDouble(), (p2.x - p1.x).toDouble()) * 180 / math.pi;
      if (a > 90)  a -= 180;
      if (a < -90) a += 180;
      return ((a * 10).round() / 10.0 - angle).abs() <= tol;
    }).toList();
  }

  List<List<int>>? _documentCorners() {
    if (_group.isEmpty || modifiedImage == null) return null;
    int minX = _group[0].cornerPoints[0].x;
    int maxX = minX, minY = _group[0].cornerPoints[0].y, maxY = minY;
    for (final b in _group) {
      for (final p in b.cornerPoints) {
        if (p.x < minX) minX = p.x; if (p.x > maxX) maxX = p.x;
        if (p.y < minY) minY = p.y; if (p.y > maxY) maxY = p.y;
      }
    }
    const m = 20;
    return [
      [_max(0, minX - m), _max(0, minY - m)],
      [_min(modifiedImage!.width,  maxX + m), _max(0, minY - m)],
      [_min(modifiedImage!.width,  maxX + m), _min(modifiedImage!.height, maxY + m)],
      [_max(0, minX - m), _min(modifiedImage!.height, maxY + m)],
    ];
  }

  imge.Image? _cropToCorners(List<List<int>> corners) {
    if (modifiedImage == null) return null;
    final xs = corners.map((c) => c[0]);
    final ys = corners.map((c) => c[1]);
    final x  = xs.reduce(_min), w = xs.reduce(_max) - x;
    final y  = ys.reduce(_min), h = ys.reduce(_max) - y;
    if (w <= 0 || h <= 0) return null;
    return imge.copyCrop(modifiedImage!, x: x, y: y, width: w, height: h);
  }

  Future<void> dispose() => _recognizer.close();
}

// File-scoped math helpers
int _min(int a, int b) => a < b ? a : b;
int _max(int a, int b) => a > b ? a : b;


// ══════════════════════════════════════════════════════════════════════════════
// ScanFileScreen
// ══════════════════════════════════════════════════════════════════════════════

class ScanFileScreen extends StatefulWidget {
  final String sectionId;
  const ScanFileScreen({super.key, required this.sectionId});

  @override
  State<ScanFileScreen> createState() => _ScanFileScreenState();
}

class _ScanFileScreenState extends State<ScanFileScreen>
    with SingleTickerProviderStateMixin {
  // ── Camera ─────────────────────────────────────────────────────────────────
  CameraController?  _ctrl;
  Future<void>?      _initFuture;

  // ── Live quality (viewfinder only) ─────────────────────────────────────────
  // ignore: unused_field
  double _blurScore   = 0;
  // ignore: unused_field
  double _avgLum      = 0;
  bool   _isBlurry    = false;
  bool   _isDark      = false;
  int    _stableFrames = 0;
  bool   _autoCapture = true;
  Uint8List? _prevY;
  bool   _analyzing   = false;
  int    _frameSkip   = 0;

  // Tap-to-focus
  Offset? _tapFocusPoint;

  // ── Capture & processing ───────────────────────────────────────────────────
  XFile?  _captured;
  String? _processedPath;  // Final displayed path
  String? _basePath;       // After OCR crop — before colour filter; used for filter switching
  bool    _isProcessing   = false;
  bool    _showScanLine   = false;

  TextBasedDocumentImageProcessor? _processor;
  RecognizedText? _ocrResult; // cached after processor disposal

  // ── Filters ────────────────────────────────────────────────────────────────
  int               _selectedFilter   = 0;
  List<Uint8List>   _filterThumbs     = [];

  // ── ML Kit / AI ───────────────────────────────────────────────────────────
  String  _mlKitText        = '';
  int     _mlKitBlockCount  = 0;
  int     _mlKitConfidence  = 0;
  Map<String, dynamic>? _aiAnalysis;
  bool    _isAnalyzingAI    = false;

  // ── Multi-page ─────────────────────────────────────────────────────────────
  final List<String>      _pages        = [];
  Map<String, dynamic>?   _primaryAI;

  // ── Animation ──────────────────────────────────────────────────────────────
  late AnimationController _bracketCtrl;

  // ── Services ───────────────────────────────────────────────────────────────
  final DatabaseService _db      = DatabaseService();
  final ImagePicker     _picker  = ImagePicker();

  // ── Filter metadata ────────────────────────────────────────────────────────
  static const _filterIcons = [
    Icons.article_rounded,
    Icons.auto_fix_high_rounded,
    Icons.brightness_low_rounded,
    Icons.brightness_high_rounded,
    Icons.filter_b_and_w_rounded,
    Icons.auto_awesome_rounded,
    Icons.photo_outlined,
  ];

  List<String> _filterNames(AppLocalizations l) => [
    l.filterDocument, l.filterSharp, l.dark,
    l.light, l.filterBW, l.filterNatural, l.original,
  ];

  // ── Lifecycle ──────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _bracketCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 900))
      ..repeat(reverse: true);
    _initCamera();
  }

  @override
  void dispose() {
    _bracketCtrl.dispose();
    _ctrl?.stopImageStream().catchError((_) {});
    _ctrl?.dispose();
    _processor?.dispose();
    super.dispose();
  }

  // ── Camera initialisation ──────────────────────────────────────────────────

  Future<void> _initCamera() async {
    try {
      final cams = await availableCameras();
      if (cams.isEmpty) return;
      _ctrl = CameraController(cams.first, ResolutionPreset.veryHigh,
          enableAudio: false);
      _initFuture = _ctrl!.initialize().then((_) {
        if (!mounted) return;
        _ctrl!.startImageStream(_onFrame);
        setState(() {});
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(
                '${AppLocalizations.of(context).errorInitializingCamera} $e')));
      }
    }
  }

  // ── Live frame analysis ────────────────────────────────────────────────────

  void _onFrame(CameraImage frame) {
    if (++_frameSkip % 10 != 0) return; // ~3 fps at 30 fps
    if (_analyzing || _captured != null) return;
    _analyzing = true;
    _processFrame(frame).whenComplete(() => _analyzing = false);
  }

  Future<void> _processFrame(CameraImage frame) async {
    try {
      final Uint8List? yPlane = _extractY(frame);
      if (yPlane == null) return;

      final result = await ImagePipelineService.analyzeFrame(
          yPlane, frame.width, frame.height, _prevY);

      _prevY = Uint8List.fromList(yPlane);

      if (!mounted) return;
      final blur  = (result['blur'] as num).toDouble();
      final lum   = (result['lum']  as num).toDouble();
      final diff  = (result['diff'] as num).toDouble();
      final blurry  = blur < _kBlurMin;
      final dark    = lum  < _kDarkMax;
      final stable  = _prevY != null && diff < _kDiffMax;

      setState(() {
        _blurScore = blur;
        _avgLum    = lum;
        _isBlurry  = blurry;
        _isDark    = dark;
      });

      _updateAutoCapture(blurry, dark, stable);
    } catch (_) {}
  }

  Uint8List? _extractY(CameraImage frame) {
    final fmt = frame.format.group;
    if (fmt == ImageFormatGroup.yuv420) {
      return frame.planes[0].bytes;
    }
    if (fmt == ImageFormatGroup.bgra8888) {
      final raw = frame.planes[0].bytes;
      final y   = Uint8List(frame.width * frame.height);
      for (int i = 0, j = 0; i < raw.length - 3; i += 4, j++) {
        if (j >= y.length) break;
        y[j] = ((raw[i + 2] * 299 + raw[i + 1] * 587 + raw[i] * 114) ~/ 1000)
            .clamp(0, 255);
      }
      return y;
    }
    return null;
  }

  void _updateAutoCapture(bool blurry, bool dark, bool stable) {
    if (!_autoCapture || _captured != null) {
      if (_stableFrames != 0) setState(() => _stableFrames = 0);
      return;
    }
    if (!blurry && !dark && stable) {
      setState(() => _stableFrames++);
      if (_stableFrames >= _kStableReq) {
        setState(() => _stableFrames = 0);
        _takePicture();
      }
    } else {
      if (_stableFrames != 0) setState(() => _stableFrames = 0);
    }
  }

  // ── Tap to focus ───────────────────────────────────────────────────────────

  Future<void> _onTapFocus(TapUpDetails d, BoxConstraints box) async {
    if (_ctrl == null || !_ctrl!.value.isInitialized) return;
    try {
      final x = d.localPosition.dx / box.maxWidth;
      final y = d.localPosition.dy / box.maxHeight;
      await _ctrl!.setFocusPoint(Offset(x, y));
      await _ctrl!.setExposurePoint(Offset(x, y));
      if (mounted) {
        setState(() => _tapFocusPoint = d.localPosition);
        Future.delayed(const Duration(seconds: 2),
            () { if (mounted) setState(() => _tapFocusPoint = null); });
      }
    } catch (_) {}
  }

  // ── Capture ────────────────────────────────────────────────────────────────

  Future<void> _takePicture() async {
    if (_ctrl == null || !_ctrl!.value.isInitialized || _captured != null) return;
    try {
      await _ctrl!.stopImageStream();
      final img = await _ctrl!.takePicture();
      setState(() => _captured = img);
      await _processCapture(img);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content:
                Text('${AppLocalizations.of(context).errorCapturingImage} $e')));
      }
    }
  }

  Future<void> _pickFromGallery() async {
    try {
      final f = await _picker.pickImage(source: ImageSource.gallery);
      if (f == null) return;
      try { await _ctrl?.stopImageStream(); } catch (_) {}
      setState(() => _captured = f);
      await _processCapture(f);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content:
                Text('${AppLocalizations.of(context).errorSelectingImage} $e')));
      }
    }
  }

  // ── Image processing pipeline ──────────────────────────────────────────────

  Future<void> _processCapture(XFile xf) async {
    setState(() { _isProcessing = true; _showScanLine = true; _selectedFilter = 0; });

    try {
      final src = File(xf.path);

      // 1. OCR-based rotation + crop
      _processor = TextBasedDocumentImageProcessor(src);
      try {
        await _processor!.initialize();
      } catch (_) {
        // If OCR fails, use original
      }

      // 2. Save the OCR-cropped intermediate (base for filter switching)
      final dir  = await getTemporaryDirectory();
      final base = File('${dir.path}/base_${DateTime.now().millisecondsSinceEpoch}.jpg');

      if (_processor?.modifiedImage != null) {
        base.writeAsBytesSync(
            imge.encodeJpg(_processor!.modifiedImage!, quality: 95));
      } else {
        await src.copy(base.path);
      }
      _basePath = base.path;

      // 3. ML Kit data (before disposal)
      _mlKitText       = _processor?.extractedText     ?? '';
      _mlKitBlockCount = _processor?.detectedBlockCount ?? 0;
      _ocrResult       = _processor?.ocr;                  // cache for AI fallback
      final parsed     = OcrParserService.parse(
          _mlKitText, recognizedText: _ocrResult);
      _mlKitConfidence = parsed.confidence;

      // 4. Full enhancement pipeline (Document filter = 0)
      final result = await ImagePipelineService.processDocument(base);
      if (result != null && mounted) {
        setState(() => _processedPath = result.file.path);
      } else if (mounted) {
        // Fallback: use base path directly
        setState(() => _processedPath = base.path);
      }

      // 5. Generate filter thumbnails in background (non-blocking)
      _generateThumbs(base);

    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content:
                Text('${AppLocalizations.of(context).errorProcessing} $e')));
      }
    } finally {
      _processor?.dispose();
      if (mounted) setState(() { _isProcessing = false; _showScanLine = false; });
    }
  }

  Future<void> _generateThumbs(File base) async {
    try {
      final thumbs = await ImagePipelineService.generateThumbnails(base);
      if (mounted) setState(() => _filterThumbs = thumbs);
    } catch (_) {}
  }

  // ── Filter application ─────────────────────────────────────────────────────

  Future<void> _applyFilter(int filterIdx) async {
    if (_basePath == null) return;
    setState(() { _selectedFilter = filterIdx; _isProcessing = true; });
    try {
      final out = await ImagePipelineService.applyFilter(
          File(_basePath!), filterIdx);
      if (out != null && mounted) setState(() => _processedPath = out.path);
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  // ── Manual crop ────────────────────────────────────────────────────────────

  Future<void> _openManualCrop() async {
    if (_basePath == null) return;
    final result = await Navigator.push<String>(
      context,
      MaterialPageRoute(
          builder: (_) => ManualCropScreen(imageFile: File(_basePath!))),
    );
    if (result == null || !mounted) return;

    // Use warped image as the new base + apply current filter
    setState(() { _basePath = result; _processedPath = result; _isProcessing = true; });
    try {
      final out = await ImagePipelineService.applyFilter(
          File(result), _selectedFilter);
      if (out != null && mounted) {
        setState(() => _processedPath = out.path);
        _generateThumbs(File(result));
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  // ── Confirm / multi-page ───────────────────────────────────────────────────

  Future<void> _confirm() async {
    if (_captured == null || _isProcessing || _isAnalyzingAI) return;

    // Run AI on first page only
    if (_pages.isEmpty) {
      await _analyzeWithAI();
      if (_aiAnalysis != null) _primaryAI = Map.from(_aiAnalysis!);
    }

    if (_processedPath != null) _pages.add(_processedPath!);

    if (mounted) _showAddMoreSheet();
  }

  void _showAddMoreSheet() {
    final l      = AppLocalizations.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final count  = _pages.length;

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => SafeArea(
        child: Container(
          margin: const EdgeInsets.all(AppTokens.sp12),
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkCard : AppColors.white,
            borderRadius: BorderRadius.circular(AppTokens.radius24),
          ),
          padding: const EdgeInsets.all(AppTokens.sp20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36, height: 4,
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.darkBorder : AppColors.grey200,
                    borderRadius: BorderRadius.circular(2)),
                ),
              ),
              const SizedBox(height: AppTokens.sp16),
              Row(children: [
                Container(
                  padding: const EdgeInsets.all(AppTokens.sp8),
                  decoration: BoxDecoration(
                    color: AppColors.info.withAlpha(24),
                    borderRadius: BorderRadius.circular(AppTokens.radius8)),
                  child: const Icon(Icons.document_scanner_rounded,
                      color: AppColors.info, size: 20),
                ),
                const SizedBox(width: AppTokens.sp12),
                Expanded(
                  child: Text(l.scannedDocument,
                    style: TextStyle(
                      fontSize: 17, fontWeight: FontWeight.w700,
                      color: isDark ? AppColors.darkText : AppColors.dark)),
                ),
              ]),
              const SizedBox(height: AppTokens.sp12),
              Text(
                count == 1
                    ? l.addMorePagesQuestion
                    : '${l.documentWithPagesAddMoreQuestion} $count ${l.documentWithPagesAddMoreQuestion2}',
                style: TextStyle(
                  fontSize: 14, height: 1.5,
                  color: isDark ? AppColors.darkSubtext : AppColors.grey500),
              ),
              const SizedBox(height: AppTokens.sp20),
              Row(children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      _retryCapture();
                    },
                    icon: const Icon(Icons.add_a_photo_rounded, size: 18),
                    label: Text('${l.documentWithPagesAddMoreQuestion} $count'),
                  ),
                ),
                const SizedBox(width: AppTokens.sp12),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () { Navigator.pop(context); _finish(); },
                    icon: const Icon(Icons.check_rounded, size: 18),
                    label: Text(
                        '${l.confirmWithPageCount} ($count ${l.confirmWithPageCount2})'),
                  ),
                ),
              ]),
            ],
          ),
        ),
      ),
    );
  }

  void _finish() {
    if (mounted) {
      Navigator.pop(context, {
        'imagePaths': _pages,
        'aiAnalysis': _primaryAI ?? _aiAnalysis,
      });
    }
  }

  Future<void> _retryCapture() async {
    setState(() {
      _captured       = null;
      _processedPath  = null;
      _basePath       = null;
      _selectedFilter = 0;
      _filterThumbs   = [];
      _showScanLine   = false;
      _ocrResult      = null;
    });
    // Restart stream
    try { await _ctrl?.startImageStream(_onFrame); } catch (_) {}
  }

  // ── AI analysis ────────────────────────────────────────────────────────────

  Future<void> _analyzeWithAI() async {
    final promptLang   = AppLocalizations.of(context).promptLanguage;
    final errorLabel   = AppLocalizations.of(context).errorAiAnalysis;

    final invoices = await _db.getNoPaidInvoices(widget.sectionId);
    final inv = StringBuffer();
    for (final i in invoices) {
      inv.write(
          'id: ${i.id} -> entidade: ${i.entity}, valor: ${i.amount}, refMesAno: ${i.monthRef}\n');
    }

    if (_processedPath == null || _isAnalyzingAI) return;
    setState(() => _isAnalyzingAI = true);

    try {
      final apiKey = await SecureStorageService.readApiKey();
      if (apiKey == null || apiKey.isEmpty) {
        final parsed = OcrParserService.parse(
            _mlKitText, recognizedText: _ocrResult);
        if (mounted) {
          setState(() => _aiAnalysis = parsed.fields);
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text(AppLocalizations.of(context).basicOcrExtraction),
              backgroundColor: AppColors.info,
              duration: const Duration(seconds: 3)));
        }
        return;
      }

      final imageBytes  = await File(_processedPath!).readAsBytes();
      final imageBase64 = base64Encode(imageBytes);
      final url = Uri.parse(
          'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent?key=$apiKey');

      final prompt = _buildGeminiPrompt(promptLang, inv.toString());

      http.Response? response;
      for (int attempt = 0; attempt < 3; attempt++) {
        try {
          response = await http.post(url,
              headers: {'Content-Type': 'application/json'},
              body: jsonEncode({
                'contents': [
                  {
                    'parts': [
                      {'text': prompt},
                      {
                        'inlineData': {
                          'mimeType': 'image/jpeg',
                          'data': imageBase64,
                        }
                      }
                    ]
                  }
                ]
              })).timeout(const Duration(seconds: 45));
          if (response.statusCode == 429) {
            await Future.delayed(Duration(seconds: 2 * (attempt + 1)));
            continue;
          }
          break;
        } on TimeoutException {
          if (attempt == 2) rethrow;
          await Future.delayed(const Duration(seconds: 3));
        }
      }

      if (response != null && response.statusCode == 200) {
        final data  = jsonDecode(response.body);
        final text  = data['candidates'][0]['content']['parts'][0]['text'] as String;
        final match = RegExp(r'\{.*\}', dotAll: true).firstMatch(text);
        if (match != null) {
          final ai = jsonDecode(match.group(0)!);
          if (mounted) setState(() => _aiAnalysis = ai);
        }
      } else {
        throw Exception('API ${response?.statusCode ?? 'no response'}');
      }
    } catch (e) {
      debugPrint('$errorLabel $e');
      if (_mlKitText.isNotEmpty) {
        final parsed = OcrParserService.parse(
            _mlKitText, recognizedText: _ocrResult);
        if (mounted) setState(() => _aiAnalysis = parsed.fields);
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(errorLabel), backgroundColor: AppColors.red));
      }
    } finally {
      if (mounted) setState(() => _isAnalyzingAI = false);
    }
  }

  String _buildGeminiPrompt(String lang, String invoices) => """
Recebeste uma imagem de um documento financeiro (ex.: fatura, recibo, comprovativo de pagamento).
Deves extrair informações e responder **APENAS** com um objeto JSON de linha única no formato seguinte, sem explicações adicionais e sem texto fora do JSON:

{"tipo_documento":<número>,"entidade":"string|UNKNOWN","data_emissao":"dd mm yyyy|UNKNOWN","valor_total":"string numérica|UNKNOWN","data_limite":"dd mm yyyy|UNKNOWN","é_crédito":"0|1|UNKNOWN","mes_ano_ref":"mm/yyyy|UNKNOWN","descrição":"string|UNKNOWN","ids_ref_fatura":"string|UNKNOWN","numero_serie":"string|UNKNOWN","metodo_pagamento":"string|UNKNOWN"}

Tipos: 1=Compra, 2=Fatura/Cobrança, 3=Comprovativo Pagamento, 4=Outro
Faturas existentes: $invoices
(Output em: $lang)""";

  // ══════════════════════════════════════════════════════════════════════════
  // BUILD
  // ══════════════════════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_ctrl == null || _initFuture == null) {
      return const Center(child: CircularProgressIndicator(color: Colors.white));
    }
    return FutureBuilder<void>(
      future: _initFuture,
      builder: (ctx, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator(color: Colors.white));
        }
        if (_processedPath != null || (_captured != null && _isProcessing)) {
          return _buildPreviewUI();
        }
        return _buildViewfinderUI();
      },
    );
  }

  // ── Viewfinder UI ──────────────────────────────────────────────────────────

  Widget _buildViewfinderUI() {
    return Stack(
      fit: StackFit.expand,
      children: [
        // Camera preview with tap-to-focus
        LayoutBuilder(builder: (ctx, box) {
          return GestureDetector(
            onTapUp: (d) => _onTapFocus(d, box),
            child: CameraPreview(_ctrl!),
          );
        }),

        // Document guide overlay
        AnimatedBuilder(
          animation: _bracketCtrl,
          builder: (ctx, _) {
            final Color color;
            if (_isBlurry) {
              color = Colors.red;
            } else if (_isDark) {
              color = Colors.orange;
            } else if (_stableFrames > 0) {
              color = Color.lerp(Colors.yellow, AppColors.success,
                  _stableFrames / _kStableReq)!;
            } else {
              color = Colors.white;
            }
            return CustomPaint(
              size: Size.infinite,
              painter: _ScannerOverlayPainter(
                bracketColor: color,
                pulse: _stableFrames >= _kStableReq ? _bracketCtrl.value : 0,
              ),
            );
          },
        ),

        // Quality badge (blur / dark)
        _buildQualityBadge(),

        // Tap focus ring
        if (_tapFocusPoint != null)
          Positioned(
            left: _tapFocusPoint!.dx - 30,
            top:  _tapFocusPoint!.dy - 30,
            child: Container(
              width: 60, height: 60,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.yellow, width: 1.5),
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),

        // Stability / auto-capture indicator
        _buildStabilityIndicator(),

        // Bottom action bar
        _buildViewfinderBar(),
      ],
    );
  }

  Widget _buildQualityBadge() {
    if (!_isBlurry && !_isDark) return const SizedBox.shrink();
    final l     = AppLocalizations.of(context);
    final color = _isBlurry ? Colors.red : Colors.orange;
    return Positioned(
      top: 16, left: 0, right: 0,
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: color.withAlpha(220),
            borderRadius: BorderRadius.circular(20)),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(_isBlurry ? Icons.blur_on : Icons.light_mode,
                color: Colors.white, size: 16),
            const SizedBox(width: 8),
            Text(_isBlurry ? l.imageTooBlurry : l.tooDark,
                style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 13)),
          ]),
        ),
      ),
    );
  }

  Widget _buildStabilityIndicator() {
    if (!_autoCapture || _stableFrames == 0) return const SizedBox.shrink();
    final l        = AppLocalizations.of(context);
    final progress = (_stableFrames / _kStableReq).clamp(0.0, 1.0);
    return Positioned(
      bottom: 96, left: 0, right: 0,
      child: Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          SizedBox(
            width: 64, height: 64,
            child: Stack(alignment: Alignment.center, children: [
              CircularProgressIndicator(
                value: progress,
                strokeWidth: 5,
                backgroundColor: Colors.white.withAlpha(60),
                valueColor: AlwaysStoppedAnimation(
                    Color.lerp(Colors.yellow, AppColors.success, progress)!)),
              const Icon(Icons.camera_alt_rounded, color: Colors.white, size: 26),
            ]),
          ),
          const SizedBox(height: 6),
          Text(l.holdSteady,
              style:
                  const TextStyle(color: Colors.white, fontSize: 11)),
        ]),
      ),
    );
  }

  Widget _buildViewfinderBar() {
    final l = AppLocalizations.of(context);
    return Positioned(
      bottom: 0, left: 0, right: 0,
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.bottomCenter,
            end: Alignment.topCenter,
            colors: [Colors.black.withAlpha(220), Colors.transparent],
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            // Gallery
            _circleButton(
              icon: Icons.photo_library_rounded,
              label: 'Gallery',
              onTap: _pickFromGallery,
            ),

            // Shutter
            GestureDetector(
              onTap: _takePicture,
              child: Container(
                width: 72, height: 72,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white,
                  border: Border.all(
                      color: Colors.white.withAlpha(100), width: 4)),
              ),
            ),

            // Auto-capture toggle
            _circleButton(
              icon: _autoCapture
                  ? Icons.motion_photos_on_rounded
                  : Icons.motion_photos_off_rounded,
              label: l.autoCapture,
              onTap: () => setState(() => _autoCapture = !_autoCapture),
              active: _autoCapture,
            ),
          ],
        ),
      ),
    );
  }

  Widget _circleButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool active = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: 52, height: 52,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: active
                ? AppColors.success.withAlpha(200)
                : Colors.white.withAlpha(40),
            border:
                Border.all(color: Colors.white.withAlpha(100), width: 1.5)),
          child: Icon(icon, color: Colors.white, size: 22),
        ),
        const SizedBox(height: 4),
        Text(label,
            style: const TextStyle(color: Colors.white70, fontSize: 10)),
      ]),
    );
  }

  // ── Preview UI (post-capture) ──────────────────────────────────────────────

  Widget _buildPreviewUI() {
    final l = AppLocalizations.of(context);
    return Stack(
      fit: StackFit.expand,
      children: [
        // Main image
        _processedPath != null
            ? InteractiveViewer(
                child: Center(
                    child: Image.file(File(_processedPath!),
                        fit: BoxFit.contain)))
            : (_captured != null
                ? Image.file(File(_captured!.path), fit: BoxFit.contain)
                : const SizedBox.shrink()),

        // Scan line animation
        if (_showScanLine) _buildScanLine(),

        // Multi-page strip (if >0 pages already confirmed)
        if (_pages.isNotEmpty) _buildPageStrip(),

        // Confidence badge
        _buildConfidenceBadge(),

        // Filter strip
        _buildFilterStrip(l),

        // Bottom action bar
        _buildPreviewBar(l),

        // Processing overlay
        if (_isProcessing)
          Container(
            color: Colors.black.withAlpha(160),
            child: const Center(
                child: CircularProgressIndicator(color: Colors.white)),
          ),
      ],
    );
  }

  Widget _buildScanLine() {
    return AnimatedBuilder(
      animation: _bracketCtrl,
      builder: (ctx, child) {
        final h = MediaQuery.of(ctx).size.height;
        return Positioned(
          left: 0, right: 0,
          top: (_bracketCtrl.value * h * 2).clamp(0.0, h),
          child: child!,
        );
      },
      child: Container(
        height: 3,
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: [
            Colors.transparent,
            AppColors.success.withAlpha(200),
            Colors.transparent,
          ]),
          boxShadow: [
            BoxShadow(
                color: AppColors.success.withAlpha(200),
                blurRadius: 8,
                spreadRadius: 2)
          ],
        ),
      ),
    );
  }

  Widget _buildPageStrip() {
    return Positioned(
      top: 0, left: 0, right: 0,
      child: Container(
        height: 72,
        color: Colors.black.withAlpha(180),
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          itemCount: _pages.length,
          itemBuilder: (_, i) => Container(
            width: 48,
            margin: const EdgeInsets.only(right: 8),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: Colors.white.withAlpha(80), width: 1)),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(5),
              child: Image.file(File(_pages[i]), fit: BoxFit.cover),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildConfidenceBadge() {
    if (_processedPath == null || _mlKitBlockCount == 0) {
      return const SizedBox.shrink();
    }
    final Color color;
    final String dots;
    if (_mlKitConfidence >= 4) {
      color = AppColors.success; dots = '●●●';
    } else if (_mlKitConfidence >= 2) {
      color = AppColors.warning; dots = '●●○';
    } else {
      color = AppColors.danger;  dots = '●○○';
    }
    return Positioned(
      top: _pages.isNotEmpty ? 80 : 12,
      left: 12,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: Colors.black.withAlpha(200),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withAlpha(160), width: 1)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Text(dots,
              style: TextStyle(
                  color: color, fontSize: 10, letterSpacing: 2)),
          const SizedBox(width: 6),
          Text('OCR $_mlKitBlockCount',
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w600)),
        ]),
      ),
    );
  }

  Widget _buildFilterStrip(AppLocalizations l) {
    if (_processedPath == null) return const SizedBox.shrink();
    final names = _filterNames(l);
    return Positioned(
      bottom: 68, left: 0, right: 0,
      child: Container(
        height: 88,
        color: Colors.black.withAlpha(200),
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          itemCount: names.length,
          itemBuilder: (_, i) {
            final selected = _selectedFilter == i;
            return GestureDetector(
              onTap: () => _applyFilter(i),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                margin: const EdgeInsets.only(right: 10),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Container(
                    width: 52, height: 52,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: selected ? AppColors.success : Colors.transparent,
                        width: 2.5,
                      ),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: i < _filterThumbs.length &&
                              _filterThumbs[i].isNotEmpty
                          ? Image.memory(_filterThumbs[i], fit: BoxFit.cover)
                          : Container(
                              color: Colors.grey[850],
                              child: Icon(_filterIcons[i],
                                  color: Colors.white54, size: 20)),
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(names[i],
                      style: TextStyle(
                        color:
                            selected ? AppColors.success : Colors.white60,
                        fontSize: 9,
                        fontWeight: selected
                            ? FontWeight.w700
                            : FontWeight.normal,
                      )),
                ]),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildPreviewBar(AppLocalizations l) {
    return Positioned(
      bottom: 0, left: 0, right: 0,
      child: Container(
        height: 64,
        color: Colors.black,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _actionBtn(Icons.replay_rounded, l.retry, _retryCapture),
            _actionBtn(
                Icons.crop_rounded, l.manualCrop, _openManualCrop),
            _actionBtn(Icons.add_a_photo_rounded, '+Pág',
                (_isProcessing || _isAnalyzingAI) ? null : _confirm),
            _actionBtn(
              Icons.check_circle_rounded,
              l.apply,
              (_isProcessing || _isAnalyzingAI)
                  ? null
                  : () async {
                      await _confirm();
                    },
              primary: true,
              loading: _isAnalyzingAI,
            ),
          ],
        ),
      ),
    );
  }

  Widget _actionBtn(
    IconData icon,
    String label,
    VoidCallback? onTap, {
    bool primary = false,
    bool loading = false,
  }) {
    final color = primary
        ? AppColors.success
        : onTap == null
            ? Colors.grey
            : Colors.white;
    return GestureDetector(
      onTap: onTap,
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        loading
            ? const SizedBox(
                width: 24, height: 24,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: Colors.white))
            : Icon(icon, color: color, size: 24),
        const SizedBox(height: 3),
        Text(label,
            style: TextStyle(color: color, fontSize: 9)),
      ]),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// Scanner overlay CustomPainter
// ══════════════════════════════════════════════════════════════════════════════

class _ScannerOverlayPainter extends CustomPainter {
  final Color bracketColor;
  final double pulse; // 0–1 animation value for "ready" state

  const _ScannerOverlayPainter({
    required this.bracketColor,
    required this.pulse,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Document guide rectangle — centred, 82 % × 68 % of screen
    final guideW = size.width  * 0.82;
    final guideH = size.height * 0.68;
    final guide  = Rect.fromCenter(
        center: Offset(size.width / 2, size.height * 0.46),
        width:  guideW,
        height: guideH);

    // Dark vignette outside the guide
    final mask = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height))
      ..addRRect(RRect.fromRectAndRadius(guide, const Radius.circular(8)))
      ..fillType = PathFillType.evenOdd;
    canvas.drawPath(mask, Paint()..color = Colors.black.withValues(alpha: 0.52));

    // Subtle guide border
    canvas.drawRRect(
        RRect.fromRectAndRadius(guide, const Radius.circular(8)),
        Paint()
          ..color = Colors.white.withValues(alpha: 0.15)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1);

    // Animated corner brackets
    final bLen  = 26.0 + pulse * 8;
    final bPaint = Paint()
      ..color     = bracketColor
      ..strokeWidth = 3.5
      ..style     = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    _drawBracket(canvas, bPaint, guide.topLeft,     1,  1,  bLen);
    _drawBracket(canvas, bPaint, guide.topRight,   -1,  1,  bLen);
    _drawBracket(canvas, bPaint, guide.bottomRight,-1, -1,  bLen);
    _drawBracket(canvas, bPaint, guide.bottomLeft,  1, -1,  bLen);
  }

  void _drawBracket(Canvas c, Paint p, Offset corner,
      double dx, double dy, double len) {
    c.drawLine(corner, corner + Offset(dx * len, 0), p);
    c.drawLine(corner, corner + Offset(0, dy * len), p);
  }

  @override
  bool shouldRepaint(_ScannerOverlayPainter old) =>
      bracketColor != old.bracketColor || pulse != old.pulse;
}
