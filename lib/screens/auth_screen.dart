/// AuthScreen — account & cloud-sync management screen.
///
/// Shows:
/// • Signed-out state: Google Sign-In button + "continue offline" option.
/// • Signed-in state:  user avatar, sync status, sync/restore buttons, sign-out.
library;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';
import '../theme/app_tokens.dart';
import '../theme/colors.dart';

class AuthScreen extends StatelessWidget {
  const AuthScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, auth, _) {
        if (!auth.cloudEnabled) return const _CloudDisabledView();
        if (auth.isSignedIn)   return _SignedInView(auth: auth);
        return _SignInView(auth: auth);
      },
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// SIGNED-OUT VIEW
// ══════════════════════════════════════════════════════════════════════════════
class _SignInView extends StatelessWidget {
  final AuthProvider auth;
  const _SignInView({required this.auth});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final theme  = Theme.of(context);

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : const Color(0xFFF5F5F7),
      appBar: AppBar(
        title: const Text('Cloud Sync'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppTokens.sp24),
          child: Column(
            children: [
              const SizedBox(height: AppTokens.sp32),

              // ── Cloud icon ─────────────────────────────────────────────────
              Container(
                width: 88,
                height: 88,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF4285F4), Color(0xFF0F9D58)],
                  ),
                  borderRadius: BorderRadius.circular(AppTokens.radius24),
                  boxShadow: AppTokens.shadowLg,
                ),
                child: const Icon(
                  Icons.cloud_sync_rounded,
                  size: 44,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: AppTokens.sp24),

