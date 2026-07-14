import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import 'package:etecsa/config/theme/app_colors.dart';
import 'package:etecsa/config/theme/widgets/status_badge.dart';
import 'package:etecsa/config/theme/widgets/ticket_card.dart';
import 'package:etecsa/features/orders/domain/entities/restaurant_order.dart';
import 'package:etecsa/features/orders/domain/entities/order_state.dart';
import 'package:etecsa/features/orders/presentation/providers/order_provider.dart';

// ---------------------------------------------------------------------------
// Order History Screen — PRD §15.6
// ---------------------------------------------------------------------------
///
/// Searchable list of past orders with date range and status filters.
/// Each order is rendered as a TicketCard with StatusBadge.
///
/// Filters:
/// - Search by client ID or order ID
/// - Date range: Today, This Week, This Month, Custom
/// - Status: All or specific OrderState

enum _DateFilter { today, thisWeek, thisMonth, custom, all }

class OrderHistoryScreen extends ConsumerStatefulWidget {
  const OrderHistoryScreen({super.key});

  @override
  ConsumerState<OrderHistoryScreen> createState() =>
      _OrderHistoryScreenState();
}

class _OrderHistoryScreenState extends ConsumerState<OrderHistoryScreen> {
  final _searchController = TextEditingController();
  List<RestaurantOrder> _allOrders = [];
  bool _isLoading = true;
  String? _error;

  _DateFilter _dateFilter = _DateFilter.all;
  DateTime? _customFrom;
  DateTime? _customTo;
  OrderState? _statusFilter;

