import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:misgastos/models/grupo.dart';
import 'package:misgastos/models/participante.dart';
import 'package:misgastos/providers/gastos_provider.dart';
import 'package:misgastos/screens/shared/dialogo_formulario.dart';
import 'package:misgastos/screens/shared/item_parametrico.dart';

class PantallaGrupos extends StatelessWidget {
  const PantallaGrupos({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<GastosProvider>();

    return Scaffold(
      appBar: AppBar(title: const Text('Grupos'), centerTitle: true),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _mostrarDialogoGrupo(context, provider),
        icon: const Icon(Icons.group_add),
        label: const Text('Nuevo grupo'),
      ),
      body: provider.grupos.isEmpty
          ? _estadoVacio(context)
          : ListView.builder(
              padding: const EdgeInsets.only(top: 12, bottom: 80),
              itemCount: provider.grupos.length,
              itemBuilder: (ctx, i) {
                final grupo = provider.grupos[i];
                return ItemParametrico(
                  titulo: grupo.nombre,
                  subtitulo: grupo.descripcion,
                  leading: CircleAvatar(
                    backgroundColor:
                        Theme.of(context).colorScheme.secondaryContainer,
                    child: Icon(Icons.group,
                        color: Theme.of(context).colorScheme.onSecondaryContainer),
                  ),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ChangeNotifierProvider.value(
                        value: provider,
                        child: _PantallaDetalleGrupo(grupo: grupo),
                      ),
                    ),
                  ),
                  onEditar: () => _mostrarDialogoGrupo(context, provider, grupo),
                  onEliminar: () async {
                    final ok = await confirmarEliminacion(context, grupo.nombre);
                    if (ok && grupo.id != null) {
                      await provider.eliminarGrupo(grupo.id!);
                    }
                  },
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
          Icon(Icons.group_outlined, size: 64,
              color: Theme.of(context).colorScheme.outlineVariant),
          const SizedBox(height: 16),
          Text('No hay grupos.\nAgrega uno con el botón +',
              textAlign: TextAlign.center,
              style: TextStyle(color: Theme.of(context).colorScheme.outline)),
        ],
      ),
    );
  }

  void _mostrarDialogoGrupo(BuildContext context, GastosProvider provider,
      [Grupo? grupo]) {
    final nombreCtrl = TextEditingController(text: grupo?.nombre ?? '');
    final descCtrl = TextEditingController(text: grupo?.descripcion ?? '');

    showDialog(
      context: context,
      builder: (ctx) => DialogoFormulario(
        titulo: grupo == null ? 'Nuevo grupo' : 'Editar grupo',
        onGuardar: () async {
          final nombre = nombreCtrl.text.trim();
          if (nombre.isEmpty) return;
          final desc = descCtrl.text.trim().isEmpty ? null : descCtrl.text.trim();
          if (grupo == null) {
            // INSERT
            await provider.agregarGrupo(Grupo(nombre: nombre, descripcion: desc));
          } else {
            // UPDATE real — conserva el mismo ID
            await provider.editarGrupo(
              Grupo(id: grupo.id, nombre: nombre, descripcion: desc),
            );
          }
          if (ctx.mounted) Navigator.pop(ctx);
        },
        contenido: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nombreCtrl,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Nombre del grupo',
                hintText: 'Ej: Depa, Familia, Viaje Perú...',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.group_outlined),
              ),
              textCapitalization: TextCapitalization.sentences,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: descCtrl,
              decoration: const InputDecoration(
                labelText: 'Descripción (opcional)',
                hintText: 'Ej: Gastos compartidos del departamento',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.notes_outlined),
              ),
              textCapitalization: TextCapitalization.sentences,
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Detalle del grupo (participantes) ───────────────────────────────────────

class _PantallaDetalleGrupo extends StatefulWidget {
  final Grupo grupo;
  const _PantallaDetalleGrupo({required this.grupo});

  @override
  State<_PantallaDetalleGrupo> createState() => _PantallaDetalleGrupoState();
}

class _PantallaDetalleGrupoState extends State<_PantallaDetalleGrupo> {
  List<Participante> _participantes = [];
  bool _cargando = true;

