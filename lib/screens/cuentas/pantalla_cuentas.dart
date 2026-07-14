import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:misgastos/models/cuenta.dart';
import 'package:misgastos/models/gasto.dart';
import 'package:misgastos/utils/iconos.dart';
import 'package:misgastos/providers/gastos_provider.dart';
import 'package:misgastos/utils/formato.dart';

class PantallaCuentas extends StatefulWidget {
  const PantallaCuentas({super.key});

  @override
  State<PantallaCuentas> createState() => _PantallaCuentasState();
}

class _PantallaCuentasState extends State<PantallaCuentas> {
  // Gastos del mes actual descontados de cada cuenta
  Map<int, double> _gastadoPorCuenta = {};
  bool _cargando = false;

  static const _coloresCuenta = [
    // Azules
    '#0288D1', '#1565C0', '#0097A7', '#00838F',
    // Verdes
    '#388E3C', '#2E7D32', '#558B2F', '#A8E063',
    // Naranjas / Rojos
    '#F57C00', '#E64A19', '#C62828', '#AD1457',
    // Morados
    '#7B1FA2', '#6A1B9A', '#4527A0', '#283593',
    // Grises / Neutros
    '#455A64', '#37474F', '#4E342E', '#BF360C',
    // Colores vivos
    '#00897B', '#F9A825', '#6D4C41', '#546E7A',
  ];

  static const _iconosCuenta = [
    'account_balance', 'savings', 'credit_card',
    'account_balance_wallet', 'monetization_on',
  ];

