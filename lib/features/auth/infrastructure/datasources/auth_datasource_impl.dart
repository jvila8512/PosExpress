import 'package:drift/drift.dart';
import 'package:etecsa/core/database/app_database.dart';
import 'package:etecsa/features/auth/domain/datasources/auth_datasource.dart';
import 'package:etecsa/features/auth/domain/entities/user.dart' as auth;
import 'package:etecsa/features/auth/infrastructure/errors/auth_errors.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:uuid/uuid.dart';

class AuthDataSourceImpl extends AuthDataSource {
  final AppDatabase _db;
  final _secureStorage = const FlutterSecureStorage();
  final _uuid = const Uuid();

  AuthDataSourceImpl(this._db);

  @override
  Future<auth.User> login(String username, String password, bool rememberMe) async {
    try {
      print("=== LOGIN DB ===");
      print("Looking for user: $username");
      
      // Usar método login de la BD (verifica contraseña con hash)
      final dbUser = await _db.login(username, password);
      
      print("DB User found: ${dbUser?.username}");
      print("User role: ${dbUser?.role}");
      print("===============");
      
      if (dbUser == null) {
        throw WrongCredentials();
      }

if (!dbUser.active) {
        throw CustomError('Usuario desactivado.');
      }
      
      // Si es el usuario admin, asegurar que tenga rol super_admin
      String userRoleToSave = dbUser.role;
      if (dbUser.username.toLowerCase() == 'admin' && dbUser.role != 'super_admin') {
        await _db.updatePassword(dbUser.id, password); // Esto actualiza, pero we'll do it differently
        // Simplemente usamos la BD para actualizar el rol
        final updDb = AppDatabase.instance;
        await (updDb.update(updDb.users)..where((u)=>u.id.equals(dbUser.id)))
            .write(UsersCompanion(role: const Value('super_admin')));
        userRoleToSave = 'super_admin';
        print('Updated admin to super_admin');
      }
      
      // Guardar sesión
      final sessionToken = _uuid.v4();
      final now = DateTime.now();
      await _secureStorage.write(key: 'session_token', value: sessionToken);
      await _secureStorage.write(key: 'session_time', value: now.toIso8601String());
      await _secureStorage.write(key: 'user_id', value: dbUser.id);
      await _secureStorage.write(key: 'user_role', value: userRoleToSave);
      
      return auth.User(
        id: dbUser.id,
        email: dbUser.email ?? '',
        fullName: dbUser.fullName,
        roles: [dbUser.role],
        token: sessionToken,
      );
    } catch (e) {
      print('Error en Login: $e');
      if (e is WrongCredentials || e is CustomError) {
        rethrow;
      }
      throw CustomError('Error al iniciar sesión');
    }
  }

@override
  Future<auth.User> register(String username, String password, String fullName) async {
    try {
      final existing = await _db.getUserByUsername(username);
      if (existing != null) {
        throw CustomError('El usuario ya existe');
      }

      // Verificar si es el primer usuario (será super_admin)
      final allUsers = await _db.getAllUsers();
      final isFirstUser = allUsers.isEmpty;
      final userRole = isFirstUser ? 'super_admin' : 'admin';
      
      final userId = const Uuid().v4();
      
      await _db.into(_db.users).insert(
        UsersCompanion.insert(
          id: userId,
          username: username,
          passwordHash: password,
          role: userRole,
          fullName: fullName,
        ),
      );

      final sessionToken = _uuid.v4();
      final now = DateTime.now();
      await _secureStorage.write(key: 'session_token', value: sessionToken);
      await _secureStorage.write(key: 'session_time', value: now.toIso8601String());
      await _secureStorage.write(key: 'user_id', value: userId);
      await _secureStorage.write(key: 'user_role', value: userRole); // Guardar el rol correcto

      return auth.User(
        id: userId,
        email: '',
        fullName: fullName,
        roles: ['admin'],
        token: sessionToken,
      );
    } catch (e) {
      if (e is CustomError) rethrow;
      print('Error en Register: $e');
      throw CustomError('Error al registrar');
    }
  }

  @override
  Future<auth.User> checkAuthStatus(String token) async {
    try {
      final storedToken = await _secureStorage.read(key: 'session_token');
      if (storedToken == null || storedToken != token) {
        throw InvalidToken();
      }

      final userId = await _secureStorage.read(key: 'user_id');
      if (userId == null) {
        throw InvalidToken();
      }

      final dbUser = await (_db.select(_db.users)
            ..where((u) => u.id.equals(userId)))
          .getSingleOrNull();

      if (dbUser == null || !dbUser.active) {
        throw InvalidToken();
      }

      return auth.User(
        id: dbUser.id,
        email: dbUser.email ?? '',
        fullName: dbUser.fullName,
        roles: [dbUser.role],
        token: token,
      );
    } catch (e) {
      if (e is InvalidToken) rethrow;
      throw InvalidToken();
    }
  }

  Future<void> logout() async {
    await _secureStorage.delete(key: 'session_token');
    await _secureStorage.delete(key: 'user_id');
  }
}