import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:misgastos/models/gasto.dart';
import 'package:misgastos/models/medio_pago.dart';
import 'package:misgastos/providers/gastos_provider.dart';
import 'package:misgastos/utils/formato.dart';
import 'package:misgastos/utils/exportar_excel.dart';
import 'package:misgastos/utils/iconos.dart';

class PantallaFacturacion extends StatefulWidget {
  const PantallaFacturacion({super.key});

  @override
  State<PantallaFacturacion> createState() => _PantallaFacturacionState();
}

class _PantallaFacturacionState extends State<PantallaFacturacion> {
  // Rango personalizado por cada medio de pago (id → desde/hasta)
  final Map<int, DateTime> _desdeMap = {};
  final Map<int, DateTime> _hastaMap = {};
  // Gastos por medio de pago
  Map<int, List<Gasto>> _gastosPorMedio = {};
  bool _cargando = true;
  // 0=Todos, 1=Mis gastos, 2=Grupos
  int _filtroTipo = 0;

  static Color _hexColor(String hex) {
    final h = hex.replaceAll('#', '');
    return Color(int.parse('FF$h', radix: 16));
  }

  @override
  void initState() {
    super.initState();
    _inicializarRangos();
  }

  /// Inicializa el rango de cada TC — carga desde BD si fue guardado antes
  Future<void> _inicializarRangos() async {
    final provider = context.read<GastosProvider>();
    final hoy = DateTime.now();

    // Cargar períodos guardados en BD
    final guardados = await provider.db.getPeriodosFacturacion();

    // Solo cargar para TCs
    for (final medio in provider.mediosPago.where((m) => m.esTarjetaCredito)) {
      if (medio.id == null) continue;
      if (_desdeMap.containsKey(medio.id)) continue;

      // Calcular mes siguiente
      final mesSig = hoy.month == 12 ? 1 : hoy.month + 1;
      final anioSig = hoy.month == 12 ? hoy.year + 1 : hoy.year;

      // 1. Buscar en el calendario el período del MES SIGUIENTE
      final periodoSiguiente = await provider.db
          .getPeriodoMes(medio.id!, anioSig, mesSig);

      if (periodoSiguiente != null) {
        // Tiene registrado el período del mes siguiente → usarlo
        _desdeMap[medio.id!] = periodoSiguiente['desde']!;
        _hastaMap[medio.id!] = periodoSiguiente['hasta']!;
      } else {
        // No tiene calendario del siguiente → mostrar mes actual
        final periodoActual = await provider.db
            .getPeriodoMes(medio.id!, hoy.year, hoy.month);
        if (periodoActual != null) {
          _desdeMap[medio.id!] = periodoActual['desde']!;
          _hastaMap[medio.id!] = periodoActual['hasta']!;
        } else if (guardados.containsKey(medio.id)) {
          _desdeMap[medio.id!] = guardados[medio.id]!['desde']!;
          _hastaMap[medio.id!] = guardados[medio.id]!['hasta']!;
        } else if (medio.diaCierre != null) {
          // Sin calendario → calcular mes actual desde día de cierre
          final p = medio.periodoActual!;
          _desdeMap[medio.id!] = p.start;
          _hastaMap[medio.id!] = p.end;
        } else {
          _desdeMap[medio.id!] = DateTime(hoy.year, hoy.month, 1);
          _hastaMap[medio.id!] = DateTime(hoy.year, hoy.month + 1, 0);
        }
      }
    }
    _cargarDatos();
  }

  Future<void> _exportarExcel() async {
    final provider = context.read<GastosProvider>();
    // Recopilar todos los gastos visibles
    List<Gasto> todos = [];
    for (final medio in provider.mediosPago.where((m) => m.esTarjetaCredito)) {
      if (medio.id == null) continue;
      final gastos = _gastosPorMedio[medio.id] ?? [];
      final filtrados = _filtroTipo == 0
          ? gastos
          : _filtroTipo == 1
              ? gastos.where((g) => !g.esCompartido).toList()
              : gastos.where((g) => g.esCompartido).toList();
      todos.addAll(filtrados);
    }
    if (todos.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No hay gastos para exportar')));
      return;
    }
    try {
      final desde = _desdeMap.values.isNotEmpty
          ? Formato.fechaCorta(_desdeMap.values.first)
          : '';
      final hasta = _hastaMap.values.isNotEmpty
          ? Formato.fechaCorta(_hastaMap.values.first)
          : '';
      await ExportarExcel.exportarGastos(
        gastos: todos,
        periodoLabel: '\$desde → \$hasta',
      );
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al exportar: \$e')));
    }
  }

