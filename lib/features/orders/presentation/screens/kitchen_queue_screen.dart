import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:etecsa/config/theme/app_colors.dart';
import 'package:etecsa/config/theme/hamburguesa_theme.dart';
import 'package:etecsa/config/theme/widgets/status_badge.dart';
import 'package:etecsa/config/theme/widgets/ticket_card.dart';
import 'package:etecsa/config/theme/widgets/order_timer.dart';
import 'package:etecsa/features/orders/domain/entities/restaurant_order.dart';
import 'package:etecsa/features/orders/domain/entities/order_state.dart';
import 'package:etecsa/features/orders/presentation/providers/order_provider.dart';
import 'package:etecsa/features/shared/widgets/side_menu.dart';

// ---------------------------------------------------------------------------
// Cocina Kitchen Queue Screen — PRD §15.7
// ---------------------------------------------------------------------------
///
/// Tres columnas tipo Kanban para la cocina:
///
/// | **Pendiente** (registrado)     | **En cocina** (enCocina)     | **Listo** (hecho)       |
/// |--------------------------------|------------------------------|-------------------------|
/// | "Recibido" → updateState      | Timer 15 min                | Info de entrega         |
/// | → enCocina                    | "Marcar hecho" → updateState | Timer de listo          |
/// |                               | → hecho + HEC SMS            |                         |
///
/// **Auto-refresh** cada 5s via [orderRepositoryProvider].
/// **Pull-to-refresh** por columna.
/// **Estado vacío** por columna.
/// **Tema oscuro** forzado (rol Cocina).
///
/// TODO(notifications): Pendiente notificación nativa Android para PED SMS
/// (sonido + vibración + pantalla encendida, repetir hasta "Recibido").
enum _ColumnType { pending, inKitchen, ready }

class KitchenQueueScreen extends ConsumerStatefulWidget {
  const KitchenQueueScreen({super.key});

  @override
  ConsumerState<KitchenQueueScreen> createState() =>
      _KitchenQueueScreenState();
}

class _KitchenQueueScreenState extends ConsumerState<KitchenQueueScreen> {
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  Timer? _refreshTimer;
  List<RestaurantOrder> _pendingOrders = [];
  List<RestaurantOrder> _inKitchenOrders = [];
  List<RestaurantOrder> _readyOrders = [];
  bool _isLoading = true;
  String? _error;

  final Set<String> _acknowledging = {};
  final Set<String> _markingDone = {};

  // ── Lifecycle ──────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _loadOrders();
    // Auto-refresh cada 5 segundos
    _refreshTimer = Timer.periodic(
      const Duration(seconds: 5),
      (_) => _loadOrders(),
    );
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  // ── Data loading ───────────────────────────────────────────────────

  /// Carga pedidos de los tres estados relevantes en paralelo.
  Future<void> _loadOrders() async {
    final repo = ref.read(orderRepositoryProvider);
    try {
      final results = await Future.wait([
        repo.getOrdersByState(OrderState.registrado),
        repo.getOrdersByState(OrderState.enCocina),
        repo.getOrdersByState(OrderState.hecho),
      ]);
      if (!mounted) return;
      setState(() {
        _pendingOrders = results[0];
        _inKitchenOrders = results[1];
        _readyOrders = results[2];
        _isLoading = false;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _error = e.toString();
      });
    }
  }

  // ── Actions ────────────────────────────────────────────────────────

