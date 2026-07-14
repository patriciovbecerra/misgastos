/// Representa un rango de fechas seleccionado por el usuario
class Periodo {
  final DateTime desde;
  final DateTime hasta;
  final String etiqueta; // texto para mostrar en la UI

  const Periodo({
    required this.desde,
    required this.hasta,
    required this.etiqueta,
  });

  /// Mes completo
  factory Periodo.mes(int mes, int anio) {
    final desde = DateTime(anio, mes, 1);
    final hasta = DateTime(anio, mes + 1, 0, 23, 59, 59);
    return Periodo(
      desde: desde,
      hasta: hasta,
      etiqueta: _nombreMes(mes, anio),
    );
  }

  /// Mes actual
  factory Periodo.mesActual() {
    final hoy = DateTime.now();
    return Periodo.mes(hoy.month, hoy.year);
  }

  /// Rango personalizado
  factory Periodo.personalizado(DateTime desde, DateTime hasta) {
    final f = _fmt(desde);
    final t = _fmt(hasta);
    return Periodo(
      desde: desde,
      hasta: DateTime(hasta.year, hasta.month, hasta.day, 23, 59, 59),
      etiqueta: '$f – $t',
    );
  }

  /// Últimos N días
  factory Periodo.ultimosDias(int dias) {
    final hasta = DateTime.now();
    final desde = hasta.subtract(Duration(days: dias - 1));
    return Periodo(
      desde: DateTime(desde.year, desde.month, desde.day),
      hasta: DateTime(hasta.year, hasta.month, hasta.day, 23, 59, 59),
      etiqueta: 'Últimos $dias días',
    );
  }

  /// Año completo
  factory Periodo.anio(int anio) {
    return Periodo(
      desde: DateTime(anio, 1, 1),
      hasta: DateTime(anio, 12, 31, 23, 59, 59),
      etiqueta: 'Año $anio',
    );
  }

  static String _fmt(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  static String _nombreMes(int mes, int anio) {
    const meses = [
      '', 'Enero', 'Febrero', 'Marzo', 'Abril', 'Mayo', 'Junio',
      'Julio', 'Agosto', 'Septiembre', 'Octubre', 'Noviembre', 'Diciembre'
    ];
    return '${meses[mes]} $anio';
  }

  bool get esMesCompleto {
    return desde.day == 1 &&
        hasta.day == DateTime(hasta.year, hasta.month + 1, 0).day;
  }
}
