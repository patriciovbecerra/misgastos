import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:misgastos/models/gasto.dart';
import 'package:misgastos/models/grupo.dart';
import 'package:misgastos/models/participante.dart';
import 'package:misgastos/providers/gastos_provider.dart';
import 'package:misgastos/utils/formato.dart';
import 'package:misgastos/utils/iconos.dart';

class PantallaTodosGastosGrupo extends StatefulWidget {
  final Grupo grupo;
  final List<Gasto> gastosPrecargados;
  final List<Participante> participantes;

  const PantallaTodosGastosGrupo({
    super.key,
    required this.grupo,
    required this.gastosPrecargados,
    required this.participantes,
  });

  @override
  State<PantallaTodosGastosGrupo> createState() =>
      _PantallaTodosGastosGrupoState();
}

class _PantallaTodosGastosGrupoState extends State<PantallaTodosGastosGrupo> {
  late List<Gasto> _gastos;
  late List<Participante> _participantes;
  bool _cargando = false;
  int _pagina = 0;
  static const _porPagina = 10;

  // Filtro de fecha adicional dentro del período
  DateTime? _desde;
  DateTime? _hasta;

  @override
  void initState() {
    super.initState();
    _gastos = List.from(widget.gastosPrecargados);
    _participantes = List.from(widget.participantes);
  }

  void _aplicarFiltro() {
    setState(() {
      _gastos = widget.gastosPrecargados.where((g) {
        if (_desde != null && g.fecha.isBefore(_desde!)) return false;
        if (_hasta != null &&
            g.fecha.isAfter(DateTime(
                _hasta!.year, _hasta!.month, _hasta!.day, 23, 59, 59)))
          return false;
        return true;
      }).toList()
        ..sort((a, b) => b.fecha.compareTo(a.fecha));
      _pagina = 0;
    });
  }

  List<Gasto> get _gastosPagina {
    final inicio = _pagina * _porPagina;
    final fin = (inicio + _porPagina).clamp(0, _gastos.length);
    return _gastos.sublist(inicio, fin);
  }

  int get _totalPaginas => (_gastos.length / _porPagina).ceil();

  double get _totalFiltrado =>
      _gastos.fold(0.0, (s, g) => s + g.valorCuota);

  double get _porPersona => _participantes.isEmpty
      ? 0
      : _totalFiltrado / (_participantes.isEmpty ? 1 : _participantes.length);

