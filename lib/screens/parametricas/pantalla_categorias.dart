import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:misgastos/models/categoria.dart';
import 'package:misgastos/providers/gastos_provider.dart';
import 'package:misgastos/screens/shared/dialogo_formulario.dart';
import 'package:misgastos/utils/iconos.dart';
import 'package:misgastos/screens/shared/selector_color.dart';

class PantallaCategorias extends StatelessWidget {
  const PantallaCategorias({super.key});

  static const _colores = [
    '#FF6B6B', '#FF8E53', '#FF85A1', '#AD1457',
    '#F0A500', '#FFEAA7', '#FF6D00', '#E64A19',
    '#96CEB4', '#A8E063', '#388E3C', '#00897B',
    '#4ECDC4', '#45B7D1', '#0288D1', '#1565C0',
    '#6C63FF', '#7B1FA2', '#4527A0', '#DDA0DD',
    '#B0BEC5', '#455A64', '#4E342E', '#F9A825',
  ];

  static Color _hexColor(String hex) =>
      Color(int.parse('FF${hex.replaceAll('#', '')}', radix: 16));

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<GastosProvider>();
    final cs = Theme.of(context).colorScheme;
    final activas = provider.categorias.where((c) => c.activo).toList();
    final inactivas = provider.categorias.where((c) => !c.activo).toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Categorías'), centerTitle: true),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _mostrarDialogo(context, provider),
        icon: const Icon(Icons.add),
        label: const Text('Nueva'),
      ),
      body: provider.categorias.isEmpty
          ? _estadoVacio(context)
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
              children: [
                // ── Activas ──────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(children: [
                    Icon(Icons.check_circle_outline,
                        size: 15, color: cs.primary),
                    const SizedBox(width: 6),
                    Text('Activas (${activas.length})',
                        style: TextStyle(fontSize: 12,
                            fontWeight: FontWeight.w700, color: cs.primary)),
                  ]),
                ),
                ...activas.map((cat) => _ItemCategoria(
                      cat: cat,
                      hexColor: _hexColor,
                      onEditar: () => _mostrarDialogo(context, provider, cat),
                      onToggle: () => _toggleActivo(context, provider, cat),
                      onEliminar: () => _eliminar(context, provider, cat),
                    )),

                // ── Inactivas ─────────────────────────────────────
                if (inactivas.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(children: [
                      Icon(Icons.block_outlined,
                          size: 15, color: cs.outline),
                      const SizedBox(width: 6),
                      Text('Inactivas — no aparecen en nuevo gasto (${inactivas.length})',
                          style: TextStyle(fontSize: 12,
                              fontWeight: FontWeight.w700, color: cs.outline)),
                    ]),
                  ),
                  ...inactivas.map((cat) => _ItemCategoria(
                        cat: cat,
                        hexColor: _hexColor,
                        onEditar: () => _mostrarDialogo(context, provider, cat),
                        onToggle: () => _toggleActivo(context, provider, cat),
                        onEliminar: () => _eliminar(context, provider, cat),
                      )),
                ],
              ],
            ),
    );
  }

  Future<void> _toggleActivo(BuildContext context,
      GastosProvider provider, Categoria cat) async {
    await provider.editarCategoria(cat.copyWith(activo: !cat.activo));
  }

  Future<void> _eliminar(BuildContext context,
      GastosProvider provider, Categoria cat) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('¿Eliminar categoría?'),
        content: Text('Se eliminará "${cat.nombre}".'),
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
    if (ok == true && cat.id != null) {
      await provider.eliminarCategoria(cat.id!);
    }
  }

  Widget _estadoVacio(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.category_outlined, size: 64,
              color: Theme.of(context).colorScheme.outlineVariant),
          const SizedBox(height: 16),
          Text('No hay categorías.\nAgrega una con el botón +',
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: Theme.of(context).colorScheme.outline)),
        ],
      ),
    );
  }

  void _mostrarDialogo(BuildContext context, GastosProvider provider,
      [Categoria? cat]) {
    final nombreCtrl = TextEditingController(text: cat?.nombre ?? '');
    final emojiCtrl = TextEditingController(
        text: cat?.icono != null && Iconos.esEmoji(cat!.icono) ? cat.icono : '');
    // Usar listas para mutabilidad en closures
    final state = [
      cat?.icono ?? '❓',   // [0] iconoSel
      cat?.color ?? '#FF6B6B', // [1] colorSel
    ];

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => DialogoFormulario(
          titulo: cat == null ? 'Nueva categoría' : 'Editar categoría',
          onGuardar: () async {
            final nombre = nombreCtrl.text.trim();
            if (nombre.isEmpty) return;
            if (cat == null) {
              await provider.agregarCategoria(
                Categoria(nombre: nombre, icono: state[0],
                    color: state[1], activo: true),
              );
            } else {
              await provider.editarCategoria(
                Categoria(id: cat.id, nombre: nombre, icono: state[0],
                    color: state[1], activo: cat.activo),
              );
            }
            if (ctx.mounted) Navigator.pop(ctx);
          },
          contenido: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: nombreCtrl,
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: 'Nombre de la categoría',
                  hintText: 'Ej: Supermercado, Delivery, Nafta...',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.label_outline),
                ),
                textCapitalization: TextCapitalization.sentences,
              ),
              const SizedBox(height: 16),
              const Text('Ícono', style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              // Campo para escribir emoji + preview
              Row(
                children: [
                  // Preview del emoji seleccionado
                  GestureDetector(
                    onTap: () {
                      // Abrir teclado en el campo de emoji
                    },
                    child: Container(
                      width: 56, height: 56,
                      decoration: BoxDecoration(
                        color: _hexColor(state[1]).withOpacity(0.15),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                            color: _hexColor(state[1]), width: 2),
                      ),
                      child: Center(
                        child: Text(
                          Iconos.toEmoji(state[0]),
                          style: const TextStyle(fontSize: 28),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        StatefulBuilder(
                          builder: (ctx2, setEmoji) {
                            // ctrl ya declarado fuera
                            return TextField(
                              controller: emojiCtrl,
                              decoration: InputDecoration(
                                hintText: 'Escribe o pega un emoji 😊',
                                hintStyle: TextStyle(fontSize: 13,
                                    color: Theme.of(context).colorScheme.outline),
                                border: const OutlineInputBorder(),
                                isDense: true,
                                contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 10),
                                suffixIcon: const Icon(Icons.emoji_emotions_outlined),
                              ),
                              style: const TextStyle(fontSize: 22),
                              maxLength: 2,
                              buildCounter: (_, {required currentLength,
                                  required isFocused, maxLength}) => null,
                              onChanged: (v) {
                                if (v.isNotEmpty && Iconos.esEmoji(v.trim())) {
                                  setState(() => state[0] = v.trim());
                                }
                              },
                            );
                          },
                        ),
                        const SizedBox(height: 4),
                        Text('Toca el campo y abre el teclado emoji ⌨️',
                            style: TextStyle(fontSize: 11,
                                color: Theme.of(context).colorScheme.outline)),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Text('Color', style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              StatefulBuilder(
                builder: (ctx4, setColor) => SelectorColor(
                  colorHex: state[1],
                  label: 'Color de la categoría',
                  onColorChanged: (hex) {
                    setColor(() => state[1] = hex);
                    setState(() => state[1] = hex);
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Item de categoría con toggle activo ─────────────────────────────────────

class _ItemCategoria extends StatelessWidget {
  final Categoria cat;
  final Color Function(String) hexColor;
  final VoidCallback onEditar;
  final VoidCallback onToggle;
  final VoidCallback onEliminar;

  const _ItemCategoria({
    required this.cat,
    required this.hexColor,
    required this.onEditar,
    required this.onToggle,
    required this.onEliminar,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final color = hexColor(cat.color);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: cat.activo ? cs.surface : cs.surfaceContainerHighest.withOpacity(0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: cat.activo ? cs.outline.withOpacity(0.12) : Colors.transparent),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: color.withOpacity(cat.activo ? 0.15 : 0.07),
            child: Text(
              Iconos.toEmoji(cat.icono),
              style: TextStyle(
                fontSize: 18,
                color: cat.activo ? null : Colors.black26,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(cat.nombre,
                style: TextStyle(
                  fontSize: 14, fontWeight: FontWeight.w600,
                  color: cat.activo ? cs.onSurface : cs.outline,
                )),
          ),
          // Toggle activo/inactivo
          GestureDetector(
            onTap: onToggle,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: cat.activo
                    ? cs.primaryContainer
                    : cs.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: cat.activo ? cs.primary : cs.outline.withOpacity(0.3)),
              ),
              child: Text(
                cat.activo ? 'Activa' : 'Inactiva',
                style: TextStyle(
                  fontSize: 11, fontWeight: FontWeight.w700,
                  color: cat.activo ? cs.primary : cs.outline,
                ),
              ),
            ),
          ),
          const SizedBox(width: 6),
          IconButton(
            icon: const Icon(Icons.edit_outlined, size: 18),
            onPressed: onEditar,
            color: cs.outline,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
          const SizedBox(width: 4),
          IconButton(
            icon: Icon(Icons.delete_outline, size: 18, color: cs.error),
            onPressed: onEliminar,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }
}
