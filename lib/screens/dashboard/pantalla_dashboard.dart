import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:misgastos/providers/gastos_provider.dart';
import 'package:misgastos/utils/formato.dart';
import 'package:misgastos/utils/iconos.dart';
import 'package:misgastos/models/periodo.dart';
import 'package:misgastos/screens/shared/selector_periodo.dart';

class PantallaDashboard extends StatefulWidget {
  const PantallaDashboard({super.key});

  @override
  State<PantallaDashboard> createState() => _PantallaDashboardState();
}

class _PantallaDashboardState extends State<PantallaDashboard> {
  List<Map<String, dynamic>> _porCategoria = [];
  List<Map<String, dynamic>> _porMedioPago = [];
  List<Map<String, dynamic>> _resumenAnual = [];
  Map<String, double> _indVsComp = {'individual': 0, 'compartido': 0};
  Map<String, dynamic> _mesActual = {};
  Map<String, dynamic> _mesAnterior = {};
  bool _cargando = true;
  int? _sectorTocado;

  @override
  void initState() {
    super.initState();
    _cargarDatos();
  }

  Future<void> _cargarDatos() async {
    setState(() => _cargando = true);
    final provider = context.read<GastosProvider>();
    final hoy = DateTime.now();
    final results = await Future.wait([
      provider.getAnalisisCategoria(),
      provider.getAnalisisMedioPago(),
      provider.getResumenAnual(),
      provider.getAnalisisIndividualVsCompartido(),
      provider.db.getComparacionMensual(hoy.year, hoy.month),
      provider.db.getComparacionMensual(
          hoy.month == 1 ? hoy.year - 1 : hoy.year,
          hoy.month == 1 ? 12 : hoy.month - 1),
    ]);
    if (mounted) {
      setState(() {
        _porCategoria = results[0] as List<Map<String, dynamic>>;
        _porMedioPago = results[1] as List<Map<String, dynamic>>;
        _resumenAnual = results[2] as List<Map<String, dynamic>>;
        _indVsComp = results[3] as Map<String, double>;
        _mesActual = results[4] as Map<String, dynamic>;
        _mesAnterior = results[5] as Map<String, dynamic>;
        _cargando = false;
      });
    }
  }

  static Color _hexColor(String hex) {
    final h = hex.replaceAll('#', '');
    return Color(int.parse('FF$h', radix: 16));
  }

