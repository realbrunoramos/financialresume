import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import '../l10n/app_localizations.dart';
import '../models/transaction.dart';
import '../services/database_service.dart';
import 'image_viewer_screen.dart';
import 'transaction_form_screen.dart';

class TransactionDetailScreen extends StatefulWidget {
  final Transaction transaction;
  final String sectionId;

  const TransactionDetailScreen({
    Key? key,
    required this.transaction,
    required this.sectionId,
  }) : super(key: key);

  @override
  State<TransactionDetailScreen> createState() => _TransactionDetailScreenState();
}

class _TransactionDetailScreenState extends State<TransactionDetailScreen> with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  bool _isExpanded = false;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _toggleExpand() {
    setState(() {
      _isExpanded = !_isExpanded;
    });
    if (_isExpanded) {
      _animationController.forward();
    } else {
      _animationController.reverse();
    }
  }

  void _shareTransaction() {
    final format = DateFormat('dd/MM/yyyy');
    final currency = NumberFormat.currency(locale: 'pt_PT', symbol: '€');
    final shareText = '''
${AppLocalizations.of(context).transactionDescription} ${widget.transaction.description}
${AppLocalizations.of(context).entity} ${widget.transaction.entity}
${AppLocalizations.of(context).amount} ${widget.transaction.isCredit ? '+' : '-'} ${currency.format(widget.transaction.amount)}
${AppLocalizations.of(context).dateField} ${format.format(widget.transaction.date)}
${AppLocalizations.of(context).reference} ${widget.transaction.monthRef ?? 'N/A'}
${AppLocalizations.of(context).paidStatus} ${widget.transaction.paid ? "${AppLocalizations.of(context).yes}" : "${AppLocalizations.of(context).no}"}
    ''';
    Share.share(shareText);
  }

  @override
  Widget build(BuildContext context) {
    final format = DateFormat('dd/MM/yyyy');
    final currency = NumberFormat.currency(locale: 'pt_PT', symbol: '€');
    final isCredit = widget.transaction.isCredit;
    final icon = isCredit ? Icons.arrow_upward : Icons.arrow_downward;
    final iconColor = isCredit ? Colors.green : Colors.red;

    final docType = widget.transaction.docType;
    final isComprovativo = docType == '3';
    final isTalao = docType == '1';

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        title: Text(
          widget.transaction.description,
          style: const TextStyle(fontWeight: FontWeight.bold),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.share),
            onPressed: _shareTransaction,
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: (value) {
              if (value == 'edit') {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (context) => TransactionFormScreen(
                      transaction: widget.transaction,
                      sectionId: widget.sectionId,
                    ),
                  ),
                );
              } else if (value == 'delete') {
                _showDeleteDialog(context);
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(value: 'edit', child: Text(AppLocalizations.of(context).edit)),
              PopupMenuItem(value: 'delete', child: Text(AppLocalizations.of(context).delete, style: TextStyle(color: Colors.red))),
            ],
          ),
        ],
      ),
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: AnimatedBuilder(
              animation: _fadeAnimation,
              builder: (context, child) {
                return Opacity(
                  opacity: _fadeAnimation.value,
                  child: Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [iconColor.withAlpha(50), Colors.transparent],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                      borderRadius: const BorderRadius.vertical(bottom: Radius.circular(20)),
                    ),
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      children: [
                        Icon(
                          icon,
                          size: 48,
                          color: iconColor,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '${isCredit ? '+' : '-'} ${currency.format(widget.transaction.amount)}',
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: iconColor,
                          ),
                        ),
                        Text(
                          widget.transaction.entity,
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w500,
                            color: Colors.grey[700],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          SliverList(
            delegate: SliverChildListDelegate([
              const SizedBox(height: 24),
              // Date
              _buildInfoTile(
                AppLocalizations.of(context).date,
                format.format(widget.transaction.date),
                Icons.calendar_today,
              ),
              // Description
              _buildInfoTile(
                AppLocalizations.of(context).description,
                widget.transaction.description,
                Icons.description,
              ),
              // Month Ref
              if (widget.transaction.monthRef != null && widget.transaction.monthRef!.isNotEmpty)
                _buildInfoTile(
                  AppLocalizations.of(context).referenceMonthYear,
                  widget.transaction.monthRef!,
                  Icons.date_range,
                ),
              // Due Date
              if (widget.transaction.dueDate != null)
                _buildInfoTile(
                  AppLocalizations.of(context).dueDate,
                  format.format(widget.transaction.dueDate!),
                  Icons.event,
                ),
              // Paid (escondido para comprovativo e talão)
              if (!isComprovativo && !isTalao)
                _buildInfoTile(
                  AppLocalizations.of(context).paid,
                  widget.transaction.paid ? "${AppLocalizations.of(context).yes}" : "${AppLocalizations.of(context).no}",
                  widget.transaction.paid ? Icons.check_circle : Icons.cancel,
                  trailing: Switch(
                    value: widget.transaction.paid,
                    onChanged: null,
                    activeColor: Colors.green,
                  ),
                ),
              const SizedBox(height: 24),
              // Anexos
              _buildAnexosSection(),
            ]),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoTile(String title, String subtitle, IconData icon, {Widget? trailing}) {
    return Card(
      color: Colors.white,  // Branco explícito
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: ListTile(
        leading: Icon(icon, color: Colors.grey[600]),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w500)),
        subtitle: Text(subtitle),
        trailing: trailing,  // Sem botão de copy para todas
      ),
    );
  }

  Widget _buildAnexosSection() {
    if (widget.transaction.receiptPaths.isEmpty) {
      return Card(
        color: Colors.white,  // Branco
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        elevation: 1,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        child: ListTile(
          leading:  Icon(Icons.attach_file, color: Colors.grey[600]),
          title: Text(AppLocalizations.of(context).attachments, style: TextStyle(fontWeight: FontWeight.w500)),
          subtitle: Text(AppLocalizations.of(context).noAttachments),
        ),
      );
    }

    return Card(
      color: Colors.white,  // Branco
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: ExpansionTile(
        leading: Icon(Icons.attach_file, color: Colors.grey[600]),
        title: Text(AppLocalizations.of(context).attachments, style: TextStyle(fontWeight: FontWeight.w500)),
        subtitle: Text('${widget.transaction.receiptPaths.length} ${AppLocalizations.of(context).countFiles}'),
        children: widget.transaction.receiptPaths.map((path) => ListTile(
          leading: Image.file(
            File(path),
            width: 50,
            height: 50,
            fit: BoxFit.cover,
          ),
          title: Text(path.split('/').last),
          trailing: IconButton(
            icon: const Icon(Icons.fullscreen),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => ImageViewerScreen(imagePath: path),
              ),
            ),
          ),
        )).toList(),
      ),
    );
  }

  void _showDeleteDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(AppLocalizations.of(context).deleteTransaction),
        content: Text(AppLocalizations.of(context).confirmDeleteTransaction),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(AppLocalizations.of(context).cancel),
          ),
          TextButton(
            onPressed: () async {
              await DatabaseService().deleteTransaction(widget.transaction.id);
              Navigator.pop(context);
              Navigator.pop(context);  // Volta para lista
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(AppLocalizations.of(context).transactionDeleted)),
              );
            },
            child: Text(AppLocalizations.of(context).delete, style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}