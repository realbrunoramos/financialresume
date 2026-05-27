import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../l10n/app_localizations.dart';
import '../models/section.dart';
import '../models/transaction.dart';
import '../models/reserved_amount.dart';
import '../providers/app_data_provider.dart';
import '../providers/transaction_provider.dart';
import '../services/database_service.dart';
import '../widgets/transaction_list_tile.dart';
import '../widgets/skeleton_loader.dart';
import '../widgets/empty_state.dart';
import '../theme/colors.dart';
import '../theme/app_tokens.dart';
import 'transaction_form_screen.dart';
import 'summary_screen.dart';
import 'transaction_detail_screen.dart';
import 'reserved_amount_form_screen.dart';

// ── Data class ────────────────────────────────────────────────────────────────
class _FinancialData {
  final double balance;
  final double totalReserved;
  final double availableAmount;
  final double dailyLimit;
  final int remainingDays;
  final List<Transaction> transactions;
  final List<Transaction> invoices;
  final List<ReservedAmount> reservedAmounts;

  const _FinancialData({
    required this.balance,
    required this.totalReserved,
    required this.availableAmount,
    required this.dailyLimit,
    required this.remainingDays,
    required this.transactions,
    required this.invoices,
    required this.reservedAmounts,
  });
}

// ── Invoice urgency ───────────────────────────────────────────────────────────
enum _Urgency { overdue, soon, ok, none }

_Urgency _urgencyOf(Transaction t) {
  if (t.dueDate == null) return _Urgency.none;
  final d = t.dueDate!.difference(DateTime.now()).inDays;
  if (d < 0) return _Urgency.overdue;
  if (d <= 7) return _Urgency.soon;
  return _Urgency.ok;
}

Color _urgencyColor(_Urgency u) {
  switch (u) {
    case _Urgency.overdue: return AppColors.danger;
    case _Urgency.soon:   return AppColors.warning;
    case _Urgency.ok:     return AppColors.success;
    case _Urgency.none:   return AppColors.info;
  }
}