              // ── Heading ────────────────────────────────────────────────────
              Text(
                'Sincronização na Nuvem',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: isDark ? AppColors.darkText : AppColors.dark,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppTokens.sp12),
              Text(
                'Faça login para sincronizar os seus dados entre '
                'dispositivos e criar cópias de segurança automáticas.',
                style: TextStyle(
                  fontSize: 15,
                  height: 1.5,
                  color: isDark ? AppColors.darkSubtext : AppColors.grey500,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppTokens.sp32),

              // ── Feature list ───────────────────────────────────────────────
              _FeatureRow(
                icon: Icons.sync_rounded,
                label: 'Sincronização automática',
                subtitle: 'Dados sempre actualizados em todos os dispositivos',
                isDark: isDark,
              ),
              _FeatureRow(
                icon: Icons.backup_rounded,
                label: 'Backup automático',
                subtitle: 'Nunca perca as suas transações e faturas',
                isDark: isDark,
              ),
              _FeatureRow(
                icon: Icons.devices_rounded,
                label: 'Multi-dispositivo',
                subtitle: 'Aceda aos seus dados em qualquer dispositivo',
                isDark: isDark,
              ),
              _FeatureRow(
                icon: Icons.lock_rounded,
                label: 'Seguro e privado',
                subtitle: 'Dados encriptados e acessíveis apenas por si',
                isDark: isDark,
              ),
              const SizedBox(height: AppTokens.sp32),

              // ── Google Sign-In button ──────────────────────────────────────
              if (auth.isSyncing)
                const Center(child: CircularProgressIndicator.adaptive())
              else
                _GoogleSignInButton(
                  onPressed: () => auth.signInWithGoogle(),
                ),

              // ── Error ──────────────────────────────────────────────────────
              if (auth.syncError != null) ...[
                const SizedBox(height: AppTokens.sp12),
                Container(
                  padding: const EdgeInsets.all(AppTokens.sp12),
                  decoration: BoxDecoration(
                    color: AppColors.danger.withAlpha(15),
                    borderRadius: BorderRadius.circular(AppTokens.radius12),
                    border: Border.all(color: AppColors.danger.withAlpha(40)),
                  ),
                  child: Text(
                    auth.syncError!,
                    style: const TextStyle(
                      color: AppColors.danger,
                      fontSize: 13,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],

              const SizedBox(height: AppTokens.sp16),

              // ── Privacy note ───────────────────────────────────────────────
              Text(
                'A chave API Gemini e dados biométricos ficam sempre '
                'armazenados apenas localmente.',
                style: TextStyle(
                  fontSize: 11,
                  color: isDark ? AppColors.darkSubtext : AppColors.grey400,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppTokens.sp32),
            ],
          ),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// SIGNED-IN VIEW
// ══════════════════════════════════════════════════════════════════════════════
class _SignedInView extends StatelessWidget {
  final AuthProvider auth;
  const _SignedInView({required this.auth});

  @override
  Widget build(BuildContext context) {
    final isDark  = Theme.of(context).brightness == Brightness.dark;
    final timeFmt = DateFormat('dd/MM/yyyy HH:mm');

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : const Color(0xFFF5F5F7),
      appBar: AppBar(
        title: const Text('Cloud Sync'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppTokens.sp16),
          children: [
            // ── User card ──────────────────────────────────────────────────
            _SyncCard(
              isDark: isDark,
              child: Row(children: [
                // Avatar
                CircleAvatar(
                  radius: 28,
                  backgroundColor: AppColors.primary.withAlpha(30),
                  backgroundImage: auth.userPhotoUrl.isNotEmpty
                      ? NetworkImage(auth.userPhotoUrl)
                      : null,
                  child: auth.userPhotoUrl.isEmpty
                      ? Icon(Icons.person_rounded,
                          color: AppColors.primary, size: 28)
                      : null,
                ),
                const SizedBox(width: AppTokens.sp16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        auth.userDisplayName,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: isDark ? AppColors.darkText : AppColors.dark,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        auth.userEmail,
                        style: TextStyle(
                          fontSize: 13,
                          color: isDark ? AppColors.darkSubtext : AppColors.grey500,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                // Sync status indicator
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: AppTokens.sp8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.success.withAlpha(25),
                    borderRadius: BorderRadius.circular(AppTokens.radiusFull),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.cloud_done_rounded,
                        size: 13, color: AppColors.success),
                    const SizedBox(width: 4),
                    Text(
                      'Activo',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppColors.success,
                      ),
                    ),
                  ]),
                ),
              ]),
            ),
            const SizedBox(height: AppTokens.sp12),

            // ── Sync status card ───────────────────────────────────────────
            _SyncCard(
              isDark: isDark,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Estado da Sincronização',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: isDark ? AppColors.darkSubtext : AppColors.grey500,
                      letterSpacing: 0.4,
                    ),
                  ),
                  const SizedBox(height: AppTokens.sp12),
                  if (auth.isSyncing)
                    const _SyncProgressRow()
                  else
                    _SyncStatusRow(
                      lastSyncAt: auth.lastSyncAt,
                      timeFmt: timeFmt,
                      isDark: isDark,
                    ),
                  if (auth.syncError != null) ...[
                    const SizedBox(height: AppTokens.sp8),
                    Text(
                      auth.syncError!,
                      style: const TextStyle(
                          color: AppColors.danger, fontSize: 12),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: AppTokens.sp12),

            // ── Actions ────────────────────────────────────────────────────
            _SyncCard(
              isDark: isDark,
              child: Column(children: [
                _ActionTile(
                  icon: Icons.sync_rounded,
                  label: 'Sincronizar agora',
                  subtitle: 'Envia alterações pendentes para a nuvem',
                  isDark: isDark,
                  loading: auth.isSyncing,
                  onTap: () => auth.triggerSync(),
                ),
                _Divider(isDark: isDark),
                _ActionTile(
                  icon: Icons.cloud_download_rounded,
                  label: 'Restaurar da nuvem',
                  subtitle: 'Descarrega todos os dados da nuvem para este dispositivo',
                  isDark: isDark,
                  onTap: () => _confirmRestore(context, auth),
                ),
              ]),
            ),
            const SizedBox(height: AppTokens.sp12),

            // ── Danger zone ────────────────────────────────────────────────
            _SyncCard(
              isDark: isDark,
              child: Column(children: [
                _ActionTile(
                  icon: Icons.logout_rounded,
                  label: 'Terminar sessão',
                  subtitle: 'Os dados locais são preservados',
                  isDark: isDark,
                  color: isDark ? AppColors.darkSubtext : AppColors.grey600,
                  onTap: () => _confirmSignOut(context, auth),
                ),
                _Divider(isDark: isDark),
                _ActionTile(
                  icon: Icons.delete_forever_rounded,
                  label: 'Eliminar conta',
                  subtitle: 'Remove todos os dados da nuvem permanentemente',
                  isDark: isDark,
                  color: AppColors.danger,
                  onTap: () => _confirmDeleteAccount(context, auth),
                ),
              ]),
            ),
            const SizedBox(height: AppTokens.sp32),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmSignOut(BuildContext ctx, AuthProvider auth) async {
    final ok = await _confirmDialog(
      ctx,
      title:   'Terminar sessão?',
      message: 'Os seus dados locais serão mantidos. Pode voltar a entrar quando quiser.',
      confirm: 'Terminar sessão',
      danger:  false,
    );
    if (ok) await auth.signOut();
  }

  Future<void> _confirmRestore(BuildContext ctx, AuthProvider auth) async {
    final ok = await _confirmDialog(
      ctx,
      title:   'Restaurar da nuvem?',
      message: 'Serão adicionados todos os dados da nuvem ao dispositivo. '
               'Os dados locais existentes são mantidos.',
      confirm: 'Restaurar',
      danger:  false,
    );
    if (ok) await auth.restoreFromCloud();
  }

  Future<void> _confirmDeleteAccount(BuildContext ctx, AuthProvider auth) async {
    final ok = await _confirmDialog(
      ctx,
      title:   'Eliminar conta?',
      message: 'Esta ação remove TODOS os dados da nuvem permanentemente e '
               'não pode ser desfeita. Os dados locais são preservados.',
      confirm: 'Eliminar permanentemente',
      danger:  true,
    );
    if (ok) {
      try {
        await auth.deleteAccount();
      } catch (_) {
        if (ctx.mounted) {
          ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(
            content: Text('Faça login novamente antes de eliminar a conta.'),
            backgroundColor: AppColors.danger,
          ));
        }
      }
    }
  }

  Future<bool> _confirmDialog(
    BuildContext ctx, {
    required String title,
    required String message,
    required String confirm,
    required bool   danger,
  }) async {
    final result = await showDialog<bool>(
      context: ctx,
      builder: (_) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: danger
                ? FilledButton.styleFrom(backgroundColor: AppColors.danger)
                : null,
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(confirm),
          ),
        ],
      ),
    );
    return result ?? false;
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// CLOUD DISABLED (Firebase not configured)
// ══════════════════════════════════════════════════════════════════════════════
class _CloudDisabledView extends StatelessWidget {
  const _CloudDisabledView();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : const Color(0xFFF5F5F7),
      appBar: AppBar(
        title: const Text('Cloud Sync'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(AppTokens.sp24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.cloud_off_rounded, size: 64,
                  color: isDark ? AppColors.darkSubtext : AppColors.grey300),
              const SizedBox(height: AppTokens.sp16),
              Text(
                'Firebase não configurado',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: isDark ? AppColors.darkText : AppColors.dark,
                ),
              ),
              const SizedBox(height: AppTokens.sp8),
              Text(
                'Execute flutterfire configure para activar a sincronização na nuvem.\n'
                'Consulte lib/firebase_options.dart para instruções.',
                style: TextStyle(
                  fontSize: 13,
                  height: 1.5,
                  color: isDark ? AppColors.darkSubtext : AppColors.grey500,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// Reusable sub-widgets
// ══════════════════════════════════════════════════════════════════════════════

class _SyncCard extends StatelessWidget {
  final Widget child;
  final bool   isDark;
  const _SyncCard({required this.child, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppTokens.sp16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : AppColors.white,
        borderRadius: BorderRadius.circular(AppTokens.radius16),
        border: Border.all(
            color: isDark ? AppColors.darkBorder : AppColors.grey100),
        boxShadow: isDark ? null : AppTokens.shadowSm,
      ),
      child: child,
    );
  }
}

class _ActionTile extends StatelessWidget {
  final IconData  icon;
  final String    label;
  final String    subtitle;
  final bool      isDark;
  final Color?    color;
  final VoidCallback onTap;
  final bool      loading;

  const _ActionTile({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.isDark,
    required this.onTap,
    this.color,
    this.loading = false,
  });

  @override
  Widget build(BuildContext context) {
    final fg = color ?? (isDark ? AppColors.darkText : AppColors.dark);
    return InkWell(
      onTap: loading ? null : onTap,
      borderRadius: BorderRadius.circular(AppTokens.radius12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppTokens.sp12),
        child: Row(children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: fg.withAlpha(isDark ? 30 : 15),
              borderRadius: BorderRadius.circular(AppTokens.radius8),
            ),
            child: loading
                ? SizedBox(
                    width: 18, height: 18,
                    child: CircularProgressIndicator.adaptive(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation(fg),
                    ),
                  )
                : Icon(icon, size: 18, color: fg),
          ),
          const SizedBox(width: AppTokens.sp12),
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: TextStyle(
                    fontSize: 15, fontWeight: FontWeight.w600, color: fg)),
              Text(subtitle,
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? AppColors.darkSubtext : AppColors.grey500,
                  )),
            ],
          )),
          Icon(Icons.chevron_right_rounded,
              color: isDark ? AppColors.darkSubtext : AppColors.grey400),
        ]),
      ),
    );
  }
}

