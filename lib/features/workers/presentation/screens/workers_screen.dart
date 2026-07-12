import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:etecsa/features/shared/shared.dart';
import 'package:etecsa/core/database/app_database.dart';
import 'package:etecsa/config/theme/app_theme.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:drift/drift.dart' show Value;
import 'package:uuid/uuid.dart';

const _secureStorage = FlutterSecureStorage();

class WorkersScreen extends ConsumerStatefulWidget {
  const WorkersScreen({super.key});

  @override
  ConsumerState<WorkersScreen> createState() => _WorkersScreenState();
}

class _WorkersScreenState extends ConsumerState<WorkersScreen> {
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  List<User> _users = [];
  bool _isLoading = true;
  String _currentRole = '';
  String _currentUserId = '';
  int _maxVendedores = 1; // default FREE plan limit
  int _currentVendedorCount = 0;

  bool get _isSuperAdmin => _currentRole == 'super_admin';
  bool get _canAddVendedor => _currentVendedorCount < _maxVendedores;
  bool get _canAddAdmin => _isSuperAdmin;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    try {
      // 1. Get current user role
      final role = await _secureStorage.read(key: 'user_role') ?? '';
      _currentRole = role;
      _currentUserId = await _secureStorage.read(key: 'user_id') ?? '';

      // 2. Load all users
      final db = AppDatabase.instance;
      final allUsers = await db.getAllUsers();

      // 3. Show all users including self, but filter by role visibility
      // super_admin sees everyone except other super_admins (keeps self)
      // admin sees vendedores + other admins (not super_admins, keeps self)
      if (_isSuperAdmin) {
        _users = allUsers.where((u) => u.role != 'super_admin' || u.id == _currentUserId).toList();
      } else if (role == 'admin') {
        _users = allUsers.where((u) => u.role == 'vendedor' || u.role == 'admin').toList();
      } else {
        _users = [];
      }

      // 4. Count current vendedores
      _currentVendedorCount = _users.where((u) => u.role == 'vendedor').length;

      // 5. Get maxVendedores from license plan
      await _loadMaxVendedores();
    } catch (e) {
      print('Error loading users: $e');
      _users = [];
    }

