import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:misgastos/models/gasto.dart';
import 'package:misgastos/providers/gastos_provider.dart';
import 'package:misgastos/utils/formato.dart';
import 'package:misgastos/utils/exportar_excel.dart';
import 'package:misgastos/utils/iconos.dart';
import 'package:misgastos/models/periodo.dart';
import 'package:misgastos/screens/shared/selector_periodo.dart';
import 'formulario_gasto.dart';

class PantallaGastos extends StatefulWidget {
  const PantallaGastos({super.key});

  @override
  State<PantallaGastos> createState() => _PantallaGastosState();
}

class _PantallaGastosState extends State<PantallaGastos> {
  // Filtros
  int? _idCategoriaFiltro;
  int? _idMedioPagoFiltro;
  bool? _tipoFiltro; // null=todos, false=individual, true=compartido
  bool _ordenAscendente = false; // false = más reciente primero

  static const _mapaIconos = {
    'food': Icons.restaurant,
    'shopping': Icons.shopping_bag,
    'car': Icons.directions_car,
    'home': Icons.home,
    'transport': Icons.directions_car_filled,
    'health': Icons.health_and_safety,
    'entertainment': Icons.movie,
    'others': Icons.more_horiz,
    'education': Icons.school,
    'travel': Icons.flight,
    'gym': Icons.fitness_center,
    'pets': Icons.pets,
    'credit_card': Icons.credit_card,
    'debit_card': Icons.payment,
    'cash': Icons.attach_money,
    'transfer': Icons.swap_horiz,
    'phone': Icons.phone_android,
    'savings': Icons.savings,
    'account_balance': Icons.account_balance,
  };

  static Color _hexColor(String hex) {
    final h = hex.replaceAll('#', '');
    return Color(int.parse('FF$h', radix: 16));
  }

  List<Gasto> _aplicarFiltros(List<Gasto> gastos) {
    final lista = List<Gasto>.from(gastos.where((g) {
      if (_idCategoriaFiltro != null && g.idCategoria != _idCategoriaFiltro) return false;
      if (_idMedioPagoFiltro != null && g.idMedioPago != _idMedioPagoFiltro) return false;
      if (_tipoFiltro != null && g.esCompartido != _tipoFiltro) return false;
      return true;
    }));
    lista.sort((a, b) => _ordenAscendente
        ? a.fecha.compareTo(b.fecha)
        : b.fecha.compareTo(a.fecha));
    return lista;
  }

