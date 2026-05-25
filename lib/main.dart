import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:provider/provider.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'screens/home_screen.dart';
import 'theme/theme.dart';
import 'l10n/app_localizations.dart';
import 'services/biometric_service.dart';
import 'services/database_service.dart';
import 'providers/transaction_provider.dart';
import 'providers/language_provider.dart';
import 'providers/theme_provider.dart';
import 'services/notification_service.dart';
import 'theme/colors.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

late List<CameraDescription> cameras;
final DatabaseService _dbService = DatabaseService();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialise timezone database and pin it to the device's local zone.
  // Without setLocalLocation, tz.local defaults to UTC and all scheduled
  // notifications fire at the wrong time.
  tz.initializeTimeZones();
  final String localTz = await FlutterTimezone.getLocalTimezone();
  tz.setLocalLocation(tz.getLocation(localTz));

  await initializeDateFormatting('pt_PT', null);
  cameras = await availableCameras();
  await _dbService.initializeDefaultSettings();

  final notificationService = NotificationService();
  await notificationService.initNotification();

  await notificationService.notificationsPlugin
      .resolvePlatformSpecificImplementation<
      AndroidFlutterLocalNotificationsPlugin>()
      ?.requestNotificationsPermission();

  runApp(MyApp(cameras: cameras,));
}

class MyApp extends StatefulWidget {
  final List<CameraDescription> cameras;
  const MyApp({super.key, required this.cameras});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  void initState() {
    super.initState();
    // Schedule once at startup — not inside build to avoid repeat on rebuild.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _scheduleDueDateNotifications(context);
    });
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => TransactionProvider()),
        ChangeNotifierProvider(create: (_) => LanguageProvider()),
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
      ],
      child: Consumer2<LanguageProvider, ThemeProvider>(
        builder: (context, languageProvider, themeProvider, child) {
          return MaterialApp(
            title: 'Financial Resume',
            theme: appTheme,
            darkTheme: appDarkTheme,
            themeMode: themeProvider.mode,
            locale: languageProvider.locale,
            localizationsDelegates: const [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            supportedLocales: const [
              Locale('en'),
              Locale('pt'),
              Locale('es'),
              Locale('fr'),
              Locale('ru'),
              Locale('zh'),
              Locale('it'),
            ],
            home: const BiometricGate(),
          );
        },
      ),
    );
  }
}
// ── Biometric lock gate ───────────────────────────────────────────────────────
// Sits between the app shell and HomeScreen.  When biometric lock is enabled
// in Settings it prompts the user to authenticate on cold start and on
// foreground resume.  If biometric hardware is unavailable, or the setting is
// off, it passes straight through to HomeScreen.
class BiometricGate extends StatefulWidget {
  const BiometricGate({super.key});

  @override
  State<BiometricGate> createState() => _BiometricGateState();
}

class _BiometricGateState extends State<BiometricGate>
    with WidgetsBindingObserver {
  bool _isLocked      = true;
  bool _isChecking    = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkAndAuthenticate();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _isLocked) {
      _checkAndAuthenticate();
    }
  }

  Future<void> _checkAndAuthenticate() async {
    final enabled = await BiometricService.isEnabled();
    if (!enabled) {
      if (mounted) setState(() { _isLocked = false; _isChecking = false; });
      return;
    }
    await _doAuthenticate();
  }

  Future<void> _doAuthenticate() async {
    if (!mounted) return;
    setState(() => _isChecking = true);
    final l       = AppLocalizations.of(context);
    final success = await BiometricService.authenticate(
      localizedReason: l.biometricReason,
    );
    if (mounted) {
      setState(() {
        _isLocked  = !success;
        _isChecking = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isChecking) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator.adaptive()),
      );
    }
    if (_isLocked) {
      final l      = AppLocalizations.of(context);
      final isDark = Theme.of(context).brightness == Brightness.dark;
      return Scaffold(
        backgroundColor:
            isDark ? AppColors.darkBackground : const Color(0xFFF5F5F7),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.lock_rounded,
                  size: 64,
                  color: isDark ? AppColors.darkSubtext : AppColors.grey400),
              const SizedBox(height: 24),
              Text(l.biometricLock,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: isDark ? AppColors.darkText : AppColors.dark,
                  )),
              const SizedBox(height: 8),
              Text(l.biometricReason,
                  style: TextStyle(
                    fontSize: 14,
                    color: isDark ? AppColors.darkSubtext : AppColors.grey500,
                  )),
              const SizedBox(height: 32),
              FilledButton.icon(
                onPressed: _doAuthenticate,
                icon: const Icon(Icons.fingerprint_rounded),
                label: Text(l.unlock),
              ),
            ],
          ),
        ),
      );
    }
    return const HomeScreen();
  }
}

Future<void> _scheduleDueDateNotifications(BuildContext context) async {
  // Capture localised strings before any await to avoid
  // use_build_context_synchronously across async gaps.
  final l = AppLocalizations.of(context);
  final warningText = l.invoiceDueWarning;
  final daysText    = l.days;

  final notificationService = NotificationService();
  // Cancel any previously scheduled notifications before rescheduling,
  // so paid invoices or changed due dates never fire stale alerts.
  await notificationService.cancelAllNotifications();

  final dbService = DatabaseService();
  final sections = await dbService.getAllSections();

  for (final section in sections) {
    final invoices = await dbService.getNoPaidInvoices(section.id);

    for (final invoice in invoices) {
      if (invoice.dueDate != null) {
        final now = DateTime.now();
        final dueDate = invoice.dueDate!;
        final normalizedDueDate = DateTime(dueDate.year, dueDate.month, dueDate.day);
        final normalizedNow = DateTime(now.year, now.month, now.day);

        final difference = normalizedDueDate.difference(normalizedNow).inDays;

        if (difference <= 8 && difference >= 1) {
          final notificationDate = DateTime(now.year, now.month, now.day, 10, 50);

          final actualNotificationDate = notificationDate.isBefore(now)
              ? notificationDate.add(const Duration(days: 1))
              : notificationDate;

          final notificationId = invoice.id.hashCode.abs() & 0x7FFFFFFF;

          await notificationService.scheduleNotification(
            id: notificationId,
            title: section.name,
            body: "$warningText ${invoice.entity} $difference $daysText!",
            scheduledDate: actualNotificationDate,
          );
        }
      }
    }
  }
}
