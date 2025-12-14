import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'data/database_helper.dart';
import 'services/local_notifications.dart';

import 'screens/welcome_screen.dart';
import 'screens/patient_home_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Inicializar BD
  await DBHelper.initDB();

  // Cargar medicamentos desde JSON (solo primera vez)
  await DBHelper.cargarMedicamentosDesdeJSON();

  // Inicializar notificaciones
  await LocalNoti.init();

  // Leer permisos guardados
  final prefs = await SharedPreferences.getInstance();
  final accepted = prefs.getBool("accepted_permissions") ?? false;

  runApp(MyApp(acceptedPermissions: accepted));
}

class MyApp extends StatelessWidget {
  final bool acceptedPermissions;
  const MyApp({super.key, required this.acceptedPermissions});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      navigatorKey: LocalNoti.navKey, // <<< AÑADIDO
      title: "Asistente Remedios",
      theme: ThemeData(primarySwatch: Colors.indigo, fontFamily: "Roboto"),
      home: acceptedPermissions
          ? PatientHomeScreen(code: "A92KD7")
          : WelcomeScreen(),
    );
  }
}
