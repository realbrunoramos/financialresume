import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import '../l10n/app_localizations.dart';
import '../models/transaction.dart';
import '../services/database_service.dart';
import '../theme/colors.dart';
import '../theme/app_tokens.dart';
import 'image_viewer_screen.dart';
import 'transaction_form_screen.dart';

class TransactionDetailScreen extends StatefulWidget {
  final Transaction transaction;
  final String sectionId;

  const TransactionDetailScreen({
    super.key,
    required this.transaction,
    required this.sectionId,
  });

  @override
  State<TransactionDetailScreen> createState() =>
      _TransactionDetailScreenState();
}

class _TransactionDetailScreenState extends State<TransactionDetailScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: AppTokens.normal);
    _fade = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _share() {
    final fmt = DateFormat('dd/MM/yyyy');
    final cur = NumberFormat.currency(locale: 'pt_PT', symbol: '€');
    final l   = AppLocalizations.of(context);
    final t   = widget.transaction;
    Share.share('''${l.transactionDescription}: ${t.description}
${l.entity}: ${t.entity}
${l.amount}: ${t.isCredit ? '+' : '-'} ${cur.format(t.amount)}
${l.dateField}: ${fmt.format(t.date)}
${l.reference}: ${t.monthRef ?? 'N/A'}
${l.paidStatus}: ${t.paid ? l.yes : l.no}''');
  }

  void _editTransaction() {
    Navigator.pushReplacement(
      context,
      slideRoute(TransactionFormScreen(
        transaction: widget.transaction,
        sectionId: widget.sectionId,
      )),
    );
  }

  void _showDeleteSheet() {
    final l      = AppLocalizations.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => SafeArea(
        child: Container(
          margin: const EdgeInsets.all(AppTokens.sp12),
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkCard : AppColors.white,
            borderRadius: BorderRadius.circular(AppTokens.radius24),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 36, height: 4,
                margin: const EdgeInsets.only(top: AppTokens.sp12),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkBorder : AppColors.grey200,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(
                    AppTokens.sp20, AppTokens.sp16, AppTokens.sp20, AppTokens.sp4),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(l.deleteTransaction,
                      style: TextStyle(
                        fontSize: 17, fontWeight: FontWeight.w700,
                        color: isDark ? AppColors.darkText : AppColors.dark,
                        letterSpacing: -0.3,
                      )),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(
                    AppTokens.sp20, AppTokens.sp8, AppTokens.sp20, AppTokens.sp20),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Text(l.confirmDeleteTransaction,
                      style: TextStyle(
                          color: isDark
                              ? AppColors.darkSubtext
                              : AppColors.grey500)),
                  const SizedBox(height: AppTokens.sp24),
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
                            backgroundColor: AppColors.danger),
                        onPressed: () async {
                          Navigator.pop(context);
                          await DatabaseService()
                              .deleteTransaction(widget.transaction.id);
                          if (mounted) {
                            Navigator.pop(context);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(l.transactionDeleted),
                                backgroundColor: AppColors.success,
                              ),
                            );
                          }
                        },
                        child: Text(l.delete),
                      ),
                    ),
                  ]),
                ]),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark   = Theme.of(context).brightness == Brightness.dark;
    final l        = AppLocalizations.of(context);
    final t        = widget.transaction;
    final fmt      = DateFormat('dd/MM/yyyy');
    final cur      = NumberFormat.currency(locale: 'pt_PT', symbol: '€');
    final isCredit = t.isCredit;
    final amtColor = isCredit ? AppColors.success : AppColors.danger;
    final bgColor  = isCredit
        ? (isDark ? AppColors.success.withAlpha(30) : AppColors.successLight)
        : (isDark ? AppColors.danger.withAlpha(30) : AppColors.dangerLight);

    final docType        = t.docType;
    final isComprovativo = docType == '3';
    final isTalao        = docType == '1';

    return Scaffold(
      backgroundColor:
          isDark ? AppColors.darkBackground : const Color(0xFFF5F5F7),
      appBar: AppBar(
        backgroundColor:
            isDark ? AppColors.darkSurface : AppColors.white,
        foregroundColor: isDark ? AppColors.darkText : AppColors.dark,
        elevation: 0,
        title: Text(
          t.description.isNotEmpty ? t.description : t.entity,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 17),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.share_rounded),
            tooltip: 'Share',
            onPressed: _share,
          ),
          IconButton(
            icon: const Icon(Icons.edit_rounded),
            tooltip: l.edit,
            onPressed: _editTransaction,
          ),
          IconButton(
            icon: Icon(Icons.delete_rounded, color: AppColors.danger),
            tooltip: l.delete,
            onPressed: _showDeleteSheet,
          ),
        ],
      ),
      body: FadeTransition(
        opacity: _fade,
        child: CustomScrollView(
          slivers: [
            // ── Hero header ──────────────────────────────────────────────────
            SliverToBoxAdapter(
              child: Container(
                width: double.infinity,
                margin: const EdgeInsets.fromLTRB(
                    AppTokens.sp16, AppTokens.sp16,
                    AppTokens.sp16, AppTokens.sp8),
                decoration: BoxDecoration(
                  color: bgColor,
                  borderRadius: BorderRadius.circular(AppTokens.radius20),
                  border: Border.all(
                    color: amtColor.withAlpha(isDark ? 60 : 40),
                  ),
                ),
                padding: const EdgeInsets.all(AppTokens.sp24),
                child: Column(
                  children: [
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: amtColor.withAlpha(isDark ? 50 : 30),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        isCredit
                            ? Icons.arrow_downward_rounded
                            : Icons.arrow_upward_rounded,
                        size: 28,
                        color: amtColor,
                      ),
                    ),
                    const SizedBox(height: AppTokens.sp12),
                    Text(
                      '${isCredit ? '+' : '-'} ${cur.format(t.amount)}',
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.w800,
                        color: amtColor,
                        letterSpacing: -1,
                      ),
                    ),
                    if (t.entity.isNotEmpty) ...[
                      const SizedBox(height: AppTokens.sp4),
                      Text(
                        t.entity,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          color: isDark
                              ? AppColors.darkSubtext
                              : AppColors.grey500,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),

            // ── Details ──────────────────────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: AppTokens.sp16, vertical: AppTokens.sp4),
                child: Column(
                  children: [
                    _InfoCard(
                      isDark: isDark,
                      children: [
                        _InfoRow(
                          icon: Icons.calendar_today_rounded,
                          label: l.date,
                          value: fmt.format(t.date),
                          isDark: isDark,
                        ),
                        if (t.description.isNotEmpty) ...[
                          _Separator(isDark: isDark),
                          _InfoRow(
                            icon: Icons.notes_rounded,
                            label: l.description,
                            value: t.description,
                            isDark: isDark,
                          ),
                        ],
                        if (t.entity.isNotEmpty) ...[
                          _Separator(isDark: isDark),
                          _InfoRow(
                            icon: Icons.business_rounded,
                            label: l.entity,
                            value: t.entity,
                            isDark: isDark,
                          ),
                        ],
                        if (t.monthRef != null &&
                            t.monthRef!.isNotEmpty) ...[
                          _Separator(isDark: isDark),
                          _InfoRow(
                            icon: Icons.date_range_rounded,
                            label: l.referenceMonthYear,
                            value: t.monthRef!,
                            isDark: isDark,
                          ),
                        ],
                        if (t.dueDate != null) ...[
                          _Separator(isDark: isDark),
                          _InfoRow(
                            icon: Icons.event_rounded,
                            label: l.dueDate,
                            value: fmt.format(t.dueDate!),
                            isDark: isDark,
                            valueColor: _dueDateColor(t.dueDate!),
                          ),
                        ],
                        if (t.numeroSerie != null &&
                            t.numeroSerie!.isNotEmpty &&
                            t.numeroSerie != 'UNKNOWN') ...[
                          _Separator(isDark: isDark),
                          _InfoRow(
                            icon: Icons.tag_rounded,
                            label: l.invoiceNumber,
                            value: t.numeroSerie!,
                            isDark: isDark,
                          ),
                        ],
                        if (t.metodoPagamento != null &&
                            t.metodoPagamento!.isNotEmpty &&
                            t.metodoPagamento != 'UNKNOWN') ...[
                          _Separator(isDark: isDark),
                          _InfoRow(
                            icon: Icons.payment_rounded,
                            label: l.payment,
                            value: t.metodoPagamento!,
                            isDark: isDark,
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: AppTokens.sp12),

                    // ── Paid status ─────────────────────────────────────────
                    if (!isComprovativo && !isTalao)
                      _InfoCard(
                        isDark: isDark,
                        children: [
                          _PaidRow(
                              transaction: t, isDark: isDark, l: l),
                        ],
                      ),

                    const SizedBox(height: AppTokens.sp12),

                    // ── Attachments ─────────────────────────────────────────
                    _AttachmentsCard(
                        transaction: t, isDark: isDark, l: l),

                    const SizedBox(height: 80),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _dueDateColor(DateTime due) {
    final d = due.difference(DateTime.now()).inDays;
    if (d < 0) return AppColors.danger;
    if (d <= 7) return AppColors.warning;
    return AppColors.success;
  }
}

// ── Info card wrapper ─────────────────────────────────────────────────────────
class _InfoCard extends StatelessWidget {
  final bool isDark;
  final List<Widget> children;
  const _InfoCard({required this.isDark, required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : AppColors.white,
        borderRadius: BorderRadius.circular(AppTokens.radius16),
        border: Border.all(
            color: isDark ? AppColors.darkBorder : AppColors.grey100),
        boxShadow: isDark ? null : AppTokens.shadowSm,
      ),
      child: Column(children: children),
    );
  }
}

// ── Single info row ───────────────────────────────────────────────────────────
class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final bool isDark;
  final Color? valueColor;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.isDark,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onLongPress: () {
        HapticFeedback.lightImpact();
        Clipboard.setData(ClipboardData(text: value));
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context).copied),
            duration: const Duration(seconds: 1),
          ),
        );
      },
      borderRadius: BorderRadius.circular(AppTokens.radius16),
      child: Padding(
        padding: const EdgeInsets.symmetric(
            horizontal: AppTokens.sp16, vertical: AppTokens.sp14),
        child: Row(children: [
          Icon(icon,
              size: 18,
              color:
                  isDark ? AppColors.darkSubtext : AppColors.grey400),
          const SizedBox(width: AppTokens.sp12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      letterSpacing: 0.4,
                      color: isDark
                          ? AppColors.darkSubtext
                          : AppColors.grey500,
                    )),
                const SizedBox(height: 2),
                Text(value,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: valueColor ??
                          (isDark
                              ? AppColors.darkText
                              : AppColors.dark),
                    )),
              ],
            ),
          ),
        ]),
      ),
    );
  }
}

