import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';
import '../models/reserved_amount.dart';
import '../services/database_service.dart';
import '../theme/colors.dart';
import '../theme/app_tokens.dart';

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
  State<ReservedAmountFormScreen> createState() =>
      _ReservedAmountFormScreenState();
}

class _ReservedAmountFormScreenState extends State<ReservedAmountFormScreen> {
  final _formKey             = GlobalKey<FormState>();
  final _descriptionController = TextEditingController();
  final _amountController    = TextEditingController();
  final DatabaseService _db  = DatabaseService();

  @override
  void initState() {
    super.initState();
    if (widget.reservedAmount != null) {
      _descriptionController.text = widget.reservedAmount!.description;
      _amountController.text      = widget.reservedAmount!.amount.toString();
    }
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  // ── Warning bottom sheet ───────────────────────────────────────────────────
  Future<void> _showWarning() async {
    final l      = AppLocalizations.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => SafeArea(
        child: Container(
          margin: const EdgeInsets.all(AppTokens.sp12),
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkCard : AppColors.white,
            borderRadius: BorderRadius.circular(AppTokens.radius24),
          ),
          padding: const EdgeInsets.all(AppTokens.sp20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Handle
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.darkBorder : AppColors.grey200,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: AppTokens.sp16),

              // Icon + title
              Row(children: [
                Container(
                  padding: const EdgeInsets.all(AppTokens.sp8),
                  decoration: BoxDecoration(
                    color: AppColors.warning.withAlpha(30),
                    borderRadius: BorderRadius.circular(AppTokens.radius8),
                  ),
                  child: const Icon(Icons.warning_amber_rounded,
                      color: AppColors.warning, size: 20),
                ),
                const SizedBox(width: AppTokens.sp12),
                Expanded(
                  child: Text(
                    l.invoiceActions,
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: isDark ? AppColors.darkText : AppColors.dark,
                    ),
                  ),
                ),
              ]),
              const SizedBox(height: AppTokens.sp12),
              Text(
                l.whatToDoWithThisInvoice,
                style: TextStyle(
                  fontSize: 14,
                  color: isDark ? AppColors.darkSubtext : AppColors.grey500,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: AppTokens.sp20),
              Row(children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text(l.cancel),
                  ),
                ),
                const SizedBox(width: AppTokens.sp12),
                Expanded(
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                        backgroundColor: AppColors.warning),
                    onPressed: () => Navigator.pop(context),
                    child: Text(l.reserve),
                  ),
                ),
              ]),
            ],
          ),
        ),
      ),
    );
  }

  // ── Save ──────────────────────────────────────────────────────────────────
  Future<void> _saveReservedAmount() async {
    final reverseAmount = double.tryParse(_amountController.text) ?? 0;
    final available     = widget.availableBalance;

    if (available != null && reverseAmount > available) {
      await _showWarning();
    }

    if (_formKey.currentState!.validate()) {
      final reservedAmount = ReservedAmount(
        id:          widget.reservedAmount?.id ??
            DateTime.now().millisecondsSinceEpoch.toString(),
        sectionId:   widget.sectionId,
        description: _descriptionController.text,
        amount:      double.parse(_amountController.text),
        createdAt:   widget.reservedAmount?.createdAt ?? DateTime.now(),
      );

      if (widget.reservedAmount == null) {
        await _db.insertReservedAmount(reservedAmount);
      } else {
        await _db.updateReservedAmount(reservedAmount);
      }

      if (mounted) Navigator.pop(context);
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final l      = AppLocalizations.of(context);
    final isEdit = widget.reservedAmount != null;

    return Scaffold(
      backgroundColor:
          isDark ? AppColors.darkBackground : const Color(0xFFF5F5F7),
      appBar: AppBar(
        backgroundColor:
            isDark ? AppColors.darkSurface : AppColors.white,
        foregroundColor: isDark ? AppColors.darkText : AppColors.dark,
        elevation: 0,
        title: Text(
          isEdit ? l.editarReserva : l.newReserve,
          style: const TextStyle(
              fontWeight: FontWeight.w700, letterSpacing: -0.3),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppTokens.sp16),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Card ──────────────────────────────────────────────────
                Container(
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.darkCard : AppColors.white,
                    borderRadius: BorderRadius.circular(AppTokens.radius16),
                    border: Border.all(
                        color: isDark
                            ? AppColors.darkBorder
                            : AppColors.grey100),
                    boxShadow:
                        isDark ? null : AppTokens.shadowSm,
                  ),
                  padding: const EdgeInsets.all(AppTokens.sp16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Description
                      TextFormField(
                        controller: _descriptionController,
                        style: TextStyle(
                            color: isDark
                                ? AppColors.darkText
                                : AppColors.dark),
                        decoration: InputDecoration(
                          labelText: l.description,
                          prefixIcon: const Icon(
                              Icons.label_outline_rounded),
                        ),
                        validator: (v) => (v == null || v.isEmpty)
                            ? l.enterDescription
                            : null,
                      ),
                      const SizedBox(height: AppTokens.sp16),

                      // Amount
                      TextFormField(
                        controller: _amountController,
                        style: TextStyle(
                            color: isDark
                                ? AppColors.darkText
                                : AppColors.dark),
                        decoration: InputDecoration(
                          labelText: l.amountToReserve,
                          prefixIcon: const Icon(
                              Icons.euro_rounded),
                        ),
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        validator: (v) {
                          if (v == null || v.isEmpty) return l.enterAmount;
                          final amt = double.tryParse(v);
                          if (amt == null || amt <= 0) {
                            return l.enterValidAmount;
                          }
                          return null;
                        },
                      ),

                      // Available balance hint
                      if (widget.availableBalance != null) ...[
                        const SizedBox(height: AppTokens.sp8),
                        Row(children: [
                          const Icon(Icons.info_outline_rounded,
                              size: 13, color: AppColors.grey400),
                          const SizedBox(width: 4),
                          Text(
                            '${l.availableBalance}: €${widget.availableBalance!.toStringAsFixed(2)}',
                            style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.grey400,
                                fontStyle: FontStyle.italic),
                          ),
                        ]),
                      ],
                    ],
                  ),
                ),

                const SizedBox(height: AppTokens.sp28),

                // ── Save button ───────────────────────────────────────────
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _saveReservedAmount,
                    icon: const Icon(Icons.save_rounded),
                    label: Text(l.saveReserve),
                    style: FilledButton.styleFrom(
                      backgroundColor:
                          isDark ? AppColors.info : AppColors.dark,
                      padding: const EdgeInsets.symmetric(
                          vertical: AppTokens.sp16),
                      shape: RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.circular(AppTokens.radius12)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
