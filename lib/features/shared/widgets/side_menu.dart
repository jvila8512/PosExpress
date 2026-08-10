import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:etecsa/config/theme/app_colors.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:google_fonts/google_fonts.dart';

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

  // ── REDES menu ─────────────────────────────────────────────────
  final List<AppMenuItem> _redesMenuItems = [
    const AppMenuItem(icon: Icons.home, label: 'Inicio', route: '/'),
    const AppMenuItem(icon: Icons.add_circle_outline, label: 'Nuevo Pedido', route: '/orders/new'),
    const AppMenuItem(icon: Icons.list_alt, label: 'Seguimiento', route: '/orders/tracking'),
    const AppMenuItem(icon: Icons.history, label: 'Historial', route: '/orders/history'),
    const AppMenuItem(icon: Icons.people_outline, label: 'Clientes', route: '/clients'),
    const AppMenuItem(icon: Icons.contact_phone_outlined, label: 'Contactos Confianza', route: '/contacts'),
    const AppMenuItem(icon: Icons.settings_outlined, label: 'Configuración', route: '/settings'),
  ];

  // ── COCINA menu ────────────────────────────────────────────────
  final List<AppMenuItem> _cocinaMenuItems = [
    const AppMenuItem(icon: Icons.home, label: 'Inicio', route: '/'),
    const AppMenuItem(icon: Icons.view_column, label: 'Cola de Cocina', route: '/kitchen'),
    const AppMenuItem(icon: Icons.contact_phone_outlined, label: 'Contactos Confianza', route: '/contacts'),
    const AppMenuItem(icon: Icons.settings_outlined, label: 'Configuración', route: '/settings'),
  ];

  // ── DOMICILIO menu ─────────────────────────────────────────────
  final List<AppMenuItem> _domicilioMenuItems = [
    const AppMenuItem(icon: Icons.home, label: 'Inicio', route: '/'),
    const AppMenuItem(icon: Icons.delivery_dining, label: 'Entregas', route: '/delivery'),
    const AppMenuItem(icon: Icons.contact_phone_outlined, label: 'Contactos Confianza', route: '/contacts'),
    const AppMenuItem(icon: Icons.settings_outlined, label: 'Configuración', route: '/settings'),
  ];

  // ── ADMIN menu ─────────────────────────────────────────────────
  final List<AppMenuItem> _adminMenuItems = [
    const AppMenuItem(icon: Icons.home, label: 'Inicio', route: '/'),
    const AppMenuItem(icon: Icons.add_circle_outline, label: 'Nuevo Pedido', route: '/orders/new'),
    const AppMenuItem(icon: Icons.people_alt, label: 'Usuarios', route: '/workers'),
    const AppMenuItem(icon: Icons.inventory_2_outlined, label: 'Productos', route: '/products'),
    const AppMenuItem(icon: Icons.category_outlined, label: 'Categorías', route: '/categories'),
    const AppMenuItem(icon: Icons.account_balance, label: 'Cierre del Día', route: '/daily-close'),
    const AppMenuItem(icon: Icons.people_outline, label: 'Clientes', route: '/clients'),
    const AppMenuItem(icon: Icons.contact_phone_outlined, label: 'Contactos Confianza', route: '/contacts'),
    const AppMenuItem(icon: Icons.receipt_long_outlined, label: 'Gastos', route: '/expenses'),
    const AppMenuItem(icon: Icons.settings_outlined, label: 'Configuración', route: '/settings'),
    const AppMenuItem(icon: Icons.help_outline, label: 'Ayuda', route: '/help'),
    const AppMenuItem(icon: Icons.key, label: 'Mi Licencia', route: '/my-license'),
    const AppMenuItem(icon: Icons.file_upload_outlined, label: 'Exportar/Importar', route: '/exports'),
  ];

  // ── SUPER ADMIN menu (extends admin + licenses) ────────────────
  final List<AppMenuItem> _superAdminMenuItems = [
    const AppMenuItem(icon: Icons.home, label: 'Inicio', route: '/'),
    const AppMenuItem(icon: Icons.add_circle_outline, label: 'Nuevo Pedido', route: '/orders/new'),
    const AppMenuItem(icon: Icons.people_alt, label: 'Usuarios', route: '/workers'),
    const AppMenuItem(icon: Icons.inventory_2_outlined, label: 'Productos', route: '/products'),
    const AppMenuItem(icon: Icons.category_outlined, label: 'Categorías', route: '/categories'),
    const AppMenuItem(icon: Icons.account_balance, label: 'Cierre del Día', route: '/daily-close'),
    const AppMenuItem(icon: Icons.people_outline, label: 'Clientes', route: '/clients'),
    const AppMenuItem(icon: Icons.contact_phone_outlined, label: 'Contactos Confianza', route: '/contacts'),
    const AppMenuItem(icon: Icons.receipt_long_outlined, label: 'Gastos', route: '/expenses'),
    const AppMenuItem(icon: Icons.settings_outlined, label: 'Configuración', route: '/settings'),
    const AppMenuItem(icon: Icons.help_outline, label: 'Ayuda', route: '/help'),
    const AppMenuItem(icon: Icons.key, label: 'Mi Licencia', route: '/my-license'),
    const AppMenuItem(icon: Icons.admin_panel_settings, label: 'Gestión de Licencias', route: '/licenses'),
    const AppMenuItem(icon: Icons.file_upload_outlined, label: 'Exportar/Importar', route: '/exports'),
  ];

  List<AppMenuItem> get _currentMenuItems {
    if (_userRole == 'super_admin') return _superAdminMenuItems;
    if (_userRole == 'admin') return _adminMenuItems;
    if (_userRole == 'redes' || _userRole == 'vendedor') return _redesMenuItems;
    if (_userRole == 'cocina') return _cocinaMenuItems;
    if (_userRole == 'domicilio') return _domicilioMenuItems;
    return _adminMenuItems;
  }

  @override
  void initState() {
    super.initState();
    _loadUserRole();
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
      // Prefijo match
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

  String get _roleTitle {
    switch (_userRole) {
      case 'super_admin':
        return 'SUPER ADMIN';
      case 'admin':
        return 'ADMINISTRADOR';
      case 'redes':
        return 'REDES';
      case 'vendedor':
        return 'REDES';
      case 'cocina':
        return 'COCINA';
      case 'domicilio':
        return 'DOMICILIO';
      case 'mesero':
        return 'MESERO';
      default:
        return 'MENÚ';
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.forBrightness(Theme.of(context).brightness);
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
                  color: AppColors.accent,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.restaurant_menu, color: Colors.white, size: 24),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Hamburguesa Express',
                    style: GoogleFonts.dmSans(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: colors.textPrimary,
                    ),
                  ),
                  if (_appVersion.isNotEmpty)
                    Text(
                      'v$_appVersion',
                      style: GoogleFonts.dmSans(
                        fontSize: 11,
                        color: colors.textSecondary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),

        // Role title
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 10),
          child: Text(
            _roleTitle,
            style: GoogleFonts.dmSans(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: AppColors.accent,
              letterSpacing: 1,
            ),
          ),
        ),

        // Menu items
        ..._currentMenuItems.map((item) => NavigationDrawerDestination(
          icon: Icon(item.icon, color: item.color ?? AppColors.accent),
          selectedIcon: Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: AppColors.accent,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(item.icon, color: Colors.white),
          ),
          label: Text(
            item.label,
            style: GoogleFonts.dmSans(),
          ),
        )),

        const Padding(
          padding: EdgeInsets.fromLTRB(28, 16, 28, 10),
          child: Divider(),
        ),

        // Logout
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
              backgroundColor: colors.danger,
              foregroundColor: Colors.white,
            ),
          ),
        ),

        // Debug role
        if (_userRole.isNotEmpty)
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              'Rol: $_userRole',
              style: GoogleFonts.dmSans(fontSize: 10, color: colors.textSecondary),
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
