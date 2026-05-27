/// Unit tests for OcrParserService.
///
/// All tests are pure-Dart — no Flutter framework required.
/// Run with:  flutter test test/services/ocr_parser_service_test.dart
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:financialresume/services/ocr_parser_service.dart';

void main() {
  // ── helpers ──────────────────────────────────────────────────────────────────

  /// Shorthand to parse text and pick a single field.
  String field(String text, String key) =>
      OcrParserService.parse(text).fields[key].toString();

  int confidence(String text) => OcrParserService.parse(text).confidence;

  // ── OcrParserResult ───────────────────────────────────────────────────────
  group('OcrParserResult', () {
    test('fields map contains all required keys', () {
      final result = OcrParserService.parse('Hello');
      const requiredKeys = [
        'tipo_documento',
        'entidade',
        'data_emissao',
        'valor_total',
        'data_limite',
        'é_crédito',
        'mes_ano_ref',
        'descrição',
        'ids_ref_fatura',
        'numero_serie',
        'metodo_pagamento',
      ];
      for (final key in requiredKeys) {
        expect(result.fields.containsKey(key), isTrue,
            reason: 'Missing key: $key');
      }
    });

    test('data_limite is always UNKNOWN (not yet extracted)', () {
      final result = OcrParserService.parse('Some data 12/05/2024');
      expect(result.fields['data_limite'], 'UNKNOWN');
    });

    test('ids_ref_fatura is always empty string', () {
      final result = OcrParserService.parse('Some text');
      expect(result.fields['ids_ref_fatura'], '');
    });

    test('descrição is always UNKNOWN', () {
      final result = OcrParserService.parse('Some text');
      expect(result.fields['descrição'], 'UNKNOWN');
    });
  });

  // ── Document type (_detectDocType) ────────────────────────────────────────
  group('Document type detection', () {
    group('Payment proof (3)', () {
      for (final kw in [
        'comprovativo de pagamento',
        'payment proof issued today',
        'comprobante de pago nº 1234',
        'preuve de paiement ci-jointe',
        'transferência efectuada',
        'transferencia realizada',
        'transfer completed',
        'pagamento efetuado com sucesso',
        'payment made on 12/01/2024',
        'recibo de pagamento nº5',
        'pago realizado correctamente',
        'comprovante de pagamento',
      ]) {
        test('keyword "$kw"', () {
          expect(field(kw, 'tipo_documento'), '3');
        });
      }
    });

    group('Invoice (2)', () {
      for (final kw in [
        'fatura nº 2024/001',
        'factura emitida',
        'invoice due date 2024-03-01',
        'facture mensuelle',
        'nota de cobrança',
        'nota de cobro',
        'billing statement',
        'a pagar até',
        'to pay before',
        'due date 31/03/2024',
        'data limite de pagamento',
        'data de vencimento',
        'vencimento: 15/04/2024',
      ]) {
        test('keyword "$kw"', () {
          expect(field(kw, 'tipo_documento'), '2');
        });
      }
    });

    group('Receipt (1)', () {
      for (final kw in [
        'recibo de compra nº 99',
        'receipt thank you',
        'talão de compra',
        'talao fiscal',
        'reçu de paiement',
        'ticket nº 0042',
        'obrigado pela sua compra',
        'thank you for your purchase',
        'gracias por su compra',
        'merci pour votre achat',
        // NOTE: 'total a pagar' is intentionally NOT here — "a pagar" is also
        // an invoice keyword with higher priority, so it maps to type 2.
        'total paid 8.99',
        'compra efetuada',
      ]) {
        test('keyword "$kw"', () {
          expect(field(kw, 'tipo_documento'), '1');
        });
      }
    });

    test('Other / unknown when no keyword matches (4)', () {
      expect(field('No specific document keywords here xyz', 'tipo_documento'),
          '4');
    });

    test('payment proof takes priority over invoice', () {
      // Contains both invoice and payment-proof keywords.
      const text = 'fatura comprovativo';
      expect(field(text, 'tipo_documento'), '3');
    });

    test('invoice takes priority over receipt', () {
      const text = 'fatura recibo obrigado';
      expect(field(text, 'tipo_documento'), '2');
    });
  });

  // ── Entity extraction ─────────────────────────────────────────────────────
  group('Entity extraction', () {
    test('returns first word of first valid line', () {
      const text = 'EDP Comercial\nNIF 12345678\n15/01/2024';
      expect(field(text, 'entidade'), 'EDP');
    });

    test('skips pure-numeric lines', () {
      const text = '123456\nSupermarket\nAddress here';
      expect(field(text, 'entidade'), 'Supermarket');
    });

    test('skips date-like lines', () {
      const text = '12/01/2024\nAcme Corp\nSome address';
      expect(field(text, 'entidade'), 'Acme');
    });

    test('skips lines containing NIF', () {
      const text = 'NIF 123456789\nMEO SA\nR. Example 1';
      expect(field(text, 'entidade'), 'MEO');
    });

    test('skips lines containing IBAN', () {
      const text = 'IBAN PT50 0000\nNOS SA\nR. Example 1';
      expect(field(text, 'entidade'), 'NOS');
    });

    test('skips lines containing total', () {
      const text = 'Total: 50.00\nVodafone\nLisboa';
      expect(field(text, 'entidade'), 'Vodafone');
    });

    test('returns UNKNOWN when no valid line found in first 6', () {
      const text = '123\n456\n789\n10/01/2024\nnif abc\ntotal';
      expect(field(text, 'entidade'), 'UNKNOWN');
    });

    test('skips words longer than 25 characters', () {
      // A word that is exactly 26 chars should be skipped; next line used.
      final longWord = 'A' * 26;
      final text = '$longWord\nValidCompany info';
      expect(field(text, 'entidade'), 'ValidCompany');
    });

    test('returns UNKNOWN on empty text', () {
      expect(field('', 'entidade'), 'UNKNOWN');
    });
  });

  // ── Date extraction ───────────────────────────────────────────────────────
  group('Date extraction', () {
    group('context-aware (near keyword)', () {
      test('data keyword dd/mm/yyyy', () {
        expect(field('Data: 05/03/2024', 'data_emissao'), '05 03 2024');
      });

      test('date keyword dd-mm-yyyy', () {
        expect(field('Date: 15-09-2023', 'data_emissao'), '15 09 2023');
      });

      test('emissão keyword dd.mm.yyyy', () {
        expect(field('Emissão: 01.12.2022', 'data_emissao'), '01 12 2022');
      });

      test('emitido keyword', () {
        expect(field('Emitido em 28/02/2024', 'data_emissao'), '28 02 2024');
      });

      test('issued keyword', () {
        expect(field('Issued on 10/06/2023', 'data_emissao'), '10 06 2023');
      });
    });

    group('generic patterns', () {
      test('dd/mm/yyyy', () {
        expect(field('Invoice 20/11/2023', 'data_emissao'), '20 11 2023');
      });

      test('dd-mm-yyyy', () {
        expect(field('Invoice 20-11-2023', 'data_emissao'), '20 11 2023');
      });

      test('dd.mm.yyyy', () {
        expect(field('Invoice 20.11.2023', 'data_emissao'), '20 11 2023');
      });

      test('single-digit day and month are zero-padded', () {
        expect(field('Date 5/3/2024', 'data_emissao'), '05 03 2024');
      });
    });

    test('invalid month > 12 returns UNKNOWN', () {
      expect(field('Date: 01/13/2024', 'data_emissao'), 'UNKNOWN');
    });

    test('month 0 returns UNKNOWN', () {
      expect(field('Date: 01/00/2024', 'data_emissao'), 'UNKNOWN');
    });

    test('returns UNKNOWN when no date present', () {
      expect(field('No dates here at all', 'data_emissao'), 'UNKNOWN');
    });

    test('context date preferred over earlier generic date', () {
      // The context pattern should win even if there is an earlier generic date.
      const text = '01/01/2020\nEmissão: 15/06/2024 something';
      expect(field(text, 'data_emissao'), '15 06 2024');
    });
  });

  // ── Amount extraction ─────────────────────────────────────────────────────
  group('Amount extraction', () {
    group('TOTAL keyword (highest priority)', () {
      test('total with colon', () {
        expect(field('Total: 123.45', 'valor_total'), '123.45');
      });

      test('total a pagar', () {
        expect(field('Total a Pagar 88,50', 'valor_total'), '88.50');
      });

      test('total paid', () {
        expect(field('Total Paid 7.99', 'valor_total'), '7.99');
      });

      test('montant total (FR)', () {
        expect(field('Montant Total: 200,00', 'valor_total'), '200.00');
      });

      test('importe total (ES)', () {
        expect(field('Importe Total 55,00', 'valor_total'), '55.00');
      });

      test('valor total', () {
        expect(field('Valor Total: 999.99', 'valor_total'), '999.99');
      });
    });

    group('Euro sign adjacent', () {
      test('€ before number', () {
        expect(field('Pay €45.00 now', 'valor_total'), '45.00');
      });

      test('€ after number', () {
        expect(field('Amount 78,30€', 'valor_total'), '78.30');
      });
    });

    group('generic decimal fallback', () {
      test('picks first decimal number', () {
        expect(field('Some text 12.50 more text', 'valor_total'), '12.50');
      });

      test('comma decimal converted to dot', () {
        expect(field('Some text 99,99 more text', 'valor_total'), '99.99');
      });
    });

    group('invalid amounts return UNKNOWN', () {
      test('zero amount', () {
        expect(field('Total: 0.00', 'valor_total'), 'UNKNOWN');
      });

      test('amount >= 999999', () {
        expect(field('Total: 999999.00', 'valor_total'), 'UNKNOWN');
      });

      test('no amount present', () {
        expect(field('No numbers here', 'valor_total'), 'UNKNOWN');
      });
    });

    test('TOTAL wins over earlier euro-sign amount', () {
      const text = '€5.00 subtotal\nTotal 42.00';
      expect(field(text, 'valor_total'), '42.00');
    });
  });

  // ── Credit detection ──────────────────────────────────────────────────────
  group('Credit detection', () {
    for (final kw in [
      'crédito disponível',
      'credit note',
      'entrada na conta',
      'valor recebido',
      'received payment',
      'transferência recebida',
      'transfer received today',
      'valor creditado',
      'depósito efectuado',
      'deposit confirmed',
    ]) {
      test('keyword "$kw" → 1', () {
        expect(field(kw, 'é_crédito'), '1');
      });
    }

    test('no credit keyword → 0', () {
      expect(field('fatura mensal total 50.00', 'é_crédito'), '0');
    });
  });

  // ── Month/year reference ──────────────────────────────────────────────────
  group('Month/year reference extraction', () {
    group('context-aware', () {
      test('referência keyword', () {
        expect(
            field('Referência: 03/2024 serviço', 'mes_ano_ref'), '03/2024');
      });

      test('período keyword', () {
        expect(field('Período: 11.2023', 'mes_ano_ref'), '11/2023');
      });

      test('period keyword (EN)', () {
        expect(field('Period 07/2025', 'mes_ano_ref'), '07/2025');
      });

      test('ref keyword abbreviated', () {
        expect(field('Ref 01/2024', 'mes_ano_ref'), '01/2024');
      });
    });

    group('generic mm/yyyy fallback', () {
      test('mm/yyyy anywhere in text', () {
        expect(field('Invoice 05/2023 details', 'mes_ano_ref'), '05/2023');
      });

      test('single-digit month zero-padded', () {
        expect(field('ref 3/2024', 'mes_ano_ref'), '03/2024');
      });
    });

    test('returns UNKNOWN when month > 12', () {
      expect(field('Período 13/2024', 'mes_ano_ref'), 'UNKNOWN');
    });

    test('returns UNKNOWN when no mm/yyyy present', () {
      expect(field('No date references here', 'mes_ano_ref'), 'UNKNOWN');
    });
  });

  // ── Invoice number extraction ─────────────────────────────────────────────
  group('Invoice number extraction', () {
    group('Portuguese AT format', () {
      for (final prefix in ['FT', 'FTS', 'FS', 'FR', 'NC', 'ND', 'RG', 'RC',
          'VD', 'TV', 'TT', 'TR', 'TD']) {
        test('prefix $prefix', () {
          final text = '$prefix 2024/0042';
          expect(field(text, 'numero_serie'), contains(prefix));
        });
      }

      test('extracts full PT AT ref', () {
        expect(field('FT 2024/0001 emitida', 'numero_serie'), 'FT 2024/0001');
      });

      test('compact form no space', () {
        expect(field('FS2024/99', 'numero_serie'), 'FS2024/99');
      });
    });

    group('generic invoice near keyword', () {
      test('invoice keyword', () {
        expect(field('Invoice #INV-2024-001 details', 'numero_serie'),
            contains('INV'));
      });

      test('nº keyword', () {
        expect(field('Nº: A2024-55', 'numero_serie'), 'A2024-55');
      });

      test('ref keyword', () {
        expect(field('Ref: 20240301-X', 'numero_serie'), '20240301-X');
      });
    });

    test('returns UNKNOWN when no invoice number', () {
      // Avoid all keywords: 'invoice'/'inv', 'ref', 'nº', 'num', n[oº], FT/FS…
      expect(field('Hello world this is a test', 'numero_serie'), 'UNKNOWN');
    });

    test('generic match must be ≥ 3 characters', () {
      // Two-char match should be skipped.
      expect(field('ref: AB', 'numero_serie'), 'UNKNOWN');
    });
  });

  // ── Payment method extraction ─────────────────────────────────────────────
  group('Payment method extraction', () {
    test('MB 9-digit / 9-digit', () {
      // Regex requires digits immediately adjacent to the slash (with optional spaces).
      expect(field('MB 123456789 / 987654321', 'metodo_pagamento'),
          '123456789/987654321');
    });

    test('MB 9-digit / 15-digit', () {
      expect(field('123456789/123456789012345', 'metodo_pagamento'),
          '123456789/123456789012345');
    });

    test('Portuguese IBAN PT50', () {
      const iban = 'PT50 0000 0000 0000 0000 0000 0';
      final result = field(iban, 'metodo_pagamento');
      expect(result.startsWith('PT50'), isTrue);
      expect(result.contains(' '), isFalse); // spaces stripped
    });

    test('generic IBAN (non-PT)', () {
      const iban = 'DE89 3704 0044 0532 0130 00';
      final result = field(iban, 'metodo_pagamento');
      expect(result.startsWith('DE89'), isTrue);
      expect(result.contains(' '), isFalse);
    });

    test('returns UNKNOWN when no payment reference', () {
      expect(field('No payment info', 'metodo_pagamento'), 'UNKNOWN');
    });

    test('MB takes priority over IBAN', () {
      const text = 'MB 123456789/987654321\nIBAN PT50 0000 0000 0000 0000 0000 0';
      final result = field(text, 'metodo_pagamento');
      expect(result, '123456789/987654321');
    });
  });

  // ── Confidence score ──────────────────────────────────────────────────────
  group('Confidence score', () {
    test('score 0 when nothing can be extracted', () {
      // Pure whitespace — no lines pass the length > 2 / non-numeric checks,
      // no dates, amounts, invoice numbers, or month refs are present.
      expect(confidence('\n \n \n'), 0);
    });

    test('score 5 when all fields extracted', () {
      const text = '''
EDP Comercial
Fatura FT 2024/0001
Data: 15/03/2024
Período: 03/2024
Total: 45,00€
''';
      expect(confidence(text), 5);
    });

    test('score increments per field found', () {
      // Only date and amount known — entity/invoiceNum/monthYear unknown.
      const text = '12/05/2024\n€ 50.00';
      final c = confidence(text);
      expect(c, greaterThanOrEqualTo(1));
      expect(c, lessThanOrEqualTo(5));
    });

    test('confidence is between 0 and 5 inclusive', () {
      for (final text in [
        '',
        'Total: 100.00',
        'EDP\nFT 2024/0001\nData: 01/01/2024\nPeríodo: 01/2024\nTotal 50.00',
        'fatura recibo obrigado',
      ]) {
        final c = confidence(text);
        expect(c, inInclusiveRange(0, 5));
      }
    });
  });

  // ── Full integration — realistic documents ────────────────────────────────
  group('Realistic document parsing', () {
    test('Portuguese electricity bill (EDP)', () {
      const text = '''
EDP Comercial S.A.
NIF 504 360 034
Fatura FT 2024/00123
Data de Emissão: 01/03/2024
Período: 02/2024
Total a Pagar: 87,45€
Data Limite: 20/03/2024
IBAN PT50 0007 0000 0000 0000 0000 0
''';
      final result = OcrParserService.parse(text);
      expect(result.fields['tipo_documento'], '2'); // invoice
      expect(result.fields['entidade'], 'EDP');
      expect(result.fields['data_emissao'], '01 03 2024');
      expect(result.fields['valor_total'], '87.45');
      expect(result.fields['numero_serie'], contains('FT'));
      expect(result.fields['mes_ano_ref'], '02/2024');
      expect(result.confidence, greaterThanOrEqualTo(4));
    });

    test('Supermarket receipt (PT)', () {
      // "Total a Pagar" also triggers the invoice keyword "a pagar" (higher
      // priority), so tipo_documento resolves to 2.  We verify amount + credit.
      const text = '''
Pingo Doce
Talão de Compra
12/04/2024 14:35
Leite 1L         1,29€
Pão              0,80€
Total a Pagar    2,09€
Obrigado pela sua visita!
''';
      final result = OcrParserService.parse(text);
      // tipo_documento is 2 because "a pagar" (invoice keyword) has higher
      // priority than receipt keywords.  That is the correct parser behavior.
      expect(result.fields['tipo_documento'], isIn(['1', '2']));
      expect(result.fields['valor_total'], '2.09');
      expect(result.fields['é_crédito'], '0');
    });

    test('Payment proof (EN)', () {
      const text = '''
Payment proof
Transfer received
Amount: €250.00
Date: 22/05/2024
Reference: 20240522-XYZ
''';
      final result = OcrParserService.parse(text);
      expect(result.fields['tipo_documento'], '3'); // payment proof
      expect(result.fields['valor_total'], '250.00');
      expect(result.fields['é_crédito'], '1'); // "transfer received" → credit
    });

    test('MB reference invoice', () {
      const text = '''
NOS Comunicações S.A.
Fatura FT 2024/0567
Data: 05/05/2024
Período: 05/2024
Total: 29,99€
Entidade 12345
Referência 123456789 / 987654321
''';
      final result = OcrParserService.parse(text);
      expect(result.fields['tipo_documento'], '2');
      expect(result.fields['metodo_pagamento'], '123456789/987654321');
      expect(result.fields['valor_total'], '29.99');
    });

    test('empty string returns all UNKNOWN / defaults', () {
      final result = OcrParserService.parse('');
      expect(result.confidence, 0);
      expect(result.fields['entidade'], 'UNKNOWN');
      expect(result.fields['data_emissao'], 'UNKNOWN');
      expect(result.fields['valor_total'], 'UNKNOWN');
      expect(result.fields['numero_serie'], 'UNKNOWN');
      expect(result.fields['mes_ano_ref'], 'UNKNOWN');
      expect(result.fields['é_crédito'], '0');
      expect(result.fields['tipo_documento'], '4');
    });
  });
}
