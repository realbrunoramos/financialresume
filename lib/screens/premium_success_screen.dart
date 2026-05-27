/// PremiumSuccessScreen — celebratory screen shown after a successful purchase.
///
/// Features:
///   • Custom confetti particle system (no external dep) via CustomPainter.
///   • Stagger-animated content (scale + fade).
///   • Auto-dismisses after 4 s or on explicit "Start using Premium" tap.
library;

import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../theme/colors.dart';

// ─────────────────────────────────────────────────────────────────────────────
// PremiumSuccessScreen
// ─────────────────────────────────────────────────────────────────────────────

class PremiumSuccessScreen extends StatefulWidget {
  const PremiumSuccessScreen({super.key});

  @override
  State<PremiumSuccessScreen> createState() => _PremiumSuccessScreenState();
}

class _PremiumSuccessScreenState extends State<PremiumSuccessScreen>
    with TickerProviderStateMixin {

  late final AnimationController _confettiCtrl;
  late final AnimationController _contentCtrl;
  late final Animation<double>   _scaleAnim;
  late final Animation<double>   _fadeAnim;

  @override
  void initState() {
    super.initState();

    _confettiCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..forward();

    _contentCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );

    _scaleAnim = CurvedAnimation(
      parent: _contentCtrl,
      curve: Curves.elasticOut,
    );
    _fadeAnim = CurvedAnimation(
      parent: _contentCtrl,
      curve: Curves.easeIn,
    );

    // Stagger content entry slightly after confetti starts.
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) _contentCtrl.forward();
    });

    // Auto-dismiss.
    Future.delayed(const Duration(seconds: 5), () {
      if (mounted) Navigator.of(context).pop();
    });
  }

  @override
  void dispose() {
    _confettiCtrl.dispose();
    _contentCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF08080F),
      body: Stack(
        children: [
          // ── Confetti layer ─────────────────────────────────────────────────
          AnimatedBuilder(
            animation: _confettiCtrl,
            builder: (_, __) => CustomPaint(
              painter: _ConfettiPainter(_confettiCtrl.value),
              child: const SizedBox.expand(),
            ),
          ),

          // ── Content ────────────────────────────────────────────────────────
          SafeArea(
            child: Center(
              child: FadeTransition(
                opacity: _fadeAnim,
                child: ScaleTransition(
                  scale: _scaleAnim,
                  child: _buildContent(context),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Crown icon.
          Container(
            width: 96,
            height: 96,
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
                  blurRadius: 32,
                  spreadRadius: 4,
                ),
              ],
            ),
            child: const Icon(
              Icons.workspace_premium_rounded,
              size:  48,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 28),

          const Text(
            'Welcome to Premium! 🎉',
            textAlign: TextAlign.center,
            style: TextStyle(
              color:      Colors.white,
              fontSize:   26,
              fontWeight: FontWeight.w800,
              height:     1.2,
            ),
          ),
          const SizedBox(height: 12),

          Text(
            'Your account has been upgraded. Enjoy unlimited AI analysis, advanced insights, and much more.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color:    Colors.white.withValues(alpha: 0.7),
              fontSize: 15,
              height:   1.5,
            ),
          ),
          const SizedBox(height: 36),

          // Feature highlights.
          _HighlightRow(icon: Icons.auto_awesome_rounded,      label: 'AI Document Analysis — 50 calls/day'),
          const SizedBox(height: 10),
          _HighlightRow(icon: Icons.all_inclusive_rounded,     label: 'Unlimited Scans & Sections'),
          const SizedBox(height: 10),
          _HighlightRow(icon: Icons.bar_chart_rounded,         label: 'Financial Insights & Analytics'),
          const SizedBox(height: 10),
          _HighlightRow(icon: Icons.picture_as_pdf_rounded,    label: 'Advanced PDF Export'),
          const SizedBox(height: 36),

          // CTA.
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.premium,
                foregroundColor: Colors.white,
                padding:         const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                textStyle: const TextStyle(
                  fontSize:   16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Start Using Premium'),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Highlight row
// ─────────────────────────────────────────────────────────────────────────────

class _HighlightRow extends StatelessWidget {
  final IconData icon;
  final String   label;

  const _HighlightRow({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width:  32,
          height: 32,
          decoration: BoxDecoration(
            color:        AppColors.premiumDeep.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 16, color: AppColors.premiumSoft),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              color:      Colors.white,
              fontSize:   14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        const Icon(Icons.check_circle_rounded,
            size: 18, color: AppColors.success),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Confetti CustomPainter
// ─────────────────────────────────────────────────────────────────────────────

class _Particle {
  final double x;       // 0–1 normalised initial x
  final double speed;   // normalised fall speed
  final double size;    // radius
  final Color  color;
  final double rotSpeed;
  final double phase;   // horizontal oscillation phase

  _Particle({
    required this.x,
    required this.speed,
    required this.size,
    required this.color,
    required this.rotSpeed,
    required this.phase,
  });
}

class _ConfettiPainter extends CustomPainter {
  final double progress; // 0.0–1.0

  static final List<_Particle> _particles = _buildParticles();

  _ConfettiPainter(this.progress);

  static List<_Particle> _buildParticles() {
    final rng = math.Random(42);
    final colors = [
      AppColors.premiumSoft,
      AppColors.premiumGold,
      AppColors.success,
      const Color(0xFFF43F5E),
      const Color(0xFF38BDF8),
      Colors.white,
    ];
    return List.generate(80, (_) => _Particle(
      x:        rng.nextDouble(),
      speed:    0.3 + rng.nextDouble() * 0.7,
      size:     3 + rng.nextDouble() * 5,
      color:    colors[rng.nextInt(colors.length)],
      rotSpeed: (rng.nextDouble() - 0.5) * 6,
      phase:    rng.nextDouble() * math.pi * 2,
    ));
  }

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint();
    for (final p in _particles) {
      final t  = (progress * p.speed).clamp(0.0, 1.0);
      final py = t * size.height;
      final px = p.x * size.width +
          math.sin(p.phase + progress * 8 * p.speed) * 20;
      final alpha = (1.0 - math.pow(t, 2)).clamp(0.0, 1.0);
      if (alpha <= 0) continue;

      paint.color = p.color.withValues(alpha: alpha);
      canvas.save();
      canvas.translate(px, py);
      canvas.rotate(progress * p.rotSpeed * math.pi * 2);

      // Alternate between circles and small rectangles.
      if (p.size > 5) {
        canvas.drawRect(
          Rect.fromCenter(
              center: Offset.zero,
              width:  p.size * 1.6,
              height: p.size * 0.8),
          paint,
        );
      } else {
        canvas.drawCircle(Offset.zero, p.size, paint);
      }
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_ConfettiPainter old) => old.progress != progress;
}
