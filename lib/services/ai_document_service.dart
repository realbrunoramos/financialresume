/// AiDocumentService — production-grade hybrid OCR + AI document pipeline.
///
/// Processing order per request:
///   1. Subscription plan check (premium gate)
///   2. Daily usage-limit check
///   3. Cache lookup (7-day TTL)
///   4. Sliding-window rate limiter (14 req / 60 s)
///   5. Gemini API call with exponential-backoff retry (3 attempts)
///   6. Token usage recording
///   7. Merge AI fields with OcrParserService fallback for UNKNOWN slots
///   8. Anomaly detection + insight extraction
///   9. Cache store
///  10. Graceful OCR fallback on any hard failure
library;

import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:http/http.dart' as http;

import 'ai_cache_service.dart';
import 'ocr_parser_service.dart';
import 'secure_storage_service.dart';
import 'subscription_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Result types
// ─────────────────────────────────────────────────────────────────────────────

class AiAnalysisResult {
  /// Full extracted field map (compatible with legacy _aiAnalysis format).
  final Map<String, dynamic> fields;

  /// 0–10 blended confidence (OCR + AI signals).
  final int confidence;

  /// Origin: 'ai' | 'cache' | 'ocr_fallback' | 'ocr_free' | 'ocr_limit'
  final String source;

  /// Model name used (null when falling back to OCR).
  final String? model;

  /// Detected expense category slug (food, utilities, transport …).
  final String? category;

  /// Canonical merchant / entity name as identified by the AI.
  final String? merchantName;

  /// Non-null when the AI flagged a potential anomaly.
  final AnomalyInfo? anomaly;

  /// Short financial observations produced by the AI.
  final List<String> insights;

  const AiAnalysisResult({
    required this.fields,
    required this.confidence,
    required this.source,
    this.model,
    this.category,
    this.merchantName,
    this.anomaly,
    this.insights = const [],
  });

  bool get isFromAi    => source == 'ai';
  bool get isFromCache => source == 'cache';
  bool get isFallback  => source.startsWith('ocr');

  // Serialise for SQLite cache (meta fields prefixed with '__').
  Map<String, dynamic> toMap() => {
    ...fields,
    '__source':     source,
    '__model':      model,
    '__category':   category,
    '__merchant':   merchantName,
    '__anomaly':    anomaly?.toMap(),
    '__insights':   insights,
    '__confidence': confidence,
  };

  factory AiAnalysisResult.fromMap(
      Map<String, dynamic> m, {required String source}) {
    final raw = m['__anomaly'];
    return AiAnalysisResult(
      fields:       Map<String, dynamic>.from(m)
          ..removeWhere((k, _) => k.startsWith('__')),
      confidence:   (m['__confidence'] as int?) ?? 5,
      source:       source,
      model:        m['__model'] as String?,
      category:     m['__category'] as String?,
      merchantName: m['__merchant'] as String?,
      anomaly:      raw != null
          ? AnomalyInfo.fromMap(Map<String, dynamic>.from(raw as Map))
          : null,
      insights:     (m['__insights'] as List?)
              ?.map((e) => e.toString()).toList() ??
          [],
    );
  }
}

class AnomalyInfo {
  final bool detected;
  final String? description;

  /// 0.0 (informational) → 1.0 (high severity)
  final double severity;

  const AnomalyInfo({
    required this.detected,
    this.description,
    this.severity = 0.5,
  });

  Map<String, dynamic> toMap() => {
    'detected':    detected,
    'description': description,
    'severity':    severity,
  };

