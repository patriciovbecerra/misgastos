class Grupo {
  final int? id;
  final String nombre;
  final String? descripcion;

  Grupo({
    this.id,
    required this.nombre,
    this.descripcion,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'nombre': nombre,
      'descripcion': descripcion,
    };
  }

  factory Grupo.fromMap(Map<String, dynamic> map) {
    return Grupo(
      id: map['id'] as int?,
      nombre: map['nombre'] as String,
      descripcion: map['descripcion'] as String?,
    );
  }

  Grupo copyWith({int? id, String? nombre, String? descripcion}) {
    return Grupo(
      id: id ?? this.id,
      nombre: nombre ?? this.nombre,
      descripcion: descripcion ?? this.descripcion,
    );
  }

  @override
  String toString() => 'Grupo(id: $id, nombre: $nombre)';
}
