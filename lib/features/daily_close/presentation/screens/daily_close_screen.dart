import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:etecsa/config/theme/app_colors.dart';
import 'package:etecsa/core/database/app_database.dart' hide RestaurantOrder;
import 'package:etecsa/features/orders/domain/entities/restaurant_order.dart';
import 'package:etecsa/features/daily_close/presentation/providers/daily_close_provider.dart';
import 'package:etecsa/features/shared/widgets/side_menu.dart';

// ---------------------------------------------------------------------------
// Admin Daily Close Screen
// ---------------------------------------------------------------------------
///
/// Pantalla de Resumen del Día con 4 tabs:
/// 1. Resumen — ventas totales, breakdown, top productos, utilidad neta, distribución
/// 2. Gastos — formulario y listado de gastos del día
/// 3. Compras — formulario y listado de compras del día
/// 4. Nómina — trabajadores, toggle trabajo, jornada, estímulo

class DailyCloseScreen extends ConsumerStatefulWidget {
  const DailyCloseScreen({super.key});

  @override
  ConsumerState<DailyCloseScreen> createState() => _DailyCloseScreenState();
}

class _DailyCloseScreenState extends ConsumerState<DailyCloseScreen>
    with SingleTickerProviderStateMixin {
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(dailyCloseProvider.notifier).loadAll();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(dailyCloseProvider);
    final colors = AppColors.forBrightness(Theme.of(context).brightness);
    final theme = Theme.of(context);

    return Scaffold(
      key: _scaffoldKey,
      drawer: SideMenu(scaffoldKey: _scaffoldKey),
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.menu),
          onPressed: () => _scaffoldKey.currentState?.openDrawer(),
        ),
        title: Text('Resumen del Día'),
        actions: [
          if (state.isLoading)
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: colors.accent,
                ),
              ),
            ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Recargar',
            onPressed: () => ref.read(dailyCloseProvider.notifier).loadAll(),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: colors.accent,
          labelColor: colors.accent,
          unselectedLabelColor: colors.textSecondary,
          tabs: const [
            Tab(text: 'Resumen', icon: Icon(Icons.summarize, size: 18)),
            Tab(text: 'Gastos', icon: Icon(Icons.money_off, size: 18)),
            Tab(text: 'Compras', icon: Icon(Icons.shopping_cart, size: 18)),
            Tab(text: 'Nómina', icon: Icon(Icons.people, size: 18)),
          ],
        ),
      ),
      body: state.isLoading && state.orders.isEmpty
          ? Center(child: CircularProgressIndicator(color: colors.accent))
          : state.error != null && state.orders.isEmpty
              ? _buildError(colors, theme)
              : TabBarView(
                  controller: _tabController,
                  children: [
                    _ResumenTab(state: state, colors: colors, theme: theme),
                    _GastosTab(state: state, colors: colors, theme: theme),
                    _ComprasTab(state: state, colors: colors, theme: theme),
                    _NominaTab(
                      state: state,
                      colors: colors,
                      theme: theme,
                      notifier: ref.read(dailyCloseProvider.notifier),
                    ),
                  ],
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
            Text('Error al cargar datos',
                style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            FilledButton.icon(
              onPressed: () =>
                  ref.read(dailyCloseProvider.notifier).loadAll(),
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('Reintentar'),
            ),
          ],
        ),
      ),
    );
  }
}

// =========================================================================
// TAB 1: RESUMEN
// =========================================================================

class _ResumenTab extends StatelessWidget {
  final DailyCloseState state;
  final AppColorsTheme colors;
  final ThemeData theme;