// ── Thin divider between rows ─────────────────────────────────────────────────
class _Separator extends StatelessWidget {
  final bool isDark;
  const _Separator({required this.isDark});

  @override
  Widget build(BuildContext context) => Divider(
        height: 1,
        indent: AppTokens.sp16 + 18 + AppTokens.sp12,
        endIndent: AppTokens.sp16,
        color: isDark ? AppColors.darkBorder : AppColors.grey100,
      );
}

// ── Paid status row ───────────────────────────────────────────────────────────
class _PaidRow extends StatelessWidget {
  final Transaction transaction;
  final bool isDark;
  final AppLocalizations l;
  const _PaidRow(
      {required this.transaction,
      required this.isDark,
      required this.l});

  @override
  Widget build(BuildContext context) {
    final paid  = transaction.paid;
    final color = paid ? AppColors.success : AppColors.grey400;

    return Padding(
      padding: const EdgeInsets.symmetric(
          horizontal: AppTokens.sp16, vertical: AppTokens.sp12),
      child: Row(children: [
        Icon(paid ? Icons.check_circle_rounded : Icons.cancel_rounded,
            size: 18, color: color),
        const SizedBox(width: AppTokens.sp12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(l.paid,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 0.4,
                    color: isDark
                        ? AppColors.darkSubtext
                        : AppColors.grey500,
                  )),
              const SizedBox(height: 2),
              Text(paid ? l.yes : l.no,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: color,
                  )),
            ],
          ),
        ),
        Switch(
          value: paid,
          onChanged: null,
          activeTrackColor: AppColors.success.withAlpha(100),
          activeThumbColor: AppColors.success,
        ),
      ]),
    );
  }
}

