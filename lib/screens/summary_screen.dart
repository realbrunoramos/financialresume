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
import '../l10n/app_localizations.dart';
import '../models/transaction.dart';
import '../models/reserved_amount.dart';
import '../services/database_service.dart';
import '../theme/colors.dart';
import '../theme/app_tokens.dart';

class _TransactionWithBalance {
  final Transaction transaction;
  final double runningBalance;

  _TransactionWithBalance({
    required this.transaction,
    required this.runningBalance,
  });
}

class SummaryScreen extends StatefulWidget {
  final String sectionId;

  const SummaryScreen({super.key, required this.sectionId});

  @override
  State<SummaryScreen> createState() => _SummaryScreenState();
}

class _SummaryScreenState extends State<SummaryScreen> {
  final DatabaseService dbService = DatabaseService();
  List<String> _selectedMonths = [];
  List<Transaction> _allTransactions = [];
  List<ReservedAmount> _allReservedAmounts = [];
  double _totalReserved = 0.0;
  double _availableAmount = 0.0;
  bool _isLoading = true;
  bool _isExporting = false;
  bool _includeReserveAmount = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final transactions = await dbService.getAllTransactions(widget.sectionId);
      final reservedAmounts = await dbService.getReservedAmounts(widget.sectionId);
      final totalReserved = reservedAmounts.fold<double>(0.0, (sum, r) => sum + r.amount,);

      final balance = transactions.fold<double>(0, (sum, t) => sum + (t.isCredit ? t.amount : -t.amount),);

      final availableAmount = (balance - totalReserved) < 0 ? 0 : balance - totalReserved;

