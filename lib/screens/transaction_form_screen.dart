import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../l10n/app_localizations.dart';
import '../models/transaction.dart';
import '../services/database_service.dart';
import '../services/file_service.dart';
import '../theme/colors.dart';
import '../theme/app_tokens.dart';
import './image_viewer_screen.dart';
import './scan_file_screen.dart';
class TransactionFormScreen extends StatefulWidget {
  final Transaction? transaction;
  final String sectionId;

  const TransactionFormScreen({super.key, this.transaction, required this.sectionId});

  @override
  State<TransactionFormScreen> createState() => _TransactionFormScreenState();
}

class _TransactionFormScreenState extends State<TransactionFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _entityController = TextEditingController();
  final _amountController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _dateController = TextEditingController();
  final _dueDateController = TextEditingController();
  final _monthRefController = TextEditingController();
  bool _isCreditToggle = false;
  List<String> _receiptPaths = [];
  DateTime _selectedDate = DateTime.now();
  DateTime _selectedDueDate = DateTime.now();
  String? _selectedDocType;
  bool? _paidToggle;
  final DatabaseService _dbService = DatabaseService();
  final FileService _fileService = FileService();
  bool _showDueDate = false;
  bool _showMonthRef = false;
  String? _idInvoiceRef;
  String? _numSerie;
  String? _paymentMethod;

  @override
  void initState() {
    super.initState();
    if (widget.transaction != null) {
      _entityController.text = widget.transaction!.entity;
      _amountController.text = widget.transaction!.amount.toString();
      _descriptionController.text = widget.transaction!.description;
      _isCreditToggle = widget.transaction!.isCredit;
      _receiptPaths = List.from(widget.transaction!.receiptPaths);
      _selectedDate = widget.transaction!.date;
      _dateController.text = DateFormat('dd/MM/yyyy').format(_selectedDate);

      _selectedDocType = widget.transaction!.docType;
      _monthRefController.text = widget.transaction!.monthRef ?? '';
      _selectedDueDate = widget.transaction!.dueDate ?? DateTime.now();
      _dueDateController.text = widget.transaction!.dueDate != null
          ? DateFormat('dd/MM/yyyy').format(_selectedDueDate)
          : '';
      _paidToggle = widget.transaction!.paid;
      _showDueDate = _selectedDocType == '2';
      _showMonthRef = _selectedDocType == '2' || _selectedDocType == '3';
    } else {
      _dateController.text = DateFormat('dd/MM/yyyy').format(_selectedDate);
    }
  }

  @override
  void dispose() {
    _entityController.dispose();
    _amountController.dispose();
    _descriptionController.dispose();
    _dateController.dispose();
    _dueDateController.dispose();
    _monthRefController.dispose();
    super.dispose();
  }

  Future<String?> _showInvoiceSelectionDialog(String idsRef) async {
    final List<String> ids =
        idsRef.split(',').where((id) => id.isNotEmpty).toList();
    if (ids.isEmpty) return null;

    // Capture context values BEFORE the await loop
    final l      = AppLocalizations.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    List<Transaction> invoices = [];
    for (final id in ids) {
      final invoice = await _dbService.getTransactionById(id);
      if (invoice != null) {
        invoices.add(invoice);
      }
    }

    if (invoices.isEmpty) return null;
    if (!mounted) return null;

    return showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.4,
        maxChildSize: 0.9,
        expand: false,
        builder: (_, scrollCtrl) => Container(
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkCard : AppColors.white,
            borderRadius: const BorderRadius.vertical(
                top: Radius.circular(AppTokens.radius24)),
          ),
          child: Column(
            children: [
              // Handle + title
              Padding(
                padding: const EdgeInsets.fromLTRB(
                    AppTokens.sp20, AppTokens.sp12, AppTokens.sp20, AppTokens.sp4),
                child: Column(children: [
                  Container(
                    width: 36, height: 4,
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.darkBorder : AppColors.grey200,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: AppTokens.sp12),
                  Row(children: [
                    Expanded(
                      child: Text(l.selectInvoiceForPayment,
                          style: TextStyle(
                              fontSize: 17, fontWeight: FontWeight.w700,
                              color: isDark ? AppColors.darkText : AppColors.dark)),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ]),
                ]),
              ),
              const Divider(height: 1),
              // Invoice list
              Expanded(
                child: ListView.separated(
                  controller: scrollCtrl,
                  padding: const EdgeInsets.symmetric(
                      vertical: AppTokens.sp8, horizontal: AppTokens.sp12),
                  itemCount: invoices.length,
                  separatorBuilder: (_, __) =>
                      const SizedBox(height: AppTokens.sp4),
                  itemBuilder: (context, index) {
                    final invoice   = invoices[index];
                    final isOverdue = invoice.dueDate != null &&
                        invoice.dueDate!.isBefore(DateTime.now());
                    final urgencyColor =
                        isOverdue ? AppColors.danger : AppColors.warning;

                    return Card(
                      elevation: 0,
                      color: isDark
                          ? AppColors.darkSurface
                          : AppColors.grey100,
                      shape: RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.circular(AppTokens.radius12)),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: AppTokens.sp16,
                            vertical: AppTokens.sp4),
                        leading: Container(
                          width: 40, height: 40,
                          decoration: BoxDecoration(
                            color: AppColors.info.withAlpha(20),
                            borderRadius:
                                BorderRadius.circular(AppTokens.radius8),
                          ),
                          child: Icon(Icons.receipt_outlined,
                              color: isOverdue
                                  ? AppColors.danger
                                  : AppColors.info,
                              size: 20),
                        ),
                        title: Row(children: [
                          Expanded(
                            child: Text(
                              invoice.entity.isNotEmpty
                                  ? invoice.entity
                                  : l.noEntity,
                              style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                  color: isDark
                                      ? AppColors.darkText
                                      : AppColors.dark),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Text('€${invoice.amount.toStringAsFixed(2)}',
                              style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                  color: AppColors.success)),
                        ]),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (invoice.monthRef != null)
                              Row(children: [
                                Icon(Icons.calendar_today_rounded,
                                    size: 11,
                                    color: isDark
                                        ? AppColors.darkSubtext
                                        : AppColors.grey400),
                                const SizedBox(width: 4),
                                Text('Ref: ${invoice.monthRef}',
                                    style: TextStyle(
                                        fontSize: 11,
                                        color: isDark
                                            ? AppColors.darkSubtext
                                            : AppColors.grey400)),
                              ]),
                            if (invoice.dueDate != null)
                              Row(children: [
                                Icon(
                                    isOverdue
                                        ? Icons.warning_rounded
                                        : Icons.schedule_rounded,
                                    size: 11, color: urgencyColor),
                                const SizedBox(width: 4),
                                Text(
                                  '${isOverdue ? l.overdue : l.due} ${DateFormat('dd/MM').format(invoice.dueDate!)}',
                                  style: TextStyle(
                                      fontSize: 11,
                                      color: urgencyColor,
                                      fontWeight: FontWeight.w500),
                                ),
                              ]),
                          ],
                        ),
                        onTap: () {
                          Navigator.pop(context, invoice.id);
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                            content: Text(
                                '${l.invoiceMarkedAsPaid} "${invoice.entity}" ${l.invoiceMarkedAsPaid2}'),
                            backgroundColor: AppColors.success,
                          ));
                        },
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _scanDocument() async {
    final result = await Navigator.push(
      context,
      slideRoute(ScanFileScreen(sectionId: widget.sectionId)),
    );

    if (result != null && result is Map<String, dynamic>) {
      final imagePaths = result['imagePaths'] as List<String>? ?? [];
      final aiResult = result['aiAnalysis'] as Map<String, dynamic>?;

      if (imagePaths.isNotEmpty) {
        setState(() {
          _receiptPaths.addAll(imagePaths);
        });
      }

      if (aiResult != null) {
        int? tipo = aiResult['tipo_documento'] as int? ?? 4;
        final entidade = aiResult['entidade'] as String? ?? '';
        final descricao = aiResult['descrição'] as String? ?? '';
        final dataEmissao = aiResult['data_emissao'] as String? ?? '';
        final valorTotal = aiResult['valor_total'] as String? ?? '';
        final dataLimite = aiResult['data_limite'] as String? ?? '';
        final mesAnoRef = aiResult['mes_ano_ref'] as String? ?? '';
        final eCredito = aiResult['é_crédito'] as String? ?? '0';
        final idsInvoiceRef = aiResult['ids_ref_fatura'] as String? ?? '';
        final numeroSerie = aiResult['numero_serie'] as String? ?? '';
        final metodoPagamento = aiResult['metodo_pagamento'] as String? ?? '';

        String? idInvoiceRef;
        if (tipo == 3) {
          if (idsInvoiceRef.isNotEmpty) {
            // AI identified specific invoice IDs — use them directly.
            idInvoiceRef = await _showInvoiceSelectionDialog(idsInvoiceRef);
          } else if (entidade.isNotEmpty) {
            // Fallback: search by entity name (+ amount similarity scoring).
            final amount = double.tryParse(valorTotal);
            final matches = await _dbService.findMatchingInvoices(
              sectionId: widget.sectionId,
              entityName: entidade,
              amount: amount,
            );
            if (matches.isNotEmpty && mounted) {
              // Reuse the same selection dialog with the matched IDs.
              final matchedIds = matches.map((i) => i.id).join(',');
              idInvoiceRef = await _showInvoiceSelectionDialog(matchedIds);
            }
          }
        }

        setState(() {
          _idInvoiceRef = idInvoiceRef;
          _isCreditToggle = eCredito == '1';
          _selectedDocType = tipo.toString();
          _entityController.text = entidade;
          _descriptionController.text = descricao;
          _numSerie = numeroSerie;
          _paymentMethod = metodoPagamento;

          if (valorTotal != 'UNKNOWN') {
            _amountController.text = valorTotal;
          }
          if (dataEmissao != 'UNKNOWN') {
            try {
              final parts = dataEmissao.split(' ');
              _selectedDate = DateTime(
                int.parse(parts[2]),
                int.parse(parts[1]),
                int.parse(parts[0]),
              );
              _dateController.text = DateFormat('dd/MM/yyyy').format(_selectedDate);
            } catch (_) {
              // Silently ignore malformed date string from AI analysis
            }
          }
          _showDueDate = (tipo == 2);
          _showMonthRef = (tipo == 2 || tipo == 3);

          if (dataLimite != 'UNKNOWN' && _showDueDate) {
            try {
              final parts = dataLimite.split(' ');
              _selectedDueDate = DateTime(
                int.parse(parts[2]),
                int.parse(parts[1]),
                int.parse(parts[0]),
              );
              _dueDateController.text = DateFormat('dd/MM/yyyy').format(_selectedDueDate);
            } catch (_) {
              // Silently ignore malformed due-date string from AI analysis
            }
          }
          if (mesAnoRef != 'UNKNOWN' && _showMonthRef) {
            _monthRefController.text = mesAnoRef;
          }
          _paidToggle = (tipo == 2) ? false : null;
        });


      }
    }
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
        _dateController.text = DateFormat('dd/MM/yyyy').format(_selectedDate);
      });
    }
  }

  Future<void> _selectMonthRef(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      initialDatePickerMode: DatePickerMode.year,
    );
    if (picked != null) {
      setState(() {
        _monthRefController.text = DateFormat('MM/yyyy').format(picked);
      });
    }
  }

  Future<void> _selectDueDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDueDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null && picked != _selectedDueDate) {
      setState(() {
        _selectedDueDate = picked;
        _dueDateController.text = DateFormat('dd/MM/yyyy').format(_selectedDueDate);
      });
    }
  }

  Future<void> _downloadImage(String path) async {
    final msg = AppLocalizations.of(context).imageDownloadedSuccessfully;
    await _fileService.downloadImage(path);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg)),
    );
  }

  Future<void> _viewImage(String path) async {
    Navigator.push(
      context,
      slideRoute(ImageViewerScreen(imagePath: path)),
    );
  }

  void _saveTransaction(String? idInvoiceRef, DateTime date) async {
    if (_formKey.currentState!.validate()) {
      if (_selectedDocType == '3' &&
          idInvoiceRef != null &&
          idInvoiceRef != 'UNKNOWN') {
        _mergeWithInvoice(idInvoiceRef, date);
        return;
      }

      final bool isPaid =
          _selectedDocType == '2' ? (_paidToggle ?? false) : false;

      // Capture context-dependent value BEFORE the await
      final errorMsg = AppLocalizations.of(context).errorSavingTransaction;

      final transaction = Transaction(
        id: widget.transaction?.id ?? const Uuid().v4(),
        amount: double.parse(_amountController.text),
        entity: _entityController.text,
        description: _descriptionController.text,
        isCredit: _isCreditToggle,
        date: _selectedDate,
        receiptPaths: _receiptPaths,
        sectionId: widget.sectionId,
        docType: _selectedDocType,
        monthRef: _monthRefController.text.isNotEmpty
            ? _monthRefController.text
            : null,
        dueDate: _showDueDate ? _selectedDueDate : null,
        paid: isPaid,
        numeroSerie: _numSerie,
        metodoPagamento: _paymentMethod,
      );

      try {
        if (widget.transaction == null) {
          await _dbService.addTransaction(transaction);
        } else {
          await _dbService.updateTransaction(transaction);
        }

        if (!mounted) return;
        // Pop with structured result so SectionScreen can offer auto-reserve
        // for new, unpaid invoices (docType '2').
        final isNewInvoice = widget.transaction == null &&
            _selectedDocType == '2' &&
            !isPaid;
        Navigator.pop(
          context,
          isNewInvoice
              ? {
                  'type':   'invoice',
                  'id':     transaction.id,
                  'amount': transaction.amount,
                  'entity': transaction.entity,
                }
              : true,
        );
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$errorMsg $e')),
        );
      }
    }
  }

  Future<void> _mergeWithInvoice(String idInvoiceRef, DateTime date) async {
    // Capture context-dependent values BEFORE any await
    final paidMsg  = AppLocalizations.of(context).invoiceMarkedPaidWithProof;
    final mergeErr = AppLocalizations.of(context).mergeError;

    try {
      final invoice = await _dbService.getTransactionById(idInvoiceRef);
      if (invoice != null) {
        final mergedPaths = [..._receiptPaths, ...invoice.receiptPaths];

        final updatedInvoice = Transaction(
          id:           invoice.id,
          amount:       invoice.amount,
          entity:       invoice.entity,
          description:  invoice.description,
          isCredit:     invoice.isCredit,
          date:         date,
          receiptPaths: mergedPaths,
          sectionId:    invoice.sectionId,
          docType:      invoice.docType,
          monthRef:     invoice.monthRef,
          dueDate:      invoice.dueDate,
          paid:         true,
        );

        await _dbService.updateTransaction(updatedInvoice);

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(paidMsg)),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$mergeErr $e')),
      );
    }
    if (!mounted) return;
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final l = AppLocalizations.of(context);
    return Scaffold(
      backgroundColor:
          isDark ? AppColors.darkBackground : const Color(0xFFF5F5F7),
      appBar: AppBar(
        backgroundColor:
            isDark ? AppColors.darkSurface : AppColors.white,
        foregroundColor: isDark ? AppColors.darkText : AppColors.dark,
        elevation: 0,
        title: Text(
          widget.transaction == null ? l.newTransaction : l.editTransaction,
          style: const TextStyle(fontWeight: FontWeight.w700, letterSpacing: -0.3),
        ),
      ),
      body: Padding(
        padding: EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              children: [

                Container(
                  padding: const EdgeInsets.all(AppTokens.sp12),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.darkCard : AppColors.white,
                    borderRadius: BorderRadius.circular(AppTokens.radius16),
                    border: Border.all(
                        color: isDark
                            ? AppColors.darkBorder
                            : AppColors.grey100),
                    boxShadow: isDark ? null : AppTokens.shadowSm,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: SizedBox(
                          height: 100,
                          child: _buildDocTypeButton(
                            icon: Icons.qr_code_rounded,
                            label: l.receipt,
                            docType: '1',
                            isDark: isDark,
                          ),
                        ),
                      ),
                      const SizedBox(width: AppTokens.sp8),
                      Expanded(
                        child: SizedBox(
                          height: 100,
                          child: _buildDocTypeButton(
                            icon: Icons.insert_chart_rounded,
                            label: l.chargeNote,
                            docType: '2',
                            isDark: isDark,
                          ),
                        ),
                      ),
                      const SizedBox(width: AppTokens.sp8),
                      Expanded(
                        child: SizedBox(
                          height: 100,
                          child: _buildDocTypeButton(
                            icon: Icons.paid_rounded,
                            label: l.proof,
                            docType: '3',
                            isDark: isDark,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: AppTokens.sp16),

                Container(
                  padding: const EdgeInsets.all(AppTokens.sp20),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.darkCard : AppColors.white,
                    borderRadius: BorderRadius.circular(AppTokens.radius16),
                    border: Border.all(
                        color: isDark
                            ? AppColors.darkBorder
                            : AppColors.grey100),
                    boxShadow: isDark ? null : AppTokens.shadowSm,
                  ),
                  child: Column(
                    children: [
                      TextFormField(
                        controller: _entityController,
                        decoration: InputDecoration(
                          labelText: AppLocalizations.of(context).entity,
                          hintText: AppLocalizations.of(context).personOrCompanyName,
                        ),
                      ),
                      SizedBox(height: 16),
                      TextFormField(
                        controller: _amountController,
                        decoration: InputDecoration(
                          labelText: AppLocalizations.of(context).valueEuro,
                        ),
                        keyboardType: TextInputType.numberWithOptions(decimal: true),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return AppLocalizations.of(context).informValue;
                          }
                          if (double.tryParse(value) == null || double.parse(value) <= 0) {
                            return AppLocalizations.of(context).informValidValue;
                          }
                          return null;
                        },
                      ),
                      SizedBox(height: 16),
                      TextFormField(
                        controller: _descriptionController,
                        decoration: InputDecoration(
                          labelText: AppLocalizations.of(context).description,
                          hintText: AppLocalizations.of(context).transactionDescription,
                        ),
                        maxLines: 2,
                      ),
                      SizedBox(height: 16),
                      TextFormField(
                        controller: _dateController,
                        decoration: InputDecoration(
                          labelText: AppLocalizations.of(context).date,
                          suffixIcon: const Icon(Icons.calendar_today),
                        ),
                        readOnly: true,
                        onTap: () => _selectDate(context),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return AppLocalizations.of(context).informDate;
                          }
                          return null;
                        },
                      ),


                      if (_showMonthRef) ...[
                        SizedBox(height: 16),
                        TextFormField(
                          controller: _monthRefController,
                          decoration: InputDecoration(
                            labelText: AppLocalizations.of(context).monthYearReference,
                            suffixIcon: const Icon(Icons.calendar_today),
                          ),
                          readOnly: true,
                          onTap: () => _selectMonthRef(context),
                        ),
                      ],

                      if (_showDueDate) ...[
                        SizedBox(height: 16),
                        TextFormField(
                          controller: _dueDateController,
                          decoration: InputDecoration(
                            labelText: AppLocalizations.of(context).deadline,
                            suffixIcon: const Icon(Icons.calendar_today),
                          ),
                          readOnly: true,
                          onTap: () => _selectDueDate(context),
                        ),
                      ],


                      if (_showDueDate) ...[
                        const SizedBox(height: AppTokens.sp16),
                        Container(
                          decoration: BoxDecoration(
                            border: Border.all(
                                color: isDark
                                    ? AppColors.darkBorder
                                    : AppColors.grey200),
                            borderRadius:
                                BorderRadius.circular(AppTokens.radius12),
                          ),
                          child: SwitchListTile(
                            title: Text(l.paid,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w600)),
                            value: _paidToggle ?? false,
                            activeThumbColor: AppColors.success,
                            onChanged: (v) =>
                                setState(() => _paidToggle = v),
                          ),
                        ),
                      ],

                      if (_selectedDocType == '3') ...[
                        const SizedBox(height: AppTokens.sp16),
                        Container(
                          decoration: BoxDecoration(
                            border: Border.all(
                                color: isDark
                                    ? AppColors.darkBorder
                                    : AppColors.grey200),
                            borderRadius:
                                BorderRadius.circular(AppTokens.radius12),
                          ),
                          child: SwitchListTile(
                            title: Text(l.isCredit,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w600)),
                            subtitle: Text(_isCreditToggle ? l.yes : l.no),
                            value: _isCreditToggle,
                            activeThumbColor: AppColors.success,
                            onChanged: (v) =>
                                setState(() => _isCreditToggle = v),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),

                const SizedBox(height: AppTokens.sp16),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _scanDocument,
                    icon: const Icon(Icons.document_scanner_rounded),
                    label: Text(l.scanDocument),
                    style: OutlinedButton.styleFrom(
                      // Explicit foregroundColor prevents the icon and label
                      // from inheriting black in dark mode.
                      foregroundColor:
                          isDark ? AppColors.darkText : AppColors.dark,
                      padding: const EdgeInsets.symmetric(
                          vertical: AppTokens.sp14),
                      side: BorderSide(
                          color: isDark
                              ? AppColors.darkBorder
                              : AppColors.grey300),
                    ),
                  ),
                ),
                const SizedBox(height: AppTokens.sp16),

                // Attachments
                Container(
                  padding: const EdgeInsets.all(AppTokens.sp16),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.darkCard : AppColors.white,
                    borderRadius: BorderRadius.circular(AppTokens.radius16),
                    border: Border.all(
                        color: isDark
                            ? AppColors.darkBorder
                            : AppColors.grey100),
                    boxShadow: isDark ? null : AppTokens.shadowSm,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        Icon(Icons.attach_file_rounded,
                            size: 18,
                            color: isDark
                                ? AppColors.darkSubtext
                                : AppColors.grey500),
                        const SizedBox(width: AppTokens.sp8),
                        Text(l.attachments,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: isDark
                                  ? AppColors.darkText
                                  : AppColors.dark,
                            )),
                        if (_receiptPaths.isNotEmpty) ...[
                          const SizedBox(width: AppTokens.sp8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.info.withAlpha(isDark ? 40 : 20),
                              borderRadius: BorderRadius.circular(
                                  AppTokens.radiusFull),
                            ),
                            child: Text('${_receiptPaths.length}',
                                style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.info)),
                          ),
                        ],
                      ]),
                      const SizedBox(height: AppTokens.sp12),
                      _receiptPaths.isEmpty
                          ? Container(
                              alignment: Alignment.center,
                              height: 80,
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.file_present_outlined,
                                      size: 36,
                                      color: isDark
                                          ? AppColors.darkSubtext
                                          : AppColors.grey300),
                                  const SizedBox(height: AppTokens.sp6),
                                  Text(l.noAttachmentsAdded,
                                      style: TextStyle(
                                          color: isDark
                                              ? AppColors.darkSubtext
                                              : AppColors.grey400,
                                          fontSize: 13)),
                                ],
                              ),
                            )
                          : Wrap(
                              spacing: AppTokens.sp10,
                              runSpacing: AppTokens.sp10,
                              children: _receiptPaths.map((path) {
                                return Stack(
                                  children: [
                                    GestureDetector(
                                      onTap: () => _viewImage(path),
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(
                                            AppTokens.radius12),
                                        child: Image.file(
                                          File(path),
                                          width: 90,
                                          height: 90,
                                          fit: BoxFit.cover,
                                        ),
                                      ),
                                    ),
                                    Positioned(
                                      top: 4,
                                      right: 4,
                                      child: GestureDetector(
                                        onTap: () => setState(
                                            () => _receiptPaths.remove(path)),
                                        child: Container(
                                          padding: const EdgeInsets.all(4),
                                          decoration: const BoxDecoration(
                                            color: Colors.black54,
                                            shape: BoxShape.circle,
                                          ),
                                          child: const Icon(
                                              Icons.close_rounded,
                                              size: 14,
                                              color: Colors.white),
                                        ),
                                      ),
                                    ),
                                    Positioned(
                                      bottom: 4,
                                      left: 4,
                                      child: GestureDetector(
                                        onTap: () => _downloadImage(path),
                                        child: Container(
                                          padding: const EdgeInsets.all(4),
                                          decoration: const BoxDecoration(
                                            color: Colors.black54,
                                            shape: BoxShape.circle,
                                          ),
                                          child: const Icon(
                                              Icons.download_rounded,
                                              size: 14,
                                              color: Colors.white),
                                        ),
                                      ),
                                    ),
                                  ],
                                );
                              }).toList(),
                            ),
                    ],
                  ),
                ),

                const SizedBox(height: AppTokens.sp24),

                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () =>
                        _saveTransaction(_idInvoiceRef, _selectedDate),
                    style: FilledButton.styleFrom(
                      backgroundColor:
                          isDark ? AppColors.info : AppColors.dark,
                      padding: const EdgeInsets.symmetric(
                          vertical: AppTokens.sp16),
                      shape: RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.circular(AppTokens.radius12)),
                    ),
                    child: Text(l.saveTransaction,
                        style: const TextStyle(fontSize: 16)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDocTypeButton({
    required IconData icon,
    required String label,
    required String docType,
    required bool isDark,
  }) {
    final isSelected = _selectedDocType == docType;
    final selectedBg = isDark ? AppColors.info : AppColors.dark;
    final unselectedBorder =
        isDark ? AppColors.darkBorder : AppColors.grey200;
    final unselectedIcon =
        isDark ? AppColors.darkSubtext : AppColors.grey500;
    final unselectedText =
        isDark ? AppColors.darkText : AppColors.dark;

    return GestureDetector(
        onTap: () {
          setState(() {
            _selectedDocType = docType;
            _showDueDate   = (docType == '2');
            _showMonthRef  = (docType == '2' || docType == '3');
            _paidToggle    = (docType == '2') ? false : null;
          });
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.symmetric(horizontal: AppTokens.sp4),
          padding: const EdgeInsets.all(AppTokens.sp12),
          decoration: BoxDecoration(
            color: isSelected ? selectedBg : Colors.transparent,
            border: Border.all(
              color: isSelected ? selectedBg : unselectedBorder,
              width: isSelected ? 2 : 1.5,
            ),
            borderRadius: BorderRadius.circular(AppTokens.radius12),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 28,
                color: isSelected ? AppColors.white : unselectedIcon,
              ),
              const SizedBox(height: AppTokens.sp8),
              Text(
                label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w600,
                  color: isSelected ? AppColors.white : unselectedText,
                ),
              ),
              const SizedBox(height: AppTokens.sp4),
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                height: 3,
                width: isSelected ? 20 : 0,
                decoration: BoxDecoration(
                  color: AppColors.white,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ],
          ),
        ),
      );
  }
}