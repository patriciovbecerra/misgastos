import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:misgastos/models/gasto.dart';
import 'package:misgastos/models/grupo.dart';
import 'package:misgastos/models/participante.dart';
import 'package:misgastos/providers/gastos_provider.dart';
import 'package:misgastos/utils/formato.dart';
import 'package:misgastos/utils/iconos.dart';

class PantallaDetalleGrupo extends StatefulWidget {
  final Grupo grupo;
  const PantallaDetalleGrupo({super.key, required this.grupo});

  @override
  State<PantallaDetalleGrupo> createState() => _PantallaDetalleGrupoState();
}

class _PantallaDetalleGrupoState extends State<PantallaDetalleGrupo>
    with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;
  List<Participante> _participantes = [];
  List<Gasto> _gastos = [];
  bool _cargando = true;

  // Mapa participanteNombre → monto que pagó
  Map<String, double> _pagadoPor = {};
  // Lista de deudas calculadas
  List<_Deuda> _deudas = [];

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 3, vsync: this);
    _cargarDatos();
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  Future<void> _cargarDatos() async {
    setState(() => _cargando = true);
    final provider = context.read<GastosProvider>();

    final participantes = await provider.getParticipantes(widget.grupo.id!);
    final todosGastos = await provider.db.getAllGastos();
    final gastosGrupo = todosGastos
        .where((g) => g.idGrupo == widget.grupo.id)
        .toList()
      ..sort((a, b) => b.fecha.compareTo(a.fecha));

    // Calcular cuánto pagó cada participante
    // Por simplicidad: el total del grupo se divide equitativamente
    // entre los participantes. El que registró el gasto "pagó" ese monto.
    final pagado = <String, double>{};
    for (final p in participantes) {
      pagado[p.nombre] = 0;
    }

    double totalGrupo = 0;
    for (final g in gastosGrupo) {
      totalGrupo += g.monto;
    }

    // Asignamos todos los gastos al primer participante como "pagador"
    // (En fases futuras se puede agregar quién pagó cada gasto)
    // Por ahora, el primero de la lista es el pagador por defecto
    if (participantes.isNotEmpty) {
      pagado[participantes.first.nombre] =
          (pagado[participantes.first.nombre] ?? 0) + totalGrupo;
    }

    // Calcular deudas: cada uno debe pagar total/n
    final deudas = _calcularDeudas(participantes, pagado, totalGrupo);

    if (mounted) {
      setState(() {
        _participantes = participantes;
        _gastos = gastosGrupo;
        _pagadoPor = pagado;
        _deudas = deudas;
        _cargando = false;
      });
    }
  }

  /// Algoritmo simplificado de liquidación de deudas
  List<_Deuda> _calcularDeudas(
    List<Participante> participantes,
    Map<String, double> pagado,
    double total,
  ) {
    if (participantes.isEmpty || total == 0) return [];

    final n = participantes.length;
    final parteIgual = total / n;

    // Balance de cada uno: lo que pagó - lo que debería pagar
    final balance = <String, double>{};
    for (final p in participantes) {
      final pagadoP = pagado[p.nombre] ?? 0;
      balance[p.nombre] = pagadoP - parteIgual;
    }

    // Separar acreedores (balance > 0) y deudores (balance < 0)
    final acreedores = balance.entries
        .where((e) => e.value > 0.5)
        .toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final deudores = balance.entries
        .where((e) => e.value < -0.5)
        .toList()
      ..sort((a, b) => a.value.compareTo(b.value));

    final deudas = <_Deuda>[];
    final saldoAcreedor = Map.fromEntries(acreedores);
    final saldoDeudor = Map.fromEntries(deudores);

    for (final deudor in saldoDeudor.keys.toList()) {
      var deuda = -(saldoDeudor[deudor] ?? 0);
      for (final acreedor in saldoAcreedor.keys.toList()) {
        if (deuda <= 0.5) break;
        final disponible = saldoAcreedor[acreedor] ?? 0;
        if (disponible <= 0.5) continue;

        final pago = deuda < disponible ? deuda : disponible;
        deudas.add(_Deuda(
          de: deudor,
          para: acreedor,
          monto: pago,
        ));
        saldoAcreedor[acreedor] = disponible - pago;
        deuda -= pago;
      }
    }

    return deudas;
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final totalGrupo = _gastos.fold(0.0, (s, g) => s + g.monto);
    final parteIgual = _participantes.isNotEmpty
        ? totalGrupo / _participantes.length
        : 0.0;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.grupo.nombre),
        centerTitle: true,
        bottom: TabBar(
          controller: _tabCtrl,
          tabs: const [
            Tab(icon: Icon(Icons.receipt_long), text: 'Gastos'),
            Tab(icon: Icon(Icons.people), text: 'Resumen'),
            Tab(icon: Icon(Icons.swap_horiz), text: 'Deudas'),
          ],
        ),
      ),
      body: _cargando
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabCtrl,
              children: [
                _TabGastos(gastos: _gastos, totalGrupo: totalGrupo),
                _TabResumen(
                  participantes: _participantes,
                  totalGrupo: totalGrupo,
                  parteIgual: parteIgual,
                  pagadoPor: _pagadoPor,
                ),
                _TabDeudas(deudas: _deudas, participantes: _participantes),
              ],
            ),
    );
  }
}

