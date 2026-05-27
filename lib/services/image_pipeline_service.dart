/// ImagePipelineService — professional document image processing pipeline.
///
/// All heavy computation runs in background isolates via compute().
/// Top-level functions must remain top-level (not methods) for isolate dispatch.
library;

import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show compute;
import 'package:image/image.dart' as imge;
import 'package:path_provider/path_provider.dart';

// ── Public data models ─────────────────────────────────────────────────────────

class PipelineResult {
  final File file;
  final double blurScore; // Laplacian variance — higher = sharper
  const PipelineResult({required this.file, required this.blurScore});
}

// ── Named filter indices ───────────────────────────────────────────────────────
// 0 = Document (3-level document enhance)
// 1 = Sharp    (unsharp mask only)
// 2 = Dark     (dark environment boost)
// 3 = Light    (bright environment correction)
// 4 = B&W      (grayscale + contrast)
// 5 = Natural  (auto-contrast only)
// 6 = Original (no colour change)

// ══════════════════════════════════════════════════════════════════════════════
// TOP-LEVEL ISOLATE ENTRY POINTS
// ══════════════════════════════════════════════════════════════════════════════

/// Full processing pipeline: auto-contrast → noise reduction → filter → sharpen.
/// Args: {bytes: Uint8List, filter: int}
/// Returns: {bytes: Uint8List, blur: double} or {error: true}
Map<String, dynamic> fullPipelineIsolate(Map<String, dynamic> args) {
  final bytes = args['bytes'] as Uint8List;
  final filterIdx = (args['filter'] as num?)?.toInt() ?? 0;

  imge.Image? img = imge.decodeImage(bytes);
  if (img == null) return {'error': true};

  // 1. Downscale to max 2 500 px on longest side (speed + memory)
  final maxDim = math.max(img.width, img.height);
  if (maxDim > 2500) {
    final s = 2500 / maxDim;
    img = imge.copyResize(img,
        width: (img.width * s).round(), height: (img.height * s).round());
  }

  // 2. Auto-contrast (1%–99% histogram stretch)
  img = _autoContrast(img);

  // 3. Mild Gaussian noise reduction (radius 1 = 3×3 kernel)
  img = imge.gaussianBlur(img, radius: 1);

  // 4. Named colour/tone filter
  img = _applyFilter(img, filterIdx);

  // 5. Unsharp mask (skip for Original filter)
  if (filterIdx != 6) img = _unsharpMask(img);

  // 6. Quality metric
  final blurScore = _laplacianVariance(img);

  return {
    'bytes': Uint8List.fromList(imge.encodeJpg(img, quality: 88)),
    'blur': blurScore,
  };
}

/// Apply a single filter to already-processed image bytes (fast, no pipeline).
/// Args: {bytes: Uint8List, filter: int}
Uint8List applyFilterIsolate(Map<String, dynamic> args) {
  final bytes = args['bytes'] as Uint8List;
  final filterIdx = (args['filter'] as num).toInt();
  final img = imge.decodeImage(bytes);
  if (img == null) return bytes;
  final out = _applyFilter(img, filterIdx);
  return Uint8List.fromList(imge.encodeJpg(out, quality: 88));
}

/// Generate thumbnail bytes for all 7 filters at once (called once after capture).
/// Args: Uint8List source image bytes.
/// Returns a list of 7 Uint8List thumbnails in filter order.
List<Uint8List> generateThumbnailsIsolate(Uint8List bytes) {
  final img = imge.decodeImage(bytes);
  if (img == null) return List.filled(7, Uint8List(0));
  // 60 px wide thumbnail
  final thumb = imge.copyResize(img, width: 60);
  return List.generate(7, (i) {
    final filtered = _applyFilter(thumb, i);
    return Uint8List.fromList(imge.encodeJpg(filtered, quality: 75));
  });
}

/// Perspective warp: maps source quad (4 corners) to a rectangle.
/// Args: map with 'bytes' (Uint8List) and 'corners' (List of 8 doubles: tl.x, tl.y, tr.x, tr.y, br.x, br.y, bl.x, bl.y).
Uint8List perspectiveWarpIsolate(Map<String, dynamic> args) {
  final bytes = args['bytes'] as Uint8List;
  final raw = (args['corners'] as List).cast<double>();

  final src = imge.decodeImage(bytes);
  if (src == null || raw.length < 8) return bytes;

  final tl = _V(raw[0], raw[1]);
  final tr = _V(raw[2], raw[3]);
  final br = _V(raw[4], raw[5]);
  final bl = _V(raw[6], raw[7]);

  // Natural output size from quad edge lengths
  final w = math.max(_d(tl, tr), _d(bl, br)).round().clamp(1, 6000);
  final h = math.max(_d(tl, bl), _d(tr, br)).round().clamp(1, 6000);

  // Homography: dst rect → src quad (inverse warp avoids holes)
  final hMat = _homography(
    src: [_V(0, 0), _V(w.toDouble(), 0), _V(w.toDouble(), h.toDouble()), _V(0, h.toDouble())],
    dst: [tl, tr, br, bl],
  );

  final dst = imge.Image(width: w, height: h);
  for (int y = 0; y < h; y++) {
    for (int x = 0; x < w; x++) {
      final sp = _applyH(hMat, x.toDouble(), y.toDouble());
      dst.setPixel(x, y, _bilinear(src,
          sp.x.clamp(0.0, src.width - 1.0),
          sp.y.clamp(0.0, src.height - 1.0)));
    }
  }
  return Uint8List.fromList(imge.encodeJpg(dst, quality: 90));
}

