import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:misgastos/models/medio_pago.dart';
import 'package:misgastos/providers/gastos_provider.dart';
import 'package:misgastos/screens/shared/dialogo_formulario.dart';
import 'package:misgastos/screens/shared/item_parametrico.dart';
import 'package:misgastos/utils/iconos.dart';
import 'package:misgastos/screens/shared/selector_color.dart';
import 'package:misgastos/screens/parametricas/pantalla_calendario_tc.dart';

class PantallaMediasPago extends StatelessWidget {
  static const _coloresMedio = [
    '#1565C0', '#0288D1', '#0097A7', '#00838F',
    '#2E7D32', '#388E3C', '#558B2F', '#F57F17',
    '#E65100', '#C62828', '#AD1457', '#6A1B9A',
    '#4527A0', '#283593', '#455A64', '#37474F',
    '#4E342E', '#BF360C', '#00897B', '#F9A825',
    '#7B1FA2', '#880E4F', '#1B5E20', '#006064',
  ];
  const PantallaMediasPago({super.key});

  // Íconos centralizados en Iconos.mapa

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<GastosProvider>();

    return Scaffold(
      appBar: AppBar(title: const Text('Medios de Pago'), centerTitle: true),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _mostrarDialogo(context, provider),
        icon: const Icon(Icons.add),
        label: const Text('Nuevo'),
      ),
      body: provider.mediosPago.isEmpty
          ? _estadoVacio(context)
          : ListView.builder(
              padding: const EdgeInsets.only(top: 12, bottom: 80),
              itemCount: provider.mediosPago.length,
              itemBuilder: (ctx, i) {
                final medio = provider.mediosPago[i];
                return ItemParametrico(
                  titulo: medio.nombre,
                  subtitulo: medio.esTarjetaCredito
                      ? (medio.diaCierre != null ? 'TC · Cierra día ${medio.diaCierre}' : 'Tarjeta de crédito')
                      : null,
                  leading: CircleAvatar(
                    backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                    child: Icon(
                      Iconos.get(medio.icono),
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                  onEditar: () => _mostrarDialogo(context, provider, medio),
                  onEliminar: () async {
                    final ok = await confirmarEliminacion(context, medio.nombre);
                    if (ok && medio.id != null) {
                      await provider.eliminarMedioPago(medio.id!);
                    }
                  },
                  trailing: medio.esTarjetaCredito
                      ? IconButton(
                          icon: const Icon(Icons.calendar_month_outlined),
                          tooltip: 'Calendario de facturación',
                          color: Theme.of(context).colorScheme.primary,
                          onPressed: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => PantallaCalendarioTC(medio: medio),
                            ),
                          ),
                        )
                      : null,
                );
              },
            ),
    );
  }

  Widget _estadoVacio(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.payment_outlined, size: 64,
              color: Theme.of(context).colorScheme.outlineVariant),
          const SizedBox(height: 16),
          Text('No hay medios de pago.\nAgrega uno con el botón +',
              textAlign: TextAlign.center,
              style: TextStyle(color: Theme.of(context).colorScheme.outline)),
        ],
      ),
    );
  }

  void _mostrarDialogo(BuildContext context, GastosProvider provider,
      [MedioPago? medio]) {
    final nombreCtrl = TextEditingController(text: medio?.nombre ?? '');
    String iconoSel = medio?.icono ?? 'credit_card';
    String colorSel = medio?.color ?? '#0288D1';
    int? diaCierreSel = medio?.diaCierre;
    bool esTCSel = medio?.esTarjetaCredito ?? false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => DialogoFormulario(
          titulo: medio == null ? 'Nuevo medio de pago' : 'Editar medio de pago',
          onGuardar: () async {
            final nombre = nombreCtrl.text.trim();
            if (nombre.isEmpty) return;
            if (medio == null) {
              await provider.agregarMedioPago(
                MedioPago(nombre: nombre, icono: iconoSel, color: colorSel, diaCierre: esTCSel ? diaCierreSel : null, esTarjetaCredito: esTCSel),
              );
            } else {
              await provider.editarMedioPago(
                MedioPago(id: medio.id, nombre: nombre, icono: iconoSel, color: colorSel, diaCierre: esTCSel ? diaCierreSel : null, esTarjetaCredito: esTCSel),
              );
            }
            if (ctx.mounted) Navigator.pop(ctx);
          },
          contenido: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Nombre libre
              TextField(
                controller: nombreCtrl,
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: 'Nombre del medio de pago',
                  hintText: 'Ej: Tarjeta Chile Visa, Efectivo, MACH...',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.label_outline),
                ),
                textCapitalization: TextCapitalization.sentences,
              ),
              const SizedBox(height: 14),
              // Toggle tarjeta de crédito
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: esTCSel
                      ? Theme.of(context).colorScheme.primaryContainer.withOpacity(0.4)
                      : Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: esTCSel
                        ? Theme.of(context).colorScheme.primary.withOpacity(0.4)
                        : Colors.transparent,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(Icons.credit_card,
                        color: esTCSel
                            ? Theme.of(context).colorScheme.primary
                            : Theme.of(context).colorScheme.outline,
                        size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Tarjeta de crédito',
                              style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: esTCSel
                                      ? Theme.of(context).colorScheme.primary
                                      : Theme.of(context).colorScheme.onSurface)),
                          Text('Aparece en Facturación con su período',
                              style: TextStyle(
                                  fontSize: 11,
                                  color: Theme.of(context).colorScheme.outline)),
                        ],
                      ),
                    ),
                    Switch(
                      value: esTCSel,
                      onChanged: (v) => setState(() {
                        esTCSel = v;
                        if (!v) diaCierreSel = null; // desactiva TC → limpia día
                                      }),
                    ),
                  ],
                ),
              ),
              // Día de cierre solo si es TC
              if (esTCSel) ...[
                const SizedBox(height: 12),
                const Text('Día de cierre',
                    style: TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                TextFormField(
                  initialValue: diaCierreSel?.toString() ?? '',
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    hintText: 'Ej: 15',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.calendar_today_outlined),
                    suffixText: 'día del mes',
                    isDense: true,
                  ),
                  onChanged: (v) {
                    final n = int.tryParse(v);
                    if (n != null && n >= 1 && n <= 31) {
                      diaCierreSel = n;
                    } else if (v.isEmpty) {
                      diaCierreSel = null;
                    }
                  },
                ),
              ],



              const SizedBox(height: 16),
              // ── Selector de color ──────────────────────────────
              SelectorColor(
                colorHex: colorSel,
                label: 'Color del medio de pago',
                onColorChanged: (hex) => setState(() => colorSel = hex),
              ),
              const SizedBox(height: 16),
              const Text('Ícono', style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: Iconos.opcionesMedioPago.map((op) {
                  final key = op['key'] as String;
                  final sel = iconoSel == key;
                  final cs = Theme.of(context).colorScheme;
                  return GestureDetector(
                    onTap: () => setState(() => iconoSel = key),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: sel ? cs.primaryContainer : cs.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(10),
                        border: sel ? Border.all(color: cs.primary, width: 2) : null,
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Iconos.get(key), color: sel ? cs.primary : null),
                          const SizedBox(height: 2),
                          Text(op['label'] as String,
                              style: TextStyle(fontSize: 9,
                                  color: sel ? cs.primary : cs.outline)),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
