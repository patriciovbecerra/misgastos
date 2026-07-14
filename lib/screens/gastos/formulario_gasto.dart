import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:misgastos/models/gasto.dart';
import 'package:misgastos/models/medio_pago.dart';
import 'package:misgastos/models/categoria.dart';
import 'package:misgastos/models/grupo.dart';
import 'package:misgastos/providers/gastos_provider.dart';
import 'package:misgastos/utils/formato.dart';
import 'package:misgastos/utils/iconos.dart';
import 'package:intl/intl.dart';

class FormularioGasto extends StatefulWidget {
  final Gasto? gasto;
  const FormularioGasto({super.key, this.gasto});

  @override
  State<FormularioGasto> createState() => _FormularioGastoState();
}

class _FormularioGastoState extends State<FormularioGasto> {
  final _formKey = GlobalKey<FormState>();
  final _montoCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _cuotasCtrl = TextEditingController(text: '1');

  DateTime _fecha = DateTime.now();
  MedioPago? _medioPago;
  Map<int, int> _frecuenciaMedios = {};
  Categoria? _categoria;
  bool _esCompartido = false;
  Grupo? _grupo;
  bool _esCuotado = false;
  bool _ingresarPorCuota = false;
  int _cuotasYaPagadas = 0;
  bool _guardando = false;

  // Íconos centralizados en Iconos.mapa

