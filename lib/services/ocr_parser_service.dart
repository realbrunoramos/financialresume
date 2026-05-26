/// OcrParserService — professional multi-language financial document parser.
///
/// Runs entirely on-device (no API key). Uses a scored candidate algorithm
/// for total-amount detection, OCR error correction, positional analysis
/// when ML Kit's [RecognizedText] object is supplied, and language-aware
/// keyword tables covering PT / EN / ES / FR / DE / IT / RU / ZH.
///
/// Confidence 0–5: counts how many of the five key fields could be extracted
/// (entity, emissionDate, amount, invoiceNumber, monthYearRef).
library;

import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Public result type
// ─────────────────────────────────────────────────────────────────────────────

class OcrParserResult {
  final Map<String, dynamic> fields;

  /// 0–5: number of key fields successfully extracted.
  final int confidence;

  /// ISO language code detected in the document, e.g. 'pt', 'en'.
  final String detectedLanguage;

  const OcrParserResult({
    required this.fields,
    required this.confidence,
    this.detectedLanguage = 'en',
  });
}

// ─────────────────────────────────────────────────────────────────────────────
// Internal: scored amount candidate
// ─────────────────────────────────────────────────────────────────────────────

class _Candidate {
  final String normalised; // always "NNN.NN"
  final double value;
  int score;
  final int lineIndex;

  _Candidate({
    required this.normalised,
    required this.value,
    required this.score,
    required this.lineIndex,
  });
}

// ─────────────────────────────────────────────────────────────────────────────
// Service
// ─────────────────────────────────────────────────────────────────────────────

class OcrParserService {
  OcrParserService._();

  // ── Total-keyword weights ────────────────────────────────────────────────────
  // 10 (weak signal) → 50 (very strong). Presence on the same line as a
  // candidate amount adds the full weight; within ±2 lines adds 40 %.
  static const Map<String, int> _totalKw = {
    // Portuguese
    'total a pagar': 50,       'total a liquidar': 50,
    'valor a pagar': 48,       'montante a pagar': 48,
    'total com iva': 46,       'total fatura': 46,
    'total c/ iva': 46,        'total s/ iva': 40,
    'valor total': 44,         'total geral': 44,
    'total final': 44,         'total incl.': 42,
    // English
    'grand total': 50,         'amount due': 50,
    'total due': 49,           'balance due': 48,
    'total payable': 48,       'amount payable': 48,
    'total amount': 46,        'net amount due': 48,
    'total charged': 44,       'net total': 42,
    // Spanish
    'importe total': 48,       'total factura': 48,
    'monto total': 46,         'total a abonar': 48,
    'importe a pagar': 48,     'cantidad a pagar': 46,
    // French
    'total ttc': 50,           'montant total': 48,
    'total à payer': 48,       'net à payer': 49,
    'montant à régler': 48,    'solde dû': 46,
    'total tva comprise': 45,  'montant dû': 46,
    // German
    'gesamtbetrag': 50,        'zu zahlen': 48,
    'endbetrag': 48,           'rechnungsbetrag': 46,
    'zu zahlender betrag': 50, 'gesamt': 38,
    // Italian
    'totale a pagare': 50,     'totale da pagare': 50,
    'totale fattura': 48,      'importo totale': 46,
    'totale complessivo': 46,  'netto a pagare': 49,
    // Russian
    'итого к оплате': 50,      'к оплате': 48,
    'сумма к оплате': 48,      'итоговая сумма': 46,
    'итого': 35,
    // Chinese
    '应付总额': 50, '合计': 40, '总计': 40, '总额': 38, '应付': 36,
    // Generic / medium (matched last, lower weight)
    'total': 30,   'montant': 24, 'importe': 24,
    'totale': 28,  'betrag': 22,  'сумма': 22,
    '金额': 20,
  };

