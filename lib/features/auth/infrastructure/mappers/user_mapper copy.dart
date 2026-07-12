



import 'package:etecsa/features/auth/domain/entities/userJhispter.dart';

class UserMapper {
  static UserJhispter userJsonToEntity(Map<String, dynamic> json, [String? token]) {
    return UserJhispter(
      id: json['id'] ?? 0,
      email: json['email'] ?? '',
      login: json['login'] ?? '',
      fullName: '${json['firstName'] ?? ''} ${json['lastName'] ?? ''}'.trim(),
      // En JHipster la lista de roles viene en 'authorities'
      roles: List<String>.from(json['authorities'] ?? []),
      token: token ?? '',
    );
  }
}
