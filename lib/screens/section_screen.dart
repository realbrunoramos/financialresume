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

  List<Transaction> _sortInvoicesByDueDate(List<Transaction> invoices) {
    final now = DateTime.now();

    return invoices..sort((a, b) {
      // Se ambas têm data de vencimento
      if (a.dueDate != null && b.dueDate != null) {
        final daysA = a.dueDate!.difference(now).inDays;
        final daysB = b.dueDate!.difference(now).inDays;

        // Faturas vencidas vêm primeiro (valores negativos menores primeiro)
        if (daysA < 0 && daysB < 0) {
          return daysA.compareTo(daysB); // Mais vencida primeiro
        }
        // Faturas vencidas vêm antes das não vencidas
        if (daysA < 0) return -1;
        if (daysB < 0) return 1;
        // Ambas não vencidas - mais próxima primeiro
        return daysA.compareTo(daysB);
      }

      // Se apenas uma tem data de vencimento, ela vem primeiro
      if (a.dueDate != null) return -1;
      if (b.dueDate != null) return 1;

      // Se nenhuma tem data de vencimento, ordena por data de emissão
      return b.date.compareTo(a.date);
    });
  }

  void _showInvoiceDetails(Transaction invoice) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.white,
        title: Text(
          invoice.entity.isNotEmpty ? invoice.entity : 'Fatura',
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
              // Número de Série
              if (invoice.numeroSerie != null && invoice.numeroSerie!.isNotEmpty && invoice.numeroSerie != 'UNKNOWN')
                _buildDetailRow('Número de Fatura:', invoice.numeroSerie!),

              // Valor
              _buildDetailRow(
                'Valor:',
                '${NumberFormat.currency(locale: 'pt_PT', symbol: '€').format(invoice.amount)}',
              ),

              // Data de Emissão
              if (invoice.date != null)
                _buildDetailRow(
                  'Data de Emissão:',
                  DateFormat('dd/MM/yyyy').format(invoice.date),
                ),

              // Data Limite
              if (invoice.dueDate != null)
                _buildDetailRow(
                  'Data Limite:',
                  '${DateFormat('dd/MM/yyyy').format(invoice.dueDate!)} '
                      '(${_getDueDateStatus(invoice.dueDate!)})',
                ),

              // Referência do Mês
              if (invoice.monthRef != null && invoice.monthRef!.isNotEmpty)
                _buildDetailRow('Referência:', invoice.monthRef!),

              if (invoice.metodoPagamento != null && invoice.metodoPagamento!.isNotEmpty && invoice.metodoPagamento != 'UNKNOWN')
                _buildDetailRow('Pagamento:', invoice.metodoPagamento!.split("/").length == 2 ? "Entidade: ${invoice.metodoPagamento!.split("/")[0]}\nReferência: ${invoice.metodoPagamento!.split("/")[1]}"
                    : "IBAN: ${invoice.metodoPagamento!}"),
              // Descrição
              if (invoice.description.isNotEmpty)
                _buildDetailRow('Descrição:', invoice.description),
            ].where((element) => element != null).cast<Widget>().toList(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Fechar', style: TextStyle(color: AppColors.dark)),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4),
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
    final difference = dueDate.difference(now);

    if (difference.inDays < 0) {
      return 'Vencida há ${difference.inDays.abs()} dias';
    } else if (difference.inDays == 0) {
      return 'Vence hoje';
    } else if (difference.inDays == 1) {
      return 'Vence amanhã';
    } else {
      return 'Vence em ${difference.inDays} dias';
    }
  }

  Future<void> _showInvoiceOptions(Transaction invoice) async {
    return showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: AppColors.white,
          title: Text(
            'Ações da Fatura',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          content: Text('O que deseja fazer com esta fatura?'),
          actions: [
            Expanded(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
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
              
                  SizedBox(width: 8),
              
                  TextButton(
                    child: Text('Excluir'),
                    onPressed: () async {
                      Navigator.of(context).pop();
                      await _confirmDeleteInvoice(invoice);
                    },
                  ),
              
                  SizedBox(width: 8),
              
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text('Cancelar', style: TextStyle(color: AppColors.grey)),
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
        title: Text('Confirmar Exclusão'),
        content: Text('Tem certeza que deseja excluir esta fatura?'),
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
      await dbService.deleteTransaction(invoice.id);
      _refreshData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Fatura excluída com sucesso!'),
            backgroundColor: AppColors.green,
          ),
        );
      }
    }
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
        content: Text('Tem certeza que deseja excluir esta transação?'),
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
            content: Text('Transação excluída com sucesso!'),
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
                Navigator.of(context).pop();
                await _confirmDeleteReservedAmount(reservedAmount);
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

  Future<void> _confirmDeleteReservedAmount(ReservedAmount reservedAmount) async {
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
            content: Text('Reserva excluída com sucesso!'),
            backgroundColor: AppColors.green,
          ),
        );
      }
    }
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
                                      ? _getDueDateStatus(invoice.dueDate!)
                                      : "Prazo não definido",
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

  Color _getInvoiceColor(Transaction invoice) {
    if (invoice.dueDate == null) return AppColors.grey.shade100;

    final daysUntilDue = invoice.dueDate!.difference(DateTime.now()).inDays;

    if (daysUntilDue < 0) {
      return Color(0xFFFFE6E6); // Vermelho muito claro para faturas vencidas
    } else if (daysUntilDue <= 3) {
      return Color(0xFFFFF4E6); // Laranja claro para faturas próximas
    } else {
      return AppColors.grey.shade100; // Cinza para faturas com prazo longo
    }
  }

  Color _getInvoiceBorderColor(Transaction invoice) {
    if (invoice.dueDate == null) return AppColors.grey.shade300;

    final daysUntilDue = invoice.dueDate!.difference(DateTime.now()).inDays;

    if (daysUntilDue < 0) {
      return AppColors.red; // Vermelho para faturas vencidas
    } else if (daysUntilDue <= 3) {
      return Colors.orange; // Laranja para faturas próximas
    } else {
      return AppColors.green; // Verde para faturas com prazo longo
    }
  }

  IconData _getInvoiceIcon(Transaction invoice) {
    if (invoice.dueDate == null) return Icons.receipt;

    final daysUntilDue = invoice.dueDate!.difference(DateTime.now()).inDays;

    if (daysUntilDue < 0) {
      return Icons.warning; // Ícone de aviso para vencidas
    } else if (daysUntilDue <= 3) {
      return Icons.schedule; // Ícone de relógio para próximas
    } else {
      return Icons.receipt; // Ícone normal para outras
    }
  }

  Color _getInvoiceIconColor(Transaction invoice) {
    if (invoice.dueDate == null) return AppColors.grey;

    final daysUntilDue = invoice.dueDate!.difference(DateTime.now()).inDays;

    if (daysUntilDue < 0) {
      return AppColors.red; // Vermelho para vencidas
    } else if (daysUntilDue <= 3) {
      return Colors.orange; // Laranja para próximas
    } else {
      return AppColors.green; // Verde para outras
    }
  }

  Color _getDueDateTextColor(DateTime? dueDate) {
    if (dueDate == null) return AppColors.grey;

    final daysUntilDue = dueDate.difference(DateTime.now()).inDays;

    if (daysUntilDue < 0) {
      return AppColors.red; // Vermelho para vencidas
    } else if (daysUntilDue <= 3) {
      return Colors.orange; // Laranja para próximas
    } else {
      return AppColors.green; // Verde para outras
    }
  }
}