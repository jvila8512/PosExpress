import 'package:etecsa/features/auth/domain/entities/user.dart' as auth;

abstract class AuthDataSource {
  Future<auth.User> login(String username, String password, bool rememberMe);
  Future<auth.User> register(String username, String password, String fullName);
  Future<auth.User> checkAuthStatus(String token);
}