  static Color _hex(String hex) =>
      Color(int.parse('FF${hex.replaceAll('#', '')}', radix: 16));

  static const _mapaIconos = {
    'account_balance': Icons.account_balance,
    'savings': Icons.savings,
    'credit_card': Icons.credit_card,
    'account_balance_wallet': Icons.account_balance_wallet,
    'monetization_on': Icons.monetization_on,
  };

  @override
  void initState() {
    super.initState();
    _cargarGastados();
  }

  Future<void> _cargarGastados() async {
    setState(() => _cargando = true);
    final provider = context.read<GastosProvider>();
    final hoy = DateTime.now();
    final desde = DateTime(hoy.year, hoy.month, 1);
    final hasta = DateTime(hoy.year, hoy.month + 1, 0, 23, 59, 59);

    // Para cada cuenta, buscar el medio de pago con el mismo nombre
    // y sumar los gastos del mes
    final mapa = <int, double>{};
    for (final cuenta in provider.cuentas) {
      // Buscar medio de pago asociado por nombre similar
      final medio = provider.mediosPago.where((m) =>
        m.nombre.toLowerCase().contains(cuenta.nombre.toLowerCase()) ||
        cuenta.nombre.toLowerCase().contains(m.nombre.toLowerCase())
      ).firstOrNull;

      if (medio != null && medio.id != null) {
        final gastado = await provider.db
            .getGastadoPorMedioPago(medio.id!, desde, hasta);
        mapa[cuenta.id!] = gastado;
      } else {
        mapa[cuenta.id!] = 0;
      }
    }

    if (mounted) setState(() { _gastadoPorCuenta = mapa; _cargando = false; });
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<GastosProvider>();
    final cs = Theme.of(context).colorScheme;
    final cuentas = provider.cuentas;

    final totalSaldo = cuentas.fold(0.0, (s, c) => s + c.saldoInicial);
    final totalGastado = _gastadoPorCuenta.values.fold(0.0, (s, v) => s + v);
    final disponibleReal = totalSaldo - totalGastado;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mis Cuentas'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _cargarGastados,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _mostrarDialogo(context, provider),
        icon: const Icon(Icons.add),
        label: const Text('Nueva cuenta'),
      ),
      body: _cargando
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _cargarGastados,
              child: cuentas.isEmpty
                  ? _EstadoVacio(onAgregar: () => _mostrarDialogo(context, provider))
                  : ListView(
                      padding: const EdgeInsets.all(16),
                      children: [

                        // ── Banner resumen ──────────────────────────────
                        _BannerResumen(
                          totalSaldo: totalSaldo,
                          totalGastado: totalGastado,
                          disponibleReal: disponibleReal,
                        ),
                        const SizedBox(height: 20),

                        // ── Lista de cuentas ────────────────────────────
                        Text('Cuentas corrientes',
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.bold)),
                        const SizedBox(height: 12),

                        ...cuentas.map((cuenta) {
                          final gastado = _gastadoPorCuenta[cuenta.id] ?? 0;
                          final disponible = cuenta.saldoInicial - gastado;
                          final pct = cuenta.saldoInicial > 0
                              ? (gastado / cuenta.saldoInicial).clamp(0.0, 1.0)
                              : 0.0;
                          final color = _hex(cuenta.color);

                          return _TarjetaCuenta(
                            cuenta: cuenta,
                            gastado: gastado,
                            disponible: disponible,
                            porcentajeGastado: pct,
                            color: color,
                            icono: _mapaIconos[cuenta.icono] ?? Icons.account_balance,
                            onEditar: () => _mostrarDialogo(context, provider, cuenta),
                            onActualizarSaldo: () => _mostrarActualizarSaldo(context, provider, cuenta),
                            onEliminar: () => _confirmarEliminar(context, provider, cuenta),
                          );
                        }),

                        const SizedBox(height: 80),
                      ],
                    ),
            ),
    );
  }

  void _mostrarDialogo(BuildContext context, GastosProvider provider, [Cuenta? cuenta]) {
    final nombreCtrl = TextEditingController(text: cuenta?.nombre ?? '');
    final saldoCtrl = TextEditingController(
        text: cuenta != null ? cuenta.saldoInicial.toStringAsFixed(0) : '');
    String colorSel = cuenta?.color ?? '#0288D1';
    String iconoSel = cuenta?.icono ?? 'account_balance';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: Text(cuenta == null ? 'Nueva cuenta' : 'Editar cuenta'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: nombreCtrl,
                  autofocus: true,
                  decoration: const InputDecoration(
                    labelText: 'Nombre del banco',
                    hintText: 'Ej: Banco Chile, Itaú...',
                    prefixIcon: Icon(Icons.account_balance),
                  ),
                  textCapitalization: TextCapitalization.words,
                ),

                const SizedBox(height: 12),
                TextField(
                  controller: saldoCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Saldo actual',
                    hintText: '0',
                    prefixText: '\$ ',
                    prefixIcon: Icon(Icons.attach_money),
                  ),
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    _MontoFormatter(),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    const Text('Color', style: TextStyle(fontWeight: FontWeight.w600)),
                    const SizedBox(width: 8),
                    Container(
                      width: 20, height: 20,
                      decoration: BoxDecoration(
                        color: _hex(colorSel),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                        boxShadow: [BoxShadow(color: _hex(colorSel).withOpacity(0.4), blurRadius: 4)],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 6,
                    mainAxisSpacing: 10,
                    crossAxisSpacing: 10,
                    childAspectRatio: 1,
                  ),
                  itemCount: _coloresCuenta.length,
                  itemBuilder: (ctx, i) {
                    final hex = _coloresCuenta[i];
                    final color = _hex(hex);
                    final sel = colorSel == hex;
                    return GestureDetector(
                      onTap: () => setState(() => colorSel = hex),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 120),
                        decoration: BoxDecoration(
                          color: color,
                          shape: BoxShape.circle,
                          border: sel ? Border.all(
                            color: Theme.of(context).colorScheme.outline,
                            width: 3,
                          ) : Border.all(color: Colors.transparent),
                          boxShadow: sel ? [
                            BoxShadow(color: color.withOpacity(0.5), blurRadius: 6)
                          ] : null,
                        ),
                        child: sel
                            ? const Icon(Icons.check, color: Colors.white, size: 16)
                            : null,
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () async {
                final nombre = nombreCtrl.text.trim();
                if (nombre.isEmpty) return;
                final saldoStr = saldoCtrl.text.replaceAll('.', '');
                final saldo = double.tryParse(saldoStr) ?? 0;

                final nueva = Cuenta(
                  id: cuenta?.id,
                  nombre: nombre,
                  numero: null,
                  icono: iconoSel,
                  color: colorSel,
                  saldoInicial: saldo,
                  fechaSaldo: DateTime.now(),
                );

                if (cuenta == null) {
                  await provider.agregarCuenta(nueva);
                } else {
                  await provider.editarCuenta(nueva);
                }
                if (ctx.mounted) Navigator.pop(ctx);
                _cargarGastados();
              },
              child: Text(cuenta == null ? 'Agregar' : 'Guardar'),
            ),
          ],
        ),
      ),
    );
  }

  void _mostrarActualizarSaldo(BuildContext context, GastosProvider provider, Cuenta cuenta) {
    final saldoCtrl = TextEditingController(
        text: cuenta.saldoInicial.toStringAsFixed(0));

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Actualizar saldo\n${cuenta.nombre}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Ingresa el saldo actual de tu cuenta',
              style: TextStyle(color: Theme.of(context).colorScheme.outline, fontSize: 13),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: saldoCtrl,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Saldo actual',
                prefixText: '\$ ',
                prefixIcon: Icon(Icons.attach_money),
              ),
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                _MontoFormatter(),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Última actualización: ${Formato.fechaLarga(cuenta.fechaSaldo)}',
              style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.outline),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () async {
              final saldoStr = saldoCtrl.text.replaceAll('.', '');
              final saldo = double.tryParse(saldoStr) ?? 0;
              await provider.editarCuenta(cuenta.copyWith(
                saldoInicial: saldo,
                fechaSaldo: DateTime.now(),
              ));
              if (ctx.mounted) Navigator.pop(ctx);
              _cargarGastados();
            },
            child: const Text('Actualizar'),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmarEliminar(BuildContext context, GastosProvider provider, Cuenta cuenta) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('¿Eliminar cuenta?'),
        content: Text('¿Eliminar "${cuenta.nombre}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (ok == true && cuenta.id != null) {
      await provider.eliminarCuenta(cuenta.id!);
    }
  }
}

