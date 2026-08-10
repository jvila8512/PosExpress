import 'dart:async';

/// Resultado de un único paso del flujo de arranque.
class StartupStepResult {
  final String name;
  final bool ok;
  final Object? error;

  const StartupStepResult({
    required this.name,
    required this.ok,
    this.error,
  });
}

/// Resultado global del flujo de arranque.
class StartupFlowResult {
  final List<StartupStepResult> steps;
  final bool timedOut;

  /// Nombre del paso que estaba en marcha cuando se disparó el timeout
  /// (null si no hubo timeout).
  final String? hangingStep;

  const StartupFlowResult({
    required this.steps,
    required this.timedOut,
    this.hangingStep,
  });
}

typedef StartupStep = ({String name, Future<void> Function() run});

/// Ejecuta pasos de arranque en orden con aislamiento por paso y un timeout
/// global (fail-open): cada fallo de paso se registra pero no aborta la
/// cadena; si el conjunto supera [timeout], devuelve [StartupFlowResult]
/// con `timedOut: true` y el nombre del paso colgado.
///
/// `log` recibe cada transición de paso (START / OK / FAIL) para dejar
/// rastro en producción.
Future<StartupFlowResult> runStartupFlow({
  required List<StartupStep> steps,
  required Duration timeout,
  void Function(String message)? log,
}) async {
  final results = <StartupStepResult>[];
  var timedOut = false;
  String? hangingStep;
  String? current;

  try {
    await Future<void>(() async {
      for (final step in steps) {
        current = step.name;
        log?.call('[STEP] START ${step.name}');
        try {
          await step.run();
          results.add(StartupStepResult(name: step.name, ok: true));
          log?.call('[STEP] OK ${step.name}');
        } catch (e) {
          results.add(StartupStepResult(name: step.name, ok: false, error: e));
          log?.call('[STEP] FAIL ${step.name}: $e');
        }
      }
      current = null;
    }).timeout(timeout);
  } on TimeoutException {
    timedOut = true;
    hangingStep = current;
  }

  return StartupFlowResult(
    steps: results,
    timedOut: timedOut,
    hangingStep: hangingStep,
  );
}