class _SyncProgressRow extends StatelessWidget {
  const _SyncProgressRow();
  @override
  Widget build(BuildContext context) {
    return Row(children: [
      const SizedBox(
        width: 16, height: 16,
        child: CircularProgressIndicator.adaptive(strokeWidth: 2),
      ),
      const SizedBox(width: AppTokens.sp12),
      Text(
        'A sincronizar…',
        style: TextStyle(
          fontSize: 13,
          color: Theme.of(context).brightness == Brightness.dark
              ? AppColors.darkSubtext : AppColors.grey500,
        ),
      ),
    ]);
  }
}

class _SyncStatusRow extends StatelessWidget {
  final DateTime? lastSyncAt;
  final DateFormat timeFmt;
  final bool isDark;
  const _SyncStatusRow({
    required this.lastSyncAt,
    required this.timeFmt,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Icon(Icons.check_circle_rounded, size: 16, color: AppColors.success),
      const SizedBox(width: AppTokens.sp8),
      Text(
        lastSyncAt != null
            ? 'Última sync: ${timeFmt.format(lastSyncAt!)}'
            : 'A aguardar sincronização…',
        style: TextStyle(
          fontSize: 13,
          color: isDark ? AppColors.darkSubtext : AppColors.grey500,
        ),
      ),
    ]);
  }
}

