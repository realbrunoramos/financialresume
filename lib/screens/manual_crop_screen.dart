/// ManualCropScreen — 4-corner perspective crop with magnifier loupe.
///
/// Push this screen with [Navigator.push] and await the result (String? path).
/// Returns the path of the warped image on confirm, null on cancel.
library;

import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../services/image_pipeline_service.dart';
import '../theme/colors.dart';

class ManualCropScreen extends StatefulWidget {
  /// The source image to crop (typically the captured + rotated file).
  final File imageFile;

  const ManualCropScreen({super.key, required this.imageFile});

  @override
  State<ManualCropScreen> createState() => _ManualCropScreenState();
}

class _ManualCropScreenState extends State<ManualCropScreen> {
  // Image info
  Size _imageSize = Size.zero;
  bool _imageLoaded = false;

  // Corner positions in IMAGE-SPACE pixels (TL, TR, BR, BL)
  late List<Offset> _corners;

  // Drag state
  int? _activeCorner;
  Offset? _dragScreenPos;

  bool _isProcessing = false;

  // ── Lifecycle ──────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _loadImageDimensions();
  }

  Future<void> _loadImageDimensions() async {
    final bytes    = await widget.imageFile.readAsBytes();
    final codec    = await ui.instantiateImageCodec(bytes);
    final frame    = await codec.getNextFrame();
    final uiImage  = frame.image;
    final size     = Size(uiImage.width.toDouble(), uiImage.height.toDouble());
    uiImage.dispose();

    final margin = Offset(size.width * 0.08, size.height * 0.08);
    setState(() {
      _imageSize   = size;
      _corners     = [
        margin,                                                        // TL
        Offset(size.width - margin.dx, margin.dy),                    // TR
        Offset(size.width - margin.dx, size.height - margin.dy),      // BR
        Offset(margin.dx, size.height - margin.dy),                    // BL
      ];
      _imageLoaded = true;
    });
  }

  // ── Coordinate helpers ─────────────────────────────────────────────────────

  Rect _displayRect(Size screen) {
    if (!_imageLoaded || _imageSize == Size.zero) return Rect.zero;
    final iAsp = _imageSize.width / _imageSize.height;
    final sAsp = screen.width / screen.height;
    double w, h;
    if (sAsp > iAsp) {
      h = screen.height;
      w = h * iAsp;
    } else {
      w = screen.width;
      h = w / iAsp;
    }
    return Rect.fromLTWH(
        (screen.width - w) / 2, (screen.height - h) / 2, w, h);
  }

  Offset _imgToScreen(Offset img, Rect rect) => Offset(
      rect.left + img.dx / _imageSize.width  * rect.width,
      rect.top  + img.dy / _imageSize.height * rect.height);

  Offset _screenToImg(Offset screen, Rect rect) => Offset(
      (screen.dx - rect.left) / rect.width  * _imageSize.width,
      (screen.dy - rect.top)  / rect.height * _imageSize.height);

  int? _nearestCorner(Offset screenPt, Rect dispRect, {double radius = 44}) {
    int? best; double bestD = radius;
    for (int i = 0; i < 4; i++) {
      final d = (_imgToScreen(_corners[i], dispRect) - screenPt).distance;
      if (d < bestD) { bestD = d; best = i; }
    }
    return best;
  }

  // ── Crop action ────────────────────────────────────────────────────────────

  Future<void> _applyCrop() async {
    setState(() => _isProcessing = true);
    try {
      final cornerList = _corners.expand((o) => [o.dx, o.dy]).toList();
      final result = await ImagePipelineService.perspectiveWarp(
          widget.imageFile, cornerList);
      if (mounted) Navigator.pop(context, result?.path);
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(l.manualCrop,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          if (!_isProcessing)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: FilledButton(
                style: FilledButton.styleFrom(backgroundColor: AppColors.success),
                onPressed: _applyCrop,
                child: Text(l.applyCorners),
              ),
            ),
        ],
      ),
      body: _imageLoaded
          ? LayoutBuilder(builder: (ctx, box) {
              final screen  = Size(box.maxWidth, box.maxHeight);
              final dispRect = _displayRect(screen);
              final scrCorners =
                  _corners.map((c) => _imgToScreen(c, dispRect)).toList();

              return GestureDetector(
                onPanStart: (d) {
                  final idx = _nearestCorner(d.localPosition, dispRect);
                  if (idx != null) {
                    setState(() {
                      _activeCorner  = idx;
                      _dragScreenPos = d.localPosition;
                    });
                  }
                },
                onPanUpdate: (d) {
                  if (_activeCorner == null) return;
                  final img = _screenToImg(d.localPosition, dispRect);
                  setState(() {
                    _corners[_activeCorner!] = Offset(
                        img.dx.clamp(0, _imageSize.width),
                        img.dy.clamp(0, _imageSize.height));
                    _dragScreenPos = d.localPosition;
                  });
                },
                onPanEnd: (_) => setState(() {
                  _activeCorner  = null;
                  _dragScreenPos = null;
                }),
                child: Stack(
                  children: [
                    // Base image
                    Positioned.fromRect(
                      rect: dispRect,
                      child: Image.file(widget.imageFile, fit: BoxFit.fill),
                    ),

                    // Quad overlay + handles
                    CustomPaint(
                      size: screen,
                      painter: _QuadPainter(
                          corners: scrCorners, activeIndex: _activeCorner),
                    ),

                    // Hint banner
                    Positioned(
                      bottom: 24,
                      left: 24,
                      right: 24,
                      child: Center(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.black.withAlpha(180),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(l.dragCornersHint,
                              style: const TextStyle(
                                  color: Colors.white, fontSize: 13),
                              textAlign: TextAlign.center),
                        ),
                      ),
                    ),

                    // Magnifier loupe
                    if (_activeCorner != null && _dragScreenPos != null)
                      _buildMagnifier(
                          _dragScreenPos!,
                          _corners[_activeCorner!],
                          dispRect,
                          screen),

                    // Processing overlay
                    if (_isProcessing)
                      Container(
                        color: Colors.black.withAlpha(190),
                        child: const Center(
                            child: CircularProgressIndicator(
                                color: Colors.white)),
                      ),
                  ],
                ),
              );
            })
          : const Center(
              child: CircularProgressIndicator(color: Colors.white)),
    );
  }

  // ── Magnifier loupe ────────────────────────────────────────────────────────

  Widget _buildMagnifier(
      Offset screenPos, Offset imgCorner, Rect dispRect, Size screen) {
    const lensSize = 110.0;
    const zoom     = 2.5;

    final lensX =
        (screenPos.dx - lensSize / 2).clamp(0.0, screen.width  - lensSize);
    final lensY =
        (screenPos.dy - lensSize - 28).clamp(0.0, screen.height - lensSize);

    // Focal point in image-space → normalised [0,1]
    final fx = (imgCorner.dx / _imageSize.width).clamp(0.0, 1.0);
    final fy = (imgCorner.dy / _imageSize.height).clamp(0.0, 1.0);

    // At zoom×, the image fills dispRect.width*zoom × dispRect.height*zoom.
    // Translate so the focal point sits at the lens centre.
    final tx = lensSize / 2 - fx * dispRect.width  * zoom;
    final ty = lensSize / 2 - fy * dispRect.height * zoom;

    return Positioned(
      left: lensX,
      top:  lensY,
      width:  lensSize,
      height: lensSize,
      child: Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 2.5),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withAlpha(120),
                blurRadius: 10,
                spreadRadius: 2)
          ],
        ),
        child: ClipOval(
          child: OverflowBox(
            maxWidth:  double.infinity,
            maxHeight: double.infinity,
            alignment: Alignment.topLeft,
            child: Transform.translate(
              offset: Offset(tx, ty),
              child: Image.file(
                widget.imageFile,
                width:  dispRect.width  * zoom,
                height: dispRect.height * zoom,
                fit: BoxFit.fill,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Quad painter ───────────────────────────────────────────────────────────────

class _QuadPainter extends CustomPainter {
  final List<Offset> corners; // 4 screen-space corners
  final int? activeIndex;

  const _QuadPainter({required this.corners, this.activeIndex});

  @override
  void paint(Canvas canvas, Size size) {
    if (corners.length < 4) return;

    // Semi-transparent fill
    final path = Path()
      ..moveTo(corners[0].dx, corners[0].dy)
      ..lineTo(corners[1].dx, corners[1].dy)
      ..lineTo(corners[2].dx, corners[2].dy)
      ..lineTo(corners[3].dx, corners[3].dy)
      ..close();

    canvas.drawPath(
        path, Paint()..color = AppColors.info.withAlpha(35)..style = PaintingStyle.fill);

    // Edge lines
    canvas.drawPath(
        path,
        Paint()
          ..color = Colors.white.withAlpha(200)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.8
          ..strokeJoin = StrokeJoin.round);

    // Corner handles
    for (int i = 0; i < 4; i++) {
      final active = i == activeIndex;
      final radius = active ? 16.0 : 11.0;
      final color  = active ? AppColors.success : Colors.white;

      canvas.drawCircle(corners[i], radius,
          Paint()..color = color.withAlpha(220)..style = PaintingStyle.fill);
      canvas.drawCircle(corners[i], radius,
          Paint()
            ..color = Colors.black.withAlpha(80)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.5);

      // Inner dot for precision
      if (!active) {
        canvas.drawCircle(corners[i], 4,
            Paint()..color = AppColors.info..style = PaintingStyle.fill);
      }
    }
  }

  @override
  bool shouldRepaint(_QuadPainter old) =>
      corners != old.corners || activeIndex != old.activeIndex;
}
