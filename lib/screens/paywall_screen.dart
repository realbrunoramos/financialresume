/// PaywallScreen — production-grade premium upgrade screen.
///
/// Design: dark (#08080F bg), purple gradient CTA, monthly/annual toggle,
/// AnimatedSwitcher price, feature comparison table, 3 social-proof cards,
/// glassmorphism plan cards.
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/subscription_plan.dart';
import '../providers/subscription_provider.dart';
import '../services/analytics_service.dart';
import '../theme/colors.dart';
import 'premium_success_screen.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Constants
// ─────────────────────────────────────────────────────────────────────────────

const _kBg       = Color(0xFF08080F);
const _kSurface  = Color(0xFF12121C);
const _kBorder   = Color(0xFF2A2A3C);
const _kTextDim  = Color(0xFF9CA3AF);

// ─────────────────────────────────────────────────────────────────────────────
// PaywallScreen
// ─────────────────────────────────────────────────────────────────────────────

class PaywallScreen extends StatefulWidget {
  const PaywallScreen({super.key});

  static Future<void> show(BuildContext context) => Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => const PaywallScreen(),
          fullscreenDialog: true,
        ),
      );

  @override
  State<PaywallScreen> createState() => _PaywallScreenState();
}

class _PaywallScreenState extends State<PaywallScreen>
    with SingleTickerProviderStateMixin {

  bool   _isAnnual    = true;   // annual tab pre-selected (best value)
  bool   _isPurchasing = false;
  String? _errorMsg;

  late final AnimationController _shimmerCtrl;

  SubscriptionPlan get _selectedPlan =>
      _isAnnual ? SubscriptionPlan.premiumAnnual : SubscriptionPlan.premiumMonthly;

  @override
  void initState() {
    super.initState();
    _shimmerCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
    AnalyticsService.log(Events.paywallViewed);
  }

  @override
  void dispose() {
    _shimmerCtrl.dispose();
    super.dispose();
  }

  // ── Purchase ────────────────────────────────────────────────────────────────

  Future<void> _purchase() async {
    if (_isPurchasing) return;
    setState(() { _isPurchasing = true; _errorMsg = null; });

    final sub = context.read<SubscriptionProvider>();
    final ok  = await sub.purchase(_selectedPlan);

    if (!mounted) return;

    if (!ok) {
      setState(() {
        _isPurchasing = false;
        _errorMsg     = sub.errorMessage ?? 'Purchase failed. Please try again.';
      });
      return;
    }

    // Listen for the provider to flip isPremium.
    // (Real result comes via BillingService callback → provider rebuild.)
    _waitForPremium();
  }

  void _waitForPremium() {
    final sub = context.read<SubscriptionProvider>();
    void check() {
      if (!mounted) return;
      if (sub.isPremium) {
        setState(() => _isPurchasing = false);
        _showSuccess();
      } else if (!sub.isPurchasing && !sub.isLoading) {
        setState(() {
          _isPurchasing = false;
          _errorMsg = sub.errorMessage;
        });
      } else {
        Future.delayed(const Duration(milliseconds: 300), check);
      }
    }
    check();
  }

  void _showSuccess() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => const PremiumSuccessScreen(),
        fullscreenDialog: true,
      ),
    );
  }

  Future<void> _restore() async {
    final sub = context.read<SubscriptionProvider>();
    await sub.restorePurchases();
    if (!mounted) return;
    if (sub.isPremium) { _showSuccess(); }
  }

  // ── Build ───────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final sub = context.watch<SubscriptionProvider>();
    _isPurchasing = sub.isPurchasing;

    return Scaffold(
      backgroundColor: _kBg,
      body: CustomScrollView(
        slivers: [
          _buildAppBar(),
          SliverToBoxAdapter(
            child: Column(
              children: [
                _buildHero(),
                const SizedBox(height: 28),
                _buildToggle(),
                const SizedBox(height: 20),
                _buildPlanCards(sub),
                const SizedBox(height: 28),
                _buildFeatureTable(),
                const SizedBox(height: 28),
                _buildTestimonials(),
                const SizedBox(height: 28),
                _buildCta(sub),
                const SizedBox(height: 12),
                _buildRestoreButton(sub),
                const SizedBox(height: 8),
                _buildLegalText(),
                const SizedBox(height: 32),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── App bar ──────────────────────────────────────────────────────────────

  SliverAppBar _buildAppBar() {
    return SliverAppBar(
      backgroundColor:    _kBg,
      foregroundColor:    Colors.white,
      elevation:          0,
      pinned:             false,
      leading: IconButton(
        icon: const Icon(Icons.close_rounded),
        onPressed: () {
          AnalyticsService.log(Events.paywallClosed);
          Navigator.of(context).pop();
        },
      ),
    );
  }

  // ─── Hero section ─────────────────────────────────────────────────────────

  Widget _buildHero() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: Column(
        children: [
          // Animated crown.
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.8, end: 1.0),
            duration: const Duration(milliseconds: 600),
            curve: Curves.elasticOut,
            builder: (_, v, child) => Transform.scale(scale: v, child: child),
            child: Container(
              width:  80,
              height: 80,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end:   Alignment.bottomRight,
                  colors: [AppColors.premiumDeep, AppColors.premiumSoft],
                ),
                shape:     BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color:      AppColors.premium.withValues(alpha: 0.5),
                    blurRadius: 28,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: const Icon(
                Icons.workspace_premium_rounded,
                size:  40,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(height: 20),

          const Text(
            'Unlock the full power\nof Financial Resume',
            textAlign: TextAlign.center,
            style: TextStyle(
              color:      Colors.white,
              fontSize:   24,
              fontWeight: FontWeight.w800,
              height:     1.25,
            ),
          ),
          const SizedBox(height: 10),

          Text(
            'AI analysis, unlimited scans, advanced insights —\neverything you need in one plan.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color:    Colors.white.withValues(alpha: 0.6),
              fontSize: 14,
              height:   1.55,
            ),
          ),
        ],
      ),
    );
  }

  // ─── Monthly / Annual toggle ──────────────────────────────────────────────

  Widget _buildToggle() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 28),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color:        _kSurface,
        borderRadius: BorderRadius.circular(14),
        border:       Border.all(color: _kBorder),
      ),
      child: Row(
        children: [
          _ToggleTab(
            label:    'Monthly',
            selected: !_isAnnual,
            onTap: () {
              if (_isAnnual) {
                setState(() => _isAnnual = false);
                AnalyticsService.log(Events.planToggled, {'to': 'monthly'});
              }
            },
          ),
          _ToggleTab(
            label:    'Annual',
            badge:    'Save 33%',
            selected: _isAnnual,
            onTap: () {
              if (!_isAnnual) {
                setState(() => _isAnnual = true);
                AnalyticsService.log(Events.planToggled, {'to': 'annual'});
              }
            },
          ),
        ],
      ),
    );
  }

  // ─── Plan cards ───────────────────────────────────────────────────────────

  Widget _buildPlanCards(SubscriptionProvider sub) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          Expanded(child: _PlanCard(
            plan:       SubscriptionPlan.freePlan,
            isSelected: false,
            onTap:      null,
          )),
          const SizedBox(width: 12),
          Expanded(child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 250),
            child: _PlanCard(
              key:        ValueKey(_isAnnual),
              plan:       _selectedPlan,
              isSelected: true,
              onTap:      _purchase,
            ),
          )),
        ],
      ),
    );
  }

  // ─── Feature comparison table ─────────────────────────────────────────────

  Widget _buildFeatureTable() {
    final rows = [
      (label: 'OCR Scanning',            free: '15/month',   premium: 'Unlimited'),
      (label: 'Sections',                free: '5 max',      premium: 'Unlimited'),
      (label: 'AI Document Analysis',    free: '—',          premium: '50/day'),
      (label: 'Financial Insights',      free: '—',          premium: '✓'),
      (label: 'Anomaly Detection',       free: '—',          premium: '✓'),
      (label: 'Advanced PDF Export',     free: 'Basic',      premium: 'Advanced'),
      (label: 'Advanced Analytics',      free: '—',          premium: '✓'),
      (label: 'Merchant Detection',      free: '—',          premium: '✓'),
      (label: 'Priority Support',        free: '—',          premium: '✓'),
    ];

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        color:        _kSurface,
        borderRadius: BorderRadius.circular(16),
        border:       Border.all(color: _kBorder),
      ),
      child: Column(
        children: [
          // Header.
          _FeatureHeader(),
          const Divider(color: _kBorder, height: 1),
          ...rows.asMap().entries.map((e) => Column(
            children: [
              _FeatureRow(
                label:   e.value.label,
                free:    e.value.free,
                premium: e.value.premium,
                shaded:  e.key.isOdd,
              ),
              if (e.key < rows.length - 1)
                const Divider(color: _kBorder, height: 1),
            ],
          )),
        ],
      ),
    );
  }

  // ─── Testimonials ─────────────────────────────────────────────────────────

  Widget _buildTestimonials() {
    const cards = [
      (name: 'Ana M.', text: '"Finally I understand my finances. The AI analysis is incredible."', stars: 5),
      (name: 'João P.', text: '"The unlimited scans alone are worth it. Best purchase I\'ve made."', stars: 5),
      (name: 'Sofia R.', text: '"Anomaly detection caught a double charge I would have missed. Amazing."', stars: 5),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 24),
          child: Text(
            'What Premium users say',
            style: TextStyle(
              color:      Colors.white,
              fontSize:   16,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(height: 14),
        SizedBox(
          height: 140,
          child: ListView.separated(
            padding:    const EdgeInsets.symmetric(horizontal: 20),
            scrollDirection: Axis.horizontal,
            itemCount:  cards.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (_, i) => _TestimonialCard(
              name:  cards[i].name,
              text:  cards[i].text,
              stars: cards[i].stars,
            ),
          ),
        ),
      ],
    );
  }

  // ─── CTA button ───────────────────────────────────────────────────────────

  Widget _buildCta(SubscriptionProvider sub) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        children: [
          if (_errorMsg != null) ...[
            Text(
              _errorMsg!,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.danger, fontSize: 13),
            ),
            const SizedBox(height: 10),
          ],
          SizedBox(
            width: double.infinity,
            height: 54,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppColors.premiumDeep, AppColors.premiumSoft],
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color:      AppColors.premium.withValues(alpha: 0.45),
                    blurRadius: 20,
                    offset:     const Offset(0, 6),
                  ),
                ],
              ),
              child: FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  shadowColor:     Colors.transparent,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  textStyle: const TextStyle(
                    fontSize:   16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                onPressed: _isPurchasing ? null : _purchase,
                child: _isPurchasing
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color:       Colors.white,
                        ),
                      )
                    : Text(
                        _isAnnual
                            ? 'Start Premium — \$${SubscriptionPlan.premiumAnnual.priceUsd.toStringAsFixed(2)}/year'
                            : 'Start Premium — \$${SubscriptionPlan.premiumMonthly.priceUsd.toStringAsFixed(2)}/month',
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRestoreButton(SubscriptionProvider sub) {
    return TextButton(
      onPressed: sub.isRestoring ? null : _restore,
      child: sub.isRestoring
          ? const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2, color: _kTextDim),
            )
          : const Text(
              'Restore Purchases',
              style: TextStyle(color: _kTextDim, fontSize: 13),
            ),
    );
  }

  Widget _buildLegalText() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: Text(
        'Payment will be charged to your account. Subscription renews automatically unless cancelled at least 24 hours before the end of the current period.',
        textAlign: TextAlign.center,
        style: TextStyle(
          color:    Colors.white.withValues(alpha: 0.35),
          fontSize: 11,
          height:   1.5,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Sub-widgets
// ─────────────────────────────────────────────────────────────────────────────

class _ToggleTab extends StatelessWidget {
  final String  label;
  final bool    selected;
  final String? badge;
  final VoidCallback onTap;

  const _ToggleTab({
    required this.label,
    required this.selected,
    required this.onTap,
    this.badge,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color:        selected ? AppColors.premiumDeep : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                label,
                style: TextStyle(
                  color:      selected ? Colors.white : _kTextDim,
                  fontSize:   14,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
              if (badge != null) ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color:        AppColors.premiumGold,
                    borderRadius: BorderRadius.circular(100),
                  ),
                  child: Text(
                    badge!,
                    style: const TextStyle(
                      color:      Colors.white,
                      fontSize:   9,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _PlanCard extends StatelessWidget {
  final SubscriptionPlan plan;
  final bool             isSelected;
  final VoidCallback?    onTap;

  const _PlanCard({
    super.key,
    required this.plan,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isPremium = plan.isPremium;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color:        _kSurface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color:  isSelected ? AppColors.premiumSoft : _kBorder,
            width:  isSelected ? 1.5 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color:      AppColors.premium.withValues(alpha: 0.3),
                    blurRadius: 20,
                    spreadRadius: 2,
                  ),
                ]
              : [],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Plan name.
            Text(
              plan.name,
              style: TextStyle(
                color:      isPremium ? AppColors.premiumSoft : _kTextDim,
                fontSize:   13,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 8),

            // Price.
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: RichText(
                key: ValueKey(plan.productId),
                text: TextSpan(
                  children: [
                    TextSpan(
                      text: '\$${plan.monthlyEquivalent.toStringAsFixed(2)}',
                      style: const TextStyle(
                        color:      Colors.white,
                        fontSize:   22,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const TextSpan(
                      text: '/mo',
                      style: TextStyle(
                        color:    _kTextDim,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            if (plan.isAnnual) ...[
              const SizedBox(height: 4),
              Text(
                '\$${plan.priceUsd.toStringAsFixed(2)} billed annually',
                style: const TextStyle(color: _kTextDim, fontSize: 10),
              ),
            ],

            if (plan.priceUsd == 0) ...[
              const SizedBox(height: 4),
              const Text(
                'Always free',
                style: TextStyle(color: _kTextDim, fontSize: 10),
              ),
            ],

            const SizedBox(height: 12),

            // Feature highlights.
            if (isPremium) ...[
              _MiniFeature('50 AI calls/day'),
              _MiniFeature('Unlimited scans'),
              _MiniFeature('Advanced insights'),
            ] else ...[
              _MiniFeatureLocked('15 scans/month'),
              _MiniFeatureLocked('5 sections max'),
              _MiniFeatureLocked('No AI'),
            ],
          ],
        ),
      ),
    );
  }
}

class _MiniFeature extends StatelessWidget {
  final String label;
  const _MiniFeature(this.label);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          const Icon(Icons.check_circle_rounded,
              size: 13, color: AppColors.success),
          const SizedBox(width: 5),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                color: Colors.white, fontSize: 11, fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniFeatureLocked extends StatelessWidget {
  final String label;
  const _MiniFeatureLocked(this.label);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          const Icon(Icons.remove_circle_outline_rounded,
              size: 13, color: _kTextDim),
          const SizedBox(width: 5),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                color: _kTextDim, fontSize: 11),
            ),
          ),
        ],
      ),
    );
  }
}

class _FeatureHeader extends StatelessWidget {
  const _FeatureHeader();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          const Expanded(
            flex: 3,
            child: Text(
              'Feature',
              style: TextStyle(
                color: _kTextDim, fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ),
          const Expanded(
            child: Text(
              'Free',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: _kTextDim, fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ),
          Expanded(
            child: Text(
              'Premium',
              textAlign: TextAlign.center,
              style: TextStyle(
                color:      AppColors.premiumSoft,
                fontSize:   12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FeatureRow extends StatelessWidget {
  final String label;
  final String free;
  final String premium;
  final bool   shaded;

  const _FeatureRow({
    required this.label,
    required this.free,
    required this.premium,
    required this.shaded,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: shaded ? Colors.white.withValues(alpha: 0.02) : Colors.transparent,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Text(
              label,
              style: const TextStyle(color: Colors.white, fontSize: 12),
            ),
          ),
          Expanded(
            child: Text(
              free,
              textAlign: TextAlign.center,
              style: const TextStyle(color: _kTextDim, fontSize: 12),
            ),
          ),
          Expanded(
            child: Text(
              premium,
              textAlign: TextAlign.center,
              style: TextStyle(
                color:      premium == '—' ? _kTextDim : AppColors.success,
                fontSize:   12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TestimonialCard extends StatelessWidget {
  final String name;
  final String text;
  final int    stars;

  const _TestimonialCard({
    required this.name,
    required this.text,
    required this.stars,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 230,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color:        _kSurface,
        borderRadius: BorderRadius.circular(14),
        border:       Border.all(color: _kBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: List.generate(
              stars,
              (_) => const Icon(
                Icons.star_rounded,
                size:  14,
                color: AppColors.premiumGold,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                color:    Colors.white,
                fontSize: 12,
                height:   1.45,
              ),
              maxLines: 4,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            name,
            style: const TextStyle(
              color:      _kTextDim,
              fontSize:   11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
