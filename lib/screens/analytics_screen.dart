/// AnalyticsScreen — global cross-section financial dashboard.
///
/// Shows: 6-month income/expense bar chart, section balance breakdown,
/// invoice pipeline status, and top entities by volume.
library;

import 'dart:math' as math;
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../l10n/app_localizations.dart';
import '../models/section.dart';
import '../providers/app_data_provider.dart';
import '../services/database_service.dart';
import '../theme/app_tokens.dart';
import '../theme/colors.dart';
import '../widgets/skeleton_loader.dart';

// ── Data class ────────────────────────────────────────────────────────────────
class _AnalyticsData {
  final List<_MonthBar>     monthBars;
  final List<_SectionStat>  sectionStats;
  final int    invoicePending;
  final int    invoiceOverdue;
  final double invoicePendingAmount;
  final List<_EntityStat>   topEntities;
  final double totalIncome;
  final double totalExpense;

  const _AnalyticsData({
    required this.monthBars,
    required this.sectionStats,
    required this.invoicePending,
    required this.invoiceOverdue,
    required this.invoicePendingAmount,
    required this.topEntities,
    required this.totalIncome,
    required this.totalExpense,
  });
}

class _MonthBar {
  final String label;  // 'Jan', 'Fev', …
  final double income;
  final double expense;
  const _MonthBar({required this.label, required this.income, required this.expense});
}

class _SectionStat {
  final Section section;
  final double  balance;
  const _SectionStat({required this.section, required this.balance});
}

class _EntityStat {
  final String entity;
  final double amount;
  final bool   isCredit;
  const _EntityStat({required this.entity, required this.amount, required this.isCredit});
}