// ─── Banner resumen ───────────────────────────────────────────────────────────

class _BannerResumen extends StatelessWidget {
  final double totalSaldo;
  final double totalGastado;
  final double disponibleReal;

  const _BannerResumen({
    required this.totalSaldo,
    required this.totalGastado,
    required this.disponibleReal,
  });

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
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Saldo total en cuentas',
              style: TextStyle(color: Colors.white70, fontSize: 13)),
          const SizedBox(height: 4),
          Text(
            Formato.moneda(totalSaldo),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 30,
              fontWeight: FontWeight.w900,
              letterSpacing: -1,
            ),
          ),
          const SizedBox(height: 14),
          Container(
            height: 1,
            color: Colors.white24,
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _BannerItem(
                  label: 'Gastado este mes',
                  valor: Formato.moneda(totalGastado),
                  valorColor: const Color(0xFFFFCDD2),
                  icono: Icons.trending_down,
                ),
              ),
              Container(width: 1, height: 40, color: Colors.white24),
              Expanded(
                child: _BannerItem(
                  label: 'Disponible real',
                  valor: Formato.moneda(disponibleReal),
                  valorColor: disponibleReal >= 0
                      ? const Color(0xFFB9F6CA)
                      : const Color(0xFFFFCDD2),
                  icono: Icons.account_balance_wallet,
                  alignRight: true,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _BannerItem extends StatelessWidget {
  final String label;
  final String valor;
  final Color valorColor;
  final IconData icono;
  final bool alignRight;

  const _BannerItem({
    required this.label,
    required this.valor,
    required this.valorColor,
    required this.icono,
    this.alignRight = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: alignRight ? 16 : 0,
        right: alignRight ? 0 : 16,
      ),
      child: Column(
        crossAxisAlignment:
            alignRight ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment:
                alignRight ? MainAxisAlignment.end : MainAxisAlignment.start,
            children: [
              if (!alignRight) Icon(icono, color: Colors.white54, size: 14),
              if (!alignRight) const SizedBox(width: 4),
              Text(label,
                  style: const TextStyle(color: Colors.white70, fontSize: 11)),
              if (alignRight) const SizedBox(width: 4),
              if (alignRight) Icon(icono, color: Colors.white54, size: 14),
            ],
          ),
          const SizedBox(height: 3),
          Text(valor,
              style: TextStyle(
                color: valorColor,
                fontSize: 16,
                fontWeight: FontWeight.w800,
              )),
        ],
      ),
    );
  }
}