// ─── Modelo de deuda ─────────────────────────────────────────────────────────

class _Deuda {
  final String de;
  final String para;
  final double monto;
  const _Deuda({required this.de, required this.para, required this.monto});
}

// ─── Tab 1: Lista de gastos del grupo ────────────────────────────────────────

class _TabGastos extends StatelessWidget {
  final List<Gasto> gastos;
  final double totalGrupo;

  static const _mapaIconos = {
    'food': Icons.restaurant, 'shopping': Icons.shopping_bag,
    'car': Icons.directions_car, 'home': Icons.home,
    'transport': Icons.directions_car_filled, 'health': Icons.health_and_safety,
    'entertainment': Icons.movie, 'others': Icons.more_horiz,
    'education': Icons.school, 'travel': Icons.flight,
    'gym': Icons.fitness_center, 'pets': Icons.pets,
  };

  static Color _hexColor(String hex) {
    final h = hex.replaceAll('#', '');
    return Color(int.parse('FF$h', radix: 16));
  }

  const _TabGastos({required this.gastos, required this.totalGrupo});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    if (gastos.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.receipt_outlined, size: 56, color: cs.outlineVariant),
            const SizedBox(height: 12),
            Text('Sin gastos en este grupo',
                style: TextStyle(color: cs.outline)),
          ],
        ),
      );
    }

    return Column(
      children: [
        // Encabezado total
        Container(
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: cs.primaryContainer,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              Icon(Icons.group, color: cs.primary),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Total del grupo',
                        style: TextStyle(
                            fontSize: 12,
                            color: cs.onPrimaryContainer.withOpacity(0.7))),
                    Text(Formato.moneda(totalGrupo),
                        style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: cs.onPrimaryContainer)),
                  ],
                ),
              ),
              Text('${gastos.length} gastos',
                  style: TextStyle(color: cs.onPrimaryContainer, fontSize: 13)),
            ],
          ),
        ),

        // Lista
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: gastos.length,
            itemBuilder: (ctx, i) {
              final g = gastos[i];
              final color = g.categoria != null
                  ? _hexColor(g.categoria!.color)
                  : cs.primary;
              return Card(
                margin: const EdgeInsets.only(bottom: 10),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: color.withOpacity(0.15),
                    child: Icon(
                      Iconos.mapa[g.categoria?.icono] ?? Icons.receipt_outlined,
                      color: color, size: 20,
                    ),
                  ),
                  title: Text(
                    g.descripcion ?? g.categoria?.nombre ?? 'Gasto',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text(
                    '${Formato.fechaCorta(g.fecha)} · ${g.medioPago?.nombre ?? ''}',
                    style: TextStyle(fontSize: 12, color: cs.outline),
                  ),
                  trailing: Text(
                    Formato.moneda(g.monto),
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: cs.onSurface,
                        fontSize: 15),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

// ─── Tab 2: Resumen por participante ─────────────────────────────────────────

class _TabResumen extends StatelessWidget {
  final List<Participante> participantes;
  final double totalGrupo;
  final double parteIgual;
  final Map<String, double> pagadoPor;

  const _TabResumen({
    required this.participantes,
    required this.totalGrupo,
    required this.parteIgual,
    required this.pagadoPor,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    if (participantes.isEmpty) {
      return Center(
        child: Text('Sin participantes en este grupo',
            style: TextStyle(color: cs.outline)),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Resumen global
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: cs.secondaryContainer,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              Expanded(
                child: _MiniKPI(
                  label: 'Total',
                  valor: Formato.moneda(totalGrupo),
                  color: cs.onSecondaryContainer,
                ),
              ),
              Container(width: 1, height: 40, color: cs.outline.withOpacity(0.3)),
              Expanded(
                child: _MiniKPI(
                  label: 'Participantes',
                  valor: '${participantes.length}',
                  color: cs.onSecondaryContainer,
                ),
              ),
              Container(width: 1, height: 40, color: cs.outline.withOpacity(0.3)),
              Expanded(
                child: _MiniKPI(
                  label: 'Parte c/u',
                  valor: Formato.moneda(parteIgual),
                  color: cs.onSecondaryContainer,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        Text('Por participante',
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),

        ...participantes.map((p) {
          final pagado = pagadoPor[p.nombre] ?? 0;
          final balance = pagado - parteIgual;
          final esDeutor = balance < -0.5;
          final esAcreedor = balance > 0.5;
          final colorBalance = esDeutor
              ? cs.error
              : esAcreedor
                  ? const Color(0xFF4CAF50)
                  : cs.outline;

          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: cs.surfaceContainerHighest.withOpacity(0.5),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: esDeutor
                    ? cs.error.withOpacity(0.3)
                    : esAcreedor
                        ? const Color(0xFF4CAF50).withOpacity(0.3)
                        : Colors.transparent,
              ),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: cs.tertiaryContainer,
                      child: Text(
                        p.nombre[0].toUpperCase(),
                        style: TextStyle(
                            color: cs.onTertiaryContainer,
                            fontWeight: FontWeight.bold),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(p.nombre,
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 15)),
                          Text(
                            esDeutor
                                ? 'Debe ${Formato.moneda(balance.abs())}'
                                : esAcreedor
                                    ? 'Le deben ${Formato.moneda(balance)}'
                                    : 'Está al día',
                            style: TextStyle(
                                color: colorBalance,
                                fontSize: 12,
                                fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(Formato.moneda(pagado),
                            style: const TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 15)),
                        Text('pagó',
                            style:
                                TextStyle(fontSize: 11, color: cs.outline)),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                // Barra de progreso
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: totalGrupo > 0 ? (pagado / totalGrupo).clamp(0.0, 1.0) : 0,
                    minHeight: 6,
                    backgroundColor: cs.outlineVariant.withOpacity(0.3),
                    valueColor: AlwaysStoppedAnimation<Color>(colorBalance == cs.outline ? cs.primary : colorBalance),
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Pagó: ${Formato.moneda(pagado)}',
                        style: TextStyle(fontSize: 11, color: cs.outline)),
                    Text('Debe pagar: ${Formato.moneda(parteIgual)}',
                        style: TextStyle(fontSize: 11, color: cs.outline)),
                  ],
                ),
              ],
            ),
          );
        }),
      ],
    );
  }
}