  const _ResumenTab({
    required this.state,
    required this.colors,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // ── Total Sales (large mono) ─────────────────────────────
        _buildTotalSalesCard(),

        const SizedBox(height: 16),

        // ── Efectivo / Transferencia breakdown ───────────────────
        _buildPaymentBreakdown(),

        const SizedBox(height: 16),

        // ── Top Products ─────────────────────────────────────────
        _buildTopProducts(),

        const SizedBox(height: 16),

        // ── Production Cost ──────────────────────────────────────
        _buildCostCard(),

        const SizedBox(height: 16),

        // ── Utilidad Neta & Distribution ─────────────────────────
        _buildProfitDistribution(),

        const SizedBox(height: 16),

        // ── Operational Indicators ───────────────────────────────
        _buildOperationalIndicators(),

        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildTotalSalesCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Text(
              'VENTAS TOTALES',
              style: theme.textTheme.bodySmall?.copyWith(
                color: colors.textSecondary,
                letterSpacing: 1,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '\$${state.totalSales.toStringAsFixed(2)}',
              style: GoogleFonts.jetBrainsMono(
                fontSize: 36,
                fontWeight: FontWeight.w700,
                color: colors.accent,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'SÓLIDOS: ',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colors.textSecondary,
                  ),
                ),
                Text(
                  '\$${state.solidSales.toStringAsFixed(2)}',
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: colors.success,
                  ),
                ),
                const SizedBox(width: 16),
                Text(
                  'LÍQUIDOS: ',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colors.textSecondary,
                  ),
                ),
                Text(
                  '\$${state.liquidSales.toStringAsFixed(2)}',
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: colors.warning,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPaymentBreakdown() {
    final cashPct = state.totalSales > 0
        ? (state.cashSales / state.totalSales * 100).toStringAsFixed(0)
        : '0';
    final transferPct = state.totalSales > 0
        ? (state.transferSales / state.totalSales * 100).toStringAsFixed(0)
        : '0';
    final diferenciaPct = state.unconfirmedPct.toStringAsFixed(0);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('DESGLOSE DE PAGOS',
                style: theme.textTheme.bodySmall?.copyWith(
                    color: colors.textSecondary, letterSpacing: 1)),
            const SizedBox(height: 12),
            _breakdownRow(
              'Efectivo',
              state.cashSales,
              '$cashPct%',
              colors.success,
            ),
            const SizedBox(height: 8),
            _breakdownRow(
              'Transferencia',
              state.transferSales,
              '$transferPct%',
              colors.warning,
            ),
            const SizedBox(height: 8),
            _breakdownRow(
              'Diferencia',
              state.diferencia,
              '$diferenciaPct%',
              state.diferencia == 0 ? colors.success : colors.warning,
            ),
          ],
        ),
      ),
    );
  }

  Widget _breakdownRow(
      String label, double amount, String pct, Color color) {
    return Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 8),
        Text(label, style: theme.textTheme.bodyMedium),
        const Spacer(),
        Text(
          '\$${amount.toStringAsFixed(2)}',
          style: GoogleFonts.jetBrainsMono(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: colors.textPrimary,
          ),
        ),
        const SizedBox(width: 12),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            pct,
            style: GoogleFonts.jetBrainsMono(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTopProducts() {
    final products = state.topProducts;
    if (products.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text('No hay productos vendidos hoy.',
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: colors.textSecondary)),
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('PRODUCTOS MÁS VENDIDOS',
                style: theme.textTheme.bodySmall?.copyWith(
                    color: colors.textSecondary, letterSpacing: 1)),
            const SizedBox(height: 12),
            ...products.take(10).map((p) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      Text(
                        p.productCode,
                        style: theme.textTheme.bodyMedium,
                      ),
                      const Spacer(),
                      Text(
                        '${p.quantity}x',
                        style: GoogleFonts.jetBrainsMono(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: colors.accent,
                        ),
                      ),
                      const SizedBox(width: 12),
                      SizedBox(
                        width: 80,
                        child: Text(
                          '\$${p.amount.toStringAsFixed(2)}',
                          textAlign: TextAlign.right,
                          style: GoogleFonts.jetBrainsMono(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: colors.textPrimary,
                          ),
                        ),
                      ),
                    ],
                  ),
                )),
          ],
        ),
      ),
    );
  }

  Widget _buildCostCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Expanded(
              child: _costItem('Costo Producción', state.productionCost),
            ),
            Container(
              width: 1,
              height: 40,
              color: colors.textSecondary.withValues(alpha: 0.2),
            ),
            Expanded(
              child: _costItem('Gastos', state.totalExpensesAmount),
            ),
            Container(
              width: 1,
              height: 40,
              color: colors.textSecondary.withValues(alpha: 0.2),
            ),
            Expanded(
              child: _costItem('Compras', state.totalPurchasesAmount),
            ),
          ],
        ),
      ),
    );
  }

  Widget _costItem(String label, double amount) {
    return Column(
      children: [
        Text(label,
            style: theme.textTheme.bodySmall
                ?.copyWith(color: colors.textSecondary)),
        const SizedBox(height: 4),
        Text(
          '\$${amount.toStringAsFixed(2)}',
          style: GoogleFonts.jetBrainsMono(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: colors.textPrimary,
          ),
        ),
      ],
    );
  }

  Widget _buildProfitDistribution() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('UTILIDAD NETA',
                style: theme.textTheme.bodySmall?.copyWith(
                    color: colors.textSecondary, letterSpacing: 1)),
            const SizedBox(height: 8),
            Center(
              child: Text(
                '\$${state.utilidadNeta.toStringAsFixed(2)}',
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                  color: state.utilidadNeta >= 0
                      ? colors.success
                      : colors.danger,
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 12),
            Text('DISTRIBUCIÓN',
                style: theme.textTheme.bodySmall?.copyWith(
                    color: colors.textSecondary, letterSpacing: 1)),
            const SizedBox(height: 12),
            _distRow('Yurdenis (30%)', state.distributionYurdenis),
            const SizedBox(height: 6),
            _distRow('Mildrey (30%)', state.distributionMildrey),
            const SizedBox(height: 6),
            _distRow('Reinversión (40%)', state.distributionNegocio),
          ],
        ),
      ),
    );
  }

  Widget _distRow(String label, double amount) {
    return Row(
      children: [
        Expanded(
          child: Text(label, style: theme.textTheme.bodyMedium),
        ),
        Text(
          '\$${amount.toStringAsFixed(2)}',
          style: GoogleFonts.jetBrainsMono(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: colors.accent,
          ),
        ),
      ],
    );
  }

  Widget _buildOperationalIndicators() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('INDICADORES OPERATIVOS',
                style: theme.textTheme.bodySmall?.copyWith(
                    color: colors.textSecondary, letterSpacing: 1)),
            const SizedBox(height: 12),
            _indicatorRow(
              'Total pedidos',
              '${state.totalOrders}',
              state.totalOrders > 0 ? colors.success : colors.textSecondary,
            ),
            _indicatorRow(
              'Tiempo medio en cocina',
              '${state.avgKitchenTimeMinutes.toStringAsFixed(0)} min',
              state.avgKitchenTimeMinutes <= 15
                  ? colors.success
                  : state.avgKitchenTimeMinutes <= 25
                      ? colors.warning
                      : colors.danger,
            ),
            _indicatorRow(
              'Tiempo medio entrega',
              '${state.avgDeliveryTimeMinutes.toStringAsFixed(0)} min',
              state.avgDeliveryTimeMinutes <= 20
                  ? colors.success
                  : state.avgDeliveryTimeMinutes <= 35
                      ? colors.warning
                      : colors.danger,
            ),
            if (state.cancelledOrders > 0) ...[
              _indicatorRow(
                'Pedidos cancelados',
                '${state.cancelledOrders}',
                colors.danger,
              ),
              ...state.cancellationReasons.entries.map((e) => Padding(
                    padding: const EdgeInsets.only(left: 24, top: 2),
                    child: Row(
                      children: [
                        Text('— ',
                            style: theme.textTheme.bodySmall
                                ?.copyWith(color: colors.textSecondary)),
                        Expanded(
                          child: Text(
                            e.key,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: colors.textSecondary,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ),
                        Text(
                          '(${e.value})',
                          style: GoogleFonts.jetBrainsMono(
                            fontSize: 12,
                            color: colors.danger,
                          ),
                        ),
                      ],
                    ),
                  )),
            ],
            _indicatorRow(
              'Pagos no confirmados',
              '${state.ordersWithUnconfirmedPayment} '
              '(${state.unconfirmedPct.toStringAsFixed(0)}%)',
              state.ordersWithUnconfirmedPayment > 0
                  ? colors.warning
                  : colors.success,
            ),
          ],
        ),
      ),
    );
  }

  Widget _indicatorRow(String label, String value, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(Icons.circle, size: 8, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Text(label, style: theme.textTheme.bodyMedium),
          ),
          Text(
            value,
            style: GoogleFonts.jetBrainsMono(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

// =========================================================================
// TAB 2: GASTOS
// =========================================================================

class _GastosTab extends ConsumerStatefulWidget {
  final DailyCloseState state;
  final AppColorsTheme colors;
  final ThemeData theme;

  const _GastosTab({
    required this.state,
    required this.colors,
    required this.theme,
  });

  @override
  ConsumerState<_GastosTab> createState() => _GastosTabState();
}

class _GastosTabState extends ConsumerState<_GastosTab> {
  final _conceptoCtrl = TextEditingController();
  final _montoCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isAdding = false;

  @override
  void dispose() {
    _conceptoCtrl.dispose();
    _montoCtrl.dispose();
    super.dispose();
  }

  Future<void> _addExpense() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isAdding = true);
    try {
      final monto = double.tryParse(
            _montoCtrl.text.replaceAll(',', '.'),
          ) ??
          0.0;
      await ref.read(dailyCloseProvider.notifier).addExpense(
            concepto: _conceptoCtrl.text.trim(),
            monto: monto,
          );
      _conceptoCtrl.clear();
      _montoCtrl.clear();
    } finally {
      if (mounted) setState(() => _isAdding = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final expenses = widget.state.expenses;
    double total = 0;
    for (final e in expenses) {
      total += e.monto;
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Form
        Form(
          key: _formKey,
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('AGREGAR GASTO',
                      style: widget.theme.textTheme.bodySmall?.copyWith(
                          color: widget.colors.textSecondary,
                          letterSpacing: 1)),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _conceptoCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Concepto',
                      hintText: 'Ej: Pasaje, agua, luz...',
                    ),
                    validator: (v) =>
                        (v == null || v.trim().isEmpty) ? 'Requerido' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _montoCtrl,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[\d.,]+')),
                    ],
                    decoration: const InputDecoration(
                      labelText: 'Monto (\$)',
                      prefixText: '\$ ',
                    ),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return 'Requerido';
                      final n = double.tryParse(v.replaceAll(',', '.'));
                      if (n == null || n <= 0) return 'Monto inválido';
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: _isAdding ? null : _addExpense,
                      icon: _isAdding
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child:
                                  CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.add, size: 18),
                      label: const Text('Agregar Gasto'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),

        const SizedBox(height: 16),

        // Total
        Text(
          'Total Gastos: \$${total.toStringAsFixed(2)}',
          style: GoogleFonts.jetBrainsMono(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: widget.colors.danger,
          ),
        ),
        const SizedBox(height: 8),

        // List
        if (expenses.isEmpty)
          Padding(
            padding: const EdgeInsets.all(24),
            child: Center(
              child: Text('No hay gastos registrados hoy.',
                  style: widget.theme.textTheme.bodyMedium
                      ?.copyWith(color: widget.colors.textSecondary)),
            ),
          )
        else
          ...expenses.map((e) => _expenseTile(e)),
      ],
    );
  }

  Widget _expenseTile(DailyExpense expense) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: ListTile(
        title: Text(expense.concepto,
            style: widget.theme.textTheme.bodyMedium),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '\$${expense.monto.toStringAsFixed(2)}',
              style: GoogleFonts.jetBrainsMono(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: widget.colors.danger,
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              icon: Icon(Icons.delete_outline,
                  size: 18, color: widget.colors.danger),
              onPressed: () => _confirmDeleteExpense(expense.id),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDeleteExpense(String id) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar gasto'),
        content: const Text('¿Estás seguro de eliminar este gasto?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              ref.read(dailyCloseProvider.notifier).deleteExpense(id);
            },
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
  }
}

// =========================================================================
// TAB 3: COMPRAS
// =========================================================================

class _ComprasTab extends ConsumerStatefulWidget {
  final DailyCloseState state;
  final AppColorsTheme colors;
  final ThemeData theme;

  const _ComprasTab({
    required this.state,
    required this.colors,
    required this.theme,
  });

  @override
  ConsumerState<_ComprasTab> createState() => _ComprasTabState();
}

class _ComprasTabState extends ConsumerState<_ComprasTab> {
  final _insumoCtrl = TextEditingController();
  final _proveedorCtrl = TextEditingController();
  final _cantidadCtrl = TextEditingController();
  final _costoCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isAdding = false;

  @override
  void dispose() {
    _insumoCtrl.dispose();
    _proveedorCtrl.dispose();
    _cantidadCtrl.dispose();
    _costoCtrl.dispose();
    super.dispose();
  }

  Future<void> _addPurchase() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isAdding = true);
    try {
      final cantidad =
          double.tryParse(_cantidadCtrl.text.replaceAll(',', '.')) ?? 0;
      final costo =
          double.tryParse(_costoCtrl.text.replaceAll(',', '.')) ?? 0;
      await ref.read(dailyCloseProvider.notifier).addPurchase(
            insumo: _insumoCtrl.text.trim(),
            proveedor: _proveedorCtrl.text.trim().isEmpty
                ? null
                : _proveedorCtrl.text.trim(),
            cantidad: cantidad,
            costo: costo,
          );
      _insumoCtrl.clear();
      _proveedorCtrl.clear();
      _cantidadCtrl.clear();
      _costoCtrl.clear();
    } finally {
      if (mounted) setState(() => _isAdding = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final purchases = widget.state.purchases;
    double total = 0;
    for (final p in purchases) {
      total += p.costo;
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Form
        Form(
          key: _formKey,
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('AGREGAR COMPRA',
                      style: widget.theme.textTheme.bodySmall?.copyWith(
                          color: widget.colors.textSecondary,
                          letterSpacing: 1)),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _insumoCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Insumo',
                      hintText: 'Ej: Pan, queso, carne...',
                    ),
                    validator: (v) =>
                        (v == null || v.trim().isEmpty) ? 'Requerido' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _proveedorCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Proveedor (opcional)',
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _cantidadCtrl,
                          keyboardType: const TextInputType.numberWithOptions(
                              decimal: true),
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(
                                RegExp(r'[\d.,]+')),
                          ],
                          decoration: const InputDecoration(
                            labelText: 'Cantidad',
                          ),
                          validator: (v) {
                            if (v == null || v.trim().isEmpty) {
                              return 'Requerido';
                            }
                            final n = double.tryParse(v.replaceAll(',', '.'));
                            if (n == null || n <= 0) return 'Inválido';
                            return null;
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          controller: _costoCtrl,
                          keyboardType: const TextInputType.numberWithOptions(
                              decimal: true),
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(
                                RegExp(r'[\d.,]+')),
                          ],
                          decoration: const InputDecoration(
                            labelText: 'Costo (\$)',
                            prefixText: '\$ ',
                          ),
                          validator: (v) {
                            if (v == null || v.trim().isEmpty) {
                              return 'Requerido';
                            }
                            final n = double.tryParse(v.replaceAll(',', '.'));
                            if (n == null || n <= 0) return 'Inválido';
                            return null;
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: _isAdding ? null : _addPurchase,
                      icon: _isAdding
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child:
                                  CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.add, size: 18),
                      label: const Text('Agregar Compra'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),

        const SizedBox(height: 16),

        // Total
        Text(
          'Total Compras: \$${total.toStringAsFixed(2)}',
          style: GoogleFonts.jetBrainsMono(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: widget.colors.warning,
          ),
        ),
        const SizedBox(height: 8),

        // List
        if (purchases.isEmpty)
          Padding(
            padding: const EdgeInsets.all(24),
            child: Center(
              child: Text('No hay compras registradas hoy.',
                  style: widget.theme.textTheme.bodyMedium
                      ?.copyWith(color: widget.colors.textSecondary)),
            ),
          )
        else
          ...purchases.map((p) => _purchaseTile(p)),
      ],
    );
  }

  Widget _purchaseTile(DailyPurchase purchase) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: ListTile(
        title: Text(purchase.insumo,
            style: widget.theme.textTheme.bodyMedium),
        subtitle: Text(
          purchase.proveedor != null
              ? '${purchase.cantidad.toStringAsFixed(1)}x · ${purchase.proveedor}'
              : '${purchase.cantidad.toStringAsFixed(1)}x',
          style: widget.theme.textTheme.bodySmall,
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '\$${purchase.costo.toStringAsFixed(2)}',
              style: GoogleFonts.jetBrainsMono(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: widget.colors.warning,
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              icon: Icon(Icons.delete_outline,
                  size: 18, color: widget.colors.danger),
              onPressed: () => _confirmDeletePurchase(purchase.id),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDeletePurchase(String id) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar compra'),
        content: const Text('¿Estás seguro de eliminar esta compra?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              ref.read(dailyCloseProvider.notifier).deletePurchase(id);
            },
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
  }
}

// =========================================================================
// TAB 4: NÓMINA
// =========================================================================

class _NominaTab extends ConsumerStatefulWidget {
  final DailyCloseState state;
  final AppColorsTheme colors;
  final ThemeData theme;
  final DailyCloseNotifier notifier;

  const _NominaTab({
    required this.state,
    required this.colors,
    required this.theme,
    required this.notifier,
  });

  @override
  ConsumerState<_NominaTab> createState() => _NominaTabState();
}

class _NominaTabState extends ConsumerState<_NominaTab> {
  final Map<String, bool> _trabajo = {};
  final Map<String, String> _jornada = {};
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _initFromState());
  }

  void _initFromState() {
    final state = widget.state;
    for (final worker in state.workers) {
      final existing = state.payrollEntries
          .where((p) => p.usuarioId == worker.id)
          .firstOrNull;
      _trabajo[worker.id] = existing?.trabajo ?? false;
      _jornada[worker.id] = existing?.jornada ?? 'diurna';
    }
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final workers = widget.state.workers;
    final stimulus = widget.notifier.calculateStimulus();

    if (workers.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text('No hay trabajadores activos.',
              style: widget.theme.textTheme.bodyMedium
                  ?.copyWith(color: widget.colors.textSecondary)),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Stimulus info
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Icon(Icons.info_outline,
                    size: 18, color: widget.colors.warning),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Estímulo: \$${stimulus.toStringAsFixed(2)} por '
                    'trabajador que trabajó (\$100 c/\$5000 sobre \$25000)',
                    style: widget.theme.textTheme.bodySmall?.copyWith(
                      color: widget.colors.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),

        // Worker list
        ...workers.map((worker) => _workerTile(worker, stimulus)),

        const SizedBox(height: 16),

        // Save button
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: _isSaving ? null : _saveAll,
            icon: _isSaving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.save, size: 18),
            label: const Text('Guardar Nómina'),
          ),
        ),
      ],
    );
  }

  Widget _workerTile(User worker, double stimulus) {
    final worked = _trabajo[worker.id] ?? false;
    final jornada = _jornada[worker.id] ?? 'diurna';
    final salarioBase = worker.salary;
    final estimuloCalculado = worked ? stimulus : 0.0;
    final total = worked ? salarioBase + estimuloCalculado : 0.0;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                // Active toggle
                Switch(
                  value: worked,
                  onChanged: (v) {
                    setState(() => _trabajo[worker.id] = v);
                  },
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        worker.fullName,
                        style: widget.theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        worked ? 'Trabajó hoy' : 'No trabajó',
                        style: widget.theme.textTheme.bodySmall?.copyWith(
                          color: worked
                              ? widget.colors.success
                              : widget.colors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (worked) ...[
              const Divider(),
              // Jornada selector
              Row(
                children: [
                  Text('Jornada: ',
                      style: widget.theme.textTheme.bodySmall?.copyWith(
                          color: widget.colors.textSecondary)),
                  const SizedBox(width: 8),
                  DropdownButton<String>(
                    value: jornada,
                    underline: const SizedBox(),
                    items: const [
                      DropdownMenuItem(
                          value: 'diurna', child: Text('Diurna')),
                      DropdownMenuItem(
                          value: 'nocturna', child: Text('Nocturna')),
                      DropdownMenuItem(
                          value: 'media', child: Text('Media')),
                    ],
                    onChanged: (v) {
                      if (v != null) {
                        setState(() => _jornada[worker.id] = v);
                      }
                    },
                  ),
                ],
              ),
              const SizedBox(height: 8),
              // Salary details
              Row(
                children: [
                  Expanded(
                    child: _salaryField(
                        'Salario Base', '\$${salarioBase.toStringAsFixed(2)}'),
                  ),
                  Expanded(
                    child: _salaryField(
                        'Estímulo', '\$${estimuloCalculado.toStringAsFixed(2)}'),
                  ),
                  Expanded(
                    child: _salaryField('Total',
                        '\$${total.toStringAsFixed(2)}', bold: true),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _salaryField(String label, String value, {bool bold = false}) {
    return Column(
      children: [
        Text(label,
            style: widget.theme.textTheme.bodySmall
                ?.copyWith(color: widget.colors.textSecondary)),
        const SizedBox(height: 2),
        Text(
          value,
          style: GoogleFonts.jetBrainsMono(
            fontSize: bold ? 15 : 13,
            fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
            color: bold ? widget.colors.accent : widget.colors.textPrimary,
          ),
        ),
      ],
    );
  }

  Future<void> _saveAll() async {
    setState(() => _isSaving = true);
    try {
      final state = widget.state;
      final stimulus = widget.notifier.calculateStimulus();

      for (final worker in state.workers) {
        final worked = _trabajo[worker.id] ?? false;
        final jornada = _jornada[worker.id];

        await widget.notifier.upsertPayroll(
          usuarioId: worker.id,
          trabajo: worked,
          jornada: worked ? jornada : null,
          salarioBase: worker.salary,
          estimulo: worked ? stimulus : 0,
        );
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Nómina guardada correctamente')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al guardar: $e'),
            backgroundColor: widget.colors.danger,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }
}
