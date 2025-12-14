import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz;
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
  }) async {
    await _plugin.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title,
      body,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'med_channel',
          'Recordatorios de Medicamentos',
          importance: Importance.max,
          priority: Priority.high,
          playSound: true,
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
        ),
      ),
      payload: payload,
    );
  }
}
