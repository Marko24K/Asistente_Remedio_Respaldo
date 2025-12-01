import 'dart:async';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

class DBHelper {
  static Database? _db;

  // =========================================================
  //  INIT DB
  // =========================================================
  static Future<void> initDB() async {
    final path = join(await getDatabasesPath(), "asistente_remedios.db");

    _db = await openDatabase(
      path,
      version: 2,
      onCreate: (db, version) async {
        // ---------------- PACIENTES ----------------
        await db.execute("""
          CREATE TABLE pacientes (
            code TEXT PRIMARY KEY,
            nombre TEXT,
            rut TEXT,
            fecha_nacimiento TEXT,
            telefono TEXT,
            direccion TEXT,
            points INTEGER DEFAULT 0,
            nivel INTEGER DEFAULT 1
          );
        """);

        // ---------------- REDES DE APOYO ----------------
        await db.execute("""
          CREATE TABLE redes_apoyo (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            patientCode TEXT,
            nombre TEXT NOT NULL,
            correo TEXT,
            telefono TEXT,
            parentesco TEXT,
            FOREIGN KEY(patientCode) REFERENCES pacientes(code)
          );
        """);

        // ---------------- MEDICAMENTOS CATÁLOGO ---------
        await db.execute("""
          CREATE TABLE medicamentos (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            nombre TEXT NOT NULL
          );
        """);

        // ---------------- RECORDATORIOS -----------------
        await db.execute("""
          CREATE TABLE reminders (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            patientCode TEXT,
            medication TEXT,
            dose TEXT,
            type TEXT,
            hour TEXT,
            notes TEXT,
            startDate TEXT,
            endDate TEXT,
            frequencyHours INTEGER,
            nextTrigger TEXT,
            FOREIGN KEY(patientCode) REFERENCES pacientes(code)
          );
        """);

        // Tabla KPIs (tomado si/no)
        await db.execute("""
          CREATE TABLE kpis_tomas (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            reminderId INTEGER,
            patientCode TEXT,
            fecha TEXT,
            horaProgramada TEXT,
            respondio TEXT, -- "si" o "no"
            puntosOtorgados INTEGER,
            FOREIGN KEY(reminderId) REFERENCES reminders(id)
          );
        """);

        // ------------- LOGROS & NIVELES (FUTURO) ---------
        await db.execute("""
          CREATE TABLE logros (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            patientCode TEXT,
            nombre TEXT,
            descripcion TEXT,
            obtenido INTEGER DEFAULT 0
          );
        """);

        // ----------- Inserción manual de prueba -------
        await db.insert("pacientes", {
          "code": "A92KD7",
          "nombre": "Juan Pérez",
          "rut": "12.345.678-9",
          "fecha_nacimiento": "1949-04-18",
          "telefono": "+56912345678",
          "direccion": "Calle Falsa 123",
          "points": 0,
          "nivel": 1,
        });

        await db.insert("reminders", {
          "patientCode": "A92KD7",
          "medication": "Paracetamol",
          "dose": "1 tableta",
          "type": "Pastilla",
          "hour": "16:00",
          "notes": "Tomar con agua",
          "startDate": "2025-12-01",
          "endDate": "2025-12-24",
          "frequencyHours": 4,
          "nextTrigger": null,
        });
        await db.insert("reminders", {
          "patientCode": "A92KD7",
          "medication": "Omeprazol",
          "dose": "200g",
          "type": "Pastilla",
          "hour": "15:30",
          "notes": "Tomar con agua",
          "startDate": "2025-12-01",
          "endDate": "2025-12-24",
          "frequencyHours": 5,
          "nextTrigger": null,
        });
        await db.insert("reminders", {
          "patientCode": "A92KD7",
          "medication": "Loratadina",
          "dose": "200g",
          "type": "Pastilla",
          "hour": "15:20",
          "notes": "Tomar con agua",
          "startDate": "2025-12-01",
          "endDate": "2025-12-24",
          "frequencyHours": 1,
          "nextTrigger": null,
        });

        await db.insert("reminders", {
          "patientCode": "A92KD7",
          "medication": "Ibuprofeno",
          "dose": "5ml",
          "type": "líq",
          "hour": "14:30",
          "notes": "tomar al seco",
          "startDate": "2025-12-01",
          "endDate": "2025-12-24",
          "frequencyHours": 1,
          "nextTrigger": null,
        });
      },
    );
  }

  static Future<Database> get database async {
    if (_db != null) return _db!;
    await initDB();
    return _db!;
  }

  // =========================================================
  //  PACIENTES
  // =========================================================
  static Future<Map<String, dynamic>?> getPatient(String code) async {
    final db = await database;
    final res = await db.query(
      "pacientes",
      where: "code = ?",
      whereArgs: [code],
    );

    if (res.isEmpty) return null;
    return res.first;
  }

  static Future<int> updatePatient(
    Map<String, dynamic> data,
    String code,
  ) async {
    final db = await database;
    return db.update("pacientes", data, where: "code = ?", whereArgs: [code]);
  }

