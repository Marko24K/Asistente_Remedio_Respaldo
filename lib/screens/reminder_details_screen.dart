import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../data/database_helper.dart';
import '../services/audio_player_service.dart';
import '../services/local_notifications.dart';
import 'patient_home_screen.dart';
import 'points_screen.dart';

class ReminderDetailScreen extends StatelessWidget {
  final Map<String, dynamic> reminder;

  const ReminderDetailScreen({super.key, required this.reminder});

  String _formatHour(DateTime? dt, String fallback) {
    if (dt == null) return fallback;
    return DateFormat("HH:mm").format(dt);
  }

  @override
  Widget build(BuildContext context) {
    final r = reminder;

    // Normalizar nextTrigger
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
        elevation: 0,
        foregroundColor: Colors.black87,
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

  // =========================================================================
  // 🔔 BOTÓN: SIMULAR NOTIFICACIÓN (inmediata → diferida)
  // =========================================================================
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

        // Próxima hora simulada
        final simulatedNext = DateTime.now().add(const Duration(seconds: 15));
        final nextHour = DateFormat("HH:mm").format(simulatedNext);

        // Guardar el momento de inicio de la simulación
        final startTime = DateTime.now();

        // 1) Notificación inmediata
        final notifId = DateTime.now().millisecondsSinceEpoch ~/ 1000;
        await LocalNoti.showImmediate(
          title: "¡Hora de tu medicamento!",
          body: "$med a las $nextHour",
          payload: "immediate|$id|$code|$nextHour|$med",
          notifId: notifId,
        );

        // Mostrar mensaje al usuario
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                "Notificación enviada. Presiona la notificación para marcar como tomado.",
              ),
              duration: Duration(seconds: 3),
              backgroundColor: Colors.blue,
            ),
          );
        }

        // 2) Esperar 15 segundos para dar tiempo a marcar
        await Future.delayed(const Duration(seconds: 15));

        // 3) Verificar si se marcó a tiempo
        bool marcadoATiempo = false;
        final eventosRecientes = await DBHelper.getEventosToma(code, limit: 5);

        for (final evento in eventosRecientes) {
          // Verificar si el evento corresponde a este recordatorio
          if (evento['id_recordatorio'] == id) {
            final fechaEvento = DateTime.parse(
              evento['fecha_hora_programada'] as String,
            );

            // Si el evento fue registrado DESPUÉS de iniciar la simulación
            if (fechaEvento.isAfter(startTime)) {
              marcadoATiempo = true;
              break;
            }
          }
        }

        // 4) Solo enviar notificación diferida si NO se marcó a tiempo
        if (!marcadoATiempo) {
          await LocalNoti.showDelayedWithActions(
            title: "¿Tomaste tu medicamento?",
            body: med,
            payload: "delayed|$id|$code|$nextHour|$med",
          );
        }
      },
      child: const Text(
        "Simular Notificación",
        style: TextStyle(fontSize: 18, color: Colors.white),
      ),
    );
  }

  // =========================================================================
  //  BOTÓN TOMAR ANTES (habilitado 1h antes y 1h después)
  // =========================================================================
  Widget _tomarAntesButton(BuildContext context, Map r) {
    // Calcular si el botón debe estar habilitado
    DateTime? nextTrigger;
    final rawNext = r["nextTrigger"];
    if (rawNext is DateTime) {
      nextTrigger = rawNext;
    } else if (rawNext is String) {
      nextTrigger = DateTime.tryParse(rawNext);
    }

    final now = DateTime.now();
    bool isEnabled = false;

    if (nextTrigger != null) {
      final oneHourBefore = nextTrigger.subtract(const Duration(hours: 1));
      final oneHourAfter = nextTrigger.add(const Duration(hours: 1));
      isEnabled = now.isAfter(oneHourBefore) && now.isBefore(oneHourAfter);
    }

    return GestureDetector(
      onTap: isEnabled
          ? () async {
              final freq = (r["frequencyHours"] ?? 24) as int;
              final id = r["id"] as int;
              final code = r["patientCode"] as String;
              final medication = r["medication"] as String;

              final now = DateTime.now();
              final next = now.add(Duration(hours: freq));

              // Actualiza la BD
              await DBHelper.updateNextTriggerById(id, next);

              // Registrar toma anticipada
              await DBHelper.registrarToma(
                idRecordatorio: id,
                estado: 'a_tiempo',
                fechaHoraReal: now,
              );

              // Reprogramar la siguiente notificación
              await LocalNoti.cancel(id);
              await LocalNoti.scheduleReminder(
                reminderId: id,
                code: code,
                medication: medication,
                scheduledTime: next,
              );

              AudioPlayerService.playSound("sounds/correct-ding.mp3");

              // POPUP para toma anticipada
              if (context.mounted) {
                showDialog(
                  context: context,
                  barrierDismissible: false,
                  builder: (ctx) => Dialog(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Ícono verde con estrella
                          Container(
                            width: 80,
                            height: 80,
                            decoration: BoxDecoration(
                              color: const Color(0xFF52B788),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: const Icon(
                              Icons.star,
                              color: Colors.white,
                              size: 48,
                            ),
                          ),
                          const SizedBox(height: 20),

                          // Título
                          const Text(
                            "¡Gracias por tu honestidad!",
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 12),

                          // Puntos ganados
                          const Text(
                            "Ganaste 15 puntos",
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF2E8B57),
                            ),
                          ),
                          const SizedBox(height: 12),

                          // Descripción
                          const Text(
                            "Agradecemos que informes tus tomas con sinceridad. Esto nos ayuda a cuidar mejor de ti.",
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.black87,
                              height: 1.4,
                            ),
                          ),
                          const SizedBox(height: 24),

                          // Botón "Ir a inicio"
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Color(0xFF2E8B57),
                                padding: const EdgeInsets.symmetric(
                                  vertical: 14,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                elevation: 0,
                              ),
                              onPressed: () {
                                Navigator.of(
                                  context,
                                ).popUntil((route) => route.isFirst);
                                Navigator.pushReplacement(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        PatientHomeScreen(code: code),
                                  ),
                                );
                              },
                              child: const Text(
                                "Ir a inicio",
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),

                          // Botón "Ver mis puntos"
                          TextButton(
                            onPressed: () {
                              Navigator.pop(ctx); // Cerrar dialog
                              Navigator.pop(context); // Cerrar reminder_details
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => PointsScreen(code: code),
                                ),
                              );
                            },
                            child: const Text(
                              "Ver mis puntos",
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w500,
                                color: Color(0xFF2E8B57),
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),

                          // Texto adicional
                          const Text(
                            "Podrás ver este cambio incluso si estás sin conexión.",
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.black54,
                              height: 1.3,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }
            }
          : null,
      child: Opacity(
        opacity: isEnabled ? 1.0 : 0.4,
        child: Container(
          width: 220,
          height: 220,
          decoration: BoxDecoration(
            color: isEnabled ? const Color(0xFF2E8B57) : Colors.grey,
            shape: BoxShape.circle,
          ),
          child: const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.check, color: Colors.white, size: 75),
                SizedBox(height: 10),
                Text(
                  "Tomar ahora",
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
    );
  }

  // =========================================================================
  // TARJETA CON DATOS DEL RECORDATORIO
  // =========================================================================
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
      builder: (_) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    "Nota",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                text.isEmpty ? "Sin notas" : text,
                style: const TextStyle(
                  fontSize: 14,
                  color: Colors.black87,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF52B788),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                  onPressed: () => Navigator.pop(context),
                  child: const Text(
                    "Entendido",
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
