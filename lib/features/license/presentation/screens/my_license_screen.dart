import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:etecsa/config/theme/app_theme.dart';
import 'package:etecsa/core/database/app_database.dart';
import 'package:etecsa/core/security/license_service.dart';

class MyLicenseScreen extends StatefulWidget {
  const MyLicenseScreen({super.key});

  @override
  State<MyLicenseScreen> createState() => _MyLicenseScreenState();
}

class _MyLicenseScreenState extends State<MyLicenseScreen> {
  bool _isLoading = true;
  LicenseValidationResult? _licenseResult;
  final String _whatsAppJavier = LicenseService.JAVIER_WHATSAPP;

  @override
  void initState() {
    super.initState();
    _loadLicenseData();
  }

  Future<void> _loadLicenseData() async {
    setState(() => _isLoading = true);

    try {
      final db = AppDatabase.instance;
      // Usar el método de validación con protección anti-manipulación
      final result = await LicenseService.validateLicenseWithTamperProtection(db);
      setState(() {
        _licenseResult = result;
      });
    } catch (e) {
      print('Error loading license: $e');
    }

    setState(() => _isLoading = false);
  }

  Color _getStatusColor() {
    if (_licenseResult == null || !_licenseResult!.hasLicense) {
      return Colors.grey;
    }

    if (_licenseResult!.isExpired) return Colors.red;

    final remaining = _licenseResult!.remainingDays;
    if (remaining <= 7) return Colors.orange;
    return Colors.green;
  }

  String _getStatusText() {
    if (_licenseResult == null || !_licenseResult!.hasLicense) {
      return 'SIN LICENCIA';
    }

    if (_licenseResult!.isExpired) return 'VENCIDA';
    if (_licenseResult!.remainingDays == 0) return 'VENCE HOY';
    return 'ACTIVA';
  }

  int _getDiasRestantes() {
    if (_licenseResult == null || _licenseResult!.expiresAt == null) return 0;
    return _licenseResult!.remainingDays;
  }

  Future<void> _contactarJavier() async {
    final licenseCode = await LicenseService.getActivatedLicenseCode();
    final mensaje = Uri.encodeComponent(
      'Hola, tengo un problema con mi licencia de PosJVL.\n\nCódigo: ${licenseCode ?? "N/A"}',
    );
    final url = Uri.parse(
      'https://wa.me/${_whatsAppJavier.replaceAll(RegExp(r'[^\d]'), '')}?text=$mensaje',
    );

    try {
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      } else {
        // Copiar al portapapeles
        await Clipboard.setData(ClipboardData(text: _whatsAppJavier));
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Número copiado al portapapeles')),
          );
        }
      }
    } catch (e) {
      await Clipboard.setData(ClipboardData(text: _whatsAppJavier));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Número copiado al portapapeles')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mi Licencia'),
        backgroundColor: AppTheme.colorCeleste,
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/'),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Card de licencia actual
                  _buildLicenseCard(),

                  const SizedBox(height: 24),

                  // Card de contacto
                  _buildContactCard(),
                ],
              ),
            ),
    );
  }

  Widget _buildLicenseCard() {
    final diasRestantes = _getDiasRestantes();
    final statusColor = _getStatusColor();
    final statusText = _getStatusText();

    // Determinar colores según estado
    final isExpired = _licenseResult?.isExpired ?? false;
    final hasLicense = _licenseResult?.hasLicense ?? false;
    final gradientColors = hasLicense
        ? (isExpired
            ? [Colors.red.shade700, Colors.red.shade500]
            : [AppTheme.colorCeleste, AppTheme.colorCeleste.withValues(alpha: 0.8)])
        : [Colors.grey.shade600, Colors.grey.shade400];

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: gradientColors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: gradientColors[0].withValues(alpha: 0.3),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'LICENCIA ACTUAL',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  statusText,
                  style: TextStyle(
                    color: statusColor,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),

          // Plan
          Text(
            hasLicense ? (_licenseResult?.planName ?? '-') : 'SIN LICENCIA',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 32,
              fontWeight: FontWeight.bold,
            ),
          ),

          const SizedBox(height: 8),

          // El código de licencia ya no se muestra por seguridad

          const SizedBox(height: 20),

          // Info row
          Row(
            children: [
              Expanded(
                child: _buildInfoItem(
                  icon: Icons.calendar_today,
                  label: 'Expira',
                  value: _licenseResult?.expiresAt != null
                      ? '${_licenseResult!.expiresAt!.day}/${_licenseResult!.expiresAt!.month}/${_licenseResult!.expiresAt!.year}'
                      : 'N/A',
                ),
              ),
              Container(
                width: 1,
                height: 40,
                color: Colors.white30,
              ),
              Expanded(
                child: _buildInfoItem(
                  icon: Icons.timer,
                  label: 'Días restantes',
                  value: diasRestantes.toString(),
                  valueColor: diasRestantes < 0
                      ? Colors.red
                      : diasRestantes <= 7
                          ? Colors.orange
                          : Colors.white,
                ),
              ),
            ],
          ),

          // Mensaje de activación si no hay licencia
          if (!hasLicense) ...[
            const SizedBox(height: 16),
            const Divider(color: Colors.white30),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => context.go('/activation'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: gradientColors[0],
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: const Text(
                  'ACTIVAR LICENCIA',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],

          // Botón actualizar si ya tiene licencia
          if (hasLicense) ...[
            const SizedBox(height: 16),
            const Divider(color: Colors.white30),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => context.go('/activation'),
                icon: const Icon(Icons.refresh, size: 20),
                label: const Text(
                  'ACTUALIZAR LICENCIA',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: const BorderSide(color: Colors.white70, width: 1.5),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildInfoItem({
    required IconData icon,
    required String label,
    required String value,
    Color? valueColor,
  }) {
    return Column(
      children: [
        Icon(icon, color: Colors.white70, size: 20),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 11,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            color: valueColor ?? Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildContactCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(alpha: 0.2),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        children: [
          const Text(
            'Contactar a soporte Técnico',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
            textAlign: TextAlign.center,
          ),

          const SizedBox(height: 20),

          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _contactarJavier,
              icon: Image.asset(
                'assets/images/whatsapp.png',
                width: 24,
                height: 24,
                color: Colors.white,
              ),
              label: const Text('Contactar por WhatsApp'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}