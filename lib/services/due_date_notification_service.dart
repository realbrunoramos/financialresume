import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';
import 'database_service.dart';
import 'notification_service.dart';

class DueDateNotificationService {
  static final DueDateNotificationService _instance = DueDateNotificationService._internal();
  factory DueDateNotificationService() => _instance;
  DueDateNotificationService._internal();

  final DatabaseService _dbService = DatabaseService();
  final NotificationService _notificationService = NotificationService();

  Future<void> scheduleAllDueDateNotifications(BuildContext context) async {
    try {
      print('📅 Iniciando agendamento de notificações...');

      // Primeiro cancela notificações antigas
      await cancelAllDueDateNotifications();

      final sections = await _dbService.getAllSections();
      int notificationsScheduled = 0;

      for (final section in sections) {
        final invoices = await _dbService.getNoPaidInvoices(section.id);

        for (final invoice in invoices) {
          if (invoice.dueDate != null && !invoice.paid) {
            final scheduled = await _scheduleNotificationForInvoice(
              context,
              section.name,
              invoice,
            );

            if (scheduled) notificationsScheduled++;
          }
        }
      }

      print('✅ Agendadas $notificationsScheduled notificações');
    } catch (e) {
      print('❌ Erro ao agendar notificações: $e');
    }
  }

  Future<bool> _scheduleNotificationForInvoice(
      BuildContext context,
      String sectionName,
      dynamic invoice,
      ) async {
    try {
      final dueDate = invoice.dueDate!;
      final now = DateTime.now();

      // Calcula diferença em dias
      final difference = dueDate.difference(now).inDays;

      // Agenda notificação apenas se vencer em até 7 dias
      if (difference >= 0 && difference <= 7) {
        // Cria um ID único baseado no invoice
        final notificationId = _generateNotificationId(invoice.id, difference);

        // Agenda para 9:00 AM do dia atual ou próximo
        final notificationTime = DateTime(now.year, now.month, now.day, 9, 0);
        final scheduledDate = notificationTime.isBefore(now)
            ? notificationTime.add(Duration(days: 1))
            : notificationTime;

        await _notificationService.scheduleNotification(
          id: notificationId,
          title: '💰 Fatura Próxima do Vencimento',
          body: _buildNotificationBody(context, sectionName, invoice.entity, difference),
          scheduledDate: scheduledDate,
        );

        return true;
      }
      return false;
    } catch (e) {
      print('❌ Erro ao agendar notificação para invoice ${invoice.id}: $e');
      return false;
    }
  }

  String _buildNotificationBody(BuildContext context, String section, String entity, int days) {
    final loc = AppLocalizations.of(context);
    if (days == 0) {
      return '$section: $entity - ${loc.dueToday?? "Vence hoje!"}';
    } else if (days == 1) {
      return '$section: $entity - ${loc.dueTomorrow ?? "Vence amanhã!"}';
    } else {
      return '$section: $entity - ${loc.dueInDays ?? "Vence em"} $days ${loc.dueInDays2 ?? "dias"}';
    }
  }

  int _generateNotificationId(String invoiceId, int days) {
    return (invoiceId.hashCode + days).abs() % 1000000000;
  }

  Future<void> cancelAllDueDateNotifications() async {
    // Cancela notificações com ID entre 0-999.999.999 (suas notificações)
    for (int i = 0; i < 1000; i++) {
      await _notificationService.cancelNotification(i);
    }
    print('🗑️ Todas as notificações anteriores foram canceladas');
  }

  Future<void> rescheduleNotifications(BuildContext context) async {
    await scheduleAllDueDateNotifications(context);
  }
}