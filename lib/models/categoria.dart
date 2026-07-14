class Categoria {
  final int? id;
  final String nombre;
  final String icono;
  final String color;
  final bool activo;

  Categoria({
    this.id,
    required this.nombre,
    required this.icono,
    required this.color,
    this.activo = true,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'nombre': nombre,
      'icono': icono,
      'color': color,
      'activo': activo ? 1 : 0,
    };
  }

  factory Categoria.fromMap(Map<String, dynamic> map) {
    return Categoria(
      id: map['id'] as int?,
      nombre: map['nombre'] as String,
      icono: map['icono'] as String,
      color: map['color'] as String,
      activo: (map['activo'] as int? ?? 1) == 1,
    );
  }

  Categoria copyWith({int? id, String? nombre, String? icono, String? color, bool? activo}) {
    return Categoria(
      id: id ?? this.id,
      nombre: nombre ?? this.nombre,
      icono: icono ?? this.icono,
      color: color ?? this.color,
      activo: activo ?? this.activo,
    );
  }

  @override
  String toString() => 'Categoria(id: $id, nombre: $nombre, activo: $activo)';
}