// ─── Tab 3: Deudas a liquidar ────────────────────────────────────────────────

class _TabDeudas extends StatelessWidget {
  final List<_Deuda> deudas;
  final List<Participante> participantes;

  const _TabDeudas({required this.deudas, required this.participantes});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    if (participantes.isEmpty) {
      return Center(
        child: Text('Agrega participantes al grupo',
            style: TextStyle(color: cs.outline)),
      );
    }

    if (deudas.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.check_circle_outline,
                size: 64, color: const Color(0xFF4CAF50)),
            const SizedBox(height: 16),
            Text('¡Todo al día!',
                style: Theme.of(context)
                    .textTheme
                    .titleLarge
                    ?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text('No hay deudas pendientes en este grupo',
                style: TextStyle(color: cs.outline)),
          ],
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Encabezado
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: cs.errorContainer.withOpacity(0.5),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: [
              Icon(Icons.info_outline, color: cs.error, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Transferencias mínimas para liquidar el grupo',
                  style: TextStyle(color: cs.onErrorContainer, fontSize: 13),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        Text('Quién le debe a quién',
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),

        ...deudas.map((d) => _TarjetaDeuda(deuda: d)),

        const SizedBox(height: 24),

        // Botón marcar todo como pagado (visual)
        OutlinedButton.icon(
          onPressed: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Funcionalidad de registro de pagos próximamente'),
                duration: Duration(seconds: 2),
              ),
            );
          },
          icon: const Icon(Icons.check_circle_outline),
          label: const Text('Marcar todo como pagado'),
          style: OutlinedButton.styleFrom(
            minimumSize: const Size(double.infinity, 48),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
          ),
        ),
      ],
    );
  }
}

class _TarjetaDeuda extends StatelessWidget {
  final _Deuda deuda;
  const _TarjetaDeuda({required this.deuda});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withOpacity(0.6),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: cs.outline.withOpacity(0.15)),
      ),
      child: Row(
        children: [
          // Deudor
          Expanded(
            child: Column(
              children: [
                CircleAvatar(
                  backgroundColor: cs.errorContainer,
                  child: Text(
                    deuda.de[0].toUpperCase(),
                    style: TextStyle(
                        color: cs.onErrorContainer,
                        fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(height: 4),
                Text(deuda.de,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 13)),
                Text('paga', style: TextStyle(fontSize: 11, color: cs.outline)),
              ],
            ),
          ),

          // Flecha + monto
          Expanded(
            child: Column(
              children: [
                Text(
                  Formato.moneda(deuda.monto),
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: cs.primary),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        height: 2,
                        color: cs.primary.withOpacity(0.4),
                      ),
                    ),
                    Icon(Icons.arrow_forward, color: cs.primary, size: 18),
                  ],
                ),
              ],
            ),
          ),

          // Acreedor
          Expanded(
            child: Column(
              children: [
                CircleAvatar(
                  backgroundColor: const Color(0xFF4CAF50).withOpacity(0.2),
                  child: Text(
                    deuda.para[0].toUpperCase(),
                    style: const TextStyle(
                        color: Color(0xFF4CAF50),
                        fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(height: 4),
                Text(deuda.para,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 13)),
                Text('recibe',
                    style: TextStyle(fontSize: 11, color: cs.outline)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Helpers ─────────────────────────────────────────────────────────────────

class _MiniKPI extends StatelessWidget {
  final String label;
  final String valor;
  final Color color;

  const _MiniKPI({required this.label, required this.valor, required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(valor,
            style: TextStyle(
                fontWeight: FontWeight.bold, fontSize: 14, color: color),
            textAlign: TextAlign.center),
        Text(label,
            style: TextStyle(fontSize: 11, color: color.withOpacity(0.7)),
            textAlign: TextAlign.center),
      ],
    );
  }
}