  Future<void> _cargarDatos() async {
    setState(() => _cargando = true);
    final provider = context.read<GastosProvider>();
    final hoy = DateTime.now();
    final mapa = <int, List<Gasto>>{};

    // Recargar períodos del calendario para cada TC (por si fueron editados)
    for (final medio in provider.mediosPago.where((m) => m.esTarjetaCredito)) {
      if (medio.id == null) continue;
      // Si el usuario no cambió el rango manualmente, buscar en el calendario
      final periodoCalendario = await provider.db
          .getPeriodoMes(medio.id!, hoy.year, hoy.month);
      // En recarga: buscar período siguiente, si no hay usar actual
      final mesSigR = hoy.month == 12 ? 1 : hoy.month + 1;
      final anioSigR = hoy.month == 12 ? hoy.year + 1 : hoy.year;
      final periodoSig = await provider.db
          .getPeriodoMes(medio.id!, anioSigR, mesSigR);
      final periodoAct = await provider.db
          .getPeriodoMes(medio.id!, hoy.year, hoy.month);
      final p = periodoSig ?? periodoAct;
      if (p != null) {
        _desdeMap[medio.id!] = p['desde']!;
        _hastaMap[medio.id!] = p['hasta']!;
      }
    }

    // Cargar gastos para TCs titulares y sus adicionales
    final todosLosmedios = [
      ...provider.mediosPago.where((m) => m.esTarjetaCredito),
      ...provider.mediosPago.where((m) => m.esTarjetaAdicional),
    ];
    for (final medio in todosLosmedios) {
      if (medio.id == null) continue;
      // Las adicionales usan el rango de su TC titular
      final idRango = medio.esTarjetaAdicional && medio.idTcTitular != null
          ? medio.idTcTitular!
          : medio.id!;
      final desde = _desdeMap[idRango] ?? DateTime(hoy.year, hoy.month, 1);
      final hastaBase = _hastaMap[idRango] ?? DateTime(hoy.year, hoy.month + 1, 0);
      final hasta = DateTime(hastaBase.year, hastaBase.month, hastaBase.day,
          23, 59, 59);

      final todos = await provider.db.getGastosByRango(desde, hasta);
      mapa[medio.id!] = todos
          .where((g) => g.idMedioPago == medio.id)
          .toList()
        ..sort((a, b) => b.fecha.compareTo(a.fecha));
    }

    if (mounted) setState(() { _gastosPorMedio = mapa; _cargando = false; });
  }

  /// Construye el resumen de lo que deben las tarjetas adicionales
  List<Widget> _buildResumenAdicionales(GastosProvider provider, ColorScheme cs) {
    final adicionales = provider.mediosPago.where((m) => m.esTarjetaAdicional).toList();
    if (adicionales.isEmpty) return [];

    final widgets = <Widget>[];
    widgets.add(Text('Lo que te deben',
        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: cs.tertiary)));
    widgets.add(const SizedBox(height: 10));

    double totalDeben = 0;

