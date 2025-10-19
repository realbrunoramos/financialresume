import 'dart:io';
import 'dart:math' as math;
import 'package:image/image.dart' as img;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:open_file/open_file.dart';
import '../models/transaction.dart';
import '../services/database_service.dart';
import '../theme/colors.dart';

class _TransactionWithBalance {
  final Transaction transaction;
  final double runningBalance;

  _TransactionWithBalance({
    required this.transaction,
    required this.runningBalance,
  });
}

class SummaryScreen extends StatelessWidget {
  final String sectionId;
  final DatabaseService dbService = DatabaseService();

  SummaryScreen({required this.sectionId});

  img.Image _createSimpleDonutChart({required double despesa, required double receita}) {
    const size = 400;
    final image = img.Image(width: size, height: size);

    img.fill(image, color: img.ColorRgb8(255, 255, 255));

    final center = size ~/ 2;
    final outerRadius = 150;
    final innerRadius = 90;
    final total = despesa + receita;

    if (total == 0) return image;

    final percentageDespesa = despesa / total;

    for (var y = 0; y < size; y++) {
      for (var x = 0; x < size; x++) {
        final dx = x - center;
        final dy = y - center;
        final distance = math.sqrt(dx * dx + dy * dy);

        if (distance <= outerRadius && distance >= innerRadius) {
          var angle = math.atan2(dy, dx);
          if (angle < 0) angle += 2 * math.pi;

          final isDespesa = angle < 2 * math.pi * percentageDespesa;
          final color = isDespesa ? img.ColorRgb8(244, 67, 54) : img.ColorRgb8(76, 175, 80);

          image.setPixel(x, y, color);
        }
      }
    }

    return image;
  }

  String formatValue(double value) {
    return value.toStringAsFixed(2);
  }

  Map<String, Map<String, dynamic>> _prepareMonthlyTablesData(List<Transaction> transactions) {
    final monthlyTransactions = _groupTransactionsByMonth(transactions);
    final Map<String, Map<String, dynamic>> monthlyData = {};

    monthlyTransactions.forEach((monthKey, monthTransactions) {
      monthTransactions.sort((a, b) => a.date.compareTo(b.date));

      double runningBalance = 0;
      final transactionsWithBalance = monthTransactions.map((t) {
        runningBalance += t.isCredit ? t.amount : -t.amount;

        String descricaoFormatada = _formatDescription(t);

        return _TransactionWithBalance(
          transaction: t.copyWith(description: descricaoFormatada),
          runningBalance: runningBalance,
        );
      }).toList();

      final reversedTransactions = transactionsWithBalance.toList().reversed.toList();

      final monthIncome = monthTransactions
          .where((t) => t.isCredit)
          .fold<double>(0, (sum, t) => sum + t.amount);

      final monthExpenses = monthTransactions
          .where((t) => !t.isCredit)
          .fold<double>(0, (sum, t) => sum + t.amount);

      final monthBalance = monthIncome - monthExpenses;

      final monthDate = DateFormat('yyyy-MM').parse(monthKey);
      final monthName = DateFormat('MMMM yyyy', 'pt_PT').format(monthDate);

      monthlyData[monthKey] = {
        'monthName': monthName,
        'transactions': reversedTransactions,
        'monthIncome': monthIncome,
        'monthExpenses': monthExpenses,
        'monthBalance': monthBalance,
      };
    });

    return monthlyData;
  }

  String _formatDescription(Transaction transaction) {
    String descricaoBase = transaction.description;
    List<String> partes = [];

    if (descricaoBase.isNotEmpty) {
      partes.add(descricaoBase);
    }

    if ((transaction.docType == '2' || transaction.docType == '3') &&
        transaction.numeroSerie != null &&
        transaction.numeroSerie!.isNotEmpty &&
        transaction.numeroSerie != 'UNKNOWN') {
      partes.add('Nº: ${transaction.numeroSerie}');
    }

    if ((transaction.docType == '2' || transaction.docType == '3') &&
        transaction.monthRef != null &&
        transaction.monthRef!.isNotEmpty &&
        transaction.monthRef != 'UNKNOWN') {
      try {
        final parts = transaction.monthRef!.split('/');
        if (parts.length == 2) {
          final mes = int.parse(parts[0]);
          final ano = int.parse(parts[1]);
          final dataRef = DateTime(ano, mes);
          final mesExtenso = DateFormat('MMMM', 'pt_PT').format(dataRef);
          partes.add('Ref: ${mesExtenso} de $ano');
        }
      } catch (e) {
        partes.add('Ref: ${transaction.monthRef}');
      }
    }

    return partes.join(' | ');
  }

