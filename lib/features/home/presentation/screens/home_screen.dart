import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:etecsa/config/theme/app_theme.dart';
import 'package:etecsa/features/shared/widgets/side_menu.dart';
import 'package:etecsa/data/repositories/home_repository.dart';
import 'package:etecsa/core/database/app_database.dart';
import 'package:etecsa/features/home/presentation/widgets/kpi_cards_row.dart';
import 'package:etecsa/features/home/presentation/widgets/sales_bar_chart.dart';
import 'package:etecsa/features/home/presentation/widgets/payment_donut_chart.dart';
import 'package:etecsa/features/home/presentation/widgets/top_products_list.dart';
import 'package:etecsa/features/home/presentation/widgets/alerts_banner.dart';
import 'package:etecsa/features/license/presentation/widgets/license_alerts_banner.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

final homeDataProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  final repository = HomeRepository();
  return await repository.loadHomeData();
});

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  String _userName = 'Usuario';
  String _userRole = '';

  @override
  void initState() {
    super.initState();
    _loadUserName();
    // Invalidar cache del homeDataProvider para que siempre cargue datos frescos
    // cuando el usuario navega de vuelta al Home (ej: después de una venta)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.invalidate(homeDataProvider);
    });
  }

  Future<void> _loadUserName() async {
    final storage = const FlutterSecureStorage();
    final userId = await storage.read(key: 'user_id');
    final role = await storage.read(key: 'user_role') ?? '';
    if (mounted) {
      setState(() => _userRole = role);
    }
    if (userId != null) {
      final db = AppDatabase.instance;
      final users = await db.getAllUsers();
      final currentUser = users.where((u) => u.id == userId).firstOrNull;
      if (mounted && currentUser != null) {
        setState(() {
          _userName = currentUser.fullName;
        });
      }
    }
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) {
      return 'Buenos días';
    } else if (hour < 18) {
      return 'Buenas tardes';
    } else {
      return 'Buenas noches';
    }
  }

  bool get _isVendedor => _userRole == 'vendedor';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      drawer: SideMenu(scaffoldKey: _scaffoldKey),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(homeDataProvider);
        },
        child: CustomScrollView(
          slivers: [
            // Modern App Bar
            SliverAppBar(
              expandedHeight: 120,
              floating: false,
              pinned: true,
              backgroundColor: AppTheme.colorCeleste,
              leading: IconButton(
                icon: const Icon(Icons.menu, color: Colors.white),
                onPressed: () => _scaffoldKey.currentState?.openDrawer(),
              ),
              flexibleSpace: FlexibleSpaceBar(
                title: Text(
                  '${_getGreeting()},',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w400,
                  ),
                ),
                background: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        AppTheme.colorCeleste,
                        AppTheme.colorCeleste.withValues(alpha: 0.8),
                        AppTheme.colorMorado.withValues(alpha: 0.6),
                      ],
                    ),
                  ),
                ),
              ),
              actions: [
                Padding(
                  padding: const EdgeInsets.only(right: 16),
                  child: Center(
                    child: Text(
                      _userName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),

            // Content
            SliverToBoxAdapter(
              child: Consumer(
                builder: (context, ref, child) {
                  final homeData = ref.watch(homeDataProvider);

                  return homeData.when(
                    data: (data) => _buildContent(data),
                    loading: () => const Center(
                      child: Padding(
                        padding: EdgeInsets.all(50),
                        child: CircularProgressIndicator(
                          color: AppTheme.colorCeleste,
                        ),
                      ),
                    ),
                    error: (error, stack) => Center(
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.error_outline,
                              size: 48,
                              color: Colors.red,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Error al cargar datos',
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: 8),
                            ElevatedButton(
                              onPressed: () => ref.invalidate(homeDataProvider),
                              child: const Text('Reintentar'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(Map<String, dynamic> data) {
    final session = data['activeSession'] as dynamic;
    final isSessionOpen = session != null && session.status == 'open';

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Session Status Banner
        _buildSessionBanner(isSessionOpen, session),

        const SizedBox(height: 20),

        // Alerts Banner (if any) — solo admin
        if (!_isVendedor) ...[
          AlertsBanner(data: data),
          const LicenseAlertsBanner(),
        ],

        // KPI Cards — vendedor NO ve Ganancia
        KPICardsRow(data: data, isVendedor: _isVendedor),

        const SizedBox(height: 24),

        // Sales Bar Chart (Last 30 days) — solo admin ve chart completo
        if (!_isVendedor)
          SalesBarChart(dailySales: data['dailySales'] as Map<int, double>),

        if (!_isVendedor) const SizedBox(height: 24),

        // Payment Method Donut Chart — vendedor puede ver su desglose
        PaymentDonutChart(
          paymentMethods: data['paymentMethods'] as Map<String, double>,
        ),

        const SizedBox(height: 24),

        // Top Products List
        TopProductsList(
          products: data['topProducts'] as List<Map<String, dynamic>>,
        ),

        const SizedBox(height: 24),

        // Quick Access Buttons — solo admin
        if (!_isVendedor) _buildQuickAccessButtons(),

        if (!_isVendedor) const SizedBox(height: 32),
      ],
      ),
    );
  }

  Widget _buildSessionBanner(bool isOpen, dynamic session) {
    return GestureDetector(
      onTap: isOpen ? () => context.go('/pos') : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: isOpen
                ? [const Color(0xFF1D9E75), const Color(0xFF1D9E75).withValues(alpha: 0.8)]
                : [Colors.orange.shade400, Colors.orange.shade600],
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: (isOpen ? const Color(0xFF1D9E75) : Colors.orange).withValues(alpha: 0.3),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                isOpen ? Icons.lock_open : Icons.lock,
                color: Colors.white,
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isOpen ? 'Caja ABIERTA' : 'Caja CERRADA',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (isOpen) ...[
                    const SizedBox(height: 2),
                    Text(
                      'Ventas del día: \$${(session?.totalSales ?? 0).toStringAsFixed(0)}',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.9),
                        fontSize: 13,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (!isOpen)
              ElevatedButton(
                onPressed: () => context.go('/pos'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.orange.shade700,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
                child: const Text(
                  'Abrir caja',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              )
            else
              Icon(
                Icons.chevron_right,
                color: Colors.white.withValues(alpha: 0.7),
                size: 20,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickAccessButtons() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'ACCESO RÁPIDO',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: Colors.grey,
            letterSpacing: 1,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildQuickButton(
                'Ventas',
                Icons.analytics_outlined,
                const Color(0xFF378ADD),
                () => context.go('/reports'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildQuickButton(
                'Productos',
                Icons.inventory_2_outlined,
                const Color(0xFF1D9E75),
                () => context.go('/products'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildQuickButton(
                'Inventario',
                Icons.warehouse_outlined,
                const Color(0xFFEF9F27),
                () => context.go('/inventory'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildQuickButton(
                'Cajas',
                Icons.point_of_sale,
                AppTheme.colorMorado,
                () => context.go('/sessions'),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildQuickButton(
    String label,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withValues(alpha: 0.1),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: color, size: 22),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  color: color,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}