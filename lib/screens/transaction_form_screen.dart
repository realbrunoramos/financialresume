import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mailer/mailer.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../l10n/app_localizations.dart';
import '../models/transaction.dart';
import '../providers/transaction_provider.dart';
import '../services/database_service.dart';
import '../services/file_service.dart';
import '../theme/colors.dart';
import '../theme/app_tokens.dart';
import './image_viewer_screen.dart';
import './scan_file_screen.dart';
import 'package:provider/provider.dart';

class TransactionFormScreen extends StatefulWidget {
  final Transaction? transaction;
  final String sectionId;

  const TransactionFormScreen({super.key, this.transaction, required this.sectionId});

  @override
  State<TransactionFormScreen> createState() => _TransactionFormScreenState();
}

class _TransactionFormScreenState extends State<TransactionFormScreen> {
  final DatabaseService dbService = DatabaseService();
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
  Map<String, dynamic>? _aiAnalysis;
  bool _showDueDate = false;
  bool _showMonthRef = false;
  String? _email;
  String? _password;
  bool get _hasCredentials => _email != null && _password != null && _email!.isNotEmpty && _password!.isNotEmpty;
  String? _idInvoiceRef;
  String? _numSerie;
  String? _paymentMethod;
  String _smtpServer = 'smtp.gmail.com';
  String _port = '587';

  @override
  void initState() {
    super.initState();
    _loadCredentials();
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
    super.dispose();
  }