// ── Attachments card ──────────────────────────────────────────────────────────
class _AttachmentsCard extends StatefulWidget {
  final Transaction transaction;
  final bool isDark;
  final AppLocalizations l;
  const _AttachmentsCard(
      {required this.transaction,
      required this.isDark,
      required this.l});

  @override
  State<_AttachmentsCard> createState() => _AttachmentsCardState();
}

class _AttachmentsCardState extends State<_AttachmentsCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final paths  = widget.transaction.receiptPaths;
    final isDark = widget.isDark;
    final l      = widget.l;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : AppColors.white,
        borderRadius: BorderRadius.circular(AppTokens.radius16),
        border: Border.all(
            color: isDark ? AppColors.darkBorder : AppColors.grey100),
        boxShadow: isDark ? null : AppTokens.shadowSm,
      ),
      child: paths.isEmpty
          ? Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: AppTokens.sp16, vertical: AppTokens.sp14),
              child: Row(children: [
                Icon(Icons.attach_file_rounded,
                    size: 18,
                    color: isDark
                        ? AppColors.darkSubtext
                        : AppColors.grey400),
                const SizedBox(width: AppTokens.sp12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(l.attachments,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            letterSpacing: 0.4,
                            color: isDark
                                ? AppColors.darkSubtext
                                : AppColors.grey500,
                          )),
                      const SizedBox(height: 2),
                      Text(l.noAttachments,
                          style: TextStyle(
                            fontSize: 15,
                            color: isDark
                                ? AppColors.darkSubtext
                                : AppColors.grey400,
                          )),
                    ],
                  ),
                ),
              ]),
            )
          : Column(
              children: [
                InkWell(
                  onTap: () => setState(() => _expanded = !_expanded),
                  borderRadius: BorderRadius.circular(AppTokens.radius16),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: AppTokens.sp16,
                        vertical: AppTokens.sp14),
                    child: Row(children: [
                      Icon(Icons.attach_file_rounded,
                          size: 18,
                          color: isDark
                              ? AppColors.darkSubtext
                              : AppColors.grey400),
                      const SizedBox(width: AppTokens.sp12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(l.attachments,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                  letterSpacing: 0.4,
                                  color: isDark
                                      ? AppColors.darkSubtext
                                      : AppColors.grey500,
                                )),
                            const SizedBox(height: 2),
                            Text(
                                '${paths.length} ${l.countFiles}',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w500,
                                  color: isDark
                                      ? AppColors.darkText
                                      : AppColors.dark,
                                )),
                          ],
                        ),
                      ),
                      Icon(
                        _expanded
                            ? Icons.expand_less_rounded
                            : Icons.expand_more_rounded,
                        color: isDark
                            ? AppColors.darkSubtext
                            : AppColors.grey400,
                      ),
                    ]),
                  ),
                ),
                AnimatedSize(
                  duration: AppTokens.normal,
                  curve: Curves.easeInOut,
                  child: _expanded
                      ? Column(
                          children: paths.map((path) => _AttachmentTile(
                                path: path,
                                isDark: isDark,
                              )).toList(),
                        )
                      : const SizedBox.shrink(),
                ),
              ],
            ),
    );
  }
}