IconData _urgencyIcon(_Urgency u) {
  switch (u) {
    case _Urgency.overdue: return Icons.warning_rounded;
    case _Urgency.soon:   return Icons.schedule_rounded;
    case _Urgency.ok:     return Icons.receipt_rounded;
    case _Urgency.none:   return Icons.receipt_outlined;
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class SectionScreen extends StatefulWidget {
  final Section section;
  const SectionScreen({super.key, required this.section});

  @override
  State<SectionScreen> createState() => _SectionScreenState();
}

class _SectionScreenState extends State<SectionScreen>
    with SingleTickerProviderStateMixin {
  final DatabaseService _db = DatabaseService();
  late Future<_FinancialData> _future;

  final _searchCtrl  = TextEditingController();
  final _searchFocus = FocusNode();
  final _scrollCtrl  = ScrollController();
  List<Transaction> _all      = [];
  List<Transaction> _filtered = [];
  bool _searchFocused   = false;
  bool _reservedExpanded = false;

  // ── Pagination state ───────────────────────────────────────────────────────
  static const int _kPageSize = 30;
  int  _txOffset      = 0;
  bool _hasMore       = true;
  bool _isLoadingMore = false;

  late AnimationController _fabCtrl;
  late Animation<double> _fabScale;

  // ── Lifecycle ──────────────────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    _fabCtrl = AnimationController(vsync: this, duration: AppTokens.slow);
    _fabScale = CurvedAnimation(parent: _fabCtrl, curve: Curves.elasticOut);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<TransactionProvider>().loadTransactions(widget.section.id);
      _fabCtrl.forward();
    });

    _scrollCtrl.addListener(_onScroll);
    _future = _load();
    _searchCtrl.addListener(_filter);
    _searchFocus.addListener(() {
      setState(() => _searchFocused = _searchFocus.hasFocus);
    });
  }

  @override
  void dispose() {
    _fabCtrl.dispose();
    _scrollCtrl.dispose();
    _searchCtrl.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  // ── Scroll → load more ─────────────────────────────────────────────────────
  void _onScroll() {
    if (_scrollCtrl.position.pixels >=
        _scrollCtrl.position.maxScrollExtent - 300) {
      _loadMore();
    }
  }

  Future<void> _loadMore() async {
    if (_isLoadingMore || !_hasMore || _searchCtrl.text.isNotEmpty) return;
    setState(() => _isLoadingMore = true);
    try {
      final more = await _db.getTransactionsPaged(
        widget.section.id,
        limit:  _kPageSize,
        offset: _txOffset,
      );
      if (!mounted) return;
      setState(() {
        _all.addAll(more);
        _txOffset += more.length;
        _hasMore       = more.length == _kPageSize;
        _isLoadingMore = false;
        _filtered      = List.of(_all);
      });
    } catch (_) {
      if (mounted) setState(() => _isLoadingMore = false);
    }
  }

  // ── Data ───────────────────────────────────────────────────────────────────
  Future<_FinancialData> _load() async {
    // Balance + count from a single SQL aggregation (no need to hold all rows).
    final stats    = await _db.getSectionStats(widget.section.id);
    final reserved = await _db.getReservedAmounts(widget.section.id);
    final invoices = await _db.getNoPaidInvoices(widget.section.id);

    final totalReserved = reserved.fold<double>(0, (s, r) => s + r.amount);
    final available =
        (stats.balance - totalReserved).clamp(0.0, double.infinity);

    final now     = DateTime.now();
    final lastDay = DateTime(now.year, now.month + 1, 0);
    final days    = lastDay.difference(now).inDays + 1;
    final daily   = available > 0 && days > 0 ? available / days : 0.0;

    // First page of transactions.
    _txOffset = 0;
    final firstPage = await _db.getTransactionsPaged(
      widget.section.id,
      limit:  _kPageSize,
      offset: 0,
    );
    _txOffset = firstPage.length;
    _hasMore  = firstPage.length == _kPageSize;

    if (mounted) {
      setState(() {
        _all = firstPage;
        _filtered = List.of(firstPage);
      });
    }

    return _FinancialData(
      balance:         stats.balance,
      totalReserved:   totalReserved,
      availableAmount: available,
      dailyLimit:      daily,
      remainingDays:   days,
      transactions:    firstPage,
      invoices:        _sortInvoices(invoices),
      reservedAmounts: reserved,
    );
  }

  Future<void> _refresh() async {
    // Reset pagination then reload.
    _txOffset      = 0;
    _hasMore       = true;
    _isLoadingMore = false;
    final d = await _load();
    if (mounted) {
      setState(() => _future = Future.value(d));
      // Propagate the change to HomeScreen so balance + card stats update
      // without requiring the user to navigate back first.
      context.read<AppDataProvider>().invalidate();
    }
  }

  /// Filters the in-memory list when the query is empty; queries the DB for
  /// a full-text search so results aren't limited to the current page.
  Future<void> _filter() async {
    final q = _searchCtrl.text.toLowerCase().trim();
    if (q.isEmpty) {
      setState(() => _filtered = List.of(_all));
      return;
    }
    // Full scan for search — results span all pages.
    final all = await _db.getAllTransactions(widget.section.id);
    if (!mounted) return;
    setState(() {
      _filtered = all.where((t) =>
          t.entity.toLowerCase().contains(q) ||
          t.description.toLowerCase().contains(q) ||
          t.amount.toString().contains(q) ||
          (t.monthRef?.toLowerCase().contains(q) ?? false) ||
          (t.numeroSerie?.toLowerCase().contains(q) ?? false) ||
          (t.metodoPagamento?.toLowerCase().contains(q) ?? false) ||
          DateFormat('dd/MM/yyyy').format(t.date).contains(q)).toList();
    });
  }

  List<Transaction> _sortInvoices(List<Transaction> list) {
    final now = DateTime.now();
    return list..sort((a, b) {
      if (a.dueDate != null && b.dueDate != null) {
        final dA = a.dueDate!.difference(now).inDays;
        final dB = b.dueDate!.difference(now).inDays;
        if (dA < 0 && dB < 0) return dA.compareTo(dB);
        if (dA < 0) return -1;
        if (dB < 0) return 1;
        return dA.compareTo(dB);
      }
      if (a.dueDate != null) return -1;
      if (b.dueDate != null) return 1;
      return b.date.compareTo(a.date);
    });
  }

  // ── Due-date label ─────────────────────────────────────────────────────────
  String _dueDateLabel(DateTime due) {
    final l = AppLocalizations.of(context);
    final now  = DateTime.now();
    final diff = DateTime(due.year, due.month, due.day)
        .difference(DateTime(now.year, now.month, now.day))
        .inDays;
    if (diff < 0) return '${l.overdueByDays} ${diff.abs()} ${l.overdueByDays2}';
    if (diff == 0) return l.dueToday;
    if (diff == 1) return l.dueTomorrow;
    return '${l.dueInDays} $diff ${l.dueInDays2}';
  }

  // ── Navigation ─────────────────────────────────────────────────────────────
  PageRouteBuilder<T> _slide<T>(Widget page) => PageRouteBuilder<T>(
        pageBuilder: (_, __, ___) => page,
        transitionDuration: AppTokens.normal,
        transitionsBuilder: (_, a, __, child) => FadeTransition(
          opacity: a,
          child: SlideTransition(
            position: Tween(
                    begin: const Offset(0.04, 0), end: Offset.zero)
                .animate(CurvedAnimation(parent: a, curve: Curves.easeOut)),
            child: child,
          ),
        ),
      );

  // ── Action sheets ──────────────────────────────────────────────────────────

  /// Shows invoice detail sheet; if user taps "Actions" awaits sheet close
  /// before opening the options sheet — avoids the Navigator race condition.
  Future<void> _showInvoiceDetails(Transaction inv) async {
    final l   = AppLocalizations.of(context);
    final cur = NumberFormat.currency(locale: 'pt_PT', symbol: '€');

    final action = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _Sheet(
        title: inv.entity.isNotEmpty ? inv.entity : l.invoice,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (inv.numeroSerie != null &&
                inv.numeroSerie!.isNotEmpty &&
                inv.numeroSerie != 'UNKNOWN')
              _DetailRow(label: l.invoiceNumber, value: inv.numeroSerie!),
            _DetailRow(label: l.value, value: cur.format(inv.amount)),
            _DetailRow(
                label: l.emissionDate,
                value: DateFormat('dd/MM/yyyy').format(inv.date)),
            if (inv.dueDate != null)
              _DetailRow(
                  label: l.limitDate,
                  value:
                      '${DateFormat('dd/MM/yyyy').format(inv.dueDate!)}  (${_dueDateLabel(inv.dueDate!)})'),
            if (inv.monthRef != null && inv.monthRef!.isNotEmpty)
              _DetailRow(
                  label: l.reference.replaceFirst(':', ''),
                  value: inv.monthRef!),
            if (inv.metodoPagamento != null &&
                inv.metodoPagamento!.isNotEmpty &&
                inv.metodoPagamento != 'UNKNOWN')
              _DetailRow(
                  label: l.payment,
                  value: inv.metodoPagamento!.split('/').length == 2
                      ? '${l.entity}: ${inv.metodoPagamento!.split('/')[0]}\n'
                          '${l.reference} ${inv.metodoPagamento!.split('/')[1]}'
                      : 'IBAN: ${inv.metodoPagamento!}'),
            if (inv.description.isNotEmpty)
              _DetailRow(label: l.description, value: inv.description),
            const SizedBox(height: AppTokens.sp16),
            Row(children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context, 'close'),
                  child: Text(l.close),
                ),
              ),
              const SizedBox(width: AppTokens.sp12),
              Expanded(
                child: FilledButton(
                  onPressed: () => Navigator.pop(context, 'actions'),
                  child: Text(l.invoiceActions),
                ),
              ),
            ]),
          ],
        ),
      ),
    );
    if (!mounted) return;
    if (action == 'actions') {
      await _showInvoiceOptions(inv);
    }
  }

  /// Awaits the options sheet before acting — no synchronous pop+open chains.
  Future<void> _showInvoiceOptions(Transaction inv) async {
    final l = AppLocalizations.of(context);
    final action = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _Sheet(
        title: l.invoiceActions,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          _SheetOption(
            icon: Icons.edit_rounded,
            label: l.edit,
            onTap: () => Navigator.pop(context, 'edit'),
          ),
          _SheetOption(
            icon: Icons.savings_rounded,
            label: l.reserve,
            onTap: () => Navigator.pop(context, 'reserve'),
          ),
          _SheetOption(
            icon: Icons.delete_rounded,
            label: l.delete,
            color: AppColors.danger,
            onTap: () => Navigator.pop(context, 'delete'),
          ),
        ]),
      ),
    );
    if (!mounted) return;
    if (action == 'edit') {
      await Navigator.push(context,
          _slide(TransactionFormScreen(
              transaction: inv, sectionId: widget.section.id)));
      if (mounted) _refresh();
    } else if (action == 'reserve') {
      _reserveInvoice(inv);
    } else if (action == 'delete') {
      final confirmed = await _confirmDelete(
        title: l.confirmDeletion,
        body: l.confirmDeleteInvoice,
      );
      if (!mounted) return;
      if (confirmed) {
        await _db.deleteTransaction(inv.id);
        _refresh();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(l.invoiceDeletedSuccessfully),
            backgroundColor: AppColors.success,
          ));
        }
      }
    }
  }

  Future<void> _showTransactionActions(Transaction t) async {
    final l = AppLocalizations.of(context);
    final action = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _Sheet(
        title: l.transactionActions,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          _SheetOption(
            icon: Icons.edit_rounded,
            label: l.edit,
            onTap: () => Navigator.pop(context, 'edit'),
          ),
          _SheetOption(
            icon: Icons.delete_rounded,
            label: l.delete,
            color: AppColors.danger,
            onTap: () => Navigator.pop(context, 'delete'),
          ),
          _SheetOption(
            icon: Icons.close_rounded,
            label: l.cancel,
            onTap: () => Navigator.pop(context),
          ),
        ]),
      ),
    );
    if (!mounted) return;
    if (action == 'edit') {
      await Navigator.push(context,
          _slide(TransactionFormScreen(
              transaction: t, sectionId: widget.section.id)));
      if (mounted) _refresh();
    } else if (action == 'delete') {
      final confirmed = await _confirmDelete(
        title: l.confirmDeletion,
        body: l.confirmDeleteTransaction,
      );
      if (!mounted) return;
      if (confirmed) {
        await _db.deleteTransaction(t.id);
        _refresh();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(l.transactionDeletedSuccessfully),
            backgroundColor: AppColors.success,
          ));
        }
      }
    }
  }

  Future<void> _showReservedActions(ReservedAmount ra) async {
    final l = AppLocalizations.of(context);
    final action = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _Sheet(
        title: l.reservationActions,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          _SheetOption(
            icon: Icons.edit_rounded,
            label: l.edit,
            onTap: () => Navigator.pop(context, 'edit'),
          ),
          _SheetOption(
            icon: Icons.delete_rounded,
            label: l.delete,
            color: AppColors.danger,
            onTap: () => Navigator.pop(context, 'delete'),
          ),
          _SheetOption(
            icon: Icons.close_rounded,
            label: l.cancel,
            onTap: () => Navigator.pop(context),
          ),
        ]),
      ),
    );
    if (!mounted) return;
    if (action == 'edit') {
      await Navigator.push(context,
          _slide(ReservedAmountFormScreen(
              reservedAmount: ra, sectionId: widget.section.id)));
      if (mounted) _refresh();
    } else if (action == 'delete') {
      final confirmed = await _confirmDelete(
        title: l.confirmDeletion,
        body: l.confirmDeleteReservation,
      );
      if (!mounted) return;
      if (confirmed) {
        await _db.deleteReservedAmount(ra.id);
        _refresh();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(l.reservationDeletedSuccessfully),
            backgroundColor: AppColors.success,
          ));
        }
      }
    }
  }

  /// Confirmation sheet — returns true when user confirms, false otherwise.
  Future<bool> _confirmDelete({
    required String title,
    required String body,
  }) async {
    final l      = AppLocalizations.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final result = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _Sheet(
        title: title,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(body,
              style: TextStyle(
                  color:
                      isDark ? AppColors.darkSubtext : AppColors.grey500)),
          const SizedBox(height: AppTokens.sp24),
          Row(children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text(l.cancel),
              ),
            ),
            const SizedBox(width: AppTokens.sp12),
            Expanded(
              child: FilledButton(
                style: FilledButton.styleFrom(
                    backgroundColor: AppColors.danger),
                onPressed: () => Navigator.pop(context, true),
                child: Text(l.delete),
              ),
            ),
          ]),
        ]),
      ),
    );
    return result ?? false;
  }

  Future<void> _reserveInvoice(Transaction inv) async {
    final l    = AppLocalizations.of(context);
    final desc = '${inv.entity} | ${inv.monthRef}';
    if (await _db.existReserve(desc)) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(l.reservationAlreadyExistsForInvoice,
            style: const TextStyle(color: AppColors.dark)),
        backgroundColor: AppColors.white,
      ));
      return;
    }
    await _db.insertReservedAmount(ReservedAmount(
      id: const Uuid().v4(),
      sectionId: widget.section.id,
      description: desc,
      amount: inv.amount,
      createdAt: DateTime.now(),
    ));
    _refresh();
  }

  /// Offers a SnackBar shortcut to reserve an amount that was just created as
  /// a new unpaid invoice.  Skips silently if a reserve with the same
  /// description already exists.
  void _offerAutoReserve({required double amount, required String entity}) {
    if (!mounted) return;
    final l   = AppLocalizations.of(context);
    final cur = NumberFormat.currency(locale: 'pt_PT', symbol: '€');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${l.reserve} ${cur.format(amount)} — $entity?'),
        duration: const Duration(seconds: 6),
        action: SnackBarAction(
          label: l.reserve,
          onPressed: () async {
            if (!mounted) return;
            if (await _db.existReserve(entity)) return;
            await _db.insertReservedAmount(ReservedAmount(
              id: const Uuid().v4(),
              sectionId: widget.section.id,
              description: entity,
              amount: amount,
              createdAt: DateTime.now(),
            ));
            _refresh();
          },
        ),
      ),
    );
  }

  // ── Build ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final l      = AppLocalizations.of(context);

    return PopScope(
      // When the search bar is active, the back gesture should dismiss the
      // keyboard / search focus instead of popping the entire screen.
      canPop: !_searchFocused,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _searchFocused) {
          _searchFocus.unfocus();
          _searchCtrl.clear();
          _filter();
        }
      },
      child: Scaffold(
      backgroundColor:
          isDark ? AppColors.darkBackground : const Color(0xFFF5F5F7),
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: FutureBuilder<_FinancialData>(
          future: _future,
          builder: (ctx, snap) {
            final loading = snap.connectionState == ConnectionState.waiting;
            final data    = snap.data;

            return CustomScrollView(
              controller: _scrollCtrl,
              slivers: [
                // ── Collapsible AppBar ─────────────────────────────────────
                SliverAppBar(
                  expandedHeight: _searchFocused ? 0 : 196,
                  pinned: true,
                  floating: false,
                  backgroundColor:
                      isDark ? AppColors.darkSurface : const Color(0xFF1C1C1E),
                  foregroundColor: AppColors.white,
                  elevation: 0,
                  title: Text(
                    widget.section.name,
                    style: const TextStyle(
                      color: AppColors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 18,
                      letterSpacing: -0.3,
                    ),
                  ),
                  actions: [
                    IconButton(
                      icon: const Icon(Icons.analytics_rounded,
                          color: AppColors.white),
                      tooltip: l.financialSummary,
                      onPressed: () => Navigator.push(context,
                          _slide(SummaryScreen(sectionId: widget.section.id))),
                    ),
                  ],
                  flexibleSpace: FlexibleSpaceBar(
                    collapseMode: CollapseMode.pin,
                    background: loading || data == null
                        ? const _FinancialHeaderSkeleton()
                        : _FinancialHeader(data: data, l: l),
                  ),
                ),

                // ── Search ─────────────────────────────────────────────────
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(
                        AppTokens.sp16, AppTokens.sp12,
                        AppTokens.sp16, AppTokens.sp4),
                    child: _SearchBar(
                      controller: _searchCtrl,
                      focusNode: _searchFocus,
                      hint: l.searchTransactions,
                      isDark: isDark,
                      onClear: () { _searchCtrl.clear(); _filter(); },
                    ),
                  ),
                ),

                // ── Invoices ───────────────────────────────────────────────
                if (!_searchFocused) ...[
                  SliverToBoxAdapter(
                    child: _InvoicesSection(
                      loading: loading,
                      invoices: data?.invoices ?? [],
                      onTap: _showInvoiceDetails,
                      onLongPress: _showInvoiceOptions,
                      dueDateLabel: _dueDateLabel,
                      l: l,
                      isDark: isDark,
                    ),
                  ),

                  // ── Reserved amounts ───────────────────────────────────
                  SliverToBoxAdapter(
                    child: _ReservedSection(
                      loading: loading,
                      items: data?.reservedAmounts ?? [],
                      expanded: _reservedExpanded,
                      onToggle: () => setState(
                          () => _reservedExpanded = !_reservedExpanded),
                      onAdd: () => Navigator.push(
                              context,
                              _slide(ReservedAmountFormScreen(
                                sectionId: widget.section.id,
                                availableBalance: data?.availableAmount,
                              )))
                          .then((_) => _refresh()),
                      onTap: _showReservedActions,
                      l: l,
                      isDark: isDark,
                    ),
                  ),
                ],

                // ── Transactions label ─────────────────────────────────────
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(
                        AppTokens.sp20, AppTokens.sp16,
                        AppTokens.sp20, AppTokens.sp8),
                    child: Text(
                      l.transactions.toUpperCase(),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.9,
                        color: isDark
                            ? AppColors.darkSubtext
                            : AppColors.grey500,
                      ),
                    ),
                  ),
                ),

                // ── Transaction list ───────────────────────────────────────
                if (loading)
                  const SliverToBoxAdapter(
                      child: TransactionListSkeleton(count: 7))
                else if (_filtered.isEmpty)
                  SliverToBoxAdapter(
                    child: EmptyState(
                      icon: Icons.receipt_long_rounded,
                      title: _searchCtrl.text.isNotEmpty
                          ? l.noTransactionsToDisplay
                          : l.noTransactionRegistered,
                      subtitle: _searchCtrl.text.isEmpty
                          ? l.addTransactionsToViewSummary
                          : null,
                    ),
                  )
                else
                  SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (_, i) {
                        // Trailing slot: load-more indicator (only in browse mode).
                        if (i == _filtered.length) {
                          if (_isLoadingMore) {
                            return const Padding(
                              padding: EdgeInsets.symmetric(vertical: 20),
                              child: Center(
                                  child: CircularProgressIndicator.adaptive()),
                            );
                          }
                          return const SizedBox.shrink();
                        }
                        final t = _filtered[i];
                        return TransactionListTile(
                          transaction: t,
                          onTap: () => Navigator.push(
                                  ctx,
                                  _slide(TransactionDetailScreen(
                                      transaction: t,
                                      sectionId: widget.section.id)))
                              .then((_) => _refresh()),
                          onLongPress: () => _showTransactionActions(t),
                          onDelete: _refresh,
                        );
                      },
                      childCount: _filtered.length + 1,
                    ),
                  ),

                // ── FAB clearance ──────────────────────────────────────────
                const SliverToBoxAdapter(child: SizedBox(height: 100)),
              ],
            );
          },
        ),
      ),
      floatingActionButton: ScaleTransition(
        scale: _fabScale,
        child: FloatingActionButton.extended(
          onPressed: () {
            HapticFeedback.lightImpact();
            Navigator.push(
                    context,
                    _slide(TransactionFormScreen(
                        sectionId: widget.section.id)))
                .then((result) {
              _refresh();
              if (result is Map && result['type'] == 'invoice') {
                _offerAutoReserve(
                  amount: result['amount'] as double,
                  entity: result['entity'] as String,
                );
              }
            });
          },
          icon: const Icon(Icons.add_rounded),
          label: Text(l.addTransaction),
          backgroundColor:
              isDark ? AppColors.info : const Color(0xFF1C1C1E),
          foregroundColor: AppColors.white,
        ),
      ),
    ),   // closes Scaffold
    );   // closes PopScope
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// Sub-widgets
// ══════════════════════════════════════════════════════════════════════════════

