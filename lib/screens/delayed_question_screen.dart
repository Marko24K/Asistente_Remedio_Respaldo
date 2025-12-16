import 'package:flutter/material.dart';
import '../data/database_helper.dart';
import '../services/audio_player_service.dart';
import 'patient_home_screen.dart';
import 'points_screen.dart';

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
                  // Registrar toma tardía
                  await DBHelper.registrarToma(
                    idRecordatorio: reminderId,
                    estado: 'tardio',
                    fechaHoraReal: DateTime.now(),
                  );

                  AudioPlayerService.playSound("sounds/correct-ding.mp3");

                  // Popup para toma tardía (SÍ)
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
                                "Ganaste 5 puntos",
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF52B788),
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
                                    backgroundColor: const Color(0xFF52B788),
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
                                  Navigator.of(
                                    context,
                                  ).popUntil((route) => route.isFirst);
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
                                    color: Color(0xFF52B788),
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
                  // Registrar omisión
                  await DBHelper.registrarToma(
                    idRecordatorio: reminderId,
                    estado: 'omitido',
                    motivoOmision: 'Usuario indicó no tomar',
                  );

                  AudioPlayerService.playSound("sounds/confirm-no.mp3");

                  // Popup para omisión (NO)
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
                              // Ícono rojo con corazón
                              Container(
                                width: 80,
                                height: 80,
                                decoration: BoxDecoration(
                                  color: const Color(0xFFD36B77),
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: const Icon(
                                  Icons.favorite,
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

                              // Sin puntos
                              const Text(
                                "0 puntos en esta ocasión",
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.black87,
                                ),
                              ),
                              const SizedBox(height: 12),

                              // Descripción
                              const Text(
                                "Agradecemos que nos cuentes la verdad sobre tus tomas. La próxima vez intentemos juntos no olvidar tu medicación.",
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
                                    backgroundColor: const Color(0xFF52B788),
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
                                  Navigator.of(
                                    context,
                                  ).popUntil((route) => route.isFirst);
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
                                    color: Color(0xFF52B788),
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