// ── Single attachment tile ────────────────────────────────────────────────────
class _AttachmentTile extends StatelessWidget {
  final String path;
  final bool isDark;
  const _AttachmentTile({required this.path, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Divider(
          height: 1,
          indent: AppTokens.sp16,
          endIndent: AppTokens.sp16,
          color: isDark ? AppColors.darkBorder : AppColors.grey100),
      InkWell(
        onTap: () => Navigator.push(
          context,
          slideRoute(ImageViewerScreen(imagePath: path)),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(
              horizontal: AppTokens.sp16, vertical: AppTokens.sp10),
          child: Row(children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(AppTokens.radius8),
              child: Image.file(
                File(path),
                width: 48,
                height: 48,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  width: 48,
                  height: 48,
                  color: isDark
                      ? AppColors.darkBorder
                      : AppColors.grey200,
                  child: Icon(Icons.broken_image_rounded,
                      size: 24,
                      color: isDark
                          ? AppColors.darkSubtext
                          : AppColors.grey400),
                ),
              ),
            ),
            const SizedBox(width: AppTokens.sp12),
            Expanded(
              child: Text(
                path.split(Platform.pathSeparator).last,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color:
                      isDark ? AppColors.darkText : AppColors.dark,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: AppTokens.sp8),
            Icon(Icons.open_in_new_rounded,
                size: 18,
                color: isDark
                    ? AppColors.darkSubtext
                    : AppColors.grey400),
          ]),
        ),
      ),
    ]);
  }
}
