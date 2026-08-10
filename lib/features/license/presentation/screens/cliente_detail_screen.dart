import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:etecsa/config/theme/app_colors.dart';
import 'package:etecsa/core/database/app_database.dart';
import 'package:etecsa/core/security/license_service.dart';

class ClienteDetailScreen extends StatefulWidget {
  final Cliente cliente;
  final bool embedded;
  final VoidCallback? onBack;
  final void Function(String)? onResult;

  const ClienteDetailScreen({
    super.key,
    required this.cliente,
    this.embedded = false,
    this.onBack,
    this.onResult,
  });

  @override
  State<ClienteDetailScreen> createState() => _ClienteDetailScreenState();
}

class _ClienteDetailScreenState extends State<ClienteDetailScreen> {
  List<LicenciasClienteData> _licencias = [];
  bool _isLoading = true;
  late Cliente _cliente;

  @override
  void initState() {
    super.initState();
    _cliente = widget.cliente;
    _loadLicencias();
  }

  Future<void> _loadLicencias() async {
    setState(() => _isLoading = true);
    try {
      final db = AppDatabase.instance;
      final licencias = await db.getLicenciasByCliente(_cliente.id);
      if (mounted) {
        setState(() {
          _licencias = licencias;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Color _getEstadoColor(String estado) {
    switch (estado.toLowerCase()) {
      case 'activa':
        return Colors.green;
      case 'vencida':
        return Colors.red;
      case 'cancelada':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  /// Helper: en modo embedded usa onResult/onBack, en modo normal usa Navigator.pop
  void _popResult([dynamic result]) {
    if (widget.embedded) {
      if (result is String && widget.onResult != null) {
        widget.onResult!(result);
      }
      widget.onBack?.call();
    } else {
      Navigator.pop(context, result);
    }
  }

  String _getPlanDisplay(String plan) {
    switch (plan.toUpperCase()) {
      case 'PRO':
        return 'PRO';
      case 'NEGOCIO':
        return 'NEGOCIO';
      case 'FREE':
        return 'FREE';
      default:
        return plan.toUpperCase();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isInactive = !_cliente.active;
    final activeCount = _licencias.where((l) => l.estado == 'activa').length;
    final expiredCount = _licencias.where((l) => l.estado == 'vencida').length;
    final totalCount = _licencias.length;

    final body = Container(
      color: Colors.grey.shade50,
      child: RefreshIndicator(
        onRefresh: _loadLicencias,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Client info card ──
              Card(
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: isInactive
                      ? BorderSide(color: Colors.orange.shade200, width: 1)
                      : BorderSide.none,
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Avatar + name row
                      Row(
                        children: [
                          Container(
                            width: 60,
                            height: 60,
                            decoration: BoxDecoration(
                              color: isInactive
                                  ? Colors.orange.shade100
                                  : AppColors.accent.withValues(
                                      alpha: 0.1,
                                    ),
                              borderRadius: BorderRadius.circular(30),
                            ),
                            child: Center(
                              child: Text(
                                _cliente.nombre.isNotEmpty
                                    ? _cliente.nombre[0].toUpperCase()
                                    : '?',
                                style: TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: isInactive
                                      ? Colors.orange.shade700
                                      : AppColors.accent,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        _cliente.nombre,
                                        style: const TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                    if (isInactive)
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 2,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.orange.shade50,
                                          borderRadius: BorderRadius.circular(
                                            4,
                                          ),
                                        ),
                                        child: Text(
                                          'INACTIVO',
                                          style: TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.orange.shade700,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                                if (_cliente.negocio != null &&
                                    _cliente.negocio!.isNotEmpty)
                                  Text(
                                    _cliente.negocio!,
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.grey.shade600,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 16),

                      // Detail rows
                      _buildDetailRow(
                        Icons.phone,
                        'Teléfono',
                        _cliente.telefono,
                      ),
                      if (_cliente.email != null && _cliente.email!.isNotEmpty)
                        _buildDetailRow(Icons.email, 'Email', _cliente.email!),
                      if (_cliente.notas != null && _cliente.notas!.isNotEmpty)
                        _buildDetailRow(Icons.note, 'Notas', _cliente.notas!),
                      _buildDetailRow(
                        Icons.calendar_today,
                        'Creado',
                        _formatDate(_cliente.createdAt),
                      ),

                      // License count badges
                      if (totalCount > 0) ...[
                        const SizedBox(height: 12),
                        const Divider(),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            _buildLicenseBadge(
                              'Activas: $activeCount',
                              Colors.green,
                            ),
                            _buildLicenseBadge(
                              'Vencidas: $expiredCount',
                              Colors.red,
                            ),
                            if (totalCount - activeCount - expiredCount > 0)
                              _buildLicenseBadge(
                                'Canceladas: ${totalCount - activeCount - expiredCount}',
                                Colors.orange,
                              ),
                          ],
                        ),
                      ],

                      const SizedBox(height: 16),

                      // Action buttons
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () {
                                _popResult('edit');
                              },
                              icon: const Icon(Icons.edit, size: 18),
                              label: const Text('Editar'),
                            ),
                          ),
                          if (isInactive) ...[
                            const SizedBox(width: 12),
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: () => _reactivarCliente(),
                                icon: const Icon(Icons.check_circle, size: 18),
                                label: const Text('Reactivar'),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: Colors.green,
                                  side: const BorderSide(color: Colors.green),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),

                      if (!isInactive) ...[
                        const SizedBox(height: 8),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: () => _confirmInactivarCliente(),
                            icon: const Icon(Icons.delete, size: 18),
                            label: const Text('Inactivar Cliente'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.red,
                              side: const BorderSide(color: Colors.red),
                            ),
                          ),
                        ),
                      ],

                      if (!isInactive && _licencias.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: () => _showRenovarTodoDialog(),
                                icon: const Icon(Icons.refresh, size: 18),
                                label: const Text(
                                  'Renovar todo',
                                  style: TextStyle(fontSize: 12),
                                ),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: Colors.green,
                                  side: const BorderSide(color: Colors.green),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: () => _showCambiarPlanDialog(),
                                icon: const Icon(Icons.swap_horiz, size: 18),
                                label: const Text(
                                  'Cambiar plan',
                                  style: TextStyle(fontSize: 12),
                                ),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: AppColors.accent,
                                  side: const BorderSide(
                                    color: AppColors.accent,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                      if (!isInactive) ...[
                        const SizedBox(height: 8),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: () => _showCrearLicenciaDialog(),
                            icon: const Icon(Icons.add, size: 18),
                            label: const Text(
                              'Crear licencia para este cliente',
                            ),
                            style: ElevatedButton.styleFrom(
                              foregroundColor: Colors.white,
                              backgroundColor: AppColors.accent,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),
              Divider(height: 1, color: Colors.grey.shade200),
              const SizedBox(height: 16),

              // ── Licenses section ──
              Row(
                children: [
                  Icon(Icons.vpn_key, size: 18, color: AppColors.accent),
                  const SizedBox(width: 8),
                  Text(
                    'LICENCIAS',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey.shade700,
                      letterSpacing: 1,
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.accent.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${_licencias.length}',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: AppColors.accent,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              if (_isLoading)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(32),
                    child: CircularProgressIndicator(),
                  ),
                )
              else if (_licencias.isEmpty)
                _buildEmptyLicencias()
              else
                ..._licencias.map((lic) => _buildLicenseCard(lic)),
            ],
          ),
        ),
      ),
    );

    if (widget.embedded) {
      return Scaffold(
        backgroundColor: Colors.grey.shade50,
        appBar: widget.onBack != null
            ? AppBar(
                title: Text(_cliente.nombre),
                backgroundColor: AppColors.accent,
                foregroundColor: Colors.white,
                leading: IconButton(
                  icon: const Icon(Icons.arrow_back),
                  onPressed: widget.onBack,
                ),
              )
            : null,
        body: body,
      );
    }

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: Text(_cliente.nombre),
        backgroundColor: AppColors.accent,
        foregroundColor: Colors.white,
      ),
      body: body,
    );
  }

  // ── Widget builders ──

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: Colors.grey),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
                const SizedBox(height: 2),
                Text(value, style: const TextStyle(fontSize: 14)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLicenseBadge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.bold,
          fontSize: 12,
        ),
      ),
    );
  }

  Widget _buildEmptyLicencias() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 48),
      child: Column(
        children: [
          Icon(Icons.key_off, size: 64, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          Text(
            'No hay licencias asignadas',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: Colors.grey.shade500,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Las licencias de este cliente aparecerán aquí',
            style: TextStyle(fontSize: 13, color: Colors.grey.shade400),
          ),
        ],
      ),
    );
  }

  Widget _buildLicenseCard(LicenciasClienteData lic) {
    final estadoColor = _getEstadoColor(lic.estado);
    final diasRestantes = lic.fechaExpiracion.difference(DateTime.now()).inDays;
    final estaVencida = diasRestantes < 0;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: estadoColor.withValues(alpha: 0.2), width: 1),
      ),
      child: InkWell(
        onTap: () => context.push('/licenses/detail/${lic.id}'),
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top row: icon + code + status badge
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: estadoColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      lic.estado == 'activa'
                          ? Icons.check_circle
                          : lic.estado == 'cancelada'
                          ? Icons.cancel
                          : Icons.error,
                      color: estadoColor,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          lic.codigo,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            _buildPlanBadge(lic.plan),
                            const SizedBox(width: 6),
                            Text(
                              estaVencida
                                  ? 'Vencida el ${_formatDate(lic.fechaExpiracion)}'
                                  : 'Vence: ${_formatDate(lic.fechaExpiracion)}',
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey.shade500,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: estadoColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: estadoColor.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Text(
                      lic.estado.toUpperCase(),
                      style: TextStyle(
                        color: estadoColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 11,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPlanBadge(String plan) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.accent.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        _getPlanDisplay(plan),
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          color: AppColors.accent,
        ),
      ),
    );
  }

