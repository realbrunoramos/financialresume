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

    final percentageDespesa = despesa / total;

    const segments = 360;

    for (var i = 0; i < segments; i++) {
      final angle = 2 * math.pi * i / segments;
      final isDespesa = angle < 2 * math.pi * percentageDespesa;
      final color = isDespesa ? img.ColorRgb8(244,67,54) : img.ColorRgb8(76,175,80);

      final angle1 = angle;
      final angle2 = angle + 2 * math.pi / segments;

      final points = [
        img.Point(
          (center + outerRadius * math.cos(angle1)).toInt(),
          (center + outerRadius * math.sin(angle1)).toInt(),
        ),
        img.Point(
          (center + outerRadius * math.cos(angle2)).toInt(),
          (center + outerRadius * math.sin(angle2)).toInt(),
        ),
        img.Point(
          (center + innerRadius * math.cos(angle2)).toInt(),
          (center + innerRadius * math.sin(angle2)).toInt(),
        ),
        img.Point(
          (center + innerRadius * math.cos(angle1)).toInt(),
          (center + innerRadius * math.sin(angle1)).toInt(),
        ),
      ];

      img.fillPolygon(
        image,
        vertices: points,
        color: color,
      );
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
        return _TransactionWithBalance(
          transaction: t,
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

  Future<void> _exportToPdf(BuildContext context) async {
    try {
      final pdf = pw.Document();
      final transactions = await dbService.getAllTransactions(sectionId);
      final format = DateFormat('dd/MM/yyyy');
      final now = DateTime.now();

      final ByteData balanceIconData =
      await rootBundle.load('assets/images/saldo.png');
      final ByteData incomeIconData =
      await rootBundle.load('assets/images/money_gain.png');
      final ByteData expensesIconData =
      await rootBundle.load('assets/images/money_loose.png');

      final balanceIcon = pw.MemoryImage(balanceIconData.buffer.asUint8List());
      final incomeIcon = pw.MemoryImage(incomeIconData.buffer.asUint8List());
      final expensesIcon =
      pw.MemoryImage(expensesIconData.buffer.asUint8List());

      final totalIncome = transactions
          .where((t) => t.isCredit)
          .fold<double>(0, (sum, t) => sum + t.amount);

      final totalExpenses = transactions
          .where((t) => !t.isCredit)
          .fold<double>(0, (sum, t) => sum + t.amount);

      final balance = totalIncome - totalExpenses;

      final donutImage =
      _createSimpleDonutChart(despesa: totalExpenses, receita: totalIncome);
      final donutPng = img.encodePng(donutImage);
      final donutPdfImage = pw.MemoryImage(donutPng);

      String formatCurrency(double value) {
        return '${value.toStringAsFixed(2)} EUR';
      }

      final ByteData appImageBytes =
      await rootBundle.load('assets/images/app_logo.png');
      final Uint8List appImageData = appImageBytes.buffer.asUint8List();

      final monthlyData = _prepareMonthlyTablesData(transactions);

      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(15),
          build: (pw.Context context) {
            return pw.Column(
              children: [
                pw.Container(
                  margin: const pw.EdgeInsets.only(bottom: 15),
                  padding: const pw.EdgeInsets.all(10),
                  child: pw.Row(
                    crossAxisAlignment: pw.CrossAxisAlignment.center,
                    children: [
                      pw.Image(pw.MemoryImage(appImageData), width: 40, height: 40),
                      pw.SizedBox(width: 10),
                      pw.Expanded(
                        child: pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.center,
                          children: [
                            pw.Text(
                              'Relatório do Resumo Financeiro',
                              style: pw.TextStyle(
                                fontSize: 14,
                                fontWeight: pw.FontWeight.bold,
                                color: PdfColors.black,
                              ),
                            ),
                            pw.Text(
                              DateFormat('dd/MM/yyyy').format(now),
                              style: pw.TextStyle(
                                fontSize: 8,
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
                  margin: const pw.EdgeInsets.only(bottom: 15),
                  padding: const pw.EdgeInsets.all(12),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.center,
                    children: [
                      pw.Text(
                        'RECEITAS VS DESPESAS',
                        style: pw.TextStyle(
                          fontSize: 12,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.black,
                        ),
                        textAlign: pw.TextAlign.center,
                      ),
                      pw.SizedBox(height: 10),

                      pw.Center(
                        child: pw.Image(donutPdfImage, width: 200, height: 200),
                      ),
                      pw.SizedBox(height: 10),
                      pw.Container(
                        margin: pw.EdgeInsets.only(bottom: 15),
                        child: pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            pw.Row(
                              mainAxisAlignment: pw.MainAxisAlignment.spaceEvenly,
                              children: [
                                _buildSummaryCard(
                                  'Total Receitas - ${((totalIncome / (totalIncome + totalExpenses)) * 100).toStringAsFixed(1)}%',
                                  formatCurrency(totalIncome),
                                  PdfColors.green,
                                  incomeIcon,
                                ),
                                _buildSummaryCard(
                                  'Total Despesas - ${((totalExpenses / (totalIncome + totalExpenses)) * 100).toStringAsFixed(1)}%',
                                  formatCurrency(totalExpenses),
                                  PdfColors.red,
                                  expensesIcon,
                                ),
                              ],
                            ),
                            pw.SizedBox(height: 10),
                            pw.Row(
                              mainAxisAlignment: pw.MainAxisAlignment.center,
                              children: [
                                _buildSummaryCard(
                                  'Saldo Total',
                                  formatCurrency(balance),
                                  PdfColors.black,
                                  balanceIcon,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                pw.Container(
                  margin: const pw.EdgeInsets.only(top: 15),
                  padding: const pw.EdgeInsets.all(12),
                  decoration: pw.BoxDecoration(
                    color: balance >= 0
                        ? _lightenColor(PdfColors.green, 0.9)
                        : _lightenColor(PdfColors.red, 0.9),
                    borderRadius: pw.BorderRadius.circular(6),
                  ),
                  child: pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(
                            'SITUAÇÃO FINANCEIRA',
                            style: pw.TextStyle(
                              fontSize: 10,
                              fontWeight: pw.FontWeight.bold,
                              color: PdfColors.grey800,
                            ),
                          ),
                          pw.SizedBox(height: 2),
                          pw.Text(
                            balance >= 0 ? 'Saldo Positivo' : 'Saldo Negativo',
                            style: pw.TextStyle(
                              fontSize: 12,
                              fontWeight: pw.FontWeight.bold,
                              color: PdfColors.white,
                            ),
                          ),
                        ],
                      ),
                      pw.Text(
                        '${formatValue(balance.abs())} EUR',
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
                  margin: const pw.EdgeInsets.only(top: 20),
                  child: pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text(
                        'Página 1',
                        style: const pw.TextStyle(
                          fontSize: 8,
                          color: PdfColors.grey600,
                        ),
                      ),
                      pw.Text(
                        'Financial Resume App - by Bruno Ramos',
                        style: const pw.TextStyle(
                          fontSize: 8,
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


      int pageNumber = 2;
      monthlyData.forEach((monthKey, data) {
        pdf.addPage(
          pw.Page(
            pageFormat: PdfPageFormat.a4,
            margin: const pw.EdgeInsets.all(15),
            build: (pw.Context context) {
              return pw.Column(
                children: [

                  pw.Container(
                    padding: const pw.EdgeInsets.all(12),
                    decoration: pw.BoxDecoration(
                      color: PdfColors.blue,
                      borderRadius: const pw.BorderRadius.only(
                        topLeft: pw.Radius.circular(6),
                        topRight: pw.Radius.circular(6),
                      ),
                    ),
                    child: pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Text(
                          data['monthName'].toUpperCase(),
                          style: pw.TextStyle(
                            fontSize: 14,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColors.white,
                          ),
                        ),
                      ],
                    ),
                  ),


                  pw.Container(
                    padding: const pw.EdgeInsets.all(10),
                    decoration: pw.BoxDecoration(
                      color: PdfColors.grey100,
                      border: pw.Border.all(color: PdfColors.grey300),
                    ),
                    child: pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
                      children: [
                        _buildMonthSummaryItem(
                            'Receitas', formatValue(data['monthIncome']), PdfColors.green),
                        _buildMonthSummaryItem(
                            'Despesas', formatValue(data['monthExpenses']), PdfColors.red),
                        _buildMonthSummaryItem('Saldo', formatValue(data['monthBalance']),
                            data['monthBalance'] >= 0 ? PdfColors.green : PdfColors.red),
                      ],
                    ),
                  ),


                  pw.Container(
                    margin: const pw.EdgeInsets.only(top: 10),
                    decoration: pw.BoxDecoration(
                      border: pw.Border.all(color: PdfColors.grey300),
                      borderRadius: const pw.BorderRadius.only(
                        bottomLeft: pw.Radius.circular(6),
                        bottomRight: pw.Radius.circular(6),
                      ),
                    ),
                    child: pw.Table(
                      border: pw.TableBorder(
                        horizontalInside: pw.BorderSide(color: PdfColors.grey200),
                        verticalInside: pw.BorderSide(color: PdfColors.grey200),
                      ),
                      columnWidths: const {
                        0: pw.FlexColumnWidth(1.5),
                        1: pw.FlexColumnWidth(3),
                        2: pw.FlexColumnWidth(1.5),
                        3: pw.FlexColumnWidth(1.5),
                      },
                      children: [

                        pw.TableRow(
                          decoration: pw.BoxDecoration(
                            color: PdfColors.grey200,
                          ),
                          children: [
                            pw.Padding(
                              padding: const pw.EdgeInsets.all(8),
                              child: pw.Text(
                                'DATA',
                                style: pw.TextStyle(
                                  fontSize: 9,
                                  fontWeight: pw.FontWeight.bold,
                                  color: PdfColors.black,
                                ),
                                textAlign: pw.TextAlign.center,
                              ),
                            ),
                            pw.Padding(
                              padding: const pw.EdgeInsets.all(8),
                              child: pw.Text(
                                'DESCRIÇÃO',
                                style: pw.TextStyle(
                                  fontSize: 9,
                                  fontWeight: pw.FontWeight.bold,
                                  color: PdfColors.black,
                                ),
                                textAlign: pw.TextAlign.center,
                              ),
                            ),
                            pw.Padding(
                              padding: const pw.EdgeInsets.all(8),
                              child: pw.Text(
                                'VALOR',
                                style: pw.TextStyle(
                                  fontSize: 9,
                                  fontWeight: pw.FontWeight.bold,
                                  color: PdfColors.black,
                                ),
                                textAlign: pw.TextAlign.center,
                              ),
                            ),
                            pw.Padding(
                              padding: const pw.EdgeInsets.all(8),
                              child: pw.Text(
                                'SALDO',
                                style: pw.TextStyle(
                                  fontSize: 9,
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
                                padding: const pw.EdgeInsets.all(6),
                                child: pw.Text(
                                  format.format(item.transaction.date),
                                  style: const pw.TextStyle(
                                    fontSize: 8,
                                    color: PdfColors.grey800,
                                  ),
                                  textAlign: pw.TextAlign.center,
                                ),
                              ),
                              pw.Padding(
                                padding: const pw.EdgeInsets.all(6),
                                child: pw.Text(
                                  item.transaction.description,
                                  style: const pw.TextStyle(
                                    fontSize: 8,
                                    color: PdfColors.grey800,
                                  ),
                                  maxLines: 2,
                                ),
                              ),
                              pw.Padding(
                                padding: const pw.EdgeInsets.all(6),
                                child: pw.Text(
                                  '${item.transaction.isCredit ? '+' : '-'}${formatValue(item.transaction.amount)}',
                                  style: pw.TextStyle(
                                    fontSize: 8,
                                    fontWeight: pw.FontWeight.bold,
                                    color: item.transaction.isCredit
                                        ? PdfColors.green
                                        : PdfColors.red,
                                  ),
                                  textAlign: pw.TextAlign.center,
                                ),
                              ),
                              pw.Padding(
                                padding: const pw.EdgeInsets.all(6),
                                child: pw.Text(
                                  formatValue(item.runningBalance),
                                  style: pw.TextStyle(
                                    fontSize: 8,
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


                  pw.Container(
                    margin: const pw.EdgeInsets.only(top: 20),
                    child: pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Text(
                          'Página $pageNumber',
                          style: const pw.TextStyle(
                            fontSize: 8,
                            color: PdfColors.grey600,
                          ),
                        ),
                        pw.Text(
                          'Financial Resume App - by Bruno Ramos',
                          style: const pw.TextStyle(
                            fontSize: 8,
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
        pageNumber++;
      });

      final output = await getTemporaryDirectory();
      final fileName =
          'resumo_financeiro_${DateFormat('yyyyMMdd').format(now)}.pdf';
      final file = File('${output.path}/$fileName');
      await file.writeAsBytes(await pdf.save());

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('PDF Salvo com sucesso!'),
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

  pw.Widget _buildMonthTable(Map<String, dynamic> data, DateFormat format) {
    final monthName = data['monthName'] as String;
    final transactionsWithBalance = data['transactions'] as List<_TransactionWithBalance>;
    final monthIncome = data['monthIncome'] as double;
    final monthExpenses = data['monthExpenses'] as double;
    final monthBalance = data['monthBalance'] as double;

    return pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 15),
      child: pw.Column(
        children: [

          pw.Container(
            padding: const pw.EdgeInsets.all(12),
            decoration: pw.BoxDecoration(
              color: PdfColors.blue,
              borderRadius: const pw.BorderRadius.only(
                topLeft: pw.Radius.circular(6),
                topRight: pw.Radius.circular(6),
              ),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  monthName.toUpperCase(),
                  style: pw.TextStyle(
                    fontSize: 14,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.white,
                  ),
                ),
              ],
            ),
          ),


          pw.Container(
            padding: const pw.EdgeInsets.all(10),
            decoration: pw.BoxDecoration(
              color: PdfColors.grey100,
              border: pw.Border.all(color: PdfColors.grey300),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
              children: [
                _buildMonthSummaryItem(
                    'Receitas', formatValue(monthIncome), PdfColors.green),
                _buildMonthSummaryItem(
                    'Despesas', formatValue(monthExpenses), PdfColors.red),
                _buildMonthSummaryItem('Saldo', formatValue(monthBalance),
                    monthBalance >= 0 ? PdfColors.green : PdfColors.red),
              ],
            ),
          ),


          pw.Container(
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: PdfColors.grey300),
              borderRadius: const pw.BorderRadius.only(
                bottomLeft: pw.Radius.circular(6),
                bottomRight: pw.Radius.circular(6),
              ),
            ),
            child: pw.Table(
              border: pw.TableBorder(
                horizontalInside: pw.BorderSide(color: PdfColors.grey200),
                verticalInside: pw.BorderSide(color: PdfColors.grey200),
              ),
              columnWidths: const {
                0: pw.FlexColumnWidth(1.5),
                1: pw.FlexColumnWidth(3),
                2: pw.FlexColumnWidth(1.5),
                3: pw.FlexColumnWidth(1.5),
              },
              children: [

                pw.TableRow(
                  decoration: pw.BoxDecoration(
                    color: PdfColors.grey200,
                  ),
                  children: [
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(8),
                      child: pw.Text(
                        'DATA',
                        style: pw.TextStyle(
                          fontSize: 9,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.black,
                        ),
                        textAlign: pw.TextAlign.center,
                      ),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(8),
                      child: pw.Text(
                        'DESCRIÇÃO',
                        style: pw.TextStyle(
                          fontSize: 9,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.black,
                        ),
                        textAlign: pw.TextAlign.center,
                      ),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(8),
                      child: pw.Text(
                        'VALOR',
                        style: pw.TextStyle(
                          fontSize: 9,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.black,
                        ),
                        textAlign: pw.TextAlign.center,
                      ),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(8),
                      child: pw.Text(
                        'SALDO',
                        style: pw.TextStyle(
                          fontSize: 9,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.black,
                        ),
                        textAlign: pw.TextAlign.center,
                      ),
                    ),
                  ],
                ),

                for (final item in transactionsWithBalance)
                  pw.TableRow(
                    decoration: pw.BoxDecoration(
                      color: transactionsWithBalance.indexOf(item).isEven
                          ? PdfColors.white
                          : PdfColors.grey50,
                    ),
                    children: [
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(6),
                        child: pw.Text(
                          format.format(item.transaction.date),
                          style: const pw.TextStyle(
                            fontSize: 8,
                            color: PdfColors.grey800,
                          ),
                          textAlign: pw.TextAlign.center,
                        ),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(6),
                        child: pw.Text(
                          item.transaction.description,
                          style: const pw.TextStyle(
                            fontSize: 8,
                            color: PdfColors.grey800,
                          ),
                          maxLines: 2,
                        ),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(6),
                        child: pw.Text(
                          '${item.transaction.isCredit ? '+' : '-'}${formatValue(item.transaction.amount)}',
                          style: pw.TextStyle(
                            fontSize: 8,
                            fontWeight: pw.FontWeight.bold,
                            color: item.transaction.isCredit
                                ? PdfColors.green
                                : PdfColors.red,
                          ),
                          textAlign: pw.TextAlign.center,
                        ),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(6),
                        child: pw.Text(
                          formatValue(item.runningBalance),
                          style: pw.TextStyle(
                            fontSize: 8,
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
        ],
      ),
    );
  }

  List<pw.Widget> _buildMonthlyTables(
      Map<String, List<Transaction>> monthlyTransactions, DateFormat format) {
    final tables = <pw.Widget>[];

    monthlyTransactions.forEach((monthKey, transactions) {
      final monthDate = DateFormat('yyyy-MM').parse(monthKey);
      final monthName = DateFormat('MMMM yyyy', 'pt_PT').format(monthDate);


      final monthIncome = transactions
          .where((t) => t.isCredit)
          .fold<double>(0, (sum, t) => sum + t.amount);

      final monthExpenses = transactions
          .where((t) => !t.isCredit)
          .fold<double>(0, (sum, t) => sum + t.amount);

      final monthBalance = monthIncome - monthExpenses;


      transactions.sort((a, b) => b.date.compareTo(a.date));


      double runningBalance = 0;
      final transactionsWithBalance = transactions.map((t) {
        runningBalance += t.isCredit ? t.amount : -t.amount;
        return _TransactionWithBalance(
          transaction: t,
          runningBalance: runningBalance,
        );
      }).toList();

      tables.addAll([
        pw.Container(
          margin: const pw.EdgeInsets.only(bottom: 15),
          child: pw.Column(
            children: [

              pw.Container(
                padding: const pw.EdgeInsets.all(12),
                decoration: pw.BoxDecoration(
                  color: PdfColors.blue,
                  borderRadius: const pw.BorderRadius.only(
                    topLeft: pw.Radius.circular(6),
                    topRight: pw.Radius.circular(6),
                  ),
                ),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(
                      monthName.toUpperCase(),
                      style: pw.TextStyle(
                        fontSize: 14,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.white,
                      ),
                    ),
                  ],
                ),
              ),

              pw.Container(
                padding: const pw.EdgeInsets.all(10),
                decoration: pw.BoxDecoration(
                  color: PdfColors.grey100,
                  border: pw.Border.all(color: PdfColors.grey300),
                ),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
                  children: [
                    _buildMonthSummaryItem(
                        'Receitas', formatValue(monthIncome), PdfColors.green),
                    _buildMonthSummaryItem(
                        'Despesas', formatValue(monthExpenses), PdfColors.red),
                    _buildMonthSummaryItem('Saldo', formatValue(monthBalance),
                        monthBalance >= 0 ? PdfColors.green : PdfColors.red),
                  ],
                ),
              ),

              pw.Container(
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: PdfColors.grey300),
                  borderRadius: const pw.BorderRadius.only(
                    bottomLeft: pw.Radius.circular(6),
                    bottomRight: pw.Radius.circular(6),
                  ),
                ),
                child: pw.Table(
                  border: pw.TableBorder(
                    horizontalInside: pw.BorderSide(color: PdfColors.grey200),
                    verticalInside: pw.BorderSide(color: PdfColors.grey200),
                  ),
                  columnWidths: const {
                    0: pw.FlexColumnWidth(1.5),
                    1: pw.FlexColumnWidth(3),
                    2: pw.FlexColumnWidth(1.5),
                    3: pw.FlexColumnWidth(1.5),
                  },
                  children: [
                    pw.TableRow(
                      decoration: pw.BoxDecoration(
                        color: PdfColors.grey200,
                      ),
                      children: [
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(8),
                          child: pw.Text(
                            'DATA',
                            style: pw.TextStyle(
                              fontSize: 9,
                              fontWeight: pw.FontWeight.bold,
                              color: PdfColors.black,
                            ),
                            textAlign: pw.TextAlign.center,
                          ),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(8),
                          child: pw.Text(
                            'DESCRIÇÃO',
                            style: pw.TextStyle(
                              fontSize: 9,
                              fontWeight: pw.FontWeight.bold,
                              color: PdfColors.black,
                            ),
                            textAlign: pw.TextAlign.center,
                          ),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(8),
                          child: pw.Text(
                            'VALOR',
                            style: pw.TextStyle(
                              fontSize: 9,
                              fontWeight: pw.FontWeight.bold,
                              color: PdfColors.black,
                            ),
                            textAlign: pw.TextAlign.center,
                          ),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(8),
                          child: pw.Text(
                            'SALDO',
                            style: pw.TextStyle(
                              fontSize: 9,
                              fontWeight: pw.FontWeight.bold,
                              color: PdfColors.black,
                            ),
                            textAlign: pw.TextAlign.center,
                          ),
                        ),
                      ],
                    ),
                    for (final item in transactionsWithBalance)
                      pw.TableRow(
                        decoration: pw.BoxDecoration(
                          color: transactionsWithBalance.indexOf(item).isEven
                              ? PdfColors.white
                              : PdfColors.grey50,
                        ),
                        children: [
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(6),
                            child: pw.Text(
                              format.format(item.transaction.date),
                              style: const pw.TextStyle(
                                fontSize: 8,
                                color: PdfColors.grey800,
                              ),
                              textAlign: pw.TextAlign.center,
                            ),
                          ),
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(6),
                            child: pw.Text(
                              item.transaction.description,
                              style: const pw.TextStyle(
                                fontSize: 8,
                                color: PdfColors.grey800,
                              ),
                              maxLines: 2,
                            ),
                          ),
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(6),
                            child: pw.Text(
                              '${item.transaction.isCredit ? '+' : '-'}${formatValue(item.transaction.amount)}',
                              style: pw.TextStyle(
                                fontSize: 8,
                                fontWeight: pw.FontWeight.bold,
                                color: item.transaction.isCredit
                                    ? PdfColors.green
                                    : PdfColors.red,
                              ),
                              textAlign: pw.TextAlign.center,
                            ),
                          ),
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(6),
                            child: pw.Text(
                              formatValue(item.runningBalance),
                              style: pw.TextStyle(
                                fontSize: 8,
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
            ],
          ),
        ),
        pw.SizedBox(height: 100),
      ]);
    });

    return tables;
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

  PdfColor _lightenColor(PdfColor color, double factor) {
    if (color == PdfColors.green) return PdfColors.lightGreen;
    if (color == PdfColors.red) return PdfColors.pink;
    return color;
  }

  pw.Widget _buildSummaryCard(
      String title, String value, PdfColor color, pw.MemoryImage icon) {
    return pw.Container(
      width: 120,
      padding: const pw.EdgeInsets.all(10),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        mainAxisAlignment: pw.MainAxisAlignment.center,
        children: [
          pw.Row(
            children: [
              pw.Image(
                icon,
                width: 20,
                height: 20,
              ),
              pw.SizedBox(width: 4),
              pw.Expanded(
                child: pw.Text(
                  title,
                  style: pw.TextStyle(
                    fontSize: 12,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.grey700,
                  ),
                  maxLines: 2,
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 4),
          pw.Text(
            value,
            style: pw.TextStyle(
              fontSize: 12,
              fontWeight: pw.FontWeight.bold,
              color: color,
            ),
            textAlign: pw.TextAlign.center,
          ),
        ],
      ),
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
