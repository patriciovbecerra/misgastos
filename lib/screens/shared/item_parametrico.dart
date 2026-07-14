import 'package:flutter/material.dart';

/// Tarjeta reutilizable para mostrar un item de tabla paramétrica
class ItemParametrico extends StatelessWidget {
  final String titulo;
  final String? subtitulo;
  final Widget leading;
  final VoidCallback? onEditar;
  final VoidCallback? onEliminar;
  final VoidCallback? onTap;
  final Widget? trailing;

  const ItemParametrico({
    super.key,
    required this.titulo,
    this.subtitulo,
    required this.leading,
    this.onEditar,
    this.onEliminar,
    this.onTap,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
      child: ListTile(
        onTap: onTap,
        leading: leading,
        title: Text(titulo, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: subtitulo != null ? Text(subtitulo!) : null,
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (trailing != null) trailing!,
            if (onEditar != null)
              IconButton(
                icon: Icon(Icons.edit_outlined, color: cs.primary, size: 20),
                onPressed: onEditar,
                tooltip: 'Editar',
              ),
            if (onEliminar != null)
              IconButton(
                icon: Icon(Icons.delete_outline, color: cs.error, size: 20),
                onPressed: onEliminar,
                tooltip: 'Eliminar',
              ),
          ],
        ),
      ),
    );
  }
}

/// Muestra un diálogo de confirmación antes de eliminar
Future<bool> confirmarEliminacion(BuildContext context, String nombre) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('¿Eliminar?'),
      content: Text('¿Estás seguro de eliminar "$nombre"?'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
          onPressed: () => Navigator.pop(ctx, true),
          child: const Text('Eliminar'),
        ),
      ],
    ),
  );
  return result ?? false;
}