    for (final adicional in adicionales) {
      final gastos = _gastosPorMedio[adicional.id] ?? [];
      // Solo los gastos NO compartidos son responsabilidad exclusiva de la adicional
      final gastosPropio = gastos.where((g) => !g.esCompartido).toList();
      // Los compartidos se dividen (solo la mitad corresponde a la adicional)
      final gastosComp = gastos.where((g) => g.esCompartido).toList();

      final montoPropio = gastosPropio.fold(0.0, (s, g) => s + g.valorCuota);
      final montoComp = gastosComp.fold(0.0, (s, g) => s + g.valorCuota) / 2;
      final totalAdicional = montoPropio + montoComp;
      totalDeben += totalAdicional;

      // Buscar nombre de TC titular
      final titular = provider.mediosPago
          .where((m) => m.id == adicional.idTcTitular)
          .firstOrNull;

      widgets.add(Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: cs.tertiary.withOpacity(0.3), width: 1.5),
          boxShadow: [BoxShadow(color: cs.shadow.withOpacity(0.04), blurRadius: 6)],
        ),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  width: 42, height: 42,
                  decoration: BoxDecoration(
                    color: cs.tertiaryContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.card_membership, color: cs.tertiary, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(adicional.nombre,
                          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                      if (titular != null)
                        Text('Adicional de ${titular.nombre}',
                            style: TextStyle(fontSize: 11, color: cs.outline)),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(Formato.moneda(totalAdicional),
                        style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900,
                            color: cs.tertiary)),
                    Text('debe transferirte', style: TextStyle(fontSize: 10, color: cs.outline)),
                  ],
                ),
              ],
            ),
            if (gastosPropio.isNotEmpty || gastosComp.isNotEmpty) ...[
              const SizedBox(height: 10),
              const Divider(height: 1),
              const SizedBox(height: 8),
              Row(
                children: [
                  if (gastosPropio.isNotEmpty)
                    Expanded(
                      child: _MiniResumen(
                        label: 'Gastos propios',
                        valor: Formato.moneda(montoPropio),
                        n: gastosPropio.length,
                        color: cs.tertiary,
                      ),
                    ),
                  if (gastosPropio.isNotEmpty && gastosComp.isNotEmpty)
                    Container(width: 1, height: 32, color: cs.outline.withOpacity(0.15),
                        margin: const EdgeInsets.symmetric(horizontal: 8)),
                  if (gastosComp.isNotEmpty)
                    Expanded(
                      child: _MiniResumen(
                        label: 'Su parte compartida',
                        valor: Formato.moneda(montoComp),
                        n: gastosComp.length,
                        color: cs.secondary,
                        alignRight: true,
                      ),
                    ),
                ],
              ),
            ],
          ],
        ),
      ));
    }

    if (adicionales.length > 1) {
      widgets.add(Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: cs.tertiaryContainer.withOpacity(0.5),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Total que te deben',
                style: TextStyle(fontWeight: FontWeight.w700, color: cs.tertiary)),
            Text(Formato.moneda(totalDeben),
                style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: cs.tertiary)),
          ],
        ),
      ));
    }

    return widgets;
  }

  /// Abre el selector de rango para una TC específica
  Future<void> _seleccionarRango(MedioPago medio) async {
    DateTime desde = _desdeMap[medio.id!] ?? DateTime.now();
    DateTime hasta = _hastaMap[medio.id!] ?? DateTime.now();

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => _SelectorRangoTC(
        medio: medio,
        desde: desde,
        hasta: hasta,
        onAplicar: (d, h) {
          setState(() {
            _desdeMap[medio.id!] = d;
            _hastaMap[medio.id!] = h;
          });
          _cargarDatos();
        },
      ),
    );
  }

  static Color _hexToColor(String hex) =>
      Color(int.parse('FF${hex.replaceAll('#', '')}', radix: 16));

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<GastosProvider>();
    final cs = Theme.of(context).colorScheme;
    // Solo mostrar tarjetas de crédito
    final medios = provider.mediosPago.where((m) => m.esTarjetaCredito).toList();

    // Total solo de las TCs visibles
    double totalGeneral = 0;
    for (final medio in medios) {
      final todosG = _gastosPorMedio[medio.id] ?? [];
      final gastosG = _filtroTipo == 0
          ? todosG
          : _filtroTipo == 1
              ? todosG.where((g) => !g.esCompartido).toList()
              : todosG.where((g) => g.esCompartido).toList();
      totalGeneral += gastosG.fold(0.0, (s, g) => s + g.valorCuota);
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Facturación'),
        actions: [
          IconButton(
            icon: const Icon(Icons.file_download_outlined),
            tooltip: 'Exportar Excel',
            onPressed: _exportarExcel,
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _cargarDatos,
            tooltip: 'Actualizar',
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(44),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
            child: Row(
              children: [
                Expanded(child: _BtnFiltroTipo(
                  label: 'Todos',
                  activo: _filtroTipo == 0,
                  onTap: () => setState(() => _filtroTipo = 0),
                  cs: cs,
                )),
                const SizedBox(width: 6),
                Expanded(child: _BtnFiltroTipo(
                  label: 'Mis gastos',
                  icono: Icons.person_outline,
                  activo: _filtroTipo == 1,
                  onTap: () => setState(() => _filtroTipo = 1),
                  cs: cs,
                )),
                const SizedBox(width: 6),
                Expanded(child: _BtnFiltroTipo(
                  label: 'Grupos',
                  icono: Icons.group_outlined,
                  activo: _filtroTipo == 2,
                  onTap: () => setState(() => _filtroTipo = 2),
                  cs: cs,
                )),
              ],
            ),
          ),
        ),
      ),
      body: _cargando
          ? const Center(child: CircularProgressIndicator())
          : medios.isEmpty
              ? _EstadoVacio()
              : RefreshIndicator(
                  onRefresh: _cargarDatos,
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [

                      // ── Banner total ─────────────────────────────
                      _BannerTotal(total: totalGeneral, nTarjetas: medios.length),
                      const SizedBox(height: 20),

                      // ── Lo que te deben (adicionales) ───────────
                      ..._buildResumenAdicionales(provider, cs),
                      if (_buildResumenAdicionales(provider, cs).isNotEmpty)
                        const SizedBox(height: 20),

                      // ── Una sección por TC ───────────────────────
                      ...medios.map((medio) {
                        final todosGastos = _gastosPorMedio[medio.id] ?? [];
                        final gastos = _filtroTipo == 0
                            ? todosGastos
                            : _filtroTipo == 1
                                ? todosGastos.where((g) => !g.esCompartido).toList()
                                : todosGastos.where((g) => g.esCompartido).toList();
                        final total = gastos.fold(0.0, (s, g) => s + g.valorCuota);
                        final desde = _desdeMap[medio.id!];
                        final hasta = _hastaMap[medio.id!];
                        return _SeccionTarjeta(
                          medio: medio,
                          gastos: gastos,
                          total: total,
                          desde: desde,
                          hasta: hasta,
                          onEditarRango: () => _seleccionarRango(medio),
                        );
                      }),

                      const SizedBox(height: 80),
                    ],
                  ),
                ),
    );
  }
}

