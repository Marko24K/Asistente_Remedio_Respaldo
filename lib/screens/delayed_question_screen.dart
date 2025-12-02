import 'package:flutter/material.dart';
import '../data/database_helper.dart';
import '../services/audio_player_service.dart';

class DelayedQuestionScreen extends StatelessWidget {
  final int reminderId;
  final String code;
  final String medication;
  final String hour;

  const DelayedQuestionScreen({
    super.key,
    required this.reminderId,
    required this.code,
    required this.medication,
    required this.hour,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F5FB),
      body: Center(
        child: Container(
          margin: const EdgeInsets.all(24),
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                "Olvidaste marcar el $medication a las $hour.\n¿Lo tomaste?",
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 18),
              ),

              const SizedBox(height: 30),

              // BOTÓN SÍ
              GestureDetector(
                onTap: () async {
                  await DBHelper.addPoints(10, code);
                  await DBHelper.addTotalPoints(10, code);

                  await DBHelper.addKpi(
                    reminderId: reminderId,
                    code: code,
                    scheduledHour: hour,
                    tomo: true,
                    puntos: 10,
                  );

                  AudioPlayerService.playSound("sounds/correct-ding.mp3");

                  // Popup
                  if (context.mounted) {
                    showDialog(
                      context: context,
                      builder: (_) => const AlertDialog(
                        title: Text("¡Bien hecho!"),
                        content: Text("Has ganado +10 puntos. Tarde pero seguro bien hecho."),
                      ),
                    );
                  }

                  await Future.delayed(const Duration(seconds: 1));
                  if (context.mounted) Navigator.pop(context, true);
                },
                child: Container(
                  width: 160,
                  height: 160,
                  decoration: const BoxDecoration(
                    color: Color(0xFF2E8B57),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.check, size: 70, color: Colors.white),
                ),
              ),

              const SizedBox(height: 15),

              // BOTÓN NO
              GestureDetector(
                onTap: () async {
                  await DBHelper.addKpi(
                    reminderId: reminderId,
                    code: code,
                    scheduledHour: hour,
                    tomo: false,
                    puntos: 0,
                  );

                  AudioPlayerService.playSound("sounds/confirm-no.mp3");

                  if (context.mounted) {
                    showDialog(
                      context: context,
                      builder: (_) => const AlertDialog(
                        title: Text("Registro guardado"),
                        content: Text("Gracias por tu sinceridad. La próxima vez lo lograrás."),
                      ),
                    );
                  }

                  await Future.delayed(const Duration(seconds: 1));
                  if (context.mounted) Navigator.pop(context, true);
                },
                child: Container(
                  width: 160,
                  height: 160,
                  decoration: const BoxDecoration(
                    color: Color(0xFFE57373),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.close, size: 70, color: Colors.white),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