  static const _coloresFijos = [
    Color(0xFF6C63FF), Color(0xFF45B7D1), Color(0xFF96CEB4),
    Color(0xFFFF6B6B), Color(0xFFF0A500), Color(0xFFDDA0DD),
    Color(0xFF4ECDC4), Color(0xFFFF85A1),
  ];

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<GastosProvider>();
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Dashboard'),
            SelectorPeriodo(
              periodo: provider.periodo,
              onCambiar: (p) async {
                await context.read<GastosProvider>().cargarGastosPeriodo(p);
                _cargarDatos();
              },
              color: cs.onSurface.withOpacity(0.7),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Actualizar',
            onPressed: _cargarDatos,
          ),
        ],
      ),
      body: _cargando
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _cargarDatos,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [

                  // ── 1. Tarjetas resumen ──
                  _buildResumenCards(provider, cs),
                  const SizedBox(height: 20),

                  // ── 2. Torta por categoría ──
                  if (_porCategoria.isNotEmpty) ...[
                    _SeccionTitulo('Gastos por categoría'),
                    const SizedBox(height: 12),
                    _buildTortaCategorias(cs),
                    const SizedBox(height: 20),
                  ],

                  // ── 3. Barras por medio de pago ──
                  if (_porMedioPago.isNotEmpty) ...[
                    _SeccionTitulo('Por medio de pago'),
                    const SizedBox(height: 12),
                    _buildBarrasMedioPago(cs),
                    const SizedBox(height: 20),
                  ],

                  // ── 4. Individual vs Compartido ──
                  _SeccionTitulo('Individual vs Compartido'),
                  const SizedBox(height: 12),
                  _buildIndVsComp(cs),
                  const SizedBox(height: 20),

                  // ── 5. Histórico anual ──
                  if (_resumenAnual.isNotEmpty) ...[
                    _SeccionTitulo('Histórico ' + provider.periodo.desde.year.toString()),
                    const SizedBox(height: 12),
                    _buildHistoricoAnual(cs, provider),
                    const SizedBox(height: 20),
                  ],

                  // ── 6. Comparación mes actual vs anterior ──
                  _SeccionTitulo('Este mes vs mes anterior'),
                  const SizedBox(height: 12),
                  _buildComparacionMensual(cs),
                  const SizedBox(height: 20),

                  // ── 7. Top 10 categorías ──
                  if (_porCategoria.isNotEmpty) ...[
                    _SeccionTitulo('Top categorías del mes'),
                    const SizedBox(height: 12),
                    _buildTopCategorias(cs),
                  ],

                  const SizedBox(height: 32),
                ],
              ),
            ),
    );
  }

  // ── Tarjetas resumen ─────────────────────────────────────────────

  Widget _buildResumenCards(GastosProvider provider, ColorScheme cs) {
    final totalMes = provider.totalMes;
    final cantGastos = provider.gastos.length;
    final promedio = cantGastos > 0 ? totalMes / cantGastos : 0.0;
    final compartido = _indVsComp['compartido'] ?? 0;

    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 1.6,
      children: [
        _TarjetaKPI(
          titulo: 'Total mes',
          valor: Formato.moneda(totalMes),
          icono: Icons.account_balance_wallet,
          color: cs.primary,
          bg: cs.primaryContainer,
        ),
        _TarjetaKPI(
          titulo: 'N° gastos',
          valor: '$cantGastos',
          icono: Icons.receipt_long,
          color: cs.secondary,
          bg: cs.secondaryContainer,
        ),
        _TarjetaKPI(
          titulo: 'Promedio',
          valor: Formato.moneda(promedio),
          icono: Icons.show_chart,
          color: const Color(0xFF45B7D1),
          bg: const Color(0xFF45B7D1).withOpacity(0.15),
        ),
        _TarjetaKPI(
          titulo: 'Compartido',
          valor: Formato.moneda(compartido),
          icono: Icons.group,
          color: const Color(0xFF96CEB4),
          bg: const Color(0xFF96CEB4).withOpacity(0.2),
        ),
      ],
    );
  }

  // ── Torta de categorías ──────────────────────────────────────────

  Widget _buildTortaCategorias(ColorScheme cs) {
    final total = _porCategoria.fold<double>(
        0, (s, e) => s + (e['total'] as num).toDouble());

    final sections = _porCategoria.asMap().entries.map((entry) {
      final i = entry.key;
      final e = entry.value;
      final valor = (e['total'] as num).toDouble();
      final color = e['color'] != null
          ? _hexColor(e['color'] as String)
          : _coloresFijos[i % _coloresFijos.length];
      final pct = total > 0 ? (valor / total * 100) : 0.0;
      final tocado = _sectorTocado == i;

      return PieChartSectionData(
        value: valor,
        color: tocado ? color : color.withOpacity(0.85),
        radius: tocado ? 82 : 68,
        title: pct >= 8 ? '${pct.toStringAsFixed(0)}%' : '',
        titleStyle: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      );
    }).toList();

    // Info de la categoría tocada
    Map<String, dynamic>? catTocada;
    Color? colorTocado;
    if (_sectorTocado != null && _sectorTocado! < _porCategoria.length) {
      catTocada = _porCategoria[_sectorTocado!];
      colorTocado = catTocada['color'] != null
          ? _hexColor(catTocada['color'] as String)
          : _coloresFijos[_sectorTocado! % _coloresFijos.length];
    }

    return SizedBox(
      height: 240,
      child: Stack(
        alignment: Alignment.center,
        children: [
          PieChart(
            PieChartData(
              sections: sections,
              centerSpaceRadius: 56,
              sectionsSpace: 2,
              pieTouchData: PieTouchData(
                touchCallback: (event, response) {
                  if (event is FlTapUpEvent) {
                    setState(() {
                      final idx = response?.touchedSection?.touchedSectionIndex;
                      if (idx == null || idx < 0) {
                        _sectorTocado = null;
                      } else {
                        _sectorTocado = _sectorTocado == idx ? null : idx;
                      }
                    });
                  }
                },
              ),
            ),
          ),
          // Centro — info al tocar o total general
          catTocada != null
              ? Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Iconos.mapa[catTocada['icono'] as String?] ?? Icons.category,
                      color: colorTocado, size: 20,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      catTocada['nombre'] as String,
                      style: TextStyle(
                          fontSize: 11, fontWeight: FontWeight.w700,
                          color: colorTocado),
                      textAlign: TextAlign.center,
                    ),
                    Text(
                      Formato.moneda((catTocada['total'] as num).toDouble()),
                      style: TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w900,
                          color: colorTocado),
                    ),
                    Text(
                      '${total > 0 ? ((catTocada['total'] as num).toDouble() / total * 100).toStringAsFixed(1) : 0}%',
                      style: TextStyle(fontSize: 10, color: cs.outline),
                    ),
                  ],
                )
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('Total', style: TextStyle(fontSize: 11, color: cs.outline)),
                    Text(Formato.moneda(total),
                        style: TextStyle(
                            fontSize: 13, fontWeight: FontWeight.w800,
                            color: cs.primary)),
                  ],
                ),
        ],
      ),
    );
  }

  // ── Barras por medio de pago ─────────────────────────────────────

  Widget _buildBarrasMedioPago(ColorScheme cs) {
    final maxVal = _porMedioPago
        .map((e) => (e['total'] as num).toDouble())
        .fold<double>(0, (a, b) => a > b ? a : b);

    final bars = _porMedioPago.asMap().entries.map((entry) {
      final i = entry.key;
      final e = entry.value;
      final valor = (e['total'] as num).toDouble();
      return BarChartGroupData(
        x: i,
        barRods: [
          BarChartRodData(
            toY: valor,
            color: _coloresFijos[i % _coloresFijos.length],
            width: 28,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
          ),
        ],
      );
    }).toList();

    return Container(
      height: 220,
      padding: const EdgeInsets.only(top: 16, right: 16),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withOpacity(0.5),
        borderRadius: BorderRadius.circular(16),
      ),
      child: BarChart(
        BarChartData(
          maxY: maxVal * 1.2,
          barGroups: bars,
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            getDrawingHorizontalLine: (_) =>
                FlLine(color: cs.outline.withOpacity(0.1), strokeWidth: 1),
          ),
          borderData: FlBorderData(show: false),
          titlesData: FlTitlesData(
            leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (val, _) {
                  final i = val.toInt();
                  if (i >= _porMedioPago.length) return const SizedBox();
                  final nombre = (_porMedioPago[i]['nombre'] as String);
                  // Abreviar nombre largo
                  final abrev = nombre.length > 8 ? '${nombre.substring(0, 7)}.' : nombre;
                  return Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(abrev,
                        style: TextStyle(fontSize: 9, color: cs.outline),
                        textAlign: TextAlign.center),
                  );
                },
                reservedSize: 32,
              ),
            ),
          ),
          barTouchData: BarTouchData(
            touchTooltipData: BarTouchTooltipData(
              getTooltipItem: (group, _, rod, __) {
                final nombre = _porMedioPago[group.x]['nombre'] as String;
                return BarTooltipItem(
                  '$nombre\n${Formato.moneda(rod.toY)}',
                  const TextStyle(color: Colors.white, fontSize: 12,
                      fontWeight: FontWeight.bold),
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  // ── Individual vs Compartido ─────────────────────────────────────

  Widget _buildIndVsComp(ColorScheme cs) {
    final ind = _indVsComp['individual'] ?? 0;
    final comp = _indVsComp['compartido'] ?? 0;
    final total = ind + comp;
    final pctInd = total > 0 ? ind / total : 0.0;
    final pctComp = total > 0 ? comp / total : 0.0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withOpacity(0.5),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _TarjetaMiniKPI(
                  label: 'Individual',
                  valor: Formato.moneda(ind),
                  pct: Formato.porcentaje(pctInd * 100),
                  color: cs.primary,
                  icono: Icons.person,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _TarjetaMiniKPI(
                  label: 'Compartido',
                  valor: Formato.moneda(comp),
                  pct: Formato.porcentaje(pctComp * 100),
                  color: cs.secondary,
                  icono: Icons.group,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          // Barra de progreso dividida
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Row(
              children: [
                if (pctInd > 0)
                  Expanded(
                    flex: (pctInd * 100).round(),
                    child: Container(height: 10, color: cs.primary),
                  ),
                if (pctComp > 0)
                  Expanded(
                    flex: (pctComp * 100).round(),
                    child: Container(height: 10, color: cs.secondary),
                  ),
                if (total == 0)
                  Expanded(child: Container(height: 10, color: cs.outlineVariant)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Histórico anual ──────────────────────────────────────────────

  Widget _buildHistoricoAnual(ColorScheme cs, GastosProvider provider) {
    if (_resumenAnual.isEmpty) return const SizedBox();

    final maxVal = _resumenAnual
        .map((e) => (e['total'] as num).toDouble())
        .fold<double>(0, (a, b) => a > b ? a : b);

    final mesesAbrev = ['E','F','M','A','M','J','J','A','S','O','N','D'];
    final mesActual = provider.periodo.desde.month;

    final bars = _resumenAnual.map((e) {
      final mes = int.parse(e['mes'] as String);
      final total = (e['total'] as num).toDouble();
      final esMesActual = mes == mesActual;
      return BarChartGroupData(
        x: mes,
        barRods: [
          BarChartRodData(
            toY: total,
            color: esMesActual ? cs.primary : cs.primary.withOpacity(0.4),
            width: 18,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(5)),
          ),
        ],
      );
    }).toList();

    return Container(
      height: 200,
      padding: const EdgeInsets.only(top: 16, right: 12, bottom: 8, left: 4),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withOpacity(0.5),
        borderRadius: BorderRadius.circular(16),
      ),
      child: BarChart(
        BarChartData(
          maxY: maxVal * 1.25,
          barGroups: bars,
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            getDrawingHorizontalLine: (_) =>
                FlLine(color: cs.outline.withOpacity(0.1), strokeWidth: 1),
          ),
          borderData: FlBorderData(show: false),
          titlesData: FlTitlesData(
            leftTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false)),
            topTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false)),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (val, _) {
                  final i = val.toInt() - 1;
                  if (i < 0 || i >= 12) return const SizedBox();
                  final esMesActual = val.toInt() == mesActual;
                  return Text(
                    mesesAbrev[i],
                    style: TextStyle(
                      fontSize: 10,
                      color: esMesActual ? cs.primary : cs.outline,
                      fontWeight: esMesActual ? FontWeight.bold : FontWeight.normal,
                    ),
                  );
                },
                reservedSize: 20,
              ),
            ),
          ),
          barTouchData: BarTouchData(
            touchTooltipData: BarTouchTooltipData(
              getTooltipItem: (group, _, rod, __) {
                final mes = group.x;
                final i = mes - 1;
                final nombreMes = i >= 0 && i < 12
                    ? Formato.nombreMes(mes)
                    : '$mes';
                return BarTooltipItem(
                  '$nombreMes\n${Formato.moneda(rod.toY)}',
                  const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.bold),
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  // ── Top categorías ───────────────────────────────────────────────

  Widget _buildTopCategorias(ColorScheme cs) {
    final total = _porCategoria.fold<double>(
        0, (s, e) => s + (e['total'] as num).toDouble());
    final top = _porCategoria.take(10).toList();

    return Column(
      children: top.asMap().entries.map((entry) {
        final i = entry.key;
        final e = entry.value;
        final valor = (e['total'] as num).toDouble();
        final pct = total > 0 ? valor / total : 0.0;
        final color = e['color'] != null
            ? _hexColor(e['color'] as String)
            : _coloresFijos[i % _coloresFijos.length];

        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: cs.surfaceContainerHighest.withOpacity(0.5),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Container(
                    width: 10, height: 10,
                    decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(e['nombre'] as String,
                        style: const TextStyle(fontWeight: FontWeight.w600)),
                  ),
                  Text(Formato.moneda(valor),
                      style: TextStyle(fontWeight: FontWeight.bold, color: color)),
                  const SizedBox(width: 8),
                  Text(Formato.porcentaje(pct * 100),
                      style: TextStyle(fontSize: 12, color: cs.outline)),
                ],
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: pct,
                  minHeight: 6,
                  backgroundColor: color.withOpacity(0.15),
                  valueColor: AlwaysStoppedAnimation<Color>(color),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}

// ─── Widgets auxiliares ──────────────────────────────────────────────────────

class _SeccionTitulo extends StatelessWidget {
  final String texto;
  const _SeccionTitulo(this.texto);

  @override
  Widget build(BuildContext context) {
    return Text(texto,
        style: Theme.of(context)
            .textTheme
            .titleMedium
            ?.copyWith(fontWeight: FontWeight.bold));
  }
}

class _TarjetaKPI extends StatelessWidget {
  final String titulo;
  final String valor;
  final IconData icono;
  final Color color;
  final Color bg;

  const _TarjetaKPI({
    required this.titulo,
    required this.valor,
    required this.icono,
    required this.color,
    required this.bg,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Icon(icono, color: color, size: 22),
          const SizedBox(height: 6),
          Text(valor,
              style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  color: color),
              maxLines: 1,
              overflow: TextOverflow.ellipsis),
          Text(titulo,
              style: TextStyle(fontSize: 11, color: color.withOpacity(0.8))),
        ],
      ),
    );
  }
}

class _TarjetaMiniKPI extends StatelessWidget {
  final String label;
  final String valor;
  final String pct;
  final Color color;
  final IconData icono;

  const _TarjetaMiniKPI({
    required this.label,
    required this.valor,
    required this.pct,
    required this.color,
    required this.icono,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(icono, color: color, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: TextStyle(fontSize: 11, color: color.withOpacity(0.8))),
                Text(valor,
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: color),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
                Text(pct, style: TextStyle(fontSize: 11, color: color)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Extensión comparación mensual ───────────────────────────────────────────

extension _DashboardComparacion on _PantallaDashboardState {

  Widget _buildComparacionMensual(ColorScheme cs) {
    final hoy = DateTime.now();
    final totalActual = (_mesActual['total'] as num?)?.toDouble() ?? 0;
    final totalAnterior = (_mesAnterior['total'] as num?)?.toDouble() ?? 0;
    final cantActual = (_mesActual['cantidad'] as num?)?.toInt() ?? 0;
    final cantAnterior = (_mesAnterior['cantidad'] as num?)?.toInt() ?? 0;
    final diferencia = totalActual - totalAnterior;
    final pct = totalAnterior > 0
        ? ((diferencia / totalAnterior) * 100).toStringAsFixed(1)
        : null;
    final subio = diferencia > 0;
    final igual = diferencia == 0;

    final mesActualNombre = Formato.nombreMes(hoy.month);
    final mesAnteriorNombre = Formato.nombreMes(
        hoy.month == 1 ? 12 : hoy.month - 1);

    final catActual = (_mesActual['porCategoria'] as List?) ?? [];
    final catAnterior = (_mesAnterior['porCategoria'] as List?) ?? [];
    final medActual = (_mesActual['porMedio'] as List?) ?? [];
    final medAnterior = (_mesAnterior['porMedio'] as List?) ?? [];

    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: cs.outline.withOpacity(0.1)),
        boxShadow: [BoxShadow(
            color: cs.shadow.withOpacity(0.05),
            blurRadius: 10, offset: const Offset(0, 3))],
      ),
      child: Column(
        children: [

          // ── Header con totales ──────────────────────────────
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: subio
                    ? [const Color(0xFFC62828), const Color(0xFFE57373)]
                    : igual
                        ? [cs.primary, cs.primary.withOpacity(0.7)]
                        : [const Color(0xFF2E7D32), const Color(0xFF66BB6A)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(20)),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Icon(
                      igual ? Icons.trending_flat
                          : subio ? Icons.trending_up : Icons.trending_down,
                      color: Colors.white, size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text('$mesActualNombre vs $mesAnteriorNombre',
                        style: const TextStyle(
                            color: Colors.white70, fontSize: 12,
                            fontWeight: FontWeight.w600)),
                    const Spacer(),
                    if (pct != null)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          '${subio ? '+' : ''}$pct%',
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12, fontWeight: FontWeight.w800),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _ColComparacion(
                        label: mesActualNombre,
                        monto: Formato.moneda(totalActual),
                        sub: '$cantActual gastos',
                        esActual: true,
                      ),
                    ),
                    Container(
                        width: 1, height: 48,
                        color: Colors.white24,
                        margin: const EdgeInsets.symmetric(horizontal: 12)),
                    Expanded(
                      child: _ColComparacion(
                        label: mesAnteriorNombre,
                        monto: Formato.moneda(totalAnterior),
                        sub: '$cantAnterior gastos',
                        esActual: false,
                      ),
                    ),
                    Container(
                        width: 1, height: 48,
                        color: Colors.white24,
                        margin: const EdgeInsets.symmetric(horizontal: 12)),
                    Expanded(
                      child: _ColComparacion(
                        label: 'Diferencia',
                        monto: '${diferencia >= 0 ? '+' : ''}${Formato.moneda(diferencia)}',
                        sub: diferencia == 0 ? 'Igual' : diferencia > 0 ? 'Más caro' : 'Más barato',
                        esActual: true,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // ── Top categorías ──────────────────────────────────
          if (catActual.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Row(
                children: [
                  Text('Top categorías',
                      style: TextStyle(
                          fontSize: 12, fontWeight: FontWeight.w700,
                          color: cs.outline)),
                  const Spacer(),
                  Text(mesActualNombre,
                      style: TextStyle(fontSize: 11, color: cs.primary,
                          fontWeight: FontWeight.w600)),
                  Text(' vs ', style: TextStyle(fontSize: 11, color: cs.outline)),
                  Text(mesAnteriorNombre,
                      style: TextStyle(fontSize: 11, color: cs.outline)),
                ],
              ),
            ),
            ...List.generate(catActual.length > 5 ? 5 : catActual.length, (i) {
              final cat = catActual[i] as Map;
              final totalCat = (cat['total'] as num).toDouble();
              // Buscar en mes anterior
              final catAnt = catAnterior.cast<Map>().where((c) =>
                  c['nombre'] == cat['nombre']).firstOrNull;
              final totalCatAnt = catAnt != null
                  ? (catAnt['total'] as num).toDouble()
                  : 0.0;
              final diffCat = totalCat - totalCatAnt;
              final color = _PantallaDashboardState._hexColor(
                  cat['color'] as String? ?? '#0288D1');

              return Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
                child: Row(
                  children: [
                    Text(Iconos.toEmoji(cat['icono'] as String? ?? ''), style: const TextStyle(fontSize: 18)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(cat['nombre'] as String,
                          style: const TextStyle(fontSize: 13)),
                    ),
                    Text(Formato.moneda(totalCat),
                        style: const TextStyle(
                            fontSize: 13, fontWeight: FontWeight.w600)),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: diffCat > 0
                            ? cs.errorContainer
                            : diffCat < 0
                                ? const Color(0xFFE8F5E9)
                                : cs.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        '${diffCat >= 0 ? '+' : ''}${Formato.moneda(diffCat)}',
                        style: TextStyle(
                          fontSize: 10, fontWeight: FontWeight.w700,
                          color: diffCat > 0
                              ? cs.error
                              : diffCat < 0
                                  ? const Color(0xFF2E7D32)
                                  : cs.outline,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],

          // ── Por medio de pago ───────────────────────────────
          if (medActual.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Text('Por medio de pago',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700,
                      color: cs.outline)),
            ),
            ...medActual.cast<Map>().map((med) {
              final totalMed = (med['total'] as num).toDouble();
              final medAnt = medAnterior.cast<Map>().where((m) =>
                  m['nombre'] == med['nombre']).firstOrNull;
              final totalMedAnt = medAnt != null
                  ? (medAnt['total'] as num).toDouble()
                  : 0.0;
              final diffMed = totalMed - totalMedAnt;
              final color = _PantallaDashboardState._hexColor(
                  med['color'] as String? ?? '#0288D1');

              return Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
                child: Row(
                  children: [
                    Container(
                      width: 10, height: 10,
                      decoration: BoxDecoration(
                          color: color, shape: BoxShape.circle),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(med['nombre'] as String,
                          style: const TextStyle(fontSize: 13)),
                    ),
                    Text(Formato.moneda(totalMed),
                        style: const TextStyle(
                            fontSize: 13, fontWeight: FontWeight.w600)),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: diffMed > 0
                            ? cs.errorContainer
                            : diffMed < 0
                                ? const Color(0xFFE8F5E9)
                                : cs.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        '${diffMed >= 0 ? '+' : ''}${Formato.moneda(diffMed)}',
                        style: TextStyle(
                          fontSize: 10, fontWeight: FontWeight.w700,
                          color: diffMed > 0
                              ? cs.error
                              : diffMed < 0
                                  ? const Color(0xFF2E7D32)
                                  : cs.outline,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }),
            const SizedBox(height: 12),
          ],
        ],
      ),
    );
  }
}

class _ColComparacion extends StatelessWidget {
  final String label;
  final String monto;
  final String sub;
  final bool esActual;

  const _ColComparacion({
    required this.label,
    required this.monto,
    required this.sub,
    required this.esActual,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: TextStyle(
                color: esActual ? Colors.white : Colors.white60,
                fontSize: 11)),
        Text(monto,
            style: TextStyle(
                color: Colors.white,
                fontSize: esActual ? 15 : 13,
                fontWeight: FontWeight.w800)),
        Text(sub,
            style: const TextStyle(color: Colors.white60, fontSize: 10)),
      ],
    );
  }
}
