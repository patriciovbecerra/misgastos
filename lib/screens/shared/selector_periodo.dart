import 'package:flutter/material.dart';
import 'package:misgastos/models/periodo.dart';
import 'package:misgastos/utils/formato.dart';

/// Widget que muestra el periodo activo y al tocarlo abre el selector
class SelectorPeriodo extends StatelessWidget {
  final Periodo periodo;
  final void Function(Periodo) onCambiar;
  final Color? color;

  const SelectorPeriodo({
    super.key,
    required this.periodo,
    required this.onCambiar,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final c = color ?? cs.onSurface;

    return GestureDetector(
      onTap: () => _mostrarSelector(context),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.date_range_outlined, size: 16, color: c.withOpacity(0.8)),
          const SizedBox(width: 4),
          Text(
            periodo.etiqueta,
            style: TextStyle(
              fontSize: 13,
              color: c.withOpacity(0.9),
              fontWeight: FontWeight.w500,
            ),
          ),
          Icon(Icons.expand_more, size: 16, color: c.withOpacity(0.7)),
        ],
      ),
    );
  }

  void _mostrarSelector(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _BottomSheetPeriodo(
        periodoActual: periodo,
        onSeleccionar: (p) {
          Navigator.pop(context);
          onCambiar(p);
        },
      ),
    );
  }
}

class _BottomSheetPeriodo extends StatefulWidget {
  final Periodo periodoActual;
  final void Function(Periodo) onSeleccionar;

  const _BottomSheetPeriodo({
    required this.periodoActual,
    required this.onSeleccionar,
  });

  @override
  State<_BottomSheetPeriodo> createState() => _BottomSheetPeriodoState();
}

