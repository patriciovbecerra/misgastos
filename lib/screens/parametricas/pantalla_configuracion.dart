import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:misgastos/providers/gastos_provider.dart';
import 'pantalla_medios_pago.dart';
import 'pantalla_categorias.dart';
import 'pantalla_grupos.dart';

class PantallaConfiguracion extends StatelessWidget {
  const PantallaConfiguracion({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<GastosProvider>();
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Configuración'),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ── Encabezado ──
          Padding(
            padding: const EdgeInsets.only(bottom: 16, top: 8),
            child: Text(
              'Tablas paramétricas',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: cs.primary,
                  ),
            ),
          ),

          // ── Medios de pago ──
          _TarjetaParametrica(
            icono: Icons.payment,
            titulo: 'Medios de Pago',
            subtitulo:
                '${provider.mediosPago.length} medios registrados',
            color: cs.primaryContainer,
            iconoColor: cs.primary,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => ChangeNotifierProvider.value(
                  value: provider,
                  child: const PantallaMediasPago(),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),

          // ── Categorías ──
          _TarjetaParametrica(
            icono: Icons.category,
            titulo: 'Categorías',
            subtitulo:
                '${provider.categorias.length} categorías registradas',
            color: const Color(0xFFFFE0B2),
            iconoColor: const Color(0xFFE65100),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => ChangeNotifierProvider.value(
                  value: provider,
                  child: const PantallaCategorias(),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),

          // ── Grupos ──
          _TarjetaParametrica(
            icono: Icons.group,
            titulo: 'Grupos',
            subtitulo:
                '${provider.grupos.length} grupos registrados',
            color: cs.secondaryContainer,
            iconoColor: cs.secondary,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => ChangeNotifierProvider.value(
                  value: provider,
                  child: const PantallaGrupos(),
                ),
              ),
            ),
          ),

          const SizedBox(height: 32),
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Text(
              'Información',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: cs.primary,
                  ),
            ),
          ),

          // ── Info de la app ──
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.info_outline, color: cs.outline),
                      const SizedBox(width: 8),
                      Text('GastosApp v1.0',
                          style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: cs.outline)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Tus datos se guardan localmente en el dispositivo.',
                    style: TextStyle(color: cs.outline, fontSize: 13),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TarjetaParametrica extends StatelessWidget {
  final IconData icono;
  final String titulo;
  final String subtitulo;
  final Color color;
  final Color iconoColor;
  final VoidCallback onTap;

  const _TarjetaParametrica({
    required this.icono,
    required this.titulo,
    required this.subtitulo,
    required this.color,
    required this.iconoColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icono, color: iconoColor),
        ),
        title: Text(titulo,
            style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(subtitulo),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}
