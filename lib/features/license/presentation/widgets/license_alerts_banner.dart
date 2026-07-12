import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:etecsa/core/database/app_database.dart';

class LicenseAlertsBanner extends StatelessWidget {
  const LicenseAlertsBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<dynamic>>(
      future: _getAlerts(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const SizedBox.shrink();
        }

        final alerts = snapshot.data!;
        final hasExpired = alerts.any((a) => a['type'] == 'expired');
        final hasExpiring = alerts.any((a) => a['type'] == 'expiring');

        Color bannerColor;
        IconData bannerIcon;
        String bannerText;

        if (hasExpired) {
          bannerColor = Colors.red;
          bannerIcon = Icons.error;
          final count = alerts.where((a) => a['type'] == 'expired').length;
          bannerText = '$count licencia${count > 1 ? 's' : ''} vencida${count > 1 ? 's' : ''}';
        } else if (hasExpiring) {
          bannerColor = Colors.orange;
          bannerIcon = Icons.warning;
          final count = alerts.where((a) => a['type'] == 'expiring').length;
          bannerText = '$count licencia${count > 1 ? 's' : ''} próximo${count > 1 ? 's' : ''} a vencer';
        } else {
          return const SizedBox.shrink();
        }

        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Material(
            color: bannerColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
            child: InkWell(
              onTap: () => context.go('/licenses'),
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: bannerColor.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(bannerIcon, color: bannerColor, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Alerta de Licencia',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: bannerColor,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            bannerText,
                            style: TextStyle(
                              color: Colors.grey.shade700,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      Icons.chevron_right,
                      color: bannerColor,
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Future<List<dynamic>> _getAlerts() async {
    try {
      final db = AppDatabase.instance;
      final List<dynamic> alerts = [];

      // Get expired licenses
      try {
        final expired = await db.getLicenciasVencidas();
        for (final lic in expired) {
          alerts.add({
            'type': 'expired',
            'id': lic.id,
            'codigo': lic.codigo,
            'clienteId': lic.clienteId,
          });
        }
      } catch (e) {
        // Table might not exist yet
      }

      // Get expiring licenses (within 7 days)
      try {
        final expiring = await db.getLicenciasProximasVencer(7);
        for (final lic in expiring) {
          alerts.add({
            'type': 'expiring',
            'id': lic.id,
            'codigo': lic.codigo,
            'clienteId': lic.clienteId,
            'diasRestantes': lic.fechaExpiracion.difference(DateTime.now()).inDays,
          });
        }
      } catch (e) {
        // Table might not exist yet
      }

      return alerts;
    } catch (e) {
      return [];
    }
  }
}