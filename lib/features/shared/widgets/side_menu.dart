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

  // ── Menú único para todos los roles (spec R5) ─────────────────
  final List<AppMenuItem> _menuItems = [
    const AppMenuItem(icon: Icons.people_alt, label: 'Usuarios', route: '/workers'),
    const AppMenuItem(icon: Icons.settings_outlined, label: 'Configuración', route: '/settings'),
  ];

  List<AppMenuItem> get _currentMenuItems => _menuItems;

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
