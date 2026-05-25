/// OcrParserService — heuristic field extraction from ML Kit recognised text.
///
/// This runs entirely on-device without any API key.  It provides a best-effort
/// result that is used as a fallback when no Gemini API key is configured or
/// when the Gemini call fails.  The confidence field indicates how many of the
/// key fields could be extracted (0–5).
///
/// Supported languages: PT, EN, ES, FR (keyword sets).
library;

class OcrParserResult {
  final Map<String, dynamic> fields;

  /// 0–5: number of key fields successfully extracted (entity, date, amount,
  /// invoiceNumber, monthYearRef).  Used to drive the confidence badge.
  final int confidence;

  const OcrParserResult({required this.fields, required this.confidence});
}

class OcrParserService {
  OcrParserService._();

  /// Extract financial document fields from [text] (ML Kit full text).
  static OcrParserResult parse(String text) {
    final lower = text.toLowerCase();

    final entity      = _extractEntity(text);
    final date        = _extractDate(text);
    final amount      = _extractAmount(text);
    final invoiceNum  = _extractInvoiceNumber(text);
    final monthYear   = _extractMonthYearRef(text);

    int conf = 0;
    if (entity != 'UNKNOWN')     conf++;
    if (date   != 'UNKNOWN')     conf++;
    if (amount != 'UNKNOWN')     conf++;
    if (invoiceNum != 'UNKNOWN') conf++;
    if (monthYear != 'UNKNOWN')  conf++;

    return OcrParserResult(
      confidence: conf,
      fields: {
        'tipo_documento': _detectDocType(lower).toString(),
        'entidade': entity,
        'data_emissao': date,
        'valor_total': amount,
        'data_limite': 'UNKNOWN',
        'é_crédito': _detectCredit(lower),
        'mes_ano_ref': monthYear,
        'descrição': 'UNKNOWN',
        'ids_ref_fatura': '',
        'numero_serie': invoiceNum,
        'metodo_pagamento': _extractPaymentMethod(text),
      },
    );
  }

  // ── Document type ──────────────────────────────────────────────────────────

  static int _detectDocType(String lower) {
    // Priority 3: payment proof
    const paymentKw = [
      'comprovativo', 'payment proof', 'comprobante de pago',
      'preuve de paiement', 'transferência', 'transferencia',
      'transfer', 'pagamento efetuado', 'payment made',
      'recibo de pagamento', 'pago realizado', 'comprovante',
    ];
    if (paymentKw.any(lower.contains)) return 3;

    // Priority 2: invoice / nota de cobrança
    const invoiceKw = [
      'fatura', 'factura', 'invoice', 'facture',
      'nota de cobrança', 'nota de cobro', 'rechnung',
      'billing', 'a pagar', 'to pay', 'due date',
      'data limite', 'data de vencimento', 'vencimento',
    ];
    if (invoiceKw.any(lower.contains)) return 2;

    // Priority 1: purchase receipt / talão
    const receiptKw = [
      'recibo', 'receipt', 'talão', 'talao', 'reçu',
      'ticket', 'obrigado', 'thank you', 'gracias', 'merci',
      'total a pagar', 'total paid', 'compra',
    ];
    if (receiptKw.any(lower.contains)) return 1;

    return 4; // Other / unknown
  }

  // ── Entity ─────────────────────────────────────────────────────────────────

  static String _extractEntity(String text) {
    final lines = text
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty && l.length > 2)
        .toList();

    if (lines.isEmpty) return 'UNKNOWN';

    // Skip lines that look like addresses, raw numbers, or known header words.
    const skipPatterns = [
      r'\d{1,2}[/.\-]\d{1,2}[/.\-]\d{2,4}', // date
      r'^[\d\s€.,+-]+$',                       // pure numeric
    ];
    const skipWords = [
      'nif', 'nº', 'rua', 'avenida', 'av.', 'street', 'total',
      'iban', 'bic', 'swift', 'vat', 'iva',
    ];

