import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:intl/intl.dart';
import '../screens/immediate_take_screen.dart';
import '../screens/delayed_question_screen.dart';

class LocalNoti {
  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  //  Para navegar incluso con la app cerrada
  static final GlobalKey<NavigatorState> navKey = GlobalKey<NavigatorState>();

  static Future<void> init() async {
    tz.initializeTimeZones();

    const android = AndroidInitializationSettings('notification_icon');

    final settings = InitializationSettings(android: android);

    await _plugin.initialize(
      settings,
      onDidReceiveNotificationResponse: (resp) {
        _handlePayload(resp.payload);
      },
    );

    // Crear canal
    const channel = AndroidNotificationChannel(
      'med_channel',
      'Recordatorios de Medicamentos',
      description: 'Notificaciones de recordatorios',
      importance: Importance.max,
      playSound: true,
    );

    final androidPlatform = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();

    await androidPlatform?.createNotificationChannel(channel);
  }

  // =============================================================
  //    MANEJAR PAYLOAD SEGÚN TIPO DE NOTIFICACIÓN
  // =============================================================
  static void _handlePayload(String? payload) {
    if (payload == null) return;

    final parts = payload.split("|");
    if (parts.isEmpty) return;

    final type = parts[0];

    if (type == "immediate") {
      // immediate|id|code|hour|med
      final id = int.parse(parts[1]);
      final code = parts[2];
      final hour = parts[3];
      final med = parts[4];

      navKey.currentState?.push(
        MaterialPageRoute(
          builder: (_) => ImmediateTakeScreen(
            reminderId: id,
            code: code,
            medication: med,
            hour: hour,
          ),
        ),
      );
    }

    if (type == "delayed") {
      final id = int.parse(parts[1]);
      final code = parts[2];
      final hour = parts[3];
      final med = parts[4];

      navKey.currentState?.push(
        MaterialPageRoute(
          builder: (_) => DelayedQuestionScreen(
            reminderId: id,
            code: code,
            medication: med,
            hour: hour,
          ),
        ),
      );
    }
  }

  // --------------------------------------------------------
  //   MOSTRAR INMEDIATA
  // --------------------------------------------------------
  static Future<void> showImmediate({
    required String title,
    required String body,
    String? payload,
    int? notifId,
  }) async {
    await _plugin.show(
      notifId ?? (DateTime.now().millisecondsSinceEpoch ~/ 1000),
      title,
      body,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'med_channel',
          'Recordatorios de Medicamentos',
          importance: Importance.max,
          priority: Priority.high,
          playSound: true,
          sound: RawResourceAndroidNotificationSound('pills'),
        ),
      ),
      payload: payload,
    );
  }

  // --------------------------------------------------------
  //   DIFERIDA
  // --------------------------------------------------------
  static Future<void> showDelayedWithActions({
    required String title,
    required String body,
    String? payload,
  }) async {
    await _plugin.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000 + 1,
      title,
      body,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'med_channel',
          'Recordatorios de Medicamentos',
          importance: Importance.max,
          priority: Priority.high,
          playSound: true,
          sound: RawResourceAndroidNotificationSound('pills'),
        ),
      ),
      payload: payload,
    );
  }

  // --------------------------------------------------------
  //   CANCELAR NOTIFICACIÓN
  // --------------------------------------------------------
  static Future<void> cancel(int notifId) async {
    await _plugin.cancel(notifId);
  }

  // --------------------------------------------------------
  //   CANCELAR TODAS LAS NOTIFICACIONES
  // --------------------------------------------------------
  static Future<void> cancelAll() async {
    await _plugin.cancelAll();
  }

  // --------------------------------------------------------
  //   PROGRAMAR NOTIFICACIÓN AUTOMÁTICA
  // --------------------------------------------------------
  static Future<void> scheduleReminder({
    required int reminderId,
    required String code,
    required String medication,
    required DateTime scheduledTime,
  }) async {
    final tz.TZDateTime tzScheduledTime = tz.TZDateTime.from(
      scheduledTime,
      tz.getLocation('America/Santiago'),
    );

    final hour = DateFormat("HH:mm").format(scheduledTime);

    await _plugin.zonedSchedule(
      reminderId,
      '¡Hora de tu medicamento!',
      '$medication a las $hour',
      tzScheduledTime,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'med_channel',
          'Recordatorios de Medicamentos',
          importance: Importance.max,
          priority: Priority.high,
          playSound: true,
          sound: RawResourceAndroidNotificationSound('pills'),
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      payload: "immediate|$reminderId|$code|$hour|$medication",
    );
  }

  // --------------------------------------------------------
  //   PROGRAMAR TODOS LOS RECORDATORIOS ACTIVOS
  // --------------------------------------------------------
  static Future<void> scheduleAllReminders(
    List<Map<String, dynamic>> reminders,
  ) async {
    try {
      // Cancelar todas las notificaciones programadas existentes
      await cancelAll();

      // Programar cada recordatorio activo
      for (final r in reminders) {
        try {
          final nextTrigger = r['nextTrigger'];
          if (nextTrigger != null) {
            DateTime? scheduledTime;
            if (nextTrigger is DateTime) {
              scheduledTime = nextTrigger;
            } else if (nextTrigger is String) {
              scheduledTime = DateTime.tryParse(nextTrigger);
            }

            if (scheduledTime != null &&
                scheduledTime.isAfter(DateTime.now())) {
              await scheduleReminder(
                reminderId: r['id'] as int,
                code: r['patientCode'] as String,
                medication: r['medication'] as String,
                scheduledTime: scheduledTime,
              );
            }
          }
        } catch (e) {
          // Si falla programar un recordatorio individual, continuar con los demás
          print('Error programando recordatorio ${r['id']}: $e');
        }
      }
    } catch (e) {
      // Si falla la programación general, los recordatorios siguen visibles
      print('Error en scheduleAllReminders: $e');
    }
  }
}
