import 'package:flutter_test/flutter_test.dart';
import 'package:etecsa/features/auth/domain/entities/user.dart';
import 'package:etecsa/features/auth/infrastructure/datasources/auth_datasource_impl.dart';

/// The role mapping function we expect to exist in auth_datasource_impl.dart
/// or a shared helper. We test it via the datasource's internal logic.
void main() {
  group('mapPosRoleToSmsRole', () {
    // These test the mapping of legacy POS roles to new SMS roles
    test('super_admin maps to admin', () {
      expect(mapPosRoleToSmsRole('super_admin'), 'admin');
    });

    test('admin stays admin', () {
      expect(mapPosRoleToSmsRole('admin'), 'admin');
    });

    test('vendedor maps to redes', () {
      expect(mapPosRoleToSmsRole('vendedor'), 'redes');
    });

    test('almacenero maps to cocina', () {
      expect(mapPosRoleToSmsRole('almacenero'), 'cocina');
    });

    test('unknown role passes through unchanged', () {
      expect(mapPosRoleToSmsRole('mesero'), 'mesero');
    });

    test('empty string passes through', () {
      expect(mapPosRoleToSmsRole(''), '');
    });
  });

  group('User SMS role getters', () {
    test('isRedes returns true when roles contains redes', () {
      final user = User(
        id: '1',
        email: 'test@test.com',
        fullName: 'Test User',
        roles: ['redes'],
        token: 'abc123',
      );
      expect(user.isRedes, isTrue);
      expect(user.isAdmin, isFalse);
      expect(user.isCocina, isFalse);
      expect(user.isDomicilio, isFalse);
      expect(user.isMesero, isFalse);
    });

    test('isCocina returns true when roles contains cocina', () {
      final user = User(
        id: '2',
        email: 'cocina@test.com',
        fullName: 'Cocina User',
        roles: ['cocina'],
        token: 'abc123',
      );
      expect(user.isCocina, isTrue);
      expect(user.isAdmin, isFalse);
      expect(user.isRedes, isFalse);
    });

    test('isDomicilio returns true when roles contains domicilio', () {
      final user = User(
        id: '3',
        email: 'domicilio@test.com',
        fullName: 'Domicilio User',
        roles: ['domicilio'],
        token: 'abc123',
      );
      expect(user.isDomicilio, isTrue);
      expect(user.isAdmin, isFalse);
    });

    test('isMesero returns true when roles contains mesero', () {
      final user = User(
        id: '4',
        email: 'mesero@test.com',
        fullName: 'Mesero User',
        roles: ['mesero'],
        token: 'abc123',
      );
      expect(user.isMesero, isTrue);
      expect(user.isAdmin, isFalse);
    });

    test('isAdmin returns true for admin role', () {
      final user = User(
        id: '5',
        email: 'admin@test.com',
        fullName: 'Admin User',
        roles: ['admin'],
        token: 'abc123',
      );
      expect(user.isAdmin, isTrue);
      expect(user.isRedes, isFalse);
    });

    test('multiple roles work correctly', () {
      final user = User(
        id: '6',
        email: 'multi@test.com',
        fullName: 'Multi Role',
        roles: ['admin', 'redes'],
        token: 'abc123',
      );
      expect(user.isAdmin, isTrue);
      expect(user.isRedes, isTrue);
      expect(user.isCocina, isFalse);
    });

    test('empty roles list returns false for all', () {
      final user = User(
        id: '7',
        email: 'empty@test.com',
        fullName: 'No Roles',
        roles: [],
        token: 'abc123',
      );
      expect(user.isAdmin, isFalse);
      expect(user.isRedes, isFalse);
      expect(user.isCocina, isFalse);
      expect(user.isDomicilio, isFalse);
      expect(user.isMesero, isFalse);
    });
  });

  group('User phone field', () {
    test('phone defaults to empty string', () {
      final user = User(
        id: '1',
        email: 'test@test.com',
        fullName: 'Test User',
        roles: ['redes'],
        token: 'abc123',
      );
      expect(user.phone, '');
    });

    test('phone can be set via constructor', () {
      final user = User(
        id: '2',
        email: 'test@test.com',
        fullName: 'Test User',
        roles: ['redes'],
        token: 'abc123',
        phone: '53512345',
      );
      expect(user.phone, '53512345');
    });

    test('phone is independent of other fields', () {
      final user = User(
        id: '3',
        email: 'a@b.com',
        fullName: 'User',
        roles: ['cocina'],
        token: 'xyz',
        phone: '53567890',
      );
      expect(user.phone, '53567890');
      expect(user.id, '3');
      expect(user.roles, ['cocina']);
    });
  });
}
