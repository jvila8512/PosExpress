import 'package:flutter/material.dart';
import 'package:etecsa/config/theme/app_theme.dart';

class KPICardsRow extends StatelessWidget {
  final Map<String, dynamic> data;
  final bool isVendedor;

  const KPICardsRow({super.key, required this.data, this.isVendedor = false});

  @override
  Widget build(BuildContext context) {
    final todaySales = data['todaySales'] as double;
    final yesterdaySales = data['yesterdaySales'] as double;
    final todayTransactions = data['todayTransactions'] as int;
    final monthlyAvgTransactions = data['monthlyAvgTransactions'] as double;
    final todayProfit = data['todayProfit'] as double;
    final todayAverageTicket = data['todayAverageTicket'] as double;

    double salesChange = 0;
    if (yesterdaySales > 0) {
      salesChange = ((todaySales - yesterdaySales) / yesterdaySales) * 100;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'MÉTRICAS DE HOY',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Colors.grey,
                letterSpacing: 1,
              ),
            ),
            Text(
              _getDateRange(),
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _KPICard(
                title: 'Ventas',
                value: '\$${todaySales.toStringAsFixed(0)}',
                subtitle: _getChangeText(salesChange),
                icon: Icons.attach_money,
                color: const Color(0xFF1D9E75),
                change: salesChange,
                tooltip: 'Total de dinero cobrado hoy por todas las ventas',
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _KPICard(
                title: 'Tickets',
                value: '$todayTransactions',
                subtitle: monthlyAvgTransactions > 0
                    ? 'Prom: ${monthlyAvgTransactions.toStringAsFixed(1)}/día'
                    : 'Sin datos',
                icon: Icons.receipt_long,
                color: const Color(0xFF378ADD),
                tooltip: 'Cantidad de ventas realizadas hoy',
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            // Vendedor NO ve Ganancia — solo ve Ventas + Tickets + Ticket$
            if (!isVendedor)
              Expanded(
                child: _KPICard(
                  title: 'Ganancia',
                  value: '\$${todayProfit.toStringAsFixed(0)}',
                  subtitle: todaySales > 0
                      ? 'Margen: ${((todayProfit / todaySales) * 100).toStringAsFixed(1)}%'
                      : 'Sin ventas',
                  icon: Icons.trending_up,
                  color: AppTheme.colorMorado,
                  tooltip: 'Dinero ganado después de descontar el costo de los productos',
                ),
              ),
            if (!isVendedor) const SizedBox(width: 12),
            Expanded(
              child: _KPICard(
                title: 'Ticket \$',
                value: '\$${todayAverageTicket.toStringAsFixed(0)}',
                subtitle: todayTransactions > 0
                    ? '$todayTransactions ventas'
                    : 'Sin ventas',
                icon: Icons.shopping_bag_outlined,
                color: const Color(0xFFEF9F27),
                tooltip: 'Promedio de dinero por venta (ventas ÷ tickets)',
              ),
            ),
          ],
        ),
      ],
    );
  }

  String _getDateRange() {
    final now = DateTime.now();
    final months = ['Ene', 'Feb', 'Mar', 'Abr', 'May', 'Jun',
      'Jul', 'Ago', 'Sep', 'Oct', 'Nov', 'Dic'];
    return '${now.day} ${months[now.month - 1]} ${now.year}';
  }

  String _getChangeText(double change) {
    if (change > 0) {
      return '+${change.toStringAsFixed(1)}% vs ayer';
    } else if (change < 0) {
      return '${change.toStringAsFixed(1)}% vs ayer';
    } else {
      return 'Sin cambios vs ayer';
    }
  }
}

class _KPICard extends StatelessWidget {
  final String title;
  final String value;
  final String subtitle;
  final IconData icon;
  final Color color;
  final double? change;
  final String? tooltip;

  const _KPICard({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.icon,
    required this.color,
    this.change,
    this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.12),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 18),
              ),
              const Spacer(),
              if (tooltip != null)
                GestureDetector(
                  onTap: () {
                    final overlay = Overlay.of(context);
                    late OverlayEntry entry;
                    entry = OverlayEntry(
                      builder: (_) => _TooltipOverlay(
                        text: tooltip!,
                        onDismiss: () => entry.remove(),
                      ),
                    );
                    overlay.insert(entry);
                  },
                  child: Padding(
                    padding: EdgeInsets.only(left: 4, right: change != null ? 4 : 0),
                    child: Icon(
                      Icons.info_outline,
                      size: 16,
                      color: Colors.grey[400],
                    ),
                  ),
                ),
              if (change != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                  decoration: BoxDecoration(
                    color: change! >= 0
                        ? const Color(0xFF1D9E75).withValues(alpha: 0.1)
                        : Colors.red.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        change! >= 0 ? Icons.arrow_upward : Icons.arrow_downward,
                        size: 11,
                        color: change! >= 0 ? const Color(0xFF1D9E75) : Colors.red,
                      ),
                      const SizedBox(width: 2),
                      Text(
                        '${change!.abs().toStringAsFixed(0)}%',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: change! >= 0 ? const Color(0xFF1D9E75) : Colors.red,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.bold,
                color: color,
                height: 1.1,
              ),
              maxLines: 1,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 11,
              color: Colors.grey[500],
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

/// Floating tooltip overlay that appears near the info icon and auto-dismisses.
class _TooltipOverlay extends StatefulWidget {
  final String text;
  final VoidCallback onDismiss;

  const _TooltipOverlay({required this.text, required this.onDismiss});

  @override
  State<_TooltipOverlay> createState() => _TooltipOverlayState();
}

class _TooltipOverlayState extends State<_TooltipOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
    );
    _opacity = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    _controller.forward();

    // Auto-dismiss after 3 seconds
    Future.delayed(const Duration(seconds: 3), _dismiss);
  }

  void _dismiss() {
    if (!mounted) return;
    _controller.reverse().then((_) => widget.onDismiss());
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: GestureDetector(
        onTap: _dismiss,
        behavior: HitTestBehavior.opaque,
        child: Container(
          color: Colors.black.withValues(alpha: 0.15),
          child: FadeTransition(
            opacity: _opacity,
            child: Center(
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 40),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                decoration: BoxDecoration(
                  color: Colors.grey[800],
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.3),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Text(
                  widget.text,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