// ── Financial header (inside SliverAppBar flexibleSpace) ─────────────────────
// Revolut-inspired design: large balance, available/reserved progress bar,
// metric pills at the bottom.
class _FinancialHeader extends StatelessWidget {
  final _FinancialData data;
  final AppLocalizations l;
  const _FinancialHeader({required this.data, required this.l});

  @override
  Widget build(BuildContext context) {
    final cur       = NumberFormat.currency(locale: 'pt_PT', symbol: '€');
    final compact   = NumberFormat.compactCurrency(locale: 'pt_PT', symbol: '€');
    final available = (data.balance - data.totalReserved).clamp(0.0, double.infinity);
    final totalAbs  = data.balance.abs().clamp(1.0, double.infinity);
    final availRatio = (available / totalAbs).clamp(0.0, 1.0);

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1A1A2E), Color(0xFF16213E), Color(0xFF0F3460)],
        ),
      ),
      padding: const EdgeInsets.fromLTRB(
          AppTokens.sp20, 86, AppTokens.sp20, AppTokens.sp16),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Label ───────────────────────────────────────────────────────────
          Text(
            l.currentBalance,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: Color(0xFF8899AA),
              letterSpacing: 0.6,
            ),
          ),
          const SizedBox(height: 2),

          // ── Big balance ──────────────────────────────────────────────────────
          Text(
            cur.format(data.balance),
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w800,
              color: data.balance >= 0 ? Colors.white : AppColors.dangerLight,
              letterSpacing: -1.0,
              height: 1.1,
            ),
          ),
          const SizedBox(height: AppTokens.sp12),

          // ── Available / Reserved progress bar ────────────────────────────────
          if (data.balance > 0) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(AppTokens.radiusFull),
              child: LinearProgressIndicator(
                value: availRatio,
                minHeight: 4,
                backgroundColor: AppColors.warning.withAlpha(60),
                valueColor:
                    const AlwaysStoppedAnimation<Color>(AppColors.success),
              ),
            ),
            const SizedBox(height: AppTokens.sp10),
          ],

          // ── Metric pills row ─────────────────────────────────────────────────
          Row(children: [
            _MetricPill(
              icon:  Icons.wallet_rounded,
              label: l.availableAmount,
              value: compact.format(available),
              color: available > 0 ? AppColors.success : AppColors.danger,
            ),
            const SizedBox(width: AppTokens.sp8),
            if (data.totalReserved > 0)
              _MetricPill(
                icon:  Icons.savings_rounded,
                label: l.totalReserved,
                value: compact.format(data.totalReserved),
                color: AppColors.warning,
              ),
            const SizedBox(width: AppTokens.sp8),
            if (data.dailyLimit > 0)
              _MetricPill(
                icon:  Icons.calendar_today_rounded,
                label: '${l.dailyLimit} / ${data.remainingDays}d',
                value: compact.format(data.dailyLimit),
                color: AppColors.info,
              ),
          ]),
        ],
      ),
    );
  }
}

