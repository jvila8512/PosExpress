import 'package:flutter_test/flutter_test.dart';
import 'package:etecsa/config/router/app_router.dart';

void main() {
  group('workersRedirectDecision (guard de /workers)', () {
    test('admin puede navegar a /workers (sin redirect)', () async {
      final decision = await workersRedirectDecision(
        loggedIn: true,
        role: 'admin',
        currentPath: '/workers',
      );
      expect(decision, isNull);
    });

    test('super_admin puede navegar a /workers (sin redirect)', () async {
      final decision = await workersRedirectDecision(
        loggedIn: true,
        role: 'super_admin',
        currentPath: '/workers',
      );
      expect(decision, isNull);
    });

    test('cocina es redirigido a /', () async {
      final decision = await workersRedirectDecision(
        loggedIn: true,
        role: 'cocina',
        currentPath: '/workers',
      );
      expect(decision, '/');
    });

    test('redes/vendedor es redirigido a /', () async {
      final decision = await workersRedirectDecision(
        loggedIn: true,
        role: 'redes',
        currentPath: '/workers',
      );
      expect(decision, '/');
      final vendedor = await workersRedirectDecision(
        loggedIn: true,
        role: 'vendedor',
        currentPath: '/workers',
      );
      expect(vendedor, '/');
    });

    test('domicilio es redirigido a /', () async {
      final decision = await workersRedirectDecision(
        loggedIn: true,
        role: 'domicilio',
        currentPath: '/workers',
      );
      expect(decision, '/');
    });

    test('mesero es redirigido a /', () async {
      final decision = await workersRedirectDecision(
        loggedIn: true,
        role: 'mesero',
        currentPath: '/workers',
      );
      expect(decision, '/');
    });

    test('sin sesión a /workers -> /login (nunca renderiza usuarios)', () async {
      final decision = await workersRedirectDecision(
        loggedIn: false,
        role: '',
        currentPath: '/workers',
      );
      expect(decision, '/login');
    });

    test('no afecta rutas que no son /workers', () async {
      final decision = await workersRedirectDecision(
        loggedIn: true,
        role: 'cocina',
        currentPath: '/orders/new',
      );
      expect(decision, isNull);
    });
  });
}