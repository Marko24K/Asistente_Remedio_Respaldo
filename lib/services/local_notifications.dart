import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/material.dart';

import '../screens/immediate_take_screen.dart';
import '../screens/delayed_question_screen.dart';

class LocalNoti {
  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  // ===================== INIT ======================
  static Future<void> init(BuildContext context) async {
    const android = AndroidInitializationSettings('notification_icon');
    final settings = InitializationSettings(android: android);

    await _plugin.initialize(
      settings,
      onDidReceiveNotificationResponse: (res) {
        _handleTap(context, res.payload);
      },
    );
  }

  // =============== MANEJO DE TAP EN NOTIFICACIÓN ===============
  static void _handleTap(BuildContext context, String? payload) {
    if (payload == null || payload.isEmpty) return;

    final p = payload.split("|");
    final type = p[0];
    final id = int.parse(p[1]);
    final code = p[2];
    final hour = p[3];
    final med = p[4];

    if (type == "immediate") {
      Navigator.push(
        context,
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
      Navigator.push(
        context,
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

  // =============== NOTIFICACIÓN INMEDIATA ===============
  static Future<void> showImmediate({
    required String title,
    required String body,
    required String payload, // immediate|id|code|hour|med
  }) async {
    const android = AndroidNotificationDetails(
      'meds_channel',
      'Medicamentos',
      importance: Importance.max,
      priority: Priority.high,
    );

    await _plugin.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title,
      body,
      const NotificationDetails(android: android),
      payload: payload,
    );
  }

  // =============== NOTIFICACIÓN DIFERIDA ===============
  static Future<void> showDelayedWithActions({
    required String title,
    required String body,
    required String payload,
  }) async {
    const android = AndroidNotificationDetails(
      'meds_channel',
      'Medicamentos',
      importance: Importance.max,
      priority: Priority.high,
    );

    await _plugin.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title,
      body,
      const NotificationDetails(android: android),
      payload: payload,
    );
  }
}
