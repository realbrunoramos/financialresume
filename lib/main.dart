import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'screens/home_screen.dart';
import 'theme/theme.dart';
import 'l10n/app_localizations.dart';
import 'services/database_service.dart';
import 'providers/transaction_provider.dart';
import 'providers/language_provider.dart';
import 'services/notification_service.dart';
import 'package:timezone/data/latest.dart' as tz;

late List<CameraDescription> cameras;
final DatabaseService _dbService = DatabaseService();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  tz.initializeTimeZones();
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
      ],
      child: Consumer<LanguageProvider>(
        builder: (context, languageProvider, child) {
          return MaterialApp(
            title: 'Financial Resume',
            theme: appTheme,
            darkTheme: appDarkTheme,
            themeMode: ThemeMode.system,
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
            home: const HomeScreen(),
          );
        },
      ),
    );
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
              ? notificationDate.add(Duration(days: 1))
              : notificationDate;

          String numericId = invoice.id.replaceAll(RegExp(r'[^0-9]'), '');
          if (numericId.isEmpty) numericId = '99999';

          if (numericId.length > 9) {
            numericId = numericId.substring(numericId.length - 9);
          }

          final notificationId = int.parse(numericId);

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
