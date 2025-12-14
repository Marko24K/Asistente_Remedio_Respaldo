import 'dart:async';
import 'dart:convert';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'dart:math' as math;
import 'package:flutter/services.dart' show rootBundle;

class DBHelper {
  static Database? _db;

  // =========================================================
  //  INIT DB
  // =========================================================
  static Future<void> initDB() async {
    final path = join(await getDatabasesPath(), "asistente_remedios.db");

    _db = await openDatabase(
      path,
      version: 3,
      onCreate: (db, version) async {
        // ---------------- BENEFICIARIOS ----------------
        await db.execute("""
          CREATE TABLE beneficiario (
            id_beneficiario INTEGER PRIMARY KEY AUTOINCREMENT,
            codigo_unico TEXT UNIQUE NOT NULL,
            nombre_completo TEXT NOT NULL,
            rut TEXT UNIQUE NOT NULL,
            fecha_nacimiento TEXT NOT NULL,
            telefono TEXT,
            direccion TEXT,
            created_at TEXT DEFAULT CURRENT_TIMESTAMP
          );
        """);

        // ---------------- PERFIL GAMIFICACIÓN ----------------
        await db.execute("""
          CREATE TABLE perfil_gamificacion (
            id_gamificacion INTEGER PRIMARY KEY AUTOINCREMENT,
            id_beneficiario INTEGER UNIQUE NOT NULL,
            puntos_actuales INTEGER NOT NULL DEFAULT 0,
            xp_total INTEGER NOT NULL DEFAULT 0,
            nivel INTEGER NOT NULL DEFAULT 1,
            updated_at TEXT DEFAULT CURRENT_TIMESTAMP,
            FOREIGN KEY(id_beneficiario) REFERENCES beneficiario(id_beneficiario) ON DELETE CASCADE,
            CHECK (puntos_actuales >= 0),
            CHECK (xp_total >= 0),
            CHECK (nivel >= 1)
          );
        """);

        // ---------------- REDES DE APOYO ----------------
        await db.execute("""
          CREATE TABLE redes_apoyo (
            id_red INTEGER PRIMARY KEY AUTOINCREMENT,
            id_beneficiario INTEGER NOT NULL,
            nombre TEXT NOT NULL,
            telefono TEXT,
            parentesco TEXT,
            created_at TEXT DEFAULT CURRENT_TIMESTAMP,
            FOREIGN KEY(id_beneficiario) REFERENCES beneficiario(id_beneficiario) ON DELETE CASCADE
          );
        """);

        // ---------------- MEDICAMENTOS CATÁLOGO ----------------
        await db.execute("""
          CREATE TABLE medicamentos (
            id_medicamento INTEGER PRIMARY KEY AUTOINCREMENT,
            nombre TEXT UNIQUE NOT NULL,
            forma_farmaceutica TEXT,
            created_at TEXT DEFAULT CURRENT_TIMESTAMP
          );
        """);

        // ---------------- RECORDATORIOS ----------------
        await db.execute("""
          CREATE TABLE recordatorios (
            id_recordatorio INTEGER PRIMARY KEY AUTOINCREMENT,
            id_beneficiario INTEGER NOT NULL,
            id_medicamento INTEGER NOT NULL,
            dosis TEXT NOT NULL,
            tipo_medicamento TEXT,
            hora TEXT NOT NULL,
            frecuencia_horas INTEGER NOT NULL,
            fecha_inicio TEXT NOT NULL,
            fecha_fin TEXT,
            notas TEXT,
            activo INTEGER DEFAULT 1,
            nextTrigger TEXT,
            created_at TEXT DEFAULT CURRENT_TIMESTAMP,
            FOREIGN KEY(id_beneficiario) REFERENCES beneficiario(id_beneficiario) ON DELETE CASCADE,
            FOREIGN KEY(id_medicamento) REFERENCES medicamentos(id_medicamento) ON DELETE RESTRICT,
            CHECK (frecuencia_horas > 0)
          );
        """);

        // ---------------- EVENTOS DE TOMA (FUENTE DE VERDAD) ----------------
        await db.execute("""
          CREATE TABLE eventos_toma (
            id_evento INTEGER PRIMARY KEY AUTOINCREMENT,
            id_recordatorio INTEGER NOT NULL,
            fecha_hora_programada TEXT NOT NULL,
            fecha_hora_real TEXT,
            estado TEXT NOT NULL,
            puntos_obtenidos INTEGER NOT NULL DEFAULT 0,
            xp_obtenido INTEGER NOT NULL DEFAULT 0,
            motivo_omision TEXT,
            notificacion_enviada INTEGER DEFAULT 0,
            intentos_notificacion INTEGER DEFAULT 0,
            created_at TEXT DEFAULT CURRENT_TIMESTAMP,
            FOREIGN KEY(id_recordatorio) REFERENCES recordatorios(id_recordatorio) ON DELETE RESTRICT,
            CHECK (estado IN ('a_tiempo', 'tardio', 'omitido', 'no_respondio')),
            CHECK (puntos_obtenidos >= 0),
            CHECK (xp_obtenido >= 0)
          );
        """);

        // ---------------- LOGROS ----------------
        await db.execute("""
          CREATE TABLE logros (
            id_logro INTEGER PRIMARY KEY AUTOINCREMENT,
            nombre TEXT NOT NULL,
            descripcion TEXT,
            icono TEXT,
            xp_requerido INTEGER DEFAULT 0,
            puntos_bonus INTEGER DEFAULT 0,
            tipo_condicion TEXT NOT NULL,
            parametro TEXT,
            created_at TEXT DEFAULT CURRENT_TIMESTAMP,
            CHECK (xp_requerido >= 0)
          );
        """);

        // ---------------- BENEFICIARIO_LOGRO ----------------
        await db.execute("""
          CREATE TABLE beneficiario_logro (
            id_benef_logro INTEGER PRIMARY KEY AUTOINCREMENT,
            id_beneficiario INTEGER NOT NULL,
            id_logro INTEGER NOT NULL,
            fecha_obtenido TEXT DEFAULT CURRENT_TIMESTAMP,
            FOREIGN KEY(id_beneficiario) REFERENCES beneficiario(id_beneficiario) ON DELETE CASCADE,
            FOREIGN KEY(id_logro) REFERENCES logros(id_logro) ON DELETE CASCADE,
            UNIQUE(id_beneficiario, id_logro)
          );
        """);

        // ---------------- RECOMPENSAS ----------------
        await db.execute("""
          CREATE TABLE recompensa (
            id_recompensa INTEGER PRIMARY KEY AUTOINCREMENT,
            nombre_recompensa TEXT NOT NULL,
            descripcion TEXT,
            puntos_requeridos INTEGER NOT NULL,
            disponible INTEGER DEFAULT 1,
            tipo TEXT,
            created_at TEXT DEFAULT CURRENT_TIMESTAMP,
            CHECK (puntos_requeridos > 0)
          );
        """);

        // ---------------- BENEFICIARIO_RECOMPENSA ----------------
        await db.execute("""
          CREATE TABLE beneficiario_recompensa (
            id_benef_recom INTEGER PRIMARY KEY AUTOINCREMENT,
            id_beneficiario INTEGER NOT NULL,
            id_recompensa INTEGER NOT NULL,
            fecha_canje TEXT DEFAULT CURRENT_TIMESTAMP,
            puntos_utilizados INTEGER NOT NULL,
            estado_entrega TEXT DEFAULT 'pendiente',
            FOREIGN KEY(id_beneficiario) REFERENCES beneficiario(id_beneficiario) ON DELETE CASCADE,
            FOREIGN KEY(id_recompensa) REFERENCES recompensa(id_recompensa) ON DELETE RESTRICT,
            CHECK (puntos_utilizados > 0)
          );
        """);

        // ---------------- ÍNDICES ----------------
        await db.execute(
          "CREATE INDEX idx_beneficiario_codigo ON beneficiario(codigo_unico);",
        );
        await db.execute(
          "CREATE INDEX idx_perfil_beneficiario ON perfil_gamificacion(id_beneficiario);",
        );
        await db.execute(
          "CREATE INDEX idx_redes_beneficiario ON redes_apoyo(id_beneficiario);",
        );
        await db.execute(
          "CREATE INDEX idx_recordatorio_beneficiario ON recordatorios(id_beneficiario);",
        );
        await db.execute(
          "CREATE INDEX idx_recordatorio_activo ON recordatorios(activo);",
        );
        await db.execute(
          "CREATE INDEX idx_eventos_recordatorio ON eventos_toma(id_recordatorio);",
        );
        await db.execute(
          "CREATE INDEX idx_eventos_programada ON eventos_toma(fecha_hora_programada);",
        );
        await db.execute(
          "CREATE INDEX idx_eventos_estado ON eventos_toma(estado);",
        );

        // ---------------- DATOS DE PRUEBA ----------------
        final idBenef = await db.insert("beneficiario", {
          "codigo_unico": "A92KD7",
          "nombre_completo": "Juan Pérez",
          "rut": "12.345.678-9",
          "fecha_nacimiento": "1949-04-18",
          "telefono": "+56912345678",
          "direccion": "Calle Falsa 123",
        });

        await db.insert("perfil_gamificacion", {
          "id_beneficiario": idBenef,
          "puntos_actuales": 0,
          "xp_total": 0,
          "nivel": 1,
        });

        // Medicamentos
        final idMed1 = await db.insert("medicamentos", {
          "nombre": "Paracetamol",
          "forma_farmaceutica": "Pastilla",
        });
        final idMed2 = await db.insert("medicamentos", {
          "nombre": "Omeprazol",
          "forma_farmaceutica": "Pastilla",
        });
        final idMed3 = await db.insert("medicamentos", {
          "nombre": "Amoxicilina",
          "forma_farmaceutica": "Jarabe",
        });
        final idMed4 = await db.insert("medicamentos", {
          "nombre": "Ibuprofeno",
          "forma_farmaceutica": "Líquido",
        });

        // Recordatorios
        await db.insert("recordatorios", {
          "id_beneficiario": idBenef,
          "id_medicamento": idMed1,
          "dosis": "500 mg",
          "tipo_medicamento": "Pastilla",
          "hora": "09:40",
          "frecuencia_horas": 4,
          "fecha_inicio": "2025-12-02",
          "fecha_fin": "2025-12-24",
          "notas": "Tomar con agua",
          "activo": 1,
        });

        await db.insert("recordatorios", {
          "id_beneficiario": idBenef,
          "id_medicamento": idMed2,
          "dosis": "200 mg",
          "tipo_medicamento": "Pastilla",
          "hora": "15:30",
          "frecuencia_horas": 6,
          "fecha_inicio": "2025-12-01",
          "fecha_fin": "2025-12-24",
          "notas": "Tomar con agua",
          "activo": 1,
        });

        await db.insert("recordatorios", {
          "id_beneficiario": idBenef,
          "id_medicamento": idMed3,
          "dosis": "2 ml",
          "tipo_medicamento": "Jarabe",
          "hora": "08:50",
          "frecuencia_horas": 4,
          "fecha_inicio": "2025-12-02",
          "fecha_fin": "2025-12-24",
          "notas": "Tomar con agua",
          "activo": 1,
        });

        await db.insert("recordatorios", {
          "id_beneficiario": idBenef,
          "id_medicamento": idMed4,
          "dosis": "5 ml",
          "tipo_medicamento": "Líquido",
          "hora": "14:30",
          "frecuencia_horas": 8,
          "fecha_inicio": "2025-12-01",
          "fecha_fin": "2025-12-24",
          "notas": "Tomar al seco",
          "activo": 1,
        });

        // Recompensas
        await db.insert("recompensa", {
          "nombre_recompensa": "10% descuento en farmacia aliada",
          "descripcion": "Cupón de descuento",
          "puntos_requeridos": 100,
          "disponible": 1,
          "tipo": "descuento",
        });
        await db.insert("recompensa", {
          "nombre_recompensa": "Organizador de pastillas semanal",
          "descripcion": "Pastillero de 7 días",
          "puntos_requeridos": 150,
          "disponible": 1,
          "tipo": "fisica",
        });
        await db.insert("recompensa", {
          "nombre_recompensa": "Control de salud en casa",
          "descripcion": "Visita de enfermera",
          "puntos_requeridos": 200,
          "disponible": 1,
          "tipo": "servicio",
        });
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 3) {
          // Migración desde versión antigua
          // (Aquí iría lógica de migración completa si es necesario)
        }
      },
    );
  }

  static Future<Database> get database async {
    if (_db != null) return _db!;
    await initDB();
    return _db!;
  }

  // =========================================================
  //  BENEFICIARIOS
  // =========================================================
  static Future<Map<String, dynamic>?> getBeneficiario(
    String codigoUnico,
  ) async {
    final db = await database;
    final res = await db.query(
      "beneficiario",
      where: "codigo_unico = ?",
      whereArgs: [codigoUnico],
    );

    if (res.isEmpty) return null;
    return res.first;
  }

  static Future<int?> getBeneficiarioId(String codigoUnico) async {
    final benef = await getBeneficiario(codigoUnico);
    return benef?['id_beneficiario'] as int?;
  }

  static Future<int> updateBeneficiario(
    Map<String, dynamic> data,
    String codigoUnico,
  ) async {
    final db = await database;
    return db.update(
      "beneficiario",
      data,
      where: "codigo_unico = ?",
      whereArgs: [codigoUnico],
    );
  }

  // =========================================================
  //  PERFIL GAMIFICACIÓN
  // =========================================================
  static Future<Map<String, dynamic>?> getPerfilGamificacion(
    String codigoUnico,
  ) async {
    final db = await database;
    final idBenef = await getBeneficiarioId(codigoUnico);
    if (idBenef == null) return null;

    final res = await db.query(
      "perfil_gamificacion",
      where: "id_beneficiario = ?",
      whereArgs: [idBenef],
    );

    if (res.isEmpty) return null;

    // Calcular nivel desde XP
    final xp = res.first['xp_total'] as int;
    final nivel = calculateNivel(xp);

    return {
      ...res.first,
      'nivel': nivel, // nivel derivado
    };
  }

  // Fórmula: nivel = floor(sqrt(xp_total / 100)) + 1
  static int calculateNivel(int xpTotal) {
    return (math.sqrt(xpTotal / 100.0)).floor() + 1;
  }

  // XP requerido para alcanzar un nivel
  static int xpParaNivel(int nivel) {
    return ((nivel - 1) * (nivel - 1) * 100).toInt();
  }

  // =========================================================
  //  REDES DE APOYO
  // =========================================================
  static Future<void> addSupportNetwork(
    String codigoUnico,
    String nombre,
    String telefono,
    String parentesco,
  ) async {
    final db = await database;
    final idBenef = await getBeneficiarioId(codigoUnico);
    if (idBenef == null) return;

    await db.insert("redes_apoyo", {
      "id_beneficiario": idBenef,
      "nombre": nombre,
      "telefono": telefono,
      "parentesco": parentesco,
    });
  }

  static Future<List<Map<String, dynamic>>> getSupportNetwork(
    String codigoUnico,
  ) async {
    final db = await database;
    final idBenef = await getBeneficiarioId(codigoUnico);
    if (idBenef == null) return [];

    return db.query(
      "redes_apoyo",
      where: "id_beneficiario = ?",
      whereArgs: [idBenef],
    );
  }

  // =========================================================
  //  MEDICAMENTOS
  // =========================================================
  static Future<int> insertMedicamento(String nombre) async {
    final db = await database;
    return db.insert("medicamentos", {"nombre": nombre});
  }

  static Future<int?> getMedicamentoId(String nombre) async {
    final db = await database;
    final res = await db.query(
      "medicamentos",
      where: "nombre = ?",
      whereArgs: [nombre],
      limit: 1,
    );

    if (res.isEmpty) return null;
    return res.first['id_medicamento'] as int;
  }

  /// Cargar medicamentos desde JSON (solo se ejecuta una vez)
  static Future<void> cargarMedicamentosDesdeJSON() async {
    final db = await database;

    // Verificar si ya se cargaron los medicamentos
    final count = await db.rawQuery(
      "SELECT COUNT(*) as total FROM medicamentos",
    );
    final total = count.first['total'] as int;

    // Si ya hay más de 10 medicamentos (considerando los 4 de prueba + otros), no cargar
    if (total > 10) {
      print("✅ Medicamentos ya cargados. Total: $total");
      return;
    }

    try {
      // Leer el archivo JSON
      final jsonString = await rootBundle.loadString(
        'assets/medicamentos/medicamentos_cl.json',
      );
      final List<dynamic> medicamentos = json.decode(jsonString);

      print("📦 Cargando ${medicamentos.length} medicamentos desde JSON...");

      // Insertar cada medicamento (ignorar duplicados)
      int insertados = 0;
      for (final nombreMed in medicamentos) {
        try {
          await db.insert(
            "medicamentos",
            {"nombre": nombreMed.toString()},
            conflictAlgorithm: ConflictAlgorithm.ignore, // Ignora si ya existe
          );
          insertados++;
        } catch (e) {
          // Ignorar errores de duplicados
          continue;
        }
      }

      print("✅ $insertados medicamentos insertados correctamente");
    } catch (e) {
      print("❌ Error al cargar medicamentos: $e");
    }
  }

  static Future<List<Map<String, dynamic>>> getAllMedicamentos() async {
    final db = await database;
    return db.query("medicamentos", orderBy: "nombre ASC");
  }

  // =========================================================
  //  RECORDATORIOS
  // =========================================================
  static Future<int> insertReminder(Map<String, dynamic> data) async {
    final db = await database;
    return db.insert("recordatorios", data);
  }

  static Future<Map<String, dynamic>?> getReminderById(int id) async {
    final db = await database;
    final res = await db.query(
      "recordatorios",
      where: "id_recordatorio = ?",
      whereArgs: [id],
    );
    if (res.isEmpty) return null;
    return res.first;
  }

  static Future<List<Map<String, dynamic>>> getReminders(
    String codigoUnico,
  ) async {
    final db = await database;
    final idBenef = await getBeneficiarioId(codigoUnico);
    if (idBenef == null) return [];

    final recordatorios = await db.query(
      "recordatorios",
      where: "id_beneficiario = ? AND activo = 1",
      whereArgs: [idBenef],
    );

    // Enriquecer con nombre del medicamento
    List<Map<String, dynamic>> result = [];
    for (var r in recordatorios) {
      final idMed = r['id_medicamento'] as int;
      final med = await db.query(
        "medicamentos",
        where: "id_medicamento = ?",
        whereArgs: [idMed],
      );

      result.add({
        ...r,
        'medication': med.isNotEmpty ? med.first['nombre'] : 'Desconocido',
        'id': r['id_recordatorio'],
        'dose': r['dosis'],
        'type': r['tipo_medicamento'],
        'hour': r['hora'],
        'notes': r['notas'],
        'startDate': r['fecha_inicio'],
        'endDate': r['fecha_fin'],
        'frequencyHours': r['frecuencia_horas'],
        'nextTrigger': r['nextTrigger'],
      });
    }

    return result;
  }

  static Future<void> updateReminderNextTrigger(int id, String newDate) async {
    final db = await database;
    await db.update(
      "recordatorios",
      {"nextTrigger": newDate},
      where: "id_recordatorio = ?",
      whereArgs: [id],
    );
  }

  // Cálculo del próximo disparo
  static DateTime calculateNextTrigger(
    String hour,
    int frequencyHours, {
    String? startDate,
  }) {
    final now = DateTime.now();

    if (frequencyHours <= 0) frequencyHours = 24;

    final parts = hour.split(":");
    final h = int.parse(parts[0]);
    final m = int.parse(parts[1]);

    late DateTime base;

    if (startDate != null) {
      final sd = DateTime.tryParse(startDate);
      if (sd != null) {
        base = DateTime(sd.year, sd.month, sd.day, h, m);

        if (base.isAfter(now)) {
          return base;
        }
      } else {
        base = DateTime(now.year, now.month, now.day, h, m);
      }
    } else {
      base = DateTime(now.year, now.month, now.day, h, m);
    }

    while (base.isBefore(now) || base.isAtSameMomentAs(now)) {
      base = base.add(Duration(hours: frequencyHours));
    }

    return base;
  }

  static Future<void> updateNextTriggerById(int reminderId, DateTime dt) async {
    final db = await database;

    await db.update(
      "recordatorios",
      {"nextTrigger": dt.toIso8601String()},
      where: "id_recordatorio = ?",
      whereArgs: [reminderId],
    );
  }

  // =========================================================
  //  EVENTOS DE TOMA (FUENTE DE VERDAD)
  // =========================================================

  /// Registrar evento de toma con cálculo automático de puntos/XP
  /// Estados: 'a_tiempo', 'tardio', 'omitido', 'no_respondio'
  static Future<void> registrarToma({
    required int idRecordatorio,
    required String estado,
    String? motivoOmision,
    DateTime? fechaHoraReal,
  }) async {
    final db = await database;

    // Calcular puntos y XP según estado
    int puntos = 0;
    int xp = 0;

    switch (estado) {
      case 'a_tiempo':
        puntos = 10;
        xp = 10;
        break;
      case 'tardio':
        puntos = 5;
        xp = 5;
        break;
      case 'omitido':
      case 'no_respondio':
        puntos = 0;
        xp = 0;
        break;
    }

    // Obtener recordatorio para saber el beneficiario
    final recordatorio = await getReminderById(idRecordatorio);
    if (recordatorio == null) return;

    final idBenef = recordatorio['id_beneficiario'] as int;

    // Insertar evento
    await db.insert("eventos_toma", {
      "id_recordatorio": idRecordatorio,
      "fecha_hora_programada": DateTime.now().toIso8601String(),
      "fecha_hora_real": fechaHoraReal?.toIso8601String(),
      "estado": estado,
      "puntos_obtenidos": puntos,
      "xp_obtenido": xp,
      "motivo_omision": motivoOmision,
      "notificacion_enviada": 1,
    });

    // Actualizar perfil de gamificación si obtuvo puntos/xp
    if (puntos > 0 || xp > 0) {
      await db.rawUpdate(
        """
        UPDATE perfil_gamificacion
        SET puntos_actuales = puntos_actuales + ?,
            xp_total = xp_total + ?,
            updated_at = CURRENT_TIMESTAMP
        WHERE id_beneficiario = ?
      """,
        [puntos, xp, idBenef],
      );

      // Actualizar nivel automáticamente
      final perfil = await db.query(
        "perfil_gamificacion",
        where: "id_beneficiario = ?",
        whereArgs: [idBenef],
      );

      if (perfil.isNotEmpty) {
        final xpTotal = perfil.first['xp_total'] as int;
        final nuevoNivel = calculateNivel(xpTotal);

        await db.update(
          "perfil_gamificacion",
          {"nivel": nuevoNivel},
          where: "id_beneficiario = ?",
          whereArgs: [idBenef],
        );
      }
    }
  }

  /// Obtener historial de eventos de toma
  static Future<List<Map<String, dynamic>>> getEventosToma(
    String codigoUnico, {
    int limit = 50,
  }) async {
    final db = await database;
    final idBenef = await getBeneficiarioId(codigoUnico);
    if (idBenef == null) return [];

    return await db.rawQuery(
      """
      SELECT e.*, r.hora, m.nombre as medicamento
      FROM eventos_toma e
      JOIN recordatorios r ON e.id_recordatorio = r.id_recordatorio
      JOIN medicamentos m ON r.id_medicamento = m.id_medicamento
      WHERE r.id_beneficiario = ?
      ORDER BY e.fecha_hora_programada DESC
      LIMIT ?
    """,
      [idBenef, limit],
    );
  }

  /// Calcular adherencia (%)
  static Future<double> calcularAdherencia(
    String codigoUnico, {
    int dias = 30,
  }) async {
    final db = await database;
    final idBenef = await getBeneficiarioId(codigoUnico);
    if (idBenef == null) return 0.0;

    final fechaInicio = DateTime.now().subtract(Duration(days: dias));

    final result = await db.rawQuery(
      """
      SELECT 
        COUNT(*) as total,
        COUNT(CASE WHEN estado IN ('a_tiempo', 'tardio') THEN 1 END) as exitosos
      FROM eventos_toma e
      JOIN recordatorios r ON e.id_recordatorio = r.id_recordatorio
      WHERE r.id_beneficiario = ?
        AND e.fecha_hora_programada >= ?
    """,
      [idBenef, fechaInicio.toIso8601String()],
    );

    if (result.isEmpty) return 0.0;

    final total = result.first['total'] as int;
    final exitosos = result.first['exitosos'] as int;

    if (total == 0) return 0.0;
    return (exitosos / total) * 100.0;
  }

  // =========================================================
  //  PUNTOS Y XP (Sistema de Gamificación)
  // =========================================================

  /// Agregar puntos canjeables (no afecta XP ni nivel)
  static Future<void> addPuntos(int puntos, String codigoUnico) async {
    final db = await database;
    final idBenef = await getBeneficiarioId(codigoUnico);
    if (idBenef == null) return;

    await db.rawUpdate(
      """
      UPDATE perfil_gamificacion
      SET puntos_actuales = puntos_actuales + ?,
          updated_at = CURRENT_TIMESTAMP
      WHERE id_beneficiario = ?
    """,
      [puntos, idBenef],
    );
  }

  /// Agregar XP (actualiza nivel automáticamente, NO reduce puntos)
  static Future<void> addXP(int xp, String codigoUnico) async {
    final db = await database;
    final idBenef = await getBeneficiarioId(codigoUnico);
    if (idBenef == null) return;

    await db.rawUpdate(
      """
      UPDATE perfil_gamificacion
      SET xp_total = xp_total + ?,
          updated_at = CURRENT_TIMESTAMP
      WHERE id_beneficiario = ?
    """,
      [xp, idBenef],
    );

    // Recalcular nivel
    final perfil = await db.query(
      "perfil_gamificacion",
      where: "id_beneficiario = ?",
      whereArgs: [idBenef],
    );

    if (perfil.isNotEmpty) {
      final xpTotal = perfil.first['xp_total'] as int;
      final nuevoNivel = calculateNivel(xpTotal);

      await db.update(
        "perfil_gamificacion",
        {"nivel": nuevoNivel},
        where: "id_beneficiario = ?",
        whereArgs: [idBenef],
      );
    }
  }

  /// Canjear puntos por recompensa (NO afecta XP ni nivel)
  static Future<bool> canjearRecompensa({
    required String codigoUnico,
    required int idRecompensa,
  }) async {
    final db = await database;
    final idBenef = await getBeneficiarioId(codigoUnico);
    if (idBenef == null) return false;

    // Obtener recompensa
    final recompensa = await db.query(
      "recompensa",
      where: "id_recompensa = ? AND disponible = 1",
      whereArgs: [idRecompensa],
    );

    if (recompensa.isEmpty) return false;

    final puntosRequeridos = recompensa.first['puntos_requeridos'] as int;

    // Verificar puntos suficientes
    final perfil = await db.query(
      "perfil_gamificacion",
      where: "id_beneficiario = ?",
      whereArgs: [idBenef],
    );

    if (perfil.isEmpty) return false;

    final puntosActuales = perfil.first['puntos_actuales'] as int;
    if (puntosActuales < puntosRequeridos) return false;

    // Transacción: descontar puntos y registrar canje
    await db.transaction((txn) async {
      await txn.rawUpdate(
        """
        UPDATE perfil_gamificacion
        SET puntos_actuales = puntos_actuales - ?,
            updated_at = CURRENT_TIMESTAMP
        WHERE id_beneficiario = ?
      """,
        [puntosRequeridos, idBenef],
      );

      await txn.insert("beneficiario_recompensa", {
        "id_beneficiario": idBenef,
        "id_recompensa": idRecompensa,
        "puntos_utilizados": puntosRequeridos,
        "estado_entrega": "pendiente",
      });
    });

    return true;
  }

  /// Obtener recompensas disponibles
  static Future<List<Map<String, dynamic>>> getRecompensasDisponibles() async {
    final db = await database;
    return await db.query(
      "recompensa",
      where: "disponible = 1",
      orderBy: "puntos_requeridos ASC",
    );
  }

  /// Obtener historial de canjes
  static Future<List<Map<String, dynamic>>> getHistorialCanjes(
    String codigoUnico,
  ) async {
    final db = await database;
    final idBenef = await getBeneficiarioId(codigoUnico);
    if (idBenef == null) return [];

    return await db.rawQuery(
      """
      SELECT br.*, r.nombre_recompensa, r.descripcion
      FROM beneficiario_recompensa br
      JOIN recompensa r ON br.id_recompensa = r.id_recompensa
      WHERE br.id_beneficiario = ?
      ORDER BY br.fecha_canje DESC
    """,
      [idBenef],
    );
  }

  // =========================================================
  //  LOGROS
  // =========================================================

  /// Verificar y desbloquear logros pendientes
  static Future<List<Map<String, dynamic>>> verificarLogros(
    String codigoUnico,
  ) async {
    final db = await database;
    final idBenef = await getBeneficiarioId(codigoUnico);
    if (idBenef == null) return [];

    final perfil = await getPerfilGamificacion(codigoUnico);
    if (perfil == null) return [];

    final xpTotal = perfil['xp_total'] as int;

    // Obtener logros no desbloqueados
    final logrosDisponibles = await db.rawQuery(
      """
      SELECT l.*
      FROM logros l
      WHERE NOT EXISTS (
        SELECT 1 FROM beneficiario_logro bl
        WHERE bl.id_logro = l.id_logro
          AND bl.id_beneficiario = ?
      )
    """,
      [idBenef],
    );

    List<Map<String, dynamic>> desbloqueados = [];

    for (var logro in logrosDisponibles) {
      final tipoCondicion = logro['tipo_condicion'] as String;
      final parametro = logro['parametro'] as String?;
      bool cumple = false;

      switch (tipoCondicion) {
        case 'xp_minimo':
          final xpReq = int.tryParse(parametro ?? '0') ?? 0;
          cumple = xpTotal >= xpReq;
          break;

        case 'racha_dias':
          // Implementar lógica de racha
          cumple = false; // TODO
          break;

        case 'tomas_consecutivas':
          // Implementar lógica de tomas consecutivas
          cumple = false; // TODO
          break;
      }

      if (cumple) {
        // Desbloquear logro
        await db.insert("beneficiario_logro", {
          "id_beneficiario": idBenef,
          "id_logro": logro['id_logro'],
        });

        // Otorgar puntos bonus si los hay
        final puntosBonus = logro['puntos_bonus'] as int? ?? 0;
        if (puntosBonus > 0) {
          await addPuntos(puntosBonus, codigoUnico);
        }

        desbloqueados.add(logro);
      }
    }

    return desbloqueados;
  }

  /// Obtener logros desbloqueados
  static Future<List<Map<String, dynamic>>> getLogrosDesbloqueados(
    String codigoUnico,
  ) async {
    final db = await database;
    final idBenef = await getBeneficiarioId(codigoUnico);
    if (idBenef == null) return [];

    return await db.rawQuery(
      """
      SELECT l.*, bl.fecha_obtenido
      FROM beneficiario_logro bl
      JOIN logros l ON bl.id_logro = l.id_logro
      WHERE bl.id_beneficiario = ?
      ORDER BY bl.fecha_obtenido DESC
    """,
      [idBenef],
    );
  }

  // =========================================================
  //  BORRAR BD (debug)
  // =========================================================
  static Future<void> clear() async {
    final db = await database;
    await db.delete("eventos_toma");
    await db.delete("beneficiario_recompensa");
    await db.delete("beneficiario_logro");
    await db.delete("recordatorios");
    await db.delete("perfil_gamificacion");
    await db.delete("redes_apoyo");
    await db.delete("beneficiario");
  }
}
