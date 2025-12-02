import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'patient_home_screen.dart';

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  bool requesting = false;

  Future<void> _requestPermissions() async {
    setState(() => requesting = true);

    // Solicitar permiso de notificación
    await Permission.notification.request();

    // Guardar que ya se aceptaron permisos (aunque los niegue)
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool("accepted_permissions", true);

    // Ir al home
    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => PatientHomeScreen(code: "A92KD7"),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.indigo[50],
      body: Center(
        child: requesting
            ? const CircularProgressIndicator()
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.medical_services_outlined,
                      size: 90, color: Colors.indigo),
                  const SizedBox(height: 20),
                  const Text(
                    "Bienvenido a Asistente Remedios",
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 30),
                    child: Text(
                      "Necesitamos permiso para mostrar tus recordatorios de medicamentos.",
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 16),
                    ),
                  ),
                  const SizedBox(height: 30),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.notifications),
                    label: const Text("Permitir Notificaciones"),
                    onPressed: _requestPermissions,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 14),
                    ),
                  )
                ],
              ),
      ),
    );
  }
}