class _MetricPill extends StatelessWidget {
  final IconData icon;
  final String   label;
  final String   value;
  final Color    color;

  const _MetricPill({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(14),
        borderRadius: BorderRadius.circular(AppTokens.radius8),
        border: Border.all(color: Colors.white.withAlpha(20)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 11, color: color),
        const SizedBox(width: 4),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: color,
              height: 1.1,
            ),
          ),
          Text(
            label,
            style: const TextStyle(
              fontSize: 8,
              color: Color(0xFF8899AA),
              height: 1.1,
            ),
          ),
        ]),
      ]),
    );
  }
}

// ── Financial header skeleton ──────────────────────────────────────────────────
class _FinancialHeaderSkeleton extends StatelessWidget {
  const _FinancialHeaderSkeleton();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1A1A2E), Color(0xFF16213E), Color(0xFF0F3460)],
        ),
      ),
      padding: const EdgeInsets.fromLTRB(
          AppTokens.sp20, 86, AppTokens.sp20, AppTokens.sp16),
      child: const Column(
        mainAxisAlignment: MainAxisAlignment.end,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SkeletonBox(width: 90, height: 10, borderRadius: AppTokens.radius4),
          SizedBox(height: 4),
          SkeletonBox(width: 180, height: 30, borderRadius: AppTokens.radius8),
          SizedBox(height: AppTokens.sp12),
          SkeletonBox(width: double.infinity, height: 4, borderRadius: AppTokens.radiusFull),
          SizedBox(height: AppTokens.sp10),
          Row(children: [
            SkeletonBox(width: 80, height: 32, borderRadius: AppTokens.radius8),
            SizedBox(width: 8),
            SkeletonBox(width: 80, height: 32, borderRadius: AppTokens.radius8),
            SizedBox(width: 8),
            SkeletonBox(width: 80, height: 32, borderRadius: AppTokens.radius8),
          ]),
        ],
      ),
    );
  }
}

