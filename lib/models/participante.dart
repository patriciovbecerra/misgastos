class Participante {
  final int? id;
  final String nombre;
  final int idGrupo;

  Participante({
    this.id,
    required this.nombre,
    required this.idGrupo,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'nombre': nombre,
      'id_grupo': idGrupo,
    };
  }

  factory Participante.fromMap(Map<String, dynamic> map) {
    return Participante(
      id: map['id'] as int?,
      nombre: map['nombre'] as String,
      idGrupo: map['id_grupo'] as int,
    );
  }

  Participante copyWith({int? id, String? nombre, int? idGrupo}) {
    return Participante(
      id: id ?? this.id,
      nombre: nombre ?? this.nombre,
      idGrupo: idGrupo ?? this.idGrupo,
    );
  }

  @override
  String toString() => 'Participante(id: $id, nombre: $nombre, grupo: $idGrupo)';
}
