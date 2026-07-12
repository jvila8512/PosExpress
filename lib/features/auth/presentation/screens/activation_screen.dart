import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:etecsa/core/security/license_service.dart';
import 'package:etecsa/core/database/app_database.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:etecsa/config/theme/app_theme.dart';

const _secureStorage = FlutterSecureStorage();

class ActivationScreen extends ConsumerStatefulWidget {
  const ActivationScreen({super.key});

  @override
  ConsumerState<ActivationScreen> createState() => _ActivationScreenState();
}

class _ActivationScreenState extends ConsumerState<ActivationScreen> {
  final _codeController = TextEditingController();
  String? _errorMessage;
  bool _isLoading = false;
  String _androidId = 'Cargando...';

  @override
  void initState() {
    super.initState();
    _loadAndroidId();
  }

  Future<void> _loadAndroidId() async {
    final id = await LicenseService.getDeviceFingerprint();
    if (mounted) {
      setState(() {
        _androidId = id;
      });
    }
  }

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _activateLicense() async {
    final code = _codeController.text.trim();

    if (code.isEmpty) {
      setState(() => _errorMessage = 'Ingrese el código de licencia');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final result = LicenseService.validateLicense(code, deviceAndroidId: _androidId);

      if (result.isValid) {
        await _secureStorage.write(key: 'activated_license', value: code);
        await _secureStorage.write(key: 'license_user_type', value: result.userType?.name ?? 'admin');
        await _secureStorage.write(key: 'license_plan', value: result.plan?.name ?? 'free');

        // Guardar fecha de activación y duración para protección anti-manipulación
        final now = DateTime.now();
        await LicenseService.saveActivationDate(now);
        await LicenseService.saveLastLoginDate(now);

        // Guardar duración según el plan
        int durationDays;
        switch (result.plan) {
          case LicensePlan.negocio:
            durationDays = LicenseService.DEFAULT_NEGOCIO_DURATION_DAYS;
            break;
          case LicensePlan.pro:
            durationDays = LicenseService.DEFAULT_PRO_DURATION_DAYS;
            break;
          case LicensePlan.max:
            durationDays = LicenseService.DEFAULT_MAX_DURATION_DAYS;
            break;
          case LicensePlan.maxpro:
            durationDays = LicenseService.DEFAULT_MAXPRO_DURATION_DAYS;
            break;
          default:
            durationDays = LicenseService.DEFAULT_FREE_DURATION_DAYS;
        }
        await LicenseService.saveLicenseDuration(durationDays);

        // Guardar Android ID en el registro del usuario logueado
        final userId = await _secureStorage.read(key: 'user_id');
        if (userId != null && userId.isNotEmpty) {
          try {
            final db = AppDatabase.instance;
            await db.updateUserAndroidId(userId, _androidId);
          } catch (e) {
            debugPrint('Error guardando androidId en usuario: $e');
          }
        }

        if (mounted) {
          context.go('/login');
        }
      } else {
        setState(() => _errorMessage = result.errorMessage ?? 'Código inválido');
      }
    } catch (e) {
      setState(() => _errorMessage = 'Error al validar');
    }

    setState(() => _isLoading = false);
  }

  Future<void> _copyAndroidId() async {
    await Clipboard.setData(ClipboardData(text: _androidId));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('ID de dispositivo copiado'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _contactWhatsApp() async {
    final phone = '5352046805';
    final text = 'Hola! Quiero una licencia de PosJVL. Mi ID de dispositivo es: $_androidId';
    final url = Uri.parse('https://wa.me/$phone?text=${Uri.encodeComponent(text)}');

    try {
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      } else {
        await Clipboard.setData(ClipboardData(text: 'ID: $_androidId - Tel: +5352046805'));
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('ID y teléfono copiados')),
          );
        }
      }
    } catch (e) {
      await Clipboard.setData(ClipboardData(text: 'ID: $_androidId — Tel: +5352046805'));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('ID y teléfono copiados')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.colorCeleste,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            children: [
              const SizedBox(height: 40),

              // Logo
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: Image.asset(
                    'assets/images/logo.png',
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => const Icon(
                      Icons.store_rounded,
                      color: AppTheme.colorCeleste,
                      size: 60,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'PosJVL',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Text(
                'Punto de Venta',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 16,
                ),
              ),

              const SizedBox(height: 32),

              // ====== 1) FORMULARIO DE ACTIVACIÓN (primero) ======
              Container(
                width: double.infinity,
                margin: const EdgeInsets.symmetric(horizontal: 20),
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Activar Licencia',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Ingrese el código que recibió',
                      style: TextStyle(
                        color: Colors.grey.shade600,
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Campo código
                    TextField(
                      controller: _codeController,
                      textCapitalization: TextCapitalization.characters,
                      decoration: InputDecoration(
                        labelText: 'Código de Licencia',
                        hintText: 'ADMIN-PRO-2027-12-31-A1B2C3D4-XXXXXXXX',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        prefixIcon: const Icon(Icons.key),
                        errorText: _errorMessage,
                      ),
                      onSubmitted: (_) => _activateLicense(),
                    ),

                    const SizedBox(height: 20),

                    // Botón ACTIVAR
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _activateLicense,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.colorCeleste,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: _isLoading
                            ? const SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                            : const Text('ACTIVAR', style: TextStyle(fontSize: 16)),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // ====== 2) DEVICE ID (copiable al tocar, sin botón "Copiar") ======
              Container(
                width: double.infinity,
                margin: const EdgeInsets.symmetric(horizontal: 20),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.blue.shade200),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.blue.shade100,
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.blue.shade50,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.phone_android,
                            color: Colors.blue.shade700,
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Tu ID de Dispositivo',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Tocá para copiar',
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
                    InkWell(
                      onTap: _copyAndroidId,
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.grey.shade200),
                        ),
                        child: SelectableText(
                          _androidId,
                          style: TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: Colors.blue.shade700,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // ====== 3) ¿No tenés código? Enviáme tu ID + Javier WhatsApp ======
              Container(
                width: double.infinity,
                margin: const EdgeInsets.symmetric(horizontal: 20),
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '¿No tenés código?',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Enviáme tu ID de dispositivo por WhatsApp',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    const SizedBox(height: 12),
                    InkWell(
                      onTap: _contactWhatsApp,
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.green.shade50,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.green.shade200),
                        ),
                        child: Row(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: Image.asset(
                                'assets/images/whatsapp.png',
                                width: 50,
                                height: 50,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => Container(
                                  width: 50,
                                  height: 50,
                                  color: const Color(0xFF25D366),
                                  child: const Center(
                                    child: Text('💬', style: TextStyle(fontSize: 24)),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Ing. Javier Vila',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.green.shade700,
                                    ),
                                  ),
                                  Text(
                                    '+53 52046805',
                                    style: TextStyle(
                                      color: Colors.green.shade700,
                                    ),
                                  ),
                                  Text(
                                    'Click para enviar ID',
                                    style: TextStyle(fontSize: 12),
                                  ),
                                ],
                              ),
                            ),
                            Icon(Icons.arrow_forward_ios, color: Colors.green, size: 16),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // Footer
              const Text(
                '© 2026 PosJVL',
                style: TextStyle(color: Colors.white70, fontSize: 12),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

}
