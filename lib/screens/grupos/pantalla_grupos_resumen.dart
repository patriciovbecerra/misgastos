import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:misgastos/models/gasto.dart';
import 'package:misgastos/models/grupo.dart';
import 'package:misgastos/models/participante.dart';
import 'package:misgastos/providers/gastos_provider.dart';
import 'package:misgastos/utils/formato.dart';
import 'package:misgastos/utils/iconos.dart';
import 'pantalla_todos_gastos_grupo.dart';
import 'package:misgastos/models/medio_pago.dart';

class PantallaGruposResumen extends StatefulWidget {
  const PantallaGruposResumen({super.key});
  @override
  State<PantallaGruposResumen> createState() => _PantallaGruposResumenState();
}

class _PantallaGruposResumenState extends State<PantallaGruposResumen> {
  // grupoId → {gastos, participantes}
  Map<int, List<Gasto>> _gastosPorGrupo = {};
  Map<int, List<Gasto>> _gastosSiguientePorGrupo = {};
  Map<int, List<Participante>> _participantesPorGrupo = {};
  bool _cargando = true;

  @override
  void initState() {
    super.initState();
    _cargarDatos();
  }

  Future<void> _cargarDatos() async {
    setState(() => _cargando = true);
    final provider = context.read<GastosProvider>();
    final todos = await provider.db.getAllGastos();
    final periodosGuardados = await provider.db.getPeriodosFacturacion();
    final hoy = DateTime.now();

    // Construir períodos actual y siguiente por medio de pago
    Map<int, Map<String, DateTime>> periodosActual = {};
    Map<int, Map<String, DateTime>> periodosSiguiente = {};

    for (final medio in provider.mediosPago) {
      if (medio.id == null) continue;
      if (medio.diaCierre != null) {
        final cierre = medio.diaCierre!;
        // Período actual
        final desdeA = hoy.day <= cierre
            ? DateTime(hoy.year, hoy.month - 1, cierre + 1)
            : DateTime(hoy.year, hoy.month, cierre + 1);
        final hastaA = hoy.day <= cierre
            ? DateTime(hoy.year, hoy.month, cierre)
            : DateTime(hoy.year, hoy.month + 1, cierre);
        // Período siguiente (un mes después)
        final desdeS = DateTime(hastaA.year, hastaA.month, hastaA.day + 1);
        final hastaS = DateTime(hastaA.year, hastaA.month + 1, cierre);
        periodosActual[medio.id!] = {'desde': desdeA, 'hasta': hastaA};
        periodosSiguiente[medio.id!] = {'desde': desdeS, 'hasta': hastaS};
      } else if (periodosGuardados.containsKey(medio.id)) {
        final p = periodosGuardados[medio.id]!;
        periodosActual[medio.id!] = p;
        final desdeS = DateTime(p['hasta']!.year, p['hasta']!.month + 1, 1);
        final hastaS = DateTime(p['hasta']!.year, p['hasta']!.month + 2, 0);
        periodosSiguiente[medio.id!] = {'desde': desdeS, 'hasta': hastaS};
      } else {
        periodosActual[medio.id!] = {
          'desde': DateTime(hoy.year, hoy.month, 1),
          'hasta': DateTime(hoy.year, hoy.month + 1, 0),
        };
        periodosSiguiente[medio.id!] = {
          'desde': DateTime(hoy.year, hoy.month + 1, 1),
          'hasta': DateTime(hoy.year, hoy.month + 2, 0),
        };
      }
    }

    bool _enPeriodo(Gasto g, Map<int, Map<String, DateTime>> periodos) {
      final p = periodos[g.idMedioPago];
      if (p == null) return false;
      final desde = p['desde']!;
      final hasta = DateTime(p['hasta']!.year, p['hasta']!.month, p['hasta']!.day, 23, 59, 59);
      return !g.fecha.isBefore(desde) && !g.fecha.isAfter(hasta);
    }

    final gastosActual = <int, List<Gasto>>{};
    final gastosSiguiente = <int, List<Gasto>>{};

    for (final g in todos) {
      if (g.idGrupo == null || !g.esCompartido) continue;
      if (_enPeriodo(g, periodosActual)) {
        gastosActual.putIfAbsent(g.idGrupo!, () => []).add(g);
      }
      if (_enPeriodo(g, periodosSiguiente)) {
        gastosSiguiente.putIfAbsent(g.idGrupo!, () => []).add(g);
      }
    }

    for (final list in gastosActual.values) {
      list.sort((a, b) => b.fecha.compareTo(a.fecha));
    }
    for (final list in gastosSiguiente.values) {
      list.sort((a, b) => b.fecha.compareTo(a.fecha));
    }

    final participantes = <int, List<Participante>>{};
    for (final grupo in provider.grupos) {
      if (grupo.id != null) {
        participantes[grupo.id!] =
            await provider.db.getParticipantesByGrupo(grupo.id!);
      }
    }

    if (mounted) {
      setState(() {
        _gastosPorGrupo = gastosActual;
        _gastosSiguientePorGrupo = gastosSiguiente;
        _participantesPorGrupo = participantes;
        _cargando = false;
      });
    }
  }