// ── Search bar ────────────────────────────────────────────────────────────────
class _SearchBar extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final String hint;
  final bool isDark;
  final VoidCallback onClear;

  const _SearchBar({
    required this.controller,
    required this.focusNode,
    required this.hint,
    required this.isDark,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      focusNode: focusNode,
      style: TextStyle(
          color: isDark ? AppColors.darkText : AppColors.dark,
          fontSize: 15),
      decoration: InputDecoration(
        hintText: hint,
        prefixIcon: Icon(Icons.search_rounded,
            color: isDark ? AppColors.darkSubtext : AppColors.grey400,
            size: 20),
        suffixIcon: controller.text.isNotEmpty
            ? IconButton(
                icon: Icon(Icons.clear_rounded,
                    color: isDark ? AppColors.darkSubtext : AppColors.grey400,
                    size: 20),
                onPressed: onClear,
              )
            : null,
        filled: true,
        fillColor: isDark ? AppColors.darkCard : AppColors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppTokens.radius12),
          borderSide: BorderSide(
              color: isDark ? AppColors.darkBorder : AppColors.grey100),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppTokens.radius12),
          borderSide: BorderSide(
              color: isDark ? AppColors.darkBorder : AppColors.grey100),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppTokens.radius12),
          borderSide:
              const BorderSide(color: AppColors.primary, width: 1.5),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: AppTokens.sp16, vertical: 12),
      ),
    );
  }
}