      setState(() {
        _allTransactions = transactions;
        _allReservedAmounts = reservedAmounts;
        _totalReserved = totalReserved;
        _availableAmount = availableAmount as double;
        _selectedMonths = _getAvailableMonths();
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  List<String> _getAvailableMonths() {
    final months = <String>{};
    for (final transaction in _allTransactions) {
      final monthKey = DateFormat('yyyy-MM').format(transaction.date);
      months.add(monthKey);
    }
    return months.toList()..sort((a, b) => b.compareTo(a));
  }

  List<Transaction> _getFilteredTransactions() {
    if (_selectedMonths.isEmpty) return _allTransactions;

    return _allTransactions.where((transaction) {
      final monthKey = DateFormat('yyyy-MM').format(transaction.date);
      return _selectedMonths.contains(monthKey);
    }).toList();
  }

  Map<String, dynamic> _calculateFinancialMetrics(List<Transaction> transactions) {
    final totalIncome = transactions.where((t) => t.isCredit).fold<double>(0, (sum, t) => sum + t.amount);
    final totalExpenses = transactions.where((t) => !t.isCredit).fold<double>(0, (sum, t) => sum + t.amount);
    final balance = totalIncome - totalExpenses;

    final availableAmount = (balance - _totalReserved) < 0 ? 0 : balance - _totalReserved;

    return {
      'totalIncome': totalIncome,
      'totalExpenses': totalExpenses,
      'balance': balance,
      'totalReserved': _totalReserved,
      'availableAmount': availableAmount,
      'reservedAmounts': _allReservedAmounts,
    };
  }

  void _showMonthSelectionDialog() {
    final availableMonths = _getAvailableMonths();
    final l      = AppLocalizations.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setSheetState) {
          return SafeArea(
            child: Container(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.7,
              ),
              margin: const EdgeInsets.all(AppTokens.sp12),
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkCard : AppColors.white,
                borderRadius: BorderRadius.circular(AppTokens.radius24),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Handle
                  Container(
                    width: 36, height: 4,
                    margin: const EdgeInsets.only(top: AppTokens.sp12),
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.darkBorder : AppColors.grey200,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  // Title + actions
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                        AppTokens.sp20, AppTokens.sp12, AppTokens.sp12, 0),
                    child: Row(children: [
                      Expanded(
                        child: Text(l.selectMonths,
                            style: TextStyle(
                              fontSize: 17, fontWeight: FontWeight.w700,
                              color: isDark ? AppColors.darkText : AppColors.dark,
                              letterSpacing: -0.3,
                            )),
                      ),
                      TextButton(
                        onPressed: () => setSheetState(() =>
                            _selectedMonths = availableMonths.toList()),
                        child: Text(l.selectAll),
                      ),
                      TextButton(
                        onPressed: () =>
                            setSheetState(() => _selectedMonths.clear()),
                        child: Text(l.clear),
                      ),
                    ]),
                  ),
                  // Month list
                  Flexible(
                    child: ListView(
                      shrinkWrap: true,
                      padding: const EdgeInsets.symmetric(
                          horizontal: AppTokens.sp8),
                      children: availableMonths.map((key) {
                        final date  = DateFormat('yyyy-MM').parse(key);
                        final name  = DateFormat('MMMM yyyy', l.monthName)
                            .format(date);
                        final sel   = _selectedMonths.contains(key);
                        return CheckboxListTile(
                          title: Text(name,
                              style: TextStyle(
                                  color: isDark
                                      ? AppColors.darkText
                                      : AppColors.dark)),
                          value: sel,
                          activeColor: AppColors.info,
                          onChanged: (v) => setSheetState(() {
                            if (v == true) {
                              _selectedMonths.add(key);
                            } else {
                              _selectedMonths.remove(key);
                            }
                          }),
                        );
                      }).toList(),
                    ),
                  ),
                  // Apply button
                  Padding(
                    padding: const EdgeInsets.all(AppTokens.sp16),
                    child: SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: () {
                          Navigator.pop(ctx);
                          setState(() {});
                        },
                        child: Text(l.apply),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

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
      if (_selectedMonths.isNotEmpty && !_selectedMonths.contains(monthKey)) {
        return;
      }

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
      final monthName = DateFormat('MMMM yyyy', AppLocalizations.of(context).monthName).format(monthDate);

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

  pw.Widget _buildReserveAmountDetails(Map<String, dynamic> metrics) {
    final totalReserved = metrics['totalReserved'] as double;
    final availableAmount = metrics['availableAmount'] as double;
    final balance = metrics['balance'] as double;
    final reservedAmounts = metrics['reservedAmounts'] as List<ReservedAmount>;

    return pw.Container(
      margin: const pw.EdgeInsets.only(top: 20),
      padding: const pw.EdgeInsets.all(16),
      decoration: pw.BoxDecoration(
        color: PdfColors.blue50,
        borderRadius: pw.BorderRadius.circular(8),
        border: pw.Border.all(color: PdfColors.blue, width: 1),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            'Detalhes dos Valores Reservados',
            style: pw.TextStyle(
              fontSize: 14,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.blue,
            ),
          ),
          pw.SizedBox(height: 12),

          // Resumo Financeiro
          pw.Container(
            padding: const pw.EdgeInsets.all(12),
            decoration: pw.BoxDecoration(
              color: PdfColors.white,
              borderRadius: pw.BorderRadius.circular(6),
              border: pw.Border.all(color: PdfColors.grey300),
            ),
            child: pw.Column(
              children: [
                // Saldo Total
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(
                      'Saldo Total:',
                      style: pw.TextStyle(
                        fontSize: 10,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.Text(
                      '${formatValue(balance)} EUR',
                      style: pw.TextStyle(
                        fontSize: 10,
                        fontWeight: pw.FontWeight.bold,
                        color: balance >= 0 ? PdfColors.green : PdfColors.red,
                      ),
                    ),
                  ],
                ),
                pw.SizedBox(height: 6),

                // Total Reservado
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(
                      'Total Reservado:',
                      style: pw.TextStyle(
                        fontSize: 10,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.Text(
                      '${formatValue(totalReserved)} EUR',
                      style: pw.TextStyle(
                        fontSize: 10,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.blue,
                      ),
                    ),
                  ],
                ),
                pw.SizedBox(height: 6),

                // Valor Disponível
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(
                      'Valor Disponível:',
                      style: pw.TextStyle(
                        fontSize: 10,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.Text(
                      '${formatValue(availableAmount)} EUR',
                      style: pw.TextStyle(
                        fontSize: 10,
                        fontWeight: pw.FontWeight.bold,
                        color: availableAmount >= 0 ? PdfColors.green : PdfColors.red,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          pw.SizedBox(height: 12),

          // Lista de Valores Reservados
          if (reservedAmounts.isNotEmpty) ...[
            pw.Text(
              'Valores Reservados Detalhados:',
              style: pw.TextStyle(
                fontSize: 12,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
            pw.SizedBox(height: 8),

            // Cabeçalho da tabela
            pw.Container(
              decoration: pw.BoxDecoration(
                color: PdfColors.grey200,
                borderRadius: pw.BorderRadius.circular(4),
              ),
              child: pw.Row(
                children: [
                  pw.Expanded(
                    flex: 3,
                    child: pw.Padding(
                      padding: const pw.EdgeInsets.all(8),
                      child: pw.Text(
                        'Descrição',
                        style: pw.TextStyle(
                          fontSize: 9,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  pw.Expanded(
                    flex: 1,
                    child: pw.Padding(
                      padding: const pw.EdgeInsets.all(8),
                      child: pw.Text(
                        'Valor',
                        style: pw.TextStyle(
                          fontSize: 9,
                          fontWeight: pw.FontWeight.bold,
                        ),
                        textAlign: pw.TextAlign.right,
                      ),
                    ),
                  ),
                  pw.Expanded(
                    flex: 1,
                    child: pw.Padding(
                      padding: const pw.EdgeInsets.all(8),
                      child: pw.Text(
                        'Data',
                        style: pw.TextStyle(
                          fontSize: 9,
                          fontWeight: pw.FontWeight.bold,
                        ),
                        textAlign: pw.TextAlign.right,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Itens da tabela
            for (int i = 0; i < reservedAmounts.length; i++)
              pw.Container(
                decoration: pw.BoxDecoration(
                  color: i.isEven ? PdfColors.white : PdfColors.grey50,
                  border: pw.Border.all(color: PdfColors.grey300, width: 0.5),
                ),
                child: pw.Row(
                  children: [
                    pw.Expanded(
                      flex: 3,
                      child: pw.Padding(
                        padding: const pw.EdgeInsets.all(8),
                        child: pw.Text(
                          reservedAmounts[i].description,
                          style: const pw.TextStyle(fontSize: 8),
                          maxLines: 2,
                        ),
                      ),
                    ),
                    pw.Expanded(
                      flex: 1,
                      child: pw.Padding(
                        padding: const pw.EdgeInsets.all(8),
                        child: pw.Text(
                          '${formatValue(reservedAmounts[i].amount)} EUR',
                          style: pw.TextStyle(
                            fontSize: 8,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColors.blue,
                          ),
                          textAlign: pw.TextAlign.right,
                        ),
                      ),
                    ),
                    pw.Expanded(
                      flex: 1,
                      child: pw.Padding(
                        padding: const pw.EdgeInsets.all(8),
                        child: pw.Text(
                          DateFormat('dd/MM/yy').format(reservedAmounts[i].createdAt),
                          style: const pw.TextStyle(fontSize: 7),
                          textAlign: pw.TextAlign.right,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

            // Total
            pw.Container(
              decoration: pw.BoxDecoration(
                color: PdfColors.blue100,
                border: pw.Border.all(color: PdfColors.blue, width: 1),
              ),
              child: pw.Row(
                children: [
                  pw.Expanded(
                    flex: 3,
                    child: pw.Padding(
                      padding: const pw.EdgeInsets.all(8),
                      child: pw.Text(
                        'TOTAL RESERVADO:',
                        style: pw.TextStyle(
                          fontSize: 9,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  pw.Expanded(
                    flex: 2,
                    child: pw.Padding(
                      padding: const pw.EdgeInsets.all(8),
                      child: pw.Text(
                        '${formatValue(totalReserved)} EUR',
                        style: pw.TextStyle(
                          fontSize: 9,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.blue,
                        ),
                        textAlign: pw.TextAlign.right,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ] else ...[
            pw.Center(
              child: pw.Text(
                'Nenhum valor reservado encontrado',
                style: pw.TextStyle(
                  fontSize: 10,
                  color: PdfColors.grey600,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _exportToPdf(BuildContext context) async {
    if (_isExporting || !_canExport()) return;

    setState(() {
      _isExporting = true;
    });

    try {
      final loc = AppLocalizations.of(context);
      final pdf = pw.Document();
      final filteredTransactions = _getFilteredTransactions();
      final format = DateFormat('dd/MM/yyyy');
      final now = DateTime.now();

      if (filteredTransactions.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context).noTransactionsSelectedForExport),
            backgroundColor: AppColors.red,
          ),
        );
        return;
      }

      final ByteData incomeIconData = await rootBundle.load('assets/images/money_gain.png');
      final ByteData expensesIconData = await rootBundle.load('assets/images/money_loose.png');

      final incomeIcon = pw.MemoryImage(incomeIconData.buffer.asUint8List());
      final expensesIcon = pw.MemoryImage(expensesIconData.buffer.asUint8List());

      final metrics = _calculateFinancialMetrics(filteredTransactions);
      final totalIncome = metrics['totalIncome'] as double;
      final totalExpenses = metrics['totalExpenses'] as double;
      final balance = metrics['balance'] as double;

      final donutImage = _createSimpleDonutChart(despesa: totalExpenses, receita: totalIncome);
      final donutPng = img.encodePng(donutImage);
      final donutPdfImage = pw.MemoryImage(donutPng);

      String formatCurrency(double value) {
        return '${value.toStringAsFixed(2)} EUR';
      }

      final ByteData appImageBytes = await rootBundle.load('assets/images/app_logo.png');
      final Uint8List appImageData = appImageBytes.buffer.asUint8List();

      final monthlyData = _prepareMonthlyTablesData(filteredTransactions);

      // Página de resumo
      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(25),
          build: (pw.Context context) {
            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                // Cabeçalho
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
                              loc.financialSummaryReport,
                              style: pw.TextStyle(
                                fontSize: 16,
                                fontWeight: pw.FontWeight.bold,
                              ),
                            ),
                            pw.Text(
                              '${loc.periodVariable} ${_getSelectedMonthsRange()}',
                              style: pw.TextStyle(
                                fontSize: 10,
                                color: PdfColors.grey600,
                              ),
                            ),
                            pw.Text(
                              '${loc.generatedOn} ${DateFormat('dd/MM/yyyy').format(now)}',
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

                // Visão Geral
                pw.Container(
                  margin: const pw.EdgeInsets.only(bottom: 20),
                  padding: const pw.EdgeInsets.all(16),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.center,
                    children: [
                      pw.Text(
                        loc.overviewOfSelectedPeriod,
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
                                _buildStatCard(
                                    loc.totalIncome,
                                    formatCurrency(totalIncome),
                                    PdfColors.green,
                                    incomeIcon,
                                    totalIncome + totalExpenses > 0
                                        ? '${((totalIncome / (totalIncome + totalExpenses)) * 100).toStringAsFixed(1)}%'
                                        : '0%'
                                ),
                                pw.SizedBox(height: 10),
                                _buildStatCard(
                                    loc.totalExpenses,
                                    formatCurrency(totalExpenses),
                                    PdfColors.red,
                                    expensesIcon,
                                    totalIncome + totalExpenses > 0
                                        ? '${((totalExpenses / (totalIncome + totalExpenses)) * 100).toStringAsFixed(1)}%'
                                        : '0%'
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // Situação Financeira
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
                            loc.financialSituationOfPeriod,
                            style: pw.TextStyle(
                              fontSize: 12,
                              fontWeight: pw.FontWeight.bold,
                              color: PdfColors.white,
                            ),
                          ),
                          pw.SizedBox(height: 4),
                          pw.Text(
                            balance >= 0 ? loc.positiveBalance : loc.negativeBalance,
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

                // Seção de Valores Reservados
                if (_includeReserveAmount)
                  _buildReserveAmountDetails(metrics),

                pw.SizedBox(height: 20),

                // Resumo dos meses selecionados
                if (monthlyData.isNotEmpty)
                  pw.Text(
                    loc.monthsIncludedInReport,
                    style: pw.TextStyle(
                      fontSize: 12,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                pw.SizedBox(height: 8),
                pw.Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: monthlyData.values.map((data) {
                    return pw.Container(
                      padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: pw.BoxDecoration(
                        color: PdfColors.blue50,
                        borderRadius: pw.BorderRadius.circular(4),
                      ),
                      child: pw.Text(
                        data['monthName'],
                        style: const pw.TextStyle(fontSize: 9),
                      ),
                    );
                  }).toList(),
                ),

                pw.Spacer(),

                // Rodapé
                pw.Container(
                  margin: const pw.EdgeInsets.only(top: 20),
                  padding: const pw.EdgeInsets.all(12),
                  child: pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text(
                        'Financial Resume App',
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
                        _buildMonthSummaryItem(loc.income, formatValue(data['monthIncome']), PdfColors.green),
                        _buildMonthSummaryItem(loc.expenses, formatValue(data['monthExpenses']), PdfColors.red),
                        _buildMonthSummaryItem(loc.balance, formatValue(data['monthBalance']),
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
                                  loc.dateHeader,
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
                                  loc.descriptionHeader,
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
                                  loc.valueHeader,
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
                                  loc.balanceHeader,
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

                  // Rodapé da página
                  pw.Container(
                    margin: const pw.EdgeInsets.only(top: 10),
                    padding: const pw.EdgeInsets.all(12),
                    child: pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Text(
                          'Financial Resume App',
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
      });

      final output = await getTemporaryDirectory();
      final fileName = 'financial_resume_${DateFormat('yyyy_MM').format(now)}.pdf';
      final file = File('${output.path}/$fileName');
      await file.writeAsBytes(await pdf.save());

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context).exportedPdf),
          backgroundColor: AppColors.green,
        ),
      );

      final openResult = await OpenFile.open(file.path);
      if (openResult.type != ResultType.done) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${AppLocalizations.of(context).errorOpeningPdfFileSavedIn} ${file.path}'),
            backgroundColor: AppColors.red,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${AppLocalizations.of(context).errorGeneratingPdf} $e'),
          backgroundColor: AppColors.red,
        ),
      );
    } finally {
      setState(() {
        _isExporting = false;
      });
    }
  }

  String _getSelectedMonthsRange() {
    if (_selectedMonths.isEmpty) return AppLocalizations.of(context).noMonthSelected;

    final months = _selectedMonths.map((key) {
      final date = DateFormat('yyyy-MM').parse(key);
      return DateFormat('MMMM yyyy', 'pt_PT').format(date);
    }).toList();

    if (months.length == 1) return months.first;
    return '${months.length} ${AppLocalizations.of(context).selectMonths}';
  }

  Map<String, List<Transaction>> _groupTransactionsByMonth(List<Transaction> transactions) {
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

  Widget _buildMonthFilterChip() {
    final l      = AppLocalizations.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final hasSel = _selectedMonths.isNotEmpty;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
          AppTokens.sp16, AppTokens.sp8, AppTokens.sp16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: _showMonthSelectionDialog,
            borderRadius: BorderRadius.circular(AppTokens.radius12),
            child: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: AppTokens.sp16, vertical: AppTokens.sp12),
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkCard : AppColors.white,
                borderRadius: BorderRadius.circular(AppTokens.radius12),
                border: Border.all(
                  color: hasSel
                      ? AppColors.info
                      : (isDark ? AppColors.darkBorder : AppColors.grey200),
                  width: hasSel ? 1.5 : 1,
                ),
                boxShadow: isDark ? null : AppTokens.shadowSm,
              ),
              child: Row(children: [
                Icon(Icons.calendar_month_rounded,
                    size: 18,
                    color: hasSel
                        ? AppColors.info
                        : (isDark ? AppColors.darkSubtext : AppColors.grey400)),
                const SizedBox(width: AppTokens.sp10),
                Expanded(
                  child: Text(
                    hasSel
                        ? '${_selectedMonths.length} ${l.months}'
                        : l.noMonthSelected,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: hasSel
                          ? AppColors.info
                          : (isDark
                              ? AppColors.darkSubtext
                              : AppColors.grey500),
                    ),
                  ),
                ),
                Icon(Icons.tune_rounded,
                    size: 18,
                    color:
                        isDark ? AppColors.darkSubtext : AppColors.grey400),
              ]),
            ),
          ),
          if (!hasSel) ...[
            const SizedBox(height: AppTokens.sp4),
            Padding(
              padding: const EdgeInsets.only(left: AppTokens.sp4),
              child: Text(
                l.selectAtLeastOneMonthToExport,
                style: const TextStyle(
                    color: AppColors.danger, fontSize: 12),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildReserveAmountSummary() {
    if (!_includeReserveAmount) return const SizedBox.shrink();

    final isDark  = Theme.of(context).brightness == Brightness.dark;
    final cur     = NumberFormat.currency(locale: 'pt_PT', symbol: '€');
    final balance = _getFilteredTransactions().fold<double>(
        0, (s, t) => s + (t.isCredit ? t.amount : -t.amount));

    return Container(
      margin: const EdgeInsets.fromLTRB(
          AppTokens.sp16, AppTokens.sp8, AppTokens.sp16, 0),
      padding: const EdgeInsets.all(AppTokens.sp16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : AppColors.white,
        borderRadius: BorderRadius.circular(AppTokens.radius16),
        border: Border.all(
            color: isDark ? AppColors.darkBorder : AppColors.grey100),
        boxShadow: isDark ? null : AppTokens.shadowSm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Icon(Icons.savings_rounded,
                size: 16, color: AppColors.info),
            const SizedBox(width: AppTokens.sp8),
            Text(AppLocalizations.of(context).amountReservations,
                style: TextStyle(
                  fontSize: 15, fontWeight: FontWeight.w600,
                  color: isDark ? AppColors.darkText : AppColors.dark,
                )),
          ]),
          const SizedBox(height: AppTokens.sp12),
          _SummaryRow(
              label: AppLocalizations.of(context).balance,
              value: cur.format(balance),
              color: isDark ? AppColors.darkText : AppColors.dark,
              isDark: isDark),
          const SizedBox(height: AppTokens.sp6),
          _SummaryRow(
              label: AppLocalizations.of(context).totalReserved,
              value: cur.format(_totalReserved),
              color: AppColors.info,
              isDark: isDark),
          const SizedBox(height: AppTokens.sp6),
          _SummaryRow(
              label: AppLocalizations.of(context).availableAmount,
              value: cur.format(_availableAmount),
              color: _availableAmount >= 0
                  ? AppColors.success
                  : AppColors.danger,
              isDark: isDark),
          if (_allReservedAmounts.isNotEmpty) ...[
            Divider(height: AppTokens.sp24,
                color: isDark ? AppColors.darkBorder : AppColors.grey100),
            ..._allReservedAmounts.map((r) => Padding(
                  padding: const EdgeInsets.only(bottom: AppTokens.sp6),
                  child: Row(children: [
                    Expanded(
                      child: Text(r.description,
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark
                                ? AppColors.darkSubtext
                                : AppColors.grey500,
                          )),
                    ),
                    const SizedBox(width: AppTokens.sp8),
                    Text(cur.format(r.amount),
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.info,
                        )),
                  ]),
                )),
          ],
        ],
      ),
    );
  }

  bool _canExport() {
    return _selectedMonths.isNotEmpty && _getFilteredTransactions().isNotEmpty;
  }

  @override
  Widget build(BuildContext context) {
    final l       = AppLocalizations.of(context);
    final isDark  = Theme.of(context).brightness == Brightness.dark;
    final cur     = NumberFormat.currency(locale: 'pt_PT', symbol: '€');
    final filtered = _getFilteredTransactions();
    final metrics  = _calculateFinancialMetrics(filtered);
    final balance  = metrics['balance'] as double;

    return Scaffold(
      backgroundColor:
          isDark ? AppColors.darkBackground : const Color(0xFFF5F5F7),
      appBar: AppBar(
        backgroundColor:
            isDark ? AppColors.darkSurface : const Color(0xFF1C1C1E),
        foregroundColor: AppColors.white,
        elevation: 0,
        title: Text(l.financialSummary,
            style: const TextStyle(
                color: AppColors.white,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.3)),
        actions: [
          if (!_isLoading && _allTransactions.isNotEmpty)
            IconButton(
              icon: _isExporting
                  ? const SizedBox(
                      width: 20, height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation(AppColors.white)))
                  : Icon(Icons.download_rounded,
                      color: _selectedMonths.isEmpty
                          ? AppColors.grey500
                          : AppColors.white),
              onPressed: _isExporting || _selectedMonths.isEmpty
                  ? null
                  : () => _exportToPdf(context),
              tooltip: _selectedMonths.isEmpty
                  ? l.selectMonthsToExport
                  : l.exportToPdf,
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _allTransactions.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.receipt_long_rounded,
                          size: 64,
                          color: isDark
                              ? AppColors.darkSubtext
                              : AppColors.grey300),
                      const SizedBox(height: AppTokens.sp16),
                      Text(l.noTransactionsToDisplay,
                          style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: isDark
                                  ? AppColors.darkText
                                  : AppColors.dark)),
                      const SizedBox(height: AppTokens.sp8),
                      Text(l.addTransactionsToViewSummary,
                          style: TextStyle(
                              color: isDark
                                  ? AppColors.darkSubtext
                                  : AppColors.grey500)),
                    ],
                  ),
                )
              : Column(
                  children: [
                    // Month filter
                    const SizedBox(height: AppTokens.sp12),
                    _buildMonthFilterChip(),

                    // Include reservations toggle
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: AppTokens.sp16, vertical: AppTokens.sp4),
                      child: Row(children: [
                        Checkbox(
                          value: _includeReserveAmount,
                          activeColor: AppColors.info,
                          onChanged: (v) => setState(
                              () => _includeReserveAmount = v ?? false),
                        ),
                        Expanded(
                          child: Text(
                            l.amountReservations,
                            style: TextStyle(
                              fontSize: 14,
                              color: isDark
                                  ? AppColors.darkText
                                  : AppColors.dark,
                            ),
                          ),
                        ),
                      ]),
                    ),

                    _buildReserveAmountSummary(),

                    // Balance card
                    Container(
                      margin: EdgeInsets.fromLTRB(
                          AppTokens.sp16,
                          _includeReserveAmount
                              ? AppTokens.sp8
                              : AppTokens.sp8,
                          AppTokens.sp16, AppTokens.sp8),
                      padding: const EdgeInsets.all(AppTokens.sp16),
                      decoration: BoxDecoration(
                        color: isDark ? AppColors.darkCard : AppColors.white,
                        borderRadius:
                            BorderRadius.circular(AppTokens.radius16),
                        border: Border.all(
                            color: isDark
                                ? AppColors.darkBorder
                                : AppColors.grey100),
                        boxShadow: isDark ? null : AppTokens.shadowSm,
                      ),
                      child: Column(children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(l.periodLabel,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: isDark
                                      ? AppColors.darkSubtext
                                      : AppColors.grey500,
                                )),
                            Text(_getSelectedMonthsRange(),
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.info,
                                )),
                          ],
                        ),
                        const SizedBox(height: AppTokens.sp10),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(l.totalBalance,
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: isDark
                                      ? AppColors.darkText
                                      : AppColors.dark,
                                )),
                            Text(cur.format(balance),
                                style: TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: -0.5,
                                  color: balance >= 0
                                      ? AppColors.success
                                      : AppColors.danger,
                                )),
                          ],
                        ),
                      ]),
                    ),

                    // Income / Expense stat cards
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: AppTokens.sp16),
                      child: Row(children: [
                        Expanded(
                          child: _buildQuickStatCard(
                            l.income,
                            metrics['totalIncome'] as double,
                            AppColors.success,
                            Icons.trending_up_rounded,
                          ),
                        ),
                        const SizedBox(width: AppTokens.sp8),
                        Expanded(
                          child: _buildQuickStatCard(
                            l.expenses,
                            metrics['totalExpenses'] as double,
                            AppColors.danger,
                            Icons.trending_down_rounded,
                          ),
                        ),
                      ]),
                    ),

                    // Transactions data table
                    Expanded(
                      child: Container(
                        margin: const EdgeInsets.all(AppTokens.sp16),
                        decoration: BoxDecoration(
                          color: isDark ? AppColors.darkCard : AppColors.white,
                          borderRadius:
                              BorderRadius.circular(AppTokens.radius16),
                          border: Border.all(
                              color: isDark
                                  ? AppColors.darkBorder
                                  : AppColors.grey100),
                          boxShadow: isDark ? null : AppTokens.shadowSm,
                        ),
                        child: ClipRRect(
                          borderRadius:
                              BorderRadius.circular(AppTokens.radius16),
                          child: _buildTransactionsTable(),
                        ),
                      ),
                    ),
                  ],
                ),
    );
  }

  Widget _buildQuickStatCard(
      String title, double value, Color color, IconData icon) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(AppTokens.sp14),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : AppColors.white,
        borderRadius: BorderRadius.circular(AppTokens.radius12),
        border: Border.all(
            color: isDark ? AppColors.darkBorder : AppColors.grey100),
        boxShadow: isDark ? null : AppTokens.shadowSm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Container(
              padding: const EdgeInsets.all(5),
              decoration: BoxDecoration(
                color: color.withAlpha(isDark ? 40 : 20),
                borderRadius: BorderRadius.circular(AppTokens.radius6),
              ),
              child: Icon(icon, size: 13, color: color),
            ),
            const SizedBox(width: AppTokens.sp6),
            Text(title,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.2,
                  color: isDark ? AppColors.darkSubtext : AppColors.grey500,
                )),
          ]),
          const SizedBox(height: AppTokens.sp8),
          Text(
            NumberFormat.currency(locale: 'pt_PT', symbol: '€').format(value),
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: color,
              letterSpacing: -0.3,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTransactionsTable() {
    final txns   = _getFilteredTransactions();
    final fmt    = DateFormat('dd/MM/yyyy');
    final cur    = NumberFormat.currency(locale: 'pt_PT', symbol: '€');
    final l      = AppLocalizations.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final hdrBg  = isDark ? AppColors.darkSurface : AppColors.dark;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: SingleChildScrollView(
        child: DataTable(
          columnSpacing: 20,
          horizontalMargin: AppTokens.sp16,
          headingRowColor: WidgetStateProperty.all(hdrBg),
          dataRowColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return AppColors.info.withAlpha(20);
            }
            return isDark ? AppColors.darkBackground : null;
          }),
          dividerThickness: 0.5,
          columns: [
            DataColumn(label: Text(l.date,
                style: const TextStyle(
                    color: AppColors.white, fontWeight: FontWeight.w600))),
            DataColumn(label: Text(l.description,
                style: const TextStyle(
                    color: AppColors.white, fontWeight: FontWeight.w600))),
            DataColumn(label: Text(l.value,
                style: const TextStyle(
                    color: AppColors.white, fontWeight: FontWeight.w600))),
            DataColumn(label: Text(l.invoice,
                style: const TextStyle(
                    color: AppColors.white, fontWeight: FontWeight.w600))),
          ],
          rows: txns.map((t) => DataRow(cells: [
                DataCell(Text(fmt.format(t.date),
                    style: TextStyle(
                        fontSize: 13,
                        color: isDark ? AppColors.darkSubtext : AppColors.grey600))),
                DataCell(ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 200),
                  child: Text(
                    t.description.isNotEmpty ? t.description : t.entity,
                    style: TextStyle(
                        fontSize: 13,
                        color: isDark ? AppColors.darkText : AppColors.dark),
                    overflow: TextOverflow.ellipsis,
                  ),
                )),
                DataCell(Text(
                  '${t.isCredit ? '+' : '-'}${cur.format(t.amount)}',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: t.isCredit ? AppColors.success : AppColors.danger,
                  ),
                )),
                DataCell(Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      t.receiptPaths.isEmpty
                          ? Icons.receipt_outlined
                          : Icons.receipt_rounded,
                      color: t.receiptPaths.isEmpty
                          ? (isDark ? AppColors.darkSubtext : AppColors.grey400)
                          : AppColors.info,
                      size: 18,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      t.receiptPaths.isEmpty
                          ? l.none
                          : '${t.receiptPaths.length}',
                      style: TextStyle(
                          fontSize: 12,
                          color: isDark
                              ? AppColors.darkSubtext
                              : AppColors.grey500),
                    ),
                  ],
                )),
              ])).toList(),
        ),
      ),
    );
  }
}

// ── Helper row widget for reserve summary ─────────────────────────────────────
class _SummaryRow extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final bool isDark;
  const _SummaryRow(
      {required this.label,
      required this.value,
      required this.color,
      required this.isDark});

  @override
  Widget build(BuildContext context) => Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: TextStyle(
                fontSize: 13,
                color: isDark ? AppColors.darkSubtext : AppColors.grey500,
              )),
          Text(value,
              style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: color)),
        ],
      );
}