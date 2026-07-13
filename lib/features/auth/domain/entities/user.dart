


class User {

  final String id;
  final String email;
  final String fullName;
  final List<String> roles;
  final String token;
  final String phone;

  User({
    required this.id,
    required this.email,
    required this.fullName,
    required this.roles,
    required this.token,
    this.phone = '',
  });

  bool get isAdmin {
    return roles.contains('admin');
  }

  bool get isRedes => roles.contains('redes');
  bool get isCocina => roles.contains('cocina');
  bool get isDomicilio => roles.contains('domicilio');
  bool get isMesero => roles.contains('mesero');

}
