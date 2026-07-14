import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:etecsa/config/theme/app_colors.dart';
import 'package:etecsa/config/theme/widgets/ticket_card.dart';
import 'package:etecsa/config/theme/widgets/order_timer.dart';
import 'package:etecsa/features/orders/domain/entities/restaurant_order.dart';
import 'package:etecsa/features/orders/domain/entities/order_state.dart';
import 'package:etecsa/features/orders/presentation/providers/order_provider.dart';
import 'package:etecsa/features/clients/domain/entities/restaurant_client.dart';
import 'package:etecsa/features/clients/presentation/providers/client_provider.dart';

// ---------------------------------------------------------------------------
// Delivery List Screen — Pedidos para Entregar
// ---------------------------------------------------------------------------
///
/// Muestra los pedidos en estado `enCamino` de tipo `DOMICILIO`,
/// ordenados del más antiguo al más reciente.
///
/// Características:
/// - Auto-refresh cada 5 segundos
/// - Pull-to-refresh
/// - Cada tarjeta muestra: datos del cliente (nombre grande, teléfono con
///   botón de llamada, dirección, referencia), items del pedido, total,
///   timer desde que salió de cocina, y botón "Marcar entregado" que
///   solicita método de cobro (EF/TR/PD) antes de cambiar el estado.
class DeliveryListScreen extends ConsumerStatefulWidget {
  const DeliveryListScreen({super.key});

  @override
  ConsumerState<DeliveryListScreen> createState() =>
      _DeliveryListScreenState();
}

class _DeliveryListScreenState extends ConsumerState<DeliveryListScreen> {
  Timer? _refreshTimer;
  bool _isInitialLoad = true;
  Map<String, RestaurantClient> _clientMap = {};

  // ─── LIFECYCLE ──────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _loadDeliveries();
    _loadClients();
    // Auto-refresh cada 5 segundos (solo órdenes, no clientes)
    _refreshTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      _loadDeliveries();
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  // ─── DATA LOADING ──────────────────────────────────────────────

  Future<void> _loadDeliveries() async {
    await ref.read(orderProvider.notifier).loadTodayOrders();
    if (mounted) {
      setState(() => _isInitialLoad = false);
    }
  }

  Future<void> _loadClients() async {
    await ref.read(clientProvider.notifier).loadAll();
    if (mounted) {
      final clientsAsync = ref.read(clientProvider);
      if (clientsAsync is AsyncData<List<RestaurantClient>>) {
        setState(() {
          _clientMap = {
            for (final c in clientsAsync.value) c.id: c,
          };
        });
      }
    }
  }

  Future<void> _onRefresh() async {
    await Future.wait([
      _loadDeliveries(),
      _loadClients(),
    ]);
  }

  // ─── BUILD ──────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.forBrightness(Theme.of(context).brightness);
    final theme = Theme.of(context);

    final notifier = ref.read(orderProvider.notifier);
    final allOrders = notifier.orders as List<RestaurantOrder>;
    final isLoading = notifier.isLoading;
    final error = notifier.error;

    // Filtrar pedidos DOMICILIO en estado enCamino, ordenar por más antiguo
    final deliveryOrders = allOrders
        .where((o) =>
            o.tipoPedido == 'DOMICILIO' && o.estado == OrderState.enCamino)
        .toList()
      ..sort((a, b) {
        final aTime = a.fechaCreacion ?? DateTime.now();
        final bTime = b.fechaCreacion ?? DateTime.now();
        return aTime.compareTo(bTime);
      });

