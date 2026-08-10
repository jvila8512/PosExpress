import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:etecsa/core/services/startup_flow.dart';

void main() {
  group('runStartupFlow', () {
    test('runs all steps in order when nothing fails', () async {
      final order = <String>[];
      final result = await runStartupFlow(
        timeout: const Duration(seconds: 5),
        steps: [
          (name: 'a', run: () async => order.add('a')),
          (name: 'b', run: () async => order.add('b')),
          (name: 'c', run: () async => order.add('c')),
        ],
      );

      expect(result.timedOut, isFalse);
      expect(order, ['a', 'b', 'c']);
      expect(result.steps.map((s) => s.name), ['a', 'b', 'c']);
      expect(result.steps.every((s) => s.ok), isTrue);
      expect(result.hangingStep, isNull);
    });

    test('isolates a failing step and continues with the next one', () async {
      final order = <String>[];
      final result = await runStartupFlow(
        timeout: const Duration(seconds: 5),
        steps: [
          (name: 'ok1', run: () async => order.add('ok1')),
          (
            name: 'boom',
            run: () async {
              order.add('boom');
              throw StateError('boom');
            },
          ),
          (name: 'ok2', run: () async => order.add('ok2')),
        ],
      );

      expect(result.timedOut, isFalse);
      expect(order, ['ok1', 'boom', 'ok2']);
      expect(result.steps[1].ok, isFalse);
      expect(result.steps[1].error, isA<StateError>());
      expect(result.steps[0].ok, isTrue);
      expect(result.steps[2].ok, isTrue);
    });

    test('flags a timeout and names the hanging step', () async {
      final log = <String>[];
      final result = await runStartupFlow(
        timeout: const Duration(milliseconds: 100),
        log: log.add,
        steps: [
          (name: 'fast', run: () async {}),
          (
            name: 'hang',
            run: () async =>
                await Completer<void>().future, // nunca se resuelve
          ),
          (name: 'never', run: () async {}),
        ],
      );

      expect(result.timedOut, isTrue);
      expect(result.hangingStep, 'hang');
      expect(result.steps.map((s) => s.name), ['fast']);
      expect(
        log.any((m) => m.contains('hang')),
        isTrue,
        reason: 'El paso colgado debe quedar identificado en el log',
      );
    });

    test('logs START and OK transitions', () async {
      final log = <String>[];
      await runStartupFlow(
        timeout: const Duration(seconds: 5),
        log: log.add,
        steps: [
          (name: 'alpha', run: () async {}),
          (name: 'beta', run: () async {}),
        ],
      );

      expect(log, contains('[STEP] START alpha'));
      expect(log, contains('[STEP] OK alpha'));
      expect(log, contains('[STEP] START beta'));
      expect(log, contains('[STEP] OK beta'));
    });

    test('logs FAIL for a broken step without aborting', () async {
      final log = <String>[];
      final result = await runStartupFlow(
        timeout: const Duration(seconds: 5),
        log: log.add,
        steps: [
          (
            name: 'broken',
            run: () async => throw Exception('x'),
          ),
          (name: 'after', run: () async {}),
        ],
      );

      expect(log, contains('[STEP] FAIL broken: Exception: x'));
      expect(result.steps[1].name, 'after');
      expect(result.steps[1].ok, isTrue);
    });
  });
}