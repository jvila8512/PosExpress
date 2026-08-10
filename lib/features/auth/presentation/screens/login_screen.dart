import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:etecsa/features/auth/presentation/providers/auth_provider.dart';
import 'package:etecsa/features/auth/presentation/providers/login_form_provider.dart';
import 'package:etecsa/config/theme/app_theme.dart';
import 'package:etecsa/core/security/license_service.dart';
import 'package:etecsa/core/database/app_database.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool _obscurePassword = true;
  bool _isLoading = false;
  Map<String, dynamic>? _licenseInfo;
  bool _checkingLicense = true;
  String _androidId = '';

  @override
  void initState() {
    super.initState();
    _loadLicenseInfo();
    _loadAndroidId();
  }

  Future<void> _loadAndroidId() async {
    try {
      final id = await LicenseService.getDeviceFingerprint();
      if (mounted) {
        setState(() {
          _androidId = id;
        });
      }
    } catch (e) {
      // Fingerprint no es crítico en login: si falla, no mostramos el chip.
      debugPrint('Error loading android id: $e');
    }
  }

  Future<void> _loadLicenseInfo() async {
    try {
      final activatedLicense = await LicenseService.getActivatedLicenseCode();

      if (activatedLicense != null && activatedLicense.isNotEmpty) {
        final db = AppDatabase.instance;
        final validationResult = await LicenseService.validateLicenseWithTamperProtection(db);

        if (validationResult.isValid) {
          setState(() {
            _licenseInfo = {
              'status': 'active',
              'plan': validationResult.planName,
              'expiresAt': validationResult.expiresAt,
              'remainingDays': validationResult.remainingDays,
            };
          });
        } else if (validationResult.isExpired) {
          setState(() {
            _licenseInfo = {
              'status': 'expired',
              'plan': validationResult.planName,
              'expiresAt': validationResult.expiredDate,
              'remainingDays': 0,
            };
          });
        } else {
          setState(() {
            _licenseInfo = {
              'status': 'invalid',
              'plan': 'UNKNOWN',
              'message': validationResult.errorMessage,
            };
          });
        }
      } else {
        setState(() {
          _licenseInfo = {
            'status': 'none',
          };
        });
      }
    } catch (e) {
      debugPrint('Error loading license info: $e');
      setState(() {
        _licenseInfo = {
          'status': 'error',
          'message': e.toString(),
        };
      });
    }

    setState(() {
      _checkingLicense = false;
    });
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
          if (_checkingLicense)
            const LinearProgressIndicator()
          else
            _buildLicenseStatusCard(),
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
            color: AppTheme.colorCeleste.withValues(alpha: 0.1),
            padding: const EdgeInsets.all(40),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'MiNegocio POS',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    color: AppTheme.colorCeleste,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 24),
                if (!_checkingLicense) _buildLicenseStatusCard(),
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

  Widget _buildLicenseStatusCard() {
    if (_licenseInfo == null || _licenseInfo!['status'] == 'none') {
      return _buildNoLicenseCard();
    }

    final status = _licenseInfo!['status'];

    if (status == 'active') {
      return _buildActiveLicenseCard();
    } else if (status == 'expired') {
      return _buildExpiredLicenseCard();
    } else {
      return _buildInvalidLicenseCard();
    }
  }

  Widget _buildNoLicenseCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.orange.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.orange.shade200),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.orange.shade100,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.key_off,
                  color: Colors.orange.shade700,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Sin Licencia',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.orange.shade700,
                      ),
                    ),
                    Text(
                      'Activa tu licencia para usar la app',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.orange.shade600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => context.go('/activation'),
              icon: const Icon(Icons.key, size: 18),
              label: const Text('Activar Licencia'),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.orange.shade700,
                side: BorderSide(color: Colors.orange.shade300),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
      ),
      ),
        _buildAndroidIdChip(),
      ],
    ),
  );
}

Widget _buildActiveLicenseCard() {
  final plan = _licenseInfo!['plan'] ?? '-';
    final expiresAt = _licenseInfo!['expiresAt'] as DateTime?;
    final remainingDays = _licenseInfo!['remainingDays'] ?? 0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.green.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.green.shade200),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.green.shade100,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.verified,
                  color: Colors.green.shade700,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          'Licencia Activa',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.green.shade700,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: AppTheme.colorCeleste,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            plan,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (expiresAt != null)
                      Text(
                        'Expira: ${expiresAt.day}/${expiresAt.month}/${expiresAt.year}',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.green.shade600,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.timer,
                  size: 16,
                  color: remainingDays <= 7 ? Colors.orange : Colors.green,
                ),
                const SizedBox(width: 4),
                Text(
                  remainingDays > 0
                      ? '$remainingDays días restantes'
                      : 'Vence hoy',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: remainingDays <= 7
                        ? Colors.orange.shade700
                        : Colors.green.shade700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExpiredLicenseCard() {
    final plan = _licenseInfo!['plan'] ?? '-';
    final expiresAt = _licenseInfo!['expiresAt'] as DateTime?;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.red.shade200),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.red.shade100,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.error,
                  color: Colors.red.shade700,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Licencia Vencida',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.red.shade700,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        plan,
                        style: const TextStyle(
                          color: Colors.black87,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (expiresAt != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                'Venció: ${expiresAt.day}/${expiresAt.month}/${expiresAt.year}',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.red.shade600,
                ),
              ),
            ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => context.go('/activation'),
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('Renovar Licencia'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red.shade600,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
        ),
      ),
      _buildAndroidIdChip(),
    ],
    ),
  );
}

  Widget _buildInvalidLicenseCard() {
    final message = _licenseInfo!['message'] ?? 'Error desconocido';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.grey.shade200,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.warning,
                  color: Colors.grey.shade700,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Licencia Inválida',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.grey.shade700,
                      ),
                    ),
                    Text(
                      message,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => context.go('/activation'),
              icon: const Icon(Icons.key, size: 18),
              label: const Text('Activar Nueva Licencia'),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.grey.shade700,
                side: BorderSide(color: Colors.grey.shade400),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
        ),
      ),
      _buildAndroidIdChip(),
    ],
    ),
  );
}

  Widget _buildAndroidIdChip() {
    if (_androidId.isEmpty) return const SizedBox.shrink();
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(Icons.phone_android, size: 16, color: Colors.blue.shade700),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'ID de Dispositivo',
                  style: TextStyle(fontSize: 10, color: Colors.blue.shade600),
                ),
                Text(
                  _androidId,
                  style: TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue.shade700,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          IconButton(
            icon: Icon(Icons.copy, size: 16, color: Colors.blue.shade700),
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: _androidId));
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('ID copiado'),
                    duration: Duration(seconds: 2),
                  ),
                );
              }
            },
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
          ),
        ],
      ),
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
                      color: AppTheme.colorCeleste,
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
                      borderSide: const BorderSide(color: AppTheme.colorCeleste, width: 2),
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
                      borderSide: const BorderSide(color: AppTheme.colorCeleste, width: 2),
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
                          activeColor: AppTheme.colorCeleste,
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
                    backgroundColor: AppTheme.colorMorado,
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