class _FeatureRow extends StatelessWidget {
  final IconData icon;
  final String   label;
  final String   subtitle;
  final bool     isDark;
  const _FeatureRow({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppTokens.sp16),
      child: Row(children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: AppColors.primary.withAlpha(isDark ? 40 : 15),
            borderRadius: BorderRadius.circular(AppTokens.radius12),
          ),
          child: Icon(icon, size: 20, color: AppColors.primary),
        ),
        const SizedBox(width: AppTokens.sp16),
        Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: isDark ? AppColors.darkText : AppColors.dark,
                )),
            Text(subtitle,
                style: TextStyle(
                  fontSize: 12,
                  color: isDark ? AppColors.darkSubtext : AppColors.grey500,
                )),
          ],
        )),
      ]),
    );
  }
}

class _GoogleSignInButton extends StatelessWidget {
  final VoidCallback onPressed;
  const _GoogleSignInButton({required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          backgroundColor: Colors.white,
          foregroundColor: const Color(0xFF3C4043),
          side: const BorderSide(color: Color(0xFFDADCE0)),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTokens.radius12),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Google "G" logo colours
            _GoogleLogo(),
            const SizedBox(width: AppTokens.sp12),
            const Text(
              'Continuar com Google',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: Color(0xFF3C4043),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GoogleLogo extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    // Simple coloured-text "G" representing the Google logo.
    return const Text(
      'G',
      style: TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.w700,
        color: Color(0xFF4285F4),
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  final bool isDark;
  const _Divider({required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Divider(
      height: 1,
      color: isDark ? AppColors.darkBorder : AppColors.grey100,
    );
  }
}

