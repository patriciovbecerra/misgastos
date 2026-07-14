import 'package:flutter/material.dart';

/// Selector de color sin paquetes externos — rueda HSV nativa de Flutter
class SelectorColor extends StatefulWidget {
  final String colorHex;
  final ValueChanged<String> onColorChanged;
  final String? label;

  const SelectorColor({
    super.key,
    required this.colorHex,
    required this.onColorChanged,
    this.label,
  });

  @override
  State<SelectorColor> createState() => _SelectorColorState();
}

class _SelectorColorState extends State<SelectorColor> {
  late HSVColor _hsv;

  static Color _hexToColor(String hex) =>
      Color(int.parse('FF${hex.replaceAll('#', '')}', radix: 16));

  static String _colorToHex(Color c) =>
      '#${c.red.toRadixString(16).padLeft(2, '0')}'
      '${c.green.toRadixString(16).padLeft(2, '0')}'
      '${c.blue.toRadixString(16).padLeft(2, '0')}'.toUpperCase();

  @override
  void initState() {
    super.initState();
    _hsv = HSVColor.fromColor(_hexToColor(widget.colorHex));
  }

  Color get _color => _hsv.toColor();

  void _abrirPicker() {
    HSVColor hsvTemp = _hsv;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) => AlertDialog(
          title: const Text('Seleccionar color'),
          content: SizedBox(
            width: 300,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Preview
                Container(
                  height: 48,
                  decoration: BoxDecoration(
                    color: hsvTemp.toColor(),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [BoxShadow(
                        color: hsvTemp.toColor().withOpacity(0.4),
                        blurRadius: 8)],
                  ),
                  child: Center(
                    child: Text(
                      _colorToHex(hsvTemp.toColor()),
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          shadows: [Shadow(blurRadius: 4)]),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Hue (matiz)
                const Align(alignment: Alignment.centerLeft,
                    child: Text('Matiz (Hue)', style: TextStyle(fontSize: 12))),
                SliderTheme(
                  data: SliderTheme.of(ctx).copyWith(
                    trackHeight: 12,
                    thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 10),
                  ),
                  child: Slider(
                    value: hsvTemp.hue,
                    min: 0, max: 360,
                    onChanged: (v) => setD(() =>
                        hsvTemp = hsvTemp.withHue(v)),
                    activeColor: hsvTemp.withSaturation(1).withValue(1).toColor(),
                  ),
                ),

                // Saturación
                const Align(alignment: Alignment.centerLeft,
                    child: Text('Saturación', style: TextStyle(fontSize: 12))),
                SliderTheme(
                  data: SliderTheme.of(ctx).copyWith(trackHeight: 12,
                      thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 10)),
                  child: Slider(
                    value: hsvTemp.saturation,
                    min: 0, max: 1,
                    onChanged: (v) => setD(() =>
                        hsvTemp = hsvTemp.withSaturation(v)),
                    activeColor: hsvTemp.toColor(),
                  ),
                ),

                // Brillo
                const Align(alignment: Alignment.centerLeft,
                    child: Text('Brillo', style: TextStyle(fontSize: 12))),
                SliderTheme(
                  data: SliderTheme.of(ctx).copyWith(trackHeight: 12,
                      thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 10)),
                  child: Slider(
                    value: hsvTemp.value,
                    min: 0.2, max: 1,
                    onChanged: (v) => setD(() =>
                        hsvTemp = hsvTemp.withValue(v)),
                    activeColor: hsvTemp.toColor(),
                  ),
                ),

                const SizedBox(height: 8),

                // Colores rápidos
                const Align(alignment: Alignment.centerLeft,
                    child: Text('Rápidos', style: TextStyle(fontSize: 12))),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 8, runSpacing: 8,
                  children: const [
                    '#1565C0', '#0288D1', '#00838F', '#2E7D32',
                    '#388E3C', '#F57F17', '#E65100', '#C62828',
                    '#AD1457', '#6A1B9A', '#4527A0', '#455A64',
                    '#4E342E', '#BF360C', '#00897B', '#F9A825',
                    '#7B1FA2', '#880E4F', '#1B5E20', '#006064',
                  ].map((hex) {
                    final c = Color(int.parse('FF${hex.replaceAll('#', '')}', radix: 16));
                    return GestureDetector(
                      onTap: () => setD(() => hsvTemp = HSVColor.fromColor(c)),
                      child: Container(
                        width: 28, height: 28,
                        decoration: BoxDecoration(
                          color: c, shape: BoxShape.circle,
                          border: Border.all(
                            color: hsvTemp.toColor().value == c.value
                                ? Colors.white : Colors.transparent,
                            width: 2),
                          boxShadow: [BoxShadow(
                              color: c.withOpacity(0.4), blurRadius: 4)],
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancelar')),
            FilledButton(
              onPressed: () {
                setState(() => _hsv = hsvTemp);
                widget.onColorChanged(_colorToHex(hsvTemp.toColor()));
                Navigator.pop(ctx);
              },
              child: const Text('Aplicar'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final current = _hexToColor(widget.colorHex);

    return GestureDetector(
      onTap: _abrirPicker,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          border: Border.all(color: cs.outline.withOpacity(0.3)),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Container(
              width: 32, height: 32,
              decoration: BoxDecoration(
                color: current,
                shape: BoxShape.circle,
                boxShadow: [BoxShadow(
                    color: current.withOpacity(0.4), blurRadius: 8)],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(widget.label ?? 'Color',
                      style: TextStyle(fontSize: 11, color: cs.outline)),
                  Text(widget.colorHex.toUpperCase(),
                      style: const TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w600)),
                ],
              ),
            ),
            Icon(Icons.colorize, color: cs.outline, size: 18),
          ],
        ),
      ),
    );
  }
}
