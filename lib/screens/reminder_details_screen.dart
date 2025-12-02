import 'package:flutter/material.dart';

import '../data/database_helper.dart';
import '../services/audio_player_service.dart';
import '../services/local_notifications.dart';

import '../screens/immediate_take_screen.dart';
import '../screens/delayed_question_screen.dart';

class ReminderDetailScreen extends StatelessWidget {
  final Map<String, dynamic> reminder;

  const ReminderDetailScreen({super.key, required this.reminder});

  String _formatHour(DateTime? dt, String fallback) {
    if (dt == null) return fallback;
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return "$h:$m";
  }

  @override
  Widget build(BuildContext context) {
    final r = reminder;

    DateTime? nextTrigger;
    final rawNext = r["nextTrigger"];
    if (rawNext is DateTime) {
      nextTrigger = rawNext;
    } else if (rawNext is String) {
      nextTrigger = DateTime.tryParse(rawNext);
    }

    final horaProgramada = r["hour"] ?? "--:--";
    final proximaToma = _formatHour(nextTrigger, horaProgramada);

    return Scaffold(
      backgroundColor: const Color(0xFFF4F7F6),
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
        title: const Text("Detalles"),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(18),
        child: Column(
          children: [
            _infoCard(context, r, horaProgramada, proximaToma),

            const SizedBox(height: 35),

            _tomarAntesButton(context, r),

            const SizedBox(height: 25),

            _simularNotificacionButton(context, r),
          ],
        ),
      ),
    );
  }

  // ===================================================================
  //  SIMULAR NOTIFICACIÓN (FLUJO COMPLETO: inmediata → diferida)
  // ===================================================================
  Widget _simularNotificacionButton(BuildContext context, Map r) {
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.blue.shade700,
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      onPressed: () async {
        final id = r["id"];
        final code = r["patientCode"];
        final med = r["medication"];
        final hour = r["hour"];

        // NOTIFICACIÓN INMEDIATA
        await LocalNoti.showImmediate(
          title: "¡Hora de tu medicamento!",
          body: "$med a las $hour",
          payload: "immediate|$id|$code|$hour|$med",
        );

        // ABRIR PANTALLA DE TOMA INMEDIATA
        if (context.mounted) {
          await Navigator.push(
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

        // SI NO MARCA EN 1 MINUTO → volver a home
        await Future.delayed(const Duration(minutes: 1));

        if (context.mounted) Navigator.pop(context, true);

        // Esperar 10 segundos y mostrar DIFERIDA
        await Future.delayed(const Duration(seconds: 10));

        if (context.mounted) {
          await LocalNoti.showDelayedWithActions(
            title: "¿Tomaste tu medicamento?",
            body: "$med",
            payload: "delayed|$id|$code|$hour|$med",
          );

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
      },
      child: const Text(
        "Simular Notificación",
        style: TextStyle(fontSize: 18, color: Colors.white),
      ),
    );
  }

  // ===================================================================
  //  TOMAR ANTES — REGISTRO + PUNTOS + POPUP
  // ===================================================================
  Widget _tomarAntesButton(BuildContext context, Map r) {
    return GestureDetector(
      onTap: () async {
        final freq = (r["frequencyHours"] ?? 24) as int;
        final id = r["id"] as int;
        final code = r["patientCode"] as String;
        final hora = r["hour"] as String;
        const puntos = 10;

        final now = DateTime.now();
        final next = now.add(Duration(hours: freq));

        // Guardar nueva próxima toma
        await DBHelper.updateNextTriggerById(id, next);

        // KPIs
        await DBHelper.addKpi(
          reminderId: id,
          code: code,
          scheduledHour: hora,
          tomo: true,
          puntos: puntos,
        );

        await DBHelper.addPoints(puntos, code);
        await DBHelper.addTotalPoints(puntos, code);

        AudioPlayerService.playSound("sounds/correct-ding.mp3");

        // POPUP
        if (context.mounted) {
          showDialog(
            context: context,
            builder: (_) => AlertDialog(
              title: const Text("¡Excelente!"),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: const [
                  Icon(Icons.star, size: 60, color: Colors.amber),
                  SizedBox(height: 10),
                  Text(
                    "+10 puntos",
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.green,
                    ),
                  ),
                  SizedBox(height: 10),
                  Text("Recordatorio reprogramado."),
                ],
              ),
              actions: [
                TextButton(
                  child: const Text("OK"),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          );

          await Future.delayed(const Duration(seconds: 2));
          if (context.mounted) Navigator.pop(context, true);
        }
      },
      child: Container(
        width: 220,
        height: 220,
        decoration: const BoxDecoration(
          color: Color(0xFF2E8B57),
          shape: BoxShape.circle,
        ),
        child: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.check, color: Colors.white, size: 75),
              SizedBox(height: 10),
              Text(
                "Tomar antes",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ===================================================================
  //  TARJETA PRINCIPAL
  // ===================================================================
  Widget _infoCard(
    BuildContext context,
    Map r,
    String horaProgramada,
    String proxima,
  ) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.medication_rounded,
                color: Colors.green,
                size: 28,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  r["medication"] ?? "",
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),

          Text("${r['dose']} • ${r['type']}"),
          const SizedBox(height: 20),

          _item("Hora programada", horaProgramada),
          _divider(),

          _item("Próxima toma", proxima),
          _divider(),

          _item("Inicio", r["startDate"] ?? ""),
          _divider(),

          _item("Fin", r["endDate"] ?? ""),
          _divider(),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                "Notas",
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              TextButton(
                onPressed: () => _showNotes(context, r["notes"] ?? ""),
                child: const Text("Ver más"),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _item(String name, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(name, style: const TextStyle(fontSize: 16)),
          Text(
            value,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  Widget _divider() => Container(
    height: 1,
    color: Colors.grey.shade300,
    margin: const EdgeInsets.symmetric(vertical: 6),
  );

  void _showNotes(BuildContext context, String text) {
    showDialog(
      context: context,
      builder: (_) =>
          AlertDialog(title: const Text("Notas"), content: Text(text)),
    );
  }
}
