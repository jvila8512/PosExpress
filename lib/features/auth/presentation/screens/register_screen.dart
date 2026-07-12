import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:drift/drift.dart' hide Column;
import 'package:uuid/uuid.dart';
import 'package:etecsa/config/theme/app_theme.dart';
import 'package:etecsa/core/database/app_database.dart';

const _secureStorage = FlutterSecureStorage();

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _usernameController = TextEditingController();
  final _nameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _obscurePassword = true;
  bool _isLoading = false;
  String? _errorMessage;
  bool _isFirstTime = false;

  @override
  void initState() {
    super.initState();
    _checkFirstTime();
  }

  Future<void> _checkFirstTime() async {
    // Verificar si es primera vez y crear superusuario automáticamente
    final db = AppDatabase.instance;
    final users = await db.getAllUsers();
    
    if (users.isEmpty) {
      // Crear superusuario automáticamente
      await _createSuperUser();
    }
  }

  Future<void> _createSuperUser() async {
    setState(() => _isLoading = true);
    try {
      final db = AppDatabase.instance;
      final uuid = Uuid();
      final userId = uuid.v4();
      
      // Crear superusuario admin
      await db.createUser(
        id: userId,
        username: 'admin',
        fullName: 'Administrador',
        password: 'Nathy*070721',
        role: 'admin',
      );
      
      if (mounted) {
        context.go('/login');
      }
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _nameController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _createAccount() async {
    final username = _usernameController.text.trim();
    final name = _nameController.text.trim();
    final password = _passwordController.text;
    final confirmPassword = _confirmPasswordController.text;

    if (username.isEmpty || name.isEmpty || password.isEmpty) {
      setState(() => _errorMessage = 'Todos los campos son requeridos');
      return;
    }

    if (password != confirmPassword) {
      setState(() => _errorMessage = 'Las contraseñas no coinciden');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final db = AppDatabase.instance;
      debugPrint('=== REGISTER START ===');
      debugPrint('DB instance: ${db.hashCode}');
      
      final userId = const Uuid().v4();
      
      await db.into(db.users).insert(
        UsersCompanion.insert(
          id: userId,
          username: username,
          passwordHash: password,
          role: 'admin',
          fullName: name,
        ),
      );

      // Verificar que se insertó
      final verifyUser = await db.getUserByUsername(username);
      debugPrint('=== USER VERIFY ===');
      debugPrint('Found user: ${verifyUser?.username}');
      debugPrint('===================');

      final sessionToken = const Uuid().v4();
      await _secureStorage.write(key: 'session_token', value: sessionToken);
      await _secureStorage.write(key: 'user_id', value: userId);
      await _secureStorage.write(key: 'user_role', value: 'admin');
      await _secureStorage.write(key: 'has_users_created', value: 'true');

      debugPrint('=== USER CREATED ===');
      debugPrint('Username: $username');
      debugPrint('User ID: $userId');
      debugPrint('====================');

      if (mounted) {
        context.go('/');
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error al crear cuenta';
        _isLoading = false;
      });
      debugPrint('Error creating account: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isTablet = constraints.maxWidth > 600;
        
        return GestureDetector(
          onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
          child: Scaffold(
            backgroundColor: Colors.white,
            body: SafeArea(
              child: isTablet ? _buildTabletLayout() : _buildPhoneLayout(),
            ),
          ),
        );
      },
    );
  }

  Widget _buildPhoneLayout() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const SizedBox(height: 20),
          Align(
            alignment: Alignment.centerLeft,
            child: IconButton(
              onPressed: () => context.go('/login'),
              icon: const Icon(Icons.arrow_back_rounded, color: AppTheme.colorCeleste, size: 30),
            ),
          ),
          const SizedBox(height: 20),
          _buildRegisterForm(),
        ],
      ),
    );
  }

  Widget _buildTabletLayout() {
    return Row(
      children: [
        Expanded(
          flex: 1,
          child: Container(
            color: AppTheme.colorCeleste.withValues(alpha: 0.1),
            padding: const EdgeInsets.all(40),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('MiNegocio POS', style: Theme.of(context).textTheme.headlineMedium?.copyWith(color: AppTheme.colorCeleste, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
        ),
        Expanded(
          flex: 1,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(40),
            child: Column(
              children: [
                IconButton(onPressed: () => context.go('/login'), icon: const Icon(Icons.arrow_back_rounded, color: Colors.grey)),
                _buildRegisterForm(),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLogo({double size = 80}) {
    return Container(
      width: size, height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: AppTheme.colorCeleste.withValues(alpha: 0.3), blurRadius: 20, offset: const Offset(0, 10))],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Image.asset('assets/images/logo.png', fit: BoxFit.cover, errorBuilder: (_, __, ___) => Container(color: AppTheme.colorCeleste, child: const Icon(Icons.storefront, size: 40, color: Colors.white))),
      ),
    );
  }

  Widget _buildRegisterForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Crear cuenta', style: Theme.of(context).textTheme.headlineMedium?.copyWith(color: AppTheme.colorCeleste, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
        const SizedBox(height: 8),
        Text('Regístrate para comenzar', style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: Colors.grey), textAlign: TextAlign.center),
        const SizedBox(height: 24),
        
        if (_errorMessage != null) ...[
          Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(10)), child: Text(_errorMessage!, style: const TextStyle(color: Colors.red), textAlign: TextAlign.center)),
          const SizedBox(height: 16),
        ],

        TextField(controller: _usernameController, decoration: _inputDecoration('Usuario', Icons.person_outline)),
        const SizedBox(height: 12),
        TextField(controller: _nameController, keyboardType: TextInputType.name, decoration: _inputDecoration('Nombre completo', Icons.badge_outlined)),
        const SizedBox(height: 12),
        TextField(controller: _passwordController, obscureText: _obscurePassword, decoration: _inputDecoration('Contraseña', Icons.lock_outline, suffix: IconButton(icon: Icon(_obscurePassword ? Icons.visibility : Icons.visibility_off), onPressed: () => setState(() => _obscurePassword = !_obscurePassword)))),
        const SizedBox(height: 12),
        TextField(controller: _confirmPasswordController, obscureText: _obscurePassword, decoration: _inputDecoration('Confirmar contraseña', Icons.lock_outline)),
        const SizedBox(height: 20),

        ElevatedButton(
          onPressed: _isLoading ? null : _createAccount,
          style: ElevatedButton.styleFrom(backgroundColor: AppTheme.colorMorado, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)), elevation: 0),
          child: _isLoading 
            ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation(Colors.white))) 
            : const Text('CREAR CUENTA', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        ),
        const SizedBox(height: 16),

        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('¿Ya tienes cuenta? ', style: TextStyle(color: Colors.grey.shade600)),
            GestureDetector(onTap: () => context.go('/login'), child: Text('Inicia sesión', style: TextStyle(color: AppTheme.colorMorado, fontWeight: FontWeight.bold))),
          ],
        ),
      ],
    );
  }

  InputDecoration _inputDecoration(String label, IconData icon, {Widget? suffix}) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon),
      filled: true,
      fillColor: Colors.grey.shade50,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide(color: Colors.grey.shade200)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: const BorderSide(color: AppTheme.colorCeleste, width: 2)),
      suffixIcon: suffix,
    );
  }
}