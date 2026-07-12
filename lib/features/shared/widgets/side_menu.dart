import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:etecsa/config/theme/app_theme.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:etecsa/features/shared/services/KeyValueStorageService.dart';

class AppMenuItem {
  final IconData icon;
  final String label;
  final String route;
  final Color? color;

  const AppMenuItem({
    required this.icon,
    required this.label,
    required this.route,
    this.color,
  });
}

class SideMenu extends StatefulWidget {
  final GlobalKey<ScaffoldState> scaffoldKey;

  const SideMenu({
    super.key,
    required this.scaffoldKey,
  });

  @override
  State<SideMenu> createState() => _SideMenuState();
}

class _SideMenuState extends State<SideMenu> {
  String _userRole = '';
  String _appVersion = '';
  int _selectedIndex = 0;
  bool _isPrefacturaMode = false;

  // Menú vendedor (limitado)
  final List<AppMenuItem> _vendedorMenuItems = [
    AppMenuItem(icon: Icons.home, label: 'Inicio', route: '/'),
    AppMenuItem(icon: Icons.help_outline, label: 'Ayuda', route: '/help'),
    AppMenuItem(icon: Icons.shopping_cart_outlined, label: 'Punto de Venta', route: '/pos'),
    AppMenuItem(icon: Icons.point_of_sale, label: 'Mis Cajas', route: '/sessions'),
    AppMenuItem(icon: Icons.download, label: 'Recibir Despacho', route: '/sync/recibir-despacho'),
    AppMenuItem(icon: Icons.history, label: 'Historial Ventas', route: '/sync/historial-ventas'),
    AppMenuItem(icon: Icons.assignment, label: 'Rendición', route: '/sync/rendicion'),
  AppMenuItem(icon: Icons.inventory_2_outlined, label: 'Mis Despachos', route: '/sync/mis-despachos'),
  AppMenuItem(icon: Icons.assignment_outlined, label: 'Mis Rendiciones', route: '/sync/mis-rendiciones'),
  AppMenuItem(icon: Icons.swap_horiz, label: 'Hist. Transferencias', route: '/sync/historial-transferencias'),
    AppMenuItem(icon: Icons.key, label: 'Mi Licencia', route: '/my-license'),
    AppMenuItem(icon: Icons.folder_open_outlined, label: 'Exportaciones', route: '/exports'),
    AppMenuItem(icon: Icons.settings_outlined, label: 'Configuración', route: '/settings'),
  ];