// ─── Selector de rango por TC ─────────────────────────────────────────────────

class _SelectorRangoTC extends StatefulWidget {
  final MedioPago medio;
  final DateTime desde;
  final DateTime hasta;
  final void Function(DateTime, DateTime) onAplicar;

  const _SelectorRangoTC({
    required this.medio,
    required this.desde,
    required this.hasta,
    required this.onAplicar,
  });

  @override
  State<_SelectorRangoTC> createState() => _SelectorRangoTCState();
}

class _SelectorRangoTCState extends State<_SelectorRangoTC> {
  late DateTime _desde;
  late DateTime _hasta;

  @override
  void initState() {
    super.initState();
    _desde = widget.desde;
    _hasta = widget.hasta;
  }

  String _fmt(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  Future<void> _pickFecha(bool esDesde) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: esDesde ? _desde : _hasta,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),

      helpText: esDesde ? 'Inicio del período' : 'Fin del período',
    );
    if (picked != null) {
      setState(() => esDesde ? _desde = picked : _hasta = picked);
    }
  }

  /// Aplica el rango calculado desde el día de cierre
  void _aplicarDesdeCierre(int diaCierre) {
    final hoy = DateTime.now();
    DateTime desde, hasta;
    if (hoy.day <= diaCierre) {
      desde = DateTime(hoy.year, hoy.month - 1, diaCierre + 1);
      hasta = DateTime(hoy.year, hoy.month, diaCierre);
    } else {
      desde = DateTime(hoy.year, hoy.month, diaCierre + 1);
      hasta = DateTime(hoy.year, hoy.month + 1, diaCierre);
    }
    setState(() { _desde = desde; _hasta = hasta; });
  }

  static Color _hexToColor(String hex) =>
      Color(int.parse('FF${hex.replaceAll('#', '')}', radix: 16));

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final hoy = DateTime.now();
    final ordenOk = !_desde.isAfter(_hasta);
    final dias = _hasta.difference(_desde).inDays + 1;

    return Padding(
      padding: EdgeInsets.only(
        left: 20, right: 20, top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Handle
          Center(
            child: Container(
              width: 40, height: 4,
              decoration: BoxDecoration(
                color: cs.outlineVariant,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Título
          Row(
            children: [
              Icon(Iconos.get(widget.medio.icono), color: cs.primary, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(widget.medio.nombre,
                        style: const TextStyle(
                            fontSize: 17, fontWeight: FontWeight.w800)),
                    Text('Período de facturación',
                        style: TextStyle(fontSize: 12, color: cs.outline)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),


          // Accesos rápidos desde el CALENDARIO registrado de la TC
          FutureBuilder<List<Map<String, dynamic>>>(
            future: Provider.of<GastosProvider>(context, listen: false)
                .db.getCalendarioTC(widget.medio.id!),
            builder: (ctx2, snap) {
              final periodos = snap.data ?? [];
              if (periodos.isEmpty) return const SizedBox();
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Períodos registrados de ${widget.medio.nombre}',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600,
                          color: cs.outline)),
                  const SizedBox(height: 8),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: periodos.map((p) {
                        final desde = DateTime.parse(p['desde'] as String);
                        final hasta = DateTime.parse(p['hasta'] as String);
                        final sel = _desde.year == desde.year &&
                            _desde.month == desde.month &&
                            _desde.day == desde.day;
                        final mes = p['mes'] as int;
                        final anio = p['anio'] as int;
                        return GestureDetector(
                          onTap: () => setState(() { _desde = desde; _hasta = hasta; }),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 120),
                            margin: const EdgeInsets.only(right: 8),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: sel ? cs.primaryContainer
                                  : cs.surfaceContainerHighest,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: sel ? cs.primary : Colors.transparent,
                                width: 2,
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(Formato.nombreMes(mes) + ' $anio',
                                    style: TextStyle(
                                        fontSize: 11, fontWeight: FontWeight.w700,
                                        color: sel ? cs.primary : cs.onSurface)),
                                Text(
                                  '${desde.day}/${desde.month} → ${hasta.day}/${hasta.month}',
                                  style: TextStyle(fontSize: 10,
                                      color: sel ? cs.primary : cs.outline),
                                ),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Divider(),
                  const SizedBox(height: 12),
                ],
              );
            },
          ),

          // Accesos rápidos si tiene día de cierre
          if (widget.medio.diaCierre != null) ...[
            Text('Períodos rápidos (cierra día \${widget.medio.diaCierre})',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600,
                    color: cs.outline)),
            const SizedBox(height: 10),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: List.generate(5, (i) {
                  final cierre = widget.medio.diaCierre!;
                  final offset = i - 2;
                  final base = DateTime(hoy.year, hoy.month + offset, 1);
                  DateTime d, h;
                  if (hoy.day <= cierre) {
                    d = DateTime(base.year, base.month - 1, cierre + 1);
                    h = DateTime(base.year, base.month, cierre);
                  } else {
                    d = DateTime(base.year, base.month, cierre + 1);
                    h = DateTime(base.year, base.month + 1, cierre);
                  }
                  final esSeleccionado = _desde.year == d.year &&
                      _desde.month == d.month && _desde.day == d.day;
                  final esEnCurso = i == 2;

                  return GestureDetector(
                    onTap: () => setState(() { _desde = d; _hasta = h; }),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 120),
                      margin: const EdgeInsets.only(right: 8),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: esSeleccionado
                            ? cs.primaryContainer
                            : cs.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: esSeleccionado
                              ? cs.primary
                              : esEnCurso
                                  ? cs.primary.withOpacity(0.4)
                                  : Colors.transparent,
                          width: esSeleccionado ? 2 : 1.5,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (esEnCurso)
                            Text('EN CURSO',
                                style: TextStyle(fontSize: 9,
                                    fontWeight: FontWeight.w800,
                                    color: cs.primary)),
                          Text(
                            '${d.day}/${d.month} → ${h.day}/${h.month}',
                            style: TextStyle(
                              fontSize: 12, fontWeight: FontWeight.w700,
                              color: esSeleccionado ? cs.primary : cs.onSurface,
                            ),
                          ),
                          Text(
                            Formato.nombreMes(h.month) + ' ' + h.year.toString(),
                            style: TextStyle(fontSize: 10,
                                color: esSeleccionado ? cs.primary : cs.outline),
                          ),
                        ],
                      ),
                    ),
                  );
                }),
              ),
            ),
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 12),
          ],

          const SizedBox(height: 16),

          // Botones
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  style: OutlinedButton.styleFrom(
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 13),
                  ),
                  child: const Text('Cancelar'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 2,
                child: FilledButton(
                  onPressed: ordenOk
                      ? () {
                          widget.onAplicar(_desde, _hasta);
                          Navigator.pop(context);
                        }
                      : null,
                  style: FilledButton.styleFrom(
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 13),
                  ),
                  child: const Text('Aplicar período'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _FilaFecha extends StatelessWidget {
  final String label;
  final DateTime fecha;
  final IconData icono;
  final Color color;
  final VoidCallback onTap;

  const _FilaFecha({
    required this.label,
    required this.fecha,
    required this.icono,
    required this.color,
    required this.onTap,
  });

  static Color _hexToColor(String hex) =>
      Color(int.parse('FF${hex.replaceAll('#', '')}', radix: 16));

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          border: Border.all(color: color.withOpacity(0.4)),
          borderRadius: BorderRadius.circular(12),
          color: color.withOpacity(0.05),
        ),
        child: Row(
          children: [
            Icon(icono, size: 18, color: color),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: TextStyle(fontSize: 10, color: cs.outline)),
                Text(Formato.fechaLarga(fecha),
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: color)),
              ],
            ),
            const Spacer(),
            Icon(Icons.edit_calendar_outlined, size: 16, color: cs.outline),
          ],
        ),
      ),
    );
  }
}