    setState(() => _isLoading = false);
  }

  Future<void> _loadMaxVendedores() async {
    try {
      final db = AppDatabase.instance;
      final planStr = await _secureStorage.read(key: 'license_plan') ?? 'free';

      // Map SecureStorage plan name to DB plan name (case-insensitive)
      final planName = planStr.toUpperCase();
      final plan = await db.getPlanByName(planName);

      if (plan != null) {
        _maxVendedores = plan.maxVendedores;
      } else {
        // Fallback defaults (solo si el plan no se encontró en DB)
        switch (planName) {
          case 'PRO':
            _maxVendedores = 5;
            break;
          case 'NEGOCIO':
            _maxVendedores = 50;
            break;
          case 'MAX':
            _maxVendedores = 100;
            break;
          case 'MAXPRO':
            _maxVendedores = 999;
            break;
          default:
            _maxVendedores = 1; // FREE
        }
      }
    } catch (e) {
      print('Error loading license plan: $e');
      _maxVendedores = 1; // safe fallback
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      drawer: SideMenu(scaffoldKey: _scaffoldKey),
      appBar: AppBar(
        title: const Text('Usuarios'),
        backgroundColor: AppTheme.colorCeleste,
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.menu),
          onPressed: () => _scaffoldKey.currentState?.openDrawer(),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _users.isEmpty
              ? _buildEmptyState()
              : _buildUsersList(),
      floatingActionButton: _buildFab(),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.people_outline, size: 64, color: Colors.grey.shade400),
          const SizedBox(height: 16),
          Text(
            'No hay usuarios registrados',
            style: TextStyle(fontSize: 18, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 8),
          if (_isSuperAdmin) ...[
            Text(
              'Podés crear administradores y vendedores',
              style: TextStyle(color: Colors.grey.shade500),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => _showAddUserDialog(),
              icon: const Icon(Icons.person_add),
              label: const Text('Crear Usuario'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.colorMorado,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
            ),
          ] else if (_canAddVendedor) ...[
            Text(
              'Podés crear hasta $_maxVendedores vendedor${_maxVendedores == 1 ? '' : 'es'} según tu plan',
              style: TextStyle(color: Colors.grey.shade500),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => _showAddUserDialog(),
              icon: const Icon(Icons.person_add),
              label: const Text('Agregar Vendedor'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.colorMorado,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
            ),
          ] else ...[
            Text(
              'Alcanzaste el límite de $_maxVendedores vendedor${_maxVendedores == 1 ? '' : 'es'} de tu plan',
              style: TextStyle(color: Colors.orange.shade700, fontWeight: FontWeight.w500),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildUsersList() {
    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _users.length + 1, // +1 for header
        itemBuilder: (context, index) {
          if (index == 0) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                children: [
                  Text(
                    '${_users.length} usuario${_users.length == 1 ? '' : 's'}',
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const Spacer(),
                  if (!_isSuperAdmin)
                    Text(
                      'Vendedores: $_currentVendedorCount/$_maxVendedores',
                      style: TextStyle(
                        color: _canAddVendedor ? Colors.grey.shade600 : Colors.orange.shade700,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                ],
              ),
            );
          }

          final user = _users[index - 1];
          return _buildUserCard(user);
        },
      ),
    );
  }

  Widget _buildUserCard(User user) {
    final isVendedor = user.role == 'vendedor';
    final isCurrentUser = user.id == _currentUserId;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: isCurrentUser
              ? AppTheme.colorMorado
              : isVendedor
                  ? Colors.green
                  : AppTheme.colorCeleste,
          child: Icon(
            isCurrentUser
                ? Icons.person
                : isVendedor
                    ? Icons.storefront
                    : Icons.admin_panel_settings,
            color: Colors.white,
            size: 20,
          ),
        ),
        title: Row(
          children: [
            Text(
              user.fullName.isNotEmpty ? user.fullName : user.username,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
            if (isCurrentUser) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(
                  color: AppTheme.colorMorado.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text(
                  'Vos',
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppTheme.colorMorado),
                ),
              ),
            ],
          ],
        ),
        subtitle: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: isVendedor ? Colors.green.shade100 : AppTheme.colorCeleste.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                isVendedor ? 'Vendedor' : 'Admin',
                style: TextStyle(
                  fontSize: 12,
                  color: isVendedor ? Colors.green.shade700 : AppTheme.colorCeleste,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '@${user.username}',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            user.active
                ? const Icon(Icons.check_circle, color: Colors.green, size: 20)
                : const Icon(Icons.cancel, color: Colors.red, size: 20),
            // PopupMenu with actions
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert, size: 20),
              padding: EdgeInsets.zero,
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'edit',
                  child: Text('Editar'),
                ),
                const PopupMenuItem(
                  value: 'reset',
                  child: Text('Resetear contraseña'),
                ),
                if (!isCurrentUser) PopupMenuItem(
                  value: 'toggle',
                  child: Text(user.active ? 'Desactivar' : 'Activar'),
                ),
              ],
              onSelected: (value) {
                if (value == 'edit') {
                  _showEditUserDialog(user);
                } else if (value == 'reset') {
                  _showResetPasswordDialog(user);
                } else if (value == 'toggle') {
                  _toggleUser(user);
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget? _buildFab() {
    if (_isSuperAdmin) {
      // Super_admin can always add users (at least admin type)
      return FloatingActionButton.extended(
        onPressed: () => _showAddUserDialog(),
        icon: const Icon(Icons.person_add),
        label: const Text('Nuevo Usuario'),
        backgroundColor: AppTheme.colorMorado,
        foregroundColor: Colors.white,
      );
    }

    if (_currentRole == 'admin' && _canAddVendedor) {
      return FloatingActionButton.extended(
        onPressed: () => _showAddUserDialog(),
        icon: const Icon(Icons.person_add),
        label: const Text('Nuevo Vendedor'),
        backgroundColor: AppTheme.colorMorado,
        foregroundColor: Colors.white,
      );
    }

    return null;
  }

  void _showAddUserDialog() {
    final nameController = TextEditingController();
    final userController = TextEditingController();
    final passController = TextEditingController();

    // Super_admin can choose role; admin always creates vendedor
    String selectedRole = _isSuperAdmin ? 'admin' : 'vendedor';

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(_isSuperAdmin ? 'Crear Usuario' : 'Agregar Vendedor'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_isSuperAdmin) ...[
                  Text(
                    'Como super_admin podés crear administradores y vendedores.',
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                  ),
                ] else ...[
                  Text(
                    'Vendedores: $_currentVendedorCount/$_maxVendedores de tu plan.',
                    style: TextStyle(
                      color: _canAddVendedor ? Colors.grey.shade600 : Colors.orange.shade700,
                      fontSize: 12,
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'Nombre completo',
                    prefixIcon: Icon(Icons.person),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: userController,
                  decoration: const InputDecoration(
                    labelText: 'Usuario',
                    prefixIcon: Icon(Icons.alternate_email),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: passController,
                  decoration: const InputDecoration(
                    labelText: 'Contraseña',
                    prefixIcon: Icon(Icons.lock),
                  ),
                  obscureText: true,
                ),
                // Role dropdown only for super_admin
                if (_isSuperAdmin) ...[
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: selectedRole,
                    items: const [
                      DropdownMenuItem(value: 'admin', child: Text('Admin')),
                      DropdownMenuItem(value: 'vendedor', child: Text('Vendedor')),
                    ],
                    onChanged: (v) {
                      setDialogState(() => selectedRole = v!);
                    },
                    decoration: const InputDecoration(
                      labelText: 'Rol',
                      prefixIcon: Icon(Icons.badge),
                    ),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (nameController.text.isEmpty ||
                    userController.text.isEmpty ||
                    passController.text.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Completa todos los campos')),
                  );
                  return;
                }

                // Check vendedor limit when creating vendedor
                if (selectedRole == 'vendedor' && !_canAddVendedor) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'Alcanzaste el límite de $_maxVendedores vendedor${_maxVendedores == 1 ? '' : 'es'} de tu plan',
                      ),
                      backgroundColor: Colors.orange,
                    ),
                  );
                  return;
                }

            final db = AppDatabase.instance;

            // Check duplicate username (case-insensitive)
            final allUsers = await db.getAllUsers();
            final newUsername = userController.text.trim().toLowerCase();
            final exists = allUsers.any((u) => u.username.toLowerCase() == newUsername);
            if (exists) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Ese nombre de usuario ya existe'),
                  backgroundColor: Colors.orange,
                ),
              );
              return;
            }

            final userId = 'user_${const Uuid().v4()}';

            try {
              await db.createUser(
                id: userId,
                username: userController.text.trim(),
                fullName: nameController.text.trim(),
                password: passController.text,
                role: selectedRole,
              );
            } catch (e) {
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Error al crear usuario: $e'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
              return;
            }

                if (mounted) {
                  Navigator.pop(context);
                  _loadData();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        selectedRole == 'admin'
                            ? 'Administrador creado exitosamente'
                            : 'Vendedor agregado exitosamente',
                      ),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.colorMorado,
              ),
              child: const Text('Crear', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  void _showEditUserDialog(User user) {
    final nameController = TextEditingController(text: user.fullName);
    final userController = TextEditingController(text: user.username);
    String selectedRole = user.role;
    bool isCurrentUser = user.id == _currentUserId;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Editar Usuario'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'Nombre completo',
                    prefixIcon: Icon(Icons.person),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: userController,
                  decoration: const InputDecoration(
                    labelText: 'Usuario',
                    prefixIcon: Icon(Icons.alternate_email),
                  ),
                ),
                // Role dropdown only for super_admin editing non-self users
                if (_isSuperAdmin && !isCurrentUser) ...[
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: selectedRole,
                    items: const [
                      DropdownMenuItem(value: 'admin', child: Text('Admin')),
                      DropdownMenuItem(value: 'vendedor', child: Text('Vendedor')),
                    ],
                    onChanged: (v) {
                      setDialogState(() => selectedRole = v!);
                    },
                    decoration: const InputDecoration(
                      labelText: 'Rol',
                      prefixIcon: Icon(Icons.badge),
                    ),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (nameController.text.trim().isEmpty || userController.text.trim().isEmpty) {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    const SnackBar(content: Text('Completa todos los campos')),
                  );
                  return;
                }

                final newUsername = userController.text.trim().toLowerCase();
                final db = AppDatabase.instance;

                // Check duplicate username (unless it's the same user's own username)
                if (newUsername != user.username.toLowerCase()) {
                  final allUsers = await db.getAllUsers();
                  final exists = allUsers.any((u) => u.username.toLowerCase() == newUsername && u.id != user.id);
                  if (exists) {
                    ScaffoldMessenger.of(ctx).showSnackBar(
                      const SnackBar(
                        content: Text('Ese nombre de usuario ya existe'),
                        backgroundColor: Colors.orange,
                      ),
                    );
                    return;
                  }
                }

                // Update user in DB
                await (db.update(db.users)..where((u) => u.id.equals(user.id))).write(
                  UsersCompanion(
                    fullName: Value(nameController.text.trim()),
                    username: Value(newUsername),
                    role: Value(selectedRole),
                  ),
                );

                if (mounted) {
                  Navigator.pop(ctx);
                  _loadData();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Usuario actualizado'),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.colorMorado),
              child: const Text('Guardar', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  void _showResetPasswordDialog(User user) {
    final passController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Resetear contraseña de @${user.username}'),
        content: TextField(
          controller: passController,
          decoration: const InputDecoration(
            labelText: 'Nueva contraseña',
            prefixIcon: Icon(Icons.lock),
          ),
          obscureText: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (passController.text.isEmpty) return;

              final db = AppDatabase.instance;
              await db.updatePassword(user.id, passController.text);

              if (mounted) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Contraseña actualizada'),
                    backgroundColor: Colors.green,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.colorMorado,
            ),
            child: const Text('Guardar', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _toggleUser(User user) async {
    final db = AppDatabase.instance;
    await (db.update(db.users)..where((u) => u.id.equals(user.id))).write(
      UsersCompanion(active: Value(!user.active)),
    );
    _loadData();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            user.active ? 'Usuario desactivado' : 'Usuario activado',
          ),
          backgroundColor: user.active ? Colors.orange : Colors.green,
        ),
      );
    }
  }
}
