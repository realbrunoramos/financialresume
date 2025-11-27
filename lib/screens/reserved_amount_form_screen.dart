import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';
import '../models/reserved_amount.dart';
import '../services/database_service.dart';
import '../theme/colors.dart';

class ReservedAmountFormScreen extends StatefulWidget {
  final String sectionId;
  final ReservedAmount? reservedAmount;
  final double? availableBalance;


  const ReservedAmountFormScreen({
    super.key,
    required this.sectionId,
    this.availableBalance,
    this.reservedAmount,
  });

  @override
  State<ReservedAmountFormScreen> createState() => _ReservedAmountFormScreenState();
}

class _ReservedAmountFormScreenState extends State<ReservedAmountFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _descriptionController = TextEditingController();
  final _amountController = TextEditingController();
  final DatabaseService dbService = DatabaseService();


  Future<void> _showWarning() async {
    try {
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
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  TextButton(
                    child: Text(AppLocalizations.of(context).cancel),
                    onPressed: () {
                      Navigator.of(context).pop();
                    },
                  ),
                  TextButton(
                    child: Text(AppLocalizations.of(context).reserve),
                    onPressed: () async {
                      Navigator.of(context).pop();
                    },
                  ),
                ],
              ),
            ],
          );
        },
      );
    } catch (e) {
    }
  }

  Future<void> _saveReservedAmount() async {
    final reverseAmount = double.parse(_amountController.text);
    final amount = widget.availableBalance;
    print('HEREEEEE $amount');
    if (amount != null) {
      if(reverseAmount > amount){
        _showWarning();
      }
    }
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
  void initState() {
    super.initState();
    if (widget.reservedAmount != null) {
      _descriptionController.text = widget.reservedAmount!.description;
      _amountController.text = widget.reservedAmount!.amount.toString();
    }
  }
  @override
  void dispose() {
    _descriptionController.dispose();
    _amountController.dispose();
    super.dispose();
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.reservedAmount == null ? AppLocalizations.of(context).newReserve : AppLocalizations.of(context).editarReserva),
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
                  labelText: AppLocalizations.of(context).description,
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return AppLocalizations.of(context).enterDescription;
                  }
                  return null;
                },
              ),
              SizedBox(height: 16),
              TextFormField(
                controller: _amountController,
                decoration: InputDecoration(
                  labelText: AppLocalizations.of(context).amountToReserve,
                ),
                keyboardType: TextInputType.numberWithOptions(decimal: true),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return AppLocalizations.of(context).enterAmount;
                  }
                  final amount = double.tryParse(value);
                  if (amount == null || amount <= 0) {
                    return AppLocalizations.of(context).enterValidAmount;
                  }
                  return null;
                },
              ),
              SizedBox(height: 32),
              ElevatedButton(
                onPressed: _saveReservedAmount,
                child: Text(AppLocalizations.of(context).saveReserve),
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
}