/// Analyse a camera frame (Y-plane) for blur and stability.
/// Args: {y: Uint8List, w: int, h: int, prev: Uint8List?}
/// Returns: {blur: double, lum: double, diff: double}
Map<String, dynamic> analyzeFrameIsolate(Map<String, dynamic> args) {
  final Uint8List y = args['y'] as Uint8List;
  final int w = args['w'] as int;
  final int h = args['h'] as int;
  final Uint8List? prev = args['prev'] as Uint8List?;

  // Subsample to ~100×100 grid
  final step = math.max(1, (math.sqrt((w * h).toDouble()) / 100).ceil());

  double lapSum = 0, lapSumSq = 0, lumSum = 0;
  int count = 0;

  for (int row = step; row < h - step; row += step) {
    for (int col = step; col < w - step; col += step) {
      final i = row * w + col;
      if (i >= y.length) continue;
      final c     = y[i];
      final top   = y[math.max(0, row - step) * w + col];
      final bot   = y[math.min(h - 1, row + step) * w + col];
      final left  = y[row * w + math.max(0, col - step)];
      final right = y[row * w + math.min(w - 1, col + step)];
      final lap   = (4 * c - top - bot - left - right).toDouble();
      lapSum   += lap;
      lapSumSq += lap * lap;
      lumSum   += c;
      count++;
    }
  }

  if (count == 0) return {'blur': 0.0, 'lum': 0.0, 'diff': 0.0};
  final mean = lapSum / count;
  final blur = (lapSumSq / count) - (mean * mean);
  final lum  = lumSum / count;

  // Frame-to-frame difference (stability)
  double diff = 0;
  if (prev != null) {
    double ds = 0;
    int dc = 0;
    for (int i = 0; i < y.length; i += step * 3) {
      if (i < prev.length) {
        ds += (y[i] - prev[i]).abs();
        dc++;
      }
    }
    diff = dc > 0 ? ds / dc : 0;
  }

  return {'blur': blur, 'lum': lum, 'diff': diff};
}

// ══════════════════════════════════════════════════════════════════════════════
// FILTER IMPLEMENTATIONS (pure functions, called inside isolates)
// ══════════════════════════════════════════════════════════════════════════════

imge.Image _applyFilter(imge.Image img, int filter) {
  switch (filter) {
    case 0: return _documentEnhance(img);
    case 1: return _unsharpMask(img, amount: 1.2);
    case 2: return imge.adjustColor(img, gamma: 0.7, contrast: 1.7, brightness: 1.3, saturation: 0.8);
    case 3: return imge.adjustColor(img, gamma: 0.9, contrast: 1.2, brightness: 0.9, saturation: 1.0);
    case 4:
      final g = imge.grayscale(img);
      return imge.adjustColor(g, contrast: 1.4, brightness: 1.1);
    case 5: return _autoContrast(img);
    case 6: return img;
    default: return img;
  }
}

/// Classic 3-level document tone enhancement (whitens backgrounds, darkens ink).
imge.Image _documentEnhance(imge.Image image) {
  const th  = 0.35;
  const th2 = 0.29;
  const th3 = 0.32;
  final out = imge.Image(width: image.width, height: image.height);
  for (int y = 0; y < image.height; y++) {
    for (int x = 0; x < image.width; x++) {
      final p    = image.getPixel(x, y);
      final gray = (p.r + p.g + p.b).toInt() ~/ 3;
      if (gray > 150) {
        out.setPixel(x, y, imge.ColorRgb8(
          (p.r + p.r * th).clamp(0, 255).toInt(),
          (p.g + p.g * th).clamp(0, 255).toInt(),
          (p.b + p.b * th).clamp(0, 255).toInt()));
      } else if (gray > 90) {
        out.setPixel(x, y, imge.ColorRgb8(
          (p.r + p.r * th2).clamp(0, 255).toInt(),
          (p.g + p.g * th2).clamp(0, 255).toInt(),
          (p.b + p.b * th2).clamp(0, 255).toInt()));
      } else {
        out.setPixel(x, y, imge.ColorRgb8(
          (p.r - p.r * th3).clamp(0, 255).toInt(),
          (p.g - p.g * th3).clamp(0, 255).toInt(),
          (p.b - p.b * th3).clamp(0, 255).toInt()));
      }
    }
  }
  return out;
}