  @override
  void initState() {
    super.initState();
    final g = widget.gasto;
    if (g != null) {
      _montoCtrl.text = _formatMonto(g.monto);
      _descCtrl.text = g.descripcion ?? '';
      _fecha = g.fecha;
      _esCompartido = g.esCompartido;
      _esCuotado = g.cuotasTotal > 1;
      _cuotasCtrl.text = g.cuotasTotal.toString();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final provider = context.read<GastosProvider>();
    final g = widget.gasto;
    if (g != null && _medioPago == null) {
      _medioPago = provider.mediosPago.where((m) => m.id == g.idMedioPago).firstOrNull;
      _categoria = provider.categorias.where((c) => c.id == g.idCategoria).firstOrNull;
      if (g.idGrupo != null) {
        _grupo = provider.grupos.where((gr) => gr.id == g.idGrupo).firstOrNull;
      }
    }
  }

  @override
  void dispose() {
    _montoCtrl.dispose();
    _descCtrl.dispose();
    _cuotasCtrl.dispose();
    super.dispose();
  }

  String _formatMonto(double v) {
    return NumberFormat('#,###', 'es_CL').format(v.round()).replaceAll(',', '.');
  }

  int get _cuotas => int.tryParse(_cuotasCtrl.text) ?? 1;

  double get _montoIngresado {
    final digits = _montoCtrl.text.replaceAll('.', '');
    return double.tryParse(digits) ?? 0;
  }

  double get _montoTotal =>
      (_esCuotado && _ingresarPorCuota) ? _montoIngresado * _cuotas : _montoIngresado;

  double get _valorCuota =>
      _esCuotado && _cuotas > 0 ? _montoTotal / _cuotas : _montoTotal;

  Future<void> _guardar() async {
    if (!_formKey.currentState!.validate()) return;
    if (_medioPago == null) { _error('Selecciona un medio de pago'); return; }
    if (_categoria == null) { _error('Selecciona una categoría'); return; }
    if (_esCompartido && _grupo == null) { _error('Selecciona un grupo'); return; }
    if (_esCuotado && _cuotas < 2) { _error('Las cuotas deben ser 2 o más'); return; }

    setState(() => _guardando = true);
    final provider = context.read<GastosProvider>();

    final gasto = Gasto(
      id: widget.gasto?.id,
      monto: _montoTotal,
      valorCuota: _valorCuota,
      cuotasTotal: _esCuotado ? _cuotas : 1,
      cuotaNumero: 1,
      fecha: _fecha,
      fechaCompra: _fecha,
      descripcion: _descCtrl.text.trim().isEmpty ? null : _descCtrl.text.trim(),
      esCompartido: _esCompartido,
      idMedioPago: _medioPago!.id!,
      idCategoria: _categoria!.id!,
      idGrupo: _esCompartido ? _grupo?.id : null,
    );

    bool ok;
    if (widget.gasto == null) {
      ok = await provider.agregarGasto(gasto, cuotasYaPagadas: _cuotasYaPagadas);

    } else {
      ok = await provider.editarGasto(gasto);
    }

    if (mounted) {
      setState(() => _guardando = false);
      if (ok) Navigator.pop(context, true);
      else _error('Error al guardar');
    }
  }

  void _error(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: Theme.of(context).colorScheme.error),
    );
  }

  Future<void> _seleccionarFecha() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _fecha,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),

    );
    if (picked != null) setState(() => _fecha = picked);
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<GastosProvider>();
    final cs = Theme.of(context).colorScheme;
    final esEdicion = widget.gasto != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(esEdicion ? 'Editar gasto' : 'Nuevo gasto'),
        centerTitle: true,
        actions: [
          if (_guardando)
            const Padding(padding: EdgeInsets.all(16),
                child: SizedBox(width: 20, height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2)))
          else
            TextButton.icon(
              onPressed: _guardar,
              icon: const Icon(Icons.check),
              label: const Text('Guardar'),
            ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [

            // ── MONTO ─────────────────────────────────────────────
            _Titulo('Monto'),
            const SizedBox(height: 8),
            TextFormField(
              controller: _montoCtrl,
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                _MontoFormatter(),
              ],
              onChanged: (_) => setState(() {}),
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: cs.primary),
              decoration: InputDecoration(
                prefixText: '\$ ',
                prefixStyle: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: cs.primary),
                hintText: '0',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                filled: true,
                fillColor: cs.primaryContainer.withOpacity(0.3),
                helperText: _esCuotado && _montoIngresado > 0
                    ? _ingresarPorCuota
                        ? 'Total: ${Formato.moneda(_montoTotal)}  ·  Cuota: ${Formato.moneda(_valorCuota)}'
                        : 'Cuota: ${Formato.moneda(_valorCuota)}  ·  Total: ${Formato.moneda(_montoTotal)}'
                    : null,
                helperStyle: TextStyle(color: cs.primary, fontWeight: FontWeight.w600),
              ),
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'Ingresa el monto';
                if (_montoIngresado <= 0) return 'Monto inválido';
                return null;
              },
            ),
            const SizedBox(height: 20),

            // ── CUOTAS ────────────────────────────────────────────
            _Titulo('Cuotas'),
            const SizedBox(height: 8),
            _buildSelectorCuotas(cs),
            const SizedBox(height: 20),

            // ── Cuotas ya pagadas ─────────────────────────────────
            if (_esCuotado && _cuotas > 1) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: cs.surfaceContainerHighest.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: _cuotasYaPagadas > 0
                          ? cs.primary.withOpacity(0.3)
                          : Colors.transparent),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.history, size: 16,
                            color: _cuotasYaPagadas > 0
                                ? cs.primary : cs.outline),
                        const SizedBox(width: 8),
                        Text(
                          '¿Ya pagaste algunas cuotas?',
                          style: TextStyle(
                              fontSize: 13, fontWeight: FontWeight.w600,
                              color: _cuotasYaPagadas > 0
                                  ? cs.primary : cs.onSurface),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        // Botón -
                        IconButton(
                          onPressed: _cuotasYaPagadas > 0
                              ? () => setState(() => _cuotasYaPagadas--)
                              : null,
                          icon: const Icon(Icons.remove_circle_outline),
                          color: cs.primary,
                          iconSize: 28,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                        const SizedBox(width: 16),
                        // Valor
                        Column(
                          children: [
                            Text(
                              '$_cuotasYaPagadas',
                              style: TextStyle(
                                  fontSize: 28, fontWeight: FontWeight.w900,
                                  color: _cuotasYaPagadas > 0
                                      ? cs.primary : cs.outline),
                            ),
                            Text('cuotas pagadas',
                                style: TextStyle(
                                    fontSize: 10, color: cs.outline)),
                          ],
                        ),
                        const SizedBox(width: 16),
                        // Botón +
                        IconButton(
                          onPressed: _cuotasYaPagadas < _cuotas - 1
                              ? () => setState(() => _cuotasYaPagadas++)
                              : null,
                          icon: const Icon(Icons.add_circle_outline),
                          color: cs.primary,
                          iconSize: 28,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                        const Spacer(),
                        // Resumen
                        if (_cuotasYaPagadas > 0)
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                'Quedan ${_cuotas - _cuotasYaPagadas} cuotas',
                                style: TextStyle(
                                    fontSize: 12, fontWeight: FontWeight.w700,
                                    color: cs.primary),
                              ),
                              Text(
                                'Registrando C${_cuotasYaPagadas + 1} a C$_cuotas',
                                style: TextStyle(
                                    fontSize: 11, color: cs.outline),
                              ),
                            ],
                          ),
                      ],
                    ),
                    // Botones rápidos
                    if (_cuotas > 2) ...[
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 6,
                        children: List.generate(
                          (_cuotas - 1).clamp(0, 8),
                          (i) => GestureDetector(
                            onTap: () => setState(
                                () => _cuotasYaPagadas = i + 1),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 120),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: _cuotasYaPagadas == i + 1
                                    ? cs.primaryContainer
                                    : cs.surfaceContainerHighest,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: _cuotasYaPagadas == i + 1
                                      ? cs.primary : Colors.transparent,
                                ),
                              ),
                              child: Text(
                                '${i + 1}',
                                style: TextStyle(
                                    fontSize: 12, fontWeight: FontWeight.w600,
                                    color: _cuotasYaPagadas == i + 1
                                        ? cs.primary : cs.outline),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],

            if (_esCuotado && _cuotas > 1)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  'La cuota 1 se paga en ${Formato.mesAnio(_fecha.month, _fecha.year)}, '
                  'la última (cuota $_cuotas) en ${Formato.mesAnio(_fecha.month + _cuotas - 1 <= 12 ? _fecha.month + _cuotas - 1 : (_fecha.month + _cuotas - 1) % 12, _fecha.month + _cuotas - 1 <= 12 ? _fecha.year : _fecha.year + (_fecha.month + _cuotas - 2) ~/ 12)}',
                  style: TextStyle(fontSize: 11, color: cs.primary, fontStyle: FontStyle.italic),
                ),
              ),
            const SizedBox(height: 20),

            // ── FECHA ─────────────────────────────────────────────
            _Titulo('Fecha de compra'),
            const SizedBox(height: 8),
            Material(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(14),
              child: InkWell(
                onTap: _seleccionarFecha,
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    border: Border.all(color: cs.outline.withOpacity(0.5)),
                    borderRadius: BorderRadius.circular(14),
                    color: cs.surface,
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.calendar_today, color: cs.primary, size: 20),
                      const SizedBox(width: 12),
                      Expanded(child: Text(Formato.fechaLarga(_fecha),
                          style: const TextStyle(fontSize: 15))),
                      Icon(Icons.edit_calendar_outlined, color: cs.outline, size: 18),
                    ],
                  ),
                ),
              ),
            ),

            // ── DESCRIPCIÓN ───────────────────────────────────────
            _Titulo('Descripción (opcional)'),
            const SizedBox(height: 8),
            TextFormField(
              controller: _descCtrl,
              decoration: InputDecoration(
                hintText: 'Ej: Smartfit, Samsung S24 3/12...',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                prefixIcon: const Icon(Icons.notes_outlined),
              ),
              textCapitalization: TextCapitalization.sentences,
              maxLines: 2,
            ),
            const SizedBox(height: 20),

            // ── MEDIO DE PAGO ─────────────────────────────────────
            _Titulo('Medio de pago'),
            const SizedBox(height: 8),
            provider.mediosPago.isEmpty
                ? _Aviso('No hay medios de pago. Agrégalos en Configuración.')
                : _SelectorHorizontal<MedioPago>(
                    items: () {
                      final lista = List<MedioPago>.from(provider.mediosPago);
                      lista.sort((a, b) =>
                          (_frecuenciaMedios[b.id] ?? 0)
                              .compareTo(_frecuenciaMedios[a.id] ?? 0));
                      return lista;
                    }(),
                    seleccionado: _medioPago,
                    onSeleccionar: (m) => setState(() => _medioPago = m),
                    labelFn: (m) => m.nombre,
                    iconFn: (m) => Iconos.mapa[m.icono] ?? Icons.payment,
                    colorFn: (_) => cs.primary,
                    bgColorFn: (_) => cs.primaryContainer,
                  ),

            const SizedBox(height: 20),

            // ── CATEGORÍA ─────────────────────────────────────────
            _Titulo('Categoría'),
            const SizedBox(height: 8),
            provider.categorias.isEmpty
                ? _Aviso('No hay categorías. Agrégalas en Configuración.')
                : _GridCategorias(
                    categorias: provider.categorias.where((c) => c.activo).toList(),
                    seleccionada: _categoria,
                    onSeleccionar: (c) => setState(() => _categoria = c),
                  ),
            const SizedBox(height: 20),

            // ── TIPO ──────────────────────────────────────────────
            _Titulo('Tipo de gasto'),
            const SizedBox(height: 8),
            _buildSelectorTipo(cs),

            if (_esCompartido) ...[
              const SizedBox(height: 16),
              _Titulo('Grupo'),
              const SizedBox(height: 8),
              provider.grupos.isEmpty
                  ? _Aviso('No hay grupos. Agrégalos en Configuración.')
                  : _SelectorGrupos(
                      grupos: provider.grupos,
                      seleccionado: _grupo,
                      onSeleccionar: (g) => setState(() => _grupo = g),
                    ),
            ],

            const SizedBox(height: 32),
            FilledButton.icon(
              onPressed: _guardando ? null : _guardar,
              icon: const Icon(Icons.save_outlined),
              label: Text(
                esEdicion ? 'Guardar cambios' : 'Registrar gasto',
                style: const TextStyle(fontSize: 16),
              ),
              style: FilledButton.styleFrom(
                minimumSize: const Size(double.infinity, 52),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  // ── Widget selector de cuotas ─────────────────────────────────────

  Widget _buildSelectorCuotas(ColorScheme cs) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withOpacity(0.5),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: _esCuotado ? cs.primary.withOpacity(0.4) : Colors.transparent,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Toggle cuotado/sin cuotas
          Row(
            children: [
              Icon(Icons.credit_card, color: _esCuotado ? cs.primary : cs.outline, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  _esCuotado ? 'Compra en cuotas' : 'Compra sin cuotas',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: _esCuotado ? cs.primary : cs.onSurface,
                  ),
                ),
              ),
              Switch(
                value: _esCuotado,
                onChanged: (v) => setState(() {
                  _esCuotado = v;
                  if (!v) _cuotasCtrl.text = '1';
                }),
              ),
            ],
          ),

          if (_esCuotado) ...[
            const SizedBox(height: 14),
            const Divider(height: 1),
            const SizedBox(height: 14),

            // Campo libre de número de cuotas
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _cuotasCtrl,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      labelText: 'Número de cuotas',
                      hintText: 'Ej: 12',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      prefixIcon: const Icon(Icons.tag),
                      suffixText: _cuotas > 1 ? 'cuotas' : 'cuota',
                    ),
                    validator: (v) {
                      if (!_esCuotado) return null;
                      final n = int.tryParse(v ?? '');
                      if (n == null || n < 2) return 'Mínimo 2 cuotas';
                      return null;
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            // Accesos rápidos — horizontal debajo del input
            Row(
              children: [3, 6, 12, 24].map((n) {
                final sel = _cuotas == n;
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: GestureDetector(
                      onTap: () => setState(() => _cuotasCtrl.text = n.toString()),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 120),
                        height: 36,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: sel ? cs.primaryContainer : cs.surface,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: sel ? cs.primary : cs.outline.withOpacity(0.3),
                            width: sel ? 2 : 1,
                          ),
                        ),
                        child: Text('${n}x',
                            style: TextStyle(
                              fontWeight: sel ? FontWeight.bold : FontWeight.normal,
                              color: sel ? cs.primary : cs.outline,
                              fontSize: 13,
                            )),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 14),

            // Modo de ingreso: total o por cuota
            Row(
              children: [
                Expanded(
                  child: _BotonModo(
                    label: 'Ingreso el total',
                    sublabel: _montoIngresado > 0 && _cuotas > 1
                        ? 'Cuota: ${Formato.moneda(_montoIngresado / _cuotas)}'
                        : 'Monto ÷ $_cuotas',
                    sel: !_ingresarPorCuota,
                    color: cs.primary,
                    onTap: () => setState(() => _ingresarPorCuota = false),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _BotonModo(
                    label: 'Ingreso la cuota',
                    sublabel: _montoIngresado > 0 && _cuotas > 1
                        ? 'Total: ${Formato.moneda(_montoIngresado * _cuotas)}'
                        : 'Monto × $_cuotas',
                    sel: _ingresarPorCuota,
                    color: cs.secondary,
                    onTap: () => setState(() => _ingresarPorCuota = true),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSelectorTipo(ColorScheme cs) {
    return Row(
      children: [
        Expanded(child: _BotonTipo(
          label: 'Individual', icono: Icons.person,
          sel: !_esCompartido, color: cs.primary,
          onTap: () => setState(() { _esCompartido = false; _grupo = null; }),
        )),
        const SizedBox(width: 12),
        Expanded(child: _BotonTipo(
          label: 'Compartido', icono: Icons.group,
          sel: _esCompartido, color: cs.secondary,
          onTap: () => setState(() => _esCompartido = true),
        )),
      ],
    );
  }
}

// ─── Widgets auxiliares ──────────────────────────────────────────────────────

class _Titulo extends StatelessWidget {
  final String texto;
  const _Titulo(this.texto);
  @override
  Widget build(BuildContext context) {
    return Text(texto,
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.onSurfaceVariant));
  }
}

class _Aviso extends StatelessWidget {
  final String mensaje;
  const _Aviso(this.mensaje);
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
          color: cs.errorContainer, borderRadius: BorderRadius.circular(10)),
      child: Text(mensaje,
          style: TextStyle(color: cs.onErrorContainer, fontSize: 13)),
    );
  }
}

class _BotonModo extends StatelessWidget {
  final String label, sublabel;
  final bool sel;
  final Color color;
  final VoidCallback onTap;
  const _BotonModo({required this.label, required this.sublabel,
      required this.sel, required this.color, required this.onTap});
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        decoration: BoxDecoration(
          color: sel ? color.withOpacity(0.12) : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: sel ? color : Theme.of(context).colorScheme.outline.withOpacity(0.3),
            width: sel ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            Text(label, style: TextStyle(
                fontWeight: FontWeight.bold, fontSize: 12,
                color: sel ? color : Theme.of(context).colorScheme.outline)),
            const SizedBox(height: 2),
            Text(sublabel, style: TextStyle(
                fontSize: 11,
                color: sel ? color.withOpacity(0.8) : Theme.of(context).colorScheme.outline),
                textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}

class _BotonTipo extends StatelessWidget {
  final String label;
  final IconData icono;
  final bool sel;
  final Color color;
  final VoidCallback onTap;
  const _BotonTipo({required this.label, required this.icono,
      required this.sel, required this.color, required this.onTap});
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: sel ? color.withOpacity(0.15) : Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: sel ? color : Colors.transparent, width: 2),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icono, color: sel ? color : Theme.of(context).colorScheme.outline, size: 20),
            const SizedBox(width: 8),
            Text(label, style: TextStyle(
                fontWeight: sel ? FontWeight.bold : FontWeight.normal,
                color: sel ? color : Theme.of(context).colorScheme.outline)),
          ],
        ),
      ),
    );
  }
}

