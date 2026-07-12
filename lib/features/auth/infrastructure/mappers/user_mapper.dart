



import 'package:etecsa/features/auth/domain/entities/user.dart';

class UserMapper {


static User userJsonToEntity( Map<String,dynamic> json ) => User(
    // JHipster devuelve 'id_token', si no existe usamos vacío
    token: json['id_token'] ?? json['token'] ?? '',
    
    // Valores de prueba para los campos que JHipster NO envía en el login
    id: json['id'] ?? 'user-temp-123',
    email: json['email'] ?? 'admin@localhost.com',
    fullName: json['fullName'] ?? 'Usuario JHipster',
    
    // Manejo seguro de la lista de roles
    roles: json['roles'] != null 
      ? List<String>.from(json['roles'].map( (role) => role ))
      : ['ROLE_USER', 'ROLE_ADMIN'], // Roles de prueba
  );
}