  // =========================================================
  //  REDES DE APOYO
  // =========================================================
  static Future<void> addSupportNetwork(
    String patientCode,
    String nombre,
    String correo,
    String telefono,
    String parentesco,
  ) async {
    final db = await database;
    await db.insert("redes_apoyo", {
      "patientCode": patientCode,
      "nombre": nombre,
      "correo": correo,
      "telefono": telefono,
      "parentesco": parentesco,
    });
  }

  static Future<List<Map<String, dynamic>>> getSupportNetwork(
    String code,
  ) async {
    final db = await database;
    return db.query("redes_apoyo", where: "patientCode = ?", whereArgs: [code]);
  }

  // =========================================================
  //  MEDICAMENTOS
  // =========================================================
  static Future<int> insertMedicamento(String nombre) async {
    final db = await database;
    return db.insert("medicamentos", {"nombre": nombre});
  }

  // =========================================================
  //  REMINDERS
  // =========================================================
  static Future<int> insertReminder(Map<String, dynamic> data) async {
    final db = await database;
    return db.insert("reminders", data);
  }

  // Obtener reminder por ID
  static Future<Map<String, dynamic>?> getReminderById(int id) async {
    final db = await database;
    final res = await db.query("reminders", where: "id = ?", whereArgs: [id]);
    if (res.isEmpty) return null;
    return res.first;
  }

  static Future<List<Map<String, dynamic>>> getReminders(String code) async {
    final db = await database;
    return db.query("reminders", where: "patientCode = ?", whereArgs: [code]);
  }

  // Actualizar nextTrigger (ISO8601)
  static Future<void> updateReminderNextTrigger(int id, String newDate) async {
    final db = await database;
    await db.update(
      "reminders",
      {"nextTrigger": newDate},
      where: "id = ?",
      whereArgs: [id],
    );
  }

  // Cálculo PROFESIONAL del próximo disparo
  static DateTime calculateNextTrigger(
    String hour,
    int frequencyHours, {
    String? startDate,
  }) {
    final now = DateTime.now();
    print('🔄 [CALC_TRIGGER] Calculando próximo disparo:');
    print('   Ahora: $now');
    print('   Hora indicada: $hour');
    print('   Frecuencia: $frequencyHours horas');
    print('   Fecha inicio: $startDate');

    if (frequencyHours <= 0) frequencyHours = 24; // seguridad

    // parse HH:mm
    final parts = hour.split(":");
    final h = int.parse(parts[0]);
    final m = int.parse(parts[1]);

    late DateTime base;

    // si hay fecha de inicio, usamos ese día + la hora
    if (startDate != null) {
      final sd = DateTime.tryParse(startDate);
      if (sd != null) {
        base = DateTime(sd.year, sd.month, sd.day, h, m);
        print('   Base desde startDate: $base');

        // si el tratamiento aún NO comienza, esa es la primera toma
        if (base.isAfter(now)) {
          print('✅ Primera toma (startDate en futuro): $base');
          return base;
        }
      } else {
        base = DateTime(now.year, now.month, now.day, h, m);
        print('   startDate inválido, usando hoy: $base');
      }
    } else {
      // sin fecha de inicio: hoy a la hora indicada
      base = DateTime(now.year, now.month, now.day, h, m);
      print('   Sin startDate, usando hoy: $base');
    }

    // avanzar ciclos hasta que quede en el futuro
    int ciclos = 0;
    while (base.isBefore(now) || base.isAtSameMomentAs(now)) {
      base = base.add(Duration(hours: frequencyHours));
      ciclos++;
    }

    print('   Ciclos avanzados: $ciclos');
    print('✅ Próximo disparo final: $base');

    return base;
  }

  static Future<void> updateNextTriggerById(int reminderId, DateTime dt) async {
    final db = await database;

    await db.update(
      "reminders",
      {"nextTrigger": dt.toIso8601String()},
      where: "id = ?",
      whereArgs: [reminderId],
    );
  }

  // =========================================================
  //  KPIs DE ADHERENCIA
  // =========================================================
  static Future<void> addKpi({
    required int reminderId,
    required String code,
    required String scheduledHour,
    required bool tomo,
    required int puntos,
  }) async {
    final db = await database;

    await db.insert("kpis_tomas", {
      "reminderId": reminderId,
      "patientCode": code,
      "fecha": DateTime.now().toIso8601String(),
      "horaProgramada": scheduledHour,
      "respondio": tomo ? "si" : "no",
      "puntosOtorgados": puntos,
    });
  }

  // =========================================================
  //  PUNTOS
  // =========================================================
  static Future<void> addPoints(int puntos, String code) async {
    final db = await database;

    await db.rawUpdate(
      """
      UPDATE pacientes
      SET points = points + ?
      WHERE code = ?
    """,
      [puntos, code],
    );
  }

  static Future<void> redeemPoints(int costo, String code) async {
    final db = await database;

    await db.rawUpdate(
      """
      UPDATE pacientes
      SET points = points - ?
      WHERE code = ? AND points >= ?
    """,
      [costo, code, costo],
    );
  }

  // =========================================================
  //  BORRAR BD (debug)
  // =========================================================
  static Future<void> clear() async {
    final db = await database;
    await db.delete("reminders");
    await db.delete("kpis_tomas");
    await db.delete("logros");
    await db.delete("redes_apoyo");
  }
}
