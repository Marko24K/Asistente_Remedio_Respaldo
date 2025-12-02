import 'package:flutter/material.dart';
import '../data/database_helper.dart';
import '../services/audio_player_service.dart';

class ImmediateTakeScreen extends StatelessWidget {
  final int reminderId;
  final String code;
  final String medication;
  final String hour;

  const ImmediateTakeScreen({
    super.key,
    required this.reminderId,
    required this.code,
    required this.medication,
    required this.hour,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              "A tomar $medication ahora",
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
              textAlign: TextAlign.center,
            ),

            const SizedBox(height: 30),

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

                // POPUP
                if (context.mounted) {
                  showDialog(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text("¡Excelente!"),
                      content: const Text(
                        "Has ganado +10 puntos por registrar tu toma. Vas muy bien",
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctx),
                          child: const Text("OK"),
                        ),
                      ],
                    ),
                  );
                }

                await Future.delayed(const Duration(seconds: 1));

                if (context.mounted) Navigator.pop(context, true);
              },
              child: Container(
                width: 180,
                height: 180,
                decoration: const BoxDecoration(
                  color: Color(0xFF2E8B57),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check, size: 70, color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
