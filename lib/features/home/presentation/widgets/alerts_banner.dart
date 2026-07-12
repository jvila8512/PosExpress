import 'package:flutter/material.dart';

class AlertsBanner extends StatefulWidget {
  final Map<String, dynamic> data;

  const AlertsBanner({super.key, required this.data});

  @override
  State<AlertsBanner> createState() => _AlertsBannerState();
}

class _AlertsBannerState extends State<AlertsBanner> {
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _showStockBottomSheet({
    required String title,
    required Color headerColor,
    required List<Map<String, dynamic>> products,
    required bool showStock,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        final maxHeight = MediaQuery.of(context).size.height * 0.6;
        return ConstrainedBox(
          constraints: BoxConstraints(maxHeight: maxHeight),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle bar
              Container(
                margin: const EdgeInsets.only(top: 8),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              // Header
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: headerColor.withValues(alpha: 0.1),
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                ),
                child: Row(
                  children: [
                    Icon(
                      showStock ? Icons.inventory_2 : Icons.warning,
                      color: headerColor,
                      size: 22,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: headerColor,
                            ),
                          ),
                          Text(
                            '${products.length} producto${products.length != 1 ? 's' : ''}',
                            style: TextStyle(
                              fontSize: 12,
                              color: headerColor.withValues(alpha: 0.7),
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              // Product list
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  itemCount: products.length,
                  itemBuilder: (context, index) {
                    final product = products[index];
                    final name = product['name'] as String? ?? 'Sin nombre';
                    final stock = product['stock'] as double?;
                    final code = product['code'] as String?;

                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: Row(
                        children: [
                          // Stock indicator
                          if (stock != null)
                            Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: stock == 0
                                    ? Colors.red.shade50
                                    : Colors.orange.shade50,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Center(
                                child: Text(
                                  stock == 0 ? '0' : stock.toInt().toString(),
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: stock == 0
                                        ? Colors.red
                                        : Colors.orange.shade700,
                                  ),
                                ),
                              ),
                            )
                          else
                            Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: Colors.red.shade50,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(
                                Icons.inventory_2_outlined,
                                color: Colors.red.shade400,
                                size: 22,
                              ),
                            ),
                          const SizedBox(width: 12),
                          // Product info
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  name,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                if (code != null && code.isNotEmpty)
                                  Text(
                                    'Código: $code',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: Colors.grey.shade500,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          // Stock label
                          if (stock != null)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: stock == 0
                                    ? Colors.red.shade50
                                    : Colors.orange.shade50,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                stock == 0 ? 'Agotado' : 'Crítico',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color: stock == 0
                                      ? Colors.red
                                      : Colors.orange.shade700,
                                ),
                              ),
                            ),
                        ],
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    // Collect all alerts
    final alerts = <Map<String, dynamic>>[];

    // Critical alerts (red) — with product data for bottom sheet
    final outOfStock = widget.data['outOfStockAlerts'] as List<Map<String, dynamic>>;
    if (outOfStock.isNotEmpty) {
      alerts.add({
        'type': 'critical',
        'title': 'Stock agotado',
        'message': '${outOfStock.length} productos agotados que vendiste esta semana',
        'icon': Icons.warning,
        'products': outOfStock,
        'showStock': false,
        'headerColor': const Color(0xFFDC2626),
      });
    }

    final cashDiffs = widget.data['cashDifferenceAlerts'] as List<Map<String, dynamic>>;
    if (cashDiffs.isNotEmpty) {
      alerts.add({
        'type': 'critical',
        'title': 'Diferencia de caja',
        'message': '${cashDiffs.length} sesiones con diferencias detectadas',
        'icon': Icons.money_off,
      });
    }

    // Warning alerts (yellow) — with product data for bottom sheet
    final criticalStock = widget.data['criticalStockAlerts'] as List<Map<String, dynamic>>;
    if (criticalStock.isNotEmpty) {
      alerts.add({
        'type': 'warning',
        'title': 'Stock crítico',
        'message': '${criticalStock.length} productos con menos de 5 unidades',
        'icon': Icons.inventory,
        'products': criticalStock,
        'showStock': true,
        'headerColor': const Color(0xFFF59E0B),
      });
    }

    final lowSales = widget.data['lowSalesAlert'] as Map<String, dynamic>?;
    if (lowSales != null) {
      final todaySales = lowSales['todaySales'] as double;
      final avgSales = lowSales['averageSales'] as double;
      alerts.add({
        'type': 'warning',
        'title': 'Ventas bajas',
        'message': 'Hoy: \$${todaySales.toStringAsFixed(0)} (promedio: \$${avgSales.toStringAsFixed(0)})',
        'icon': Icons.trending_down,
      });
    }

    // Positive alerts (green)
    final highSales = widget.data['highSalesAlert'] as Map<String, dynamic>?;
    if (highSales != null) {
      final percentage = highSales['percentage'] as double;
      alerts.add({
        'type': 'positive',
        'title': '¡Excelente día!',
        'message': 'Ventas ${percentage.toStringAsFixed(0)}% por encima del promedio',
        'icon': Icons.celebration,
      });
    }

    if (alerts.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      constraints: const BoxConstraints(maxHeight: 100),
      child: ListView.separated(
        controller: _scrollController,
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(vertical: 4),
        itemCount: alerts.length,
        separatorBuilder: (context, index) => const SizedBox(width: 12),
        itemBuilder: (context, index) {
          final alert = alerts[index];
          final products = alert['products'] as List<Map<String, dynamic>>?;
          final hasProducts = products != null && products.isNotEmpty;

          return GestureDetector(
            onTap: hasProducts
                ? () => _showStockBottomSheet(
                      title: alert['title'] as String,
                      headerColor: alert['headerColor'] as Color,
                      products: products,
                      showStock: alert['showStock'] as bool,
                    )
                : null,
            child: _AlertCard(
              type: alert['type'] as String,
              title: alert['title'] as String,
              message: alert['message'] as String,
              icon: alert['icon'] as IconData,
              isClickable: hasProducts,
            ),
          );
        },
      ),
    );
  }
}

class _AlertCard extends StatelessWidget {
  final String type;
  final String title;
  final String message;
  final IconData icon;
  final bool isClickable;

  const _AlertCard({
    required this.type,
    required this.title,
    required this.message,
    required this.icon,
    this.isClickable = false,
  });

  @override
  Widget build(BuildContext context) {
    Color backgroundColor;
    Color borderColor;
    Color textColor;

    switch (type) {
      case 'critical':
        backgroundColor = const Color(0xFFFEE2E2);
        borderColor = const Color(0xFFE24B4A);
        textColor = const Color(0xFFDC2626);
        break;
      case 'warning':
        backgroundColor = const Color(0xFFFEF3C7);
        borderColor = const Color(0xFFF59E0B);
        textColor = const Color(0xFFD97706);
        break;
      case 'positive':
        backgroundColor = const Color(0xFFD1FAE5);
        borderColor = const Color(0xFF1D9E75);
        textColor = const Color(0xFF059669);
        break;
      default:
        backgroundColor = Colors.grey[100]!;
        borderColor = Colors.grey[400]!;
        textColor = Colors.grey[700]!;
    }

    return Container(
      width: 220,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: borderColor.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(icon, color: textColor, size: 16),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: textColor,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (isClickable)
                Icon(Icons.chevron_right, color: textColor.withValues(alpha: 0.6), size: 16),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            message,
            style: TextStyle(
              fontSize: 11,
              color: textColor.withValues(alpha: 0.8),
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}