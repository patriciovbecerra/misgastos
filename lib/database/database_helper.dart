import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:misgastos/models/gasto.dart';
import 'package:misgastos/models/medio_pago.dart';
import 'package:misgastos/models/categoria.dart';
import 'package:misgastos/models/grupo.dart';
import 'package:misgastos/models/participante.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;
  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('gastos_app.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);
    return await openDatabase(
      path,
      version: 13,
      onCreate: _createDB,
      onUpgrade: _upgradeDB,
    );
  }

  Future<void> _createDB(Database db, int version) async {
    await db.execute('PRAGMA foreign_keys = ON');

    await db.execute('''
      CREATE TABLE medios_pago (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        nombre TEXT NOT NULL,
        icono TEXT NOT NULL,
        dia_cierre INTEGER,
        color TEXT NOT NULL DEFAULT '#0288D1',
        es_tarjeta_credito INTEGER NOT NULL DEFAULT 0,
        es_tarjeta_adicional INTEGER NOT NULL DEFAULT 0,
        id_tc_titular INTEGER
      )
    ''');

    await db.execute('''
      CREATE TABLE categorias (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        nombre TEXT NOT NULL,
        icono TEXT NOT NULL,
        color TEXT NOT NULL,
        activo INTEGER NOT NULL DEFAULT 1
      )
    ''');

    await db.execute('''
      CREATE TABLE grupos (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        nombre TEXT NOT NULL,
        descripcion TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE participantes (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        nombre TEXT NOT NULL,
        id_grupo INTEGER NOT NULL,
        FOREIGN KEY (id_grupo) REFERENCES grupos(id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE gastos (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        monto REAL NOT NULL,
        valor_cuota REAL NOT NULL,
        cuotas_total INTEGER NOT NULL DEFAULT 1,
        cuota_numero INTEGER NOT NULL DEFAULT 1,
        id_compra_origen INTEGER,
        fecha TEXT NOT NULL,
        fecha_compra TEXT NOT NULL,
        descripcion TEXT,
        es_compartido INTEGER NOT NULL DEFAULT 0,
        id_medio_pago INTEGER NOT NULL,
        id_categoria INTEGER NOT NULL,
        id_grupo INTEGER,
        FOREIGN KEY (id_medio_pago) REFERENCES medios_pago(id),
        FOREIGN KEY (id_categoria) REFERENCES categorias(id),
        FOREIGN KEY (id_grupo) REFERENCES grupos(id)
      )
    ''');

    await db.execute('''
      CREATE TABLE periodos_facturacion (
        id_medio_pago INTEGER PRIMARY KEY,
        desde TEXT NOT NULL,
        hasta TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE calendario_facturacion (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        id_medio_pago INTEGER NOT NULL,
        anio INTEGER NOT NULL,
        mes INTEGER NOT NULL,
        desde TEXT NOT NULL,
        hasta TEXT NOT NULL,
        UNIQUE(id_medio_pago, anio, mes),
        FOREIGN KEY (id_medio_pago) REFERENCES medios_pago(id)
      )
    ''');
    await _insertDatosIniciales(db);
  }

  Future<void> _upgradeDB(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 4) {
      await _insertCategoriasNuevas(db);
    }
    if (oldVersion < 13) {
      try {
        await db.execute(
            "ALTER TABLE categorias ADD COLUMN activo INTEGER NOT NULL DEFAULT 1");
      } catch (_) {}
    }
    if (oldVersion < 12) {
      // Migrar íconos de texto a emojis
      final Map<String, String> iconMap = {
        'supermercado': '🛒', 'food': '🌮', 'delivery': '🛵',
        'cafe': '☕', 'bar': '🍺', 'fast_food': '🍔',
        'pizza': '🍕', 'ice_cream': '🍦', 'wine': '🍷',
        'car': '🚗', 'bencina': '⛽', 'parking': '🅿️',
        'transport': '🚌', 'bus': '🚌', 'travel': '✈️',
        'home': '🏠', 'utilities': '💡', 'internet': '📡',
        'furniture': '🛋️', 'cleaning': '🧹', 'tools': '🔧',
        'clothing': '👕', 'shoes': '👟', 'shopping': '👜',
        'accessories': '🕶️', 'health': '💊', 'doctor': '🏥',
        'dental': '🦷', 'gym': '💪', 'wellness': '🧘',
        'hygiene': '🧴', 'entertainment': '🎬', 'gaming': '🎮',
        'music': '🎵', 'streaming': '📺', 'events': '🎟️',
        'books': '📚', 'hotel': '🏨', 'tourism': '🗺️',
        'luggage': '🧳', 'phone': '📱', 'computer': '💻',
        'electronics': '🎧', 'tech': '💻', 'pets': '🐶',
        'vet': '🐾', 'pet_food': '🦴', 'education': '🎓',
        'courses': '📖', 'school': '🏫', 'account_balance': '🏦',
        'insurance': '🛡️', 'credit_card': '💳', 'investment': '📈',
        'gift': '🎁', 'haircut': '💈', 'laundry': '🧴',
        'others': '❓', 'sport': '⚽', 'beauty': '💅',
        'work': '💼', 'rent': '🏠', 'subscription': '📲',
        'donation': '🙏', 'taxes': '💸', 'fees': '🧾',
        'baby': '👶', 'toy': '🧸', 'spa': '💅',
        'cloud': '☁️', 'app': '📲', 'documents': '📄',
        'parking_work': '🅿️', 'office': '🏢',
        'bike': '🚲', 'swimming': '🏊', 'hiking': '🥾',
        'makeup': '💅', 'garden': '🌱', 'security': '🔒',
        'appliance': '🍳', 'fast_food': '🍔',
      };
      try {
        for (final entry in iconMap.entries) {
          await db.rawUpdate(
            "UPDATE categorias SET icono = ? WHERE icono = ?",
            [entry.value, entry.key],
          );
        }
      } catch (_) {}
    }
    if (oldVersion < 11) {
      // Insertar Farmacia si no existe
      try {
        final existing = await db.query('categorias',
            where: 'nombre = ?', whereArgs: ['Farmacia']);
        if (existing.isEmpty) {
          await db.insert('categorias', {
            'nombre': 'Farmacia',
            'icono': 'health',
            'color': '#DDA0DD',
            'activo': 1,
          });
        }
      } catch (_) {}
    }
    if (oldVersion < 10) {
      try {
        await db.execute('''
          CREATE TABLE IF NOT EXISTS calendario_facturacion (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            id_medio_pago INTEGER NOT NULL,
            anio INTEGER NOT NULL,
            mes INTEGER NOT NULL,
            desde TEXT NOT NULL,
            hasta TEXT NOT NULL,
            UNIQUE(id_medio_pago, anio, mes),
            FOREIGN KEY (id_medio_pago) REFERENCES medios_pago(id)
          )
        ''');
      } catch (_) {}
    }
    if (oldVersion < 9) {
      try { await db.execute("ALTER TABLE medios_pago ADD COLUMN color TEXT NOT NULL DEFAULT '#0288D1'"); } catch (_) {}
    }
    if (oldVersion < 8) {
      try { await db.execute('ALTER TABLE medios_pago ADD COLUMN es_tarjeta_adicional INTEGER NOT NULL DEFAULT 0'); } catch (_) {}
      try { await db.execute('ALTER TABLE medios_pago ADD COLUMN id_tc_titular INTEGER'); } catch (_) {}
    }
    if (oldVersion < 7) {
      try {
        await db.execute('''
          CREATE TABLE IF NOT EXISTS periodos_facturacion (
            id_medio_pago INTEGER PRIMARY KEY,
            desde TEXT NOT NULL,
            hasta TEXT NOT NULL
          )
        ''');
      } catch (_) {}
    }
    if (oldVersion < 6) {
      try { await db.execute('ALTER TABLE medios_pago ADD COLUMN dia_cierre INTEGER'); } catch (_) {}
      try { await db.execute('ALTER TABLE medios_pago ADD COLUMN es_tarjeta_credito INTEGER NOT NULL DEFAULT 0'); } catch (_) {}
    }
  }

  Future<void> _insertDatosIniciales(Database db) async {
    final mediosPago = [
      {'nombre': 'Bco Chile',    'icono': 'credit_card', 'color': '#1565C0', 'dia_cierre': null, 'es_tarjeta_credito': 1, 'es_tarjeta_adicional': 0, 'id_tc_titular': null},
      {'nombre': 'Bco Itau',     'icono': 'credit_card', 'color': '#E65100', 'dia_cierre': null, 'es_tarjeta_credito': 1, 'es_tarjeta_adicional': 0, 'id_tc_titular': null},
      {'nombre': 'Ripley',       'icono': 'credit_card', 'color': '#C62828', 'dia_cierre': null, 'es_tarjeta_credito': 1, 'es_tarjeta_adicional': 0, 'id_tc_titular': null},
      {'nombre': 'Efectivo',     'icono': 'cash',        'color': '#2E7D32', 'dia_cierre': null, 'es_tarjeta_credito': 0, 'es_tarjeta_adicional': 0, 'id_tc_titular': null},
      {'nombre': 'Transferencia','icono': 'transfer',    'color': '#0097A7', 'dia_cierre': null, 'es_tarjeta_credito': 0, 'es_tarjeta_adicional': 0, 'id_tc_titular': null},
      {'nombre': 'Débito',       'icono': 'debit_card',  'color': '#455A64', 'dia_cierre': null, 'es_tarjeta_credito': 0, 'es_tarjeta_adicional': 0, 'id_tc_titular': null},
    ];
    for (final m in mediosPago) await db.insert('medios_pago', m);

    final categorias = [
      {'nombre': 'Supermercado',        'icono': 'supermercado',   'color': '#FF6B6B'},
      {'nombre': 'Comida rápida',       'icono': 'food',           'color': '#FF6B6B'},
      {'nombre': 'Delivery',            'icono': 'delivery',       'color': '#FF6B6B'},
      {'nombre': 'Café',                'icono': 'cafe',           'color': '#FF6B6B'},
      {'nombre': 'Bar / Trago',         'icono': 'bar',            'color': '#FF6B6B'},
      {'nombre': 'Restaurante',         'icono': 'food',           'color': '#FF6B6B'},
      {'nombre': 'Auto',                'icono': 'car',            'color': '#45B7D1'},
      {'nombre': 'Bencina',             'icono': 'bencina',        'color': '#45B7D1'},
      {'nombre': 'Estacionamiento',     'icono': 'parking',        'color': '#45B7D1'},
      {'nombre': 'Uber / Taxi',         'icono': 'transport',      'color': '#45B7D1'},
      {'nombre': 'Transporte público',  'icono': 'bus',            'color': '#45B7D1'},
      {'nombre': 'Mantención auto',     'icono': 'tools',          'color': '#45B7D1'},
      {'nombre': 'Arriendo / Depa',     'icono': 'home',           'color': '#96CEB4'},
      {'nombre': 'Luz / Agua / Gas',    'icono': 'utilities',      'color': '#96CEB4'},
      {'nombre': 'Internet / TV',       'icono': 'internet',       'color': '#96CEB4'},
      {'nombre': 'Muebles',             'icono': 'furniture',      'color': '#96CEB4'},
      {'nombre': 'Limpieza',            'icono': 'cleaning',       'color': '#96CEB4'},
      {'nombre': 'Reparaciones',        'icono': 'tools',          'color': '#96CEB4'},
      {'nombre': 'Ropa',                'icono': 'clothing',       'color': '#F0A500'},
      {'nombre': 'Zapatos',             'icono': 'shoes',          'color': '#F0A500'},
      {'nombre': 'Multitienda',         'icono': 'shopping',       'color': '#F0A500'},
      {'nombre': 'Accesorios',          'icono': 'accessories',    'color': '#F0A500'},
      {'nombre': 'Farmacia',            'icono': 'health',         'color': '#DDA0DD'},
      {'nombre': 'Médico',              'icono': 'doctor',         'color': '#DDA0DD'},
      {'nombre': 'Dentista',            'icono': 'dental',         'color': '#DDA0DD'},
      {'nombre': 'Gimnasio',            'icono': 'gym',            'color': '#DDA0DD'},
      {'nombre': 'Bienestar',           'icono': 'wellness',       'color': '#DDA0DD'},
      {'nombre': 'Higiene',             'icono': 'hygiene',        'color': '#DDA0DD'},
      {'nombre': 'Cine',                'icono': 'entertainment',  'color': '#6C63FF'},
      {'nombre': 'Videojuegos',         'icono': 'gaming',         'color': '#6C63FF'},
      {'nombre': 'Música',              'icono': 'music',          'color': '#6C63FF'},
      {'nombre': 'Streaming',           'icono': 'streaming',      'color': '#6C63FF'},
      {'nombre': 'Eventos',             'icono': 'events',         'color': '#6C63FF'},
      {'nombre': 'Libros',              'icono': 'books',          'color': '#6C63FF'},
      {'nombre': 'Vuelos',              'icono': 'travel',         'color': '#FFEAA7'},
      {'nombre': 'Hotel',               'icono': 'hotel',          'color': '#FFEAA7'},
      {'nombre': 'Turismo',             'icono': 'tourism',        'color': '#FFEAA7'},
      {'nombre': 'Equipaje',            'icono': 'luggage',        'color': '#FFEAA7'},
      {'nombre': 'Celular',             'icono': 'phone',          'color': '#4ECDC4'},
      {'nombre': 'Computador',          'icono': 'computer',       'color': '#4ECDC4'},
      {'nombre': 'Electrónica',         'icono': 'electronics',    'color': '#4ECDC4'},
      {'nombre': 'Accesorios tech',     'icono': 'tech',           'color': '#4ECDC4'},
      {'nombre': 'Mascotas',            'icono': 'pets',           'color': '#FF85A1'},
      {'nombre': 'Veterinario',         'icono': 'vet',            'color': '#FF85A1'},
      {'nombre': 'Comida mascota',      'icono': 'pet_food',       'color': '#FF85A1'},
      {'nombre': 'Colegio / Universidad','icono': 'education',     'color': '#A8E063'},
      {'nombre': 'Cursos',              'icono': 'courses',        'color': '#A8E063'},
      {'nombre': 'Útiles',              'icono': 'school',         'color': '#A8E063'},
      {'nombre': 'Banco / Crédito',     'icono': 'account_balance','color': '#B0BEC5'},
      {'nombre': 'Seguro',              'icono': 'insurance',      'color': '#B0BEC5'},
      {'nombre': 'Avance TC',           'icono': 'credit_card',    'color': '#B0BEC5'},
      {'nombre': 'Inversión',           'icono': 'investment',     'color': '#B0BEC5'},
      {'nombre': 'Regalos',             'icono': 'gift',           'color': '#B0BEC5'},
      {'nombre': 'Peluquería',          'icono': 'haircut',        'color': '#B0BEC5'},
      {'nombre': 'Lavandería',          'icono': 'laundry',        'color': '#B0BEC5'},
      {'nombre': 'Otros',               'icono': 'others',         'color': '#B0BEC5'},
    ];
    for (final c in categorias) await db.insert('categorias', c);
  }

  Future<void> _insertCategoriasNuevas(Database db) async {
    final existentes = await db.query('categorias');
    final nombres = existentes.map((e) => e['nombre'] as String).toSet();
    final nuevas = [
      {'nombre': 'Supermercado', 'icono': 'supermercado', 'color': '#FF6B6B'},
      {'nombre': 'Farmacia', 'icono': 'health', 'color': '#DDA0DD'},
      {'nombre': 'Delivery', 'icono': 'delivery', 'color': '#FF6B6B'},
      {'nombre': 'Café', 'icono': 'cafe', 'color': '#FF6B6B'},
      {'nombre': 'Bencina', 'icono': 'bencina', 'color': '#45B7D1'},
      {'nombre': 'Estacionamiento', 'icono': 'parking', 'color': '#45B7D1'},
      {'nombre': 'Ropa', 'icono': 'clothing', 'color': '#F0A500'},
      {'nombre': 'Streaming', 'icono': 'streaming', 'color': '#6C63FF'},
      {'nombre': 'Vuelos', 'icono': 'travel', 'color': '#FFEAA7'},
      {'nombre': 'Celular', 'icono': 'phone', 'color': '#4ECDC4'},
      {'nombre': 'Mascotas', 'icono': 'pets', 'color': '#FF85A1'},
      {'nombre': 'Otros', 'icono': 'others', 'color': '#B0BEC5'},
    ];
    for (final c in nuevas) {
      if (!nombres.contains(c['nombre'])) await db.insert('categorias', c);
    }
  }

  // ─── MEDIOS DE PAGO ──────────────────────────────────────────────

  Future<List<MedioPago>> getMediosPago() async {
    final db = await database;
    final maps = await db.query('medios_pago', orderBy: 'nombre ASC');
    return maps.map((m) => MedioPago.fromMap(m)).toList();
  }

  Future<MedioPago?> getMedioPagoById(int id) async {
    final db = await database;
    final maps = await db.query('medios_pago', where: 'id = ?', whereArgs: [id]);
    if (maps.isEmpty) return null;
    return MedioPago.fromMap(maps.first);
  }

  Future<int> insertMedioPago(MedioPago medio) async {
    final db = await database;
    return await db.insert('medios_pago', medio.toMap());
  }

  Future<int> updateMedioPago(MedioPago medio) async {
    final db = await database;
    return await db.update('medios_pago', medio.toMap(), where: 'id = ?', whereArgs: [medio.id]);
  }

  Future<int> deleteMedioPago(int id) async {
    final db = await database;
    return await db.delete('medios_pago', where: 'id = ?', whereArgs: [id]);
  }

  // ─── CATEGORÍAS ──────────────────────────────────────────────────

  Future<List<Categoria>> getCategorias() async {
    final db = await database;
    final maps = await db.query('categorias', orderBy: 'nombre ASC');
    return maps.map((m) => Categoria.fromMap(m)).toList();
  }

  Future<List<Categoria>> getCategoriasActivas() async {
    final db = await database;
    final maps = await db.query('categorias',
        where: 'activo = 1', orderBy: 'nombre ASC');
    return maps.map((m) => Categoria.fromMap(m)).toList();
  }

  Future<Categoria?> getCategoriaById(int id) async {
    final db = await database;
    final maps = await db.query('categorias', where: 'id = ?', whereArgs: [id]);
    if (maps.isEmpty) return null;
    return Categoria.fromMap(maps.first);
  }

  Future<int> insertCategoria(Categoria categoria) async {
    final db = await database;
    return await db.insert('categorias', categoria.toMap());
  }

  Future<int> updateCategoria(Categoria categoria) async {
    final db = await database;
    return await db.update('categorias', categoria.toMap(), where: 'id = ?', whereArgs: [categoria.id]);
  }

  Future<int> deleteCategoria(int id) async {
    final db = await database;
    return await db.delete('categorias', where: 'id = ?', whereArgs: [id]);
  }

  // ─── GRUPOS ──────────────────────────────────────────────────────

  Future<List<Grupo>> getGrupos() async {
    final db = await database;
    final maps = await db.query('grupos', orderBy: 'nombre ASC');
    return maps.map((m) => Grupo.fromMap(m)).toList();
  }

  Future<Grupo?> getGrupoById(int id) async {
    final db = await database;
    final maps = await db.query('grupos', where: 'id = ?', whereArgs: [id]);
    if (maps.isEmpty) return null;
    return Grupo.fromMap(maps.first);
  }

  Future<int> insertGrupo(Grupo grupo) async {
    final db = await database;
    return await db.insert('grupos', grupo.toMap());
  }

  Future<int> updateGrupo(Grupo grupo) async {
    final db = await database;
    return await db.update('grupos', grupo.toMap(), where: 'id = ?', whereArgs: [grupo.id]);
  }

  Future<int> deleteGrupo(int id) async {
    final db = await database;
    return await db.delete('grupos', where: 'id = ?', whereArgs: [id]);
  }

  // ─── PARTICIPANTES ───────────────────────────────────────────────

  Future<List<Participante>> getParticipantesByGrupo(int idGrupo) async {
    final db = await database;
    final maps = await db.query('participantes',
        where: 'id_grupo = ?', whereArgs: [idGrupo], orderBy: 'nombre ASC');
    return maps.map((m) => Participante.fromMap(m)).toList();
  }

  Future<int> insertParticipante(Participante p) async {
    final db = await database;
    return await db.insert('participantes', p.toMap());
  }

  Future<int> eliminarParticipante(int id) => deleteParticipante(id);

  Future<int> deleteParticipante(int id) async {
    final db = await database;
    return await db.delete('participantes', where: 'id = ?', whereArgs: [id]);
  }

  // ─── GASTOS ──────────────────────────────────────────────────────

  /// Calcula la fecha en que debe caer la cuota N según el día de cierre de la TC.
  /// Si la compra es ANTES del cierre → cuota 1 cae en el período actual
  /// Si la compra es DESPUÉS del cierre → cuota 1 cae en el período siguiente
  /// Calcula la fecha de cobro de la cuota N según el día de cierre.
  ///
  /// Regla:
  /// - Si compra ANTES o EN el día de cierre → cuota 1 se cobra ese mismo mes (día cierre)
  ///   Ej: cierre día 15, compra el 5 ene → C1=15 ene, C2=15 feb, C3=15 mar
  /// - Si compra DESPUÉS del día de cierre → cuota 1 se cobra el siguiente mes
  ///   Ej: cierre día 15, compra el 20 ene → C1=15 feb, C2=15 mar, C3=15 abr
  DateTime _fechaCuota(DateTime fechaCompra, int numeroCuota, int? diaCierre) {
    if (diaCierre == null) {
      // Sin día de cierre: cuota 1 en el mes siguiente a la compra
      return DateTime(fechaCompra.year, fechaCompra.month + numeroCuota, 1);
    }
    // Offset según si la compra cayó antes o después del cierre
    final int offsetBase = fechaCompra.day <= diaCierre
        ? numeroCuota - 1  // compra antes/en el cierre → cuota 1 este mes
        : numeroCuota;     // compra después del cierre → cuota 1 el mes siguiente
    final mes = fechaCompra.month + offsetBase;
    return DateTime(fechaCompra.year, mes, diaCierre);
  }

  /// [cuotasYaPagadas] indica cuántas cuotas ya fueron cobradas antes de registrar.
  /// Si cuotasYaPagadas=3, se generan solo las cuotas 4..N.
  Future<int> insertGastoConCuotas(Gasto gasto, {int cuotasYaPagadas = 0}) async {
    final db = await database;

    // Gasto sin cuotas
    if (gasto.cuotasTotal <= 1) {
      final map = gasto.toMap()..remove('id');
      return await db.insert('gastos', map);
    }

    // Obtener día de cierre del medio de pago
    int? diaCierre;
    final medioMaps = await db.query('medios_pago',
        where: 'id = ?', whereArgs: [gasto.idMedioPago]);
    if (medioMaps.isNotEmpty) {
      diaCierre = medioMaps.first['dia_cierre'] as int?;
    }

    final primeraCuota = cuotasYaPagadas + 1;
    if (primeraCuota > gasto.cuotasTotal) return -1;

    // Insertar primera cuota — sin id, sin id_compra_origen por ahora
    final primeraMap = gasto.toMap()
      ..remove('id')
      ..['cuota_numero'] = primeraCuota
      ..['id_compra_origen'] = null
      ..['fecha'] = _fechaCuota(gasto.fechaCompra, primeraCuota, diaCierre).toIso8601String();

    final primerID = await db.insert('gastos', primeraMap);

    // Actualizar la primera cuota con su propio id como origen
    await db.update('gastos', {'id_compra_origen': primerID},
        where: 'id = ?', whereArgs: [primerID]);

    // Cuotas restantes
    for (int i = primeraCuota + 1; i <= gasto.cuotasTotal; i++) {
      final cuotaMap = gasto.toMap()
        ..remove('id')
        ..['cuota_numero'] = i
        ..['id_compra_origen'] = primerID
        ..['fecha'] = _fechaCuota(gasto.fechaCompra, i, diaCierre).toIso8601String();
      await db.insert('gastos', cuotaMap);
    }
    return primerID;
  }

  Future<int> updateGasto(Gasto gasto) async {
    final db = await database;
    return await db.update('gastos', gasto.toMap(),
        where: 'id = ?', whereArgs: [gasto.id]);
  }

  Future<int> deleteGasto(int id) async {
    final db = await database;
    // Buscar si tiene id_compra_origen (es una cuota hija)
    final maps = await db.query('gastos', where: 'id = ?', whereArgs: [id]);
    if (maps.isEmpty) return 0;

    final idOrigen = maps.first['id_compra_origen'] as int?;

    if (idOrigen != null) {
      // Es cuota hija → eliminar todas las cuotas de esa compra (hijas + origen)
      await db.delete('gastos',
          where: 'id_compra_origen = ?', whereArgs: [idOrigen]);
      await db.delete('gastos',
          where: 'id = ?', whereArgs: [idOrigen]);
    } else {
      // Puede ser cuota origen → verificar si tiene cuotas hijas
      final hijas = await db.query('gastos',
          where: 'id_compra_origen = ?', whereArgs: [id]);
      if (hijas.isNotEmpty) {
        // Eliminar todas las cuotas hijas y luego la origen
        await db.delete('gastos',
            where: 'id_compra_origen = ?', whereArgs: [id]);
      }
      // Eliminar el gasto (sea origen o gasto simple)
      await db.delete('gastos', where: 'id = ?', whereArgs: [id]);
    }
    return 1;
  }

  Future<List<Gasto>> getGastosByRango(DateTime desde, DateTime hasta) async {
    final db = await database;
    final maps = await db.query(
      'gastos',
      where: 'fecha BETWEEN ? AND ?',
      whereArgs: [desde.toIso8601String(), hasta.toIso8601String()],
      orderBy: 'fecha DESC',
    );
    return await _enriquecerGastos(db, maps);
  }

  Future<List<Gasto>> getAllGastos() async {
    final db = await database;
    final maps = await db.query('gastos', orderBy: 'fecha DESC');
    return await _enriquecerGastos(db, maps);
  }

  Future<List<Gasto>> getCuotasPendientes() async {
    final db = await database;
    final hoy = DateTime.now().toIso8601String();
    final maps = await db.query(
      'gastos',
      where: 'fecha > ? AND cuotas_total > 1',
      whereArgs: [hoy],
      orderBy: 'fecha ASC',
    );
    return await _enriquecerGastos(db, maps);
  }

  Future<List<Gasto>> _enriquecerGastos(
      Database db, List<Map<String, dynamic>> maps) async {
    final List<Gasto> gastos = [];
    for (final map in maps) {
      final gasto = Gasto.fromMap(map);
      final medio = await getMedioPagoById(gasto.idMedioPago);
      final cat = await getCategoriaById(gasto.idCategoria);
      final grupo = gasto.idGrupo != null ? await getGrupoById(gasto.idGrupo!) : null;
      gastos.add(gasto.copyWith(medioPago: medio, categoria: cat, grupo: grupo));
    }
    return gastos;
  }

  // ─── ANÁLISIS ────────────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> getTotalPorRangoMedioPago(
      DateTime desde, DateTime hasta) async {
    final db = await database;
    return await db.rawQuery('''
      SELECT mp.nombre, mp.icono, SUM(g.valor_cuota) as total
      FROM gastos g
      JOIN medios_pago mp ON g.id_medio_pago = mp.id
      WHERE g.fecha BETWEEN ? AND ?
      GROUP BY mp.id, mp.nombre, mp.icono
      ORDER BY total DESC
    ''', [desde.toIso8601String(), hasta.toIso8601String()]);
  }

  Future<List<Map<String, dynamic>>> getTotalPorRangoCategoria(
      DateTime desde, DateTime hasta) async {
    final db = await database;
    return await db.rawQuery('''
      SELECT c.nombre, c.icono, c.color, SUM(g.valor_cuota) as total
      FROM gastos g
      JOIN categorias c ON g.id_categoria = c.id
      WHERE g.fecha BETWEEN ? AND ?
      GROUP BY c.id, c.nombre, c.icono, c.color
      ORDER BY total DESC
    ''', [desde.toIso8601String(), hasta.toIso8601String()]);
  }

  Future<Map<String, double>> getTotalIndividualVsCompartidoRango(
      DateTime desde, DateTime hasta) async {
    final db = await database;
    final result = await db.rawQuery('''
      SELECT es_compartido, SUM(valor_cuota) as total
      FROM gastos
      WHERE fecha BETWEEN ? AND ?
      GROUP BY es_compartido
    ''', [desde.toIso8601String(), hasta.toIso8601String()]);
    double individual = 0, compartido = 0;
    for (final row in result) {
      if (row['es_compartido'] == 0) {
        individual = (row['total'] as num).toDouble();
      } else {
        compartido = (row['total'] as num).toDouble();
      }
    }
    return {'individual': individual, 'compartido': compartido};
  }

  Future<List<Map<String, dynamic>>> getResumenAnual(int anio) async {
    final db = await database;
    return await db.rawQuery('''
      SELECT strftime('%m', fecha) as mes, SUM(valor_cuota) as total
      FROM gastos
      WHERE strftime('%Y', fecha) = ?
      GROUP BY mes ORDER BY mes ASC
    ''', [anio.toString()]);
  }


  // ─── PERÍODOS DE FACTURACIÓN ─────────────────────────────────────

  Future<Map<int, Map<String, DateTime>>> getPeriodosFacturacion() async {
    final db = await database;
    final maps = await db.query('periodos_facturacion');
    final result = <int, Map<String, DateTime>>{};
    for (final m in maps) {
      result[m['id_medio_pago'] as int] = {
        'desde': DateTime.parse(m['desde'] as String),
        'hasta': DateTime.parse(m['hasta'] as String),
      };
    }
    return result;
  }

  Future<void> guardarPeriodoFacturacion(
      int idMedioPago, DateTime desde, DateTime hasta) async {
    final db = await database;
    await db.insert(
      'periodos_facturacion',
      {
        'id_medio_pago': idMedioPago,
        'desde': desde.toIso8601String(),
        'hasta': hasta.toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> eliminarPeriodoFacturacion(int idMedioPago) async {
    final db = await database;
    await db.delete('periodos_facturacion',
        where: 'id_medio_pago = ?', whereArgs: [idMedioPago]);
  }


  Future<Map<int, int>> getFrecuenciaMedios() async {
    final db = await database;
    final result = await db.rawQuery(
        'SELECT id_medio_pago, COUNT(*) as total FROM gastos GROUP BY id_medio_pago');
    final mapa = <int, int>{};
    for (final row in result) {
      mapa[row['id_medio_pago'] as int] = row['total'] as int;
    }
    return mapa;
  }

  /// Retorna mapa idCategoria → cantidad de veces usada
  Future<Map<int, int>> getFrecuenciaCategorias() async {
    final db = await database;
    final result = await db.rawQuery('''
      SELECT id_categoria, COUNT(*) as total
      FROM gastos
      GROUP BY id_categoria
    ''');
    final mapa = <int, int>{};
    for (final row in result) {
      mapa[row['id_categoria'] as int] = row['total'] as int;
    }
    return mapa;
  }


  // ─── COMPARACIÓN MENSUAL ─────────────────────────────────────────

  Future<Map<String, dynamic>> getComparacionMensual(int anio, int mes) async {
    final db = await database;
    final desde = DateTime(anio, mes, 1).toIso8601String();
    final hasta = DateTime(anio, mes + 1, 0, 23, 59, 59).toIso8601String();

    // Total del mes
    final totalRes = await db.rawQuery('''
      SELECT COALESCE(SUM(valor_cuota), 0) as total
      FROM gastos WHERE fecha BETWEEN ? AND ?
    ''', [desde, hasta]);
    final total = (totalRes.first['total'] as num).toDouble();

    // Por categoría
    final porCategoria = await db.rawQuery('''
      SELECT c.nombre, c.color, c.icono, COALESCE(SUM(g.valor_cuota), 0) as total
      FROM gastos g JOIN categorias c ON g.id_categoria = c.id
      WHERE g.fecha BETWEEN ? AND ?
      GROUP BY c.id ORDER BY total DESC LIMIT 5
    ''', [desde, hasta]);

    // Por medio de pago
    final porMedio = await db.rawQuery('''
      SELECT mp.nombre, mp.color, COALESCE(SUM(g.valor_cuota), 0) as total
      FROM gastos g JOIN medios_pago mp ON g.id_medio_pago = mp.id
      WHERE g.fecha BETWEEN ? AND ?
      GROUP BY mp.id ORDER BY total DESC
    ''', [desde, hasta]);

    // Cantidad de gastos
    final cantRes = await db.rawQuery(
      'SELECT COUNT(*) as cant FROM gastos WHERE fecha BETWEEN ? AND ?',
      [desde, hasta]);
    final cant = (cantRes.first['cant'] as num).toInt();

    return {
      'total': total,
      'cantidad': cant,
      'porCategoria': porCategoria,
      'porMedio': porMedio,
    };
  }


  // ─── CALENDARIO DE FACTURACIÓN ──────────────────────────────────

  /// Obtiene todos los períodos de una TC ordenados por año/mes
  Future<List<Map<String, dynamic>>> getCalendarioTC(int idMedioPago) async {
    final db = await database;
    return await db.query(
      'calendario_facturacion',
      where: 'id_medio_pago = ?',
      whereArgs: [idMedioPago],
      orderBy: 'anio DESC, mes DESC',
    );
  }

  /// Guarda o actualiza un período mensual
  Future<void> guardarPeriodoCalendario({
    required int idMedioPago,
    required int anio,
    required int mes,
    required DateTime desde,
    required DateTime hasta,
  }) async {
    final db = await database;
    await db.insert(
      'calendario_facturacion',
      {
        'id_medio_pago': idMedioPago,
        'anio': anio,
        'mes': mes,
        'desde': desde.toIso8601String(),
        'hasta': hasta.toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> eliminarPeriodoCalendario(int id) async {
    final db = await database;
    await db.delete('calendario_facturacion',
        where: 'id = ?', whereArgs: [id]);
  }

  /// Obtiene el período registrado para un mes/año específico de una TC
  Future<Map<String, DateTime>?> getPeriodoMes(
      int idMedioPago, int anio, int mes) async {
    final db = await database;
    final maps = await db.query(
      'calendario_facturacion',
      where: 'id_medio_pago = ? AND anio = ? AND mes = ?',
      whereArgs: [idMedioPago, anio, mes],
    );
    if (maps.isEmpty) return null;
    return {
      'desde': DateTime.parse(maps.first['desde'] as String),
      'hasta': DateTime.parse(maps.first['hasta'] as String),
    };
  }

  Future<void> close() async {
    final db = await database;
    db.close();
  }
}
