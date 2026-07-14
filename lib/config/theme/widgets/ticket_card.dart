import 'package:flutter/material.dart';

/// A card styled like a restaurant ticket stub with:
/// - A dashed border (simulated via a [CustomPainter])
/// - Two decorative circles at the top (left & right) simulating torn holes
/// - Optional header area in Bungee font
/// - [child] content below the header
class TicketCard extends StatelessWidget {
  final Widget? header;
  final Widget child;
  final EdgeInsetsGeometry margin;
  final EdgeInsetsGeometry padding;
  final Color? backgroundColor;
  final double? width;

  const TicketCard({
    super.key,
    this.header,
    required this.child,
    this.margin = const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    this.padding = const EdgeInsets.all(16),
    this.backgroundColor,
    this.width,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bg = backgroundColor ?? theme.colorScheme.surface;
    final borderColor = theme.colorScheme.onSurface.withValues(alpha: 0.15);

    return Container(
      width: width,
      margin: margin,
      child: CustomPaint(
        painter: _DashedBorderPainter(
          color: borderColor,
          strokeWidth: 1.5,
          dashLength: 6,
          gapLength: 4,
        ),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Decorative circles at top (torn holes)
              if (header != null) ...[
                _TicketTopHoles(borderColor: borderColor),
                const SizedBox(height: 8),
                header!,
                const SizedBox(height: 8),
              ],
              // Dashed separator below header
              if (header != null)
                _DashedLine(color: borderColor),
              // Main content
              Padding(
                padding: EdgeInsets.only(top: header != null ? 12 : 0),
                child: child,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Two small circles at the top simulating ticket torn holes.
class _TicketTopHoles extends StatelessWidget {
  final Color borderColor;

  const _TicketTopHoles({required this.borderColor});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 14,
          height: 14,
          margin: const EdgeInsets.only(left: 20),
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor,
            shape: BoxShape.circle,
            border: Border.all(color: borderColor, width: 1),
          ),
        ),
        const Spacer(),
        Container(
          width: 14,
          height: 14,
          margin: const EdgeInsets.only(right: 20),
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor,
            shape: BoxShape.circle,
            border: Border.all(color: borderColor, width: 1),
          ),
        ),
      ],
    );
  }
}

/// A horizontal dashed line.
class _DashedLine extends StatelessWidget {
  final Color color;

  const _DashedLine({required this.color});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: const Size(double.infinity, 1),
      painter: _DashedLinePainter(color: color),
    );
  }
}

/// Paints dashed lines for both the outer border and inner dividers.
class _DashedBorderPainter extends CustomPainter {
  final Color color;
  final double strokeWidth;
  final double dashLength;
  final double gapLength;

  _DashedBorderPainter({
    required this.color,
    this.strokeWidth = 1.5,
    this.dashLength = 6,
    this.gapLength = 4,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke;

    final path = Path()
      ..addRRect(RRect.fromRectAndRadius(
        Rect.fromLTWH(0, 0, size.width, size.height),
        const Radius.circular(16),
      ));

    // Draw dashed path manually
    final pathMetrics = path.computeMetrics();
    for (final metric in pathMetrics) {
      double distance = 0;
      while (distance < metric.length) {
        final dashEnd = (distance + dashLength).clamp(0.0, metric.length) as double;
        final segment = metric.extractPath(distance, dashEnd);
        canvas.drawPath(segment, paint);
        distance += dashLength + gapLength;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DashedBorderPainter oldDelegate) =>
      oldDelegate.color != color ||
      oldDelegate.strokeWidth != strokeWidth ||
      oldDelegate.dashLength != dashLength ||
      oldDelegate.gapLength != gapLength;
}

/// Paints a single horizontal dashed line.
class _DashedLinePainter extends CustomPainter {
  final Color color;

  _DashedLinePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1;

    const dashLength = 6.0;
    const gapLength = 4.0;
    double startX = 0;

    while (startX < size.width) {
      final endX = (startX + dashLength).clamp(0.0, size.width) as double;
      canvas.drawLine(Offset(startX, 0), Offset(endX, 0), paint);
      startX += dashLength + gapLength;
    }
  }

  @override
  bool shouldRepaint(covariant _DashedLinePainter oldDelegate) =>
      oldDelegate.color != color;
}
