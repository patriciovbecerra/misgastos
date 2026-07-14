class MedioPago {
  final int? id;
  final String nombre;
  final String icono;
  final int? diaCierre; // día del mes que cierra la TC (1-31), null = sin cierre
  final String color;            // color hex del medio de pago
  final bool esTarjetaCredito;  // true = aparece en Facturación
  final bool esTarjetaAdicional; // true = es adicional de otra TC
  final int? idTcTitular;        // id del medio de pago titular

  MedioPago({
    this.id,
    required this.nombre,
    required this.icono,
    this.diaCierre,
    this.color = '#0288D1',
    this.esTarjetaCredito = false,
    this.esTarjetaAdicional = false,
    this.idTcTitular,
  });

  /// Calcula el rango del período de facturación actual
  /// Si cierra el 15: período va del 16 del mes anterior al 15 del mes actual
  /// Período EN CURSO — donde están cayendo los gastos actuales
  /// Ej: cierra el 15, hoy es 20 jul → período 16 jul → 15 ago
  /// Ej: cierra el 15, hoy es 10 jul → período 16 jun → 15 jul
  DateTimeRange? get periodoActual {
    if (diaCierre == null) return null;
    final hoy = DateTime.now();
    final cierre = diaCierre!;
    DateTime desde, hasta;
    if (hoy.day <= cierre) {
      // Antes del cierre → el período empezó el mes pasado y cierra este mes
      desde = DateTime(hoy.year, hoy.month - 1, cierre + 1);
      hasta = DateTime(hoy.year, hoy.month, cierre);
    } else {
      // Después del cierre → el período empezó este mes y cierra el siguiente
      desde = DateTime(hoy.year, hoy.month, cierre + 1);
      hasta = DateTime(hoy.year, hoy.month + 1, cierre);
    }
    return DateTimeRange(start: desde, end: hasta);
  }

  /// Período SIGUIENTE — el que se acumulará para pagar después
  DateTimeRange? get periodoSiguiente {
    final actual = periodoActual;
    if (actual == null) return null;
    final cierre = diaCierre!;
    final desde = DateTime(actual.end.year, actual.end.month, cierre + 1);
    final hasta = DateTime(actual.end.year, actual.end.month + 1, cierre);
    return DateTimeRange(start: desde, end: hasta);
  }

  /// Texto del período: "16 jun → 15 jul"
  String get textoPeriodo {
    final p = periodoActual;
    if (p == null) return 'Sin fecha de cierre';
    String fmt(DateTime d) =>
        '${d.day} ${_mes(d.month)}';
    return '${fmt(p.start)} → ${fmt(p.end)}';
  }

  /// Días que faltan para el cierre
  int? get diasParaCierre {
    if (diaCierre == null) return null;
    final hoy = DateTime.now();
    final cierre = diaCierre!;
    DateTime proxCierre;
    if (hoy.day <= cierre) {
      proxCierre = DateTime(hoy.year, hoy.month, cierre);
    } else {
      proxCierre = DateTime(hoy.year, hoy.month + 1, cierre);
    }
    return proxCierre.difference(DateTime(hoy.year, hoy.month, hoy.day)).inDays;
  }

  static String _mes(int m) {
    const meses = ['', 'ene', 'feb', 'mar', 'abr', 'may', 'jun',
        'jul', 'ago', 'sep', 'oct', 'nov', 'dic'];
    return meses[m];
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'nombre': nombre,
      'icono': icono,
      'dia_cierre': diaCierre,
      'color': color,
      'es_tarjeta_credito': esTarjetaCredito ? 1 : 0,
      'es_tarjeta_adicional': esTarjetaAdicional ? 1 : 0,
      'id_tc_titular': idTcTitular,
    };
  }

  factory MedioPago.fromMap(Map<String, dynamic> map) {
    return MedioPago(
      id: map['id'] as int?,
      nombre: map['nombre'] as String,
      icono: map['icono'] as String,
      diaCierre: map['dia_cierre'] as int?,
      color: map['color'] as String? ?? '#0288D1',
      esTarjetaCredito: (map['es_tarjeta_credito'] as int? ?? 0) == 1,
      esTarjetaAdicional: (map['es_tarjeta_adicional'] as int? ?? 0) == 1,
      idTcTitular: map['id_tc_titular'] as int?,
    );
  }

  MedioPago copyWith({int? id, String? nombre, String? icono, String? color, int? diaCierre, bool? esTarjetaCredito, bool? esTarjetaAdicional, int? idTcTitular}) {
    return MedioPago(
      id: id ?? this.id,
      nombre: nombre ?? this.nombre,
      icono: icono ?? this.icono,
      diaCierre: diaCierre ?? this.diaCierre,
      color: color ?? this.color,
      esTarjetaCredito: esTarjetaCredito ?? this.esTarjetaCredito,
      esTarjetaAdicional: esTarjetaAdicional ?? this.esTarjetaAdicional,
      idTcTitular: idTcTitular ?? this.idTcTitular,
    );
  }

  @override
  String toString() => 'MedioPago(id: \$id, nombre: \$nombre, cierre: \$diaCierre)';
}

class DateTimeRange {
  final DateTime start;
  final DateTime end;
  const DateTimeRange({required this.start, required this.end});
}
