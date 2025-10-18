import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/section.dart';
import '../models/transaction.dart';
import '../models/reserved_amount.dart';
import '../services/database_service.dart';
import '../widgets/transaction_list_tile.dart';
import '../widgets/reserved_amount_tile.dart';
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

  @override
  void initState() {
    super.initState();
    _financialData = _loadFinancialData();
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



  Future<void> _showInvoiceOptions(Transaction invoice) async {
    return showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: AppColors.white,
          title: Text('${invoice.entity}'),
          content: Text('O que deseja fazer com esta fatura?'),
          actions: <Widget>[
            TextButton(
              child: Text('Cancelar'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: Text('Excluir'),
              onPressed: () async {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: Text('Confirmar Exclusão'),
                    content: Text('Tem certeza que deseja excluir esta fatura?'),
                    actions: [
                      TextButton(
                        child: Text('Cancelar'),
                        onPressed: () => Navigator.of(context).pop(false),
                      ),
                      TextButton(
                        child: Text('Excluir'),
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
                      SnackBar(content: Text('Fatura excluída com sucesso!')),
                    );
                  }
                }
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: Text('Editar'),
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
          ],
        );
      },
    );
  }

  Future<void> _showTransactionActions(Transaction transaction) async {
    return showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: AppColors.white,
          title: Text('Ações da Transação'),
          content: Text('O que deseja fazer?'),
          actions: <Widget>[
            TextButton(
              child: Text('Editar'),
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
              child: Text('Excluir'),
              onPressed: () async {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: Text('Confirmar Exclusão'),
                    content: Text('Tem certeza que deseja excluir esta transação?'),
                    actions: [
                      TextButton(
                        child: Text('Cancelar'),
                        onPressed: () => Navigator.of(context).pop(false),
                      ),
                      TextButton(
                        child: Text('Excluir'),
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
                      SnackBar(content: Text('Transação excluída com sucesso!')),
                    );
                  }
                }
                Navigator.of(context).pop();
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

  Future<void> _showReservedAmountActions(ReservedAmount reservedAmount) async {
    return showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: AppColors.white,
          title: Text('Ações da Reserva'),
          content: Text('O que deseja fazer?'),
          actions: <Widget>[
            TextButton(
              child: Text('Editar'),
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
              child: Text('Excluir'),
              onPressed: () async {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: Text('Confirmar Exclusão'),
                    content: Text('Tem certeza que deseja excluir esta reserva?'),
                    actions: [
                      TextButton(
                        child: Text('Cancelar'),
                        onPressed: () => Navigator.of(context).pop(false),
                      ),
                      TextButton(
                        child: Text('Excluir'),
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
                      SnackBar(content: Text('Reserva excluída com sucesso!')),
                    );
                  }
                }
                Navigator.of(context).pop();
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
      body: Container(
        color: AppColors.white,
        child: Column(
          children: [
            // Seção de Faturas Pendentes
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
                        child: Text('Nenhuma fatura registada'),
                      ),
                    );
                  }

                  final invoices = snapshot.data!;
                  return ListView.builder(
                    scrollDirection: Axis.horizontal,
                    padding: EdgeInsets.symmetric(horizontal: 12),
                    itemCount: invoices.length,
                    itemBuilder: (context, index) {
                      final invoice = invoices[index];
                      return GestureDetector(
                        onTap: () => _showInvoiceOptions(invoice),
                        child: Container(
                          width: 140,
                          margin: EdgeInsets.symmetric(horizontal: 4),
                          decoration: BoxDecoration(
                            color: AppColors.grey.shade100,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Padding(
                            padding: EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Row(
                                  children: [
                                    Icon(Icons.warning, color: AppColors.red, size: 14),
                                    SizedBox(width: 4),
                                    Expanded(
                                      child: Text(
                                        invoice.entity.isNotEmpty ? invoice.entity : 'Entidade Desconhecida',
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
                                      : "Sem referência",
                                  style: TextStyle(
                                    color: AppColors.grey,
                                    fontSize: 10,
                                  ),
                                ),
                                SizedBox(height: 4),
                                Text(
                                  invoice.dueDate != null
                                      ? invoice.dueDate!.difference(DateTime.now()).inDays < 0
                                      ? "Vencida há ${invoice.dueDate!.difference(DateTime.now()).inDays.abs()} dias"
                                      : "Vence em ${invoice.dueDate!.difference(DateTime.now()).inDays} dias"
                                      : "Prazo não definido",
                                  style: TextStyle(
                                    color: invoice.dueDate != null && invoice.dueDate!.difference(DateTime.now()).inDays < 0
                                        ? AppColors.red
                                        : AppColors.green,
                                    fontSize: 10,
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

            // Painel de Informações Financeiras
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
                    return Text('Erro ao carregar dados', style: TextStyle(color: AppColors.white));
                  }
                  final data = snapshot.data!;

                  final balance = (data['balance'] as num).toDouble();
                  final totalReserved = (data['totalReserved'] as num).toDouble();
                  final dailyLimit = (data['dailyLimit'] as num).toDouble();
                  final remainingDays = data['remainingDays'] as int;
                  final availableAmount = balance - totalReserved;

                  return Column(
                    children: [
                      // Saldo Atual
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Saldo Atual:',
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

                      // Total Reservado
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Total Reservado:',
                            style: TextStyle(fontSize: 14, color: AppColors.grey),
                          ),
                          Text(
                            '${NumberFormat.currency(locale: 'pt_PT', symbol: '€').format(totalReserved)}',
                            style: TextStyle(fontSize: 14, color: AppColors.grey),
                          ),
                        ],
                      ),
                      SizedBox(height: 8),

                      // Valor Disponível
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Valor Disponível:',
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

                      // Limite Diário
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Limite Diário:',
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
                      Text(
                        '($remainingDays dias restantes no mês)',
                        style: TextStyle(fontSize: 12, color: AppColors.grey),
                      ),
                    ],
                  );
                },
              ),
            ),

            // Resto do código permanece igual...
            Container(
              height: 100,
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Reservas de Montante',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        IconButton(
                          icon: Icon(Icons.add, size: 20),
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
                  ),
                  Expanded(
                    child: FutureBuilder<List<ReservedAmount>>(
                      future: dbService.getReservedAmounts(widget.section.id),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.waiting) {
                          return Center(child: CircularProgressIndicator());
                        }
                        if (!snapshot.hasData || snapshot.data!.isEmpty) {
                          return Center(
                            child: Padding(
                              padding: EdgeInsets.all(16),
                              child: Text('Nenhuma reserva registada'),
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
                              child: ReservedAmountTile(
                                reservedAmount: reservedAmount,
                                onDelete: () => _showReservedAmountActions(reservedAmount),
                              ),
                            );
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),

            Expanded(
              child: FutureBuilder<Map<String, dynamic>>(
                future: _financialData,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return Center(child: CircularProgressIndicator());
                  }
                  if (!snapshot.hasData) {
                    return Center(child: Text('Erro ao carregar transações.'));
                  }
                  final data = snapshot.data!;
                  final transactions = data['transactions'] as List<Transaction>;
                  if (transactions.isEmpty) {
                    return Center(child: Text('Nenhuma transação registrada.'));
                  }
                  transactions.sort((a, b) => b.date.compareTo(a.date));
                  return ListView.builder(
                    itemCount: transactions.length,
                    itemBuilder: (context, index) {
                      final transaction = transactions[index];
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
            ),
          ],
        ),
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
}