  // Menú admin
  final List<AppMenuItem> _adminMenuItems = [
    AppMenuItem(icon: Icons.home, label: 'Inicio', route: '/'),
    AppMenuItem(icon: Icons.help_outline, label: 'Ayuda', route: '/help'),
    AppMenuItem(icon: Icons.inventory_2_outlined, label: 'Productos', route: '/products'),
    AppMenuItem(icon: Icons.category_outlined, label: 'Categorías', route: '/categories'),
    AppMenuItem(icon: Icons.shopping_cart_outlined, label: 'Punto de Venta', route: '/pos'),
    AppMenuItem(icon: Icons.point_of_sale, label: 'Cajas', route: '/sessions'),
    AppMenuItem(icon: Icons.warehouse_outlined, label: 'Inventario', route: '/inventory'),
    AppMenuItem(icon: Icons.receipt_long_outlined, label: 'Gastos', route: '/expenses'),
    AppMenuItem(icon: Icons.analytics_outlined, label: 'Reportes', route: '/reports'),
    AppMenuItem(icon: Icons.people_outline, label: 'Usuarios', route: '/workers'),
    AppMenuItem(icon: Icons.send, label: 'Despacho', route: '/sync/despacho'),
    AppMenuItem(icon: Icons.assignment_return, label: 'Procesar Rendición', route: '/sync/procesar-rendicion'),
    AppMenuItem(icon: Icons.send_outlined, label: 'Hist. Despachos', route: '/sync/historial-despachos'),
  AppMenuItem(icon: Icons.assignment_outlined, label: 'Hist. Rendiciones', route: '/sync/historial-rendiciones'),
  AppMenuItem(icon: Icons.swap_horiz, label: 'Hist. Transferencias', route: '/sync/historial-transferencias'),
  AppMenuItem(icon: Icons.key, label: 'Mi Licencia', route: '/my-license'),
  AppMenuItem(icon: Icons.folder_open_outlined, label: 'Exportaciones', route: '/exports'),
  AppMenuItem(icon: Icons.settings_outlined, label: 'Configuración', route: '/settings'),
];

// Menú super_admin (todo + licencias)
  final List<AppMenuItem> _superAdminMenuItems = [
    AppMenuItem(icon: Icons.home, label: 'Inicio', route: '/'),
    AppMenuItem(icon: Icons.help_outline, label: 'Ayuda', route: '/help'),
    AppMenuItem(icon: Icons.inventory_2_outlined, label: 'Productos', route: '/products'),
    AppMenuItem(icon: Icons.category_outlined, label: 'Categorías', route: '/categories'),
    AppMenuItem(icon: Icons.upload_file, label: 'Importar Productos', route: '/products/import', color: Colors.deepPurple),
    AppMenuItem(icon: Icons.shopping_cart_outlined, label: 'Punto de Venta', route: '/pos'),
    AppMenuItem(icon: Icons.point_of_sale, label: 'Cajas', route: '/sessions'),
    AppMenuItem(icon: Icons.warehouse_outlined, label: 'Inventario', route: '/inventory'),
    AppMenuItem(icon: Icons.receipt_long_outlined, label: 'Gastos', route: '/expenses'),
    AppMenuItem(icon: Icons.analytics_outlined, label: 'Reportes', route: '/reports'),
    AppMenuItem(icon: Icons.people_outline, label: 'Usuarios', route: '/workers'),
    AppMenuItem(icon: Icons.send, label: 'Despacho', route: '/sync/despacho'),
    AppMenuItem(icon: Icons.assignment_return, label: 'Procesar Rendición', route: '/sync/procesar-rendicion'),
    AppMenuItem(icon: Icons.send_outlined, label: 'Hist. Despachos', route: '/sync/historial-despachos'),
    AppMenuItem(icon: Icons.assignment_outlined, label: 'Hist. Rendiciones', route: '/sync/historial-rendiciones'),
    AppMenuItem(icon: Icons.swap_horiz, label: 'Hist. Transferencias', route: '/sync/historial-transferencias'),
    AppMenuItem(icon: Icons.key, label: 'Mi Licencia', route: '/my-license'),
    AppMenuItem(icon: Icons.folder_open_outlined, label: 'Exportaciones', route: '/exports'),
    AppMenuItem(icon: Icons.settings_outlined, label: 'Configuración', route: '/settings'),
    AppMenuItem(icon: Icons.admin_panel_settings, label: 'Gestión de Licencias', route: '/licenses'),
  ];

  List<AppMenuItem> get _currentMenuItems {
    final items = _getBaseMenuItems();
    final isAdminOrSuperAdmin = _userRole == 'admin' || _userRole == 'super_admin';
    if (_isPrefacturaMode && isAdminOrSuperAdmin) {
      return [
        ...items,
        const AppMenuItem(icon: Icons.description, label: 'Prefactura', route: '/prefactura'),
      ];
    }
    return items;
  }

  List<AppMenuItem> _getBaseMenuItems() {
    if (_userRole == 'super_admin') return _superAdminMenuItems;
    if (_userRole == 'vendedor') return _vendedorMenuItems;
    return _adminMenuItems;
  }

  @override
  void initState() {
    super.initState();
    _loadUserRole();
    _loadPrefacturaMode();
  }