  @override
  void initState() {
    super.initState();
    _loadOrders();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadOrders() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final repo = ref.read(orderRepositoryProvider);
      final orders = await repo.getAllOrders();
      if (mounted) {
        setState(() {
          _allOrders = orders;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  List<RestaurantOrder> get _filteredOrders {
    var filtered = _allOrders;

    // Text search
    final query = _searchController.text.trim().toLowerCase();
    if (query.isNotEmpty) {
      filtered = filtered.where((o) {
        return o.id.toLowerCase().contains(query) ||
            o.clienteId.toLowerCase().contains(query);
      }).toList();
    }

    // Status filter
    if (_statusFilter != null) {
      filtered =
          filtered.where((o) => o.estado == _statusFilter).toList();
    }

    // Date filter
    final now = DateTime.now();
    switch (_dateFilter) {
      case _DateFilter.today:
        final today = DateTime(now.year, now.month, now.day);
        filtered = filtered.where((o) {
          final fecha = o.fechaCreacion;
          return fecha != null && fecha.isAfter(today);
        }).toList();
      case _DateFilter.thisWeek:
        final weekStart = now.subtract(Duration(days: now.weekday - 1));
        final startOfWeek =
            DateTime(weekStart.year, weekStart.month, weekStart.day);
        filtered = filtered.where((o) {
          final fecha = o.fechaCreacion;
          return fecha != null && fecha.isAfter(startOfWeek);
        }).toList();
      case _DateFilter.thisMonth:
        final monthStart = DateTime(now.year, now.month, 1);
        filtered = filtered.where((o) {
          final fecha = o.fechaCreacion;
          return fecha != null && fecha.isAfter(monthStart);
        }).toList();
      case _DateFilter.custom:
        if (_customFrom != null) {
          filtered = filtered.where((o) {
            final fecha = o.fechaCreacion;
            return fecha != null && !fecha.isBefore(_customFrom!);
          }).toList();
        }
        if (_customTo != null) {
          final endOfDay = DateTime(_customTo!.year, _customTo!.month,
              _customTo!.day, 23, 59, 59);
          filtered = filtered.where((o) {
            final fecha = o.fechaCreacion;
            return fecha != null && !fecha.isAfter(endOfDay);
          }).toList();
        }
      case _DateFilter.all:
        break;
    }

    return filtered;
  }

  Future<void> _pickCustomRange() async {
    final from = await showDatePicker(
      context: context,
      initialDate: _customFrom ?? DateTime.now(),
      firstDate: DateTime(2024),
      lastDate: DateTime.now(),
      helpText: 'Fecha desde',
    );
    if (from == null || !mounted) return;

    final to = await showDatePicker(
      context: context,
      initialDate: _customTo ?? DateTime.now(),
      firstDate: from,
      lastDate: DateTime.now(),
      helpText: 'Fecha hasta',
    );
    if (to == null || !mounted) return;

    setState(() {
      _customFrom = from;
      _customTo = to;
      _dateFilter = _DateFilter.custom;
    });
  }

  // ─────────────────────────────────────────────────────────────────────
  // BUILD
  // ─────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.forBrightness(Theme.of(context).brightness);
    final theme = Theme.of(context);
    final filtered = _filteredOrders;

    return Scaffold(
      appBar: AppBar(
        title: Text('Historial (${filtered.length})'),
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
      ),
      body: Column(
        children: [
          // ── Filters ─────────────────────────────────
          _buildFilters(colors, theme),
          const Divider(height: 1),

          // ── Orders list ─────────────────────────────
          Expanded(
            child: _isLoading && _allOrders.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : _error != null && _allOrders.isEmpty
                    ? _buildError(colors, theme)
                    : filtered.isEmpty
                        ? _buildEmpty(colors, theme)
                        : RefreshIndicator(
                            onRefresh: _loadOrders,
                            child: ListView.builder(
                              padding: const EdgeInsets.only(
                                  top: 8, bottom: 24),
                              itemCount: filtered.length,
                              itemBuilder: (context, index) =>
                                  _buildOrderCard(
                                      filtered[index], colors, theme),
                            ),
                          ),
          ),
        ],
      ),
    );
  }

  // ─── FILTERS ───────────────────────────────────────────────────────

  Widget _buildFilters(AppColorsTheme colors, ThemeData theme) {
    final dateLabel = switch (_dateFilter) {
      _DateFilter.today => 'Hoy',
      _DateFilter.thisWeek => 'Esta semana',
      _DateFilter.thisMonth => 'Este mes',
      _DateFilter.custom => _customFrom != null && _customTo != null
          ? '${DateFormat.MMMd().format(_customFrom!)} - ${DateFormat.MMMd().format(_customTo!)}'
          : 'Personalizado',
      _DateFilter.all => 'Todas las fechas',
    };

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      color: colors.surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Search
          TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Buscar por folio o cliente...',
              prefixIcon: const Icon(Icons.search, size: 20),
              isDense: true,
              contentPadding:
                  const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, size: 18),
                      onPressed: () {
                        _searchController.clear();
                        setState(() {});
                      },
                    )
                  : null,
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 8),

          // Date + Status filters row
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                // Date filter chips
                _buildFilterChip(
                  'Hoy',
                  _dateFilter == _DateFilter.today,
                  () => setState(() => _dateFilter = _DateFilter.today),
                  colors,
                ),
                const SizedBox(width: 6),
                _buildFilterChip(
                  'Semana',
                  _dateFilter == _DateFilter.thisWeek,
                  () =>
                      setState(() => _dateFilter = _DateFilter.thisWeek),
                  colors,
                ),
                const SizedBox(width: 6),
                _buildFilterChip(
                  'Mes',
                  _dateFilter == _DateFilter.thisMonth,
                  () =>
                      setState(() => _dateFilter = _DateFilter.thisMonth),
                  colors,
                ),
                const SizedBox(width: 6),
                _buildFilterChip(
                  dateLabel,
                  _dateFilter == _DateFilter.custom,
                  _pickCustomRange,
                  colors,
                  icon: Icons.date_range,
                ),
                const SizedBox(width: 6),
                _buildFilterChip(
                  'Todas',
                  _dateFilter == _DateFilter.all,
                  () => setState(() => _dateFilter = _DateFilter.all),
                  colors,
                ),

                const SizedBox(width: 12),
                Container(
                  height: 24,
                  width: 1,
                  color: colors.textSecondary.withValues(alpha: 0.3),
                ),
                const SizedBox(width: 12),

                // Status filter dropdown
                _buildStatusDropdown(colors, theme),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(
    String label,
    bool selected,
    VoidCallback onTap,
    AppColorsTheme colors, {
    IconData? icon,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? colors.accent : colors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected
                ? colors.accent
                : colors.textSecondary.withValues(alpha: 0.3),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon,
                  size: 14,
                  color: selected
                      ? Colors.white
                      : colors.textSecondary),
              const SizedBox(width: 4),
            ],
            Text(
              label,
              style: GoogleFonts.dmSans(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color:
                    selected ? Colors.white : colors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusDropdown(
      AppColorsTheme colors, ThemeData theme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
            color: colors.textSecondary.withValues(alpha: 0.3)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<OrderState?>(
          value: _statusFilter,
          isDense: true,
          hint: Text('Estado',
              style: GoogleFonts.dmSans(
                  fontSize: 12, fontWeight: FontWeight.w600)),
          items: [
            DropdownMenuItem(
              value: null,
              child: Text('Todos los estados',
                  style: GoogleFonts.dmSans(fontSize: 12)),
            ),
            ...OrderState.values.map((s) => DropdownMenuItem(
                  value: s,
                  child: Text(StatusBadge.labelFor(s),
                      style: GoogleFonts.dmSans(fontSize: 12)),
                )),
          ],
          onChanged: (v) => setState(() => _statusFilter = v),
        ),
      ),
    );
  }

  // ─── ORDER CARD ────────────────────────────────────────────────────

  Widget _buildOrderCard(
    RestaurantOrder order,
    AppColorsTheme colors,
    ThemeData theme,
  ) {
    return TicketCard(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header: ID + Status
          Row(
            children: [
              Text(
                order.id,
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: colors.textPrimary,
                ),
              ),
              const Spacer(),
              StatusBadge(state: order.estado, fontSize: 11),
            ],
          ),
          const SizedBox(height: 6),

          // Client info
          Row(
            children: [
              Icon(Icons.person_outline,
                  size: 14, color: colors.textSecondary),
              const SizedBox(width: 4),
              Text(
                'Cliente: ${order.clienteId}',
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: colors.textSecondary),
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),

          // Date + type
          if (order.fechaCreacion != null) ...[
            const SizedBox(height: 2),
            Row(
              children: [
                Icon(Icons.access_time,
                    size: 14, color: colors.textSecondary),
                const SizedBox(width: 4),
                Text(
                  DateFormat('dd/MM/yy HH:mm')
                      .format(order.fechaCreacion!),
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: colors.textSecondary),
                ),
                const SizedBox(width: 12),
                Icon(Icons.delivery_dining,
                    size: 14, color: colors.textSecondary),
                const SizedBox(width: 4),
                Text(
                  order.tipoPedido,
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: colors.textSecondary),
                ),
              ],
            ),
          ],
          const SizedBox(height: 8),

          // Items
          if (order.items.isNotEmpty) ...[
            const Divider(height: 1),
            const SizedBox(height: 6),
            ...order.items.take(5).map((item) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 1),
                  child: Row(
                    children: [
                      Text(
                        '${item.qty}x',
                        style: GoogleFonts.jetBrainsMono(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: colors.accent,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          item.code,
                          style: theme.textTheme.bodySmall,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        '\$${item.subtotal.toStringAsFixed(2)}',
                        style: GoogleFonts.jetBrainsMono(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: colors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                )),
            if (order.items.length > 5)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  'y ${order.items.length - 5} más',
                  style: theme.textTheme.bodySmall?.copyWith(
                      color: colors.textSecondary,
                      fontStyle: FontStyle.italic),
                ),
              ),
            const SizedBox(height: 6),
            const Divider(height: 1),
            const SizedBox(height: 4),
            Row(
              children: [
                const Spacer(),
                Text(
                  'Total: ',
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(color: colors.textSecondary),
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
      ),
    );
  }

  // ─── EMPTY / ERROR ────────────────────────────────────────────────

  Widget _buildEmpty(AppColorsTheme colors, ThemeData theme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.receipt_long_outlined,
                size: 64,
                color: colors.textSecondary.withValues(alpha: 0.3)),
            const SizedBox(height: 16),
            Text('No hay pedidos',
                style: theme.textTheme.titleLarge
                    ?.copyWith(color: colors.textSecondary)),
            const SizedBox(height: 8),
            Text(
              'Probá cambiando los filtros.',
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: colors.textSecondary),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildError(AppColorsTheme colors, ThemeData theme) {
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
            Text(
              _error!,
              style: theme.textTheme.bodySmall
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
}
