import 'package:flutter/material.dart';

import '../data/database_helper.dart';
import '../services/feedback_scheduler.dart';
import '../services/audio_player_service.dart';

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

    // nextTrigger puede venir como DateTime o como String -> lo normalizo
    DateTime? nextTrigger;
    final rawNext = r["nextTrigger"];
    if (rawNext is DateTime) {
      nextTrigger = rawNext;
    } else if (rawNext is String) {
      nextTrigger = DateTime.tryParse(rawNext);
    }

    final horaProgramada = (r["hour"] ?? "--:--") as String;
    final proximaToma = _formatHour(nextTrigger, horaProgramada);

    return Scaffold(
      backgroundColor: const Color(0xFFF4F7F6),
      appBar: AppBar(
        title: const Text("Detalles"),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(18),
        child: Column(
          children: [
            // ---------- TARJETA PRINCIPAL ----------
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Título + icono
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
                  Text(
                    "${r['dose'] ?? ''} • ${r['type'] ?? ''}",
                    style: const TextStyle(fontSize: 16, color: Colors.black54),
                  ),

                  const SizedBox(height: 20),

                  // Hora programada (la original del tratamiento)
                  _item("Hora programada", horaProgramada),
                  _divider(),

                  // Próxima toma (usa nextTrigger)
                  _item("Próxima toma", proximaToma),
                  _divider(),

                  _item("Inicio del recordatorio", r["startDate"] ?? ""),
                  _divider(),
                  _item("Fin del recordatorio", r["endDate"] ?? ""),
                  _divider(),

                  // Notas + botón "Ver más"
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        "Notas",
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      TextButton(
                        onPressed: () => _showNotes(context, r["notes"] ?? ""),
                        child: const Text("Ver más"),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 35),

            // ---------- BOTÓN TOMAR ANTES ----------
            GestureDetector(
              onTap: () async {
                final freq = (r["frequencyHours"] ?? 24) as int;
                final reminderId = r["id"] as int;
                final code = r["patientCode"] as String;
                final hora = r["hour"] as String;
                final puntos = 10;

                // La toma real es AHORA → la próxima es en freq horas
                final now = DateTime.now();
                final next = now.add(Duration(hours: freq));

                // Cancelar la notificación anterior
                await FeedbackScheduler.cancelNotification(reminderId);

                // Actualizar nextTrigger en BD
                await DBHelper.updateNextTriggerById(reminderId, next);

                // Programar la siguiente notificación exacta
                await FeedbackScheduler.scheduleDueReminder(
                  reminderId: reminderId,
                  code: code,
                  medication: r["medication"] as String,
                  hour: hora,
                  when: next,
                );

                // Registrar en KPIs que se tomó ANTES de la hora
                await DBHelper.addKpi(
                  reminderId: reminderId,
                  code: code,
                  scheduledHour: hora,
                  tomo: true,
                  puntos: puntos,
                );

                // Sumar puntos por TOMAR ANTES
                await DBHelper.addPoints(puntos, code);

                // Reproducir sonido de éxito
                await AudioPlayerService.playSound('correct_ding.mp3');

                // Mostrar popup con puntos
                if (context.mounted) {
                  showDialog(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text("¡Excelente!"),
                      content: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.star, color: Colors.amber, size: 60),
                          const SizedBox(height: 16),
                          Text(
                            "+$puntos puntos",
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Colors.green,
                            ),
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            "Recordatorio reprogramado para más tarde.",
                          ),
                        ],
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctx),
                          child: const Text("OK"),
                        ),
                      ],
                    ),
                  );

                  // Cerrar después de 2 segundos
                  await Future.delayed(const Duration(seconds: 2));
                  if (context.mounted) {
                    Navigator.pop(context, true);
                  }
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
            ),
          ],
        ),
      ),
    );
  }

  Widget _item(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
          ),
          Text(
            value,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  Widget _divider() {
    return Container(
      height: 1,
      color: Colors.grey.shade300,
      margin: const EdgeInsets.symmetric(vertical: 6),
    );
  }

  void _showNotes(BuildContext context, String text) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Título + cerrar
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      "Nota",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFF2D6A4F)),
                    color: const Color(0xFFF7F9F8),
                  ),
                  child: Text(text, style: const TextStyle(fontSize: 15)),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2D6A4F),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: const Text(
                      "Entendido",
                      style: TextStyle(fontSize: 18, color: Colors.white),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