  Future<void> _loadCredentials() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _email = prefs.getString('email');
        _password = prefs.getString('password');
        final server = prefs.getString('smtp_server') ?? 'smtp.gmail.com';
        final port = prefs.getString('port') ?? '587';
        _smtpServer = server;
        _port = port;
      });
    }
  }

  Future<void> _showCredentialsDialog() async {
    final emailCtrl = TextEditingController(text: _email);
    final passwordCtrl = TextEditingController(text: _password);

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(AppLocalizations.of(context).configureEmailCredentials),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: emailCtrl,
                decoration: InputDecoration(
                  labelText: 'Email',
                  hintText: 'exemplo@gmail.com',
                ),
                keyboardType: TextInputType.emailAddress,
              ),
              SizedBox(height: 16),
              TextField(
                controller: passwordCtrl,
                decoration: InputDecoration(
                  labelText: AppLocalizations.of(context).appPassword,
                  hintText: AppLocalizations.of(context).forGmailUseAppPassword,
                ),
                obscureText: true,
              ),
              SizedBox(height: 16),
              Text(
                AppLocalizations.of(context).forGmailEnableTwoStepVerificationAndGenerateAppPassword,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(AppLocalizations.of(context).cancel),
          ),
          ElevatedButton(
            onPressed: () async {
              final prefs = await SharedPreferences.getInstance();
              await prefs.setString('email', emailCtrl.text);
              await prefs.setString('password', passwordCtrl.text);
              if (mounted) {
                setState(() {
                  _email = emailCtrl.text;
                  _password = passwordCtrl.text;
                });
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(AppLocalizations.of(context).credentialsSavedSuccessfully)),
                );
                _showComposeDialog();
              }
            },
            child: Text(AppLocalizations.of(context).save),
          ),
        ],
      ),
    );
  }

  void _handleEmailSend() {
    if (!_hasCredentials) {
      _showCredentialsDialog();
    } else {
      _showComposeDialog();
    }
  }

  Future<String?> _showInvoiceSelectionDialog(String idsRef) async {
    final List<String> ids = idsRef.split(',').where((id) => id.isNotEmpty).toList();
    if (ids.isEmpty) return null;
    List<Transaction> invoices = [];
    for (final id in ids) {
      final invoice = await _dbService.getTransactionById(id);
      if (invoice != null) {
        invoices.add(invoice);
      }
    }

    if (invoices.isEmpty) return null;

    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          AppLocalizations.of(context).selectInvoiceForPayment,
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        content: SizedBox(
          width: double.maxFinite,
          height: 350,
          child: ListView.builder(
            itemCount: invoices.length,
            itemBuilder: (context, index) {
              final invoice = invoices[index];
              final isOverdue = invoice.dueDate != null &&
                  invoice.dueDate!.isBefore(DateTime.now());

              return Card(
                margin: EdgeInsets.symmetric(vertical: 4),
                elevation: 2,
                child: ListTile(
                  contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  leading: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.receipt,
                      color: isOverdue ? Colors.red : Colors.blue,
                      size: 24,
                    ),
                  ),
                  title: Row(
                    children: [
                      Expanded(
                        child: Text(
                          invoice.entity.isNotEmpty ? invoice.entity : AppLocalizations.of(context).noEntity,
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        '€${invoice.amount.toStringAsFixed(2)}',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: Colors.green[700],
                        ),
                      ),
                    ],
                  ),
                  subtitle: Padding(
                    padding: EdgeInsets.only(top: 4),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (invoice.monthRef != null)
                          Row(
                            children: [
                              Icon(Icons.calendar_today, size: 12, color: Colors.grey[600]),
                              SizedBox(width: 4),
                              Text(
                                'Ref: ${invoice.monthRef}',
                                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                              ),
                            ],
                          ),
                        if (invoice.dueDate != null)
                          Row(
                            children: [
                              Icon(
                                isOverdue ? Icons.warning : Icons.schedule,
                                size: 12,
                                color: isOverdue ? Colors.red : Colors.orange,
                              ),
                              SizedBox(width: 4),
                              Text(
                                isOverdue
                                    ? '${AppLocalizations.of(context).overdue} ${DateFormat('dd/MM').format(invoice.dueDate!)}'
                                    : '${AppLocalizations.of(context).due} ${DateFormat('dd/MM').format(invoice.dueDate!)}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: isOverdue ? Colors.red : Colors.orange,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ),
                  onTap: () {
                    Navigator.pop(context, invoice.id);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('${AppLocalizations.of(context).invoiceMarkedAsPaid} "${invoice.entity}" ${AppLocalizations.of(context).invoiceMarkedAsPaid2}'),
                        backgroundColor: Colors.green,
                      ),
                    );
                  },
                ),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              AppLocalizations.of(context).cancel,
              style: TextStyle(color: Colors.grey),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showComposeDialog() async {
    final recipientCtrl = TextEditingController();
    final subjectCtrl = TextEditingController();
    final bodyCtrl = TextEditingController();
    bool isGenerating = false;


    if (_aiAnalysis != null) {
      final entidade = _aiAnalysis!['entidade'] as String? ?? '';
      if (entidade.isNotEmpty) {
        final prevEmails = await _dbService.getPreviousEmailsForEntity(entidade);
        if (prevEmails.isNotEmpty) {
          recipientCtrl.text = prevEmails.first['recipient'] as String;
        }
      }
    }

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text('Compor Email'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: recipientCtrl,
                  decoration: InputDecoration(
                    labelText: AppLocalizations.of(context).recipient,
                    hintText: AppLocalizations.of(context).emailExample,
                  ),
                  keyboardType: TextInputType.emailAddress,
                ),
                SizedBox(height: 16),
                TextField(
                  controller: subjectCtrl,
                  decoration: InputDecoration(
                    labelText: AppLocalizations.of(context).subject,
                  ),
                ),
                SizedBox(height: 16),
                TextField(
                  controller: bodyCtrl,
                  decoration: InputDecoration(
                    labelText: AppLocalizations.of(context).messageBody,
                  ),
                  maxLines: 5,
                ),
                SizedBox(height: 16),
                ElevatedButton(
                  onPressed: isGenerating ? null : () async {
                    setDialogState(() { isGenerating = true; });
                    await _generateEmailContent(subjectCtrl, bodyCtrl);
                    setDialogState(() { isGenerating = false; });
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.black,
                    foregroundColor: Colors.white,
                    minimumSize: Size(double.infinity, 50),
                  ),
                  child: Text(isGenerating ? AppLocalizations.of(context).generating : AppLocalizations.of(context).generateAISuggestion),
                ),
                if (_receiptPaths.isNotEmpty) ...[
                  SizedBox(height: 16),
                  Container(
                    padding: EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.attach_file, color: Colors.grey[600]),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '${AppLocalizations.of(context).attachmentFileName} ${_receiptPaths.first.split('/').last}',
                            style: TextStyle(color: Colors.grey[700]),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (recipientCtrl.text.isEmpty || subjectCtrl.text.isEmpty || bodyCtrl.text.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(AppLocalizations.of(context).fillAllFields)),
                  );
                  return;
                }
                Navigator.pop(context);
                await _sendEmail(
                  recipient: recipientCtrl.text,
                  subject: subjectCtrl.text,
                  body: bodyCtrl.text,
                );
              },
              child: Text(AppLocalizations.of(context).send),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _generateEmailContent(TextEditingController subjectCtrl, TextEditingController bodyCtrl) async {
    if (_aiAnalysis == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context).aiAnalysisNotAvailableScanDocumentFirst)),
      );
      return;
    }

    final entidade = _aiAnalysis!['entidade'] as String? ?? _entityController.text;
    final descricao = _aiAnalysis!['descrição'] as String? ?? _descriptionController.text;
    final mesAnoRef = _aiAnalysis!['mes_ano_ref'] as String? ?? _monthRefController.text;
    final valorTotal = _aiAnalysis!['valor_total'] as String? ?? _amountController.text;
    final currentMonth = DateFormat('MMMM yyyy', 'pt').format(_selectedDate);


    final previousEmails = await _dbService.getPreviousEmailsForEntity(entidade);
    String previousStr = '';
    if (previousEmails.isNotEmpty) {

      final limitedEmails = previousEmails.take(2);
      previousStr = limitedEmails.map((e) =>
      'Data de Emissão: ${e['emission_date']}\nAssunto: ${e['subject']}\nCorpo: ${e['body']}\n\n'
      ).join();
    }

    final prompt = """
    Baseado nos seguintes dados de transação:
    - Entidade: $entidade
    - Descrição: $descricao
    - Mês/Ano Referência: $mesAnoRef
    - Valor: $valorTotal
    - Mês atual: $currentMonth

    Analise os emails anteriores para esta entidade (use padrões semelhantes, adaptando para o novo mês e detalhes):
    $previousStr

    Gere um assunto e corpo de email padrão em português para envio de comprovativo de pagamento.
    O assunto deve seguir o padrão dos anteriores, adaptando para o novo mês: $currentMonth.
    O corpo deve ser uma mensagem educada, mencionando o anexo, o valor e os detalhes, terminando com saudações.

    Responda APENAS com um objeto JSON de linha única:
    {"subject": "assunto gerado", "body": "corpo gerado"}
    Sem texto adicional.
    (Atenção: o output deve ser no idioma: ${AppLocalizations.of(context).promptLanguage})    
    """;

    try {
      final apiKey = await dbService.getSetting('gemini_api_key');

      Uri url = Uri.parse('https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent?key=$apiKey');

      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'contents': [
            {
              'parts': [
                {'text': prompt}
              ]
            }
          ],

          'generationConfig': {
            'temperature': 0.7,
            'topK': 40,
            'topP': 0.95,
            'maxOutputTokens': 512,
          }
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final content = data['candidates'][0]['content']['parts'][0]['text'];

        final jsonMatch = RegExp(r'\{.*\}').firstMatch(content);
        if (jsonMatch != null) {
          final genResult = jsonDecode(jsonMatch.group(0)!);
          if (mounted) {
            subjectCtrl.text = genResult['subject'] ?? '';
            bodyCtrl.text = genResult['body'] ?? '';
          }
        } else {
          throw Exception('JSON não encontrado na resposta');
        }
      } else {
        throw Exception('Erro na API Gemini: ${response.statusCode}');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${AppLocalizations.of(context).aiGenerationError} $e')),
        );
      }
    }
  }

  Future<void> _sendEmail({required String recipient, required String subject, required String body}) async {
    try {
      /*final smtpServer = SmtpServer(
        _smtpServer,
        port: int.parse(_port),
        username: _email,
        password: _password,
        ssl: false,
        ignoreBadCertificate: true,
      );*/

      final message = Message()
        ..from = Address(_email!, 'Financial Resume App')
        ..recipients.add(recipient)
        ..subject = subject
        ..html = body;

      if (_receiptPaths.isNotEmpty) {
        message.attachments.add(FileAttachment(File(_receiptPaths.first)));
      }


      final entity = _aiAnalysis?['entidade'] as String? ?? _entityController.text;
      final emissionDate = DateFormat('dd/MM/yyyy').format(_selectedDate);
      await _dbService.addSentEmail({
        'entity': entity,
        'recipient': recipient,
        'subject': subject,
        'body': body,
        'sentAt': DateTime.now().toIso8601String(),
        'emission_date': emissionDate,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context).emailSentSuccessfully)),
        );
      }
    } on MailerException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${AppLocalizations.of(context).errorSendingEmail} ${e.problems.map((p) => '${p.code}: ${p.msg}').join(', ')}')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${AppLocalizations.of(context).errorSendingEmail}: $e')),
        );
      }
    }
  }

  Future<void> _scanDocument() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => ScanFileScreen(sectionId: widget.sectionId)),
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
          idInvoiceRef = await _showInvoiceSelectionDialog(idsInvoiceRef);
        }

        setState(() {
          _idInvoiceRef = idInvoiceRef;
          _isCreditToggle = eCredito == '1';
          _aiAnalysis = aiResult;
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
            } catch (e) {

            }
          }
          if (mesAnoRef != 'UNKNOWN') {
            try {
              final parts = dataEmissao.split(' ');
              _selectedDate = DateTime(
                int.parse(parts[2]),
                int.parse(parts[1]),
                int.parse(parts[0]),
              );
              _monthRefController.text = DateFormat('MM/yyyy').format(_selectedDate);
            } catch (e) {

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
            } catch (e) {
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
    await _fileService.downloadImage(path);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Imagem baixada com sucesso!')),
    );
  }

  Future<void> _viewImage(String path) async {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ImageViewerScreen(imagePath: path),
      ),
    );
  }

  void _saveTransaction(String? idInvoiceRef, DateTime date) async {
    if (_formKey.currentState!.validate()) {
      if (_selectedDocType == '3' && idInvoiceRef != null && idInvoiceRef != 'UNKNOWN') {
        _mergeWithInvoice(idInvoiceRef, date);
        return;
      }

      final bool isPaid = _selectedDocType == '2' ? (_paidToggle ?? false) : false;

      final transaction = Transaction(
        id: widget.transaction?.id ?? DateTime.now().toString(),
        amount: double.parse(_amountController.text),
        entity: _entityController.text,
        description: _descriptionController.text,
        isCredit: _isCreditToggle,
        date: _selectedDate,
        receiptPaths: _receiptPaths,
        sectionId: widget.sectionId,
        docType: _selectedDocType,
        monthRef: _monthRefController.text.isNotEmpty ? _monthRefController.text : null,
        dueDate: _showDueDate ? _selectedDueDate : null,
        paid: isPaid,
        numeroSerie: _numSerie,
        metodoPagamento: _paymentMethod,
      );

      try {
        //final transactionProvider = context.read<TransactionProvider>();

        if (widget.transaction == null) {
          await _dbService.addTransaction(transaction);
        } else {
          await _dbService.updateTransaction(transaction);
        }

        Navigator.pop(context, true);
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${AppLocalizations.of(context).errorSavingTransaction} $e')),
        );
      }
    }
  }

  Future<void> _mergeWithInvoice(String idInvoiceRef, DateTime date) async {
    try {
      final invoice = await _dbService.getTransactionById(idInvoiceRef);
      if (invoice != null) {
        final mergedPaths = [..._receiptPaths, ...invoice.receiptPaths];

        final updatedInvoice = Transaction(
          id: invoice.id,
          amount: invoice.amount,
          entity: invoice.entity,
          description: invoice.description,
          isCredit: invoice.isCredit,
          date: date,
          receiptPaths: mergedPaths,
          sectionId: invoice.sectionId,
          docType: invoice.docType,
          monthRef: invoice.monthRef,
          dueDate: invoice.dueDate,
          paid: true,
        );

        await _dbService.updateTransaction(updatedInvoice);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context).invoiceMarkedPaidWithProof)),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${AppLocalizations.of(context).mergeError} $e')),
      );
    }
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
        actions: [
          IconButton(
            icon: const Icon(Icons.email_rounded),
            onPressed: _handleEmailSend,
            tooltip: l.send,
          ),
        ],
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
                          border: OutlineInputBorder(),
                        ),
                      ),
                      SizedBox(height: 16),
                      TextFormField(
                        controller: _amountController,
                        decoration: InputDecoration(
                          labelText: '${AppLocalizations.of(context).valueEuro}',
                          border: OutlineInputBorder(),
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
                          border: OutlineInputBorder(),
                        ),
                        maxLines: 2,
                      ),
                      SizedBox(height: 16),
                      TextFormField(
                        controller: _dateController,
                        decoration: InputDecoration(
                          labelText: AppLocalizations.of(context).date,
                          border: OutlineInputBorder(),
                          suffixIcon: Icon(Icons.calendar_today),
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
                            border: OutlineInputBorder(),
                            suffixIcon: Icon(Icons.calendar_today),
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
                            border: OutlineInputBorder(),
                            suffixIcon: Icon(Icons.calendar_today),
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