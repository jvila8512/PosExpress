import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:etecsa/features/auth/domain/entities/user.dart' as auth;
import 'package:etecsa/features/auth/domain/repositories/auth_repository.dart';
import 'package:etecsa/features/auth/infrastructure/errors/auth_errors.dart';
import 'package:etecsa/features/auth/infrastructure/repositories/auth_repository_impl.dart';
import 'package:etecsa/features/auth/infrastructure/datasources/auth_datasource_impl.dart';
import 'package:etecsa/core/database/app_database.dart';
import 'package:etecsa/core/security/license_service.dart';

/// Provider para el datasource
final _authDataSourceProvider = Provider<AuthDataSourceImpl>((ref) {
  final database = AppDatabase.instance;
  return AuthDataSourceImpl(database);
});

/// Provider para el repository
final authRepositoryProvider = Provider<AuthRepository>((ref) {
  final dataSource = ref.watch(_authDataSourceProvider);
  return AuthRepositoryImpl(dataSource);
});

/// Provider principal de autenticación
final authProvider = NotifierProvider<AuthNotifier, AuthState>(AuthNotifier.new);

class AuthNotifier extends Notifier<AuthState> {
  AuthRepository get _repository => ref.read(authRepositoryProvider);

  @override
  AuthState build() {
    return const AuthState();
  }

  Future<void> loginUser(String username, String password, bool rememberMe) async {
    state = state.copyWith(authStatus: AuthStatus.checking, errorMessage: '');

    try {
      // VERIFICAR LICENCIA PRIMERO — sin licencia activa, nadie entra
      final activatedLicense = await LicenseService.getActivatedLicenseCode();
      if (activatedLicense == null || activatedLicense.isEmpty) {
        _logout('Activa tu licencia primero');
        return;
      }

      // Validar que la licencia sea vigente
      final db = AppDatabase.instance;
      final validation = await LicenseService.validateLicenseWithTamperProtection(db);
      if (!validation.isValid) {
        if (validation.isExpired) {
          _logout('Licencia vencida. Renueva tu plan.');
        } else {
          _logout('Licencia inválida. Contacta a soporte.');
        }
        return;
      }

      // Login normal
      try {
        final user = await _repository.login(username, password, rememberMe);
        state = state.copyWith(
          user: user,
          authStatus: AuthStatus.authenticated,
        );
      } on WrongCredentials {
        final isFirstTime = await _isFirstTimeLogin();
        
        if (isFirstTime && username == 'admin') {
          await _createDefaultAdmin(password);
          final user = await _repository.login(username, password, rememberMe);
          state = state.copyWith(
            user: user,
            authStatus: AuthStatus.authenticated,
          );
        } else {
          _logout('Usuario o contraseña incorrectos');
        }
      }
    } on WrongCredentials {
      _logout('Usuario o contraseña incorrectos');
    } on CustomError catch (e) {
      _logout(e.message);
    } catch (e) {
      _logout('Error inesperado. Intente de nuevo.');
    }
  }

  // Verificar si es el primer login (no hay usuarios)
  Future<bool> _isFirstTimeLogin() async {
    return true; // Por ahora siempre permite crear admin
  }

  // Crear admin por defecto
  Future<void> _createDefaultAdmin(String password) async {
    final db = AppDatabase.instance;
    await db.createDefaultAdmin();
    await db.createDefaultJefe();
  }

  Future<void> registerUser(String username, String password, String fullName) async {
    state = state.copyWith(authStatus: AuthStatus.checking, errorMessage: '');

    try {
      // Verificar licencia antes de registrar
      final activatedLicense = await LicenseService.getActivatedLicenseCode();
      if (activatedLicense == null || activatedLicense.isEmpty) {
        _logout('Activa tu licencia primero antes de crear cuentas');
        return;
      }

      final user = await _repository.register(username, password, fullName);
      state = state.copyWith(
        user: user,
        authStatus: AuthStatus.authenticated,
      );
    } on CustomError catch (e) {
      _logout(e.message);
    } catch (e) {
      _logout('Error al registrar. Intente de nuevo.');
    }
  }

  Future<void> checkAuthStatus(String token) async {
    state = state.copyWith(authStatus: AuthStatus.checking);

    try {
      final user = await _repository.checkAuthStatus(token);
      state = state.copyWith(
        user: user,
        authStatus: AuthStatus.authenticated,
      );
    } catch (e) {
      state = state.copyWith(
        authStatus: AuthStatus.notAuthenticated,
        user: null,
      );
    }
  }

  Future<void> logout() async {
    try {
      await _repository.logout();
    } catch (_) {}
    state = state.copyWith(
      authStatus: AuthStatus.notAuthenticated,
      user: null,
      errorMessage: '',
    );
  }

  void _logout(String message) {
    state = state.copyWith(
      authStatus: AuthStatus.notAuthenticated,
      user: null,
      errorMessage: message,
    );
  }

  void clearError() {
    state = state.copyWith(errorMessage: '');
  }
}

/// Estado de autenticación
enum AuthStatus { checking, authenticated, notAuthenticated }

class AuthState {
  final AuthStatus authStatus;
  final auth.User? user;
  final String errorMessage;

  const AuthState({
    this.authStatus = AuthStatus.checking,
    this.user,
    this.errorMessage = '',
  });

  AuthState copyWith({
    AuthStatus? authStatus,
    auth.User? user,
    String? errorMessage,
  }) {
    return AuthState(
      authStatus: authStatus ?? this.authStatus,
      user: user ?? this.user,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }

  bool get isAuthenticated => authStatus == AuthStatus.authenticated;
  bool get isAdmin => user?.roles.contains('admin') ?? false;
  bool get isRedes => user?.roles.contains('redes') ?? false;
  bool get isCocina => user?.roles.contains('cocina') ?? false;
  bool get isDomicilio => user?.roles.contains('domicilio') ?? false;
  bool get isMesero => user?.roles.contains('mesero') ?? false;
}