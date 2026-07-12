import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:etecsa/config/theme/app_theme.dart';
import 'package:etecsa/features/shared/widgets/side_menu.dart';
import 'package:etecsa/core/database/app_database.dart';
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

  @override
  void initState() {
    super.initState();
    _checkAdminStatus();
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
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      drawer: SideMenu(scaffoldKey: _scaffoldKey),
      appBar: AppBar(
        title: const Text('Inicio'),
        backgroundColor: AppTheme.colorCeleste,
        leading: IconButton(icon: const Icon(Icons.menu), onPressed: () => _scaffoldKey.currentState?.openDrawer()),
      ),
      body: FutureBuilder(
        future: _loadStats(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          
          final stats = snapshot.data!;
          final session = stats['session'] as Session?;
          final todayOrders = stats['todayOrders'] as List<Order>;
          
          return SingleChildScrollView(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Session status - compact
                _buildSessionBanner(session),
                
                const SizedBox(height: 12),
                
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

  Widget _buildSessionBanner(Session? session) {
    if (session != null && session.status == 'open') {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.green.shade100,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(Icons.check_circle, color: Colors.green.shade700, size: 18),
            const SizedBox(width: 6),
            Text('Caja ABIERTA', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green.shade700)),
            const Spacer(),
            Text('\$${session.totalSales.toStringAsFixed(0)}', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green.shade700)),
          ],
        ),
      );
    } else {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.orange.shade100,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(Icons.warning, color: Colors.orange.shade700, size: 18),
            const SizedBox(width: 6),
            Text('Caja cerrada', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.orange.shade700)),
          ],
        ),
      );
    }
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
        leading: Icon(icon, color: AppTheme.colorCeleste),
        title: Text(title),
        trailing: const Icon(Icons.arrow_forward_ios, size: 14),
        onTap: () => context.go(route),
      ),
    );
  }

  Future<Map<String, dynamic>> _loadStats() async {
    final db = AppDatabase.instance;
    final session = await db.getActiveSession();
    
    // ====== HOY ======
    List<Order> todayOrders = [];
    double salesToday = 0;
    double cashToday = 0;
    double transferToday = 0;
    
    if (session != null) {
      todayOrders = await db.getPaidOrdersBySession(session.id);
    } else {
      final allSessions = await db.getAllSessions();
      final today = DateTime.now();
      final todayStart = DateTime(today.year, today.month, today.day);
      
      final todaySessions = allSessions.where((s) {
        return s.openingTime.isAfter(todayStart) || s.openingTime.isAtSameMomentAs(todayStart);
      }).toList();
      
      for (final s in todaySessions) {
        final orders = await db.getPaidOrdersBySession(s.id);
        todayOrders.addAll(orders);
      }
    }
    
    for (final order in todayOrders) {
      salesToday += order.totalAmount;
      final payments = await db.getOrderPayments(order.id);
      for (final payment in payments) {
        if (payment.paymentMethod == 'efectivo') {
          cashToday += payment.amount - (payment.changeGiven ?? 0);
        } else if (payment.paymentMethod == 'transferencia') {
          transferToday += payment.amount;
        }
      }
    }
    
    // ====== MES ACTUAL ======
    final allSessionsMonth = await db.getAllSessions();
    final now = DateTime.now();
    final monthStart = DateTime(now.year, now.month, 1);
    
    double salesMonth = 0;
    double cashMonth = 0;
    double transferMonth = 0;
    List<Order> monthOrders = [];
    
    final monthSessions = allSessionsMonth.where((s) => s.openingTime.isAfter(monthStart)).toList();
    
    for (final s in monthSessions) {
      final orders = await db.getPaidOrdersBySession(s.id);
      monthOrders.addAll(orders);
    }
    
    for (final order in monthOrders) {
      salesMonth += order.totalAmount;
      final payments = await db.getOrderPayments(order.id);
      for (final payment in payments) {
        if (payment.paymentMethod == 'efectivo') {
          cashMonth += payment.amount - (payment.changeGiven ?? 0);
        } else if (payment.paymentMethod == 'transferencia') {
          transferMonth += payment.amount;
        }
      }
    }
    
    return {
      'session': session,
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
}