    for (final line in lines.take(6)) {
      final lo = line.toLowerCase();
      if (skipWords.any(lo.contains)) continue;
      if (skipPatterns.any((p) => RegExp(p).hasMatch(line))) continue;

      // Take the first word of the line (entity names are rarely multi-word
      // in the first line and anything beyond 25 chars is likely a phrase).
      final words = line.split(RegExp(r'\s+'));
      final first = words.first;
      if (first.length > 2 && first.length <= 25) {
        return first;
      }
    }
    return 'UNKNOWN';
  }

  // ── Date ───────────────────────────────────────────────────────────────────

  static String _extractDate(String text) {
    // dd/mm/yyyy  dd-mm-yyyy  dd.mm.yyyy
    final patterns = [
      RegExp(r'(\d{1,2})[/.\-](\d{1,2})[/.\-](\d{4})'),
      RegExp(r'(\d{1,2})\s(\d{1,2})\s(\d{4})'),
    ];

    // Prefer dates near keywords "data" / "date" / "emiss"
    final contextPattern = RegExp(
      r'(?:data|date|emiss[aã]o|emitido|issued).*?(\d{1,2})[/.\-\s](\d{1,2})[/.\-\s](\d{4})',
      caseSensitive: false,
    );
    final ctxMatch = contextPattern.firstMatch(text);
    if (ctxMatch != null) {
      final d = ctxMatch.group(1)!.padLeft(2, '0');
      final m = ctxMatch.group(2)!.padLeft(2, '0');
      final y = ctxMatch.group(3)!;
      if (_validMonth(m)) return '$d $m $y';
    }

    for (final pat in patterns) {
      final match = pat.firstMatch(text);
      if (match != null) {
        final d = match.group(1)!.padLeft(2, '0');
        final m = match.group(2)!.padLeft(2, '0');
        final y = match.group(3)!;
        if (_validMonth(m)) return '$d $m $y';
      }
    }
    return 'UNKNOWN';
  }

  static bool _validMonth(String m) {
    final v = int.tryParse(m);
    return v != null && v >= 1 && v <= 12;
  }

  // ── Amount ─────────────────────────────────────────────────────────────────

  static String _extractAmount(String text) {
    // Highest priority: "TOTAL …" lines
    final totalPat = RegExp(
      r'(?:total|total a pagar|total paid|montant total|importe total|valor total)'
      r'[\s:€]*(\d{1,6}[.,]\d{2})',
      caseSensitive: false,
    );
    final tMatch = totalPat.firstMatch(text);
    if (tMatch != null) {
      return _normaliseAmount(tMatch.group(1)!);
    }

    // Euro sign adjacent to number
    for (final pat in [
      RegExp(r'€\s*(\d{1,6}[.,]\d{2})'),
      RegExp(r'(\d{1,6}[.,]\d{2})\s*€'),
    ]) {
      final m = pat.firstMatch(text);
      if (m != null) {
        final v = _normaliseAmount(m.group(1)!);
        if (v != 'UNKNOWN') return v;
      }
    }

    // Last resort: any decimal number
    final generic = RegExp(r'(\d{1,6}[.,]\d{2})');
    final gm = generic.firstMatch(text);
    if (gm != null) {
      final v = _normaliseAmount(gm.group(1)!);
      if (v != 'UNKNOWN') return v;
    }

    return 'UNKNOWN';
  }

  static String _normaliseAmount(String raw) {
    final normalised = raw.replaceAll(',', '.');
    final value = double.tryParse(normalised);
    if (value == null || value <= 0 || value >= 999999) return 'UNKNOWN';
    return normalised.contains('.') ? normalised : '$normalised.00';
  }

  // ── Credit detection ───────────────────────────────────────────────────────

  static String _detectCredit(String lower) {
    const creditKw = [
      'crédito', 'credit', 'entrada', 'recebido', 'received',
      'transferência recebida', 'transfer received', 'creditado',
      'depósito', 'deposit',
    ];
    return creditKw.any(lower.contains) ? '1' : '0';
  }

  // ── Month/year reference ───────────────────────────────────────────────────

  static String _extractMonthYearRef(String text) {
    // Near "ref" / "período" keywords
    final contextPat = RegExp(
      r'(?:ref(?:er[êe]ncia)?|per[íi]odo|period|r[eé]f[ée]rence)'
      r'.*?(\d{1,2})[/.](\d{4})',
      caseSensitive: false,
    );
    var match = contextPat.firstMatch(text);
    if (match != null) {
      final m = match.group(1)!.padLeft(2, '0');
      final y = match.group(2)!;
      if (_validMonth(m)) return '$m/$y';
    }

    // Any mm/yyyy occurrence
    final fallback = RegExp(r'(\d{1,2})[/.](\d{4})');
    match = fallback.firstMatch(text);
    if (match != null) {
      final m = match.group(1)!.padLeft(2, '0');
      final y = match.group(2)!;
      if (_validMonth(m)) return '$m/$y';
    }

    return 'UNKNOWN';
  }

  // ── Invoice number ─────────────────────────────────────────────────────────

  static String _extractInvoiceNumber(String text) {
    // Portuguese AT format: FT YYYY/NNNN etc.
    final ptPat = RegExp(
      r'\b(FT|FTS|FS|FR|NC|ND|RG|RC|VD|TV|TT|TR|TD)\s*\d+/\d+\b',
    );
    var match = ptPat.firstMatch(text);
    if (match != null) return match.group(0)!.trim();

    // Generic invoice number near keyword
    final genericPat = RegExp(
      r'(?:invoice|inv|ref|n[oº]\.?|num(?:ero)?)[#.\s:]*(\w[\w\-/]+)',
      caseSensitive: false,
    );
    match = genericPat.firstMatch(text);
    if (match != null) {
      final v = match.group(1)!.trim();
      if (v.length >= 3) return v;
    }

    return 'UNKNOWN';
  }

  // ── Payment method ─────────────────────────────────────────────────────────

  static String _extractPaymentMethod(String text) {
    // Portuguese MB: entity (9 digits) / reference (9-15 digits)
    final mbPat = RegExp(r'(\d{9})\s*/\s*(\d{9,15})');
    var match = mbPat.firstMatch(text);
    if (match != null) return '${match.group(1)}/${match.group(2)}';

    // Portuguese IBAN: PT50 followed by groups of 4 digits
    final ibanPat = RegExp(r'\b(PT\d{2}[\s\d]{15,30})\b');
    match = ibanPat.firstMatch(text);
    if (match != null) {
      return match.group(1)!.replaceAll(RegExp(r'\s+'), '');
    }

    // Generic IBAN
    final genericIban = RegExp(r'\b([A-Z]{2}\d{2}[\s\d]{10,30})\b');
    match = genericIban.firstMatch(text);
    if (match != null) {
      return match.group(1)!.replaceAll(RegExp(r'\s+'), '');
    }

    return 'UNKNOWN';
  }
}
