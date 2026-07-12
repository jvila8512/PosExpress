


class UserJhispter {
  final int id;
  final String email;
  final String login; // Nombre de usuario en JHipster
  final String fullName;
  final List<String> roles;
  final String token;

  UserJhispter({
    required this.id,
    required this.email,
    required this.login,
    required this.fullName,
    required this.roles,
    required this.token,
  });


  bool get isAdmin {
    return roles.contains('admin');
  }

}
