import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:etecsa/core/services/startup_flow.dart';
import 'package:etecsa/features/shared/presentation/screens/splash_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
  });

  /// Router mínimo con /splash + destinos del fail-open. El splash se monta
  /// con steps y fuentes inyectadas para no tocar DB real ni platform channels.
  GoRouter buildRouter({
    List<StartupStep>? steps,
    Future<bool> Function()? hasUsers,
  }) {
    return GoRouter(
      initialLocation: '/splash',
      routes: [
        GoRoute(
          path: '/splash',
          builder: (ctx, state) => SplashScreen(
            startupSteps: steps,
            hasUsersOverride: hasUsers,
          ),
        ),
        GoRoute(
          path: '/login',
          builder: (ctx, state) => const Scaffold(body: SizedBox()),
        ),
        GoRoute(
          path: '/register',
          builder: (ctx, state) => const Scaffold(body: SizedBox()),
        ),
      ],
    );
  }

  testWidgets('timeout (paso que nunca completa) -> fail-open a /login',
      (tester) async {
    final router = buildRouter(
      hasUsers: () async => true,
      steps: [
        (name: 'hang', run: () => Completer<void>().future),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(child: MaterialApp.router(routerConfig: router)),
    );
    await tester.pump(); // arranca _initApp

    // Avanzar más allá del fence de 10s
    await tester.pump(const Duration(seconds: 11));
    await tester.pumpAndSettle();

    expect(
      router.routerDelegate.currentConfiguration.uri.path,
      '/login',
      reason: 'Con usuarios existentes, el fail-open debe ir a /login',
    );
  });

  testWidgets('timeout (paso que nunca completa) -> fail-open a /register '
      'cuando no hay usuarios', (tester) async {
    final router = buildRouter(
      hasUsers: () async => false,
      steps: [
        (name: 'hang', run: () => Completer<void>().future),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(child: MaterialApp.router(routerConfig: router)),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 11));
    await tester.pumpAndSettle();

    expect(
      router.routerDelegate.currentConfiguration.uri.path,
      '/register',
      reason: 'Sin usuarios, el fail-open debe ir a /register',
    );
  });

  testWidgets('pasos que fallan no abortan el splash (sin crash ni hang)',
      (tester) async {
    final router = buildRouter(
      hasUsers: () async => true,
      steps: [
        (
          name: 'boom',
          run: () async => throw StateError('step exploded'),
        ),
        (name: 'ok', run: () async {}),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(child: MaterialApp.router(routerConfig: router)),
    );
    await tester.pump();

    // Aislamiento por paso: el fallo se loguea y la cadena sigue; el widget
    // no tira excepción ni navega por sí solo (la decisión depende de la DB,
    // que el test no toca). Avance fijo sin pumpAndSettle (spinner infinito).
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 100));

    expect(tester.takeException(), isNull);
    expect(
      router.routerDelegate.currentConfiguration.uri.path,
      '/splash',
      reason: 'Sin timeout la cadena continúa; la decisión la resuelve _decideRoute',
    );
  });

  testWidgets('fondo del splash usa el accent de marca', (tester) async {
    final router = buildRouter(
      hasUsers: () async => true,
      steps: [
        (name: 'hang', run: () => Completer<void>().future),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(child: MaterialApp.router(routerConfig: router)),
    );
    await tester.pump();

    // Verificar el fondo mientras el splash sigue montado (antes del timeout).
    final splashScaffold = tester.widget<Scaffold>(
      find
          .descendant(
            of: find.byType(SplashScreen),
            matching: find.byType(Scaffold),
          )
          .first,
    );
    expect(
      splashScaffold.backgroundColor,
      const Color(0xFFD9531E),
      reason: 'Splash debe usar AppColors.accent (Achiote)',
    );

    // Dejar que el timeout navegue para no dejar timers pendientes.
    await tester.pump(const Duration(seconds: 11));
    await tester.pumpAndSettle();
  });
}