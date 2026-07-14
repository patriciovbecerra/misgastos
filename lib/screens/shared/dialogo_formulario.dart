import 'package:flutter/material.dart';

/// Diálogo genérico con título, contenido y botones Cancelar / Guardar
class DialogoFormulario extends StatefulWidget {
  final String titulo;
  final Widget contenido;
  final Future<void> Function() onGuardar;
  final String textoGuardar;

  const DialogoFormulario({
    super.key,
    required this.titulo,
    required this.contenido,
    required this.onGuardar,
    this.textoGuardar = 'Guardar',
  });

  @override
  State<DialogoFormulario> createState() => _DialogoFormularioState();
}

class _DialogoFormularioState extends State<DialogoFormulario> {
  bool _guardando = false;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.titulo),
      content: SingleChildScrollView(child: widget.contenido),
      actions: [
        TextButton(
          onPressed: _guardando ? null : () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: _guardando ? null : () async {
            setState(() => _guardando = true);
            try {
              await widget.onGuardar();
            } finally {
              if (mounted) setState(() => _guardando = false);
            }
          },
          child: _guardando
              ? const SizedBox(
                  width: 18, height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : Text(widget.textoGuardar),
        ),
      ],
    );
  }
}