  factory AnomalyInfo.fromMap(Map<String, dynamic> m) => AnomalyInfo(
    detected:    m['detected'] as bool? ?? false,
    description: m['description'] as String?,
    severity:    (m['severity'] as num?)?.toDouble() ?? 0.5,
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// Internal exception types
// ─────────────────────────────────────────────────────────────────────────────

class _RateLimitException implements Exception {
  @override String toString() => 'RateLimitException';
}

class _ApiException implements Exception {
  final int    statusCode;
  final String body;
  _ApiException(this.statusCode, this.body);
  @override String toString() => 'ApiException($statusCode)';
}

// ─────────────────────────────────────────────────────────────────────────────
// Sliding-window rate limiter (14 requests / 60 s)
// Gemini free tier allows 15/min; we use 14 for headroom.
// ─────────────────────────────────────────────────────────────────────────────

class _RateLimiter {
  static const int      _maxReqs = 14;
  static const Duration _window  = Duration(minutes: 1);
  static final Queue<DateTime> _ts = Queue<DateTime>();

  static Future<void> waitIfNeeded() async {
    while (true) {
      final now = DateTime.now();
      while (_ts.isNotEmpty && now.difference(_ts.first) >= _window) {
        _ts.removeFirst();
      }
      if (_ts.length < _maxReqs) {
        _ts.add(now);
        return;
      }
      final waitMs =
          _window.inMilliseconds - now.difference(_ts.first).inMilliseconds + 100;
      await Future.delayed(Duration(milliseconds: waitMs.clamp(100, 62000)));
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// AiDocumentService
// ─────────────────────────────────────────────────────────────────────────────

class AiDocumentService {
  AiDocumentService._();

  static const String _model    = 'gemini-2.5-flash';
  static const String _endpoint =
      'https://generativelanguage.googleapis.com/v1beta/models/$_model:generateContent';

  // ── Public entry point ─────────────────────────────────────────────────────

  static Future<AiAnalysisResult> analyze({
    required String imagePath,
    required String ocrText,
    RecognizedText? recognizedText,
    required String sectionId,
    required String promptLanguage,
    List<String> existingInvoices = const [],
  }) async {
    // 1. Plan gate
    final plan = await SubscriptionService.getCurrentPlan();
    if (plan == AppPlan.free) {
      return _fallback(ocrText, recognizedText, 'ocr_free');
    }

    // 2. Daily limit gate
    if (!await SubscriptionService.canUseAi()) {
      debugPrint('[AiDocumentService] Daily limit reached — OCR fallback');
      return _fallback(ocrText, recognizedText, 'ocr_limit');
    }

    // 3. Cache lookup
    final cacheKey = AiCacheService.computeKey(ocrText);
    try {
      final cached = await AiCacheService.lookup(cacheKey);
      if (cached != null) {
        debugPrint('[AiDocumentService] Cache hit $cacheKey');
        return AiAnalysisResult.fromMap(cached, source: 'cache');
      }
    } catch (e) {
      debugPrint('[AiDocumentService] Cache lookup error: $e');
    }

    // 4. API key
    final apiKey = await SecureStorageService.readApiKey();
    if (apiKey == null || apiKey.isEmpty) {
      return _fallback(ocrText, recognizedText, 'ocr_free');
    }

    // 5. Rate-limited call with exponential-backoff retry
    Map<String, dynamic>? aiFields;
    Exception? lastErr;

    for (int attempt = 0; attempt < 3; attempt++) {
      try {
        await _RateLimiter.waitIfNeeded();
        aiFields = await _callGemini(
            imagePath, ocrText, promptLanguage, existingInvoices, apiKey);
        break;
      } on _RateLimitException {
        final delay = Duration(seconds: (attempt + 1) * 4);
        debugPrint('[AiDocumentService] Rate limit hit, waiting ${delay.inSeconds}s');
        await Future.delayed(delay);
      } on TimeoutException catch (e) {
        lastErr = e;
        debugPrint('[AiDocumentService] Timeout attempt ${attempt + 1}: $e');
        if (attempt < 2) { await Future.delayed(Duration(seconds: (attempt + 1) * 3)); }
      } on _ApiException catch (e) {
        lastErr = e;
        debugPrint('[AiDocumentService] API error: $e');
        if (e.statusCode == 429) {
          await Future.delayed(Duration(seconds: (attempt + 1) * 5));
        } else {
          break; // Non-retryable HTTP error
        }
      } catch (e) {
        lastErr = Exception(e.toString());
        debugPrint('[AiDocumentService] Unexpected error attempt ${attempt + 1}: $e');
        break;
      }
    }

    if (aiFields == null) {
      debugPrint('[AiDocumentService] All retries exhausted ($lastErr)');
      return _fallback(ocrText, recognizedText, 'ocr_timeout');
    }

    // 6. Record usage (fire-and-forget)
    final tokens = _estimateTokens(ocrText);
    SubscriptionService.recordAiCall(tokensUsed: tokens);

    // 7. Merge AI fields with OCR fallback for UNKNOWN slots
    final ocr    = OcrParserService.parse(ocrText, recognizedText: recognizedText);
    final merged = _mergeResults(aiFields, ocr);

    // 8. Extract premium fields
    final category   = _canonicalCategory(aiFields['categoria'] as String?);
    final merchant   = _nvl(aiFields['comerciante'] as String?);
    final anomalyStr = aiFields['anomalia'] as String?;
    final insightsRaw = aiFields['insights'];

    final anomaly = (anomalyStr != null &&
            anomalyStr.isNotEmpty &&
            anomalyStr.toUpperCase() != 'NONE')
        ? AnomalyInfo(detected: true, description: anomalyStr, severity: 0.5)
        : null;

    final insights = _parseInsights(insightsRaw);
    final confidence = _blendConfidence(ocr.confidence, aiFields);

    // Strip AI-only meta keys from the stored fields map
    final cleanFields = Map<String, dynamic>.from(merged)
      ..remove('categoria')
      ..remove('comerciante')
      ..remove('anomalia')
      ..remove('insights');

    final result = AiAnalysisResult(
      fields:       cleanFields,
      confidence:   confidence,
      source:       'ai',
      model:        _model,
      category:     category,
      merchantName: merchant,
      anomaly:      anomaly,
      insights:     insights,
    );

    // 9. Cache result (fire-and-forget)
    AiCacheService.store(cacheKey, result.toMap(), model: _model);

    return result;
  }

  // ── Gemini REST call ───────────────────────────────────────────────────────

  static Future<Map<String, dynamic>> _callGemini(
    String imagePath,
    String ocrText,
    String promptLanguage,
    List<String> existingInvoices,
    String apiKey,
  ) async {
    final imageBytes  = await File(imagePath).readAsBytes();
    final imageBase64 = base64Encode(imageBytes);
    final invStr      = existingInvoices.join('\n');
    final prompt      = _buildPrompt(promptLanguage, invStr, ocrText);

    final url  = Uri.parse('$_endpoint?key=$apiKey');
    final body = jsonEncode({
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
      ],
      'generationConfig': {
        'temperature':      0.1,
        'maxOutputTokens':  600,
        'responseMimeType': 'application/json',
      },
      'safetySettings': [
        {'category': 'HARM_CATEGORY_HARASSMENT',        'threshold': 'BLOCK_NONE'},
        {'category': 'HARM_CATEGORY_HATE_SPEECH',       'threshold': 'BLOCK_NONE'},
        {'category': 'HARM_CATEGORY_SEXUALLY_EXPLICIT', 'threshold': 'BLOCK_NONE'},
        {'category': 'HARM_CATEGORY_DANGEROUS_CONTENT', 'threshold': 'BLOCK_NONE'},
      ],
    });

    final response = await http
        .post(url, headers: {'Content-Type': 'application/json'}, body: body)
        .timeout(const Duration(seconds: 60));

    if (response.statusCode == 429) { throw _RateLimitException(); }
    if (response.statusCode != 200) {
      throw _ApiException(response.statusCode, response.body);
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    String? text;
    try {
      text = data['candidates'][0]['content']['parts'][0]['text'] as String;
    } catch (_) {
      throw _ApiException(200, 'Unexpected Gemini response structure');
    }

    // Gemini with responseMimeType=application/json returns raw JSON
    try {
      return jsonDecode(text) as Map<String, dynamic>;
    } catch (_) {
      // Fallback: extract first {...} block from text
      final m = RegExp(r'\{[\s\S]*\}').firstMatch(text);
      if (m == null) { throw _ApiException(200, 'No JSON found in response'); }
      return jsonDecode(m.group(0)!) as Map<String, dynamic>;
    }
  }

  // ── Prompt ─────────────────────────────────────────────────────────────────

  static String _buildPrompt(
      String lang, String invoices, String ocrText) {
    final ocrSnippet = ocrText.length > 1200
        ? '${ocrText.substring(0, 1200)}…'
        : ocrText;
    return '''
Analyse this financial document image and the pre-extracted OCR text.
Return ONLY a valid JSON object — no markdown, no explanation.

OCR text (reference):
$ocrSnippet

Existing invoices in system (for duplicate/match detection):
${invoices.isEmpty ? 'none' : invoices}

Required JSON schema (all fields mandatory):
{
  "tipo_documento": <integer: 1=Purchase 2=Invoice/Bill 3=PaymentProof 4=Other>,
  "entidade": "<company or person | UNKNOWN>",
  "data_emissao": "<dd mm yyyy | UNKNOWN>",
  "valor_total": "<plain numeric string e.g. 42.50 | UNKNOWN>",
  "data_limite": "<dd mm yyyy | UNKNOWN>",
  "é_crédito": "<0 or 1 | UNKNOWN>",
  "mes_ano_ref": "<mm/yyyy | UNKNOWN>",
  "descrição": "<one-sentence description | UNKNOWN>",
  "ids_ref_fatura": "<matching existing invoice id(s) | UNKNOWN>",
  "numero_serie": "<invoice or serial number | UNKNOWN>",
  "metodo_pagamento": "<payment method | UNKNOWN>",
  "categoria": "<one of: food utilities transport health shopping services entertainment education housing insurance taxes other>",
  "comerciante": "<canonical merchant name | UNKNOWN>",
  "anomalia": "<describe if amount suspicious/duplicate/outlier, else NONE>",
  "insights": "<comma-separated financial observations e.g. recurring charge, higher than usual | NONE>"
}

Output language: $lang
Rules:
- valor_total: plain number without currency symbol
- Dates: "dd mm yyyy" format
- Use UNKNOWN for uncertain fields
- Anomaly: flag if matches existing invoice amount/entity or is unusually large''';
  }

  // ── Merge AI + OCR ─────────────────────────────────────────────────────────

  static Map<String, dynamic> _mergeResults(
      Map<String, dynamic> ai, OcrParserResult ocr) {
    final out = Map<String, dynamic>.from(ai);

    void fill(String aiKey, String ocrKey) {
      final v = out[aiKey]?.toString() ?? '';
      if (v.isEmpty || v == 'UNKNOWN') {
        final ocrVal = ocr.fields[ocrKey]?.toString() ?? '';
        if (ocrVal.isNotEmpty) { out[aiKey] = ocrVal; }
      }
    }

    fill('valor_total',      'valor_total');
    fill('entidade',         'entidade');
    fill('data_emissao',     'data_emissao');
    fill('data_limite',      'data_limite');
    fill('mes_ano_ref',      'mes_ano_ref');
    fill('numero_serie',     'numero_serie');
    fill('metodo_pagamento', 'metodo_pagamento');
    fill('é_crédito',       'é_crédito');
    return out;
  }

  // ── OCR fallback ───────────────────────────────────────────────────────────

  static AiAnalysisResult _fallback(
      String ocrText, RecognizedText? rt, String source) {
    final ocr = OcrParserService.parse(ocrText, recognizedText: rt);
    return AiAnalysisResult(
      fields:     ocr.fields,
      confidence: ocr.confidence,
      source:     source,
      insights:   const [],
    );
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  /// Blend OCR confidence (0–5) and AI field completeness into a 0–10 score.
  static int _blendConfidence(int ocrConf, Map<String, dynamic> ai) {
    const keys = [
      'entidade', 'valor_total', 'data_emissao', 'tipo_documento', 'mes_ano_ref'
    ];
    final aiScore = keys.where((k) {
      final v = ai[k]?.toString() ?? '';
      return v.isNotEmpty && v != 'UNKNOWN';
    }).length; // 0-5
    return ((aiScore * 2 + ocrConf * 2) ~/ 2).clamp(0, 10);
  }

  /// Rough token estimate: 4 chars ≈ 1 text token, image ≈ 258 tokens.
  static int _estimateTokens(String ocrText) =>
      (ocrText.length / 4).ceil() + 258;

  static String? _canonicalCategory(String? raw) {
    if (raw == null || raw.toUpperCase() == 'UNKNOWN') { return null; }
    const valid = {
      'food', 'utilities', 'transport', 'health', 'shopping', 'services',
      'entertainment', 'education', 'housing', 'insurance', 'taxes', 'other',
    };
    final lower = raw.toLowerCase().trim();
    return valid.contains(lower) ? lower : 'other';
  }

  static String? _nvl(String? s) =>
      (s == null || s.isEmpty || s.toUpperCase() == 'UNKNOWN') ? null : s;

  static List<String> _parseInsights(dynamic raw) {
    if (raw == null) { return const []; }
    final s = raw.toString().trim();
    if (s.isEmpty || s.toUpperCase() == 'NONE') { return const []; }
    return s.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
  }
}
