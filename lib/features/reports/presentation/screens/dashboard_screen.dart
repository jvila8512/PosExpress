import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:etecsa/config/theme/app_colors.dart';
import 'package:etecsa/features/shared/widgets/side_menu.dart';
import 'package:etecsa/features/orders/domain/entities/restaurant_order.dart';
import 'package:etecsa/features/orders/presentation/providers/order_provider.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

const _dashboardSecureStorage = FlutterSecureStorage();

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  bool _isSuperAdmin = false;
  late Future<Map<String, dynamic>> _statsFuture;

  @override
  void initState() {
    super.initState();
    _checkAdminStatus();
    _statsFuture = _loadStats();
  }

  Future<void> _checkAdminStatus() async {
    final role = await _dashboardSecureStorage.read(key: 'user_role');
    if (mounted) {
      setState(() {
        // Both super_admin and admin can see admin options
        _isSuperAdmin = role == 'super_admin' || role == 'admin';
      });
    }
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      drawer: SideMenu(scaffoldKey: _scaffoldKey),
      appBar: AppBar(
        title: const Text('Inicio'),
        backgroundColor: AppColors.accent,
        leading: IconButton(icon: const Icon(Icons.menu), onPressed: () => _scaffoldKey.currentState?.openDrawer()),
      ),
      body: FutureBuilder(
        future: _statsFuture,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return _buildErrorState();
          }

          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          
          final stats = snapshot.data!;
          final todayOrders = stats['todayOrders'] as List<RestaurantOrder>;
          
          return SingleChildScrollView(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ====== HOY ======
                const Text('HOY', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.grey)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    _buildStatCard('Ventas', '\$${stats['salesToday']}', Colors.green),
                    const SizedBox(width: 8),
                    _buildStatCard('Efectivo', '\$${stats['cashToday']}', Colors.orange),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    _buildStatCard('Transfer', '\$${stats['transferToday']}', Colors.purple),
                    const SizedBox(width: 8),
                    _buildStatCard('Pedidos', '${todayOrders.length}', Colors.blue),
                  ],
                ),
                
                const SizedBox(height: 16),
                
                // ====== MES ======
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(8)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('MES ACTUAL', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.blue)),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          _buildStatCard('Ventas', '\$${stats['salesMonth']}', Colors.blue),
                          const SizedBox(width: 8),
                          _buildStatCard('Efectivo', '\$${stats['cashMonth']}', Colors.orange),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          _buildStatCard('Transfer', '\$${stats['transferMonth']}', Colors.purple),
                          const SizedBox(width: 8),
                          _buildStatCard('Pedidos', '${(stats['monthOrders'] as List).length}', Colors.blue),
                        ],
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 16),
                
                // Quick actions
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _buildQuickAction(context, 'Nueva Venta', Icons.point_of_sale, '/pos'),
                    _buildQuickAction(context, 'Productos', Icons.inventory_2, '/products'),
                    _buildQuickAction(context, 'Categorías', Icons.category, '/categories'),
                    _buildQuickAction(context, 'Cajas', Icons.history, '/sessions'),
                    if (_isSuperAdmin) ...[
                      _buildQuickAction(context, 'Gestionar Licencias', Icons.key, '/licenses'),
                      _buildQuickAction(context, 'Usuarios', Icons.people, '/users'),
                    ],
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('Error al cargar los datos de ventas'),
          const SizedBox(height: 12),
          ElevatedButton(
            onPressed: () {
              setState(() {
                _statsFuture = _loadStats();
              });
            },
            child: const Text('Reintentar'),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String title, String value, Color color) {
    return Expanded(
      child: Container(
        height: 80,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: TextStyle(fontSize: 11, color: color)),
            Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color)),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickAction(BuildContext context, String title, IconData icon, String route) {
    return Card(
      margin: const EdgeInsets.only(bottom: 6),
      child: ListTile(
        leading: Icon(icon, color: AppColors.accent),
        title: Text(title),
        trailing: const Icon(Icons.arrow_forward_ios, size: 14),
        onTap: () => context.go(route),
      ),
    );
  }

  Future<Map<String, dynamic>> _loadStats() async {
    final repository = ref.read(orderRepositoryProvider);
    final now = DateTime.now();
    final monthStart = DateTime(now.year, now.month, 1);

    final todayOrders = await repository.getTodayOrders();
    final monthOrders = await repository.getOrdersSince(monthStart);

    // ====== HOY ======
    double salesToday = 0;
    double cashToday = 0;
    double transferToday = 0;
    for (final order in todayOrders) {
      salesToday += order.montoTotal;
      if (_isCash(order.metodoPago)) {
        cashToday += order.montoTotal;
      } else if (_isTransfer(order.metodoPago)) {
        transferToday += order.montoTotal;
      }
    }

    // ====== MES ACTUAL ======
    double salesMonth = 0;
    double cashMonth = 0;
    double transferMonth = 0;
    for (final order in monthOrders) {
      salesMonth += order.montoTotal;
      if (_isCash(order.metodoPago)) {
        cashMonth += order.montoTotal;
      } else if (_isTransfer(order.metodoPago)) {
        transferMonth += order.montoTotal;
      }
    }

    return {
      'salesToday': salesToday,
      'cashToday': cashToday,
      'transferToday': transferToday,
      'todayOrders': todayOrders,
      // Month data
      'salesMonth': salesMonth,
      'cashMonth': cashMonth,
      'transferMonth': transferMonth,
      'monthOrders': monthOrders,
    };
  }

  bool _isCash(String? method) {
    final normalized = method?.toLowerCase();
    return normalized == 'efectivo' || normalized == 'cash';
  }

  bool _isTransfer(String? method) {
    final normalized = method?.toLowerCase();
    return normalized == 'transferencia' || normalized == 'transfer';
  }
}