  @override
  void initState() {
    super.initState();
    _cargarParticipantes();
  }

  Future<void> _cargarParticipantes() async {
    final provider = context.read<GastosProvider>();
    final lista = await provider.getParticipantes(widget.grupo.id!);
    if (mounted) {
      setState(() {
        _participantes = lista;
        _cargando = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: Text(widget.grupo.nombre), centerTitle: true),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _mostrarDialogoParticipante,
        icon: const Icon(Icons.person_add),
        label: const Text('Agregar'),
      ),
      body: _cargando
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                if (widget.grupo.descripcion != null)
                  Container(
                    width: double.infinity,
                    margin: const EdgeInsets.all(16),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: cs.secondaryContainer,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(widget.grupo.descripcion!,
                        style: TextStyle(color: cs.onSecondaryContainer)),
                  ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  child: Row(
                    children: [
                      Text(
                        'Participantes (${_participantes.length})',
                        style: Theme.of(context)
                            .textTheme
                            .titleSmall
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: _participantes.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.person_outline,
                                  size: 48, color: cs.outlineVariant),
                              const SizedBox(height: 12),
                              Text(
                                'Sin participantes aún.\nAgrega miembros con el botón +',
                                textAlign: TextAlign.center,
                                style: TextStyle(color: cs.outline),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.only(top: 4, bottom: 80),
                          itemCount: _participantes.length,
                          itemBuilder: (ctx, i) {
                            final p = _participantes[i];
                            return ItemParametrico(
                              titulo: p.nombre,
                              leading: CircleAvatar(
                                backgroundColor: cs.tertiaryContainer,
                                child: Text(
                                  p.nombre[0].toUpperCase(),
                                  style: TextStyle(
                                    color: cs.onTertiaryContainer,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              onEditar: () => _mostrarDialogoEditarParticipante(p),
                              onEliminar: () async {
                                final ok = await confirmarEliminacion(context, p.nombre);
                                if (ok && p.id != null) {
                                  final provider = context.read<GastosProvider>();
                                  await provider.eliminarParticipante(p.id!);
                                  await _cargarParticipantes();
                                }
                              },
                            );
                          },
                        ),
                ),
              ],
            ),
    );
  }

  void _mostrarDialogoParticipante() {
    final nombreCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => DialogoFormulario(
        titulo: 'Agregar participante',
        textoGuardar: 'Agregar',
        onGuardar: () async {
          final nombre = nombreCtrl.text.trim();
          if (nombre.isEmpty) return;
          final provider = context.read<GastosProvider>();
          await provider.agregarParticipante(
            Participante(nombre: nombre, idGrupo: widget.grupo.id!),
          );
          await _cargarParticipantes();
          if (ctx.mounted) Navigator.pop(ctx);
        },
        contenido: TextField(
          controller: nombreCtrl,
          decoration: const InputDecoration(
            labelText: 'Nombre del participante',
            hintText: 'Ej: Pato, María, Juan...',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.person_outline),
          ),
          textCapitalization: TextCapitalization.words,
          autofocus: true,
        ),
      ),
    );
  }

  void _mostrarDialogoEditarParticipante(Participante p) {
    final nombreCtrl = TextEditingController(text: p.nombre);
    showDialog(
      context: context,
      builder: (ctx) => DialogoFormulario(
        titulo: 'Editar participante',
        onGuardar: () async {
          final nombre = nombreCtrl.text.trim();
          if (nombre.isEmpty) return;
          // UPDATE directo en DB
          final db = context.read<GastosProvider>();
          await db.eliminarParticipante(p.id!);
          await db.agregarParticipante(
            Participante(nombre: nombre, idGrupo: p.idGrupo),
          );
          await _cargarParticipantes();
          if (ctx.mounted) Navigator.pop(ctx);
        },
        contenido: TextField(
          controller: nombreCtrl,
          decoration: const InputDecoration(
            labelText: 'Nombre del participante',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.person_outline),
          ),
          textCapitalization: TextCapitalization.words,
          autofocus: true,
        ),
      ),
    );
  }
}