  // ── Actions ──

  Future<void> _reactivarCliente() async {
    final db = AppDatabase.instance;
    await db.reactivarCliente(_cliente.id);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${_cliente.nombre} reactivado'),
          backgroundColor: Colors.green,
        ),
      );
      _popResult('reactivated');
    }
  }

  Future<void> _confirmInactivarCliente() async {
    final db = AppDatabase.instance;
    final licenciasActivas = _licencias
        .where((l) => l.estado == 'activa')
        .toList();

    if (licenciasActivas.isNotEmpty) {
      if (!mounted) return;
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('No se puede inactivar'),
          content: Text(
            '${_cliente.nombre} tiene ${licenciasActivas.length} licencia${licenciasActivas.length > 1 ? "s" : ""} activa${licenciasActivas.length > 1 ? "s" : ""}.\n\n'
            'Cancelá o dejá vencer las licencias antes de inactivar el cliente.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Entendido'),
            ),
          ],
        ),
      );
      return;
    }

    if (!mounted) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Inactivar Cliente'),
        content: Text(
          '¿Inactivar a ${_cliente.nombre}? Se ocultará de la lista de activos pero su historial se conservará.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.orange),
            child: const Text('Inactivar'),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      await db.deleteCliente(_cliente.id);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Cliente inactivado')));
        _popResult('inactivated');
      }
    }
  }

  // ── Gestión de licencias ──

  Future<void> _showRenovarTodoDialog() async {
    final vencidas = _licencias.where((l) => l.estado == 'vencida').toList();
    final activas = _licencias.where((l) => l.estado == 'activa').toList();
    final aRenovar = vencidas.isNotEmpty ? vencidas : activas;

    if (aRenovar.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No hay licencias para renovar')),
      );
      return;
    }

    final diasController = TextEditingController(text: '365');
    final result = await showDialog<int>(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.refresh, color: Colors.green),
            const SizedBox(width: 8),
            const Text('Renovar todo'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Cliente: ${_cliente.nombre}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Se renovarán ${aRenovar.length} licencia${aRenovar.length > 1 ? 's' : ''} con código NUEVO',
            ),
            if (vencidas.isEmpty && activas.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  '(${activas.length} activa${activas.length > 1 ? 's' : ''} - se extenderán)',
                  style: TextStyle(fontSize: 12, color: Colors.orange.shade700),
                ),
              ),
            const SizedBox(height: 16),
            TextField(
              controller: diasController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Días de duración',
                hintText: '365',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () {
              final dias = int.tryParse(diasController.text);
              if (dias == null || dias <= 0) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Ingrese un número válido de días'),
                  ),
                );
                return;
              }
              Navigator.pop(context, dias);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
            ),
            child: const Text('Renovar'),
          ),
        ],
      ),
    );

    if (result != null && mounted) {
      try {
        final db = AppDatabase.instance;
        final renovadas = await db.batchRenewWithNewCodes(
          _cliente.id,
          result,
          'NEGOCIO',
        );

        await _loadLicencias();

        if (!mounted) return;
        _showEnvioDialog(renovadas);
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error al renovar: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  void _showEnvioDialog(List<Map<String, dynamic>> renovadas) {
    final telefono = _cliente.telefono;
    final codigosTexto = renovadas
        .asMap()
        .entries
        .map(
          (e) =>
              '${e.key + 1}. ${e.value['codigo_nuevo']} (${e.value['plan']})',
        )
        .join('\n');
    final mensaje =
        'Hola ${_cliente.nombre}! Tus nuevas licencias ExpressPos:\n\n$codigosTexto';

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.green),
            const SizedBox(width: 8),
            Text(
              '${renovadas.length} renovada${renovadas.length > 1 ? 's' : ''}',
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Se generaron códigos nuevos.',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              '${renovadas.length} licencia${renovadas.length > 1 ? 's' : ''} actualizada${renovadas.length > 1 ? 's' : ''} con código nuevo.',
            ),
            const SizedBox(height: 16),
            const Text(
              '¿Enviar códigos al cliente?',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('No ahora'),
          ),
          if (telefono.isNotEmpty) ...[
            ElevatedButton.icon(
              onPressed: () {
                Navigator.pop(context);
                _enviarPorWhatsApp(telefono, mensaje);
              },
              icon: const Icon(Icons.chat, size: 18),
              label: const Text('WhatsApp'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
              ),
            ),
            const SizedBox(width: 8),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.pop(context);
                _enviarPorSms(telefono, mensaje);
              },
              icon: const Icon(Icons.sms, size: 18),
              label: const Text('SMS'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _enviarPorWhatsApp(String telefono, String mensaje) async {
    final cleanPhone = telefono.replaceAll(RegExp(r'[^0-9]'), '');
    try {
      // Si ya tiene +, usar dígitos tal cual. Si no, agregar código de Cuba (53).
      final hasCountryCode = telefono.trim().startsWith('+');
      final fullPhone = hasCountryCode ? cleanPhone : '53$cleanPhone';
      final url = Uri.parse(
        'whatsapp://send?phone=$fullPhone&text=${Uri.encodeComponent(mensaje)}',
      );
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      } else {
        _enviarPorSms(telefono, mensaje);
      }
    } catch (_) {
      _enviarPorSms(telefono, mensaje);
    }
  }

  Future<void> _enviarPorSms(String telefono, String mensaje) async {
    try {
      final url = Uri.parse(
        'sms:$telefono?body=${Uri.encodeComponent(mensaje)}',
      );
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      }
    } catch (_) {}
  }

  Future<void> _showCambiarPlanDialog() async {
    final db = AppDatabase.instance;
    final planes = await db.getAllLicensePlanes();

    String selectedPlan = _licencias.isNotEmpty
        ? _licencias.first.plan.toUpperCase()
        : 'NEGOCIO';
    if (!planes.any((p) => p.nombre == selectedPlan)) {
      selectedPlan = planes.isNotEmpty ? planes.first.nombre : 'NEGOCIO';
    }

    final result = await showDialog<String>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Row(
            children: [
              const Icon(Icons.swap_horiz, color: AppColors.accent),
              const SizedBox(width: 8),
              const Text('Cambiar plan'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Cliente: ${_cliente.nombre}',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Text(
                'Se cambiarán TODAS las ${_licencias.length} licencias de este cliente.',
              ),
              const SizedBox(height: 16),
              const Text(
                'Nuevo plan:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                initialValue: selectedPlan,
                items: planes
                    .map(
                      (p) => DropdownMenuItem(
                        value: p.nombre,
                        child: Text(
                          '${p.nombre} - \${p.precio.toStringAsFixed(0)}',
                        ),
                      ),
                    )
                    .toList(),
                onChanged: (val) {
                  if (val != null) {
                    setDialogState(() => selectedPlan = val);
                  }
                },
                decoration: const InputDecoration(border: OutlineInputBorder()),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, selectedPlan),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accent,
                foregroundColor: Colors.white,
              ),
              child: const Text('Cambiar todas'),
            ),
          ],
        ),
      ),
    );

    if (result != null && mounted) {
      try {
        final count = await db.batchChangePlanByCliente(_cliente.id, result);
        await _loadLicencias();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('$count licencias cambiadas a $result'),
              backgroundColor: AppColors.accent,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
          );
        }
      }
    }
  }

  Future<void> _showCrearLicenciaDialog() async {
    final db = AppDatabase.instance;
    final planes = await db.getAllLicensePlanes();

    String selectedPlan = 'NEGOCIO';
    String selectedTipo = 'VENDEDOR';
    if (planes.isNotEmpty && !planes.any((p) => p.nombre == selectedPlan)) {
      selectedPlan = planes.first.nombre;
    }

    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Crear licencia'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Cliente: ${_cliente.nombre}',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: selectedTipo,
                decoration: const InputDecoration(
                  labelText: 'Tipo',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(value: 'ADMIN', child: Text('Admin')),
                  DropdownMenuItem(value: 'VENDEDOR', child: Text('Vendedor')),
                ],
                onChanged: (val) {
                  if (val != null) setDialogState(() => selectedTipo = val);
                },
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: selectedPlan,
                decoration: const InputDecoration(
                  labelText: 'Plan',
                  border: OutlineInputBorder(),
                ),
                items: planes
                    .map(
                      (p) => DropdownMenuItem(
                        value: p.nombre,
                        child: Text(
                          '${p.nombre} - \${p.precio.toStringAsFixed(0)}',
                        ),
                      ),
                    )
                    .toList(),
                onChanged: (val) {
                  if (val != null) setDialogState(() => selectedPlan = val);
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, {
                'tipo': selectedTipo,
                'plan': selectedPlan,
              }),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accent,
                foregroundColor: Colors.white,
              ),
              child: const Text('Crear'),
            ),
          ],
        ),
      ),
    );

    if (result != null && mounted) {
      try {
        final plan = planes.firstWhere((p) => p.nombre == result['plan']);
        final codigo = LicenseService.generateLicenseCode(
          result['tipo']!,
          result['plan']!,
          DateTime.now().add(Duration(days: plan.diasDuracion)),
          '',
        );
        await db.createLicenciaCliente(
          id: 'LC${DateTime.now().millisecondsSinceEpoch}',
          clienteId: _cliente.id,
          codigo: codigo,
          plan: result['plan']!,
          fechaCreacion: DateTime.now(),
          fechaExpiracion: DateTime.now().add(
            Duration(days: plan.diasDuracion),
          ),
          precioPagado: plan.precio,
        );
        await _loadLicencias();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Licencia creada'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
          );
        }
      }
    }
  }
}
