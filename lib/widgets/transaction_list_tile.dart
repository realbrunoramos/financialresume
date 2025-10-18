import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/transaction.dart';
import '../services/database_service.dart';
import '/screens/receipt_list_screen.dart';

class TransactionListTile extends StatelessWidget {
  final Transaction transaction;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final VoidCallback? onDelete;

  const TransactionListTile({
    Key? key,
    required this.transaction,
    required this.onTap,
    required this.onLongPress,
    this.onDelete,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final format = DateFormat('dd/MM/yyyy');
    final currency = NumberFormat.currency(locale: 'pt_PT', symbol: '€');

    final isCredit = transaction.isCredit;
    final icon = isCredit ? Icons.arrow_upward : Icons.arrow_downward;
    final iconColor = isCredit ? Colors.green : Colors.red;
    final bgColor = Color.fromARGB(230, 255, 255, 255);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      height: 80,  // Altura fixa e uniforme para todas as tiles
      child: Card(
        elevation: 1,  // Sombra sutil para minimalismo
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        color: bgColor,
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: onTap,
          onLongPress: onLongPress,
          child: Padding(
            padding: const EdgeInsets.all(12),  // Reduzido para caber no height
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Icon
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: iconColor.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    icon,
                    color: iconColor,
                    size: 20,  // Reduzido para caber
                  ),
                ),
                const SizedBox(width: 8),
                // Content
                Expanded(
                  child: Flexible(  // Flexible para evitar overflow
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          transaction.description,
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w500,  // Leve bold para simplicidade
                            fontSize: 14,  // Ajustado para caber
                          ),
                          maxLines: 1,  // Reduzido para 1 linha para evitar overflow
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          format.format(transaction.date),
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 11,  // Pequeno para minimalismo
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                // Trailing Amount
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      '${isCredit ? '+' : '-'} ${currency.format(transaction.amount)}',
                      style: TextStyle(
                        color: iconColor,
                        fontSize: 14,  // Ajustado
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (transaction.receiptPaths.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          '${transaction.receiptPaths.length} anexo(s)',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 10,
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

}