  pw.Widget _buildStatCard(String title, String value, PdfColor color, pw.MemoryImage icon, String percentage) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(12),

      child: pw.Row(
        children: [
          pw.Container(
            width: 60,
            height: 60,
            decoration: pw.BoxDecoration(
              borderRadius: pw.BorderRadius.circular(6),
            ),
            child: pw.Center(
              child: pw.Image(icon, width: 46, height: 46),
            ),
          ),
          pw.SizedBox(width: 10),
          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  title,
                  style: pw.TextStyle(
                    fontSize: 10,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.grey700,
                  ),
                ),
                pw.Text(
                  value,
                  style: pw.TextStyle(
                    fontSize: 12,
                    fontWeight: pw.FontWeight.bold,
                    color: color,
                  ),
                ),
                if (percentage.isNotEmpty)
                  pw.Text(
                    percentage,
                    style: pw.TextStyle(
                      fontSize: 9,
                      color: PdfColors.grey600,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _exportToPdf(BuildContext context) async {
    try {
      final pdf = pw.Document();
      final transactions = await dbService.getAllTransactions(sectionId);
      final format = DateFormat('dd/MM/yyyy');
      final now = DateTime.now();

      final ByteData incomeIconData = await rootBundle.load('assets/images/money_gain.png');
      final ByteData expensesIconData = await rootBundle.load('assets/images/money_loose.png');

      final incomeIcon = pw.MemoryImage(incomeIconData.buffer.asUint8List());
      final expensesIcon = pw.MemoryImage(expensesIconData.buffer.asUint8List());

      final totalIncome = transactions.where((t) => t.isCredit).fold<double>(0, (sum, t) => sum + t.amount);
      final totalExpenses = transactions.where((t) => !t.isCredit).fold<double>(0, (sum, t) => sum + t.amount);
      final balance = totalIncome - totalExpenses;

      final donutImage = _createSimpleDonutChart(despesa: totalExpenses, receita: totalIncome);
      final donutPng = img.encodePng(donutImage);
      final donutPdfImage = pw.MemoryImage(donutPng);

      String formatCurrency(double value) {
        return '${value.toStringAsFixed(2)} EUR';
      }

      final ByteData appImageBytes = await rootBundle.load('assets/images/app_logo.png');
      final Uint8List appImageData = appImageBytes.buffer.asUint8List();

      final monthlyData = _prepareMonthlyTablesData(transactions);

      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(25),
          build: (pw.Context context) {
            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Container(
                  margin: const pw.EdgeInsets.only(bottom: 20),
                  child: pw.Row(
                    crossAxisAlignment: pw.CrossAxisAlignment.center,
                    children: [
                      pw.Container(
                        width: 50,
                        height: 50,
                        child: pw.Center(
                          child: pw.Image(pw.MemoryImage(appImageData), width: 30, height: 30),
                        ),
                      ),
                      pw.SizedBox(width: 15),
                      pw.Expanded(
                        child: pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            pw.Text(
                              'Relatório - Resumo Financeiro',
                              style: pw.TextStyle(
                                fontSize: 16,
                                fontWeight: pw.FontWeight.bold,
                              ),
                            ),
                            pw.Text(
                              DateFormat('dd/MM/yyyy').format(now),
                              style: pw.TextStyle(
                                fontSize: 10,
                                color: PdfColors.grey600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                pw.Container(
                  margin: const pw.EdgeInsets.only(bottom: 20),
                  padding: const pw.EdgeInsets.all(16),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.center,
                    children: [
                      pw.Text(
                        'Visão Geral',
                        style: pw.TextStyle(
                          fontSize: 18,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.black,
                        ),
                      ),
                      pw.SizedBox(height: 15),

                      pw.Row(
                        crossAxisAlignment: pw.CrossAxisAlignment.center,
                        children: [
                          pw.Expanded(
                            flex: 2,
                            child: pw.Center(
                              child: pw.Image(donutPdfImage, width: 180, height: 180),
                            ),
                          ),
                          pw.Expanded(
                            flex: 3,
                            child: pw.Column(
                              crossAxisAlignment: pw.CrossAxisAlignment.start,
                              children: [
                                _buildStatCard('Total Receitas', formatCurrency(totalIncome),
                                    PdfColors.green, incomeIcon, '${((totalIncome / (totalIncome + totalExpenses)) * 100).toStringAsFixed(1)}%'),
                                pw.SizedBox(height: 10),
                                _buildStatCard('Total Despesas', formatCurrency(totalExpenses),
                                    PdfColors.red, expensesIcon, '${((totalExpenses / (totalIncome + totalExpenses)) * 100).toStringAsFixed(1)}%'),

                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                pw.Container(
                  padding: const pw.EdgeInsets.all(16),
                  decoration: pw.BoxDecoration(
                    color: balance >= 0 ? PdfColors.lightGreen : PdfColors.pink,
                    borderRadius: pw.BorderRadius.circular(8),
                  ),
                  child: pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(
                            'SITUAÇÃO FINANCEIRA ATUAL',
                            style: pw.TextStyle(
                              fontSize: 12,
                              fontWeight: pw.FontWeight.bold,
                              color: PdfColors.white,
                            ),
                          ),
                          pw.SizedBox(height: 4),
                          pw.Text(
                            balance >= 0 ? 'Saldo Positivo' : 'Saldo Negativo',
                            style: pw.TextStyle(
                              fontSize: 14,
                              fontWeight: pw.FontWeight.bold,
                              color: PdfColors.white,
                            ),
                          ),
                        ],
                      ),
                      pw.Text(
                        formatCurrency(balance.abs()),
                        style: pw.TextStyle(
                          fontSize: 18,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.white,
                        ),
                      ),
                    ],
                  ),
                ),

                pw.Spacer(),

                pw.Container(
                  margin: const pw.EdgeInsets.only(top: 20),
                  padding: const pw.EdgeInsets.all(12),
                  child: pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text(
                        'Financial Resume App - by Bruno Ramos',
                        style: const pw.TextStyle(
                          fontSize: 9,
                          color: PdfColors.grey600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      );

      monthlyData.forEach((monthKey, data) {
        pdf.addPage(
          pw.Page(
            pageFormat: PdfPageFormat.a4,
            margin: const pw.EdgeInsets.all(25),
            build: (pw.Context context) {
              return pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Container(
                    padding: const pw.EdgeInsets.all(16),
                    decoration: pw.BoxDecoration(
                      color: PdfColors.blue,
                      borderRadius: pw.BorderRadius.circular(8),
                    ),
                    child: pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Text(
                          data['monthName'].toUpperCase(),
                          style: pw.TextStyle(
                            fontSize: 16,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColors.white,
                          ),
                        ),
                      ],
                    ),
                  ),

                  pw.Container(
                    margin: const pw.EdgeInsets.only(top: 15, bottom: 10),
                    padding: const pw.EdgeInsets.all(12),
                    decoration: pw.BoxDecoration(
                      color: PdfColors.grey100,
                      borderRadius: pw.BorderRadius.circular(6),
                    ),
                    child: pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
                      children: [
                        _buildMonthSummaryItem('Receitas', formatValue(data['monthIncome']), PdfColors.green),
                        _buildMonthSummaryItem('Despesas', formatValue(data['monthExpenses']), PdfColors.red),
                        _buildMonthSummaryItem('Saldo', formatValue(data['monthBalance']),
                            data['monthBalance'] >= 0 ? PdfColors.green : PdfColors.red),
                      ],
                    ),
                  ),

                  pw.Expanded(
                    child: pw.Container(
                      decoration: pw.BoxDecoration(
                        border: pw.Border.all(color: PdfColors.grey300),
                        borderRadius: pw.BorderRadius.circular(6),
                      ),
                      child: pw.Table(
                        border: pw.TableBorder.all(color: PdfColors.grey200),
                        columnWidths: const {
                          0: pw.FlexColumnWidth(1.2),
                          1: pw.FlexColumnWidth(3.5),
                          2: pw.FlexColumnWidth(1.3),
                          3: pw.FlexColumnWidth(1.3),
                        },
                        children: [
                          pw.TableRow(
                            decoration: pw.BoxDecoration(
                              color: PdfColors.grey200,
                            ),
                            children: [
                              pw.Padding(
                                padding: const pw.EdgeInsets.all(10),
                                child: pw.Text(
                                  'DATA',
                                  style: pw.TextStyle(
                                    fontSize: 10,
                                    fontWeight: pw.FontWeight.bold,
                                    color: PdfColors.black,
                                  ),
                                  textAlign: pw.TextAlign.center,
                                ),
                              ),
                              pw.Padding(
                                padding: const pw.EdgeInsets.all(10),
                                child: pw.Text(
                                  'DESCRIÇÃO',
                                  style: pw.TextStyle(
                                    fontSize: 10,
                                    fontWeight: pw.FontWeight.bold,
                                    color: PdfColors.black,
                                  ),
                                  textAlign: pw.TextAlign.center,
                                ),
                              ),
                              pw.Padding(
                                padding: const pw.EdgeInsets.all(10),
                                child: pw.Text(
                                  'VALOR',
                                  style: pw.TextStyle(
                                    fontSize: 10,
                                    fontWeight: pw.FontWeight.bold,
                                    color: PdfColors.black,
                                  ),
                                  textAlign: pw.TextAlign.center,
                                ),
                              ),
                              pw.Padding(
                                padding: const pw.EdgeInsets.all(10),
                                child: pw.Text(
                                  'SALDO',
                                  style: pw.TextStyle(
                                    fontSize: 10,
                                    fontWeight: pw.FontWeight.bold,
                                    color: PdfColors.black,
                                  ),
                                  textAlign: pw.TextAlign.center,
                                ),
                              ),
                            ],
                          ),
                          for (final item in data['transactions'])
                            pw.TableRow(
                              decoration: pw.BoxDecoration(
                                color: data['transactions'].indexOf(item).isEven
                                    ? PdfColors.white
                                    : PdfColors.grey50,
                              ),
                              children: [
                                pw.Padding(
                                  padding: const pw.EdgeInsets.all(8),
                                  child: pw.Text(
                                    format.format(item.transaction.date),
                                    style: const pw.TextStyle(
                                      fontSize: 9,
                                      color: PdfColors.grey800,
                                    ),
                                    textAlign: pw.TextAlign.center,
                                  ),
                                ),
                                pw.Padding(
                                  padding: const pw.EdgeInsets.all(8),
                                  child: pw.Text(
                                    item.transaction.description,
                                    style: const pw.TextStyle(
                                      fontSize: 9,
                                      color: PdfColors.grey800,
                                    ),
                                    maxLines: 2,
                                  ),
                                ),
                                pw.Padding(
                                  padding: const pw.EdgeInsets.all(8),
                                  child: pw.Text(
                                    '${item.transaction.isCredit ? '+' : '-'}${formatValue(item.transaction.amount)}',
                                    style: pw.TextStyle(
                                      fontSize: 9,
                                      fontWeight: pw.FontWeight.bold,
                                      color: item.transaction.isCredit
                                          ? PdfColors.green
                                          : PdfColors.red,
                                    ),
                                    textAlign: pw.TextAlign.center,
                                  ),
                                ),
                                pw.Padding(
                                  padding: const pw.EdgeInsets.all(8),
                                  child: pw.Text(
                                    formatValue(item.runningBalance),
                                    style: pw.TextStyle(
                                      fontSize: 9,
                                      fontWeight: pw.FontWeight.bold,
                                      color: item.runningBalance >= 0
                                          ? PdfColors.green
                                          : PdfColors.red,
                                    ),
                                    textAlign: pw.TextAlign.center,
                                  ),
                                ),
                              ],
                            ),
                        ],
                      ),
                    ),
                  ),

                ],
              );
            },
          ),
        );
      });

      final output = await getTemporaryDirectory();
      final fileName = 'resumo_financeiro_${DateFormat('yyyyMMdd_HHmm').format(now)}.pdf';
      final file = File('${output.path}/$fileName');
      await file.writeAsBytes(await pdf.save());

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('PDF gerado com sucesso!'),
          backgroundColor: AppColors.green,
        ),
      );

      final openResult = await OpenFile.open(file.path);
      if (openResult.type != ResultType.done) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao abrir PDF. Ficheiro salvo em: ${file.path}'),
            backgroundColor: AppColors.red,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erro ao gerar PDF: $e'),
          backgroundColor: AppColors.red,
        ),
      );
    }
  }

  Map<String, List<Transaction>> _groupTransactionsByMonth(
      List<Transaction> transactions) {
    final Map<String, List<Transaction>> monthlyMap = {};

    for (final transaction in transactions) {
      final monthKey = DateFormat('yyyy-MM').format(transaction.date);
      if (!monthlyMap.containsKey(monthKey)) {
        monthlyMap[monthKey] = [];
      }
      monthlyMap[monthKey]!.add(transaction);
    }

    final sortedKeys = monthlyMap.keys.toList()..sort((a, b) => b.compareTo(a));

    final sortedMap = <String, List<Transaction>>{};
    for (final key in sortedKeys) {
      sortedMap[key] = monthlyMap[key]!;
    }

    return sortedMap;
  }

  pw.Widget _buildMonthSummaryItem(String title, String value, PdfColor color) {
    return pw.Column(
      children: [
        pw.Text(
          title,
          style: pw.TextStyle(
            fontSize: 8,
            fontWeight: pw.FontWeight.bold,
            color: PdfColors.grey700,
          ),
        ),
        pw.SizedBox(height: 2),
        pw.Text(
          value,
          style: pw.TextStyle(
            fontSize: 10,
            fontWeight: pw.FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.light,
      appBar: AppBar(
        title: Text(
          'Resumo Financeiro',
          style: TextStyle(
            color: AppColors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: AppColors.dark,
        iconTheme: IconThemeData(color: AppColors.white),
        actions: [
          IconButton(
            icon: Icon(Icons.download, color: AppColors.white),
            onPressed: () => _exportToPdf(context),
            tooltip: 'Exportar para PDF',
          ),
        ],
      ),
      body: FutureBuilder<List<Transaction>>(
        future: dbService.getAllTransactions(sectionId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(AppColors.dark),
              ),
            );
          }

          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.error_outline,
                    color: AppColors.red,
                    size: 64,
                  ),
                  SizedBox(height: 16),
                  Text(
                    'Erro ao carregar transações',
                    style: TextStyle(
                      color: AppColors.dark,
                      fontSize: 18,
                    ),
                  ),
                ],
              ),
            );
          }

          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.receipt_long,
                    color: AppColors.grey,
                    size: 64,
                  ),
                  SizedBox(height: 16),
                  Text(
                    'Nenhuma transação para exibir',
                    style: TextStyle(
                      color: AppColors.grey,
                      fontSize: 18,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Adicione transações para ver o resumo',
                    style: TextStyle(
                      color: AppColors.grey,
                    ),
                  ),
                ],
              ),
            );
          }

          final transactions = snapshot.data!;
          final format = DateFormat('dd/MM/yyyy HH:mm');
          final currency = NumberFormat.currency(locale: 'pt_PT', symbol: '€');

          final totalBalance = transactions.fold<double>(
              0, (sum, t) => sum + (t.isCredit ? t.amount : -t.amount));

          return Column(
            children: [
              Container(
                margin: EdgeInsets.all(16),
                padding: EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.black.withAlpha(100),
                      blurRadius: 8,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Saldo Total:',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppColors.dark,
                      ),
                    ),
                    Text(
                      currency.format(totalBalance),
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color:
                            totalBalance >= 0 ? AppColors.green : AppColors.red,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Container(
                  margin: EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    color: AppColors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.black.withAlpha(100),
                        blurRadius: 8,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: SingleChildScrollView(
                      child: DataTable(
                        columnSpacing: 20,
                        horizontalMargin: 16,
                        headingRowColor:
                            WidgetStateProperty.all(AppColors.dark),
                        columns: [
                          DataColumn(
                            label: Text(
                              'Data',
                              style: TextStyle(
                                color: AppColors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          DataColumn(
                            label: Text(
                              'Descrição',
                              style: TextStyle(
                                color: AppColors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          DataColumn(
                            label: Text(
                              'Valor',
                              style: TextStyle(
                                color: AppColors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          DataColumn(
                            label: Text(
                              'Faturas',
                              style: TextStyle(
                                color: AppColors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                        rows: transactions.map((t) {
                          return DataRow(
                            cells: [
                              DataCell(
                                Text(
                                  format.format(t.date),
                                  style: TextStyle(color: AppColors.dark),
                                ),
                              ),
                              DataCell(
                                Text(
                                  t.description,
                                  style: TextStyle(color: AppColors.dark),
                                ),
                              ),
                              DataCell(
                                Text(
                                  "${t.isCredit ? '+' : '-'}${currency.format(t.amount)}",
                                  style: TextStyle(
                                    color: t.isCredit
                                        ? AppColors.green
                                        : AppColors.red,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              DataCell(
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      t.receiptPaths.isEmpty
                                          ? Icons.receipt_outlined
                                          : Icons.receipt,
                                      color: t.receiptPaths.isEmpty
                                          ? AppColors.grey
                                          : AppColors.blue,
                                      size: 20,
                                    ),
                                    SizedBox(width: 4),
                                    Text(
                                      t.receiptPaths.isEmpty
                                          ? 'Nenhuma'
                                          : '${t.receiptPaths.length}',
                                      style: TextStyle(
                                        color: AppColors.dark,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                ),
              ),
              Container(
                margin: EdgeInsets.all(16),
                child: ElevatedButton.icon(
                  onPressed: () => _exportToPdf(context),
                  icon: Icon(Icons.picture_as_pdf),
                  label: Text('Exportar para PDF'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.dark,
                    foregroundColor: AppColors.white,
                    padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