  void _abrirFormularioGrupo([Grupo? grupo]) {
    final nombreCtrl = TextEditingController(text: grupo?.nombre ?? '');
    final descCtrl = TextEditingController(text: grupo?.descripcion ?? '');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          left: 20, right: 20, top: 16,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 40, height: 4,
                decoration: BoxDecoration(color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 16),
            Text(grupo == null ? 'Nuevo grupo' : 'Editar grupo',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
            const SizedBox(height: 16),
            TextField(
              controller: nombreCtrl,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Nombre del grupo',
                prefixIcon: Icon(Icons.group),
              ),
              textCapitalization: TextCapitalization.words,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: descCtrl,
              decoration: const InputDecoration(
                labelText: 'Descripción (opcional)',
                prefixIcon: Icon(Icons.notes),
              ),
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
                onPressed: () async {
                  final nombre = nombreCtrl.text.trim();
                  if (nombre.isEmpty) return;
                  final provider = context.read<GastosProvider>();
                  if (grupo == null) {
                    await provider.agregarGrupo(
                        Grupo(nombre: nombre, descripcion: descCtrl.text.trim()));
                  } else {
                    await provider.editarGrupo(
                        grupo.copyWith(nombre: nombre, descripcion: descCtrl.text.trim()));
                  }
                  if (ctx.mounted) Navigator.pop(ctx);
                  _cargarDatos();
                },
                style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12))),
                child: Text(grupo == null ? 'Crear grupo' : 'Guardar'),
              )),
            ]),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<GastosProvider>();
    final cs = Theme.of(context).colorScheme;
    final grupos = provider.grupos;

    return Scaffold(
      appBar: AppBar(title: const Text('Grupos')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _abrirFormularioGrupo(),
        icon: const Icon(Icons.add),
        label: const Text('Nuevo grupo'),
      ),
      body: _cargando
          ? const Center(child: CircularProgressIndicator())
          : grupos.isEmpty
              ? _EstadoVacio(onAgregar: () => _abrirFormularioGrupo())
              : RefreshIndicator(
                  onRefresh: _cargarDatos,
                  child: ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                    itemCount: grupos.length,
                    itemBuilder: (ctx, i) {
                      final grupo = grupos[i];
                      final gastos = _gastosPorGrupo[grupo.id] ?? [];
                      final participantes =
                          _participantesPorGrupo[grupo.id] ?? [];
                      final total =
                          gastos.fold(0.0, (s, g) => s + g.valorCuota);
                      return _TarjetaGrupo(
                        grupo: grupo,
                        gastos: gastos,
                        gastosSiguiente: _gastosSiguientePorGrupo[grupo.id] ?? [],
                        participantes: participantes,
                        total: total,
                        onEditar: () => _abrirFormularioGrupo(grupo),
                        onEliminar: () => _confirmarEliminar(grupo),
                        onVerTodos: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => PantallaTodosGastosGrupo(
                              grupo: grupo,
                              gastosPrecargados: _gastosPorGrupo[grupo.id] ?? [],
                              participantes: _participantesPorGrupo[grupo.id] ?? [],
                            ),
                          ),
                        ).then((_) => _cargarDatos()),
                      );
                    },
                  ),
                ),
    );
  }

  Future<void> _confirmarEliminar(Grupo grupo) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('¿Eliminar grupo?'),
        content: Text('Se eliminará "${grupo.nombre}". Los gastos no se borran.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar')),
          FilledButton(
            style: FilledButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (ok == true && grupo.id != null) {
      await context.read<GastosProvider>().eliminarGrupo(grupo.id!);
      _cargarDatos();
    }
  }
}

