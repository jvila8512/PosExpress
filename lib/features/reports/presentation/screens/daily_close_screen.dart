import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import 'package:etecsa/config/theme/app_colors.dart';

// ---------------------------------------------------------------------------
// Daily Close Screen
// ---------------------------------------------------------------------------
///
/// Muestra el resumen de cierre del día con métricas principales.
/// Pantalla placeholder que se integrará con la lógica de DailySummaries.

class DailyCloseScreen extends ConsumerStatefulWidget {
  const DailyCloseScreen({super.key});

  @override
  ConsumerState<DailyCloseScreen> createState() =>
      _DailyCloseScreenState();
}

class _DailyCloseScreenState extends ConsumerState<DailyCloseScreen> {
  @override
  Widget build(BuildContext context) {
    final colors = AppColors.forBrightness(Theme.of(context).brightness);
    final theme = Theme.of(context);
    final today = DateFormat('EEEE, dd/MM/yyyy').format(DateTime.now());
    final dateStr =
        '${DateTime.now().year}-${DateTime.now().month.toString().padLeft(2, '0')}-${DateTime.now().day.toString().padLeft(2, '0')}';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Cierre del Día'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Header
          Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  Icon(Icons.check_circle_outline,
                      size: 56, color: colors.success),
                  const SizedBox(height: 12),
                  Text(
                    'Resumen del Día',
                    style: theme.textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    today,
                    style: theme.textTheme.bodyMedium
                        ?.copyWith(color: colors.textSecondary),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    dateStr,
                    style: theme.textTheme.bodySmall?.copyWith(
                        color: colors.textSecondary),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Métricas placeholder
          _buildMetricCard(
            'Ventas del día',
            'Pendiente de calcular',
            Icons.trending_up,
            colors.success,
            colors,
            theme,
          ),
          const SizedBox(height: 8),
          _buildMetricCard(
            'Gastos del día',
            'Pendiente de calcular',
            Icons.shopping_cart,
            colors.warning,
            colors,
            theme,
          ),
          const SizedBox(height: 8),
          _buildMetricCard(
            'Utilidad estimada',
            'Pendiente de calcular',
            Icons.savings,
            colors.accent,
            colors,
            theme,
          ),
          const SizedBox(height: 24),

          // Info card
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(Icons.info_outline,
                      size: 20, color: colors.textSecondary),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'El resumen completo del cierre se generará al procesar las ventas del día. Esta funcionalidad estará disponible en la próxima actualización.',
                      style: theme.textTheme.bodySmall?.copyWith(
                          color: colors.textSecondary),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricCard(
    String label,
    String value,
    IconData icon,
    Color iconColor,
    AppColorsTheme colors,
    ThemeData theme,
  ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: iconColor, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: colors.textSecondary),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    value,
                    style: GoogleFonts.jetBrainsMono(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: colors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