  /// "Recibido": confirma pedido, pasa a [OrderState.enCocina].
  Future<void> _onRecibido(String orderId) async {
    setState(() => _acknowledging.add(orderId));
    try {
      await ref.read(orderProvider.notifier).updateState(
            orderId,
            OrderState.enCocina,
          );
      await _loadOrders();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al confirmar pedido: $e')),
        );
      }
    } finally {
      setState(() => _acknowledging.remove(orderId));
    }
  }

  /// "Marcar hecho": pasa a [OrderState.hecho] (envía HEC SMS automático).
  Future<void> _onMarcarHecho(String orderId) async {
    setState(() => _markingDone.add(orderId));
    try {
      await ref.read(orderProvider.notifier).updateState(
            orderId,
            OrderState.hecho,
          );
      await _loadOrders();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al marcar hecho: $e')),
        );
      }
    } finally {
      setState(() => _markingDone.remove(orderId));
    }
  }

  // ── Build ──────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    // Force dark theme for Cocina role
    return Theme(
      data: HamburguesaThemeData.instance.dark,
      child: Scaffold(
        key: _scaffoldKey,
        drawer: SideMenu(scaffoldKey: _scaffoldKey),
        appBar: _buildAppBar(),
        body: _buildBody(),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      leading: IconButton(
        icon: const Icon(Icons.menu),
        onPressed: () => _scaffoldKey.currentState?.openDrawer(),
      ),
      title: const Text('Cocina — Cola de Pedidos'),
      actions: [
        if (_isLoading)
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
    );
  }

  Widget _buildBody() {
    final noData = _pendingOrders.isEmpty &&
        _inKitchenOrders.isEmpty &&
        _readyOrders.isEmpty;

    // Initial loading spinner
    if (_isLoading && noData) {
      return const Center(child: CircularProgressIndicator());
    }

    // Full-screen error (when no data at all)
    if (_error != null && noData) {
      return _buildErrorState();
    }

    // ── Three-column Kanban ──────────────────────────────────────────
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: _buildColumn(
            title: 'Pendiente',
            icon: Icons.schedule,
            count: _pendingOrders.length,
            orders: _pendingOrders,
            columnType: _ColumnType.pending,
            accentColor: AppColors.forBrightness(Brightness.dark).warning,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildColumn(
            title: 'En cocina',
            icon: Icons.restaurant,
            count: _inKitchenOrders.length,
            orders: _inKitchenOrders,
            columnType: _ColumnType.inKitchen,
            accentColor: AppColors.accent,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildColumn(
            title: 'Listo',
            icon: Icons.check_circle_outline,
            count: _readyOrders.length,
            orders: _readyOrders,
            columnType: _ColumnType.ready,
            accentColor: AppColors.forBrightness(Brightness.dark).success,
          ),
        ),
      ],
    );
  }

  // ── Error state ────────────────────────────────────────────────────

  Widget _buildErrorState() {
    final colors = AppColors.forBrightness(Brightness.dark);
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
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(
              _error!,
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: colors.textSecondary),
              textAlign: TextAlign.center,
            ),
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

  // ── Column ─────────────────────────────────────────────────────────

  Widget _buildColumn({
    required String title,
    required IconData icon,
    required int count,
    required List<RestaurantOrder> orders,
    required _ColumnType columnType,
    required Color accentColor,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.darkSurface.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          // Header (fixed)
          _buildColumnHeader(title, icon, count, accentColor),
          const SizedBox(height: 4),
          // Scrollable order list or empty state
          Expanded(
            child: ClipRRect(
              borderRadius: const BorderRadius.vertical(
                bottom: Radius.circular(16),
              ),
              child: RefreshIndicator(
                onRefresh: _loadOrders,
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    if (orders.isEmpty) {
                      // Tall enough to fill column + allow pull-to-refresh
                      return ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        children: [
                          SizedBox(
                            height: constraints.maxHeight,
                            child: _buildEmptyState(columnType),
                          ),
                        ],
                      );
                    }
                    return ListView.builder(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.only(
                        left: 8,
                        right: 8,
                        bottom: 16,
                      ),
                      itemCount: orders.length,
                      itemBuilder: (context, index) => _buildOrderCard(
                        orders[index],
                        columnType,
                        accentColor,
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Column header ──────────────────────────────────────────────────

  Widget _buildColumnHeader(
    String title,
    IconData icon,
    int count,
    Color accentColor,
  ) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Row(
        children: [
          Icon(icon, size: 20, color: accentColor),
          const SizedBox(width: 8),
          Text(
            title,
            style: GoogleFonts.dmSans(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppColors.darkTextPrimary,
            ),
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
            decoration: BoxDecoration(
              color: accentColor.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '$count',
              style: GoogleFonts.jetBrainsMono(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: accentColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Empty state ────────────────────────────────────────────────────

  Widget _buildEmptyState(_ColumnType type) {
    final colors = AppColors.forBrightness(Brightness.dark);
    final (icon, message, hint) = switch (type) {
      _ColumnType.pending => (
        Icons.inbox_outlined,
        'Sin pedidos pendientes',
        'Los nuevos pedidos aparecerán aquí.',
      ),
      _ColumnType.inKitchen => (
        Icons.restaurant_menu,
        'Nada en cocina',
        'Presiona Recibido en un pedido para empezar.',
      ),
      _ColumnType.ready => (
        Icons.check_circle_outline,
        'Nada listo aún',
        'Los pedidos terminados aparecerán aquí.',
      ),
    };

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 48,
                color: colors.textSecondary.withValues(alpha: 0.3)),
            const SizedBox(height: 12),
            Text(
              message,
              style: GoogleFonts.dmSans(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: colors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            Text(
              hint,
              style: GoogleFonts.dmSans(
                fontSize: 12,
                color: colors.textSecondary.withValues(alpha: 0.6),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  // ── Order card ─────────────────────────────────────────────────────

  Widget _buildOrderCard(
    RestaurantOrder order,
    _ColumnType columnType,
    Color accentColor,
  ) {
    return TicketCard(
      margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildCardHeader(order, columnType),
          const SizedBox(height: 8),
          _buildCardClient(order),
          const SizedBox(height: 8),
          _buildCardItems(order),
          const SizedBox(height: 8),
          _buildCardFooter(order, columnType, accentColor),
        ],
      ),
    );
  }

  Widget _buildCardHeader(RestaurantOrder order, _ColumnType columnType) {
    return Row(
      children: [
        // Folio
        Text(
          order.id,
          style: GoogleFonts.jetBrainsMono(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: AppColors.darkTextPrimary,
          ),
        ),
        const Spacer(),
        // State pill badge (redundant with column but explicit per spec)
        StatusBadge(state: order.estado, fontSize: 10),
      ],
    );
  }

  Widget _buildCardClient(RestaurantOrder order) {
    return Row(
      children: [
        Icon(Icons.person_outline,
            size: 14, color: AppColors.darkTextSecondary),
        const SizedBox(width: 4),
        Flexible(
          child: Text(
            order.clienteId.isNotEmpty ? order.clienteId : 'Cliente',
            style: GoogleFonts.dmSans(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: AppColors.darkTextSecondary,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        if (order.mesaId != null) ...[
          const SizedBox(width: 12),
          Icon(Icons.table_restaurant,
              size: 14, color: AppColors.darkTextSecondary),
          const SizedBox(width: 4),
          Text(
            'Mesa ${order.mesaId}',
            style: GoogleFonts.dmSans(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: AppColors.darkTextSecondary,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildCardItems(RestaurantOrder order) {
    final items = order.items;
    if (items.isEmpty) {
      return Text(
        'Sin items',
        style: GoogleFonts.dmSans(
          fontSize: 12,
          color: AppColors.darkTextSecondary.withValues(alpha: 0.6),
        ),
      );
    }

    const int maxVisible = 4;
    final visible = items.take(maxVisible).toList();
    final remaining = items.length - maxVisible;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final item in visible)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 1),
            child: Row(
              children: [
                Text(
                  '${item.qty}x',
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.accent,
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    item.code,
                    style: GoogleFonts.dmSans(
                      fontSize: 13,
                      color: AppColors.darkTextPrimary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        if (remaining > 0)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              'y $remaining más',
              style: GoogleFonts.dmSans(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: AppColors.darkTextSecondary,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildCardFooter(
    RestaurantOrder order,
    _ColumnType columnType,
    Color accentColor,
  ) {
    return switch (columnType) {
      _ColumnType.pending => _buildPendingFooter(order),
      _ColumnType.inKitchen => _buildInKitchenFooter(order),
      _ColumnType.ready => _buildReadyFooter(order),
    };
  }

  // ── Pendiente: "Recibido" button ───────────────────────────────────

  Widget _buildPendingFooter(RestaurantOrder order) {
    final isLoading = _acknowledging.contains(order.id);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // TODO(notifications): High-priority notification when PED SMS arrives.
        // Requires Android-native setup (sound + vibration + screen on).
        // Sound must repeat every few seconds until "Recibido" is pressed.
        SizedBox(
          height: 42,
          child: OutlinedButton.icon(
            onPressed: isLoading ? null : () => _onRecibido(order.id),
            icon: isLoading
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.check_circle_outline, size: 18),
            label: Text(isLoading ? 'Confirmando...' : 'Recibido'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.darkTextPrimary,
              side: BorderSide(color: AppColors.accent, width: 1.5),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ── En cocina: Timer + "Marcar hecho" button ───────────────────────

  Widget _buildInKitchenFooter(RestaurantOrder order) {
    final isLoading = _markingDone.contains(order.id);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Timer (15 min target, changes color Mostaza→Guayaba if exceeded)
        if (order.fechaCreacion != null)
          Align(
            alignment: Alignment.center,
            child: Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: OrderTimer(
                startTime: order.fechaCreacion!,
                timeObjective: const Duration(minutes: 15),
                fontSize: 20,
                showIcon: true,
              ),
            ),
          ),
        // Marcar hecho button
        SizedBox(
          height: 42,
          child: FilledButton.icon(
            onPressed: isLoading ? null : () => _onMarcarHecho(order.id),
            icon: isLoading
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.check, size: 18),
            label: Text(isLoading ? 'Procesando...' : 'Marcar hecho'),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.accent,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ── Listo: delivery info + timer ──────────────────────────────────

  Widget _buildReadyFooter(RestaurantOrder order) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Info badge
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: AppColors.forBrightness(Brightness.dark)
                .success
                .withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Icon(Icons.info_outline,
                  size: 14,
                  color: AppColors.forBrightness(Brightness.dark).success),
              const SizedBox(width: 6),
              Text(
                order.tipoPedido == 'DOMICILIO'
                    ? 'Esperando Domicilio'
                    : 'Esperando Mesero',
                style: GoogleFonts.dmSans(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.forBrightness(Brightness.dark).success,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        // Timer: how long it's been ready
        if (order.fechaCreacion != null)
          Align(
            alignment: Alignment.center,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Listo hace ',
                  style: GoogleFonts.dmSans(
                    fontSize: 12,
                    color: AppColors.darkTextSecondary,
                  ),
                ),
                OrderTimer(
                  startTime: order.fechaCreacion!,
                  timeObjective: const Duration(minutes: 15),
                  fontSize: 14,
                  defaultColor:
                      AppColors.forBrightness(Brightness.dark).success,
                ),
              ],
            ),
          ),
      ],
    );
  }
}
