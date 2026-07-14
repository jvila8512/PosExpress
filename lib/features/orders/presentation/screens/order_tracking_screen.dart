import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:etecsa/config/theme/app_colors.dart';
import 'package:etecsa/config/theme/widgets/status_badge.dart';
import 'package:etecsa/config/theme/widgets/ticket_card.dart';
import 'package:etecsa/config/theme/widgets/order_timer.dart';
import 'package:etecsa/features/orders/domain/entities/restaurant_order.dart';
import 'package:etecsa/features/orders/presentation/providers/order_provider.dart';

// ---------------------------------------------------------------------------
// Redes Order Tracking Screen
// ---------------------------------------------------------------------------
///
/// Muestra los pedidos de hoy con estado en vivo.
/// Se auto-refresca cada 5 segundos.
/// Cada pedido muestra: folio (JetBrains Mono), StatusBadge, OrderTimer,
/// datos del cliente, items y total.

class OrderTrackingScreen extends ConsumerStatefulWidget {
  const OrderTrackingScreen({super.key});

  @override
  ConsumerState<OrderTrackingScreen> createState() =>
      _OrderTrackingScreenState();
}

class _OrderTrackingScreenState extends ConsumerState<OrderTrackingScreen> {
  Timer? _refreshTimer;
  bool _isInitialLoad = true;