// ─── Tarjeta de cuenta ───────────────────────────────────────────────────────

class _TarjetaCuenta extends StatelessWidget {
  final Cuenta cuenta;
  final double gastado;
  final double disponible;
  final double porcentajeGastado;
  final Color color;
  final IconData icono;
  final VoidCallback onEditar;
  final VoidCallback onActualizarSaldo;
  final VoidCallback onEliminar;

  const _TarjetaCuenta({
    required this.cuenta,
    required this.gastado,
    required this.disponible,
    required this.porcentajeGastado,
    required this.color,
    required this.icono,
    required this.onEditar,
    required this.onActualizarSaldo,
    required this.onEliminar,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final esBajo = porcentajeGastado > 0.7;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: esBajo
              ? cs.error.withOpacity(0.3)
              : color.withOpacity(0.2),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.06),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // ── Cabecera ────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 48, height: 48,
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(icono, color: color, size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(cuenta.nombre,
                          style: const TextStyle(
                              fontWeight: FontWeight.w800, fontSize: 16)),
                      if (cuenta.numero != null)
                        Text('**** ${cuenta.numero}',
                            style: TextStyle(
                                fontSize: 12, color: cs.outline)),
                      Text(
                        'Actualizado: ${Formato.fechaCorta(cuenta.fechaSaldo)}',
                        style: TextStyle(fontSize: 11, color: cs.outlineVariant),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      Formato.moneda(cuenta.saldoInicial),
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        color: color,
                      ),
                    ),
                    Text('saldo ingresado',
                        style: TextStyle(fontSize: 10, color: cs.outline)),
                  ],
                ),
              ],
            ),
          ),

          // ── Barra de uso ────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
            child: Column(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: porcentajeGastado,
                    minHeight: 8,
                    backgroundColor: cs.surfaceContainerHighest,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      esBajo ? cs.error : color,
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Gastado: ${Formato.moneda(gastado)}',
                      style: TextStyle(
                        fontSize: 11,
                        color: esBajo ? cs.error : cs.outline,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      'Disponible: ${Formato.moneda(disponible)}',
                      style: TextStyle(
                        fontSize: 11,
                        color: disponible >= 0
                            ? const Color(0xFF2E7D32)
                            : cs.error,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // ── Botones de acción ───────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onActualizarSaldo,
                    icon: const Icon(Icons.edit, size: 16),
                    label: const Text('Actualizar saldo',
                        style: TextStyle(fontSize: 12)),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: color,
                      side: BorderSide(color: color.withOpacity(0.4)),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                      padding: const EdgeInsets.symmetric(vertical: 8),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: onEditar,
                  icon: const Icon(Icons.settings_outlined, size: 20),
                  color: cs.outline,
                  tooltip: 'Editar cuenta',
                ),
                IconButton(
                  onPressed: onEliminar,
                  icon: const Icon(Icons.delete_outline, size: 20),
                  color: cs.error,
                  tooltip: 'Eliminar cuenta',
                ),
              ],
            ),
          ),
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
          Icon(Icons.account_balance_outlined, size: 72, color: cs.outlineVariant),
          const SizedBox(height: 16),
          Text('Sin cuentas registradas',
              style: Theme.of(context).textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text('Agrega tu cuenta corriente para\nver tu saldo disponible',
              textAlign: TextAlign.center,
              style: TextStyle(color: cs.outline)),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: onAgregar,
            icon: const Icon(Icons.add),
            label: const Text('Agregar cuenta'),
          ),
        ],
      ),
    );
  }
}

// ─── Formateador monto ────────────────────────────────────────────────────────

