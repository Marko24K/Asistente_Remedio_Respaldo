import 'dart:io';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../data/database_helper.dart';

class PointsScreen extends StatefulWidget {
  final String code;

  const PointsScreen({super.key, required this.code});

  @override
  State<PointsScreen> createState() => _PointsScreenState();
}

class _PointsScreenState extends State<PointsScreen> {
  int puntos = 0;
  int totalPoints = 0;
  int metaNivel = 100;
  int nivel = 1;

  bool loading = true;
  bool isOffline = false;

  final List<Map<String, dynamic>> recompensas = [
    {"nombre": "10% en farmacia aliada", "costo": 100},
    {"nombre": "Organizador de pastillas semanal", "costo": 150},
    {"nombre": "Control de salud en casa", "costo": 200},
    {"nombre": "Kit bienestar", "costo": 250},
    {"nombre": "Termómetro digital premium", "costo": 300},
  ];

  @override
  void initState() {
    super.initState();
    loadPoints();
    checkConnection();
  }

  Future<void> checkConnection() async {
    try {
      final result = await InternetAddress.lookup("google.com");
      setState(() => isOffline = result.isEmpty);
    } catch (_) {
      setState(() => isOffline = true);
    }
  }

  Future<void> loadPoints() async {
    final p = await DBHelper.getPatient(widget.code);
    puntos = p?["points"] ?? 0;
    totalPoints = p?["totalPoints"] ?? puntos;

    nivel = (totalPoints ~/ metaNivel) + 1;

    setState(() => loading = false);
  }

  Future<void> canjear(int costo, String nombre) async {
    if (puntos < costo) return;

    await DBHelper.addPoints(-costo, widget.code);
    await loadPoints();

    // ignore: use_build_context_synchronously
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          "Canjeaste: $nombre 🎉",
          style: const TextStyle(fontSize: 17),
        ),
        backgroundColor: Colors.green.shade700,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F4),

      bottomNavigationBar: _bottomNav(),

      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          "Mis Puntos",
          style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),

      body: loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  if (isOffline) _offlineBanner(),

                  const SizedBox(height: 16),

                  _cardPuntos(), // tarjeta principal centrada

                  const SizedBox(height: 22),

                  _cardProgreso(), // tarjeta progreso nivel

                  const SizedBox(height: 22),

                  _cardRecompensas(), // tarjeta recompensas

                  const SizedBox(height: 90),
                ],
              ),
            ),
    );
  }

  // ------------------- BANNER OFFLINE -------------------
  Widget _offlineBanner() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF4CC),
        borderRadius: BorderRadius.circular(10),
      ),
      child: const Row(
        children: [
          Icon(Icons.wifi_off, color: Colors.black54),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              "Sin conexión. Tus datos se sincronizarán al volver a estar en línea.",
              style: TextStyle(fontSize: 15),
            ),
          ),
        ],
      ),
    );
  }

  // ------------------- TARJETA DE PUNTOS -------------------
  Widget _cardPuntos() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        children: [
          const Text(
            "¡Vas muy bien!",
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1B4332),
            ),
          ),
          const SizedBox(height: 16),

          // Número de puntos
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFE6F4EA),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text(
              "$puntos puntos",
              style: const TextStyle(
                fontSize: 34,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1B4332),
              ),
            ),
          ),

          const SizedBox(height: 10),
          const Text(
            "Estás avanzando hacia tu próxima recompensa.",
            style: TextStyle(fontSize: 16, color: Colors.black54),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  // ------------------- TARJETA PROGRESO -------------------
  Widget _cardProgreso() {
    double progreso = (totalPoints % metaNivel) / metaNivel;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Progreso al próximo nivel",
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 18),

          LinearProgressIndicator(
            value: progreso,
            color: const Color(0xFF2D6A4F),
            backgroundColor: Colors.grey.shade300,
            minHeight: 14,
            borderRadius: BorderRadius.circular(10),
          ),

          const SizedBox(height: 10),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "Actual: $totalPoints pts",
                style: const TextStyle(fontSize: 15),
              ),
              Text(
                "Nivel $nivel",
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ------------------- TARJETA RECOMPENSAS -------------------
  Widget _cardRecompensas() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Recompensas disponibles",
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 18),

          for (var r in recompensas) _rewardItem(r),
        ],
      ),
    );
  }

  Widget _rewardItem(Map<String, dynamic> r) {
    final nombre = r["nombre"];
    final costo = r["costo"];
    final disponible = puntos >= costo;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF2F7F3),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(
            Icons.card_giftcard,
            size: 40,
            color: disponible ? Colors.green.shade800 : Colors.grey,
          ),

          const SizedBox(width: 16),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  nombre,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  disponible
                      ? "¡Disponible para canjear!"
                      : "Necesitas ${costo - puntos} pts",
                  style: TextStyle(
                    color: disponible ? Colors.green.shade700 : Colors.black54,
                    fontSize: 15,
                  ),
                ),
              ],
            ),
          ),

          ElevatedButton(
            onPressed: disponible ? () => canjear(costo, nombre) : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: disponible
                  ? Colors.green.shade700
                  : Colors.grey.shade400,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text(
              "Canjear",
              style: TextStyle(color: Colors.white, fontSize: 15),
            ),
          ),
        ],
      ),
    );
  }

  // ------------------- NAV INFERIOR -------------------
  Widget _bottomNav() {
    return Container(
      height: 72,
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.grey.shade300)),
      ),
      child: Row(
        children: [
          _navItem(
            icon: FontAwesomeIcons.pills,
            label: "Remedios",
            active: false,
            onTap: () {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (_) => PatientHomeScreen(patientCode: widget.code),
                ),
              );
            },
          ),
          _navItem(
            icon: FontAwesomeIcons.star,
            label: "Puntos",
            active: true,
            onTap: () {},
          ),
        ],
      ),
    );
  }

  Widget _navItem({
    required IconData icon,
    required String label,
    required bool active,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            FaIcon(
              icon,
              size: 22,
              color: active ? Colors.green.shade800 : Colors.grey.shade600,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: active ? Colors.green.shade800 : Colors.grey.shade600,
                fontWeight: active ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
