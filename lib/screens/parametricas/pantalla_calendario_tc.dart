import 'package:flutter/material.dart';
import 'package:misgastos/models/medio_pago.dart';
import 'package:misgastos/providers/gastos_provider.dart';
import 'package:misgastos/utils/formato.dart';
import 'package:provider/provider.dart';

class PantallaCalendarioTC extends StatefulWidget {
  final MedioPago medio;
  const PantallaCalendarioTC({super.key, required this.medio});

  @override
  State<PantallaCalendarioTC> createState() => _PantallaCalendarioTCState();
}

class _PantallaCalendarioTCState extends State<PantallaCalendarioTC> {
  List<Map<String, dynamic>> _periodos = [];
  bool _cargando = true;

  static const _meses = [
    '', 'Enero', 'Febrero', 'Marzo', 'Abril', 'Mayo', 'Junio',
    'Julio', 'Agosto', 'Septiembre', 'Octubre', 'Noviembre', 'Diciembre',
  ];

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    setState(() => _cargando = true);
    final provider = context.read<GastosProvider>();
    final data = await provider.db.getCalendarioTC(widget.medio.id!);
    if (mounted) setState(() { _periodos = data; _cargando = false; });
  }

  Future<void> _editarPeriodo(Map<String, dynamic> periodo) async {
    DateTime? desdeSel = DateTime.parse(periodo['desde'] as String);
    DateTime? hastaSel = DateTime.parse(periodo['hasta'] as String);
    final mes = periodo['mes'] as int;
    final anio = periodo['anio'] as int;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => Padding(
          padding: EdgeInsets.only(
            left: 20, right: 20, top: 16,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(child: Container(width: 40, height: 4,
                  decoration: BoxDecoration(color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(2)))),
              const SizedBox(height: 16),
              Text('Editar — ${_meses[mes]} $anio',
                  style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
              const SizedBox(height: 16),
              _FilaFecha(label: 'Desde', fecha: desdeSel,
                onTap: () async {
                  final p = await showDatePicker(
                    context: ctx,
                    initialDate: desdeSel ?? DateTime.now(),
                    firstDate: DateTime(2020), lastDate: DateTime(2030));
                  if (p != null) setS(() => desdeSel = p);
                }),
              const SizedBox(height: 10),
              _FilaFecha(label: 'Hasta', fecha: hastaSel,
                onTap: () async {
                  final p = await showDatePicker(
                    context: ctx,
                    initialDate: hastaSel ?? DateTime.now(),
                    firstDate: DateTime(2020), lastDate: DateTime(2030));
                  if (p != null) setS(() => hastaSel = p);
                }),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: desdeSel != null && hastaSel != null
                      ? () async {
                          final provider = context.read<GastosProvider>();
                          await provider.db.guardarPeriodoCalendario(
                            idMedioPago: widget.medio.id!,
                            anio: anio, mes: mes,
                            desde: desdeSel!, hasta: hastaSel!,
                          );
                          if (ctx.mounted) Navigator.pop(ctx);
                          _cargar();
                        }
                      : null,
                  style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12))),
                  child: const Text('Guardar cambios'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _agregarPeriodo() async {
    final hoy = DateTime.now();
    int anioSel = hoy.year;
    int mesSel = hoy.month;
    DateTime? desdeSel;
    DateTime? hastaSel;

    // Pre-calcular desde el día de cierre si existe
    if (widget.medio.diaCierre != null) {
      final cierre = widget.medio.diaCierre!;
      desdeSel = DateTime(hoy.year, hoy.month - 1, cierre + 1);
      hastaSel = DateTime(hoy.year, hoy.month, cierre);
    }

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => Padding(
          padding: EdgeInsets.only(
            left: 20, right: 20, top: 16,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(child: Container(width: 40, height: 4,
                  decoration: BoxDecoration(color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(2)))),
              const SizedBox(height: 16),
              Text('Nuevo período de facturación',
                  style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
              const SizedBox(height: 16),

              // Selector mes/año
              Row(children: [
                Expanded(
                  child: DropdownButtonFormField<int>(
                    value: mesSel,
                    decoration: const InputDecoration(labelText: 'Mes'),
                    items: List.generate(12, (i) => i + 1)
                        .where((m) => !_periodos.any((p) =>
                            p['mes'] as int == m &&
                            p['anio'] as int == anioSel))
                        .map((m) => DropdownMenuItem(
                            value: m, child: Text(_meses[m])))
                        .toList(),
                    onChanged: (v) {
                      setS(() { mesSel = v!; });
                      // Recalcular fechas si hay día de cierre
                      if (widget.medio.diaCierre != null) {
                        final c = widget.medio.diaCierre!;
                        setS(() {
                          desdeSel = DateTime(anioSel, v! - 1, c + 1);
                          hastaSel = DateTime(anioSel, v, c);
                        });
                      }
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButtonFormField<int>(
                    value: anioSel,
                    decoration: const InputDecoration(labelText: 'Año'),
                    items: [2023, 2024, 2025, 2026, 2027].map((a) =>
                        DropdownMenuItem(value: a, child: Text('$a'))).toList(),
                    onChanged: (v) => setS(() => anioSel = v!),
                  ),
                ),
              ]),
              const SizedBox(height: 14),

              // Desde
              _FilaFecha(
                label: 'Desde',
                fecha: desdeSel,
                onTap: () async {
                  final p = await showDatePicker(
                    context: ctx,
                    initialDate: desdeSel ?? DateTime.now(),
                    firstDate: DateTime(2020),
                    lastDate: DateTime(2030),
                  );
                  if (p != null) setS(() => desdeSel = p);
                },
              ),
              const SizedBox(height: 10),

              // Hasta
              _FilaFecha(
                label: 'Hasta',
                fecha: hastaSel,
                onTap: () async {
                  final p = await showDatePicker(
                    context: ctx,
                    initialDate: hastaSel ?? DateTime.now(),
                    firstDate: DateTime(2020),
                    lastDate: DateTime(2030),
                  );
                  if (p != null) setS(() => hastaSel = p);
                },
              ),
              const SizedBox(height: 16),

              Row(children: [
                Expanded(child: OutlinedButton(
                  onPressed: () => Navigator.pop(ctx),
                  style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12))),
                  child: const Text('Cancelar'),
                )),
                const SizedBox(width: 10),
                Expanded(flex: 2, child: FilledButton(
                  onPressed: desdeSel != null && hastaSel != null
                      ? () async {
                          final provider = context.read<GastosProvider>();
                          await provider.db.guardarPeriodoCalendario(
                            idMedioPago: widget.medio.id!,
                            anio: anioSel,
                            mes: mesSel,
                            desde: desdeSel!,
                            hasta: hastaSel!,
                          );
                          if (ctx.mounted) Navigator.pop(ctx);
                          _cargar();
                        }
                      : null,
                  style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12))),
                  child: const Text('Guardar período'),
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

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Calendario de facturación'),
            Text(widget.medio.nombre,
                style: TextStyle(fontSize: 12, color: cs.outline)),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _agregarPeriodo,
        icon: const Icon(Icons.add),
        label: const Text('Agregar período'),
      ),

      body: _cargando
          ? const Center(child: CircularProgressIndicator())
          : _periodos.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.calendar_month_outlined,
                          size: 64, color: cs.outlineVariant),
                      const SizedBox(height: 16),
                      Text('Sin períodos registrados',
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      Text(
                        'Agrega los períodos de facturación\nde ${widget.medio.nombre}',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: cs.outline),
                      ),
                      const SizedBox(height: 24),
                      FilledButton.icon(
                        onPressed: _agregarPeriodo,
                        icon: const Icon(Icons.add),
                        label: const Text('Agregar período'),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                  itemCount: _periodos.length,
                  itemBuilder: (ctx, i) {
                    final p = _periodos[i];
                    final mes = p['mes'] as int;
                    final anio = p['anio'] as int;
                    final desde = DateTime.parse(p['desde'] as String);
                    final hasta = DateTime.parse(p['hasta'] as String);
                    final hoy = DateTime.now();
                    final esActual = anio == hoy.year && mes == hoy.month;

                    return Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: esActual
                            ? cs.primaryContainer.withOpacity(0.4)
                            : cs.surface,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: esActual
                              ? cs.primary.withOpacity(0.4)
                              : cs.outline.withOpacity(0.12),
                          width: esActual ? 2 : 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 48, height: 48,
                            decoration: BoxDecoration(
                              color: esActual
                                  ? cs.primaryContainer
                                  : cs.surfaceContainerHighest,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text('$mes',
                                    style: TextStyle(
                                        fontSize: 18, fontWeight: FontWeight.w900,
                                        color: esActual ? cs.primary : cs.onSurface)),
                                Text('$anio',
                                    style: TextStyle(
                                        fontSize: 9, color: cs.outline)),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(children: [
                                  Text(_meses[mes],
                                      style: const TextStyle(
                                          fontSize: 15, fontWeight: FontWeight.w700)),
                                  if (esActual) ...[
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 7, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: cs.primary,
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: const Text('ACTUAL',
                                          style: TextStyle(fontSize: 9,
                                              color: Colors.white,
                                              fontWeight: FontWeight.w800)),
                                    ),
                                  ],
                                ]),
                                Text(
                                  '${Formato.fechaCorta(desde)} → ${Formato.fechaCorta(hasta)}',
                                  style: TextStyle(
                                      fontSize: 13, color: cs.outline),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: Icon(Icons.edit_outlined,
                                color: cs.primary, size: 20),
                            onPressed: () => _editarPeriodo(p),
                          ),
                          IconButton(
                            icon: Icon(Icons.delete_outline,
                                color: cs.error, size: 20),
                            onPressed: () async {
                              final ok = await showDialog<bool>(
                                context: context,
                                builder: (ctx) => AlertDialog(
                                  title: const Text('¿Eliminar período?'),
                                  content: Text(
                                      'Se eliminará el período de ${_meses[mes]} $anio'),
                                  actions: [
                                    TextButton(
                                        onPressed: () => Navigator.pop(ctx, false),
                                        child: const Text('Cancelar')),
                                    FilledButton(
                                      style: FilledButton.styleFrom(
                                          backgroundColor: cs.error),
                                      onPressed: () => Navigator.pop(ctx, true),
                                      child: const Text('Eliminar'),
                                    ),
                                  ],
                                ),
                              );
                              if (ok == true) {
                                await context.read<GastosProvider>().db
                                    .eliminarPeriodoCalendario(p['id'] as int);
                                _cargar();
                              }
                            },
                          ),
                        ],
                      ),
                    );
                  },
                ),
    );
  }
}

class _FilaFecha extends StatelessWidget {
  final String label;
  final DateTime? fecha;
  final VoidCallback onTap;

  const _FilaFecha({required this.label, required this.fecha, required this.onTap});

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
                Text(label, style: TextStyle(fontSize: 10, color: cs.outline)),
                Text(
                  fecha != null ? Formato.fechaLarga(fecha!) : 'Seleccionar...',
                  style: TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w600,
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
