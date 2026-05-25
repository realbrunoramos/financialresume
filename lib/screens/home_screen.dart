import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:intl/intl.dart';
import '../models/section.dart';
import '../services/database_service.dart';
import '../theme/colors.dart';
import '../theme/app_tokens.dart';
import '../l10n/app_localizations.dart';
import '../widgets/skeleton_loader.dart';
import '../widgets/empty_state.dart';
import 'section_screen.dart';
import 'settings_screen.dart';
import 'about_screen.dart';
import 'package:uuid/uuid.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  final DatabaseService _db = DatabaseService();
  final TextEditingController _nameCtrl = TextEditingController();
  late Future<List<Section>> _sectionsFuture;
  late AnimationController _fabAnimCtrl;
  late Animation<double> _fabAnim;

  @override
  void initState() {
    super.initState();
    _sectionsFuture = _db.getAllSections();
    _fabAnimCtrl = AnimationController(
      vsync: this,
      duration: AppTokens.normal,
    );
    _fabAnim = CurvedAnimation(parent: _fabAnimCtrl, curve: AppTokens.easeOut);
    Future.microtask(() => _fabAnimCtrl.forward());
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _fabAnimCtrl.dispose();
    super.dispose();
  }

  void _reload() => setState(() => _sectionsFuture = _db.getAllSections());

  // ── Gradiente por índice ──────────────────────────────────────────────────
  LinearGradient _gradient(int index) {
    final colors = AppColors.sectionGradients[index % AppColors.sectionGradients.length];
    return LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: colors,
    );
  }

  // ── Criar secção ──────────────────────────────────────────────────────────
  Future<void> _createSection() async {
    _nameCtrl.clear();
    final loc = AppLocalizations.of(context);

    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _CreateSectionSheet(controller: _nameCtrl, loc: loc),
    );

    if (confirmed == true && _nameCtrl.text.trim().isNotEmpty) {
      await _db.addSection(Section(
        id: const Uuid().v4(),
        name: _nameCtrl.text.trim(),
        createdAt: DateTime.now(),
      ));
      _reload();
      if (mounted) {
        HapticFeedback.lightImpact();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${_nameCtrl.text.trim()} ${loc.createdSuccessfully}!'),
          ),
        );
      }
    }
  }

  // ── Opções de secção ──────────────────────────────────────────────────────
  Future<void> _showOptions(Section section) async {
    HapticFeedback.mediumImpact();
    final loc = AppLocalizations.of(context);

    final action = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _SectionOptionsSheet(section: section, loc: loc),
    );

    if (!mounted) return;
    if (action == 'rename') _renameSection(section);
    else if (action == 'delete') _deleteSection(section);
  }

  Future<void> _renameSection(Section section) async {
    _nameCtrl.text = section.name;
    final loc = AppLocalizations.of(context);

    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _CreateSectionSheet(
        controller: _nameCtrl,
        loc: loc,
        isRename: true,
      ),
    );

    if (confirmed == true && _nameCtrl.text.trim().isNotEmpty) {
      await _db.updateSection(Section(
        id: section.id,
        name: _nameCtrl.text.trim(),
        createdAt: section.createdAt,
      ));
      _reload();
    }
  }

  Future<void> _deleteSection(Section section) async {
    final loc    = AppLocalizations.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final confirm = await showModalBottomSheet<bool>(
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
              Center(
                child: Container(
                  width: 36, height: 4,
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.darkBorder : AppColors.grey200,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: AppTokens.sp16),
              Row(children: [
                Container(
                  padding: const EdgeInsets.all(AppTokens.sp8),
                  decoration: BoxDecoration(
                    color: AppColors.danger.withAlpha(24),
                    borderRadius: BorderRadius.circular(AppTokens.radius8),
                  ),
                  child: const Icon(Icons.delete_outline_rounded,
                      color: AppColors.danger, size: 20),
                ),
                const SizedBox(width: AppTokens.sp12),
                Expanded(
                  child: Text(
                    loc.deleteSection,
                    style: TextStyle(
                      fontSize: 17, fontWeight: FontWeight.w700,
                      color: isDark ? AppColors.darkText : AppColors.dark,
                    ),
                  ),
                ),
              ]),
              const SizedBox(height: AppTokens.sp12),
              Text(
                '${loc.deleteSectionConfirmation} ${loc.thisActionCannotBeUndone}',
                style: TextStyle(
                  fontSize: 14, height: 1.5,
                  color: isDark ? AppColors.darkSubtext : AppColors.grey500,
                ),
              ),
              const SizedBox(height: AppTokens.sp20),
              Row(children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: Text(loc.cancel),
                  ),
                ),
                const SizedBox(width: AppTokens.sp12),
                Expanded(
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                        backgroundColor: AppColors.danger),
                    onPressed: () => Navigator.pop(context, true),
                    child: Text(loc.delete),
                  ),
                ),
              ]),
            ],
          ),
        ),
      ),
    );

    if (confirm == true) {
      await _db.deleteSection(section.id);
      _reload();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(loc.sectionDeleted)),
        );
      }
    }
  }

  // ── Stats de secção ───────────────────────────────────────────────────────
  Future<_SectionStats> _loadStats(String sectionId) async {
    final s = await _db.getSectionStats(sectionId);
    return _SectionStats(count: s.count, balance: s.balance);
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      // ── AppBar ─────────────────────────────────────────────────────────────
      appBar: AppBar(
        leading: Padding(
          padding: const EdgeInsets.all(AppTokens.sp10),
          child: SvgPicture.asset(
            'assets/images/app_logo.svg',
            colorFilter: ColorFilter.mode(
              isDark ? AppColors.darkText : AppColors.dark,
              BlendMode.srcIn,
            ),
          ),
        ),
        title: Text(
          'Financial Resume',
          style: theme.textTheme.titleLarge,
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline_rounded),
            tooltip: loc.about,
            onPressed: () => Navigator.push(
              context,
              slideRoute(const AboutScreen()),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.settings_rounded),
            tooltip: loc.settings,
            onPressed: () => Navigator.push(
              context,
              slideRoute(const SettingsScreen()),
            ),
          ),
          const SizedBox(width: AppTokens.sp4),
        ],
      ),

      // ── Body ───────────────────────────────────────────────────────────────
      body: FutureBuilder<List<Section>>(
        future: _sectionsFuture,
        builder: (context, snap) {
          // Loading
          if (snap.connectionState == ConnectionState.waiting) {
            return _buildLoadingBody();
          }

          // Erro
          if (snap.hasError) {
            return EmptyState(
              icon: Icons.cloud_off_rounded,
              title: loc.errorLoadingSections,
              actionLabel: loc.tryAgain,
              onAction: _reload,
            );
          }

          final sections = snap.data ?? [];

          // Sem secções
          if (sections.isEmpty) {
            return _buildEmptyBody(loc);
          }

          return _buildSectionGrid(sections, loc, isDark, theme);
        },
      ),

      // ── FAB ────────────────────────────────────────────────────────────────
      floatingActionButton: ScaleTransition(
        scale: _fabAnim,
        child: FloatingActionButton.extended(
          onPressed: _createSection,
          icon: const Icon(Icons.add_rounded),
          label: Text(loc.newSection),
          heroTag: 'home_fab',
        ),
      ),
    );
  }

  // ── Body: loading ─────────────────────────────────────────────────────────
  Widget _buildLoadingBody() {
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(
        AppTokens.sp16, AppTokens.sp16, AppTokens.sp16, 120,
      ),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: AppTokens.sp12,
        mainAxisSpacing: AppTokens.sp12,
        childAspectRatio: 1.1,
      ),
      itemCount: 4,
      itemBuilder: (_, __) => const SectionCardSkeleton(),
    );
  }

  // ── Body: sem secções ─────────────────────────────────────────────────────
  Widget _buildEmptyBody(AppLocalizations loc) {
    return EmptyState(
      icon: Icons.grid_view_rounded,
      title: loc.noSectionsCreated,
      subtitle: loc.tapPlusToCreateFirstSection,
      actionLabel: loc.newSection,
      onAction: _createSection,
      iconColor: AppColors.grey400,
    );
  }

  // ── Body: grid de secções ─────────────────────────────────────────────────
  Widget _buildSectionGrid(
    List<Section> sections,
    AppLocalizations loc,
    bool isDark,
    ThemeData theme,
  ) {
    return CustomScrollView(
      slivers: [
        // Cabeçalho de resumo total (apenas quando há secções)
        SliverToBoxAdapter(
          child: _TotalSummaryHeader(sections: sections, db: _db, isDark: isDark),
        ),

        // Grid de secções
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(
            AppTokens.sp16, AppTokens.sp8, AppTokens.sp16, 120,
          ),
          sliver: SliverGrid(
            delegate: SliverChildBuilderDelegate(
              (ctx, i) => _SectionCard(
                section: sections[i],
                index: i,
                gradient: _gradient(i),
                loadStats: () => _loadStats(sections[i].id),
                onTap: () {
                  HapticFeedback.lightImpact();
                  Navigator.push(
                    context,
                    slideRoute(SectionScreen(section: sections[i])),
                  ).then((_) => _reload());
                },
                onLongPress: () => _showOptions(sections[i]),
                loc: loc,
              ),
              childCount: sections.length,
            ),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: AppTokens.sp12,
              mainAxisSpacing: AppTokens.sp12,
              childAspectRatio: 1.05,
            ),
          ),
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// HEADER DE RESUMO TOTAL
// ═══════════════════════════════════════════════════════════════════════════════
class _TotalSummaryHeader extends StatefulWidget {
  final List<Section> sections;
  final DatabaseService db;
  final bool isDark;

  const _TotalSummaryHeader({
    required this.sections,
    required this.db,
    required this.isDark,
  });

  @override
  State<_TotalSummaryHeader> createState() => _TotalSummaryHeaderState();
}

class _TotalSummaryHeaderState extends State<_TotalSummaryHeader> {
  late Future<double> _totalFuture;

  @override
  void initState() {
    super.initState();
    _totalFuture = widget.db.getTotalBalance();
  }

  @override
  void didUpdateWidget(_TotalSummaryHeader oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Refresh whenever the section list changes (add / delete / rename).
    if (oldWidget.sections != widget.sections) {
      setState(() => _totalFuture = widget.db.getTotalBalance());
    }
  }

  @override
  Widget build(BuildContext context) {
    final currency = NumberFormat.currency(locale: 'pt_PT', symbol: '€');
    final loc = AppLocalizations.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppTokens.sp16, AppTokens.sp16, AppTokens.sp16, AppTokens.sp4,
      ),
      child: Container(
        padding: const EdgeInsets.all(AppTokens.sp20),
        decoration: BoxDecoration(
          gradient: AppColors.primaryGradient,
          borderRadius: BorderRadius.circular(AppTokens.radius20),
          boxShadow: AppTokens.shadowLg,
        ),
        child: FutureBuilder<double>(
          future: _totalFuture,
          builder: (_, snap) {
            final balance = snap.data ?? 0;
            final isPositive = balance >= 0;

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      loc.currentBalance,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        letterSpacing: 0.2,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppTokens.sp8, vertical: AppTokens.sp4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withAlpha(20),
                        borderRadius: BorderRadius.circular(AppTokens.radiusFull),
                      ),
                      child: Text(
                        '${widget.sections.length} ${loc.sectionsCreated}',
                        style: const TextStyle(
                          color: Colors.white70, fontSize: 11,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppTokens.sp8),
                snap.connectionState == ConnectionState.waiting
                    ? const SkeletonBox(width: 160, height: 32,
                        borderRadius: AppTokens.radius8)
                    : Text(
                        currency.format(balance),
                        style: TextStyle(
                          color: isPositive ? Colors.white : AppColors.dangerLight,
                          fontSize: 30,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.8,
                          height: 1.1,
                        ),
                      ),
                const SizedBox(height: AppTokens.sp4),
                Row(
                  children: [
                    Icon(
                      isPositive
                          ? Icons.trending_up_rounded
                          : Icons.trending_down_rounded,
                      size: 14,
                      color: isPositive
                          ? AppColors.successLight
                          : AppColors.dangerLight,
                    ),
                    const SizedBox(width: AppTokens.sp4),
                    Text(
                      isPositive ? loc.positiveBalance : loc.negativeBalance,
                      style: TextStyle(
                        color: isPositive
                            ? AppColors.successLight
                            : AppColors.dangerLight,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// CARD DE SECÇÃO
// ═══════════════════════════════════════════════════════════════════════════════
class _SectionCard extends StatefulWidget {
  final Section section;
  final int index;
  final LinearGradient gradient;
  final Future<_SectionStats> Function() loadStats;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final AppLocalizations loc;

  const _SectionCard({
    required this.section,
    required this.index,
    required this.gradient,
    required this.loadStats,
    required this.onTap,
    required this.onLongPress,
    required this.loc,
  });

  @override
  State<_SectionCard> createState() => _SectionCardState();
}

class _SectionCardState extends State<_SectionCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _pressCtrl;
  late Animation<double> _scaleAnim;
  late Future<_SectionStats> _statsFuture;

  @override
  void initState() {
    super.initState();
    _pressCtrl = AnimationController(
      vsync: this,
      duration: AppTokens.fast,
      lowerBound: 0.0,
      upperBound: 1.0,
    );
    _scaleAnim = Tween<double>(begin: 1.0, end: 0.965).animate(
      CurvedAnimation(parent: _pressCtrl, curve: AppTokens.easeOut),
    );
    _statsFuture = widget.loadStats();
  }

  @override
  void dispose() {
    _pressCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currency = NumberFormat.currency(locale: 'pt_PT', symbol: '€');
    final loc = widget.loc;

    return GestureDetector(
      onTapDown: (_) => _pressCtrl.forward(),
      onTapUp: (_) => _pressCtrl.reverse(),
      onTapCancel: () => _pressCtrl.reverse(),
      onTap: widget.onTap,
      onLongPress: widget.onLongPress,
      child: AnimatedBuilder(
        animation: _scaleAnim,
        builder: (_, child) => Transform.scale(
          scale: _scaleAnim.value,
          child: child,
        ),
        child: Container(
          decoration: BoxDecoration(
            gradient: widget.gradient,
            borderRadius: BorderRadius.circular(AppTokens.radius20),
            boxShadow: AppTokens.shadowMd,
          ),
          padding: const EdgeInsets.all(AppTokens.sp16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Data de criação ──────────────────────────────────────────
              Align(
                alignment: Alignment.topRight,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppTokens.sp6, vertical: AppTokens.sp2,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withAlpha(20),
                    borderRadius: BorderRadius.circular(AppTokens.radiusFull),
                  ),
                  child: Text(
                    DateFormat('dd/MM/yy').format(widget.section.createdAt),
                    style: const TextStyle(
                      fontSize: 9, color: Colors.white70,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),

              // ── Nome da secção ───────────────────────────────────────────
              const Spacer(),
              Text(
                widget.section.name,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                  height: 1.2,
                  letterSpacing: -0.2,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: AppTokens.sp8),

              // ── Stats ────────────────────────────────────────────────────
              FutureBuilder<_SectionStats>(
                future: _statsFuture,
                builder: (_, snap) {
                  if (snap.connectionState == ConnectionState.waiting) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SkeletonBox(
                          width: 60, height: 9,
                          borderRadius: AppTokens.radiusFull,
                        ),
                        const SizedBox(height: AppTokens.sp4),
                        SkeletonBox(
                          width: 90, height: 12,
                          borderRadius: AppTokens.radiusFull,
                        ),
                      ],
                    );
                  }

                  final stats = snap.data;
                  if (stats == null) return const SizedBox.shrink();

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${stats.count} ${loc.transactions}',
                        style: const TextStyle(
                          fontSize: 10,
                          color: Colors.white60,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                      const SizedBox(height: AppTokens.sp2),
                      Text(
                        currency.format(stats.balance),
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: stats.balance >= 0
                              ? AppColors.successLight
                              : AppColors.dangerLight,
                          letterSpacing: -0.3,
                        ),
                      ),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// BOTTOM SHEET — CRIAR / RENOMEAR SECÇÃO
// ═══════════════════════════════════════════════════════════════════════════════
class _CreateSectionSheet extends StatelessWidget {
  final TextEditingController controller;
  final AppLocalizations loc;
  final bool isRename;

  const _CreateSectionSheet({
    required this.controller,
    required this.loc,
    this.isRename = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final theme = Theme.of(context);

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkSurface : AppColors.white,
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(AppTokens.radius24),
          ),
        ),
        padding: const EdgeInsets.fromLTRB(
          AppTokens.sp24, AppTokens.sp16, AppTokens.sp24, AppTokens.sp32,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle
            Center(
              child: Container(
                width: 36, height: 4,
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkBorder : AppColors.grey300,
                  borderRadius: BorderRadius.circular(AppTokens.radiusFull),
                ),
              ),
            ),
            const SizedBox(height: AppTokens.sp20),

            Text(
              isRename ? loc.renameSection : loc.newSection,
              style: theme.textTheme.headlineSmall,
            ),
            const SizedBox(height: AppTokens.sp20),

            TextField(
              controller: controller,
              autofocus: true,
              textCapitalization: TextCapitalization.words,
              decoration: InputDecoration(
                hintText: loc.sectionName,
                prefixIcon: const Icon(Icons.grid_view_rounded, size: 20),
              ),
              onSubmitted: (_) => Navigator.pop(context, true),
            ),
            const SizedBox(height: AppTokens.sp20),

            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: Text(loc.cancel),
                  ),
                ),
                const SizedBox(width: AppTokens.sp12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context, true),
                    child: Text(loc.save),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// BOTTOM SHEET — OPÇÕES DA SECÇÃO
// ═══════════════════════════════════════════════════════════════════════════════
class _SectionOptionsSheet extends StatelessWidget {
  final Section section;
  final AppLocalizations loc;

  const _SectionOptionsSheet({
    required this.section,
    required this.loc,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.white,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(AppTokens.radius24),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(
        AppTokens.sp24, AppTokens.sp16, AppTokens.sp24, AppTokens.sp32,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 36, height: 4,
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkBorder : AppColors.grey300,
              borderRadius: BorderRadius.circular(AppTokens.radiusFull),
            ),
          ),
          const SizedBox(height: AppTokens.sp16),
          Text(
            section.name,
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: AppTokens.sp20),

          _OptionTile(
            icon: Icons.edit_rounded,
            label: loc.rename,
            onTap: () => Navigator.pop(context, 'rename'),
          ),
          const SizedBox(height: AppTokens.sp4),
          _OptionTile(
            icon: Icons.delete_outline_rounded,
            label: loc.delete,
            color: AppColors.danger,
            onTap: () => Navigator.pop(context, 'delete'),
          ),
          const SizedBox(height: AppTokens.sp8),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(loc.cancel),
          ),
        ],
      ),
    );
  }
}

class _OptionTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color? color;
  final VoidCallback onTap;

  const _OptionTile({
    required this.icon,
    required this.label,
    required this.onTap,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final effectiveColor =
        color ?? (isDark ? AppColors.darkText : AppColors.dark);

    return Material(
      color: Colors.transparent,
      child: ListTile(
        leading: Container(
          width: 40, height: 40,
          decoration: BoxDecoration(
            color: effectiveColor.withAlpha(isDark ? 30 : 12),
            borderRadius: BorderRadius.circular(AppTokens.radius10),
          ),
          child: Icon(icon, color: effectiveColor, size: 20),
        ),
        title: Text(
          label,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w500,
            color: effectiveColor,
          ),
        ),
        onTap: onTap,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTokens.radius12),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// MODELOS & HELPERS
// ═══════════════════════════════════════════════════════════════════════════════
class _SectionStats {
  final int count;
  final double balance;
  const _SectionStats({required this.count, required this.balance});
}