// ─── Tarjeta de grupo ─────────────────────────────────────────────────────────

class _TarjetaGrupo extends StatelessWidget {
  final Grupo grupo;
  final List<Gasto> gastos;
  final List<Gasto> gastosSiguiente;
  final List<Participante> participantes;
  final double total;
  final VoidCallback onEditar;
  final VoidCallback onEliminar;
  final VoidCallback onVerTodos;

  const _TarjetaGrupo({
    required this.grupo,
    required this.gastos,
    required this.gastosSiguiente,
    required this.participantes,
    required this.total,
    required this.onEditar,
    required this.onEliminar,
    required this.onVerTodos,
  });

  static Color _hex(String hex) =>
      Color(int.parse('FF${hex.replaceAll('#', '')}', radix: 16));

  double get _porPersona => participantes.isEmpty
      ? 0
      : total / participantes.length; // total ya es suma de valorCuota

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final ultimos5 = gastos.length > 5 ? gastos.sublist(0, 5) : gastos;
    final hayMas = gastos.length > 5;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: cs.outline.withOpacity(0.12), width: 1.5),
        boxShadow: [BoxShadow(
            color: cs.shadow.withOpacity(0.05),
            blurRadius: 10, offset: const Offset(0, 3))],
      ),
      child: Column(
        children: [

          // ── Cabecera ─────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Row(
                  children: [
                    Container(
                      width: 46, height: 46,
                      decoration: BoxDecoration(
                        color: cs.primaryContainer,
                        borderRadius: BorderRadius.circular(13),
                      ),
                      child: Icon(Icons.group, color: cs.primary, size: 22),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(grupo.nombre,
                              style: const TextStyle(
                                  fontSize: 17, fontWeight: FontWeight.w800)),
                          if (grupo.descripcion != null &&
                              grupo.descripcion!.isNotEmpty)
                            Text(grupo.descripcion!,
                                style: TextStyle(
                                    fontSize: 12, color: cs.outline)),
                        ],
                      ),
                    ),
                    IconButton(
                        onPressed: onEditar,
                        icon: Icon(Icons.edit_outlined,
                            size: 18, color: cs.outline)),
                    IconButton(
                        onPressed: onEliminar,
                        icon: Icon(Icons.delete_outline,
                            size: 18, color: cs.error)),
                  ],
                ),

                const SizedBox(height: 12),

                // ── Resumen financiero ────────────────────────
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: cs.primaryContainer.withOpacity(0.4),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Total del grupo',
                                style: TextStyle(
                                    fontSize: 11, color: cs.outline)),
                            Text(Formato.moneda(total),
                                style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w900,
                                    color: cs.primary)),
                          ],
                        ),
                      ),
                      if (participantes.isNotEmpty) ...[
                        Container(
                            width: 1, height: 36,
                            color: cs.outline.withOpacity(0.2),
                            margin: const EdgeInsets.symmetric(horizontal: 12)),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text('Por persona',
                                style: TextStyle(
                                    fontSize: 11, color: cs.outline)),
                            Text(Formato.moneda(_porPersona),
                                style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w800,
                                    color: cs.secondary)),
                            Text(
                                '${participantes.length} participantes',
                                style: TextStyle(
                                    fontSize: 10, color: cs.outline)),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),

                // ── Participantes horizontal ─────────────────
                if (participantes.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: participantes.map((p) => Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircleAvatar(
                          radius: 13,
                          backgroundColor: cs.secondaryContainer,
                          child: Text(
                            p.nombre.isNotEmpty ? p.nombre[0].toUpperCase() : '?',
                            style: TextStyle(fontSize: 11,
                                fontWeight: FontWeight.bold, color: cs.secondary),
                          ),
                        ),
                        const SizedBox(width: 5),
                        Text(p.nombre.split(' ').first,
                            style: const TextStyle(
                                fontSize: 13, fontWeight: FontWeight.w600)),
                      ],
                    )).toList(),
                  ),
                ],
              ],
            ),
          ),

          // ── Gastos período de facturación ────────────────────
          if (gastos.isNotEmpty) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: cs.primaryContainer.withOpacity(0.3),
                border: Border(
                    top: BorderSide(color: cs.outline.withOpacity(0.1))),
              ),
              child: Row(
                children: [
                  Icon(Icons.credit_card_outlined, size: 13, color: cs.primary),
                  const SizedBox(width: 6),
                  Text('Período de facturación',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700,
                          color: cs.primary, letterSpacing: 0.5)),
                  const Spacer(),
                  Text(Formato.moneda(total),
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800,
                          color: cs.primary)),
                ],
              ),
            ),
            ...ultimos5.map((g) {
              final color = g.categoria != null
                  ? _hex(g.categoria!.color)
                  : cs.primary;
              final porPersona = participantes.isEmpty
                  ? g.valorCuota
                  : g.valorCuota / participantes.length;
              return Container(
                margin: const EdgeInsets.fromLTRB(12, 0, 12, 6),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: cs.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: cs.outline.withOpacity(0.08)),
                ),
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
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            g.descripcion ?? g.categoria?.nombre ?? 'Gasto',
                            style: const TextStyle(
                                fontSize: 13, fontWeight: FontWeight.w600),
                            maxLines: 1, overflow: TextOverflow.ellipsis,
                          ),
                          Text(Formato.fechaCorta(g.fecha),
                              style: TextStyle(fontSize: 11, color: cs.outline)),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(Formato.moneda(g.valorCuota),
                            style: const TextStyle(
                                fontSize: 13, fontWeight: FontWeight.bold)),
                        Text('c/u ${Formato.moneda(porPersona)}',
                            style: TextStyle(fontSize: 10, color: cs.secondary,
                                fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ],
                ),
              );
            }),

            // ── Próximo período ───────────────────────────────
            if (gastosSiguiente.isNotEmpty) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: cs.secondaryContainer.withOpacity(0.4),
                  border: Border(
                    top: BorderSide(color: cs.outline.withOpacity(0.1))),
                ),
                child: Row(
                  children: [
                    Icon(Icons.upcoming_outlined, size: 14, color: cs.secondary),
                    const SizedBox(width: 6),
                    Text('Próximo período',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700,
                            color: cs.secondary, letterSpacing: 0.5)),
                    const Spacer(),
                    Text(
                      Formato.moneda(gastosSiguiente.fold(0.0, (s, g) => s + g.valorCuota)),
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800,
                          color: cs.secondary),
                    ),
                  ],
                ),
              ),
              ...gastosSiguiente.take(3).map((g) {
                final color = g.categoria != null
                    ? _hex(g.categoria!.color)
                    : cs.secondary;
                final porParticipante = participantes.isEmpty
                    ? g.valorCuota
                    : g.valorCuota / participantes.length;
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    border: Border(
                        top: BorderSide(color: cs.outline.withOpacity(0.05))),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 32, height: 32,
                        decoration: BoxDecoration(
                          color: color.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(9),
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
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          g.descripcion ?? g.categoria?.nombre ?? 'Gasto',
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                          maxLines: 1, overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(Formato.moneda(g.valorCuota),
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                          Text('c/u ${Formato.moneda(porParticipante)}',
                              style: TextStyle(fontSize: 10, color: cs.outline)),
                        ],
                      ),
                    ],
                  ),
                );
              }),
            ],

            // ── Botón ver todos ────────────────────────────────
            InkWell(
              onTap: onVerTodos,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: cs.primaryContainer.withOpacity(0.3),
                  border: Border(
                      top: BorderSide(color: cs.outline.withOpacity(0.1))),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.list_alt_outlined,
                        size: 16, color: cs.primary),
                    const SizedBox(width: 6),
                    Text(
                      hayMas
                          ? 'Ver todos los gastos (${gastos.length})'
                          : 'Ver gastos del grupo',
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: cs.primary),
                    ),
                    const SizedBox(width: 4),
                    Icon(Icons.chevron_right, size: 16, color: cs.primary),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ─── Estado vacío ─────────────────────────────────────────────────────────────

class _EstadoVacio extends StatelessWidget {
  final VoidCallback onAgregar;
  const _EstadoVacio({required this.onAgregar});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.group_outlined, size: 72, color: cs.outlineVariant),
          const SizedBox(height: 16),
          Text('Sin grupos creados',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text('Crea un grupo para dividir gastos\ncon amigos o familia',
              textAlign: TextAlign.center,
              style: TextStyle(color: cs.outline)),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: onAgregar,
            icon: const Icon(Icons.add),
            label: const Text('Nuevo grupo'),
          ),
        ],
      ),
    );
  }
}