// ─────────────────────────────────────────────────────────────────────────────
class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  final DatabaseService _db = DatabaseService();
  late Future<_AnalyticsData> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<_AnalyticsData> _load() async {
    final sections = context.read<AppDataProvider>().sections;

    final monthlyFut  = _db.getMonthlyStats(months: 6);
    final invoiceFut  = _db.getGlobalInvoiceStats();
    final entitiesFut = _db.getTopEntities(limit: 5);

    // Section stats in parallel.
    final sectionStatsFut = Future.wait(
      sections.map((s) => _db.getSectionStats(s.id)),
    );

    final monthly      = await monthlyFut;
    final invoiceStats = await invoiceFut;
    final entities     = await entitiesFut;
    final rawStats     = await sectionStatsFut;

    // Build month bars — fill missing months with zero.
    final now        = DateTime.now();
    final monthBars  = <_MonthBar>[];
    double totalIncome  = 0;
    double totalExpense = 0;

    for (var i = 5; i >= 0; i--) {
      final dt    = DateTime(now.year, now.month - i, 1);
      final key   = DateFormat('yyyy-MM').format(dt);
      final label = DateFormat('MMM', 'pt').format(dt);
      final row   = monthly.firstWhere(
        (r) => r['month'] == key,
        orElse: () => {'month': key, 'income': 0.0, 'expense': 0.0},
      );
      final inc = (row['income'] as num).toDouble();
      final exp = (row['expense'] as num).toDouble();
      monthBars.add(_MonthBar(label: label, income: inc, expense: exp));
      totalIncome  += inc;
      totalExpense += exp;
    }

    final sectionStats = List.generate(sections.length, (i) => _SectionStat(
      section: sections[i],
      balance: rawStats[i].balance,
    ))..sort((a, b) => b.balance.compareTo(a.balance));

    return _AnalyticsData(
      monthBars:            monthBars,
      sectionStats:         sectionStats,
      invoicePending:       invoiceStats.pending,
      invoiceOverdue:       invoiceStats.overdue,
      invoicePendingAmount: invoiceStats.pendingAmount,
      topEntities:          entities.map((e) => _EntityStat(
        entity:   e.entity,
        amount:   e.amount,
        isCredit: e.isCredit,
      )).toList(),
      totalIncome:  totalIncome,
      totalExpense: totalExpense,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final loc    = AppLocalizations.of(context);
    final theme  = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(loc.analytics, style: theme.textTheme.titleLarge),
        elevation: 0,
      ),
      body: FutureBuilder<_AnalyticsData>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return _buildSkeleton();
          }
          if (snap.hasError || snap.data == null) {
            return Center(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.bar_chart_rounded, size: 56,
                    color: isDark ? AppColors.darkSubtext : AppColors.grey300),
                const SizedBox(height: 12),
                Text(loc.errorLoadingSections,
                    style: TextStyle(
                        color: isDark ? AppColors.darkSubtext : AppColors.grey500)),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: () => setState(() => _future = _load()),
                  child: Text(loc.tryAgain),
                ),
              ]),
            );
          }

          final data = snap.data!;
          return RefreshIndicator(
            onRefresh: () async => setState(() => _future = _load()),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(
                AppTokens.sp16, AppTokens.sp8, AppTokens.sp16, 40),
              children: [
                // ── Summary pills ─────────────────────────────────────────────
                _SummaryRow(data: data, isDark: isDark),
                const SizedBox(height: AppTokens.sp20),

                // ── Monthly bar chart ─────────────────────────────────────────
                _SectionCard(
                  title: loc.monthlyOverview,
                  icon: Icons.bar_chart_rounded,
                  isDark: isDark,
                  child: _MonthlyBarChart(bars: data.monthBars, isDark: isDark),
                ),
                const SizedBox(height: AppTokens.sp16),

                // ── Invoice pipeline ──────────────────────────────────────────
                if (data.invoicePending > 0) ...[
                  _InvoicePipeline(data: data, isDark: isDark, loc: loc),
                  const SizedBox(height: AppTokens.sp16),
                ],

                // ── Section breakdown ─────────────────────────────────────────
                if (data.sectionStats.isNotEmpty) ...[
                  _SectionCard(
                    title: loc.sectionsCreated,
                    icon: Icons.grid_view_rounded,
                    isDark: isDark,
                    child: _SectionBreakdown(
                      stats: data.sectionStats,
                      isDark: isDark,
                    ),
                  ),
                  const SizedBox(height: AppTokens.sp16),
                ],

                // ── Top entities ──────────────────────────────────────────────
                if (data.topEntities.isNotEmpty) ...[
                  _SectionCard(
                    title: loc.topEntities,
                    icon: Icons.people_rounded,
                    isDark: isDark,
                    child: _TopEntitiesList(
                      entities: data.topEntities,
                      isDark: isDark,
                    ),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildSkeleton() {
    return ListView(
      padding: const EdgeInsets.all(AppTokens.sp16),
      children: [
        const SkeletonBox(width: double.infinity, height: 80, borderRadius: 16),
        const SizedBox(height: 16),
        const SkeletonBox(width: double.infinity, height: 220, borderRadius: 16),
        const SizedBox(height: 16),
        const SkeletonBox(width: double.infinity, height: 120, borderRadius: 16),
        const SizedBox(height: 16),
        const SkeletonBox(width: double.infinity, height: 200, borderRadius: 16),
      ],
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// Summary row
// ══════════════════════════════════════════════════════════════════════════════
class _SummaryRow extends StatelessWidget {
  final _AnalyticsData data;
  final bool isDark;
  const _SummaryRow({required this.data, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final cur = NumberFormat.currency(locale: 'pt_PT', symbol: '€');
    final balance = data.totalIncome - data.totalExpense;
    return Row(children: [
      Expanded(child: _SummaryPill(
        label: 'Entradas (6M)',
        value: cur.format(data.totalIncome),
        color: AppColors.success,
        icon:  Icons.trending_up_rounded,
        isDark: isDark,
      )),
      const SizedBox(width: AppTokens.sp10),
      Expanded(child: _SummaryPill(
        label: 'Saídas (6M)',
        value: cur.format(data.totalExpense),
        color: AppColors.danger,
        icon:  Icons.trending_down_rounded,
        isDark: isDark,
      )),
      const SizedBox(width: AppTokens.sp10),
      Expanded(child: _SummaryPill(
        label: 'Resultado',
        value: cur.format(balance),
        color: balance >= 0 ? AppColors.success : AppColors.danger,
        icon:  Icons.account_balance_wallet_rounded,
        isDark: isDark,
      )),
    ]);
  }
}

class _SummaryPill extends StatelessWidget {
  final String label;
  final String value;
  final Color  color;
  final IconData icon;
  final bool isDark;
  const _SummaryPill({
    required this.label,
    required this.value,
    required this.color,
    required this.icon,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppTokens.sp12),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : AppColors.white,
        borderRadius: BorderRadius.circular(AppTokens.radius16),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.grey100,
        ),
        boxShadow: isDark ? null : AppTokens.shadowSm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(height: AppTokens.sp6),
          Text(
            value,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: isDark ? AppColors.darkText : AppColors.dark,
              letterSpacing: -0.3,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              color: isDark ? AppColors.darkSubtext : AppColors.grey500,
            ),
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// Reusable section card
// ══════════════════════════════════════════════════════════════════════════════
class _SectionCard extends StatelessWidget {
  final String   title;
  final IconData icon;
  final Widget   child;
  final bool     isDark;
  const _SectionCard({
    required this.title,
    required this.icon,
    required this.child,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppTokens.sp16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : AppColors.white,
        borderRadius: BorderRadius.circular(AppTokens.radius20),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.grey100,
        ),
        boxShadow: isDark ? null : AppTokens.shadowSm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: AppColors.primary.withAlpha(isDark ? 40 : 20),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, size: 16, color: AppColors.primary),
            ),
            const SizedBox(width: AppTokens.sp8),
            Text(
              title,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: isDark ? AppColors.darkText : AppColors.dark,
                letterSpacing: -0.2,
              ),
            ),
          ]),
          const SizedBox(height: AppTokens.sp16),
          child,
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// Monthly bar chart
// ══════════════════════════════════════════════════════════════════════════════
class _MonthlyBarChart extends StatelessWidget {
  final List<_MonthBar> bars;
  final bool isDark;
  const _MonthlyBarChart({required this.bars, required this.isDark});

  @override
  Widget build(BuildContext context) {
    if (bars.every((b) => b.income == 0 && b.expense == 0)) {
      return SizedBox(
        height: 160,
        child: Center(
          child: Text(
            'Sem dados no período',
            style: TextStyle(
              color: isDark ? AppColors.darkSubtext : AppColors.grey400,
              fontSize: 13,
            ),
          ),
        ),
      );
    }

    final maxVal = bars.fold<double>(0, (m, b) => math.max(m, math.max(b.income, b.expense)));
    final currency = NumberFormat.compactCurrency(locale: 'pt_PT', symbol: '€');

    return SizedBox(
      height: 180,
      child: BarChart(
        BarChartData(
          alignment: BarChartAlignment.spaceAround,
          maxY: maxVal * 1.25,
          minY: 0,
          barTouchData: BarTouchData(
            enabled: true,
            touchTooltipData: BarTouchTooltipData(
              getTooltipColor: (_) => isDark ? AppColors.darkSurface : Colors.white,
              getTooltipItem: (group, groupIndex, rod, rodIndex) {
                final bar   = bars[group.x];
                final label = rodIndex == 0 ? '▲ ${currency.format(bar.income)}' : '▼ ${currency.format(bar.expense)}';
                return BarTooltipItem(
                  label,
                  TextStyle(
                    color: rodIndex == 0 ? AppColors.success : AppColors.danger,
                    fontWeight: FontWeight.w600,
                    fontSize: 11,
                  ),
                );
              },
            ),
          ),
          titlesData: FlTitlesData(
            show: true,
            topTitles:   const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (val, meta) {
                  final i = val.toInt();
                  if (i < 0 || i >= bars.length) return const SizedBox.shrink();
                  return Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      bars[i].label,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                        color: isDark ? AppColors.darkSubtext : AppColors.grey500,
                      ),
                    ),
                  );
                },
                reservedSize: 24,
              ),
            ),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 44,
                getTitlesWidget: (val, meta) {
                  if (val == 0) return const SizedBox.shrink();
                  return Text(
                    currency.format(val),
                    style: TextStyle(
                      fontSize: 9,
                      color: isDark ? AppColors.darkSubtext : AppColors.grey400,
                    ),
                  );
                },
              ),
            ),
          ),
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: maxVal > 0 ? maxVal / 3 : 100,
            getDrawingHorizontalLine: (_) => FlLine(
              color: (isDark ? AppColors.darkBorder : AppColors.grey100).withAlpha(120),
              strokeWidth: 1,
            ),
          ),
          borderData: FlBorderData(show: false),
          barGroups: List.generate(bars.length, (i) {
            final b = bars[i];
            return BarChartGroupData(
              x: i,
              barRods: [
                BarChartRodData(
                  toY: b.income,
                  color: AppColors.success.withAlpha(200),
                  width: 10,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                ),
                BarChartRodData(
                  toY: b.expense,
                  color: AppColors.danger.withAlpha(200),
                  width: 10,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                ),
              ],
              barsSpace: 3,
            );
          }),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// Invoice pipeline
// ══════════════════════════════════════════════════════════════════════════════
class _InvoicePipeline extends StatelessWidget {
  final _AnalyticsData data;
  final bool isDark;
  final AppLocalizations loc;
  const _InvoicePipeline({required this.data, required this.isDark, required this.loc});

  @override
  Widget build(BuildContext context) {
    final cur = NumberFormat.currency(locale: 'pt_PT', symbol: '€');
    return Container(
      padding: const EdgeInsets.all(AppTokens.sp16),
      decoration: BoxDecoration(
        color: AppColors.warning.withAlpha(isDark ? 25 : 18),
        borderRadius: BorderRadius.circular(AppTokens.radius20),
        border: Border.all(color: AppColors.warning.withAlpha(60)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(Icons.receipt_long_rounded, color: AppColors.warning, size: 18),
            const SizedBox(width: AppTokens.sp8),
            Text(
              loc.invoice,
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 14,
                color: AppColors.warning,
              ),
            ),
          ]),
          const SizedBox(height: AppTokens.sp12),
          Row(children: [
            _InvoicePill(
              count: data.invoicePending,
              label: 'Pendentes',
              color: AppColors.warning,
            ),
            const SizedBox(width: AppTokens.sp10),
            if (data.invoiceOverdue > 0)
              _InvoicePill(
                count: data.invoiceOverdue,
                label: 'Vencidas',
                color: AppColors.danger,
              ),
            const Spacer(),
            Text(
              cur.format(data.invoicePendingAmount),
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 15,
                color: AppColors.warning,
              ),
            ),
          ]),
        ],
      ),
    );
  }
}

