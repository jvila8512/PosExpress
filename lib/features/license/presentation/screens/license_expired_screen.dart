import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:etecsa/config/theme/app_theme.dart';
import 'package:etecsa/core/security/license_service.dart';

class LicenseExpiredScreen extends StatelessWidget {
  final DateTime? expiredDate;
  final int? daysElapsed;
  final int? durationDays;

  const LicenseExpiredScreen({
    super.key,
    this.expiredDate,
    this.daysElapsed,
    this.durationDays,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.red.shade50,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(height: 40),

              // Icono de licencia expirada
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  color: Colors.red.shade100,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.error_outline,
                  size: 60,
                  color: Colors.red.shade700,
                ),
              ),

              const SizedBox(height: 24),

              // Título
              Text(
                'LICENCIA EXPIRADA',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.red.shade700,
                ),
              ),

              const SizedBox(height: 12),

              // Subtítulo
              Text(
                'Tu licencia de ExpressPos ha vencido',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.red.shade600,
                ),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 32),

              // Card con detalles
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.red.shade100,
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    // Icono de calendario
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.event_busy,
                        size: 40,
                        color: Colors.red.shade600,
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Fecha de expiración
                    Text(
                      'Fecha de expiración',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      expiredDate != null
                          ? '${expiredDate!.day}/${expiredDate!.month}/${expiredDate!.year}'
                          : 'Desconocida',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.red.shade700,
                      ),
                    ),

                    const SizedBox(height: 16),
                    Divider(color: Colors.red.shade100),
                    const SizedBox(height: 16),

                    // Detalles
                    if (daysElapsed != null && durationDays != null) ...[
                      _buildDetailRow(
                        'Días transcurridos',
                        '$daysElapsed',
                        Icons.schedule,
                      ),
                      const SizedBox(height: 12),
                      _buildDetailRow(
                        'Duración original',
                        '$durationDays días',
                        Icons.calendar_today,
                      ),
                    ],
                  ],
                ),
              ),

              const SizedBox(height: 32),

              // Mensaje
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.orange.shade200),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      color: Colors.orange.shade700,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Contacta a Javier para renovar tu licencia y continuar usando ExpressPos',
                        style: TextStyle(
                          color: Colors.orange.shade700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

        const SizedBox(height: 24),

        // Android ID del dispositivo
        FutureBuilder<String>(
          future: LicenseService.getDeviceFingerprint(),
          builder: (context, snapshot) {
            if (!snapshot.hasData || snapshot.data!.isEmpty) {
              return const SizedBox.shrink();
            }
            final androidId = snapshot.data!;
            return Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.phone_android, size: 20, color: Colors.blue.shade700),
                      const SizedBox(width: 8),
                      Text(
                        'ID de Dispositivo',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.blue.shade700,
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        icon: Icon(Icons.copy, size: 18, color: Colors.blue.shade700),
                        onPressed: () async {
                          await Clipboard.setData(ClipboardData(text: androidId));
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('ID copiado al portapapeles'),
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
                  const SizedBox(height: 4),
                  SelectableText(
                    androidId,
                    style: TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 13,
                      color: Colors.blue.shade800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Envía este ID junto con tu solicitud de renovación',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.blue.shade600,
                    ),
                  ),
                ],
              ),
            );
          },
        ),

        const SizedBox(height: 24),

        // Botón de WhatsApp
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton.icon(
                  onPressed: _contactarJavier,
                  icon: const Icon(Icons.chat, color: Colors.white),
                  label: const Text(
                    'Contactar por WhatsApp',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Botón de SMS — enviar ID por SMS
              SizedBox(
                width: double.infinity,
                height: 56,
                child: OutlinedButton.icon(
                  onPressed: _enviarIdPorSms,
                  icon: const Icon(Icons.sms, color: Colors.blue),
                  label: const Text(
                    'Enviar mi ID por SMS',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.blue,
                    side: const BorderSide(color: Colors.blue),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Botón alternativo
              TextButton.icon(
                onPressed: _copyPhoneNumber,
                icon: const Icon(Icons.copy),
                label: const Text('Copiar número de teléfono'),
                style: TextButton.styleFrom(
                  foregroundColor: Colors.grey.shade600,
                ),
              ),

              const SizedBox(height: 32),

              // Información de contacto
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppTheme.colorCeleste.withValues(alpha: 0.1),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.person,
                            color: AppTheme.colorCeleste,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Ing. Javier Vila',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                LicenseService.JAVIER_WHATSAPP,
                                style: TextStyle(
                                  color: Colors.grey.shade600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Horario de atención: 8:00 AM - 10:00 PM',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade500,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Cerrar sesión
              TextButton(
                onPressed: () async {
                  // Limpiar sesión y redirigir a login
                  // ignore: use_build_context_synchronously
                  context.go('/login');
                },
                child: Text(
                  'Cerrar sesión',
                  style: TextStyle(color: Colors.grey.shade600),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 20, color: Colors.grey.shade600),
        const SizedBox(width: 8),
        Text(
          label,
          style: TextStyle(color: Colors.grey.shade600),
        ),
        const Spacer(),
        Text(
          value,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  Future<void> _contactarJavier() async {
    final androidId = await LicenseService.getDeviceFingerprint();
    final mensaje = Uri.encodeComponent(
      androidId.isNotEmpty
        ? 'Hola! Mi licencia de ExpressPos ha expirado. Mi ID de dispositivo es: $androidId. Necesito renovarla por favor.'
        : 'Hola! Mi licencia de ExpressPos ha expirado. Necesito renovarla por favor.',
    );
    final url = Uri.parse(
      'https://wa.me/${LicenseService.JAVIER_WHATSAPP.replaceAll(RegExp(r'[^\d]'), '')}?text=$mensaje',
    );

    try {
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      } else {
        await _copyPhoneNumber();
      }
    } catch (e) {
      await _copyPhoneNumber();
    }
  }

  Future<void> _copyPhoneNumber() async {
    await Clipboard.setData(ClipboardData(text: LicenseService.JAVIER_WHATSAPP));
  }

  Future<void> _enviarIdPorSms() async {
    final androidId = await LicenseService.getDeviceFingerprint();
    final phone = LicenseService.JAVIER_WHATSAPP.replaceAll(RegExp(r'[^\d]'), '');
    final mensaje = androidId.isNotEmpty
        ? 'Hola! Mi ID de dispositivo ExpressPos es: $androidId. Necesito renovar mi licencia.'
        : 'Hola! Necesito renovar mi licencia de ExpressPos.';
    final url = Uri.parse('sms:$phone?body=${Uri.encodeComponent(mensaje)}');

    try {
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      } else {
        await Clipboard.setData(ClipboardData(text: mensaje));
      }
    } catch (e) {
      await Clipboard.setData(ClipboardData(text: mensaje));
    }
  }
}