  void _abrirFormulario([Gasto? gasto]) async {
    final provider = context.read<GastosProvider>();
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChangeNotifierProvider.value(
          value: provider,
          child: FormularioGasto(gasto: gasto),
        ),
      ),
    );
  }

  void _duplicarGasto(Gasto gasto) {
    // Crear copia sin id, con fecha de hoy, reseteando cuotas
    final copia = Gasto(
      monto: gasto.monto,
      valorCuota: gasto.valorCuota,
      cuotasTotal: gasto.cuotasTotal,
      cuotaNumero: 1,
      fecha: DateTime.now(),
      fechaCompra: DateTime.now(),
      descripcion: gasto.descripcion,
      esCompartido: gasto.esCompartido,
      idCategoria: gasto.idCategoria,
      idMedioPago: gasto.idMedioPago,
      idGrupo: gasto.idGrupo,
      categoria: gasto.categoria,
      medioPago: gasto.medioPago,
      grupo: gasto.grupo,
    );
    _abrirFormulario(copia);
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<GastosProvider>();
    final cs = Theme.of(context).colorScheme;
    final gastosFiltrados = _aplicarFiltros(provider.gastos);
    final hayFiltros = _idCategoriaFiltro != null ||
        _idMedioPagoFiltro != null ||
        _tipoFiltro != null;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Gastos'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(44),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 0, 8, 6),
            child: Row(
              children: [
                // Mes anterior
                IconButton(
                  icon: const Icon(Icons.chevron_left, size: 22),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  onPressed: () {
                    final p = provider.periodo;
                    final nuevomes = p.desde.month - 1;
                    final nuevoAnio = p.desde.year + (nuevomes < 1 ? -1 : 0);
                    final mes = nuevomes < 1 ? 12 : nuevomes;
                    context.read<GastosProvider>()
                        .cargarGastosPeriodo(Periodo.mes(mes, nuevoAnio));
                  },
                  color: cs.primary,
                ),
                // Selector de período (toca para abrir selector completo)
                Expanded(
                  child: GestureDetector(
                    onTap: () => _abrirSelectorPeriodo(context, provider),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: cs.primaryContainer.withOpacity(0.5),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.calendar_today,
                              size: 13, color: cs.primary),
                          const SizedBox(width: 6),
                          Text(
                            provider.periodo.etiqueta,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: cs.primary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                // Mes siguiente
                IconButton(
                  icon: const Icon(Icons.chevron_right, size: 22),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  onPressed: () {
                    final p = provider.periodo;
                    final nuevomes = p.desde.month + 1;
                    final nuevoAnio = p.desde.year + (nuevomes > 12 ? 1 : 0);
                    final mes = nuevomes > 12 ? 1 : nuevomes;
                    context.read<GastosProvider>()
                        .cargarGastosPeriodo(Periodo.mes(mes, nuevoAnio));
                  },
                  color: cs.primary,
                ),
                // Botón orden fecha
                IconButton(
                  icon: Icon(
                    _ordenAscendente
                        ? Icons.arrow_upward
                        : Icons.arrow_downward,
                    size: 20,
                  ),
                  tooltip: _ordenAscendente ? 'Más antiguo primero' : 'Más reciente primero',
                  color: cs.primary,
                  onPressed: () => setState(() => _ordenAscendente = !_ordenAscendente),
                ),
                // Filtro
                Stack(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.filter_list),
                      tooltip: 'Filtrar',
                      onPressed: _mostrarFiltros,
                    ),
                    if (hayFiltros)
                      Positioned(
                        right: 8, top: 8,
                        child: Container(
                          width: 8, height: 8,
                          decoration: BoxDecoration(
                              color: cs.error, shape: BoxShape.circle),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.file_download_outlined),
            tooltip: 'Exportar Excel',
            onPressed: () async {
              final gastos = _aplicarFiltros(
                  context.read<GastosProvider>().gastos);
              if (gastos.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('No hay gastos para exportar')));
                return;
              }
              try {
                final provider = context.read<GastosProvider>();
                await ExportarExcel.exportarGastos(
                  gastos: gastos,
                  periodoLabel: provider.periodo.etiqueta,
                );
              } catch (e) {
                if (mounted) ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error: \$e')));
              }
            },
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _abrirFormulario(),
        icon: const Icon(Icons.add),
        label: const Text('Nuevo gasto'),
      ),
      body: provider.isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // ── Resumen del mes ──
                _ResumenMes(
                  total: provider.totalMes,
                  cantidad: provider.gastos.length,
                  filtrado: gastosFiltrados.length != provider.gastos.length
                      ? gastosFiltrados.fold(0.0, (s, g) => (s ?? 0.0) + g.monto)
                      : null,
                ),

                // ── Chip de filtros activos ──
                if (hayFiltros)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    child: Row(
                      children: [
                        Icon(Icons.filter_list, size: 16, color: cs.primary),
                        const SizedBox(width: 4),
                        Text('Filtros activos',
                            style: TextStyle(fontSize: 12, color: cs.primary)),
                        const Spacer(),
                        TextButton(
                          onPressed: () => setState(() {
                            _idCategoriaFiltro = null;
                            _idMedioPagoFiltro = null;
                            _tipoFiltro = null;
                          }),
                          child: const Text('Limpiar', style: TextStyle(fontSize: 12)),
                        ),
                      ],
                    ),
                  ),

                // ── Lista de gastos ──
                Expanded(
                  child: gastosFiltrados.isEmpty
                      ? _EstadoVacio(hayFiltros: hayFiltros)
                      : ListView.builder(
                          padding: const EdgeInsets.only(
                              left: 16, right: 16, top: 8, bottom: 100),
                          itemCount: gastosFiltrados.length,
                          itemBuilder: (ctx, i) {
                            final gasto = gastosFiltrados[i];
                            return _TarjetaGasto(
                              gasto: gasto,
                              onEditar: () => _abrirFormulario(gasto),
                              onEliminar: () => _confirmarEliminar(gasto),
                              onDuplicar: () => _duplicarGasto(gasto),
                            );
                          },
                        ),
                ),
              ],
            ),
    );
  }

  Future<void> _confirmarEliminar(Gasto gasto) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('¿Eliminar gasto?'),
        content: Text(
          '${Formato.moneda(gasto.monto)} — ${gasto.descripcion ?? gasto.categoria?.nombre ?? ""}',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          FilledButton(
            style: FilledButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (ok == true && gasto.id != null) {
      if (mounted) await context.read<GastosProvider>().eliminarGasto(gasto.id!);
    }
  }



  void _abrirSelectorPeriodo(BuildContext context, GastosProvider provider) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => SelectorPeriodo(
        periodo: provider.periodo,
        onCambiar: (p) {
          context.read<GastosProvider>().cargarGastosPeriodo(p);
          Navigator.pop(context);
        },
      ),
    );
  }

  void _mostrarFiltros() {
    final provider = context.read<GastosProvider>();
    int? catFiltro = _idCategoriaFiltro;
    int? medioFiltro = _idMedioPagoFiltro;
    bool? tipoFiltro = _tipoFiltro;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setStateSheet) => DraggableScrollableSheet(
          initialChildSize: 0.7,
          minChildSize: 0.4,
          maxChildSize: 0.95,
          expand: false,
          builder: (_, scrollCtrl) => Padding(
          padding: const EdgeInsets.all(20),
          child: ListView(
            controller: scrollCtrl,
            children: [
              Row(
                children: [
                  const Text('Filtros', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const Spacer(),
                  TextButton(
                    onPressed: () => setStateSheet(() {
                      catFiltro = null;
                      medioFiltro = null;
                      tipoFiltro = null;
                    }),
                    child: const Text('Limpiar todo'),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Tipo
              const Text('Tipo', style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [
                  _FiltroChip(label: 'Todos', sel: tipoFiltro == null,
                      onTap: () => setStateSheet(() => tipoFiltro = null)),
                  _FiltroChip(label: 'Individual', sel: tipoFiltro == false,
                      onTap: () => setStateSheet(() => tipoFiltro = false)),
                  _FiltroChip(label: 'Compartido', sel: tipoFiltro == true,
                      onTap: () => setStateSheet(() => tipoFiltro = true)),
                ],
              ),
              const SizedBox(height: 16),

              // Categoría
              const Text('Categoría', style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _FiltroChip(label: 'Todas', sel: catFiltro == null,
                      onTap: () => setStateSheet(() => catFiltro = null)),
                  ...provider.categorias.map((c) => _FiltroChip(
                        label: c.nombre,
                        sel: catFiltro == c.id,
                        onTap: () => setStateSheet(() => catFiltro = c.id),
                      )),
                ],
              ),
              const SizedBox(height: 16),

              // Medio de pago
              const Text('Medio de pago', style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _FiltroChip(label: 'Todos', sel: medioFiltro == null,
                      onTap: () => setStateSheet(() => medioFiltro = null)),
                  ...provider.mediosPago.map((m) => _FiltroChip(
                        label: m.nombre,
                        sel: medioFiltro == m.id,
                        onTap: () => setStateSheet(() => medioFiltro = m.id),
                      )),
                ],
              ),
              const SizedBox(height: 20),

              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () {
                    setState(() {
                      _idCategoriaFiltro = catFiltro;
                      _idMedioPagoFiltro = medioFiltro;
                      _tipoFiltro = tipoFiltro;
                    });
                    Navigator.pop(ctx);
                  },
                  child: const Text('Aplicar filtros'),
                ),
              ),
              SizedBox(height: MediaQuery.of(ctx).viewInsets.bottom),
            ],
          ),
        ),
        ),
      ),
    );
  }
}

