import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:etecsa/config/theme/app_colors.dart';

/// A live count-up timer for orders, styled with JetBrains Mono.
///
/// Changes color based on elapsed time relative to [timeObjective]:
/// - elapsed < 75% → [defaultColor] (usually text-primary / accent)
/// - 75% ≤ elapsed < 100% → [warningColor] (Mostaza)
/// - elapsed ≥ 100% → [dangerColor] (Guayaba)
///
/// The timer ticks every second via [Timer.periodic].
class OrderTimer extends StatefulWidget {
  /// When the order started (e.g. `order.createdAt`).
  final DateTime startTime;

  /// The time objective the kitchen/process should meet.
  /// Defaults to 15 minutes.
  final Duration timeObjective;

  /// Color when well within the time objective (< 75%).
  final Color? defaultColor;

  /// Color when approaching the time objective (75%–99%).
  final Color? warningColor;

  /// Color when the time objective has been exceeded (≥ 100%).
  final Color? dangerColor;

  /// Font size for the timer display. Defaults to 16.
  final double fontSize;

  /// Whether to show a small icon next to the time.
  final bool showIcon;

  /// Callback fired every second with the elapsed [Duration].
  final void Function(Duration elapsed)? onTick;

  const OrderTimer({
    super.key,
    required this.startTime,
    this.timeObjective = const Duration(minutes: 15),
    this.defaultColor,
    this.warningColor,
    this.dangerColor,
    this.fontSize = 16,
    this.showIcon = false,
    this.onTick,
  });

  @override
  State<OrderTimer> createState() => _OrderTimerState();
}

class _OrderTimerState extends State<OrderTimer> {
  Timer? _timer;
  Duration _elapsed = Duration.zero;

  @override
  void initState() {
    super.initState();
    _updateElapsed();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      _updateElapsed();
    });
  }

  @override
  void didUpdateWidget(OrderTimer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.startTime != widget.startTime) {
      _updateElapsed();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _updateElapsed() {
    final now = DateTime.now();
    final elapsed = now.difference(widget.startTime);
    if (elapsed != _elapsed) {
      setState(() => _elapsed = elapsed);
      widget.onTick?.call(elapsed);
    }
  }

  /// Returns the display string (MM:SS).
  String get _formatted {
    final minutes = _elapsed.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = _elapsed.inSeconds.remainder(60).toString().padLeft(2, '0');
    final hours = _elapsed.inHours;
    if (hours > 0) {
      return '${hours.toString().padLeft(2, '0')}:$minutes:$seconds';
    }
    return '$minutes:$seconds';
  }

  /// Resolves the timer color based on progress toward [widget.timeObjective].
  Color _resolveColor(Brightness brightness) {
    final objectiveMs = widget.timeObjective.inMilliseconds;
    if (objectiveMs <= 0) return widget.defaultColor ?? AppColors.forBrightness(brightness).textPrimary;

    final elapsedMs = _elapsed.inMilliseconds;
    final progress = elapsedMs / objectiveMs; // 0.0 → 1.0+

    if (progress >= 1.0) {
      return widget.dangerColor ?? AppColors.forBrightness(brightness).danger;
    } else if (progress >= 0.75) {
      return widget.warningColor ?? AppColors.forBrightness(brightness).warning;
    } else {
      return widget.defaultColor ?? AppColors.forBrightness(brightness).textPrimary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final color = _resolveColor(brightness);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (widget.showIcon) ...[
          Icon(
            Icons.timer_outlined,
            size: widget.fontSize * 1.2,
            color: color,
          ),
          const SizedBox(width: 4),
        ],
        Text(
          _formatted,
          style: GoogleFonts.jetBrainsMono(
            fontSize: widget.fontSize,
            fontWeight: FontWeight.w600,
            color: color,
            height: 1.0,
          ),
        ),
      ],
    );
  }
}