  Future<void> _loadPrefacturaMode() async {
    final storage = KeyValueStorageService();
    final enabled = await storage.getValue('prefactura_mode_enabled');
    if (mounted) {
      setState(() => _isPrefacturaMode = enabled == 'true');
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _updateSelectedIndex();
  }

  void _updateSelectedIndex() {
    if (!mounted) return;
    try {
      final router = GoRouter.of(context);
      final route = router.routeInformationProvider.value.uri.path;
      
      final items = _currentMenuItems;
      for (int i = 0; i < items.length; i++) {
        if (items[i].route == route) {
          if (_selectedIndex != i) {
            setState(() => _selectedIndex = i);
          }
          return;
        }
      }
      // Si no encuentra coincidencia exacta, buscar por prefijo
      for (int i = 0; i < items.length; i++) {
        if (route.startsWith(items[i].route) && items[i].route != '/') {
          if (_selectedIndex != i) {
            setState(() => _selectedIndex = i);
          }
          return;
        }
      }
    } catch (e) {
      // Ignore errors
    }
  }

  Future<void> _loadUserRole() async {
    final storage = const FlutterSecureStorage();
    final role = await storage.read(key: 'user_role') ?? '';

    String version = '';
    try {
      final info = await PackageInfo.fromPlatform();
      version = info.version;
    } catch (_) {}

    if (mounted) {
      setState(() {
        _userRole = role;
        _appVersion = version;
      });
      _updateSelectedIndex();
    }
  }

  void _onItemTap(int index) {
    final items = _currentMenuItems;
    if (index >= 0 && index < items.length) {
      widget.scaffoldKey.currentState?.closeDrawer();
      context.go(items[index].route);
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasNotch = MediaQuery.of(context).viewPadding.top > 35;

    return NavigationDrawer(
      elevation: 1,
      selectedIndex: _selectedIndex,
      onDestinationSelected: _onItemTap,
      children: [
        // Header
          Padding(
            padding: EdgeInsets.fromLTRB(20, hasNotch ? 20 : 30, 16, 10),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppTheme.colorCeleste,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.storefront, color: Colors.white, size: 24),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'PosJVL',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    if (_appVersion.isNotEmpty)
                      Text(
                        'v$_appVersion',
                        style: TextStyle(fontSize: 11, color: Colors.grey.shade500, fontWeight: FontWeight.w500),
                      ),
                  ],
                ),
              ],
            ),
          ),

        // Título según rol
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 10),
          child: Text(
            _userRole == 'super_admin' 
              ? 'ADMINISTRADOR' 
              : _userRole == 'vendedor' 
                ? 'VENDEDOR' 
                : 'MENÚ',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: AppTheme.colorCeleste,
            ),
          ),
        ),

        // Items del menú
        ..._currentMenuItems.map((item) => NavigationDrawerDestination(
          icon: Icon(item.icon, color: item.color ?? AppTheme.colorCeleste),
          selectedIcon: Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: AppTheme.colorCeleste,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(item.icon, color: Colors.white),
          ),
          label: Text(item.label),
        )),

        const Padding(
          padding: EdgeInsets.fromLTRB(28, 16, 28, 10),
          child: Divider(),
        ),

        // Cerrar sesión
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: ElevatedButton.icon(
            onPressed: () async {
              await _logout();
              if (context.mounted) context.go('/login');
            },
            icon: const Icon(Icons.logout),
            label: const Text('Cerrar sesión'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade400,
              foregroundColor: Colors.white,
            ),
          ),
        ),

        // DEBUG
        if (_userRole.isNotEmpty)
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              'Rol: $_userRole',
              style: const TextStyle(fontSize: 10, color: Colors.grey),
            ),
          ),

        const SizedBox(height: 20),
      ],
    );
  }

  Future<void> _logout() async {
    const storage = FlutterSecureStorage();
    await storage.delete(key: 'session_token');
    await storage.delete(key: 'user_id');
  }
}