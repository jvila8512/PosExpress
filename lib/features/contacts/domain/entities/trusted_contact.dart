/// A trusted phone number for SMS origin filtering.
///
/// Each contact is associated with a role and is used by the
/// BroadcastReceiver to filter incoming SMS messages.
class TrustedContact {
  final String id;
  final String rol; // admin | redes | cocina | domicilio | mesero
  final String usuarioId;
  final String numeroTelefono;
  final bool activo;

  const TrustedContact({
    required this.id,
    required this.rol,
    required this.usuarioId,
    required this.numeroTelefono,
    this.activo = true,
  });

  factory TrustedContact.fromJson(Map<String, dynamic> json) {
    return TrustedContact(
      id: json['id']?.toString() ?? '',
      rol: json['rol']?.toString() ?? '',
      usuarioId: json['usuario_id']?.toString() ?? '',
      numeroTelefono: json['numero_telefono']?.toString() ?? '',
      activo: json['activo'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'rol': rol,
    'usuario_id': usuarioId,
    'numero_telefono': numeroTelefono,
    'activo': activo,
  };

  TrustedContact copyWith({
    String? id,
    String? rol,
    String? usuarioId,
    String? numeroTelefono,
    bool? activo,
  }) {
    return TrustedContact(
      id: id ?? this.id,
      rol: rol ?? this.rol,
      usuarioId: usuarioId ?? this.usuarioId,
      numeroTelefono: numeroTelefono ?? this.numeroTelefono,
      activo: activo ?? this.activo,
    );
  }
}
