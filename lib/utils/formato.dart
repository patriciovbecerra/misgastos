import 'package:intl/intl.dart';

class Formato {
  // Formatea monto en pesos chilenos: $1.234.567
  static String moneda(double monto) {
    final formatter = NumberFormat.currency(
      locale: 'es_CL',
      symbol: '\$',
      decimalDigits: 0,
    );
    return formatter.format(monto);
  }

  // Fecha corta: 15 jun
  static String fechaCorta(DateTime fecha) {
    return DateFormat('d MMM', 'es').format(fecha);
  }

  // Fecha larga: lunes 15 de junio de 2025
  static String fechaLarga(DateTime fecha) {
    return DateFormat('EEEE d \'de\' MMMM \'de\' y', 'es').format(fecha);
  }

  // Mes y año: junio 2025
  static String mesAnio(int mes, int anio) {
    final fecha = DateTime(anio, mes);
    return DateFormat('MMMM y', 'es').format(fecha);
  }

  // Solo mes: junio
  static String nombreMes(int mes) {
    final fecha = DateTime(2000, mes);
    return DateFormat('MMMM', 'es').format(fecha);
  }

  // Porcentaje: 34.5%
  static String porcentaje(double valor) {
    return '${valor.toStringAsFixed(1)}%';
  }
}