  // Penalise — if any of these appear on the same / preceding line the
  // candidate is likely a line-item subtotal, not the grand total.
  static const Map<String, int> _penaltyKw = {
    'subtotal': 25,        'sub total': 25,     'sub-total': 25,
    'iva s/': 18,          'base iva': 18,
    'unit price': 22,      'precio unitario': 22, 'prix unitaire': 22,
    'prezzo unitario': 22, 'einzelpreis': 22,   'единицу': 22,
    '单价': 22,
    'desconto': 18,        'discount': 18,      'descuento': 18,
    'rabais': 18,          'rabatt': 18,        'sconto': 18,
    'iva': 12,             'vat': 12,           'tva': 12,
    'mwst': 12,            'taxa': 12,          'imposto': 12,
    'tax': 10,
  };

  // ── Language-detection keyword sets ──────────────────────────────────────────
  static const Map<String, List<String>> _langKw = {
    'pt': ['fatura', 'vencimento', 'pagamento', 'nif', 'emissão',
           'obrigado', 'empresa', 'contribuinte', 'nipc'],
    'en': ['invoice', 'due date', 'vat number', 'receipt', 'thank you',
           'company', 'issued', 'payment'],
    'es': ['factura', 'vencimiento', 'empresa', 'importe', 'rfc',
           'recibo', 'gracias', 'fecha de emision'],
    'fr': ['facture', 'échéance', 'entreprise', 'tva', 'reçu',
           'merci', "date d'émission", 'paiement'],
    'de': ['rechnung', 'fälligkeit', 'unternehmen', 'mwst', 'quittung',
           'danke', 'rechnungsdatum', 'lieferdatum'],
    'it': ['fattura', 'scadenza', 'azienda', 'p.iva', 'ricevuta',
           'grazie', 'data fattura', 'partita iva'],
    'ru': ['счёт', 'оплата', 'итого', 'организация', 'ндс',
           'квитанция', 'дата', 'сумма'],
    'zh': ['发票', '付款', '合计', '公司', '税', '收据', '日期'],
  };

  // ── Document-type keyword sets ────────────────────────────────────────────────
  static const List<String> _paymentKw = [
    'comprovativo', 'comprovante', 'payment proof', 'comprobante de pago',
    'preuve de paiement', 'zahlungsbeleg', 'ricevuta di pagamento',
    'подтверждение оплаты', '付款证明', 'transferência', 'transferencia',
    'pagamento efetuado', 'payment made', 'pago realizado',
    'débito direto', 'débito directo', 'sepa direct', '转账',
  ];
  static const List<String> _invoiceKw = [
    'fatura', 'factura', 'invoice', 'facture', 'rechnung', 'fattura',
    '发票', 'nota de cobrança', 'nota de cobro', 'billing', 'to pay',
    'due date', 'vencimento', 'vencimiento', 'fälligkeit',
    'scadenza', 'срок оплаты', '到期',
  ];
  static const List<String> _receiptKw = [
    'recibo', 'receipt', 'talão', 'reçu', 'quittung', 'ricevuta', '收据',
    'obrigado', 'thank you', 'gracias', 'merci', 'danke', 'grazie', '谢谢',
    'compra', 'ticket de compra', 'sales receipt',
  ];

  // ── Due-date vs emission-date keywords ───────────────────────────────────────
  static const List<String> _dueDateKw = [
    'data limite', 'data de vencimento', 'vencimento', 'vencimiento',
    'due date', 'payment due', 'date limite', "date d'échéance",
    'fälligkeit', 'scadenza', 'срок оплаты', '到期日',
    'pay by', 'pagar até', 'limite de pagamento',
    'data pagamento', 'fecha de pago',
  ];
  static const List<String> _emissionDateKw = [
    'data de emissão', 'data emissão', 'emitido em', 'emitido a',
    'invoice date', 'data fatura', 'fecha de emisión', "date d'émission",
    'rechnungsdatum', 'data fattura', 'дата счёта', '发票日期',
    'data:', 'date:', 'issued:', 'issued on',
  ];

