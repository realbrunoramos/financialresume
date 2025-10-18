// widgets/reserved_amount_tile.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/reserved_amount.dart';

class ReservedAmountTile extends StatelessWidget {
  final ReservedAmount reservedAmount;
  final VoidCallback onDelete;

  const ReservedAmountTile({
    super.key,
    required this.reservedAmount,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 160,
      margin: EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        color: Color.fromARGB(210, 230, 240, 255),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue.shade100),
      ),
      child: Padding(
        padding: const EdgeInsets.all(8), // Reduzido de 12 para 8
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center, // Alterado para center
            children: [
              Text(
                  reservedAmount.description,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 12, // Reduzido de 14 para 12
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              const SizedBox(height: 4), // Adicionado espaçamento
              Text(
                NumberFormat.currency(locale: 'pt_PT', symbol: '€')
                    .format(reservedAmount.amount),
                style: TextStyle(
                  color: Colors.blue[800],
                  fontSize: 14, // Reduzido de 16 para 14
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 2), // Adicionado espaçamento
              Text(
                'Criado em ${DateFormat('dd/MM/yyyy').format(reservedAmount.createdAt)}',
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 9, // Reduzido de 10 para 9
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}