// ─── Widgets de la lista ─────────────────────────────────────────────────────

class _ResumenMes extends StatelessWidget {
  final double total;
  final int cantidad;
  final double? filtrado;

  const _ResumenMes({
    required this.total,
    required this.cantidad,
    this.filtrado,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.primaryContainer,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Total del mes',
                    style: TextStyle(fontSize: 12, color: cs.onPrimaryContainer.withOpacity(0.7))),
                Text(Formato.moneda(total),
                    style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: cs.onPrimaryContainer)),
                if (filtrado != null)
                  Text('Filtrado: ${Formato.moneda(filtrado!)}',
                      style: TextStyle(fontSize: 12, color: cs.primary)),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('$cantidad gastos',
                  style: TextStyle(
                      fontWeight: FontWeight.bold, color: cs.onPrimaryContainer)),
              Text('registrados',
                  style: TextStyle(fontSize: 12,
                      color: cs.onPrimaryContainer.withOpacity(0.7))),
            ],
          ),
        ],
      ),
    );
  }
}

class _TarjetaGasto extends StatelessWidget {
  final Gasto gasto;
  final VoidCallback onEditar;
  final VoidCallback onEliminar;
  final VoidCallback onDuplicar;

  const _TarjetaGasto({
    required this.gasto,
    required this.onEditar,
    required this.onEliminar,
    required this.onDuplicar,
  });

  static Color _hexColor(String hex) {
    final h = hex.replaceAll('#', '');
    return Color(int.parse('FF$h', radix: 16));
  }