  static Color _hex(String hex) =>
      Color(int.parse('FF${hex.replaceAll('#', '')}', radix: 16));

  Future<void> _filtrarFechas() async {
    DateTime? desde = _desde;
    DateTime? hasta = _hasta;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => Padding(
          padding: EdgeInsets.only(
              left: 20, right: 20, top: 16,
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(child: Container(
                  width: 40, height: 4,
                  decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(2)))),
              const SizedBox(height: 16),
              const Text('Filtrar por fecha',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
              const SizedBox(height: 16),
              _FilaFechaFiltro(
                label: 'Desde',
                fecha: desde,
                onTap: () async {
                  final p = await showDatePicker(
                      context: ctx,
                      initialDate: desde ?? DateTime.now(),
                      firstDate: DateTime(2020),
                      lastDate: DateTime(2030));
                  if (p != null) setS(() => desde = p);
                },
              ),
              const SizedBox(height: 10),
              _FilaFechaFiltro(
                label: 'Hasta',
                fecha: hasta,
                onTap: () async {
                  final p = await showDatePicker(
                      context: ctx,
                      initialDate: hasta ?? DateTime.now(),
                      firstDate: DateTime(2020),
                      lastDate: DateTime(2030));
                  if (p != null) setS(() => hasta = p);
                },
              ),
              const SizedBox(height: 16),
              Row(children: [
                Expanded(child: OutlinedButton(
                  onPressed: () {
                    setS(() { desde = null; hasta = null; });
                  },
                  style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12))),
                  child: const Text('Limpiar'),
                )),
                const SizedBox(width: 10),
                Expanded(flex: 2, child: FilledButton(
                  onPressed: () {
                    setState(() { _desde = desde; _hasta = hasta; });
                    _aplicarFiltro();
                    Navigator.pop(ctx);
                  },
                  style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12))),
                  child: const Text('Aplicar'),
                )),
              ]),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final hayFiltro = _desde != null || _hasta != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.grupo.nombre),
        actions: [
          IconButton(
            icon: Badge(
              isLabelVisible: hayFiltro,
              child: const Icon(Icons.tune),
            ),
            onPressed: _filtrarFechas,
            tooltip: 'Filtrar por fecha',
          ),
        ],
      ),
      body: _cargando
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [

                // ── Banner resumen ────────────────────────────
                Container(
                  margin: const EdgeInsets.all(16),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [cs.primary, cs.primary.withOpacity(0.7)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(18),
                    boxShadow: [BoxShadow(
                        color: cs.primary.withOpacity(0.3),
                        blurRadius: 12, offset: const Offset(0, 4))],
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Total gastado',
                                    style: TextStyle(
                                        color: Colors.white70, fontSize: 12)),
                                Text(Formato.moneda(_totalFiltrado),
                                    style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 26,
                                        fontWeight: FontWeight.w900)),
                              ],
                            ),
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              const Text('Por persona',
                                  style: TextStyle(
                                      color: Colors.white70, fontSize: 12)),
                              Text(Formato.moneda(_porPersona),
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 18,
                                      fontWeight: FontWeight.w800)),
                              Text(
                                  '${_participantes.length} participantes',
                                  style: const TextStyle(
                                      color: Colors.white60, fontSize: 11)),
                            ],
                          ),
                        ],
                      ),
                      if (_participantes.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        Container(height: 1, color: Colors.white24),
                        const SizedBox(height: 10),
                        Row(
                          children: _participantes.map((p) => Expanded(
                            child: Column(
                              children: [
                                Text(p.nombre.split(' ').first,
                                    style: const TextStyle(
                                        color: Colors.white70, fontSize: 11)),
                                Text(Formato.moneda(_porPersona),
                                    style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700)),
                              ],
                            ),
                          )).toList(),
                        ),
                      ],
                    ],
                  ),
                ),

                // ── Filtro activo ────────────────────────────
                if (hayFiltro)
                  Container(
                    margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: cs.primaryContainer.withOpacity(0.5),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.filter_list, size: 14, color: cs.primary),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            '${_desde != null ? Formato.fechaCorta(_desde!) : '...'}'
                            ' → '
                            '${_hasta != null ? Formato.fechaCorta(_hasta!) : '...'}',
                            style: TextStyle(
                                fontSize: 12,
                                color: cs.primary,
                                fontWeight: FontWeight.w600),
                          ),
                        ),
                        GestureDetector(
                          onTap: () {
                            setState(() { _desde = null; _hasta = null; });
                            _aplicarFiltro();
                          },
                          child: Icon(Icons.close, size: 16, color: cs.primary),
                        ),
                      ],
                    ),
                  ),

                // ── Lista de gastos (paginada de 10) ─────────
                Expanded(
                  child: _gastos.isEmpty
                      ? Center(
                          child: Text(
                            hayFiltro
                                ? 'Sin gastos en ese período'
                                : 'Sin gastos en este grupo',
                            style: TextStyle(color: cs.outline),
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                          itemCount: _gastosPagina.length + 1,
                          itemBuilder: (ctx, i) {
                            if (i == _gastosPagina.length) {
                              return _Paginador(
                                pagina: _pagina,
                                total: _totalPaginas,
                                onAnterior: _pagina > 0
                                    ? () => setState(() => _pagina--)
                                    : null,
                                onSiguiente: _pagina < _totalPaginas - 1
                                    ? () => setState(() => _pagina++)
                                    : null,
                              );
                            }
                            final g = _gastosPagina[i];
                            final color = g.categoria != null
                                ? _hex(g.categoria!.color)
                                : cs.primary;
                            return Container(
                              margin: const EdgeInsets.only(bottom: 8),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: cs.surface,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                    color: cs.outline.withOpacity(0.1)),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 40, height: 40,
                                    decoration: BoxDecoration(
                                      color: color.withOpacity(0.12),
                                      borderRadius: BorderRadius.circular(11),
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
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          g.descripcion ??
                                              g.categoria?.nombre ?? 'Gasto',
                                          style: const TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w600),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        Row(children: [
                                          Text(Formato.fechaCorta(g.fecha),
                                              style: TextStyle(
                                                  fontSize: 11,
                                                  color: cs.outline)),
                                          if (g.medioPago != null) ...[
                                            Text(' · ',
                                                style: TextStyle(
                                                    color: cs.outline)),
                                            Text(g.medioPago!.nombre,
                                                style: TextStyle(
                                                    fontSize: 11,
                                                    color: cs.outline)),
                                          ],
                                        ]),
                                      ],
                                    ),
                                  ),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text(Formato.moneda(g.monto),
                                          style: const TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.bold)),
                                      Text(
                                        'c/u ${Formato.moneda(g.valorCuota / (_participantes.isEmpty ? 1 : _participantes.length))}',
                                        style: TextStyle(
                                            fontSize: 10, color: cs.outline),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
    );
  }
}

// ─── Paginador ────────────────────────────────────────────────────────────────

class _Paginador extends StatelessWidget {
  final int pagina;
  final int total;
  final VoidCallback? onAnterior;
  final VoidCallback? onSiguiente;

  const _Paginador({
    required this.pagina,
    required this.total,
    this.onAnterior,
    this.onSiguiente,
  });

  @override
  Widget build(BuildContext context) {
    if (total <= 1) return const SizedBox();
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton(
            onPressed: onAnterior,
            icon: const Icon(Icons.chevron_left),
            color: onAnterior != null ? cs.primary : cs.outline,
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            decoration: BoxDecoration(
              color: cs.primaryContainer,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text('${pagina + 1} / $total',
                style: TextStyle(
                    fontWeight: FontWeight.w700, color: cs.primary)),
          ),
          IconButton(
            onPressed: onSiguiente,
            icon: const Icon(Icons.chevron_right),
            color: onSiguiente != null ? cs.primary : cs.outline,
          ),
        ],
      ),
    );
  }
}

// ─── Fila de fecha para filtro ────────────────────────────────────────────────

class _FilaFechaFiltro extends StatelessWidget {
  final String label;
  final DateTime? fecha;
  final VoidCallback onTap;

  const _FilaFechaFiltro({
      required this.label, required this.fecha, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          border: Border.all(
              color: fecha != null
                  ? cs.primary.withOpacity(0.4)
                  : cs.outline.withOpacity(0.3)),
          borderRadius: BorderRadius.circular(12),
          color: fecha != null ? cs.primary.withOpacity(0.05) : null,
        ),
        child: Row(
          children: [
            Icon(Icons.calendar_today, size: 18,
                color: fecha != null ? cs.primary : cs.outline),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: TextStyle(fontSize: 10, color: cs.outline)),
                Text(
                  fecha != null
                      ? Formato.fechaLarga(fecha!)
                      : 'Seleccionar...',
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: fecha != null ? cs.primary : cs.outline),
                ),
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