// ─── Banner total ─────────────────────────────────────────────────────────────

class _BannerTotal extends StatelessWidget {
  final double total;
  final int nTarjetas;
  const _BannerTotal({required this.total, required this.nTarjetas});

  static Color _hexToColor(String hex) =>
      Color(int.parse('FF${hex.replaceAll('#', '')}', radix: 16));

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF0288D1), Color(0xFF29B6F6)],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0288D1).withOpacity(0.3),
            blurRadius: 12, offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Total facturado',
                    style: TextStyle(color: Colors.white70, fontSize: 12)),
                const SizedBox(height: 4),
                Text(Formato.moneda(total),
                    style: const TextStyle(
                        color: Colors.white, fontSize: 28,
                        fontWeight: FontWeight.w900, letterSpacing: -0.5)),
                const SizedBox(height: 4),
                Text('en $nTarjetas tarjetas / medios de pago',
                    style: const TextStyle(color: Colors.white60, fontSize: 11)),
              ],
            ),
          ),
          const Icon(Icons.credit_card, color: Colors.white24, size: 48),
        ],
      ),
    );
  }
}

// ─── Sección por tarjeta ──────────────────────────────────────────────────────

class _SeccionTarjeta extends StatefulWidget {
  final MedioPago medio;
  final List<Gasto> gastos;
  final double total;
  final DateTime? desde;
  final DateTime? hasta;
  final VoidCallback onEditarRango;

