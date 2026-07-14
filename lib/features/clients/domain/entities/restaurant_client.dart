/// Represents a restaurant delivery client.
///
/// This is a separate entity from the license-level `Clientes` table.
/// No foreign key relationship exists between them.
class RestaurantClient {
  final String id;
  final String nombre;
  final String telefono;
  final String? direccion;
  final String? referencia;
  final String? notas;
  final DateTime? fechaRegistro;

  const RestaurantClient({
    required this.id,
    required this.nombre,
    required this.telefono,
    this.direccion,
    this.referencia,
    this.notas,
    this.fechaRegistro,
  });

  factory RestaurantClient.fromJson(Map<String, dynamic> json) {
    return RestaurantClient(
      id: json['id']?.toString() ?? '',
      nombre: json['nombre']?.toString() ?? '',
      telefono: json['telefono']?.toString() ?? '',
      direccion: json['direccion']?.toString(),
      referencia: json['referencia']?.toString(),
      notas: json['notas']?.toString(),
      fechaRegistro: json['fecha_registro'] != null
          ? DateTime.tryParse(json['fecha_registro'].toString())
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'nombre': nombre,
    'telefono': telefono,
    if (direccion != null) 'direccion': direccion,
    if (referencia != null) 'referencia': referencia,
    if (notas != null) 'notas': notas,
    if (fechaRegistro != null) 'fecha_registro': fechaRegistro!.toIso8601String(),
  };

  RestaurantClient copyWith({
    String? id,
    String? nombre,
    String? telefono,
    String? direccion,
    String? referencia,
    String? notas,
    DateTime? fechaRegistro,
  }) {
    return RestaurantClient(
      id: id ?? this.id,
      nombre: nombre ?? this.nombre,
      telefono: telefono ?? this.telefono,
      direccion: direccion ?? this.direccion,
      referencia: referencia ?? this.referencia,
      notas: notas ?? this.notas,
      fechaRegistro: fechaRegistro ?? this.fechaRegistro,
    );
  }
}