// ── Invoices carousel section ─────────────────────────────────────────────────
class _InvoicesSection extends StatelessWidget {
  final bool loading;
  final List<Transaction> invoices;
  final void Function(Transaction) onTap;
  final void Function(Transaction) onLongPress;
  final String Function(DateTime) dueDateLabel;
  final AppLocalizations l;
  final bool isDark;

  const _InvoicesSection({
    required this.loading,
    required this.invoices,
    required this.onTap,
    required this.onLongPress,
    required this.dueDateLabel,
    required this.l,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
              AppTokens.sp20, AppTokens.sp16, AppTokens.sp20, AppTokens.sp8),
          child: Text(
            l.transactionInvoices.toUpperCase(),
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.9,
              color: isDark ? AppColors.darkSubtext : AppColors.grey500,
            ),
          ),
        ),
        SizedBox(
          height: 130,
          child: loading
              ? ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(
                      horizontal: AppTokens.sp16),
                  itemCount: 4,
                  separatorBuilder: (_, __) =>
                      const SizedBox(width: AppTokens.sp10),
                  itemBuilder: (_, __) => const SkeletonBox(
                      width: 140, height: 120,
                      borderRadius: AppTokens.radius16),
                )
              : invoices.isEmpty
                  ? Center(
                      child: EmptyStateInline(
                        icon: Icons.receipt_outlined,
                        message: l.noInvoiceRegistered,
                      ),
                    )
                  : ListView.separated(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(
                          horizontal: AppTokens.sp16),
                      itemCount: invoices.length,
                      separatorBuilder: (_, __) =>
                          const SizedBox(width: AppTokens.sp10),
                      itemBuilder: (_, i) => _InvoiceCard(
                        invoice: invoices[i],
                        isDark: isDark,
                        onTap: () => onTap(invoices[i]),
                        onLongPress: () => onLongPress(invoices[i]),
                        dueDateLabel: dueDateLabel,
                        l: l,
                      ),
                    ),
        ),
      ],
    );
  }
}