  const _SeccionTarjeta({
    required this.medio,
    required this.gastos,
    required this.total,
    required this.desde,
    required this.hasta,
    required this.onEditarRango,
  });

  @override
  State<_SeccionTarjeta> createState() => _SeccionTarjetaState();
}

class _SeccionTarjetaState extends State<_SeccionTarjeta> {
  bool _expandido = true;

  static Color _hex(String hex) =>
      Color(int.parse('FF${hex.replaceAll('#', '')}', radix: 16));

  static Color _hexColor(String hex) {
    final h = hex.replaceAll('#', '');
    return Color(int.parse('FF$h', radix: 16));
  }

  String _fmtRango() {
    if (widget.desde == null || widget.hasta == null) return 'Sin período';
    return '${Formato.fechaCorta(widget.desde!)} → ${Formato.fechaCorta(widget.hasta!)}';
  }

  static Color _hexToColor(String hex) =>
      Color(int.parse('FF${hex.replaceAll('#', '')}', radix: 16));

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final diasRestantes = widget.medio.diasParaCierre;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: cs.outline.withOpacity(0.12), width: 1.5),
        boxShadow: [BoxShadow(
            color: cs.shadow.withOpacity(0.04),
            blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Column(
        children: [

          // ── Cabecera ─────────────────────────────────────────
          InkWell(
            onTap: () => setState(() => _expandido = !_expandido),
            borderRadius: BorderRadius.vertical(
              top: const Radius.circular(20),
              bottom: _expandido ? Radius.zero : const Radius.circular(20),
            ),
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    _SeccionTarjetaState._hex(widget.medio.color),
                    _SeccionTarjetaState._hex(widget.medio.color).withOpacity(0.75),
                  ],
                ),
                borderRadius: BorderRadius.vertical(
                  top: const Radius.circular(20),
                  bottom: _expandido ? Radius.zero : const Radius.circular(20),
                ),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      // Ícono TC sobre fondo de color
                      Container(
                        width: 44, height: 44,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(Iconos.get(widget.medio.icono),
                            color: Colors.white, size: 22),
                      ),
                      const SizedBox(width: 12),

                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(widget.medio.nombre,
                                style: const TextStyle(
                                    fontSize: 16, fontWeight: FontWeight.w800)),
                            const SizedBox(height: 3),
                            // Rango editable — toca para cambiar
                            GestureDetector(
                              onTap: widget.onEditarRango,
                              child: Row(
                                children: [
                                  Icon(Icons.date_range_outlined,
                                      size: 12, color: cs.primary),
                                  const SizedBox(width: 4),
                                  Text(_fmtRango(),
                                      style: TextStyle(
                                          fontSize: 11,
                                          color: cs.primary,
                                          fontWeight: FontWeight.w600)),
                                  const SizedBox(width: 4),
                                  Icon(Icons.edit_outlined,
                                      size: 11, color: cs.outline),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),

                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(Formato.moneda(widget.total),
                              style: const TextStyle(
                                  fontSize: 18, fontWeight: FontWeight.w900,
                                  color: Colors.white)),
                          Text('${widget.gastos.length} gastos',
                              style: const TextStyle(
                                  fontSize: 10, color: Colors.white70)),
                        ],
                      ),
                      const SizedBox(width: 6),
                      const Icon(Icons.expand_more, color: Colors.white70),
                    ],
                  ),

                  // Badge alerta cierre
                  if (widget.medio.diaCierre != null && diasRestantes != null) ...[
                    const SizedBox(height: 10),
                    GestureDetector(
                      onTap: widget.onEditarRango,
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 7),
                        decoration: BoxDecoration(
                          color: diasRestantes <= 3
                              ? cs.errorContainer
                              : diasRestantes <= 7
                                  ? const Color(0xFFFFF3E0)
                                  : cs.primaryContainer.withOpacity(0.5),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.access_time,
                              size: 14,
                              color: Colors.white,
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                diasRestantes == 0
                                    ? '¡Cierra hoy! · Toca para ajustar el período'
                                    : diasRestantes == 1
                                        ? '¡Cierra mañana! · Toca para ajustar'
                                        : 'Cierra en $diasRestantes días (día ${widget.medio.diaCierre}) · Toca para ajustar',
                                style: TextStyle(
                                  fontSize: 11, fontWeight: FontWeight.w600,
                                  color: diasRestantes <= 3
                                      ? cs.error
                                      : diasRestantes <= 7
                                          ? const Color(0xFFE65100)
                                          : cs.primary,
                                ),
                              ),
                            ),
                            Icon(Icons.chevron_right, size: 14, color: cs.outline),
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),

          // ── Lista de gastos ───────────────────────────────────
          if (_expandido)
            widget.gastos.isEmpty
                ? Padding(
                    padding: const EdgeInsets.all(20),
                    child: Center(
                      child: Text('Sin gastos en este período',
                          style: TextStyle(color: cs.outline, fontSize: 13)),
                    ),
                  )
                : ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: widget.gastos.length,
                    separatorBuilder: (_, __) => Divider(
                        height: 1, indent: 16, endIndent: 16,
                        color: cs.outline.withOpacity(0.08)),
                    itemBuilder: (ctx, i) {
                      final g = widget.gastos[i];
                      final color = g.categoria != null
                          ? _hexColor(g.categoria!.color)
                          : cs.primary;
                      return Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 10),
                        child: Row(
                          children: [
                            Container(
                              width: 38, height: 38,
                              decoration: BoxDecoration(
                                color: color.withOpacity(0.12),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Center(
                                child: g.categoria != null && Iconos.esEmoji(g.categoria!.icono)
                                    ? Text(g.categoria!.icono,
                                        textAlign: TextAlign.center,
                                        style: const TextStyle(fontSize: 20, height: 1.0))
                                    : Text(
                                        g.categoria?.nombre.isNotEmpty == true
                                            ? g.categoria!.nombre[0].toUpperCase()
                                            : '?',
                                        style: TextStyle(fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                            color: color)),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    g.descripcion ??
                                        g.categoria?.nombre ?? 'Gasto',
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w600, fontSize: 13),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  Row(
                                    children: [
                                      Text(Formato.fechaCorta(g.fecha),
                                          style: TextStyle(
                                              fontSize: 11, color: cs.outline)),
                                      if (g.esCuotado) ...[
                                        const SizedBox(width: 6),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 5, vertical: 1),
                                          decoration: BoxDecoration(
                                            color: cs.primaryContainer,
                                            borderRadius: BorderRadius.circular(5),
                                          ),
                                          child: Text(
                                            'C${g.cuotaNumero}/${g.cuotasTotal}',
                                            style: TextStyle(
                                                fontSize: 9, color: cs.primary,
                                                fontWeight: FontWeight.bold),
                                          ),
                                        ),
                                      ],
                                      if (g.esCompartido && g.grupo != null) ...[
                                        const SizedBox(width: 6),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 5, vertical: 1),
                                          decoration: BoxDecoration(
                                            color: cs.secondaryContainer,
                                            borderRadius: BorderRadius.circular(5),
                                          ),
                                          child: Text(
                                            g.grupo!.nombre,
                                            style: TextStyle(
                                                fontSize: 9, color: cs.secondary,
                                                fontWeight: FontWeight.bold),
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(Formato.moneda(g.valorCuota),
                                    style: const TextStyle(
                                        fontSize: 14, fontWeight: FontWeight.bold)),
                                if (g.esCuotado)
                                  Text('de ${Formato.moneda(g.monto)}',
                                      style: TextStyle(
                                          fontSize: 10, color: cs.outline)),
                              ],
                            ),
                          ],
                        ),
                      );
                    },
                  ),
        ],
      ),
    );
  }
}

