import 'package:intl/intl.dart';

class Formato {
  static final _numFmt = NumberFormat('#,##0', 'es_CL');

  /// Moneda chilena: $1.234.567
  static String moneda(double monto) {
    final num = _numFmt.format(monto.abs());
    return monto < 0 ? '-\$$num' : '\$$num';
  }

  static String fechaCorta(DateTime fecha) =>
      DateFormat('d MMM', 'es').format(fecha);

  static String fechaLarga(DateTime fecha) =>
      DateFormat("EEEE d 'de' MMMM 'de' y", 'es').format(fecha);

  static String mesAnio(int mes, int anio) =>
      DateFormat('MMMM y', 'es').format(DateTime(anio, mes));

  static String nombreMes(int mes) =>
      DateFormat('MMMM', 'es').format(DateTime(2000, mes));

  static String porcentaje(double valor) =>
      '${valor.toStringAsFixed(1)}%';
}
