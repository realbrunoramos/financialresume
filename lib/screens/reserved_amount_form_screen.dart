import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';
import '../models/reserved_amount.dart';
import '../services/database_service.dart';
import '../theme/colors.dart';

class ReservedAmountFormScreen extends StatefulWidget {
  final ReservedAmount? reservedAmount;
  final String sectionId;

  const ReservedAmountFormScreen({
    super.key,
    this.reservedAmount,
    required this.sectionId,
  });

  @override
  State<ReservedAmountFormScreen> createState() => _ReservedAmountFormScreenState();
}

class _ReservedAmountFormScreenState extends State<ReservedAmountFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _descriptionController = TextEditingController();
  final _amountController = TextEditingController();
  final DatabaseService dbService = DatabaseService();

  @override
  void initState() {
    super.initState();
    if (widget.reservedAmount != null) {
      _descriptionController.text = widget.reservedAmount!.description;
      _amountController.text = widget.reservedAmount!.amount.toString();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.reservedAmount == null ? AppLocalizations.of(context).novaReserva : AppLocalizations.of(context).editarReserva),
        backgroundColor: AppColors.white,
      ),
      body: Padding(
        padding: EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(
                controller: _descriptionController,
                decoration: InputDecoration(
                  labelText: AppLocalizations.of(context).descricao,
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return AppLocalizations.of(context).insiraDescricao;
                  }
                  return null;
                },
              ),
              SizedBox(height: 16),
              TextFormField(
                controller: _amountController,
                decoration: InputDecoration(
                  labelText: AppLocalizations.of(context).valorAReservar,
                ),
                keyboardType: TextInputType.numberWithOptions(decimal: true),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return AppLocalizations.of(context).insiraValor;
                  }
                  final amount = double.tryParse(value);
                  if (amount == null || amount <= 0) {
                    return AppLocalizations.of(context).insiraValorValido;
                  }
                  return null;
                },
              ),
              SizedBox(height: 32),
              ElevatedButton(
                onPressed: _saveReservedAmount,
                child: Text(AppLocalizations.of(context).guardarReserva),
                style: ElevatedButton.styleFrom(
                  minimumSize: Size(double.infinity, 50),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _saveReservedAmount() async {
    if (_formKey.currentState!.validate()) {
      final reservedAmount = ReservedAmount(
        id: widget.reservedAmount?.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
        sectionId: widget.sectionId,
        description: _descriptionController.text,
        amount: double.parse(_amountController.text),
        createdAt: widget.reservedAmount?.createdAt ?? DateTime.now(),
      );

      if (widget.reservedAmount == null) {
        await dbService.insertReservedAmount(reservedAmount);
      } else {
        await dbService.updateReservedAmount(reservedAmount);
      }

      if (mounted) {
        Navigator.pop(context);
      }
    }
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    _amountController.dispose();
    super.dispose();
  }
}