class _SelectorHorizontal<T> extends StatelessWidget {
  final List<T> items;
  final T? seleccionado;
  final void Function(T) onSeleccionar;
  final String Function(T) labelFn;
  final IconData Function(T) iconFn;
  final Color Function(T) colorFn;
  final Color Function(T) bgColorFn;
  const _SelectorHorizontal({required this.items, required this.seleccionado,
      required this.onSeleccionar, required this.labelFn, required this.iconFn,
      required this.colorFn, required this.bgColorFn});
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 80,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (ctx, i) {
          final item = items[i];
          final sel = seleccionado == item;
          final color = colorFn(item);
          final bg = bgColorFn(item);
          return GestureDetector(
            onTap: () => onSeleccionar(item),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              width: 90,
              decoration: BoxDecoration(
                color: sel ? bg : Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: sel ? color : Colors.transparent, width: 2),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(iconFn(item), color: sel ? color : Theme.of(context).colorScheme.outline, size: 24),
                  const SizedBox(height: 4),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Text(labelFn(item),
                        textAlign: TextAlign.center, maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 10,
                            fontWeight: sel ? FontWeight.bold : FontWeight.normal,
                            color: sel ? color : Theme.of(context).colorScheme.outline)),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _GridCategorias extends StatefulWidget {
  final List<Categoria> categorias;
  final Categoria? seleccionada;
  final void Function(Categoria) onSeleccionar;
  const _GridCategorias({required this.categorias, required this.seleccionada,
      required this.onSeleccionar});
  @override
  State<_GridCategorias> createState() => _GridCategoriasState();
}

class _GridCategoriasState extends State<_GridCategorias> {
  final _busquedaCtrl = TextEditingController();
  String _query = '';
  Map<int, int> _frecuencia = {};
  bool _ordenadoPorUso = false;

  static Color _hex(String hex) =>
      Color(int.parse('FF${hex.replaceAll('#', '')}', radix: 16));

  @override
  void initState() {
    super.initState();
    _cargarFrecuencia();
  }

  Future<void> _cargarFrecuencia() async {
    final provider = context.read<GastosProvider>();
    final freq = await provider.db.getFrecuenciaCategorias();
    if (mounted) setState(() => _frecuencia = freq);
  }

  @override
  void dispose() {
    _busquedaCtrl.dispose();
    super.dispose();
  }

  List<Categoria> get _filtradas {
    var lista = widget.categorias.where((c) =>
      _query.isEmpty ||
      c.nombre.toLowerCase().contains(_query.toLowerCase())
    ).toList();
    if (_ordenadoPorUso) {
      lista.sort((a, b) =>
          (_frecuencia[b.id] ?? 0).compareTo(_frecuencia[a.id] ?? 0));
    }
    return lista;
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final cats = _filtradas;
    return Column(
      children: [
        // ── Buscador + botón más usadas ─────────────────────────
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _busquedaCtrl,
                onChanged: (v) => setState(() => _query = v),
                decoration: InputDecoration(
                  hintText: 'Buscar categoría...',
                  hintStyle: TextStyle(fontSize: 13, color: cs.outline),
                  prefixIcon: Icon(Icons.search, size: 18, color: cs.outline),
                  suffixIcon: _query.isNotEmpty
                      ? IconButton(
                          icon: Icon(Icons.close, size: 16, color: cs.outline),
                          onPressed: () {
                            _busquedaCtrl.clear();
                            setState(() => _query = '');
                          },
                        )
                      : null,
                  contentPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                  isDense: true,
                ),
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: () => setState(() => _ordenadoPorUso = !_ordenadoPorUso),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: _ordenadoPorUso ? cs.primaryContainer : cs.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: _ordenadoPorUso ? cs.primary : Colors.transparent,
                    width: 1.5,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.trending_up, size: 16,
                        color: _ordenadoPorUso ? cs.primary : cs.outline),
                    const SizedBox(width: 4),
                    Text('Más usadas',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600,
                            color: _ordenadoPorUso ? cs.primary : cs.outline)),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),

        // ── Grid ────────────────────────────────────────────────
        cats.isEmpty
            ? Padding(
                padding: const EdgeInsets.all(20),
                child: Text('Sin resultados para "$_query"',
                    style: TextStyle(color: cs.outline, fontSize: 13)),
              )
            : GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 4, mainAxisSpacing: 8,
                    crossAxisSpacing: 8, childAspectRatio: 1.0),
                itemCount: cats.length,
                itemBuilder: (ctx, i) {
                  final cat = cats[i];
                  final sel = widget.seleccionada?.id == cat.id;
                  final color = _hex(cat.color);
                  final usos = _frecuencia[cat.id] ?? 0;
                  return GestureDetector(
                    onTap: () => widget.onSeleccionar(cat),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      decoration: BoxDecoration(
                        color: sel ? color.withOpacity(0.2)
                            : cs.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                            color: sel ? color : Colors.transparent, width: 2),
                      ),
                      child: Stack(
                        children: [
                          Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  Iconos.toEmoji(cat.icono),
                                  style: const TextStyle(fontSize: 24),
                                ),
                                const SizedBox(height: 4),
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 4),
                                  child: Text(cat.nombre,
                                      textAlign: TextAlign.center, maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(fontSize: 10,
                                          fontWeight: sel ? FontWeight.bold : FontWeight.normal,
                                          color: sel ? color : cs.outline)),
                                ),
                              ],
                            ),
                          ),
                          if (usos > 0 && _ordenadoPorUso)
                            Positioned(
                              top: 3, right: 3,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                decoration: BoxDecoration(
                                  color: color.withOpacity(0.85),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text('$usos',
                                    style: const TextStyle(fontSize: 8,
                                        color: Colors.white, fontWeight: FontWeight.bold)),
                              ),
                            ),
                        ],
                      ),
                    ),
                  );
                },
              ),
      ],
    );
  }
}


