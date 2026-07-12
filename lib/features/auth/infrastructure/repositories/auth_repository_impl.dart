import 'package:etecsa/features/auth/domain/datasources/auth_datasource.dart';
import 'package:etecsa/features/auth/domain/entities/user.dart' as auth;
import 'package:etecsa/features/auth/domain/repositories/auth_repository.dart';
import 'package:etecsa/features/auth/infrastructure/datasources/auth_datasource_impl.dart';

class AuthRepositoryImpl extends AuthRepository {

  final AuthDataSource _dataSource;

  AuthRepositoryImpl(this._dataSource);

  @override
  Future<auth.User> login(String username, String password, bool rememberMe) {
    return _dataSource.login(username, password, rememberMe);
  }

  @override
  Future<auth.User> register(String username, String password, String fullName) {
    return _dataSource.register(username, password, fullName);
  }

  @override
  Future<auth.User> checkAuthStatus(String token) {
    return _dataSource.checkAuthStatus(token);
  }

  @override
  Future<void> logout() async {
    if (_dataSource is AuthDataSourceImpl) {
      await (_dataSource as AuthDataSourceImpl).logout();
    }
  }
}