class _MontoFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue old, TextEditingValue nv) {
    final digits = nv.text.replaceAll('.', '');
    if (digits.isEmpty) return nv.copyWith(text: '');
    final number = int.tryParse(digits) ?? 0;
    final formatted = number.toString().replaceAllMapped(
        RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (m) => '${m[1]}.');
    return nv.copyWith(
        text: formatted,
        selection: TextSelection.collapsed(offset: formatted.length));
  }
}

// ─── Últimos gastos de la cuenta (expandible) ────────────────────────────────

class _UltimosGastosCuenta extends StatefulWidget {
  final Cuenta cuenta;
  final Color color;

  const _UltimosGastosCuenta({required this.cuenta, required this.color});

  @override
  State<_UltimosGastosCuenta> createState() => _UltimosGastosCuentaState();
}

class _UltimosGastosCuentaState extends State<_UltimosGastosCuenta> {
  bool _expandido = false;
  List<Gasto> _gastos = [];
  bool _cargando = false;

  static Color _hexColor(String hex) {
    final h = hex.replaceAll('#', '');
    return Color(int.parse('FF$h', radix: 16));
  }

  Future<void> _cargarGastos() async {
    if (_cargando) return;
    setState(() => _cargando = true);
    final provider = context.read<GastosProvider>();

    // Buscar medio de pago asociado por nombre
    final medio = provider.mediosPago.where((m) =>
      m.nombre.toLowerCase().contains(widget.cuenta.nombre.toLowerCase()) ||
      widget.cuenta.nombre.toLowerCase().contains(m.nombre.toLowerCase())
    ).firstOrNull;

    List<Gasto> gastos = [];
    if (medio != null && medio.id != null) {
      final todos = await provider.db.getAllGastos();
      gastos = todos
          .where((g) => g.idMedioPago == medio.id)
          .take(5)
          .toList();
    }

    if (mounted) setState(() { _gastos = gastos; _cargando = false; });
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Column(
      children: [
        // Botón expandir
        InkWell(
          onTap: () {
            setState(() => _expandido = !_expandido);
            if (_expandido && _gastos.isEmpty) _cargarGastos();
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: _expandido
                  ? widget.color.withOpacity(0.06)
                  : Colors.transparent,
              border: Border(
                top: BorderSide(color: cs.outline.withOpacity(0.1)),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  _expandido
                      ? Icons.keyboard_arrow_up
                      : Icons.keyboard_arrow_down,
                  color: widget.color,
                  size: 18,
                ),
                const SizedBox(width: 6),
                Text(
                  _expandido ? 'Ocultar gastos' : 'Ver últimos 5 gastos',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: widget.color,
                  ),
                ),
              ],
            ),
          ),
        ),

        // Lista de gastos
        if (_expandido)
          _cargando
              ? Padding(
                  padding: const EdgeInsets.all(16),
                  child: Center(
                    child: SizedBox(
                      width: 24, height: 24,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: widget.color),
                    ),
                  ),
                )
              : _gastos.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(
                        'Sin gastos registrados con esta cuenta',
                        style: TextStyle(fontSize: 12, color: cs.outline),
                        textAlign: TextAlign.center,
                      ),
                    )
                  : Column(
                      children: _gastos.map((g) {
                        final color = g.categoria != null
                            ? _hexColor(g.categoria!.color)
                            : cs.primary;
                        return Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 10),
                          decoration: BoxDecoration(
                            border: Border(
                              top: BorderSide(
                                  color: cs.outline.withOpacity(0.06)),
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 34, height: 34,
                                decoration: BoxDecoration(
                                  color: color.withOpacity(0.12),
                                  borderRadius: BorderRadius.circular(9),
                                ),
                                child: Icon(
                                  Iconos.mapa[g.categoria?.icono] ??
                                      Icons.receipt_outlined,
                                  color: color, size: 16,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      g.descripcion ??
                                          g.categoria?.nombre ?? 'Gasto',
                                      style: const TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    Text(
                                      Formato.fechaCorta(g.fecha),
                                      style: TextStyle(
                                          fontSize: 11, color: cs.outline),
                                    ),
                                  ],
                                ),
                              ),
                              Text(
                                Formato.moneda(g.valorCuota),
                                style: const TextStyle(
                                    fontSize: 13, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
      ],
    );
  }
}