class _BottomSheetPeriodoState extends State<_BottomSheetPeriodo>
    with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;
  // Para tab "Mes"
  late int _mes;
  late int _anio;
  // Para tab "Rango"
  DateTime? _desde;
  DateTime? _hasta;

  final hoy = DateTime.now();

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 3, vsync: this);
    _mes = hoy.month;
    _anio = hoy.year;
    _desde = widget.periodoActual.desde;
    _hasta = widget.periodoActual.hasta;
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  static String _fmtFecha(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40, height: 4,
            decoration: BoxDecoration(
              color: cs.outlineVariant,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),
          Text('Seleccionar período',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),

          // Tabs
          TabBar(
            controller: _tabCtrl,
            tabs: const [
              Tab(text: 'Rápido'),
              Tab(text: 'Por mes'),
              Tab(text: 'Rango libre'),
            ],
          ),

          SizedBox(
            height: 340,
            child: TabBarView(
              controller: _tabCtrl,
              children: [
                _TabRapido(onSeleccionar: widget.onSeleccionar),
                _TabMes(
                  mes: _mes,
                  anio: _anio,
                  onMesCambio: (m) => setState(() => _mes = m),
                  anioCambio: (a) => setState(() => _anio = a),
                  onAplicar: () => widget.onSeleccionar(Periodo.mes(_mes, _anio)),
                ),
                _TabRango(
                  desde: _desde,
                  hasta: _hasta,
                  onDesdeCambio: (d) => setState(() => _desde = d),
                  onHastaCambio: (h) => setState(() => _hasta = h),
                  onAplicar: () {
                    if (_desde != null && _hasta != null) {
                      final d = _desde!.isBefore(_hasta!) ? _desde! : _hasta!;
                      final h = _desde!.isBefore(_hasta!) ? _hasta! : _desde!;
                      widget.onSeleccionar(Periodo.personalizado(d, h));
                    }
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Tab Rápido ────────────────────────────────────────────────────────────────

class _TabRapido extends StatelessWidget {
  final void Function(Periodo) onSeleccionar;
  const _TabRapido({required this.onSeleccionar});

  @override
  Widget build(BuildContext context) {
    final hoy = DateTime.now();
    final opciones = [
      ('Hoy', Periodo.ultimosDias(1)),
      ('Últimos 7 días', Periodo.ultimosDias(7)),
      ('Últimos 15 días', Periodo.ultimosDias(15)),
      ('Últimos 30 días', Periodo.ultimosDias(30)),
      ('Este mes', Periodo.mes(hoy.month, hoy.year)),
      ('Este mes + siguiente', Periodo.personalizado(
          DateTime(hoy.year, hoy.month, 1),
          DateTime(hoy.year, hoy.month + 2, 0))),
      ('Mes siguiente', Periodo.mes(hoy.month + 1, hoy.year)),
      ('Mes anterior', Periodo.mes(
          hoy.month == 1 ? 12 : hoy.month - 1,
          hoy.month == 1 ? hoy.year - 1 : hoy.year)),
      ('Este año', Periodo.anio(hoy.year)),
      ('Año anterior', Periodo.anio(hoy.year - 1)),
    ];

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: opciones.length,
      itemBuilder: (ctx, i) {
        final (label, periodo) = opciones[i];
        return ListTile(
          dense: true,
          leading: const Icon(Icons.bolt, size: 18),
          title: Text(label),
          subtitle: Text(periodo.etiqueta,
              style: TextStyle(
                  fontSize: 11,
                  color: Theme.of(ctx).colorScheme.outline)),
          trailing: const Icon(Icons.chevron_right, size: 18),
          onTap: () => onSeleccionar(periodo),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        );
      },
    );
  }
}

// ── Tab Por Mes ───────────────────────────────────────────────────────────────

class _TabMes extends StatelessWidget {
  final int mes;
  final int anio;
  final void Function(int) onMesCambio;
  final void Function(int) anioCambio;
  final VoidCallback onAplicar;

  const _TabMes({
    required this.mes,
    required this.anio,
    required this.onMesCambio,
    required this.anioCambio,
    required this.onAplicar,
  });

  static const _meses = [
    'Enero', 'Febrero', 'Marzo', 'Abril', 'Mayo', 'Junio',
    'Julio', 'Agosto', 'Septiembre', 'Octubre', 'Noviembre', 'Diciembre',
  ];

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final hoy = DateTime.now();

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Selector de año
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left),
                onPressed: anio > 2020 ? () => anioCambio(anio - 1) : null,
              ),
              Text('$anio',
                  style: const TextStyle(
                      fontSize: 20, fontWeight: FontWeight.bold)),
              IconButton(
                icon: const Icon(Icons.chevron_right),
                onPressed: anio < hoy.year ? () => anioCambio(anio + 1) : null,
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Grid de meses
          Expanded(
            child: GridView.builder(
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                childAspectRatio: 2.2,
                mainAxisSpacing: 6,
                crossAxisSpacing: 6,
              ),
              itemCount: 12,
              itemBuilder: (ctx, i) {
                final sel = i + 1 == mes;
                final esFuturo = DateTime(anio, i + 1).isAfter(hoy);
                return GestureDetector(
                  onTap: esFuturo ? null : () => onMesCambio(i + 1),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 120),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: sel
                          ? cs.primaryContainer
                          : esFuturo
                              ? cs.surfaceContainerHighest.withOpacity(0.3)
                              : cs.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: sel ? cs.primary : Colors.transparent,
                        width: 1.5,
                      ),
                    ),
                    child: Text(
                      _meses[i].substring(0, 3),
                      style: TextStyle(
                        fontWeight:
                            sel ? FontWeight.bold : FontWeight.normal,
                        color: sel
                            ? cs.primary
                            : esFuturo
                                ? cs.outlineVariant
                                : cs.onSurface,
                        fontSize: 13,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 8),
          FilledButton(
            onPressed: onAplicar,
            style: FilledButton.styleFrom(
              minimumSize: const Size(double.infinity, 44),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            child: Text('Ver ${_meses[mes - 1]} $anio'),
          ),
        ],
      ),
    );
  }
}

// ── Tab Rango Libre ───────────────────────────────────────────────────────────

class _TabRango extends StatelessWidget {
  final DateTime? desde;
  final DateTime? hasta;
  final void Function(DateTime) onDesdeCambio;
  final void Function(DateTime) onHastaCambio;
  final VoidCallback onAplicar;

  const _TabRango({
    required this.desde,
    required this.hasta,
    required this.onDesdeCambio,
    required this.onHastaCambio,
    required this.onAplicar,
  });

  static String _fmt(DateTime? d) {
    if (d == null) return 'Seleccionar';
    return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
  }

  Future<void> _pick(BuildContext context, bool esDesde) async {
    final hoy = DateTime.now();
    final inicial = esDesde ? (desde ?? hoy) : (hasta ?? hoy);
    final picked = await showDatePicker(
      context: context,
      initialDate: inicial,
      firstDate: DateTime(2020),
      lastDate: hoy,

      helpText: esDesde ? 'Fecha desde' : 'Fecha hasta',
    );
    if (picked != null) {
      esDesde ? onDesdeCambio(picked) : onHastaCambio(picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final listo = desde != null && hasta != null;
    final ordenOk = listo && !desde!.isAfter(hasta!);

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 8),

          // Desde
          Text('Desde',
              style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: cs.onSurface.withOpacity(0.7))),
          const SizedBox(height: 6),
          _BotonFecha(
            label: _fmt(desde),
            icono: Icons.calendar_today,
            onTap: () => _pick(context, true),
          ),
          const SizedBox(height: 16),

          // Hasta
          Text('Hasta',
              style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: cs.onSurface.withOpacity(0.7))),
          const SizedBox(height: 6),
          _BotonFecha(
            label: _fmt(hasta),
            icono: Icons.calendar_today,
            onTap: () => _pick(context, false),
          ),

          if (listo && !ordenOk)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                'La fecha de inicio debe ser anterior a la fecha de fin',
                style: TextStyle(color: cs.error, fontSize: 12),
              ),
            ),

          const Spacer(),

          // Resumen del rango
          if (listo && ordenOk)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: cs.primaryContainer.withOpacity(0.5),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, size: 16, color: cs.primary),
                  const SizedBox(width: 8),
                  Text(
                    '${hasta!.difference(desde!).inDays + 1} días seleccionados',
                    style: TextStyle(color: cs.primary, fontSize: 13),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 12),

          FilledButton(
            onPressed: (listo && ordenOk) ? onAplicar : null,
            style: FilledButton.styleFrom(
              minimumSize: const Size(double.infinity, 44),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Aplicar rango'),
          ),
        ],
      ),
    );
  }
}

class _BotonFecha extends StatelessWidget {
  final String label;
  final IconData icono;
  final VoidCallback onTap;

  const _BotonFecha({
    required this.label,
    required this.icono,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          border: Border.all(color: cs.outline.withOpacity(0.4)),
          borderRadius: BorderRadius.circular(12),
          color: cs.surfaceContainerHighest.withOpacity(0.5),
        ),
        child: Row(
          children: [
            Icon(icono, size: 18, color: cs.primary),
            const SizedBox(width: 10),
            Text(label,
                style: TextStyle(
                    fontSize: 15,
                    color: label == 'Seleccionar'
                        ? cs.outline
                        : cs.onSurface)),
            const Spacer(),
            Icon(Icons.edit_calendar_outlined, size: 16, color: cs.outline),
          ],
        ),
      ),
    );
  }
}
