import 'package:flutter/material.dart';
import 'package:misgastos/database/database_helper.dart';
import 'package:misgastos/models/gasto.dart';
import 'package:misgastos/models/medio_pago.dart';
import 'package:misgastos/models/categoria.dart';
import 'package:misgastos/models/grupo.dart';
import 'package:misgastos/models/participante.dart';
import 'package:misgastos/models/periodo.dart';

class GastosProvider extends ChangeNotifier {
  final DatabaseHelper _db = DatabaseHelper.instance;
  DatabaseHelper get db => _db;

  List<Gasto> _gastos = [];
  List<MedioPago> _mediosPago = [];
  List<Categoria> _categorias = [];
  List<Grupo> _grupos = [];
  bool _isLoading = false;
  String? _error;

  Periodo _periodo = Periodo.mesActual();

  List<Gasto> get gastos => _gastos;
  List<MedioPago> get mediosPago => _mediosPago;
  List<Categoria> get categorias => _categorias;
  List<Grupo> get grupos => _grupos;
  bool get isLoading => _isLoading;
  String? get error => _error;
  Periodo get periodo => _periodo;

  double get totalMes => _gastos.fold(0, (sum, g) => sum + g.valorCuota);

  Future<void> inicializar() async {
    _setLoading(true);
    try {
      await Future.wait([
        cargarGastosPeriodo(),
        cargarMediosPago(),
        cargarCategorias(),
        cargarGrupos(),
      ]);
    } catch (e) {
      _error = e.toString();
    } finally {
      _setLoading(false);
    }
  }

  // ─── Gastos ───────────────────────────────────────────────────────
  Future<void> cargarGastosPeriodo([Periodo? periodo]) async {
    if (periodo != null) _periodo = periodo;
    _setLoading(true);
    try {
      _gastos = await _db.getGastosByRango(_periodo.desde, _periodo.hasta);
      _error = null;
    } catch (e) {
      _error = e.toString();
    } finally {
      _setLoading(false);
    }
  }

  // Alias para compatibilidad
  Future<void> cargarGastosMes({int? mes, int? anio}) async {
    final p = Periodo.mes(
      mes ?? _periodo.desde.month,
      anio ?? _periodo.desde.year,
    );
    await cargarGastosPeriodo(p);
  }

  Future<bool> agregarGasto(Gasto gasto, {int cuotasYaPagadas = 0}) async {
    try {
      await _db.insertGastoConCuotas(gasto, cuotasYaPagadas: cuotasYaPagadas);
      await cargarGastosMes();
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<List<Gasto>> getCuotasPendientes() async {
    return await _db.getCuotasPendientes();
  }

  Future<bool> editarGasto(Gasto gasto) async {
    try {
      await _db.updateGasto(gasto);
      await cargarGastosMes();
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> eliminarGasto(int id) async {
    try {
      await _db.deleteGasto(id);
      await cargarGastosMes();
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  // ─── Medios de pago ───────────────────────────────────────────────
  Future<void> cargarMediosPago() async {
    _mediosPago = await _db.getMediosPago();
    notifyListeners();
  }

  Future<bool> agregarMedioPago(MedioPago medio) async {
    try {
      await _db.insertMedioPago(medio);
      await cargarMediosPago();
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> editarMedioPago(MedioPago medio) async {
    try {
      await _db.updateMedioPago(medio);
      await cargarMediosPago();
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> eliminarMedioPago(int id) async {
    try {
      await _db.deleteMedioPago(id);
      await cargarMediosPago();
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  // ─── Categorías ───────────────────────────────────────────────────
  Future<void> cargarCategorias() async {
    _categorias = await _db.getCategorias();
    notifyListeners();
  }

  Future<bool> agregarCategoria(Categoria categoria) async {
    try {
      await _db.insertCategoria(categoria);
      await cargarCategorias();
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> editarCategoria(Categoria categoria) async {
    try {
      await _db.updateCategoria(categoria);
      await cargarCategorias();
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> eliminarCategoria(int id) async {
    try {
      await _db.deleteCategoria(id);
      await cargarCategorias();
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  // ─── Grupos ───────────────────────────────────────────────────────
  Future<void> cargarGrupos() async {
    _grupos = await _db.getGrupos();
    notifyListeners();
  }

  Future<bool> agregarGrupo(Grupo grupo) async {
    try {
      await _db.insertGrupo(grupo);
      await cargarGrupos();
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> editarGrupo(Grupo grupo) async {
    try {
      await _db.updateGrupo(grupo);
      await cargarGrupos();
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> eliminarGrupo(int id) async {
    try {
      await _db.deleteGrupo(id);
      await cargarGrupos();
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  // ─── Participantes ───────────────────────────────────────────────
  Future<List<Participante>> getParticipantes(int idGrupo) async {
    return await _db.getParticipantesByGrupo(idGrupo);
  }

  Future<bool> agregarParticipante(Participante p) async {
    try {
      await _db.insertParticipante(p);
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> eliminarParticipante(int id) async {
    try {
      await _db.deleteParticipante(id);
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  // ─── Análisis / Dashboard ─────────────────────────────────────────
  Future<List<Map<String, dynamic>>> getAnalisisMedioPago() async {
    return await _db.getTotalPorRangoMedioPago(_periodo.desde, _periodo.hasta);
  }

  Future<List<Map<String, dynamic>>> getAnalisisCategoria() async {
    return await _db.getTotalPorRangoCategoria(_periodo.desde, _periodo.hasta);
  }

  Future<Map<String, double>> getAnalisisIndividualVsCompartido() async {
    return await _db.getTotalIndividualVsCompartidoRango(_periodo.desde, _periodo.hasta);
  }

  Future<List<Map<String, dynamic>>> getResumenAnual() async {
    return await _db.getResumenAnual(_periodo.desde.year);
  }

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  void limpiarError() {
    _error = null;
    notifyListeners();
  }
}