// ── Single invoice card ───────────────────────────────────────────────────────
class _InvoiceCard extends StatelessWidget {
  final Transaction invoice;
  final bool isDark;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final String Function(DateTime) dueDateLabel;
  final AppLocalizations l;

  const _InvoiceCard({
    required this.invoice,
    required this.isDark,
    required this.onTap,
    required this.onLongPress,
    required this.dueDateLabel,
    required this.l,
  });

  @override
  Widget build(BuildContext context) {
    final urgency = _urgencyOf(invoice);
    final color   = _urgencyColor(urgency);
    final cur     = NumberFormat.currency(locale: 'pt_PT', symbol: '€');

    return GestureDetector(
      onTap: () { HapticFeedback.lightImpact(); onTap(); },
      onLongPress: () { HapticFeedback.mediumImpact(); onLongPress(); },
      child: Container(
        width: 148,
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkCard : AppColors.white,
          borderRadius: BorderRadius.circular(AppTokens.radius16),
          border: Border.all(color: color.withAlpha(isDark ? 90 : 120), width: 1.5),
          boxShadow: isDark ? null : AppTokens.shadowSm,
        ),
        padding: const EdgeInsets.all(AppTokens.sp12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Container(
                padding: const EdgeInsets.all(5),
                decoration: BoxDecoration(
                  color: color.withAlpha(isDark ? 40 : 25),
                  shape: BoxShape.circle,
                ),
                child: Icon(_urgencyIcon(urgency), size: 13, color: color),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  invoice.entity.isNotEmpty
                      ? invoice.entity
                      : l.unknownEntity,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: isDark ? AppColors.darkText : AppColors.dark,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ]),
            const SizedBox(height: AppTokens.sp6),
            Text(
              cur.format(invoice.amount),
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: color,
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(height: AppTokens.sp4),
            if (invoice.monthRef != null && invoice.monthRef!.isNotEmpty)
              Text(
                invoice.monthRef!,
                style: TextStyle(
                  fontSize: 10,
                  color: isDark ? AppColors.darkSubtext : AppColors.grey500,
                ),
              ),
            const Spacer(),
            Text(
              invoice.dueDate != null
                  ? dueDateLabel(invoice.dueDate!)
                  : l.deadlineNotDefined,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w500,
                color: color,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

// ── Reserved amounts section ──────────────────────────────────────────────────
class _ReservedSection extends StatelessWidget {
  final bool loading;
  final List<ReservedAmount> items;
  final bool expanded;
  final VoidCallback onToggle;
  final VoidCallback onAdd;
  final void Function(ReservedAmount) onTap;
  final AppLocalizations l;
  final bool isDark;

  const _ReservedSection({
    required this.loading,
    required this.items,
    required this.expanded,
    required this.onToggle,
    required this.onAdd,
    required this.onTap,
    required this.l,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(
          AppTokens.sp16, AppTokens.sp8, AppTokens.sp16, 0),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : AppColors.white,
        borderRadius: BorderRadius.circular(AppTokens.radius16),
        border: Border.all(
            color: isDark ? AppColors.darkBorder : AppColors.grey100),
        boxShadow: isDark ? null : AppTokens.shadowSm,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header row
          InkWell(
            onTap: onToggle,
            borderRadius: BorderRadius.circular(AppTokens.radius16),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: AppTokens.sp16, vertical: AppTokens.sp12),
              child: Row(children: [
                Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color: AppColors.info.withAlpha(isDark ? 40 : 20),
                    borderRadius:
                        BorderRadius.circular(AppTokens.radius8),
                  ),
                  child: const Icon(Icons.savings_rounded,
                      size: 16, color: AppColors.info),
                ),
                const SizedBox(width: AppTokens.sp12),
                Expanded(
                  child: Text(l.amountReservations,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: isDark
                            ? AppColors.darkText
                            : AppColors.dark,
                      )),
                ),
                if (!loading)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.info.withAlpha(isDark ? 40 : 20),
                      borderRadius:
                          BorderRadius.circular(AppTokens.radiusFull),
                    ),
                    child: Text('${items.length}',
                        style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppColors.info)),
                  ),
                const SizedBox(width: AppTokens.sp4),
                IconButton(
                  icon: Icon(
                    expanded
                        ? Icons.expand_less_rounded
                        : Icons.expand_more_rounded,
                    color:
                        isDark ? AppColors.darkSubtext : AppColors.grey500,
                  ),
                  visualDensity: VisualDensity.compact,
                  onPressed: onToggle,
                ),
                IconButton(
                  icon: const Icon(Icons.add_circle_outline_rounded,
                      color: AppColors.success),
                  visualDensity: VisualDensity.compact,
                  onPressed: onAdd,
                ),
              ]),
            ),
          ),

          // Expandable list
          AnimatedSize(
            duration: AppTokens.normal,
            curve: Curves.easeInOut,
            child: expanded
                ? SizedBox(
                    height: 120,
                    child: loading
                        ? ListView.separated(
                            scrollDirection: Axis.horizontal,
                            padding: const EdgeInsets.symmetric(
                                horizontal: AppTokens.sp12,
                                vertical: AppTokens.sp8),
                            itemCount: 3,
                            separatorBuilder: (_, __) =>
                                const SizedBox(width: AppTokens.sp8),
                            itemBuilder: (_, __) => const SkeletonBox(
                                width: 150, height: 88,
                                borderRadius: AppTokens.radius12),
                          )
                        : items.isEmpty
                            ? Center(
                                child: EmptyStateInline(
                                  icon: Icons.savings_outlined,
                                  message: l.noReservationRegistered,
                                ),
                              )
                            : ListView.separated(
                                scrollDirection: Axis.horizontal,
                                padding: const EdgeInsets.fromLTRB(
                                    AppTokens.sp12, AppTokens.sp4,
                                    AppTokens.sp12, AppTokens.sp12),
                                itemCount: items.length,
                                separatorBuilder: (_, __) =>
                                    const SizedBox(width: AppTokens.sp8),
                                itemBuilder: (_, i) =>
                                    _ReservedCard(
                                      item: items[i],
                                      isDark: isDark,
                                      onTap: () => onTap(items[i]),
                                    ),
                              ),
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }
}