/// Histogram stretch (1%–99% percentile clip) for auto-contrast.
imge.Image _autoContrast(imge.Image img) {
  final counts = List.filled(256, 0);
  for (int y = 0; y < img.height; y++) {
    for (int x = 0; x < img.width; x++) {
      final p    = img.getPixel(x, y);
      final luma = (p.r * 299 + p.g * 587 + p.b * 114) ~/ 1000;
      counts[luma.clamp(0, 255)]++;
    }
  }
  final total = img.width * img.height;
  final lo = (total * 0.01).round();
  final hi = (total * 0.99).round();
  int cumul = 0, low = 0, high = 255;
  for (int i = 0; i < 256; i++) {
    cumul += counts[i];
    if (cumul <= lo) low = i;
    if (cumul <= hi) high = i;
  }
  if (high <= low) return img;
  final scale = 255.0 / (high - low);
  final out   = imge.Image(width: img.width, height: img.height);
  for (int y = 0; y < img.height; y++) {
    for (int x = 0; x < img.width; x++) {
      final p = img.getPixel(x, y);
      out.setPixel(x, y, imge.ColorRgb8(
        ((p.r - low) * scale).clamp(0.0, 255.0).toInt(),
        ((p.g - low) * scale).clamp(0.0, 255.0).toInt(),
        ((p.b - low) * scale).clamp(0.0, 255.0).toInt()));
    }
  }
  return out;
}

/// Unsharp mask: out = original + amount × (original − blurred).
imge.Image _unsharpMask(imge.Image img, {double amount = 0.5, int radius = 2}) {
  final blurred = imge.gaussianBlur(img, radius: radius);
  final out     = imge.Image(width: img.width, height: img.height);
  for (int y = 0; y < img.height; y++) {
    for (int x = 0; x < img.width; x++) {
      final o = img.getPixel(x, y);
      final b = blurred.getPixel(x, y);
      out.setPixel(x, y, imge.ColorRgb8(
        (o.r + amount * (o.r - b.r)).clamp(0.0, 255.0).toInt(),
        (o.g + amount * (o.g - b.g)).clamp(0.0, 255.0).toInt(),
        (o.b + amount * (o.b - b.b)).clamp(0.0, 255.0).toInt()));
    }
  }
  return out;
}

/// Laplacian variance — proxy for sharpness (higher = sharper).
double _laplacianVariance(imge.Image img) {
  final small = imge.copyResize(img, width: 200);
  double sum = 0, sumSq = 0;
  int count   = 0;
  for (int y = 1; y < small.height - 1; y++) {
    for (int x = 1; x < small.width - 1; x++) {
      final c   = _luma(small.getPixel(x, y));
      final lap = 4 * c
          - _luma(small.getPixel(x, y - 1))
          - _luma(small.getPixel(x, y + 1))
          - _luma(small.getPixel(x - 1, y))
          - _luma(small.getPixel(x + 1, y));
      sum   += lap;
      sumSq += lap * lap;
      count++;
    }
  }
  if (count == 0) return 0;
  final m = sum / count;
  return (sumSq / count) - (m * m);
}

double _luma(imge.Pixel p) => p.r * 0.299 + p.g * 0.587 + p.b * 0.114;

// ══════════════════════════════════════════════════════════════════════════════
// PERSPECTIVE WARP MATH
// ══════════════════════════════════════════════════════════════════════════════

class _V {
  final double x, y;
  const _V(this.x, this.y);
}

double _d(_V a, _V b) {
  final dx = a.x - b.x, dy = a.y - b.y;
  return math.sqrt(dx * dx + dy * dy);
}

/// DLT homography from 4 src→dst point pairs.
/// Maps src[i] → dst[i] using the 8-DOF projective transform.
List<double> _homography({
  required List<_V> src,
  required List<_V> dst,
}) {
  final a = List.generate(8, (_) => List.filled(8, 0.0));
  final b = List.filled(8, 0.0);
  for (int i = 0; i < 4; i++) {
    final sx = src[i].x, sy = src[i].y;
    final dx = dst[i].x, dy = dst[i].y;
    final r0 = i * 2, r1 = r0 + 1;
    a[r0] = [sx, sy, 1, 0, 0, 0, -dx * sx, -dx * sy];
    b[r0] = dx;
    a[r1] = [0, 0, 0, sx, sy, 1, -dy * sx, -dy * sy];
    b[r1] = dy;
  }
  final h = _gaussElim(a, b);
  return [...h, 1.0];
}

