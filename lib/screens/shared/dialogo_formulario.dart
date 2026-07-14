import 'package:flutter/material.dart';

/// Diálogo genérico con título, contenido y botones Cancelar / Guardar
class DialogoFormulario extends StatelessWidget {
  final String titulo;
  final Widget contenido;
  final VoidCallback onGuardar;
  final String textoGuardar;

  const DialogoFormulario({
    super.key,
    required this.titulo,
    required this.contenido,
    required this.onGuardar,
    this.textoGuardar = 'Guardar',
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(titulo),
      content: SingleChildScrollView(child: contenido),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: onGuardar,
          child: Text(textoGuardar),
        ),
      ],
    );
  }
}
