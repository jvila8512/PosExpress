import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:etecsa/config/theme/app_colors.dart';
import 'package:etecsa/core/database/app_database.dart';
import 'package:url_launcher/url_launcher.dart';

class LicenseDetailScreen extends ConsumerStatefulWidget {
  final String licenseId;

  const LicenseDetailScreen({
    super.key,
    required this.licenseId,
  });

  @override
  ConsumerState<LicenseDetailScreen> createState() => _LicenseDetailScreenState();
}

class _LicenseDetailScreenState extends ConsumerState<LicenseDetailScreen> {
  // Using dynamic to avoid type issues with generated code
  dynamic _licencia;
  dynamic _cliente;
  bool _isLoading = true;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _loadLicencia();
  }

  Future<void> _loadLicencia() async {
    setState(() => _isLoading = true);
    try {
      final db = AppDatabase.instance;
      final licencias = await db.getAllLicenciasCliente();
      
      // Find the license by id
      LicenciasClienteData? found;
      for (final lic in licencias) {
        if (lic.id == widget.licenseId) {
          found = lic;
          break;
        }
      }
      _licencia = found;
      
      if (_licencia != null) {
        _cliente = await db.getClienteById(_licencia!.clienteId);
      }
    } catch (e) {
      _errorMessage = 'Error al cargar licencia: $e';
    }
    setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Detalle de Licencia'),
        backgroundColor: AppColors.accent,
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/licenses'),
        ),
        actions: [
          if (_licencia != null)
            PopupMenuButton<String>(
              onSelected: (value) {
                if (value == 'renew') {
                  _showRenewDialog();
                } else if (value == 'cancel') {
                  _confirmCancelLicense();
                } else if (value == 'copy') {
                  _copyToClipboard(_licencia.codigo);
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'renew',
                  child: Row(
                    children: [
                      Icon(Icons.refresh),
                      SizedBox(width: 8),
                      Text('Renovar'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'cancel',
                  child: Row(
                    children: [
                      Icon(Icons.cancel, color: Colors.red),
                      SizedBox(width: 8),
                      Text('Cancelar', style: TextStyle(color: Colors.red)),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'copy',
                  child: Row(
                    children: [
                      Icon(Icons.copy),
                      SizedBox(width: 8),
                      Text('Copiar código'),
                    ],
                  ),
                ),
              ],
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _licencia == null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.error_outline,
                        size: 60,
                        color: Colors.grey.shade400,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Licencia no encontrada',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                )
              : _buildLicenseDetails(),
    );
  }

  Widget _buildLicenseDetails() {
    final diasRestantes = _licencia.fechaExpiracion.difference(DateTime.now()).inDays;
    final estaVencida = diasRestantes < 0;
    final estaProximaVencer = diasRestantes >= 0 && diasRestantes <= 7;

    Color statusColor;
    IconData statusIcon;
    
    switch (_licencia.estado) {
      case 'activa':
        if (estaVencida) {
          statusColor = Colors.red;
          statusIcon = Icons.cancel;
        } else if (estaProximaVencer) {
          statusColor = Colors.orange;
          statusIcon = Icons.warning;
        } else {
          statusColor = Colors.green;
          statusIcon = Icons.check_circle;
        }
        break;
      case 'vencida':
        statusColor = Colors.red;
        statusIcon = Icons.cancel;
        break;
      case 'cancelada':
        statusColor = Colors.grey;
        statusIcon = Icons.block;
        break;
      default:
        statusColor = Colors.grey;
        statusIcon = Icons.help;
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Status Card
          Card(
            color: statusColor.withValues(alpha: 0.1),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(statusIcon, color: statusColor, size: 40),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _licencia.estado.toUpperCase(),
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: statusColor,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          estaVencida
                              ? 'Venció hace ${-diasRestantes} días'
                              : '$diasRestantes días restantes',
                          style: TextStyle(
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Code Section
          const Text(
            'Código de Licencia',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 8),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      _licencia.codigo,
                      style: const TextStyle(
                        fontSize: 18,
                        fontFamily: 'monospace',
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.copy),
                    onPressed: () => _copyToClipboard(_licencia.codigo),
                  ),
                  IconButton(
                    icon: const Icon(Icons.sms),
                    tooltip: 'Enviar por SMS',
                    onPressed: () => _sendBySms(),
                  ),
                  IconButton(
                    icon: const Icon(Icons.send),
                    onPressed: () => _sendToWhatsApp(),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Plan and Dates
          Row(
            children: [
              Expanded(
                child: _buildInfoCard(
                  'Plan',
                  _licencia.plan,
                  Icons.category,
                  AppColors.accent,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildInfoCard(
                  'Precio Pagado',
                  '\$${_licencia.precioPagado.toStringAsFixed(2)}',
                  Icons.attach_money,
                  Colors.green,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildInfoCard(
                  'Fecha Inicio',
                  _formatDate(_licencia.fechaCreacion),
                  Icons.play_arrow,
                  Colors.blue,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildInfoCard(
                  'Fecha Expiración',
                  _formatDate(_licencia.fechaExpiracion),
                  Icons.stop,
                  estaVencida ? Colors.red : Colors.orange,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Client Section
          if (_cliente != null) ...[
            const Text(
              'Cliente',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 8),
            Card(
              child: ListTile(
                leading: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppColors.accent.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Center(
                    child: Text(
                      _cliente.nombre[0].toUpperCase(),
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: AppColors.accent,
                      ),
                    ),
                  ),
                ),
                title: Text(_cliente.nombre),
                subtitle: Text(_cliente.telefono),
                trailing: IconButton(
                  icon: const Icon(Icons.phone),
                  onPressed: () => _callClient(_cliente.telefono),
                ),
              ),
            ),
            const SizedBox(height: 24),
          ],

          // Device Info
          if (_licencia.dispositivoId != null && _licencia.dispositivoId!.isNotEmpty) ...[
            const Text(
              'Dispositivo',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 8),
            Card(
              child: ListTile(
                leading: const Icon(Icons.devices),
                title: const Text('ID de Dispositivo'),
                subtitle: Text(
                  _licencia.dispositivoId!,
                  style: const TextStyle(fontSize: 12),
                ),
                trailing: IconButton(
                  icon: const Icon(Icons.copy),
                  onPressed: () => _copyToClipboard(_licencia.dispositivoId!),
                ),
              ),
            ),
            const SizedBox(height: 24),
          ],

          // Notes
          if (_licencia.notas != null && _licencia.notas!.isNotEmpty) ...[
            const Text(
              'Notas',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 8),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(_licencia.notas!),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ],
      ),
    );
  }

  Widget _buildInfoCard(String label, String value, IconData icon, Color color) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 16, color: color),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _copyToClipboard(String text) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Copiado al portapapeles')),
    );
  }

  void _sendToWhatsApp() {
    if (_cliente == null) return;
    
    final phone = _cliente.telefono.replaceAll(RegExp(r'[^\d]'), '');
    final text = 'Tu código de licencia ExpressPos es: ${_licencia.codigo}\n\n'
        'Plan: ${_licencia.plan}\n'
        'Expira: ${_formatDate(_licencia.fechaExpiracion)}\n\n'
        'Gracias por usar ExpressPos';
    
    final url = Uri.parse('https://wa.me/$phone?text=${Uri.encodeComponent(text)}');
    
    launchUrl(url, mode: LaunchMode.externalApplication);
  }

  void _sendBySms() {
    if (_cliente == null) return;
    
    final phone = _cliente.telefono.replaceAll(RegExp(r'[^\d]'), '');
    final text = 'Tu código de licencia ExpressPos es: ${_licencia.codigo}\n'
        'Plan: ${_licencia.plan} | Expira: ${_formatDate(_licencia.fechaExpiracion)}\n'
        'Instalá la app e ingresá el código para activar.';
    
    final url = Uri.parse('sms:$phone?body=${Uri.encodeComponent(text)}');
    
    launchUrl(url, mode: LaunchMode.externalApplication);
  }

  void _callClient(String phone) {
    final url = Uri.parse('tel:$phone');
    launchUrl(url);
  }

  void _showRenewDialog() {
    int selectedDias = 30;
    
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Renovar Licencia'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Selecciona la duración de la renovación:'),
              const SizedBox(height: 16),
              DropdownButtonFormField<int>(
                value: selectedDias,
                decoration: const InputDecoration(
                  labelText: 'Días a agregar',
                ),
                items: const [
                  DropdownMenuItem(value: 30, child: Text('30 días')),
                  DropdownMenuItem(value: 90, child: Text('90 días')),
                  DropdownMenuItem(value: 180, child: Text('180 días')),
                  DropdownMenuItem(value: 365, child: Text('365 días')),
                ],
                onChanged: (value) {
                  setDialogState(() => selectedDias = value!);
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () async {
                final db = AppDatabase.instance;
                await db.renewLicenciaCliente(_licencia.id, selectedDias);
                if (mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Licencia renovada')),
                  );
                  _loadLicencia();
                }
              },
              child: const Text('Renovar'),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmCancelLicense() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancelar Licencia'),
        content: const Text('¿Estás seguro de cancelar esta licencia?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('No'),
          ),
          FilledButton(
            onPressed: () async {
              final db = AppDatabase.instance;
              await db.cancelLicenciaCliente(_licencia.id);
              if (mounted) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Licencia cancelada')),
                );
                _loadLicencia();
              }
            },
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Sí, cancelar'),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
}