class _InvoicePill extends StatelessWidget {
  final int count;
  final String label;
  final Color color;
  const _InvoicePill({required this.count, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withAlpha(30),
        borderRadius: BorderRadius.circular(AppTokens.radiusFull),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Text(
          '$count',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: color),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w500),
        ),
      ]),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// Section breakdown
// ══════════════════════════════════════════════════════════════════════════════
class _SectionBreakdown extends StatelessWidget {
  final List<_SectionStat> stats;
  final bool isDark;
  const _SectionBreakdown({required this.stats, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final cur = NumberFormat.currency(locale: 'pt_PT', symbol: '€');
    final maxAbs = stats.fold<double>(
      0, (m, s) => math.max(m, s.balance.abs()),
    );

    return Column(
      children: stats.take(8).map((s) {
        final ratio   = maxAbs > 0 ? s.balance.abs() / maxAbs : 0.0;
        final isPos   = s.balance >= 0;
        final barColor = isPos ? AppColors.success : AppColors.danger;

        return Padding(
          padding: const EdgeInsets.only(bottom: AppTokens.sp12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      s.section.name,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: isDark ? AppColors.darkText : AppColors.dark,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Text(
                    cur.format(s.balance),
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: isPos ? AppColors.success : AppColors.danger,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 5),
              ClipRRect(
                borderRadius: BorderRadius.circular(AppTokens.radiusFull),
                child: LinearProgressIndicator(
                  value: ratio.clamp(0.0, 1.0),
                  minHeight: 5,
                  backgroundColor:
                      isDark ? AppColors.darkBorder : AppColors.grey100,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    barColor.withAlpha(180),
                  ),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// Top entities
// ══════════════════════════════════════════════════════════════════════════════
class _TopEntitiesList extends StatelessWidget {
  final List<_EntityStat> entities;
  final bool isDark;
  const _TopEntitiesList({required this.entities, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final cur   = NumberFormat.currency(locale: 'pt_PT', symbol: '€');
    final maxAmt = entities.fold<double>(0, (m, e) => math.max(m, e.amount));

    return Column(
      children: entities.map((e) {
        final ratio = maxAmt > 0 ? e.amount / maxAmt : 0.0;
        return Padding(
          padding: const EdgeInsets.only(bottom: AppTokens.sp12),
          child: Row(children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: AppColors.info.withAlpha(isDark ? 40 : 20),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Center(
                child: Text(
                  e.entity.isNotEmpty ? e.entity[0].toUpperCase() : '?',
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    color: AppColors.info,
                  ),
                ),
              ),
            ),
            const SizedBox(width: AppTokens.sp12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          e.entity,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: isDark ? AppColors.darkText : AppColors.dark,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        cur.format(e.amount),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: isDark ? AppColors.darkText : AppColors.dark,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(AppTokens.radiusFull),
                    child: LinearProgressIndicator(
                      value: ratio.clamp(0.0, 1.0),
                      minHeight: 4,
                      backgroundColor:
                          isDark ? AppColors.darkBorder : AppColors.grey100,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        AppColors.info.withAlpha(160),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ]),
        );
      }).toList(),
    );
  }
}
