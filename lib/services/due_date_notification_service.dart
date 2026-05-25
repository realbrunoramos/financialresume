import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';
import 'database_service.dart';
import 'notification_service.dart';

class DueDateNotificationService {
  static final DueDateNotificationService _instance =
      DueDateNotificationService._internal();
  factory DueDateNotificationService() => _instance;
  DueDateNotificationService._internal();

  final DatabaseService _dbService = DatabaseService();
  final NotificationService _notificationService = NotificationService();

  Future<void> scheduleAllDueDateNotifications(BuildContext context) async {
    // Capture localised strings before any await.
    final loc          = AppLocalizations.of(context);
    final dueToday     = loc.dueToday;
    final dueTomorrow  = loc.dueTomorrow;
    final dueInDays    = loc.dueInDays;
    final dueInDays2   = loc.dueInDays2;

    try {
      debugPrint('Iniciando agendamento de notificações...');
      await cancelAllDueDateNotifications();

      final sections = await _dbService.getAllSections();
      int notificationsScheduled = 0;

      for (final section in sections) {
        final invoices = await _dbService.getNoPaidInvoices(section.id);

        for (final invoice in invoices) {
          if (invoice.dueDate != null && !invoice.paid) {
            final scheduled = await _scheduleNotificationForInvoice(
              sectionName: section.name,
              invoice:     invoice,
              dueToday:    dueToday,
              dueTomorrow: dueTomorrow,
              dueInDays:   dueInDays,
              dueInDays2:  dueInDays2,
            );
            if (scheduled) notificationsScheduled++;
          }
        }
      }

      debugPrint('Agendadas $notificationsScheduled notificações');
    } catch (e) {
      debugPrint('Erro ao agendar notificações: $e');
    }
  }

  Future<bool> _scheduleNotificationForInvoice({
    required String sectionName,
    required dynamic invoice,
    required String dueToday,
    required String dueTomorrow,
    required String dueInDays,
    required String dueInDays2,
  }) async {
    try {
      final dueDate   = invoice.dueDate!;
      final now       = DateTime.now();
      final difference = dueDate.difference(now).inDays;

      if (difference >= 0 && difference <= 7) {
        final notificationId = _generateNotificationId(invoice.id, difference);

        final notificationTime = DateTime(now.year, now.month, now.day, 9, 0);
        final scheduledDate = notificationTime.isBefore(now)
            ? notificationTime.add(const Duration(days: 1))
            : notificationTime;

        await _notificationService.scheduleNotification(
          id:            notificationId,
          title:         'Fatura Próxima do Vencimento',
          body:          _buildNotificationBody(
            sectionName:  sectionName,
            entity:       invoice.entity as String,
            days:         difference,
            dueToday:     dueToday,
            dueTomorrow:  dueTomorrow,
            dueInDays:    dueInDays,
            dueInDays2:   dueInDays2,
          ),
          scheduledDate: scheduledDate,
        );

        return true;
      }
      return false;
    } catch (e) {
      debugPrint('Erro ao agendar notificação para invoice ${invoice.id}: $e');
      return false;
    }
  }

  String _buildNotificationBody({
    required String sectionName,
    required String entity,
    required int    days,
    required String dueToday,
    required String dueTomorrow,
    required String dueInDays,
    required String dueInDays2,
  }) {
    if (days == 0) {
      return '$sectionName: $entity - $dueToday';
    } else if (days == 1) {
      return '$sectionName: $entity - $dueTomorrow';
    } else {
      return '$sectionName: $entity - $dueInDays $days $dueInDays2';
    }
  }

  int _generateNotificationId(String invoiceId, int days) =>
      (invoiceId.hashCode + days).abs() % 1000000000;

  Future<void> cancelAllDueDateNotifications() async {
    for (int i = 0; i < 1000; i++) {
      await _notificationService.cancelNotification(i);
    }
    debugPrint('Todas as notificações anteriores foram canceladas');
  }

  Future<void> rescheduleNotifications(BuildContext context) async {
    await scheduleAllDueDateNotifications(context);
  }
}