  // ── Payment method keywords → label ─────────────────────────────────────────
  static const Map<String, String> _pmKw = {
    'mb way': 'MB Way',     'mbway': 'MB Way',
    'multibanco': 'Multibanco',
    'paypal': 'PayPal',
    'visa': 'Visa',         'mastercard': 'Mastercard',
    'maestro': 'Maestro',   'amex': 'Amex',
    'american express': 'American Express',
    'débito direto': 'Débito Direto',
    'débito directo': 'Débito Direto',
    'sepa': 'SEPA Direct Debit',
    'transferência bancária': 'Transferência Bancária',
    'transferencia bancaria': 'Transferencia Bancaria',
    'bank transfer': 'Bank Transfer',
    'wire transfer': 'Wire Transfer',
    'dinheiro': 'Dinheiro',   'cash': 'Cash',
    'efectivo': 'Efectivo',   'espèces': 'Espèces',
    'barzahlung': 'Bargeld',
    'cheque': 'Cheque',       'check': 'Check',
    'boleto': 'Boleto',       'pix': 'PIX',
  };

  // ─────────────────────────────────────────────────────────────────────────────
  // Public entry point
  // ─────────────────────────────────────────────────────────────────────────────

  /// Extract financial-document fields from [text] (ML Kit's full text).
  ///
  /// Pass [recognizedText] from ML Kit to enable positional scoring
  /// (larger bounding boxes = bigger font = likely label/total).
  static OcrParserResult parse(String text, {RecognizedText? recognizedText}) {
    if (text.trim().isEmpty) {
      return OcrParserResult(
          fields: _unknownFields(), confidence: 0, detectedLanguage: 'en');
    }

    final corrected   = _correctOcr(text);
    final lower       = corrected.toLowerCase();
    final lines       = corrected.split('\n');
    final linesLower  = lower.split('\n');

    final lang        = _detectLanguage(lower);
    final entity      = _extractEntity(corrected, linesLower);
    final emission    = _extractDate(lines, linesLower, due: false);
    final dueDate     = _extractDate(lines, linesLower, due: true);
    final amount      = _extractTotal(lines, linesLower, recognizedText);
    final invoiceNum  = _extractInvoiceNumber(corrected, lower);
    final monthYear   = _extractMonthYear(corrected, lower);
    final credit      = _detectCredit(lower);
    final docType     = _detectDocType(lower);
    final payMethod   = _extractPaymentMethod(corrected, lower);
    final description = _extractDescription(corrected, lower);
    final currency    = _detectCurrency(corrected);

    int conf = 0;
    if (entity    != 'UNKNOWN') conf++;
    if (emission  != 'UNKNOWN') conf++;
    if (amount    != 'UNKNOWN') conf++;
    if (invoiceNum != 'UNKNOWN') conf++;
    if (monthYear != 'UNKNOWN') conf++;

    return OcrParserResult(
      detectedLanguage: lang,
      confidence: conf,
      fields: {
        'tipo_documento': docType.toString(),
        'entidade': entity,
        'data_emissao': emission,
        'valor_total': amount,
        'data_limite': dueDate,
        'é_crédito': credit,
        'mes_ano_ref': monthYear,
        'descrição': description,
        'ids_ref_fatura': '',
        'numero_serie': invoiceNum,
        'metodo_pagamento': payMethod,
        'moeda': currency,
      },
    );
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // OCR error correction
  // ─────────────────────────────────────────────────────────────────────────────

  /// Corrects common OCR substitutions in numeric contexts only:
  ///   O / o → 0    l / I → 1    S → 5
  /// Only fires when the character is sandwiched between digit characters,
  /// so prose text is unaffected.
  static String _correctOcr(String text) {
    final buf   = StringBuffer();
    final chars = text.runes.toList();
    final isDigit = RegExp(r'\d');

    for (int i = 0; i < chars.length; i++) {
      final c    = String.fromCharCode(chars[i]);
      final prev = i > 0               ? String.fromCharCode(chars[i - 1]) : '';
      final next = i < chars.length - 1 ? String.fromCharCode(chars[i + 1]) : '';
      final pd   = isDigit.hasMatch(prev);
      final nd   = isDigit.hasMatch(next);

      if ((c == 'O' || c == 'o') && pd && nd)      { buf.write('0'); continue; }
      if ((c == 'l' || c == 'I') && pd && nd)       { buf.write('1'); continue; }
      if (c == 'S' && pd && nd)                      { buf.write('5'); continue; }
      buf.write(c);
    }
    return buf.toString();
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // Language detection
  // ─────────────────────────────────────────────────────────────────────────────

  static String _detectLanguage(String lower) {
    final scores = <String, int>{};
    for (final entry in _langKw.entries) {
      scores[entry.key] = entry.value.where(lower.contains).length;
    }
    if (scores.values.every((v) => v == 0)) return 'en';
    return scores.entries.reduce((a, b) => a.value >= b.value ? a : b).key;
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // Document type
  // ─────────────────────────────────────────────────────────────────────────────

  static int _detectDocType(String lower) {
    if (_paymentKw.any(lower.contains)) return 3;
    if (_invoiceKw.any(lower.contains)) return 2;
    if (_receiptKw.any(lower.contains)) return 1;
    return 4;
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // Entity extraction
  // ─────────────────────────────────────────────────────────────────────────────

  static String _extractEntity(String text, List<String> linesLower) {
    final lines = text.split('\n').map((l) => l.trim()).toList();

    final skipRx = [
      RegExp(r'^\d{1,2}[/.\-]\d{1,2}[/.\-]\d{2,4}'), // date
      RegExp(r'^[\d\s€$£.,+\-/()]+$'),                  // pure numeric
    ];
    const skipWords = [
      'nif', 'nipc', 'nº', 'num', 'rua', 'avenida', 'av.', 'street',
      'total', 'iban', 'bic', 'swift', 'vat', 'iva', 'invoice', 'fatura',
      'factura', 'receipt', 'recibo', 'data', 'date', 'ref', 'tel',
      'fax', 'www', 'http', '@', 'cp ', 'c.p.', 'bp ', 'nr.',
    ];

    for (final line in lines.take(8)) {
      if (line.length < 3 || line.length > 70) continue;
      final lo = line.toLowerCase();
      if (skipWords.any(lo.contains)) continue;
      if (skipRx.any((rx) => rx.hasMatch(line))) continue;
      if (!RegExp(r'[A-Za-zÀ-ÿА-яα-ω一-鿿]').hasMatch(line)) continue;
      return line.length <= 50 ? line : line.substring(0, 50);
    }
    return 'UNKNOWN';
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // Total amount — scored candidate algorithm
  // ─────────────────────────────────────────────────────────────────────────────

  static String _extractTotal(
    List<String> lines,
    List<String> linesLower,
    RecognizedText? recognizedText,
  ) {
    final candidates = _findAllAmounts(lines);
    if (candidates.isEmpty) return 'UNKNOWN';

    _scoreByKeywords(candidates, linesLower);
    _scoreByPosition(candidates, lines.length);
    _scoreByMaxValue(candidates);
    if (recognizedText != null) {
      _scoreByVisualSize(candidates, lines, recognizedText);
    }

    final viable = candidates.where((c) => c.score > 0).toList();
    final pool   = viable.isNotEmpty ? viable : candidates;
    pool.sort((a, b) => b.score.compareTo(a.score));

    // Tie-break: among equal scores prefer the one appearing later in the doc
    final best = pool.first.score;
    final topN = pool.where((c) => c.score == best).toList()
      ..sort((a, b) => b.lineIndex.compareTo(a.lineIndex));

    return topN.first.normalised;
  }

  // -- Scan each line for monetary patterns and collect candidates ------------

  static List<_Candidate> _findAllAmounts(List<String> lines) {
    // We track unique (value, lineIndex) pairs so the same amount on different
    // lines (e.g. as a line-item and as the total) is kept separately.
    final results = <_Candidate>[];
    final seenKey = <String>{};

    // Patterns ordered from most to least specific.
    final patterns = [
      // European thousands: 1.234,56  /  1 234,56
      RegExp(r'(\d{1,3}(?:[.\s]\d{3})+,\d{2})\b'),
      // US thousands: 1,234.56
      RegExp(r'(\d{1,3}(?:,\d{3})+\.\d{2})\b'),
      // Simple comma-decimal: 123,56  (no leading/trailing digit)
      RegExp(r'(?<!\d)(\d{1,6},\d{2})(?!\d)'),
      // Simple period-decimal: 123.56
      RegExp(r'(?<!\d)(\d{1,6}\.\d{2})(?!\d)'),
    ];

    for (int li = 0; li < lines.length; li++) {
      final line = lines[li];
      for (final rx in patterns) {
        for (final m in rx.allMatches(line)) {
          final raw  = m.group(1) ?? '';
          if (raw.isEmpty) continue;
          final norm = _normalise(raw);
          if (norm == null) continue;
          final val  = double.tryParse(norm) ?? 0;
          if (val <= 0 || val >= 1000000) continue;

          final key = '$li:$norm';
          if (seenKey.contains(key)) continue;
          seenKey.add(key);

          results.add(_Candidate(
            normalised: norm,
            value: val,
            score: 0,
            lineIndex: li,
          ));
        }
      }
    }
    return results;
  }

  // -- Score: keyword proximity -----------------------------------------------

  static void _scoreByKeywords(
      List<_Candidate> candidates, List<String> linesLower) {
    for (final c in candidates) {
      for (int delta = -3; delta <= 0; delta++) {
        final idx = c.lineIndex + delta;
        if (idx < 0 || idx >= linesLower.length) continue;
        final ll = linesLower[idx];
        final same = delta == 0;

        for (final entry in _totalKw.entries) {
          if (ll.contains(entry.key)) {
            c.score += same ? entry.value : (entry.value * 0.4).round();
          }
        }
        for (final entry in _penaltyKw.entries) {
          if (ll.contains(entry.key)) {
            c.score -= same ? entry.value : (entry.value * 0.3).round();
          }
        }
      }

      // Currency symbol on same line
      final sl = linesLower[c.lineIndex];
      if (_hasCurrencySymbol(sl)) c.score += 8;
    }
  }

  static bool _hasCurrencySymbol(String line) {
    const syms = ['€', r'$', '£', '¥', '₹', '₽', 'eur', 'usd', 'gbp', 'chf'];
    return syms.any(line.contains);
  }

  // -- Score: document position -----------------------------------------------

  static void _scoreByPosition(List<_Candidate> candidates, int totalLines) {
    if (totalLines == 0) return;
    for (final c in candidates) {
      final ratio = c.lineIndex / totalLines;
      if (ratio > 0.75)      { c.score += 20; }
      else if (ratio > 0.5)  { c.score += 10; }
      else if (ratio > 0.3)  { c.score += 4; }
      else                   { c.score -= 4; }
    }
  }

  // -- Score: maximum monetary value (tie-breaker) ----------------------------

  static void _scoreByMaxValue(List<_Candidate> candidates) {
    if (candidates.isEmpty) return;
    final maxVal = candidates.map((c) => c.value).reduce((a, b) => a > b ? a : b);
    for (final c in candidates) {
      if (c.value == maxVal) c.score += 5;
    }
  }

  // -- Score: visual / bounding-box size from ML Kit --------------------------

  static void _scoreByVisualSize(
    List<_Candidate> candidates,
    List<String> lines,
    RecognizedText rt,
  ) {
    // Estimate total document height from all block bounding boxes.
    double maxY = 0;
    for (final block in rt.blocks) {
      final bot = block.boundingBox.bottom;
      if (bot > maxY) maxY = bot;
    }
    if (maxY == 0) return;

    for (final block in rt.blocks) {
      for (final line in block.lines) {
        final bb = line.boundingBox;
        final lineH = bb.height;
        // Vertical position bonus (bottom of page = higher chance of total)
        final posRatio = bb.bottom / maxY;

        final lineText = line.text;
        for (final c in candidates) {
          // Match candidate value against this visual line's text
          final variantComma = c.normalised.replaceAll('.', ',');
          if (!lineText.contains(c.normalised) &&
              !lineText.contains(variantComma)) { continue; }

          // Font-size bonus: larger text → more likely a label or grand total
          // Assume average body text height ≈ 20px; normalise to 0-12 bonus.
          final sizeBonus = ((lineH / 20 - 1) * 4).round().clamp(0, 12);
          c.score += sizeBonus;

          // Position within image (redundant but from real pixel coords)
          if (posRatio > 0.75)     { c.score += 6; }
          else if (posRatio > 0.5) { c.score += 3; }
        }
      }
    }
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // Amount normalisation
  // ─────────────────────────────────────────────────────────────────────────────

  /// Returns a dot-decimal string ("NNN.NN") or null if unparseable.
  static String? _normalise(String raw) {
    var s = raw.replaceAll(' ', '').trim();

    // European: 1.234,56  →  1234.56
    if (RegExp(r'^\d{1,3}(\.\d{3})+,\d{2}$').hasMatch(s)) {
      s = s.replaceAll('.', '').replaceAll(',', '.');
    }
    // US: 1,234.56  →  1234.56
    else if (RegExp(r'^\d{1,3}(,\d{3})+\.\d{2}$').hasMatch(s)) {
      s = s.replaceAll(',', '');
    }
    // Simple comma-decimal: 123,45
    else if (RegExp(r'^\d+,\d{2}$').hasMatch(s)) {
      s = s.replaceAll(',', '.');
    }
    // Already dot-decimal: 123.45 — keep as-is

    final val = double.tryParse(s);
    if (val == null || val <= 0) return null;
    return val.toStringAsFixed(2);
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // Date extraction
  // ─────────────────────────────────────────────────────────────────────────────

  static String _extractDate(
    List<String> lines,
    List<String> linesLower, {
    required bool due,
  }) {
    final kwList = due ? _dueDateKw : _emissionDateKw;

    final numPat = RegExp(r'(\d{1,2})[/.\-\s](\d{1,2})[/.\-\s](\d{4})');
    final isoPat = RegExp(r'(\d{4})[.\-](\d{2})[.\-](\d{2})');

    // 1. Prefer a date found on the same line as (or within 2 lines after)
    //    a relevant keyword.
    for (int i = 0; i < linesLower.length; i++) {
      if (!kwList.any(linesLower[i].contains)) continue;

      for (int delta = 0; delta <= 2; delta++) {
        final idx = i + delta;
        if (idx >= lines.length) break;
        final line = lines[idx];

        var m = numPat.firstMatch(line);
        if (m != null) {
          final d = m.group(1)!.padLeft(2, '0');
          final mo = m.group(2)!.padLeft(2, '0');
          final y  = m.group(3)!;
          if (_validMonth(mo) && _validYear(y)) return '$d $mo $y';
        }
        m = isoPat.firstMatch(line);
        if (m != null) {
          final y  = m.group(1)!;
          final mo = m.group(2)!;
          final d  = m.group(3)!;
          if (_validMonth(mo) && _validYear(y)) return '$d $mo $y';
        }
      }
    }

    // 2. Fallback: collect all dates and return first (emission) or last (due).
    final allDates = <String>[];
    for (final line in lines) {
      for (final m in numPat.allMatches(line)) {
        final d  = m.group(1)!.padLeft(2, '0');
        final mo = m.group(2)!.padLeft(2, '0');
        final y  = m.group(3)!;
        if (_validMonth(mo) && _validYear(y)) {
          allDates.add('$d $mo $y');
        }
      }
    }
    if (allDates.isEmpty) return 'UNKNOWN';
    return due ? allDates.last : allDates.first;
  }

  static bool _validMonth(String m) {
    final v = int.tryParse(m);
    return v != null && v >= 1 && v <= 12;
  }

  static bool _validYear(String y) {
    final v = int.tryParse(y);
    return v != null && v >= 1990 && v <= 2100;
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // Invoice number
  // ─────────────────────────────────────────────────────────────────────────────

  static String _extractInvoiceNumber(String text, String lower) {
    // Portuguese AT standard invoice codes (FT, FS, FR, NC …)
    final ptPat = RegExp(
      r'\b(FT|FTS|FS|FR|NC|ND|RG|RC|VD|TV|TT|TR|TD|FD|GT|GR)\s*[\s/\-]?\d+[/\-]\d+\b',
    );
    var m = ptPat.firstMatch(text);
    if (m != null) return m.group(0)!.trim();

    // Generic keyword-anchored patterns
    final genericPat = RegExp(
      r'(?:invoice\s*[#:]\s*|inv[.#:\s]*|fatura\s*n[oº.:\s]+|factura\s*n[oº.:\s]+'
      r'|fattura\s*n[.:\s]*|rechnung(?:s)?(?:\s*nr)?[.:\s]*'
      r'|n[oº][.:\s]+|num(?:ero)?[.:\s]*|ref(?:er[eê]ncia)?[.:\s]*'
      r'|numéro[.:\s]*|f(?:act)?[.:\s]*nr[.:\s]*)'
      r'([A-Z0-9][A-Z0-9\-/]{2,24})',
      caseSensitive: false,
    );
    m = genericPat.firstMatch(text);
    if (m != null) {
      final v = m.group(1)!.trim();
      if (v.length >= 3) return v;
    }

    return 'UNKNOWN';
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // Month/year reference
  // ─────────────────────────────────────────────────────────────────────────────

  // Written month names → 2-digit number (all 7 app languages + DE).
  static const Map<String, String> _monthNames = {
    // PT
    'janeiro':'01','fevereiro':'02','março':'03','abril':'04',
    'maio':'05','junho':'06','julho':'07','agosto':'08',
    'setembro':'09','outubro':'10','novembro':'11','dezembro':'12',
    // EN
    'january':'01','february':'02','march':'03','april':'04',
    'may':'05','june':'06','july':'07','august':'08',
    'september':'09','october':'10','november':'11','december':'12',
    // ES
    'enero':'01','febrero':'02','marzo':'03','junio':'06',
    'julio':'07','septiembre':'09','octubre':'10','noviembre':'11','diciembre':'12',
    // FR
    'janvier':'01','février':'02','mars':'03','avril':'04',
    'mai':'05','juin':'06','juillet':'07','août':'08',
    'septembre':'09','octobre':'10','novembre':'11','décembre':'12',
    // DE
    'januar':'01','februar':'02','märz':'03',
    'juni':'06','juli':'07','oktober':'10','dezember':'12',
    // IT
    'gennaio':'01','febbraio':'02','aprile':'04',
    'maggio':'05','giugno':'06','luglio':'07',
    'settembre':'09','ottobre':'10','dicembre':'12',
  };

  static String _extractMonthYear(String text, String lower) {
    // Near period/reference keywords
    final ctxPat = RegExp(
      r'(?:ref(?:er[êe]ncia)?|per[íi]odo|period|r[eé]f[ée]rence'
      r'|mês de|mes de|month of|monat|mese di)'
      r'[\s:]*(\d{1,2})[/.](\d{4})',
      caseSensitive: false,
    );
    var m = ctxPat.firstMatch(text);
    if (m != null) {
      final mo = m.group(1)!.padLeft(2, '0');
      final y  = m.group(2)!;
      if (_validMonth(mo) && _validYear(y)) return '$mo/$y';
    }

    // Written month name + 4-digit year
    for (final entry in _monthNames.entries) {
      final rx = RegExp(r'\b' + entry.key + r'\s+(\d{4})\b', caseSensitive: false);
      m = rx.firstMatch(lower);
      if (m != null) {
        final y = m.group(1)!;
        if (_validYear(y)) return '${entry.value}/$y';
      }
    }

    // Fallback: any mm/yyyy
    final fallback = RegExp(r'(\d{1,2})[/.](\d{4})');
    m = fallback.firstMatch(text);
    if (m != null) {
      final mo = m.group(1)!.padLeft(2, '0');
      final y  = m.group(2)!;
      if (_validMonth(mo) && _validYear(y)) return '$mo/$y';
    }

    return 'UNKNOWN';
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // Credit detection
  // ─────────────────────────────────────────────────────────────────────────────

  static String _detectCredit(String lower) {
    const debitKw = [
      'a pagar', 'to pay', 'due', 'debit', 'débito', 'cobrança',
      'charge', 'cobrar',
    ];
    const creditKw = [
      'crédito', 'credit', 'recebido', 'received', 'creditado',
      'credit note', 'nota de crédito', 'avoir', 'gutschrift',
      'accredito', 'кредит', 'депозит', 'deposit',
    ];
    if (debitKw.any(lower.contains)) return '0';
    if (creditKw.any(lower.contains)) return '1';
    return 'UNKNOWN';
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // Currency detection
  // ─────────────────────────────────────────────────────────────────────────────

  static String _detectCurrency(String text) {
    const ordered = [
      ('€', 'EUR'), ('EUR', 'EUR'),
      (r'$', 'USD'), ('USD', 'USD'),
      ('£', 'GBP'), ('GBP', 'GBP'),
      ('¥', 'JPY'), ('JPY', 'JPY'), ('CNY', 'CNY'),
      ('₹', 'INR'), ('INR', 'INR'),
      ('₽', 'RUB'), ('RUB', 'RUB'),
      ('CHF', 'CHF'),
      ('R\$', 'BRL'), ('BRL', 'BRL'),
      ('NOK', 'NOK'), ('SEK', 'SEK'), ('DKK', 'DKK'),
      ('PLN', 'PLN'), ('CZK', 'CZK'),
    ];
    for (final (sym, code) in ordered) {
      if (text.contains(sym)) return code;
    }
    return 'EUR';
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // Payment method
  // ─────────────────────────────────────────────────────────────────────────────

  static String _extractPaymentMethod(String text, String lower) {
    // Portuguese Multibanco: 5-digit entity / 9-digit reference
    final mbPat = RegExp(r'\b(\d{5})\s*/\s*(\d{9})\b');
    var m = mbPat.firstMatch(text);
    if (m != null) return 'Multibanco: ${m.group(1)}/${m.group(2)}';

    // IBAN (2-letter country code + 2 check digits + up to 30 alphanum)
    final ibanPat = RegExp(r'\b([A-Z]{2}\d{2}[\s\d]{10,32})\b');
    m = ibanPat.firstMatch(text);
    if (m != null) {
      final iban = m.group(1)!.replaceAll(RegExp(r'\s+'), '');
      if (iban.length >= 15) return 'IBAN: $iban';
    }

    // Keyword map
    for (final entry in _pmKw.entries) {
      if (lower.contains(entry.key)) return entry.value;
    }

    return 'UNKNOWN';
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // Description
  // ─────────────────────────────────────────────────────────────────────────────

  static String _extractDescription(String text, String lower) {
    const descKw = [
      'descrição', 'description', 'descripción', 'désignation',
      'leistung', 'descrizione', 'описание', '描述',
      'serviço', 'service', 'produto', 'product', 'item', 'artigo',
    ];

    final lines = text.split('\n');
    for (int i = 0; i < lines.length; i++) {
      if (!descKw.any(lines[i].toLowerCase().contains)) continue;
      for (int j = i + 1; j < lines.length && j <= i + 4; j++) {
        final candidate = lines[j].trim();
        if (candidate.length > 4 &&
            !RegExp(r'^[\d\s€$£.,+\-]+$').hasMatch(candidate)) {
          return candidate.length > 80 ? candidate.substring(0, 80) : candidate;
        }
      }
    }
    return 'UNKNOWN';
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // Helpers
  // ─────────────────────────────────────────────────────────────────────────────

  static Map<String, dynamic> _unknownFields() => {
    'tipo_documento': '4',
    'entidade':       'UNKNOWN',
    'data_emissao':   'UNKNOWN',
    'valor_total':    'UNKNOWN',
    'data_limite':    'UNKNOWN',
    'é_crédito':      'UNKNOWN',
    'mes_ano_ref':    'UNKNOWN',
    'descrição':      'UNKNOWN',
    'ids_ref_fatura': '',
    'numero_serie':   'UNKNOWN',
    'metodo_pagamento': 'UNKNOWN',
    'moeda':          'EUR',
  };
}
