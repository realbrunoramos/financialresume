import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;

class NotificationService {
  final FlutterLocalNotificationsPlugin notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  Future<void> initNotification() async {
    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await notificationsPlugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse:
          (NotificationResponse notificationResponse) async {
        debugPrint('Notificação clicada: ${notificationResponse.payload}');
      },
    );

    await _setupNotificationChannels();
  }

  Future<void> _setupNotificationChannels() async {
    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      'financial_channel',
      'Financial Notifications',
      description: 'Notifications for financial reminders and scans',
      importance: Importance.max,
      enableLights: true,
      enableVibration: true,
      playSound: true,

    );

    await notificationsPlugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);
  }

  Future<NotificationDetails> notificationDetails() async {
    return const NotificationDetails(
      android: AndroidNotificationDetails(
        'financial_channel',
        'Financial Notifications',
        channelDescription: 'Notifications for financial reminders and scans',
        importance: Importance.max,
        priority: Priority.max,
        playSound: true,
      ),
      iOS: DarwinNotificationDetails(),
    );
  }

  Future<void> showNotification({int id = 0,String? title,String? body,String? payload,}) async {
    try {
      await notificationsPlugin.show(
        id,
        title,
        body,
        await notificationDetails(),
        payload: payload,
      );
    } catch (e) {
      debugPrint('Erro ao mostrar notificação: $e');
    }
  }

  Future<void> scheduleNotification({int id = 0,String? title,String? body,String? payload,required DateTime scheduledDate,}) async {
    try {
      await notificationsPlugin.zonedSchedule(
        id,
        title,
        body,
        tz.TZDateTime.from(scheduledDate, tz.local),
        await notificationDetails(),
        payload: payload,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      );
    } catch (e) {
      debugPrint('Erro ao agendar notificação: $e');
    }
  }

  Future<void> cancelNotification(int id) async {
    await notificationsPlugin.cancel(id);
  }

  Future<void> cancelAllNotifications() async {
    await notificationsPlugin.cancelAll();
  }
}