List<double> _gaussElim(List<List<double>> a, List<double> b) {
  final n = a.length;
  for (int col = 0; col < n; col++) {
    int maxRow = col;
    for (int row = col + 1; row < n; row++) {
      if (a[row][col].abs() > a[maxRow][col].abs()) maxRow = row;
    }
    final tmpR = a[col]; a[col] = a[maxRow]; a[maxRow] = tmpR;
    final tmpB = b[col]; b[col] = b[maxRow]; b[maxRow] = tmpB;
    final pivot = a[col][col];
    if (pivot.abs() < 1e-12) continue;
    for (int row = col + 1; row < n; row++) {
      final f = a[row][col] / pivot;
      for (int c = col; c < n; c++) { a[row][c] -= f * a[col][c]; }
      b[row] -= f * b[col];
    }
  }
  final x = List.filled(n, 0.0);
  for (int i = n - 1; i >= 0; i--) {
    x[i] = b[i];
    for (int j = i + 1; j < n; j++) { x[i] -= a[i][j] * x[j]; }
    if (a[i][i].abs() > 1e-12) x[i] /= a[i][i];
  }
  return x;
}

_V _applyH(List<double> h, double x, double y) {
  final w = h[6] * x + h[7] * y + h[8];
  if (w.abs() < 1e-12) return const _V(0, 0);
  return _V((h[0] * x + h[1] * y + h[2]) / w,
            (h[3] * x + h[4] * y + h[5]) / w);
}

imge.Color _bilinear(imge.Image img, double x, double y) {
  final x0 = x.floor().clamp(0, img.width - 1);
  final y0 = y.floor().clamp(0, img.height - 1);
  final x1 = (x0 + 1).clamp(0, img.width - 1);
  final y1 = (y0 + 1).clamp(0, img.height - 1);
  final fx = x - x0, fy = y - y0;
  final p00 = img.getPixel(x0, y0);
  final p10 = img.getPixel(x1, y0);
  final p01 = img.getPixel(x0, y1);
  final p11 = img.getPixel(x1, y1);
  double lerp2(num a, num b, num c, num d) =>
      a * (1 - fx) * (1 - fy) + b * fx * (1 - fy) + c * (1 - fx) * fy + d * fx * fy;
  return imge.ColorRgb8(
    lerp2(p00.r, p10.r, p01.r, p11.r).clamp(0, 255).toInt(),
    lerp2(p00.g, p10.g, p01.g, p11.g).clamp(0, 255).toInt(),
    lerp2(p00.b, p10.b, p01.b, p11.b).clamp(0, 255).toInt());
}

// ══════════════════════════════════════════════════════════════════════════════
// SERVICE API (callable from the UI)
// ══════════════════════════════════════════════════════════════════════════════

class ImagePipelineService {
  ImagePipelineService._();

  /// Full pipeline: decode → resize → auto-contrast → noise → filter → sharpen → encode.
  static Future<PipelineResult?> processDocument(File src, {int filter = 0}) async {
    final bytes  = await src.readAsBytes();
    final result = await compute(fullPipelineIsolate, {'bytes': bytes, 'filter': filter});
    if (result['error'] == true) return null;
    final path = await _writeTmp('proc', result['bytes'] as Uint8List);
    return PipelineResult(file: File(path), blurScore: (result['blur'] as num).toDouble());
  }

  /// Apply one filter to already-processed bytes (fast — no full pipeline).
  static Future<File?> applyFilter(File src, int filter) async {
    final bytes   = await src.readAsBytes();
    final outBytes = await compute(applyFilterIsolate, {'bytes': bytes, 'filter': filter});
    return File(await _writeTmp('filt$filter', outBytes));
  }

  /// Generate 7 filter thumbnails (60 px wide) in one isolate call.
  static Future<List<Uint8List>> generateThumbnails(File src) async {
    final bytes = await src.readAsBytes();
    return compute(generateThumbnailsIsolate, bytes);
  }

  /// Perspective warp using 4 corner points in image-space pixels.
  static Future<File?> perspectiveWarp(File src, List<double> corners) async {
    final bytes    = await src.readAsBytes();
    final outBytes = await compute(perspectiveWarpIsolate, {'bytes': bytes, 'corners': corners});
    return File(await _writeTmp('crop', outBytes));
  }

  /// Analyse one camera frame.
  static Future<Map<String, dynamic>> analyzeFrame(
      Uint8List yPlane, int w, int h, Uint8List? prev) =>
      compute(analyzeFrameIsolate, {'y': yPlane, 'w': w, 'h': h, 'prev': prev});

  static Future<String> _writeTmp(String tag, Uint8List bytes) async {
    final dir  = await getTemporaryDirectory();
    final path = '${dir.path}/${tag}_${DateTime.now().millisecondsSinceEpoch}.jpg';
    await File(path).writeAsBytes(bytes);
    return path;
  }
}