class _SelectorGrupos extends StatelessWidget {
  final List<Grupo> grupos;
  final Grupo? seleccionado;
  final void Function(Grupo) onSeleccionar;
  const _SelectorGrupos({required this.grupos, required this.seleccionado,
      required this.onSeleccionar});
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      children: grupos.map((g) {
        final sel = seleccionado?.id == g.id;
        return GestureDetector(
          onTap: () => onSeleccionar(g),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: sel ? cs.secondaryContainer : cs.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: sel ? cs.secondary : Colors.transparent, width: 2),
            ),
            child: Row(
              children: [
                Icon(Icons.group, color: sel ? cs.secondary : cs.outline, size: 20),
                const SizedBox(width: 12),
                Expanded(child: Text(g.nombre,
                    style: TextStyle(fontWeight: sel ? FontWeight.bold : FontWeight.normal))),
                if (sel) Icon(Icons.check_circle, color: cs.secondary, size: 20),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _MontoFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue old, TextEditingValue nv) {
    final digits = nv.text.replaceAll('.', '');
    if (digits.isEmpty) return nv.copyWith(text: '');
    final number = int.tryParse(digits) ?? 0;
    final formatted = NumberFormat('#,###', 'es_CL').format(number).replaceAll(',', '.');
    return nv.copyWith(
        text: formatted, selection: TextSelection.collapsed(offset: formatted.length));
  }
}

