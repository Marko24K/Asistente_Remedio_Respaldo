import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'data/database_helper.dart';
import 'screens/welcome_screen.dart';
import 'screens/patient_home_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Inicializar BD
  await DBHelper.initDB();

  // Revisar si ya aceptó permisos
  final prefs = await SharedPreferences.getInstance();
  final accepted = prefs.getBool("accepted_permissions") ?? false;

  runApp(MyApp(
    acceptedPermissions: accepted,
  ));
}

class MyApp extends StatelessWidget {
  final bool acceptedPermissions;
  const MyApp({super.key, required this.acceptedPermissions});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: "Asistente Remedios",
      theme: ThemeData(
        primarySwatch: Colors.indigo,
        fontFamily: "Roboto",
      ),
      home: acceptedPermissions
          ? PatientHomeScreen(code: "A92KD7")
          : WelcomeScreen(),
    );
  }
}
