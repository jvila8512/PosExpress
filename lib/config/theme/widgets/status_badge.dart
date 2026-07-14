import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:etecsa/features/orders/domain/entities/order_state.dart';
import 'package:etecsa/config/theme/app_colors.dart';

/// A colored pill badge that represents an [OrderState].
///
/// Color mapping follows the PRD §15 semantics:
/// - `registrado` → warning (Mostaza) — confirmed, pending
/// - `enCocina`  → accent (Achiote) — in progress
/// - `hecho`     → success (Mojo) — ready
/// - `enCamino`  → warning (Mostaza) — in transit
/// - `entregado` / `entregadoEnMesa` → success (Mojo) — delivered
/// - `pagado` / `cerrado` → success (Mojo) — completed
/// - `cancelado` → danger (Guayaba) — cancelled
class StatusBadge extends StatelessWidget {
  final OrderState state;
  final double fontSize;
  final EdgeInsetsGeometry padding;

  const StatusBadge({
    super.key,
    required this.state,
    this.fontSize = 12,
    this.padding = const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
  });

  /// Resolves the display label for each [OrderState].
  static String labelFor(OrderState state) {
    switch (state) {
      case OrderState.registrado:
        return 'Registrado';
      case OrderState.enCocina:
        return 'En cocina';
      case OrderState.hecho:
        return 'Listo';
      case OrderState.enCamino:
        return 'En camino';
      case OrderState.entregado:
        return 'Entregado';
      case OrderState.entregadoEnMesa:
        return 'Entregado';
      case OrderState.pagado:
        return 'Pagado';
      case OrderState.cerrado:
        return 'Cerrado';
      case OrderState.cancelado:
        return 'Cancelado';
    }
  }

  /// Resolves the background color for each [OrderState].
  static Color colorFor(OrderState state, {required Brightness brightness}) {
    switch (state) {
      case OrderState.registrado:
        return AppColors.forBrightness(brightness).warning;
      case OrderState.enCocina:
        return AppColors.accent;
      case OrderState.hecho:
        return AppColors.forBrightness(brightness).success;
      case OrderState.enCamino:
        return AppColors.forBrightness(brightness).warning;
      case OrderState.entregado:
      case OrderState.entregadoEnMesa:
      case OrderState.pagado:
      case OrderState.cerrado:
        return AppColors.forBrightness(brightness).success;
      case OrderState.cancelado:
        return AppColors.forBrightness(brightness).danger;
    }
  }

  /// Resolves the foreground (text) color for each [OrderState].
  static Color textColorFor(OrderState state, {required Brightness brightness}) {
    switch (state) {
      case OrderState.registrado:
      case OrderState.enCocina:
      case OrderState.hecho:
      case OrderState.enCamino:
      case OrderState.entregado:
      case OrderState.entregadoEnMesa:
      case OrderState.pagado:
      case OrderState.cerrado:
        return Colors.white;
      case OrderState.cancelado:
        return Colors.white;
    }
  }

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final bgColor = colorFor(state, brightness: brightness);
    final fgColor = textColorFor(state, brightness: brightness);

    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(100), // fully rounded pill
      ),
      child: Text(
        labelFor(state),
        style: GoogleFonts.dmSans(
          fontSize: fontSize,
          fontWeight: FontWeight.w600,
          color: fgColor,
          height: 1.2,
        ),
      ),
    );
  }
}
