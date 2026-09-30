import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:etecsa/features/auth/presentation/providers/auth_provider.dart';
import 'package:etecsa/features/auth/presentation/providers/login_form_provider.dart';
import 'package:etecsa/config/theme/app_colors.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool _obscurePassword = true;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isTablet = constraints.maxWidth > 600;

        return GestureDetector(
          onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
          child: Scaffold(
            body: SafeArea(
              child: isTablet
                  ? _buildTabletLayout(context, constraints)
                  : _buildPhoneLayout(context, constraints),
            ),
          ),
        );
      },
    );
  }

  Widget _buildPhoneLayout(BuildContext context, BoxConstraints constraints) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(height: 20),
          _buildLoginForm(context, isTablet: false),
        ],
      ),
    );
  }

  Widget _buildTabletLayout(BuildContext context, BoxConstraints constraints) {
    return Row(
      children: [
        Expanded(
          flex: 1,
          child: Container(
            color: AppColors.accent.withValues(alpha: 0.1),
            padding: const EdgeInsets.all(40),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'MiNegocio POS',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    color: AppColors.accent,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),

        Expanded(
          flex: 1,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(40),
            child: _buildLoginForm(context, isTablet: true),
          ),
        ),
      ],
    );
  }

  Widget _buildLoginForm(BuildContext context, {required bool isTablet}) {
    return Consumer(
      builder: (context, ref, _) {
        final loginForm = ref.watch(loginFormProvider);
        final textStyles = Theme.of(context).textTheme;

        ref.listen(authProvider, (previous, next) {
          if (next.errorMessage.isNotEmpty) {
            ScaffoldMessenger.of(context).hideCurrentSnackBar();
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(next.errorMessage),
                backgroundColor: Colors.red,
              ),
            );
          }
          if (next.isAuthenticated) {
            context.go('/');
          }
        });

        return StatefulBuilder(
          builder: (context, setState) {
            return Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (!isTablet) ...[
                  Text(
                    'Bienvenido',
                    style: textStyles.headlineMedium?.copyWith(
                      color: AppColors.accent,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Ingresa a tu cuenta',
                    style: textStyles.bodyLarge?.copyWith(
                      color: Colors.grey,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 32),
                ],

                TextField(
                  onChanged: ref.read(loginFormProvider.notifier).onEmailChange,
                  keyboardType: TextInputType.text,
                  decoration: InputDecoration(
                    labelText: 'Usuario',
                    prefixIcon: const Icon(Icons.person_outline),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(15),
                      borderSide: BorderSide.none,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(15),
                      borderSide: BorderSide(color: Colors.grey.shade200),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(15),
                      borderSide: const BorderSide(color: AppColors.accent, width: 2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                TextField(
                  onChanged: ref.read(loginFormProvider.notifier).onPasswordChanged,
                  obscureText: _obscurePassword,
                  decoration: InputDecoration(
                    labelText: 'Contraseña',
                    prefixIcon: const Icon(Icons.lock_outline),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(15),
                      borderSide: BorderSide.none,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(15),
                      borderSide: BorderSide(color: Colors.grey.shade200),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(15),
                      borderSide: const BorderSide(color: AppColors.accent, width: 2),
                    ),
                    suffixIcon: IconButton(
                      icon: Icon(_obscurePassword ? Icons.visibility : Icons.visibility_off),
                      onPressed: () {
                        setState(() {
                          _obscurePassword = !_obscurePassword;
                        });
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Checkbox(
                          value: loginForm.rememberMe,
                          onChanged: (v) => ref.read(loginFormProvider.notifier).onRememberMeChanged(v ?? false),
                          activeColor: AppColors.accent,
                        ),
                        Text('Recordarme', style: TextStyle(color: Colors.grey.shade600)),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                ElevatedButton(
                  onPressed: _isLoading ? null : () async {
                    setState(() {
                      _isLoading = true;
                    });

                    final username = loginForm.email.value.trim();
                    final password = loginForm.password.value.trim();

                    debugPrint('=== LOGIN INTENTO ===');
                    debugPrint('Username: $username');
                    debugPrint('Password: $password');
                    debugPrint('====================');

                    await ref.read(authProvider.notifier).loginUser(username, password, loginForm.rememberMe);

                    if (context.mounted) {
                      setState(() {
                        _isLoading = false;
                      });
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.accent,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15),
                    ),
                    elevation: 0,
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation(Colors.white),
                          ),
                        )
                      : const Text(
                          'INICIAR SESIÓN',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                ),
              ],
            );
          },
        );
      },
    );
  }
}