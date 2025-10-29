import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../l10n/app_localizations.dart';
import '../models/section.dart';
import '../models/transaction.dart';
import '../models/reserved_amount.dart';
import '../providers/transaction_provider.dart';
import '../services/database_service.dart';
import '../widgets/transaction_list_tile.dart';
import 'transaction_form_screen.dart';
import 'summary_screen.dart';
import 'transaction_detail_screen.dart';
import 'reserved_amount_form_screen.dart';
import '../theme/colors.dart';

class SectionScreen extends StatefulWidget {
  final Section section;

  const SectionScreen({super.key, required this.section});

  @override
  State<SectionScreen> createState() => _SectionScreenState();
}

class _SectionScreenState extends State<SectionScreen> {
  final DatabaseService dbService = DatabaseService();
  late Future<Map<String, dynamic>> _financialData;
  bool _isReservedAmountsExpanded = false;
  final _searchController = TextEditingController();
  List<Transaction> _filteredTransactions = [];
  List<Transaction> _allTransactions = [];
  final FocusNode _searchFocusNode = FocusNode();
  bool _isSearchActive = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<TransactionProvider>().loadTransactions(widget.section.id);
    });
    _financialData = _loadFinancialData();
    _searchController.addListener(_filterTransactions);
    _searchFocusNode.addListener(_handleSearchFocusChange);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.white,
        title: Text(widget.section.name),
        actions: [
          IconButton(
            icon: Icon(Icons.summarize, color: AppColors.dark),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => SummaryScreen(sectionId: widget.section.id),
                ),
              );
            },
          ),
        ],
      ),
      body: Consumer<TransactionProvider>(
          builder: (context, transactionProvider, child) {
            if (transactionProvider.isLoading) {
              return Center(child: CircularProgressIndicator());
            }
            //final transactions = transactionProvider.transactions;

            return GestureDetector(
              onTap: () => FocusScope.of(context).unfocus(),
              child: Container(
                color: AppColors.white,
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      if (!_isSearchActive) ...[
                        Container(
                          padding: EdgeInsets.all(16),
                          color: AppColors.dark,
                          child: FutureBuilder<Map<String, dynamic>>(
                            future: _financialData,
                            builder: (context, snapshot) {
                              if (snapshot.connectionState == ConnectionState.waiting) {
                                return Center(child: CircularProgressIndicator(color: AppColors.white));
                              }

                              if (!snapshot.hasData) {
                                return Text(AppLocalizations.of(context).errorLoadingData, style: TextStyle(color: AppColors.white));
                              }

                              final data = snapshot.data!;

                              final balance = (data['balance'] as num).toDouble();
                              final totalReserved = (data['totalReserved'] as num).toDouble();
                              final dailyLimit = (data['dailyLimit'] as num).toDouble();
                              final remainingDays = data['remainingDays'] as int;

                              final availableAmount = balance - totalReserved;

                              return Column(
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        AppLocalizations.of(context).currentBalance,
                                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.white),
                                      ),
                                      Text(
                                        '${NumberFormat.currency(locale: 'pt_PT', symbol: '€').format(balance)}',
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                          color: balance >= 0 ? AppColors.green : AppColors.red,
                                        ),
                                      ),
                                    ],
                                  ),
                                  SizedBox(height: 8),

                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        AppLocalizations.of(context).availableAmount,
                                        style: TextStyle(fontSize: 14, color: AppColors.grey),
                                      ),
                                      Text(
                                        '${NumberFormat.currency(locale: 'pt_PT', symbol: '€').format(availableAmount)}',
                                        style: TextStyle(
                                          fontSize: 14,
                                          color: availableAmount >= 0 ? AppColors.green : AppColors.red,
                                        ),
                                      ),
                                    ],
                                  ),
                                  SizedBox(height: 8),

                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        AppLocalizations.of(context).totalReserved,
                                        style: TextStyle(fontSize: 14, color: AppColors.grey),
                                      ),
                                      Text(
                                        '${NumberFormat.currency(locale: 'pt_PT', symbol: '€').format(totalReserved)}',
                                        style: TextStyle(fontSize: 14, color: AppColors.grey),
                                      ),
                                    ],
                                  ),
                                  SizedBox(height: 8),

                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        AppLocalizations.of(context).dailyLimit,
                                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.white),
                                      ),
                                      Text(
                                        '${NumberFormat.currency(locale: 'pt_PT', symbol: '€').format(dailyLimit)}',
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                          color: dailyLimit > 0 ? AppColors.blue : AppColors.red,
                                        ),
                                      ),
                                    ],
                                  ),
                                  SizedBox(height: 4),

                                  Text('($remainingDays ${AppLocalizations.of(context).daysRemainingInMonth})', style: TextStyle(fontSize: 12, color: AppColors.grey),
                                  ),
                                ],
                              );
                            },
                          ),
                        ),
                        SizedBox(height: 8),
                      ],
                      Container(
                        height: 60,
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: TextField(
                          controller: _searchController,
                          focusNode: _searchFocusNode,
                          decoration: InputDecoration(
                            hintText: AppLocalizations.of(context).searchTransactions,
                            prefixIcon: Icon(Icons.search, color: AppColors.dark),
                            suffixIcon: _searchController.text.isNotEmpty
                                ? IconButton(
                              icon: Icon(Icons.clear, color: AppColors.dark),
                              onPressed: () {
                                _searchController.clear();
                                _filterTransactions();
                              },
                            )
                                : null,
                            filled: true,
                            fillColor: AppColors.grey.shade100,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                            contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 3),
                          ),
                          style: TextStyle(color: AppColors.dark),
                          onChanged: (_) => _filterTransactions(),
                        ),
                      ),

                      if (!_isSearchActive) ...[
                        Container(
                          height: 120,
                          padding: EdgeInsets.symmetric(vertical: 6),
                          child: FutureBuilder<List<Transaction>>(
                            future: dbService.getNoPaidInvoices(widget.section.id),
                            builder: (context, snapshot) {
                              if (snapshot.connectionState == ConnectionState.waiting) {
                                return Center(child: CircularProgressIndicator());
                              }

                              if (snapshot.hasError) {
                                return Center(
                                  child: Text('Erro: ${snapshot.error}'),
                                );
                              }

                              if (!snapshot.hasData || snapshot.data!.isEmpty) {
                                return Center(
                                  child: Padding(
                                    padding: EdgeInsets.all(16),
                                    child: Text(AppLocalizations.of(context).noInvoiceRegistered),
                                  ),
                                );
                              }

                              final invoices = _sortInvoicesByDueDate(snapshot.data!);
                              return ListView.builder(
                                scrollDirection: Axis.horizontal,
                                padding: EdgeInsets.symmetric(horizontal: 12),
                                itemCount: invoices.length,
                                itemBuilder: (context, index) {
                                  final invoice = invoices[index];
                                  return GestureDetector(
                                    onTap: () => _showInvoiceDetails(invoice),
                                    onLongPress: () => _showInvoiceOptions(invoice),
                                    child: Container(
                                      width: 140,
                                      margin: EdgeInsets.symmetric(horizontal: 4),
                                      decoration: BoxDecoration(
                                        color: _getInvoiceColor(invoice),
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                          color: _getInvoiceBorderColor(invoice),
                                          width: 2,
                                        ),
                                      ),
                                      child: Padding(
                                        padding: EdgeInsets.all(12),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Row(
                                              children: [
                                                Icon(
                                                  _getInvoiceIcon(invoice),
                                                  color: _getInvoiceIconColor(invoice),
                                                  size: 14,
                                                ),
                                                SizedBox(width: 4),
                                                Expanded(
                                                  child: Text(
                                                    invoice.entity.isNotEmpty ? invoice.entity : AppLocalizations.of(context).unknownEntity,
                                                    style: TextStyle(
                                                      fontWeight: FontWeight.bold,
                                                      fontSize: 14,
                                                    ),
                                                    maxLines: 1,
                                                    overflow: TextOverflow.ellipsis,
                                                  ),
                                                ),
                                              ],
                                            ),
                                            SizedBox(height: 4),
                                            Text(
                                              '${NumberFormat.currency(locale: 'pt_PT', symbol: '€').format(invoice.amount)}',
                                              style: TextStyle(
                                                color: AppColors.blue,
                                                fontSize: 16,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                            SizedBox(height: 4),
                                            Text(
                                              invoice.monthRef != null
                                                  ? "Ref: ${DateFormat('MM/yyyy').format(DateFormat('MM/yyyy').parse(invoice.monthRef!))}"
                                                  : AppLocalizations.of(context).noReference,
                                              style: TextStyle(
                                                color: AppColors.grey,
                                                fontSize: 10,
                                              ),
                                            ),
                                            SizedBox(height: 4),
                                            Text(
                                              invoice.dueDate != null
                                                  ? _getDueDateStatus(invoice.dueDate!)
                                                  : AppLocalizations.of(context).deadlineNotDefined,
                                              style: TextStyle(
                                                color: _getDueDateTextColor(invoice.dueDate),
                                                fontSize: 10,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              );
                            },
                          ),
                        ),

                        Container(
                          decoration: BoxDecoration(
                            color: AppColors.white,
                            border: Border(
                              bottom: BorderSide(color: AppColors.grey.shade300, width: 1),
                            ),
                          ),
                          child: Column(
                            children: [
                              ListTile(
                                contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                                leading: Icon(
                                  Icons.savings,
                                  color: AppColors.dark,
                                  size: 24,
                                ),
                                title: Text(
                                  AppLocalizations.of(context).amountReservations,
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.dark,
                                  ),
                                ),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    FutureBuilder<List<ReservedAmount>>(
                                      future: dbService.getReservedAmounts(widget.section.id),
                                      builder: (context, snapshot) {
                                        final count = snapshot.data?.length ?? 0;
                                        return Container(
                                          padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: AppColors.blue.withAlpha(25),
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                          child: Text(
                                            '$count',
                                            style: TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.bold,
                                              color: AppColors.blue,
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                                    SizedBox(width: 8),
                                    IconButton(
                                      icon: Icon(
                                        _isReservedAmountsExpanded
                                            ? Icons.expand_less
                                            : Icons.expand_more,
                                        color: AppColors.dark,
                                        size: 20,
                                      ),
                                      onPressed: () {
                                        setState(() {
                                          _isReservedAmountsExpanded = !_isReservedAmountsExpanded;
                                        });
                                      },
                                    ),
                                    IconButton(
                                      icon: Icon(
                                        Icons.add_circle_outline,
                                        color: AppColors.green,
                                        size: 20,
                                      ),
                                      onPressed: () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (context) => ReservedAmountFormScreen(sectionId: widget.section.id),
                                          ),
                                        ).then((_) => _refreshData());
                                      },
                                    ),
                                  ],
                                ),
                                onTap: () {
                                  setState(() {
                                    _isReservedAmountsExpanded = !_isReservedAmountsExpanded;
                                  });
                                },
                              ),

                              AnimatedContainer(
                                duration: Duration(milliseconds: 300),
                                height: _isReservedAmountsExpanded ? 120 : 0,
                                child: FutureBuilder<List<ReservedAmount>>(
                                  future: dbService.getReservedAmounts(widget.section.id),
                                  builder: (context, snapshot) {
                                    if (snapshot.connectionState == ConnectionState.waiting) {
                                      return Center(child: CircularProgressIndicator());
                                    }
                                    if (!snapshot.hasData || snapshot.data!.isEmpty) {
                                      return Center(
                                        child: SingleChildScrollView(
                                          child: Padding(
                                            padding: EdgeInsets.all(16),
                                            child: Column(
                                              mainAxisAlignment: MainAxisAlignment.center,
                                              children: [
                                                Icon(
                                                  Icons.savings_outlined,
                                                  size: 40,
                                                  color: AppColors.grey.shade400,
                                                ),
                                                SizedBox(height: 8),
                                                Text(
                                                  AppLocalizations.of(context).noReservationRegistered,
                                                  style: TextStyle(
                                                    color: AppColors.grey.shade600,
                                                    fontSize: 14,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      );
                                    }
                                    final reservedAmounts = snapshot.data!;
                                    return ListView.builder(
                                      scrollDirection: Axis.horizontal,
                                      padding: EdgeInsets.symmetric(horizontal: 12),
                                      itemCount: reservedAmounts.length,
                                      itemBuilder: (context, index) {
                                        final reservedAmount = reservedAmounts[index];
                                        return GestureDetector(
                                          onTap: () => _showReservedAmountActions(reservedAmount),
                                          child: _buildEnhancedReservedAmountCard(reservedAmount),
                                        );
                                      },
                                    );
                                  },
                                ),
                              )

                            ],
                          ),
                        ),
                      ],

                      FutureBuilder<Map<String, dynamic>>(
                        future: _financialData,
                        builder: (context, snapshot) {
                          if (snapshot.connectionState == ConnectionState.waiting) {
                            return Center(child: CircularProgressIndicator());
                          }
                          if (!snapshot.hasData) {
                            return Center(child: Text(AppLocalizations.of(context).errorLoadingTransactions));
                          }
                          final data = snapshot.data!;
                          final transactions = data['transactions'] as List<Transaction>;
                          if (transactions.isEmpty) {
                            return Center(child: Text(AppLocalizations.of(context).noTransactionRegistered));
                          }
                          return ListView.builder(
                            shrinkWrap: true,
                            physics: NeverScrollableScrollPhysics(),
                            itemCount: _filteredTransactions.length,
                            itemBuilder: (context, index) {
                              final transaction = _filteredTransactions[index];
                              return Container(
                                child: TransactionListTile(
                                  transaction: transaction,
                                  onLongPress: () => _showTransactionActions(transaction),
                                  onTap: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => TransactionDetailScreen(
                                          transaction: transaction,
                                          sectionId: widget.section.id,
                                        ),
                                      ),
                                    ).then((_) => _refreshData());
                                  },
                                  onDelete: () => _refreshData(),
                                ),
                              );
                            },
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
            );
          }
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppColors.dark,
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => TransactionFormScreen(sectionId: widget.section.id),
            ),
          ).then((_) => _refreshData());
        },
        child: Icon(Icons.add, color: AppColors.white),
      ),
    );
  }

  void _handleSearchFocusChange() {

    setState(() {
      _isSearchActive = _searchFocusNode.hasFocus;
    });
  }

  void _filterTransactions() {
    final query = _searchController.text.toLowerCase().trim();

    if (query.isEmpty) {
      setState(() {
        _filteredTransactions = _allTransactions;
      });
      return;
    }

    setState(() {
      _filteredTransactions = _allTransactions.where((transaction) {
        return transaction.entity.toLowerCase().contains(query) ||
            transaction.description.toLowerCase().contains(query) ||
            transaction.amount.toString().contains(query) ||
            (transaction.monthRef?.toLowerCase().contains(query) ?? false) ||
            (transaction.numeroSerie?.toLowerCase().contains(query) ?? false) ||
            (transaction.metodoPagamento?.toLowerCase().contains(query) ?? false) ||
            DateFormat('dd/MM/yyyy').format(transaction.date).contains(query);
      }).toList();
    });
  }

  Future<Map<String, dynamic>> _loadFinancialData() async {
    final transactions = await dbService.getAllTransactions(widget.section.id);
    final balance = transactions.fold<double>(0,(sum, t) => sum + (t.isCredit ? t.amount : -t.amount));
    final reservedAmounts = await dbService.getReservedAmounts(widget.section.id);
    final totalReserved = reservedAmounts.fold<double>(
      0.0, (sum, r) => sum + (r.amount is int ? (r.amount as int).toDouble() : r.amount),
    );

    final now = DateTime.now();
    final lastDayOfMonth = DateTime(now.year, now.month + 1, 0);
    final remainingDays = lastDayOfMonth.difference(now).inDays + 1;

    final availableAmount = balance - totalReserved;
    final dailyLimit = availableAmount > 0 && remainingDays > 0
        ? availableAmount / remainingDays
        : 0;

    if (mounted) {
      setState(() {
        _allTransactions = transactions;
        _filterTransactions();
      });
    }

    return {
      'balance': balance,
      'totalReserved': totalReserved,
      'dailyLimit': dailyLimit,
      'remainingDays': remainingDays,
      'transactions': transactions,
      'reservedAmounts': reservedAmounts,
    };
  }

  void _refreshData() {
    setState(() {
      _financialData = _loadFinancialData();
    });
  }

  List<Transaction> _sortInvoicesByDueDate(List<Transaction> invoices) {
    final now = DateTime.now();

    return invoices..sort((a, b) {
      if (a.dueDate != null && b.dueDate != null) {
        final daysA = a.dueDate!.difference(now).inDays;
        final daysB = b.dueDate!.difference(now).inDays;

        if (daysA < 0 && daysB < 0) {
          return daysA.compareTo(daysB);
        }
        if (daysA < 0) return -1;
        if (daysB < 0) return 1;
        return daysA.compareTo(daysB);
      }

      if (a.dueDate != null) return -1;
      if (b.dueDate != null) return 1;

      return b.date.compareTo(a.date);
    });
  }

  void _showInvoiceDetails(Transaction invoice) {
    final List<Map<String, dynamic>> details = [];

    if (invoice.numeroSerie != null && invoice.numeroSerie!.isNotEmpty && invoice.numeroSerie != 'UNKNOWN') {
      details.add({'label': AppLocalizations.of(context).invoiceNumber, 'value': invoice.numeroSerie!});
    }

    details.add({
      'label': AppLocalizations.of(context).value,
      'value': '${NumberFormat.currency(locale: 'pt_PT', symbol: '€').format(invoice.amount)}'
    });

    details.add({
      'label': AppLocalizations.of(context).emissionDate,
      'value': DateFormat('dd/MM/yyyy').format(invoice.date)
    });

    if (invoice.dueDate != null) {
      details.add({
        'label': AppLocalizations.of(context).limitDate,
        'value': '${DateFormat('dd/MM/yyyy').format(invoice.dueDate!)} (${_getDueDateStatus(invoice.dueDate!)})'
      });
    }

    if (invoice.monthRef != null && invoice.monthRef!.isNotEmpty) {
      details.add({'label': AppLocalizations.of(context).reference.replaceFirst(':', ''), 'value': invoice.monthRef!});
    }

    if (invoice.metodoPagamento != null && invoice.metodoPagamento!.isNotEmpty && invoice.metodoPagamento != 'UNKNOWN') {
      details.add({
        'label': AppLocalizations.of(context).payment,
        'value': invoice.metodoPagamento!.split("/").length == 2
            ? "${AppLocalizations.of(context).entity}: ${invoice.metodoPagamento!.split("/")[0]}\n${AppLocalizations.of(context).reference} ${invoice.metodoPagamento!.split("/")[1]}"
            : "IBAN: ${invoice.metodoPagamento!}"
      });
    }

    if (invoice.description.isNotEmpty) {
      details.add({'label': AppLocalizations.of(context).description, 'value': invoice.description});
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.white,
        title: Text(
          invoice.entity.isNotEmpty ? invoice.entity : AppLocalizations.of(context).invoice,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              for (int i = 0; i < details.length; i++)
                _buildDetailRow(
                    details[i]['label'],
                    details[i]['value'],
                    i.isEven ? Colors.grey[300]! : Colors.grey[50]!
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(AppLocalizations.of(context).close, style: TextStyle(color: AppColors.dark)),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, Color color) {
    return Container(
      width: double.infinity,
      color: color,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: AppColors.dark,
                fontSize: 14,
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              value,
              style: TextStyle(
                color: AppColors.grey.shade700,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _getDueDateStatus(DateTime dueDate) {
    final now = DateTime.now();
    final normalizedDueDate = DateTime(dueDate.year, dueDate.month, dueDate.day);
    final normalizedNow = DateTime(now.year, now.month, now.day);

    final difference = normalizedDueDate.difference(normalizedNow).inDays;

    if (difference < 0) {
      return '${AppLocalizations.of(context).overdueByDays} ${difference.abs()} ${AppLocalizations.of(context).overdueByDays2}';
    } else if (difference == 0) {
      return AppLocalizations.of(context).dueToday;
    } else if (difference == 1) {
      return AppLocalizations.of(context).dueTomorrow;
    } else {
      return '${AppLocalizations.of(context).dueInDays} $difference ${AppLocalizations.of(context).dueInDays2}';
    }
  }

  Future<void> _showInvoiceOptions(Transaction invoice) async {
    return showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: AppColors.white,
          title: Text(
            AppLocalizations.of(context).invoiceActions,
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          content: Text(AppLocalizations.of(context).whatToDoWithThisInvoice),
          actions: [
            Expanded(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  TextButton(
                    child: Text(AppLocalizations.of(context).edit),
                    onPressed: () {
                      Navigator.of(context).pop();
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => TransactionFormScreen(
                            transaction: invoice,
                            sectionId: widget.section.id,
                          ),
                        ),
                      ).then((_) => _refreshData());
                    },
                  ),

                  SizedBox(width: 2),

                  TextButton(
                    child: Text(AppLocalizations.of(context).delete),
                    onPressed: () async {
                      Navigator.of(context).pop();
                      await _confirmDeleteInvoice(invoice);
                    },
                  ),
                  SizedBox(width: 2),

                  TextButton(
                    child: Text(AppLocalizations.of(context).reserve),
                    onPressed: () async {
                      Navigator.of(context).pop();
                      await _reserveInvoiceAmount(invoice);
                    },
                  ),

                ],
              ),
            ),
          ],

        );
      },
    );
  }

  Future<void> _confirmDeleteInvoice(Transaction invoice) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(AppLocalizations.of(context).confirmDeletion),
        content: Text(AppLocalizations.of(context).confirmDeleteInvoice),
        actions: [
          TextButton(
            child: Text(AppLocalizations.of(context).cancel),
            onPressed: () => Navigator.of(context).pop(false),
          ),
          TextButton(
            child: Text('Excluir', style: TextStyle(color: AppColors.red)),
            onPressed: () => Navigator.of(context).pop(true),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await dbService.deleteTransaction(invoice.id);
      _refreshData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context).invoiceDeletedSuccessfully),
            backgroundColor: AppColors.green,
          ),
        );
      }
    }
  }

  Future<void> _reserveInvoiceAmount(Transaction invoice) async {
    final description = "${invoice.entity} | ${invoice.monthRef}";
    final existAlready = await dbService.existReserve(description);
    if (existAlready) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context).reservationAlreadyExistsForInvoice, style: TextStyle(color: AppColors.black)),
          backgroundColor: AppColors.white,
        ),
      );
      return;
    } else{
      final reservedAmount = ReservedAmount(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        sectionId: widget.section.id,
        description: description,
        amount: invoice.amount,
        createdAt: DateTime.now(),
      );
      await dbService.insertReservedAmount(reservedAmount);
      setState(() {
        _refreshData();
      });
    }
  }

  Future<void> _showTransactionActions(Transaction transaction) async {
    return showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: AppColors.white,
          title: Text(AppLocalizations.of(context).transactionActions),
          content: Text(AppLocalizations.of(context).whatToDo),
          actions: <Widget>[
            TextButton(
              child: Text(AppLocalizations.of(context).edit),
              onPressed: () {
                Navigator.of(context).pop();
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => TransactionFormScreen(
                      transaction: transaction,
                      sectionId: widget.section.id,
                    ),
                  ),
                ).then((_) => _refreshData());
              },
            ),
            TextButton(
              child: Text(AppLocalizations.of(context).delete),
              onPressed: () async {
                Navigator.of(context).pop();
                await _confirmDeleteTransaction(transaction);
              },
            ),
            TextButton(
              child: Text('Cancelar'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> _confirmDeleteTransaction(Transaction transaction) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Confirmar Exclusão'),
        content: Text(AppLocalizations.of(context).confirmDeleteTransaction),
        actions: [
          TextButton(
            child: Text('Cancelar'),
            onPressed: () => Navigator.of(context).pop(false),
          ),
          TextButton(
            child: Text('Excluir', style: TextStyle(color: AppColors.red)),
            onPressed: () => Navigator.of(context).pop(true),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await dbService.deleteTransaction(transaction.id);
      _refreshData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context).transactionDeletedSuccessfully),
            backgroundColor: AppColors.green,
          ),
        );
      }
    }
  }

  Future<void> _showReservedAmountActions(ReservedAmount reservedAmount) async {
    return showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: AppColors.white,
          title: Text(AppLocalizations.of(context).reservationActions),
          content: Text(AppLocalizations.of(context).whatToDo),
          actions: <Widget>[
            TextButton(
              child: Text(AppLocalizations.of(context).edit),
              onPressed: () {
                Navigator.of(context).pop();
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ReservedAmountFormScreen(
                      reservedAmount: reservedAmount,
                      sectionId: widget.section.id,
                    ),
                  ),
                ).then((_) => _refreshData());
              },
            ),
            TextButton(
              child: Text(AppLocalizations.of(context).delete),
              onPressed: () async {
                Navigator.of(context).pop();
                await _confirmDeleteReservedAmount(reservedAmount);
              },
            ),
            TextButton(
              child: Text(AppLocalizations.of(context).cancel),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> _confirmDeleteReservedAmount(ReservedAmount reservedAmount) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Confirmar Exclusão'),
        content: Text(AppLocalizations.of(context).confirmDeleteReservation),
        actions: [
          TextButton(
            child: Text('Cancelar'),
            onPressed: () => Navigator.of(context).pop(false),
          ),
          TextButton(
            child: Text('Excluir', style: TextStyle(color: AppColors.red)),
            onPressed: () => Navigator.of(context).pop(true),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await dbService.deleteReservedAmount(reservedAmount.id);
      _refreshData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context).reservationDeletedSuccessfully),
            backgroundColor: AppColors.green,
          ),
        );
      }
    }
  }


  Widget _buildEnhancedReservedAmountCard(ReservedAmount reservedAmount) {
    return Container(
      width: 160,
      margin: EdgeInsets.symmetric(horizontal: 6, vertical: 8),
      child: Card(
        elevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
            color: AppColors.grey.shade300,
            width: 1,
          ),
        ),
        child: SingleChildScrollView(
          child: Padding(
            padding: EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: AppColors.blue.withAlpha(25),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.savings,
                        size: 16,
                        color: AppColors.blue,
                      ),
                    ),
                    Text(
                      '${NumberFormat.currency(locale: 'pt_PT', symbol: '€').format(reservedAmount.amount)}',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: AppColors.dark,
                      ),
                    ),
                  ],
                ),

                SizedBox(height: 8),

                Text(
                  reservedAmount.description,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: AppColors.dark,
                  ),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),

                SizedBox(height: 5),

                Row(
                  children: [
                    Icon(
                      Icons.calendar_today,
                      size: 10,
                      color: AppColors.grey.shade600,
                    ),
                    SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        DateFormat('dd/MM/yy').format(reservedAmount.createdAt),
                        style: TextStyle(
                          fontSize: 10,
                          color: AppColors.grey.shade600,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),

                Container(
                  margin: EdgeInsets.only(top: 4),
                  height: 2,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [AppColors.blue, AppColors.green],
                    ),
                    borderRadius: BorderRadius.circular(1),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Color _getInvoiceColor(Transaction invoice) {
    if (invoice.dueDate == null) return AppColors.grey.shade100;

    final daysUntilDue = invoice.dueDate!.difference(DateTime.now()).inDays;

    if (daysUntilDue < 0) {
      return Color(0xFFFFE6E6);
    } else if (daysUntilDue <= 3) {
      return Color(0xFFFFF4E6);
    } else {
      return AppColors.grey.shade100;
    }
  }

  Color _getInvoiceBorderColor(Transaction invoice) {
    if (invoice.dueDate == null) return AppColors.grey.shade300;

    final daysUntilDue = invoice.dueDate!.difference(DateTime.now()).inDays;

    if (daysUntilDue < 0) {
      return AppColors.red;
    } else if (daysUntilDue <= 3) {
      return Colors.orange;
    } else {
      return AppColors.green;
    }
  }

  IconData _getInvoiceIcon(Transaction invoice) {
    if (invoice.dueDate == null) return Icons.receipt;

    final daysUntilDue = invoice.dueDate!.difference(DateTime.now()).inDays;

    if (daysUntilDue < 0) {
      return Icons.warning;
    } else if (daysUntilDue <= 3) {
      return Icons.schedule;
    } else {
      return Icons.receipt;
    }
  }

  Color _getInvoiceIconColor(Transaction invoice) {
    if (invoice.dueDate == null) return AppColors.grey;

    final daysUntilDue = invoice.dueDate!.difference(DateTime.now()).inDays;

    if (daysUntilDue < 0) {
      return AppColors.red;
    } else if (daysUntilDue <= 3) {
      return Colors.orange;
    } else {
      return AppColors.green;
    }
  }

  Color _getDueDateTextColor(DateTime? dueDate) {
    if (dueDate == null) return AppColors.grey;

    final daysUntilDue = dueDate.difference(DateTime.now()).inDays;

    if (daysUntilDue < 0) {
      return AppColors.red;
    } else if (daysUntilDue <= 3) {
      return Colors.orange;
    } else {
      return AppColors.green;
    }
  }
}