class _EstadoVacio extends StatelessWidget {
  static Color _hexToColor(String hex) =>
      Color(int.parse('FF${hex.replaceAll('#', '')}', radix: 16));

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.credit_card_outlined, size: 72, color: cs.outlineVariant),
          const SizedBox(height: 16),
          Text('Sin medios de pago',
              style: Theme.of(context).textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text('Marca tus TC como Tarjeta de credito en Configuracion > Medios de pago',
              textAlign: TextAlign.center,
              style: TextStyle(color: cs.outline, fontSize: 13)),
        ],
      ),
    );
  }
}

// ─── Widget mini resumen ──────────────────────────────────────────────────────

class _MiniResumen extends StatelessWidget {
  final String label;
  final String valor;
  final int n;
  final Color color;
  final bool alignRight;

  const _MiniResumen({
    required this.label,
    required this.valor,
    required this.n,
    required this.color,
    this.alignRight = false,
  });

  static Color _hexToColor(String hex) =>
      Color(int.parse('FF${hex.replaceAll('#', '')}', radix: 16));

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment:
          alignRight ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        Text(label,
            style: TextStyle(
                fontSize: 10,
                color: Theme.of(context).colorScheme.outline)),
        Text(valor,
            style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: color)),
        Text('$n gasto${n != 1 ? 's' : ''}',
            style: TextStyle(
                fontSize: 10,
                color: Theme.of(context).colorScheme.outline)),
      ],
    );
  }
}

// ─── Botón filtro tipo ────────────────────────────────────────────────────────

class _BtnFiltroTipo extends StatelessWidget {
  final String label;
  final IconData? icono;
  final bool activo;
  final VoidCallback onTap;
  final ColorScheme cs;

  const _BtnFiltroTipo({
    required this.label,
    this.icono,
    required this.activo,
    required this.onTap,
    required this.cs,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(vertical: 7),
        decoration: BoxDecoration(
          color: activo ? cs.primary : cs.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (icono != null) ...[
              Icon(icono, size: 13,
                  color: activo ? Colors.white : cs.outline),
              const SizedBox(width: 4),
            ],
            Text(label,
                style: TextStyle(
                  fontSize: 12, fontWeight: FontWeight.w700,
                  color: activo ? Colors.white : cs.outline,
                )),
          ],
        ),
      ),
    );
  }
}