// ── Single reserved-amount card ───────────────────────────────────────────────
class _ReservedCard extends StatelessWidget {
  final ReservedAmount item;
  final bool isDark;
  final VoidCallback onTap;

  const _ReservedCard({
    required this.item,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cur = NumberFormat.currency(locale: 'pt_PT', symbol: '€');
    return GestureDetector(
      onTap: () { HapticFeedback.lightImpact(); onTap(); },
      child: Container(
        width: 158,
        decoration: BoxDecoration(
          color: isDark
              ? AppColors.darkBackground
              : const Color(0xFFF5F5F7),
          borderRadius: BorderRadius.circular(AppTokens.radius12),
          border: Border.all(
              color: isDark ? AppColors.darkBorder : AppColors.grey100),
        ),
        padding: const EdgeInsets.all(AppTokens.sp10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Icon(Icons.savings_rounded,
                    size: 14, color: AppColors.info),
                Text(
                  cur.format(item.amount),
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.info,
                    letterSpacing: -0.2,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppTokens.sp6),
            Text(
              item.description,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: isDark ? AppColors.darkText : AppColors.dark,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: AppTokens.sp4),
            Row(children: [
              Icon(Icons.calendar_today_rounded,
                  size: 9,
                  color:
                      isDark ? AppColors.darkSubtext : AppColors.grey400),
              const SizedBox(width: 3),
              Text(
                DateFormat('dd/MM/yy').format(item.createdAt),
                style: TextStyle(
                  fontSize: 9,
                  color: isDark
                      ? AppColors.darkSubtext
                      : AppColors.grey500,
                ),
              ),
            ]),
            const SizedBox(height: AppTokens.sp4),
            Container(
              height: 2,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                    colors: [AppColors.info, AppColors.success]),
                borderRadius: BorderRadius.circular(1),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Generic bottom sheet wrapper ──────────────────────────────────────────────
class _Sheet extends StatelessWidget {
  final String title;
  final Widget child;
  const _Sheet({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return SafeArea(
      child: Container(
        margin: const EdgeInsets.all(AppTokens.sp12),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkCard : AppColors.white,
          borderRadius: BorderRadius.circular(AppTokens.radius24),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Drag handle
            Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.only(top: AppTokens.sp12),
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkBorder : AppColors.grey200,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            // Title
            Padding(
              padding: const EdgeInsets.fromLTRB(
                  AppTokens.sp20, AppTokens.sp16,
                  AppTokens.sp20, AppTokens.sp4),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(title,
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: isDark ? AppColors.darkText : AppColors.dark,
                      letterSpacing: -0.3,
                    )),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                  AppTokens.sp20, AppTokens.sp8,
                  AppTokens.sp20, AppTokens.sp20),
              child: child,
            ),
          ],
        ),
      ),
    );
  }
}

// ── Sheet option row ──────────────────────────────────────────────────────────
class _SheetOption extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? color;

  const _SheetOption({
    required this.icon,
    required this.label,
    required this.onTap,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final isDark   = Theme.of(context).brightness == Brightness.dark;
    final fg       = color ?? (isDark ? AppColors.darkText : AppColors.dark);

    return InkWell(
      onTap: () { HapticFeedback.lightImpact(); onTap(); },
      borderRadius: BorderRadius.circular(AppTokens.radius12),
      child: Padding(
        padding: const EdgeInsets.symmetric(
            vertical: AppTokens.sp14, horizontal: AppTokens.sp4),
        child: Row(children: [
          Icon(icon, size: 20, color: fg),
          const SizedBox(width: AppTokens.sp16),
          Text(label,
              style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: fg)),
        ]),
      ),
    );
  }
}

// ── Detail row (invoice details sheet) ───────────────────────────────────────
class _DetailRow extends StatelessWidget {
  final String label;
  final String value;
  const _DetailRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppTokens.sp6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: isDark ? AppColors.darkSubtext : AppColors.grey500,
                )),
          ),
          Expanded(
            child: Text(value,
                style: TextStyle(
                  fontSize: 13,
                  color: isDark ? AppColors.darkText : AppColors.dark,
                )),
          ),
        ],
      ),
    );
  }
}