  @override
  void initState() {
    super.initState();
    _loadOrders();
    // Auto-refresh cada 5 segundos
    _refreshTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      _loadOrders();
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadOrders() async {
    await ref.read(orderProvider.notifier).loadTodayOrders();
    if (mounted) {
      setState(() => _isInitialLoad = false);
    }
  }

  // ─────────────────────────────────────────────────────────────────────
  // BUILD
  // ─────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.forBrightness(Theme.of(context).brightness);
    final theme = Theme.of(context);

    final notifier = ref.read(orderProvider.notifier);
    final orders = notifier.orders as List<RestaurantOrder>;
    final isLoading = notifier.isLoading;
    final error = notifier.error;

    // Agrupar órdenes por estado
    final grouped = <String, List<RestaurantOrder>>{};
    for (final order in orders) {
      final label = StatusBadge.labelFor(order.estado);
      grouped.putIfAbsent(label, () => []);
      grouped[label]!.add(order);
    }

    // Orden de visualización de grupos
    final groupOrder = [
      'Registrado',
      'En cocina',
      'Listo',
      'En camino',
      'Entregado',
      'Cancelado',
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text('Pedidos de Hoy (${orders.length})'),
        actions: [
          if (isLoading)
            const Padding(
              padding: EdgeInsets.only(right: 16),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refrescar',
            onPressed: _loadOrders,
          ),
        ],
      ),
      body: _buildBody(colors, theme, orders, grouped, groupOrder, isLoading, error),
    );
  }

  Widget _buildBody(
    AppColorsTheme colors,
    ThemeData theme,
    List<RestaurantOrder> orders,
    Map<String, List<RestaurantOrder>> grouped,
    List<String> groupOrder,
    bool isLoading,
    String? error,
  ) {
    if (_isInitialLoad && isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (error != null && orders.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline,
                  size: 64, color: colors.danger.withValues(alpha: 0.6)),
              const SizedBox(height: 16),
              Text('Error al cargar pedidos',
                  style: theme.textTheme.titleMedium),
              const SizedBox(height: 8),
              Text(error,
                  style: theme.textTheme.bodySmall?.copyWith(
                      color: colors.textSecondary),
                  textAlign: TextAlign.center),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: _loadOrders,
                icon: const Icon(Icons.refresh, size: 18),
                label: const Text('Reintentar'),
              ),
            ],
          ),
        ),
      );
    }

    if (orders.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.receipt_long_outlined,
                size: 80, color: colors.textSecondary.withValues(alpha: 0.3)),
            const SizedBox(height: 16),
            Text('No hay pedidos hoy',
                style: theme.textTheme.titleLarge?.copyWith(
                    color: colors.textSecondary)),
            const SizedBox(height: 8),
            Text('Los pedidos nuevos aparecerán aquí automáticamente.',
                style: theme.textTheme.bodyMedium?.copyWith(
                    color: colors.textSecondary),
                textAlign: TextAlign.center),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadOrders,
      child: ListView(
        padding: const EdgeInsets.only(top: 8, bottom: 24),
        children: [
          for (final groupName in groupOrder)
            if (grouped.containsKey(groupName)) ...[
              _buildGroupHeader(colors, theme, groupName,
                  grouped[groupName]!.length),
              ...grouped[groupName]!.map(
                (order) => _buildOrderCard(order, colors, theme),
              ),
              const SizedBox(height: 8),
            ],
          // Grupos no listados en groupOrder
          for (final entry in grouped.entries)
            if (!groupOrder.contains(entry.key)) ...[
              _buildGroupHeader(
                  colors, theme, entry.key, entry.value.length),
              ...entry.value.map(
                (order) => _buildOrderCard(order, colors, theme),
              ),
              const SizedBox(height: 8),
            ],
        ],
      ),
    );
  }

  // ─── HEADER DE GRUPO ─────────────────────────────────────────────────

  Widget _buildGroupHeader(
    AppColorsTheme colors,
    ThemeData theme,
    String label,
    int count,
  ) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Row(
        children: [
          Text(
            label,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: colors.accent.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '$count',
              style: GoogleFonts.jetBrainsMono(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: colors.accent,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── TARJETA DE PEDIDO ──────────────────────────────────────────────

  Widget _buildOrderCard(
    RestaurantOrder order,
    AppColorsTheme colors,
    ThemeData theme,
  ) {
    return TicketCard(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      padding: const EdgeInsets.all(14),
      header: _buildTicketHeader(order, colors, theme),
      child: _buildTicketBody(order, colors, theme),
    );
  }

  Widget _buildTicketHeader(
    RestaurantOrder order,
    AppColorsTheme colors,
    ThemeData theme,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Folio + Estado
        Row(
          children: [
            // Folio en JetBrains Mono
            Text(
              order.id,
              style: GoogleFonts.jetBrainsMono(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: colors.textPrimary,
              ),
            ),
            const Spacer(),
            StatusBadge(state: order.estado),
          ],
        ),
        const SizedBox(height: 8),
        // Timer
        if (order.fechaCreacion != null)
          Align(
            alignment: Alignment.centerRight,
            child: OrderTimer(
              startTime: order.fechaCreacion!,
              timeObjective: const Duration(minutes: 15),
              fontSize: 14,
              showIcon: true,
            ),
          ),
      ],
    );
  }

  Widget _buildTicketBody(
    RestaurantOrder order,
    AppColorsTheme colors,
    ThemeData theme,
  ) {
    // Items
    final items = order.items;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Lista de items
        if (items.isNotEmpty) ...[
          for (final item in items)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                children: [
                  Text(
                    '${item.qty}x',
                    style: GoogleFonts.jetBrainsMono(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: colors.accent,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      item.code,
                      style: theme.textTheme.bodyMedium,
                    ),
                  ),
                  Text(
                    '\$${(item.subtotal).toStringAsFixed(2)}',
                    style: GoogleFonts.jetBrainsMono(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: colors.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 4),
          const Divider(height: 1),
          const SizedBox(height: 4),
          // Total
          Row(
            children: [
              const Spacer(),
              Text(
                'Total: ',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colors.textSecondary,
                ),
              ),
              Text(
                '\$${order.montoTotal.toStringAsFixed(2)}',
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: colors.accent,
                ),
              ),
            ],
          ),
        ] else
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text('Sin items',
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: colors.textSecondary)),
          ),
      ],
    );
  }
}
