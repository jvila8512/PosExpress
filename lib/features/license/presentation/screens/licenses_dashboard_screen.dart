import 'package:flutter/material.dart';
import 'package:etecsa/config/theme/app_theme.dart';
import 'package:etecsa/core/database/app_database.dart';
import 'package:etecsa/features/license/presentation/screens/clientes_screen.dart';
import 'package:etecsa/features/license/presentation/screens/plan_pricing_screen.dart';
import 'package:etecsa/features/license/presentation/screens/all_licenses_screen.dart';
import 'package:etecsa/features/shared/widgets/side_menu.dart';

class LicensesDashboardScreen extends StatefulWidget {
  final int initialTab;

  const LicensesDashboardScreen({super.key, this.initialTab = 0});

  @override
  State<LicensesDashboardScreen> createState() =>
      _LicensesDashboardScreenState();
}

class _LicensesDashboardScreenState extends State<LicensesDashboardScreen>
    with SingleTickerProviderStateMixin {
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  late TabController _tabController;
  int _currentIndex = 0;

  // Stats
  bool _isLoading = true;
  int _activas = 0;
  int _vencidas = 0;
  int _canceladas = 0;
  double _ingresosTotales = 0;
  int _clientesCount = 0;
  List<LicenciasClienteData> _recentLicenses = [];
  List<LicenciasClienteData> _proximasVencer = [];
  List<Cliente> _clientes = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 4,
      vsync: this,
      initialIndex: widget.initialTab,
    );
    _currentIndex = widget.initialTab;
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        setState(() => _currentIndex = _tabController.index);
      }
    });
    _loadDashboardData();
  }

  Future<void> _loadDashboardData() async {
    setState(() => _isLoading = true);
    try {
      final db = AppDatabase.instance;

      final results = await Future.wait([
        db.getLicenciasCountByEstado(),
        db.getTotalLicenciasIngresos(),
        db.getClientesCount(),
        db.getAllLicenciasCliente(),
        db.getAllClientes(),
        db.getLicenciasProximasVencer(7),
      ]);

      final countByEstado = results[0] as Map<String, int>;
      final ingresos = results[1] as double;
      final clientesCount = results[2] as int;
      final allLicenses = results[3] as List<LicenciasClienteData>;
      final clientes = results[4] as List<Cliente>;
      final proximas = results[5] as List<LicenciasClienteData>;

      final recent = allLicenses.take(5).toList();

      if (mounted) {
        setState(() {
          _activas = countByEstado['activa'] ?? 0;
          _vencidas = countByEstado['vencida'] ?? 0;
          _canceladas = countByEstado['cancelada'] ?? 0;
          _ingresosTotales = ingresos;
          _clientesCount = clientesCount;
          _recentLicenses = recent;
          _clientes = clientes;
          _proximasVencer = proximas;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _getClienteName(String clienteId) {
    final cliente = _clientes.where((c) => c.id == clienteId).firstOrNull;
    return cliente?.nombre ?? 'Desconocido';
  }

  String _getClienteNegocio(String clienteId) {
    final cliente = _clientes.where((c) => c.id == clienteId).firstOrNull;
    return cliente?.negocio ?? '';
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  String _formatCurrency(double amount) {
    if (amount >= 1000000) {
      return '\$${(amount / 1000000).toStringAsFixed(1)}M';
    } else if (amount >= 1000) {
      return '\$${(amount / 1000).toStringAsFixed(1)}K';
    } else {
      return '\$${amount.toStringAsFixed(2)}';
    }
  }

  Color _getEstadoColor(String estado) {
    switch (estado.toLowerCase()) {
      case 'activa':
        return Colors.green;
      case 'vencida':
        return Colors.red;
      case 'cancelada':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      drawer: SideMenu(scaffoldKey: _scaffoldKey),
      appBar: AppBar(
        title: Text(_getAppBarTitle()),
        backgroundColor: AppTheme.colorCeleste,
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.menu),
          onPressed: () => _scaffoldKey.currentState?.openDrawer(),
        ),
        actions: [
          if (_currentIndex == 0 && _proximasVencer.isNotEmpty)
            Stack(
              children: [
                IconButton(
                  icon: const Icon(Icons.notifications),
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          '${_proximasVencer.length} licencias próximas a vencer',
                        ),
                        backgroundColor: Colors.orange,
                      ),
                    );
                  },
                ),
                Positioned(
                  right: 8,
                  top: 8,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                    ),
                    constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
                    child: Text(
                      '${_proximasVencer.length}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              ],
            ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadDashboardData,
          ),
        ],
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildDashboardTab(),
          const ClientesScreen(embedded: true),
          const PlanPricingScreen(embedded: true),
          const AllLicensesScreen(embedded: true),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          _tabController.animateTo(index);
          setState(() => _currentIndex = index);
        },
        type: BottomNavigationBarType.fixed,
        selectedItemColor: AppTheme.colorMorado,
        unselectedItemColor: Colors.grey,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.dashboard),
            label: 'Dashboard',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.people),
            label: 'Clientes',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.card_membership),
            label: 'Planes',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.vpn_key),
            label: 'Licencias',
          ),
        ],
      ),
    );
  }

  String _getAppBarTitle() {
    switch (_currentIndex) {
      case 0:
        return 'Gestión de Licencias';
      case 1:
        return 'Clientes';
      case 2:
        return 'Planes de Precios';
      case 3:
        return 'Todas las Licencias';
      default:
        return 'Gestión de Licencias';
    }
  }

  // ================================================================
  // DASHBOARD TAB
  // ================================================================

  Widget _buildDashboardTab() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return RefreshIndicator(
      onRefresh: _loadDashboardData,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Stats Cards - 2x2 Grid (ALL same size)
            Row(
          children: [
            Expanded(
              child: _buildStatCard(
                icon: Icons.verified_user,
                value: _activas.toString(),
                label: 'Activas',
                color: Colors.green,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildStatCard(
                icon: Icons.error_outline,
                value: _vencidas.toString(),
                label: 'Vencidas',
                color: Colors.red,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildStatCard(
                icon: Icons.attach_money,
                value: _formatCurrency(_ingresosTotales),
                label: 'Ingresos',
                color: AppTheme.colorMorado,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildStatCard(
                icon: Icons.people,
                value: _clientesCount.toString(),
                label: 'Clientes',
                color: AppTheme.colorCeleste,
              ),
            ),
          ],
        ),

            const SizedBox(height: 24),

            // Licenses by Status
            _buildSectionTitle('LICENCIAS POR ESTADO'),
            const SizedBox(height: 12),
            _buildStatusChart(),

            const SizedBox(height: 24),

            // Expiring Soon
            if (_proximasVencer.isNotEmpty) ...[
              _buildSectionTitle('PRÓXIMAS A VENCER'),
              const SizedBox(height: 12),
              _buildExpiringSoon(),
              const SizedBox(height: 24),
            ],

            // Recent Licenses
            _buildSectionTitle('LICENCIAS RECIENTES'),
            const SizedBox(height: 12),
            _buildRecentLicenses(),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required String value,
    required String label,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
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
          // Row: icon top-right + value left
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: FittedBox(
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
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 22),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade600,
              fontWeight: FontWeight.w500,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.bold,
        color: Colors.grey,
        letterSpacing: 1,
      ),
    );
  }

  Widget _buildStatusChart() {
    final total = _activas + _vencidas + _canceladas;
    if (total == 0) {
      return Container(
        padding: const EdgeInsets.all(24),
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
        child: Center(
          child: Column(
            children: [
              Icon(Icons.bar_chart, size: 48, color: Colors.grey.shade300),
              const SizedBox(height: 8),
              Text(
                'Sin datos de licencias',
                style: TextStyle(color: Colors.grey.shade500, fontSize: 14),
              ),
            ],
          ),
        ),
      );
    }

    return Row(
      children: [
        Expanded(
          child: _buildStatusCard(
            icon: Icons.check_circle,
            count: _activas,
            label: 'Activas',
            color: Colors.green,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildStatusCard(
            icon: Icons.error,
            count: _vencidas,
            label: 'Vencidas',
            color: Colors.red,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildStatusCard(
            icon: Icons.cancel,
            count: _canceladas,
            label: 'Canceladas',
            color: Colors.orange,
          ),
        ),
      ],
    );
  }

  Widget _buildStatusCard({
    required IconData icon,
    required int count,
    required String label,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 6),
          Text(
            '$count',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 2),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: color.withValues(alpha: 0.8),
              ),
              maxLines: 1,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExpiringSoon() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.orange.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orange.shade200),
      ),
      child: Column(
        children: _proximasVencer.map((lic) {
          final dias = lic.fechaExpiracion.difference(DateTime.now()).inDays;
          final nombre = _getClienteName(lic.clienteId);

          return Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              children: [
                Icon(Icons.schedule, size: 16, color: Colors.orange.shade700),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    nombre,
                    style: const TextStyle(
                      fontWeight: FontWeight.w500,
                      fontSize: 13,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Text(
                  '$dias días',
                  style: TextStyle(
                    color: dias <= 3 ? Colors.red : Colors.orange.shade700,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildRecentLicenses() {
    if (_recentLicenses.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(24),
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
        child: Center(
          child: Column(
            children: [
              Icon(Icons.key_off, size: 48, color: Colors.grey.shade300),
              const SizedBox(height: 8),
              Text(
                'Sin licencias recientes',
                style: TextStyle(color: Colors.grey.shade500, fontSize: 14),
              ),
            ],
          ),
        ),
      );
    }

    // Group recent licenses by clienteId
    final Map<String, List<LicenciasClienteData>> grouped = {};
    for (final lic in _recentLicenses) {
      grouped.putIfAbsent(lic.clienteId, () => []).add(lic);
    }

    // Sort groups: client with most licenses first
    final sortedEntries = grouped.entries.toList()
      ..sort((a, b) => b.value.length.compareTo(a.value.length));

    return Column(
      children: sortedEntries.map((entry) {
        final licencias = entry.value;
        final clienteNombre = _getClienteName(entry.key);
        final clienteNegocio = _getClienteNegocio(entry.key);
        final activeCount = licencias.where((l) => l.estado == 'activa').length;

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: ExpansionTile(
            tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            shape: const Border(),
            collapsedShape: const Border(),
            leading: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppTheme.colorCeleste.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Center(
                child: Text(
                  clienteNombre.isNotEmpty
                      ? clienteNombre[0].toUpperCase()
                      : '?',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.colorCeleste,
                  ),
                ),
              ),
            ),
            title: Text(
              clienteNombre,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
            subtitle: Row(
              children: [
                if (clienteNegocio.isNotEmpty) ...[
                  Flexible(
                    child: Text(
                      clienteNegocio,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '$activeCount activas',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: Colors.green.shade700,
                    ),
                  ),
                ),
              ],
            ),
            children: licencias.map((lic) {
              final estadoColor = _getEstadoColor(lic.estado);

              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    // Status icon
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: estadoColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        lic.estado == 'activa'
                            ? Icons.check_circle
                            : lic.estado == 'cancelada'
                                ? Icons.cancel
                                : Icons.error,
                        color: estadoColor,
                        size: 18,
                      ),
                    ),
                    const SizedBox(width: 10),
                    // Code + plan
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            lic.codigo,
                            style: const TextStyle(
                              fontWeight: FontWeight.w500,
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              Text(
                                _getPlanDisplay(lic.plan),
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Exp: ${_formatDate(lic.fechaExpiracion)}',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey.shade500,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    // Status badge
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 3),
                      decoration: BoxDecoration(
                        color: estadoColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                            color: estadoColor.withValues(alpha: 0.3)),
                      ),
                      child: Text(
                        lic.estado.toUpperCase(),
                        style: TextStyle(
                          color: estadoColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 9,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        );
      }).toList(),
    );
  }

  String _getPlanDisplay(String plan) {
    switch (plan.toUpperCase()) {
      case 'PRO':
        return 'PRO';
      case 'NEGOCIO':
        return 'NEGOCIO';
      case 'FREE':
        return 'FREE';
      default:
        return plan.toUpperCase();
    }
  }
}