    return Scaffold(
      appBar: AppBar(
        title: Text('Domicilio (${deliveryOrders.length})'),
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
            onPressed: _onRefresh,
          ),
        ],
      ),
      body: _buildBody(colors, theme, deliveryOrders, isLoading, error),
    );
  }

  // ─── BODY ──────────────────────────────────────────────────────

  Widget _buildBody(
    AppColorsTheme colors,
    ThemeData theme,
    List<RestaurantOrder> orders,
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
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: colors.textSecondary),
                  textAlign: TextAlign.center),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: _onRefresh,
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
            Icon(Icons.directions_bike_outlined,
                size: 80,
                color: colors.textSecondary.withValues(alpha: 0.3)),
            const SizedBox(height: 16),
            Text('No hay pedidos para entregar',
                style: theme.textTheme.titleLarge
                    ?.copyWith(color: colors.textSecondary)),
            const SizedBox(height: 8),
            Text(
              'Los pedidos en camino aparecerán aquí.',
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: colors.textSecondary),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _onRefresh,
      child: ListView(
        padding: const EdgeInsets.only(top: 8, bottom: 24),
        children: orders
            .map((order) => _buildDeliveryCard(
                  order,
                  _clientMap[order.clienteId],
                  colors,
                  theme,
                ))
            .toList(),
      ),
    );
  }

  // ─── DELIVERY CARD ─────────────────────────────────────────────

  Widget _buildDeliveryCard(
    RestaurantOrder order,
    RestaurantClient? client,
    AppColorsTheme colors,
    ThemeData theme,
  ) {
    return TicketCard(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      padding: const EdgeInsets.all(14),
      child: _buildDeliveryContent(order, client, colors, theme),
    );
  }

  Widget _buildDeliveryContent(
    RestaurantOrder order,
    RestaurantClient? client,
    AppColorsTheme colors,
    ThemeData theme,
  ) {
    final clientName = client?.nombre ?? 'Cliente #${order.clienteId}';
    final clientPhone = client?.telefono ?? '';
    final address = client?.direccion ?? '';
    final reference = client?.referencia ?? '';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ── Header: Client name + Timer ──────────────────
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Text(
                clientName,
                style: GoogleFonts.bungee(
                  fontSize: 18,
                  color: colors.textPrimary,
                ),
              ),
            ),
            if (order.fechaCreacion != null)
              OrderTimer(
                startTime: order.fechaCreacion!,
                fontSize: 14,
              ),
          ],
        ),
        const SizedBox(height: 6),

        // ── Phone + Call button ──────────────────────────
        if (clientPhone.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: () => _launchPhone(clientPhone),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Icon(Icons.phone,
                        size: 16, color: colors.textSecondary),
                    const SizedBox(width: 6),
                    Text(
                      clientPhone,
                      style: GoogleFonts.jetBrainsMono(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: colors.textPrimary,
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: colors.success.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.call,
                              size: 14, color: colors.success),
                          const SizedBox(width: 4),
                          Text(
                            'Llamar',
                            style: GoogleFonts.dmSans(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: colors.success,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

        // ── Address ────────────────────────────────────
        if (address.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.location_on_outlined,
                    size: 16, color: colors.textSecondary),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    address,
                    style: theme.textTheme.bodyMedium,
                  ),
                ),
              ],
            ),
          ),

        // ── Reference ──────────────────────────────────
        if (reference.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.notes_rounded,
                    size: 16, color: colors.textSecondary),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Ref: $reference',
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: colors.textSecondary),
                  ),
                ),
              ],
            ),
          ),

        // ── Separator ──────────────────────────────────
        const Divider(height: 1),
        const SizedBox(height: 8),

        // ── Order items ─────────────────────────────────
        if (order.items.isNotEmpty) ...[
          for (final item in order.items)
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
                    '\$${item.subtotal.toStringAsFixed(2)}',
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
              Text(
                'Total: ',
                style: theme.textTheme.bodyMedium
                    ?.copyWith(color: colors.textSecondary),
              ),
              const Spacer(),
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
          const SizedBox(height: 12),
        ] else ...[
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text('Sin items',
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: colors.textSecondary)),
          ),
          const SizedBox(height: 8),
        ],

        // ── "Marcar entregado" button ──────────────────
        FilledButton.icon(
          onPressed: () => _showDeliverDialog(order, client),
          icon: const Icon(Icons.check_circle_outline, size: 18),
          label: const Text('Marcar entregado'),
        ),
      ],
    );
  }

  // ─── PHONE LAUNCHER ────────────────────────────────────────────

  Future<void> _launchPhone(String phone) async {
    final uri = Uri.parse('tel:$phone');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  // ─── DELIVER DIALOG ───────────────────────────────────────────

  /// Muestra un diálogo para seleccionar el método de cobro y confirmar
  /// la entrega. Al confirmar actualiza el `metodoPago` de la orden y
  /// cambia el estado a `entregado` (lo que dispara el SMS ENT).
  Future<void> _showDeliverDialog(
      RestaurantOrder order, RestaurantClient? client) async {
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) {
        String? selectedMethod;
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Marcar como entregado'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Cliente: ${client?.nombre ?? order.clienteId}',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Total: \$${order.montoTotal.toStringAsFixed(2)}',
                    style: GoogleFonts.jetBrainsMono(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: AppColors.accent,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Método de cobro:',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const SizedBox(height: 4),
                  RadioListTile<String>(
                    title: const Text('Efectivo (EF)'),
                    value: 'EF',
                    groupValue: selectedMethod,
                    onChanged: (v) =>
                        setDialogState(() => selectedMethod = v),
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                  ),
                  RadioListTile<String>(
                    title: const Text('Transferencia (TR)'),
                    value: 'TR',
                    groupValue: selectedMethod,
                    onChanged: (v) =>
                        setDialogState(() => selectedMethod = v),
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                  ),
                  RadioListTile<String>(
                    title: const Text('Pendiente (PD)'),
                    value: 'PD',
                    groupValue: selectedMethod,
                    onChanged: (v) =>
                        setDialogState(() => selectedMethod = v),
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: const Text('Cancelar'),
                ),
                FilledButton(
                  onPressed: selectedMethod != null
                      ? () => Navigator.of(ctx).pop(selectedMethod)
                      : null,
                  child: const Text('Confirmar entrega'),
                ),
              ],
            );
          },
        );
      },
    );

    if (result != null && mounted) {
      try {
        // 1. Actualizar método de pago en BD
        await ref
            .read(orderRepositoryProvider)
            .updateOrder(order.copyWith(metodoPago: result));

        // 2. Cambiar estado a entregado (dispara SMS ENT)
        await ref
            .read(orderProvider.notifier)
            .updateState(order.id, OrderState.entregado);
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error al marcar entregado: $e'),
              backgroundColor: AppColors.forBrightness(
                      Theme.of(context).brightness)
                  .danger,
            ),
          );
        }
      }
    }
  }
}