  void _mostrarOpciones(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(width: 40, height: 4,
                  margin: const EdgeInsets.only(bottom: 8),
                  decoration: BoxDecoration(color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(2))),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: Text(
                  gasto.descripcion ?? gasto.categoria?.nombre ?? 'Gasto',
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                ),
              ),
              const Divider(),
              ListTile(
                leading: Icon(Icons.edit_outlined, color: cs.primary),
                title: const Text('Editar gasto'),
                onTap: () { Navigator.pop(context); onEditar(); },
              ),
              ListTile(
                leading: Icon(Icons.copy_outlined, color: cs.secondary),
                title: const Text('Duplicar gasto'),
                subtitle: const Text('Abre el formulario con los mismos datos'),
                onTap: () { Navigator.pop(context); onDuplicar(); },
              ),
              ListTile(
                leading: Icon(Icons.delete_outline, color: cs.error),
                title: Text('Eliminar', style: TextStyle(color: cs.error)),
                subtitle: gasto.esCuotado
                    ? const Text('Se eliminarán todas las cuotas')
                    : null,
                onTap: () { Navigator.pop(context); onEliminar(); },
              ),
            ],
          ),
        ),
      ),
    );
  }


  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final color = gasto.categoria != null
        ? _hexColor(gasto.categoria!.color)
        : cs.primary;

    return Dismissible(
      key: Key('gasto-${gasto.id}'),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: cs.error,
          borderRadius: BorderRadius.circular(14),
        ),
        child: const Icon(Icons.delete_outline, color: Colors.white),
      ),
      confirmDismiss: (_) async {
        onEliminar();
        return false; // el provider maneja la eliminación
      },
      child: Card(
        margin: const EdgeInsets.only(bottom: 10),
        child: InkWell(
          onTap: onEditar,
          onLongPress: () => _mostrarOpciones(context),
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                // Ícono categoría
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: Text(
                        Iconos.toEmoji(gasto.categoria?.icono ?? ''),
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 22, height: 1.0),
                      ),
                  ),
                ),
                const SizedBox(width: 12),

                // Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        gasto.descripcion ?? gasto.categoria?.nombre ?? 'Gasto',
                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          Icon(Icons.calendar_today_outlined, size: 12, color: cs.outline),
                          const SizedBox(width: 3),
                          Text(Formato.fechaCorta(gasto.fecha),
                              style: TextStyle(fontSize: 12, color: cs.outline)),
                          const SizedBox(width: 8),
                          Icon(
                            Iconos.mapa[gasto.medioPago?.icono] ?? Icons.payment,
                            size: 12,
                            color: cs.outline,
                          ),
                          const SizedBox(width: 3),
                          Flexible(
                            child: Text(
                              gasto.medioPago?.nombre ?? '',
                              style: TextStyle(fontSize: 12, color: cs.outline),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),

                // Monto + badges
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      Formato.moneda(gasto.valorCuota),
                      style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: cs.onSurface),
                    ),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 4,
                      runSpacing: 4,
                      alignment: WrapAlignment.end,
                      children: [
                        if (gasto.esCuotado)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: cs.primaryContainer,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              'C${gasto.cuotaNumero}/${gasto.cuotasTotal}',
                              style: TextStyle(fontSize: 10, color: cs.primary, fontWeight: FontWeight.w600),
                            ),
                          ),
                        if (gasto.esCompartido)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: cs.secondaryContainer,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text('Compartido',
                                style: TextStyle(fontSize: 10,
                                    color: cs.onSecondaryContainer, fontWeight: FontWeight.w600)),
                          ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _EstadoVacio extends StatelessWidget {
  final bool hayFiltros;
  const _EstadoVacio({required this.hayFiltros});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.receipt_long_outlined, size: 64, color: cs.outlineVariant),
          const SizedBox(height: 16),
          Text(
            hayFiltros
                ? 'Sin gastos con esos filtros'
                : 'Sin gastos este mes',
            style: TextStyle(color: cs.outline, fontSize: 16),
          ),
          const SizedBox(height: 8),
          Text(
            hayFiltros
                ? 'Prueba cambiando los filtros'
                : 'Toca + para registrar el primero',
            style: TextStyle(color: cs.outlineVariant, fontSize: 13),
          ),
        ],
      ),
    );
  }
}

class _FiltroChip extends StatelessWidget {
  final String label;
  final bool sel;
  final VoidCallback onTap;

  const _FiltroChip({required this.label, required this.sel, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: sel ? cs.primaryContainer : cs.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color: sel ? cs.primary : Colors.transparent, width: 1.5),
        ),
        child: Text(label,
            style: TextStyle(
                fontSize: 13,
                fontWeight: sel ? FontWeight.bold : FontWeight.normal,
                color: sel ? cs.primary : cs.outline)),
      ),
    );
  }
}

// ─── Botón filtro fijo/variable ───────────────────────────────────────────────

class _BtnFiltroGasto extends StatelessWidget {
  final String label;
  final bool activo;
  final VoidCallback onTap;
  final ColorScheme cs;
  final Color? colorActivo;

  const _BtnFiltroGasto({
    required this.label,
    required this.activo,
    required this.onTap,
    required this.cs,
    this.colorActivo,
  });

  @override
  Widget build(BuildContext context) {
    final color = colorActivo ?? cs.primary;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: activo ? color.withOpacity(0.15) : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
              color: activo ? color : Colors.transparent, width: 1.5),
        ),
        child: Text(label,
            style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: activo ? color : cs.outline)),
      ),
    );
  }
}
