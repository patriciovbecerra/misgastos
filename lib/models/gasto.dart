import 'package:misgastos/models/medio_pago.dart';
import 'package:misgastos/models/categoria.dart';
import 'package:misgastos/models/grupo.dart';

class Gasto {
  final int? id;
  final double monto;          // monto TOTAL de la compra
  final double valorCuota;     // monto por cuota (monto / cuotasTotal)
  final int cuotasTotal;       // total de cuotas (ej: 12)
  final int cuotaNumero;       // qué cuota es esta (ej: 3 de 12)
  final int? idCompraOrigen;   // agrupa todas las cuotas de una misma compra
  final DateTime fecha;        // fecha de esta cuota (mes en que se paga)
  final DateTime fechaCompra;  // fecha original de la compra
  final String? descripcion;
  final bool esCompartido;
  final int idMedioPago;
  final int idCategoria;
  final int? idGrupo;

  // Relaciones
  final MedioPago? medioPago;
  final Categoria? categoria;
  final Grupo? grupo;

  Gasto({
    this.id,
    required this.monto,
    required this.valorCuota,
    this.cuotasTotal = 1,
    this.cuotaNumero = 1,
    this.idCompraOrigen,
    required this.fecha,
    DateTime? fechaCompra,
    this.descripcion,
    required this.esCompartido,
    required this.idMedioPago,
    required this.idCategoria,
    this.idGrupo,
    this.medioPago,
    this.categoria,
    this.grupo,
  }) : fechaCompra = fechaCompra ?? fecha;

  bool get esCuotado => cuotasTotal > 1;
  bool get esUltimaCuota => cuotaNumero == cuotasTotal;
  String get etiquetaCuota => esCuotado ? 'Cuota $cuotaNumero/$cuotasTotal' : '';

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'monto': monto,
      'valor_cuota': valorCuota,
      'cuotas_total': cuotasTotal,
      'cuota_numero': cuotaNumero,
      'id_compra_origen': idCompraOrigen,
      'fecha': fecha.toIso8601String(),
      'fecha_compra': fechaCompra.toIso8601String(),
      'descripcion': descripcion,
      'es_compartido': esCompartido ? 1 : 0,
      'id_medio_pago': idMedioPago,
      'id_categoria': idCategoria,
      'id_grupo': idGrupo,
    };
  }

  factory Gasto.fromMap(Map<String, dynamic> map) {
    return Gasto(
      id: map['id'] as int?,
      monto: (map['monto'] as num).toDouble(),
      valorCuota: map['valor_cuota'] != null
          ? (map['valor_cuota'] as num).toDouble()
          : (map['monto'] as num).toDouble(),
      cuotasTotal: (map['cuotas_total'] as int?) ?? 1,
      cuotaNumero: (map['cuota_numero'] as int?) ?? 1,
      idCompraOrigen: map['id_compra_origen'] as int?,
      fecha: DateTime.parse(map['fecha'] as String),
      fechaCompra: map['fecha_compra'] != null
          ? DateTime.parse(map['fecha_compra'] as String)
          : DateTime.parse(map['fecha'] as String),
      descripcion: map['descripcion'] as String?,
      esCompartido: (map['es_compartido'] as int) == 1,
      idMedioPago: map['id_medio_pago'] as int,
      idCategoria: map['id_categoria'] as int,
      idGrupo: map['id_grupo'] as int?,
    );
  }

  Gasto copyWith({
    int? id,
    double? monto,
    double? valorCuota,
    int? cuotasTotal,
    int? cuotaNumero,
    int? idCompraOrigen,
    DateTime? fecha,
    DateTime? fechaCompra,
    String? descripcion,
    bool? esCompartido,
    int? idMedioPago,
    int? idCategoria,
    int? idGrupo,
    MedioPago? medioPago,
    Categoria? categoria,
    Grupo? grupo,
  }) {
    return Gasto(
      id: id ?? this.id,
      monto: monto ?? this.monto,
      valorCuota: valorCuota ?? this.valorCuota,
      cuotasTotal: cuotasTotal ?? this.cuotasTotal,
      cuotaNumero: cuotaNumero ?? this.cuotaNumero,
      idCompraOrigen: idCompraOrigen ?? this.idCompraOrigen,
      fecha: fecha ?? this.fecha,
      fechaCompra: fechaCompra ?? this.fechaCompra,
      descripcion: descripcion ?? this.descripcion,
      esCompartido: esCompartido ?? this.esCompartido,
      idMedioPago: idMedioPago ?? this.idMedioPago,
      idCategoria: idCategoria ?? this.idCategoria,
      idGrupo: idGrupo ?? this.idGrupo,
      medioPago: medioPago ?? this.medioPago,
      categoria: categoria ?? this.categoria,
      grupo: grupo ?? this.grupo,
    );
  }
}
