import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:etecsa/config/theme/app_theme.dart';
import 'package:etecsa/core/database/app_database.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:uuid/uuid.dart';
import 'package:etecsa/core/security/license_service.dart';

class AllLicensesScreen extends StatefulWidget {
  final bool embedded;
  const AllLicensesScreen({super.key, this.embedded = false});

  @override
  State<AllLicensesScreen> createState() => _AllLicensesScreenState();
}

class _AllLicensesScreenState extends State<AllLicensesScreen> {
  bool _isLoading = true;
  List<LicenciasClienteData> _licenses = [];
  List<Cliente> _clientes = [];
  List<LicensePlane> _dbPlans = [];
  
  // Paginación
  static const int _pageSize = 20;
  int _currentPage = 0;
  int _totalCount = 0;
  bool _hasMore = true;
  
  // Filtros
  String _searchQuery = '';
  String _filterEstado = ''; // '', 'activa', 'vencida', 'cancelada'

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    
    try {
      final db = AppDatabase.instance;
      
      // Cargar clientes
      _clientes = await db.getAllClientes();

      // Cargar planes desde DB
      _dbPlans = await db.getAllLicensePlanes();
      
      // Obtener total de licencias con filtros
      _totalCount = await _getFilteredLicensesCount();
      
      // Cargar página actual
      _licenses = await _loadPage(0);
      _currentPage = 0;
      _hasMore = _licenses.length >= _pageSize;
      
    } catch (e) {
      print('Error loading: $e');
    }
    
    setState(() => _isLoading = false);
  }

  Future<int> _getFilteredLicensesCount() async {
    final db = AppDatabase.instance;
    var licencias = await db.getAllLicenciasCliente();
    
    // Aplicar filtro de estado
    if (_filterEstado.isNotEmpty) {
      licencias = licencias.where((l) => l.estado == _filterEstado).toList();
    }
    
    // Aplicar filtro de búsqueda
    if (_searchQuery.isNotEmpty) {
      final query = _searchQuery.toLowerCase();
      licencias = licencias.where((l) {
        final cliente = _clientes.where((c) => c.id == l.clienteId).firstOrNull;
      final nombreCliente = cliente?.nombre.toLowerCase() ?? '';
      final negocioCliente = cliente?.negocio?.toLowerCase() ?? '';
      return nombreCliente.contains(query) || negocioCliente.contains(query);
    }).toList();
  }

  return licencias.length;
}

Future<List<LicenciasClienteData>> _loadPage(int page) async {
  final db = AppDatabase.instance;
  final offset = page * _pageSize;

  var licencias = await db.getLicenciasClientePaginadas(
    limit: _pageSize,
    offset: offset,
    estado: _filterEstado.isNotEmpty ? _filterEstado : null,
  );

  // Si hay búsqueda, filtrar localmente
  if (_searchQuery.isNotEmpty) {
    final query = _searchQuery.toLowerCase();
    licencias = licencias.where((l) {
      final cliente = _clientes.where((c) => c.id == l.clienteId).firstOrNull;
      final nombreCliente = cliente?.nombre.toLowerCase() ?? '';
      final negocioCliente = cliente?.negocio?.toLowerCase() ?? '';
        return nombreCliente.contains(query) || negocioCliente.contains(query);
      }).toList();
    }
    
    return licencias;
  }

  String _getClienteName(String clienteId) {
    final cliente = _clientes.where((c) => c.id == clienteId).firstOrNull;
    return cliente?.nombre ?? 'Cliente desconocido';
  }

  /// Returns the business name, or null if none
  String? _getClienteNegocio(String clienteId) {
    final cliente = _clientes.where((c) => c.id == clienteId).firstOrNull;
    if (cliente?.negocio != null && cliente!.negocio!.isNotEmpty) {
      return cliente.negocio;
    }
    return null;
  }

  Color _getEstadoBadgeColor(String estado) {
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

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  Future<void> _cancelLicense(LicenciasClienteData licencia) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancelar Licencia'),
        content: Text('¿Está seguro que desea cancelar la licencia de ${_getClienteName(licencia.clienteId)}${_getClienteNegocio(licencia.clienteId) != null ? ' (${_getClienteNegocio(licencia.clienteId)})' : ''}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('No'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
            child: const Text('Sí, Cancelar'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        final db = AppDatabase.instance;
        await db.cancelLicenciaCliente(licencia.id);
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Licencia cancelada correctamente'),
              backgroundColor: Colors.orange,
            ),
          );
          _loadData();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error al cancelar: $e')),
          );
        }
      }
    }
  }

  /// Cuenta cuántas licencias activas tiene un cliente (excluyendo la actual)
  Future<int> _countClientActiveLicenses(String clienteId, String excludeId) async {
    final db = AppDatabase.instance;
    final todas = await db.getAllLicenciasCliente();
    return todas.where((l) =>
      l.clienteId == clienteId &&
      l.id != excludeId &&
      l.estado == 'activa'
    ).length;
  }

  /// Diálogo para extender una licencia individual
  Future<void> _showExtendLicenseDialog(LicenciasClienteData licencia) async {
    final diasController = TextEditingController(text: '30');
    final result = await showDialog<int>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Extender Licencia'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Cliente: ${_getClienteName(licencia.clienteId)}'),
            Text('Plan: ${_getPlanDisplay(licencia.plan)}'),
            Text('Expira: ${_formatDate(licencia.fechaExpiracion)}'),
            const SizedBox(height: 16),
            TextField(
              controller: diasController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Días a extender',
                hintText: '30',
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
                  const SnackBar(content: Text('Ingrese un número válido de días')),
                );
                return;
              }
              Navigator.pop(context, dias);
            },
            child: const Text('Extender'),
          ),
        ],
      ),
    );

    if (result != null && mounted) {
      try {
        final db = AppDatabase.instance;
        await db.renewLicenciaCliente(licencia.id, result);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Licencia extendida por $result días'),
              backgroundColor: Colors.green,
            ),
          );
          _loadData();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e')),
          );
        }
      }
    }
  }

  /// Diálogo para extender TODAS las licencias activas de un cliente
  Future<void> _showBatchExtendDialog(String clienteId) async {
    final diasController = TextEditingController(text: '30');
    final result = await showDialog<int>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Extender Cliente'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Cliente: ${_getClienteName(clienteId)}'),
            const Text('Se extenderán TODAS las licencias activas de este cliente'),
            const SizedBox(height: 16),
            TextField(
              controller: diasController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Días a extender',
                hintText: '30',
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
                  const SnackBar(content: Text('Ingrese un número válido de días')),
                );
                return;
              }
              Navigator.pop(context, dias);
            },
            child: const Text('Extender todas'),
          ),
        ],
      ),
    );

    if (result != null && mounted) {
      try {
        final db = AppDatabase.instance;
        final count = await db.batchRenewLicenciasByCliente(clienteId, result);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('$count licencias extendidas por $result días'),
              backgroundColor: Colors.green,
            ),
          );
          _loadData();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e')),
          );
        }
      }
    }
  }

  /// Diálogo para cambiar el plan de una licencia (ej: FREE → NEGOCIO)
  /// Opcionalmente actualiza TODAS las licencias activas del mismo cliente.
  Future<void> _showChangePlanDialog(LicenciasClienteData licencia) async {
    String selectedPlan = licencia.plan.toUpperCase();
    if (!_dbPlans.any((p) => p.nombre == selectedPlan)) {
      selectedPlan = _dbPlans.isNotEmpty ? _dbPlans.first.nombre : 'FREE';
    }
    bool aplicarATodas = false;

    // Verificar cuántas licencias activas tiene el cliente además de esta
    final otrasActivas = await _countClientActiveLicenses(licencia.clienteId, licencia.id);

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Cambiar Plan'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Cliente: ${_getClienteName(licencia.clienteId)}', style: const TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text('Plan actual: ${_getPlanDisplay(licencia.plan)}'),
                Text('Expira: ${_formatDate(licencia.fechaExpiracion)}'),
                const SizedBox(height: 16),
                const Text('Nuevo Plan:', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  value: selectedPlan,
                  items: _dbPlans.map((p) => DropdownMenuItem(
                    value: p.nombre,
                    child: Text(p.precio == 0
                      ? '${p.nombre} - Gratis (${p.diasDuracion} días)'
                      : '${p.nombre} - \$${p.precio.toInt()} (${p.diasDuracion} días)'),
                  )).toList(),
                  onChanged: (v) => setDialogState(() => selectedPlan = v!),
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                  ),
                ),
                const SizedBox(height: 16),
                if (otrasActivas > 0) ...[
                  CheckboxListTile(
                    value: aplicarATodas,
                    onChanged: (v) => setDialogState(() => aplicarATodas = v ?? false),
                    title: Text('Aplicar a las $otrasActivas licencias activas restantes de este cliente'),
                    subtitle: const Text('Admin + vendedores se actualizarán al mismo plan'),
                    controlAffinity: ListTileControlAffinity.leading,
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                  ),
                  const SizedBox(height: 8),
                ],
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.amber.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, color: Colors.amber.shade700, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Se generará un código nuevo para cada licencia. El cliente no necesita reactivar.',
                          style: TextStyle(fontSize: 12, color: Colors.amber.shade800),
                        ),
                      ),
                    ],
                  ),
                ),
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
                final dbPlan = _dbPlans.where((p) => p.nombre == selectedPlan).firstOrNull;
                if (dbPlan == null) return;
                Navigator.pop(context, {
                  'plan': selectedPlan,
                  'dias': dbPlan.diasDuracion,
                  'precio': dbPlan.precio,
                  'aplicarATodas': aplicarATodas,
                });
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.amber.shade600,
                foregroundColor: Colors.white,
              ),
              child: const Text('Cambiar Plan'),
            ),
          ],
        ),
      ),
    );

    if (result != null && mounted) {
      try {
        final db = AppDatabase.instance;
        final nuevoPlan = result['plan'] as String;
        final dias = result['dias'] as int;
        final precio = result['precio'] as double;
        final aplicarTodas = result['aplicarATodas'] as bool;
        final now = DateTime.now();
        final nuevaFecha = now.add(Duration(days: dias));

        if (aplicarTodas) {
          // Cambiar TODAS las licencias activas del cliente
          final todas = await db.getAllLicenciasCliente();
          final delCliente = todas.where((l) =>
            l.clienteId == licencia.clienteId && l.estado == 'activa');

          int count = 0;
          for (final l in delCliente) {
            final tipo = _inferTipoFromCodigo(l.codigo);
            final androidId = _extractAndroidIdFromCode(l.codigo);
            final nuevoCodigo = _generarCodigo(tipo, nuevoPlan, androidId: androidId);
            await db.updateLicenciaCliente(
              id: l.id,
              codigo: nuevoCodigo,
              plan: nuevoPlan.toLowerCase(),
              fechaExpiracion: nuevaFecha,
              precioPagado: precio,
            );
            count++;
          }
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('$count licencias cambiadas a $nuevoPlan'),
                backgroundColor: Colors.green,
              ),
            );
          }
        } else {
          // Cambiar SOLO esta licencia
          final tipo = _inferTipoFromCodigo(licencia.codigo);
          final androidId = _extractAndroidIdFromCode(licencia.codigo);
          final nuevoCodigo = _generarCodigo(tipo, nuevoPlan, androidId: androidId);
          await db.updateLicenciaCliente(
            id: licencia.id,
            codigo: nuevoCodigo,
            plan: nuevoPlan.toLowerCase(),
            fechaExpiracion: nuevaFecha,
            precioPagado: precio,
          );
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Licencia cambiada a $nuevoPlan'),
                backgroundColor: Colors.green,
              ),
            );
          }
        }

        // Ofrecer enviar códigos por WhatsApp
        if (mounted) {
          final enviar = await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('¿Enviar códigos?'),
              content: const Text('¿Querés enviar los nuevos códigos por WhatsApp al cliente?'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('No'),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('Sí, enviar'),
                ),
              ],
            ),
          );

          if (enviar == true) {
            final cliente = _clientes.where((c) => c.id == licencia.clienteId).firstOrNull;
            if (cliente != null && cliente.telefono.isNotEmpty) {
              // Enviar el código de la licencia principal
              final licenciasActualizadas = await db.getAllLicenciasCliente();
              final deEsteCliente = licenciasActualizadas.where((l) =>
                l.clienteId == licencia.clienteId &&
                (aplicarTodas || l.id == licencia.id));
              for (final l in deEsteCliente) {
                await _enviarPorWhatsApp(cliente.telefono, l.codigo, l.plan);
                await Future.delayed(const Duration(seconds: 1)); // evitar spam
              }
            }
          }
        }

        _loadData();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e')),
          );
        }
      }
    }
  }

  /// Inferir tipo (ADMIN/VENDEDOR) desde el código de licencia
  String _inferTipoFromCodigo(String codigo) {
    final parts = codigo.toUpperCase().split('-');
    if (parts.isNotEmpty && ['ADMIN', 'VENDEDOR', 'ALMACENERO'].contains(parts[0])) {
      return parts[0];
    }
    return 'ADMIN'; // default
  }

  /// Extraer Android ID desde un código de licencia existente
  /// Formato: TIPO-PLAN-FECHA-ANDROIDID-HASH
  /// El device ID puede contener guiones (ej: VVOB35.78-66)
  String _extractAndroidIdFromCode(String codigo) {
    final parts = codigo.toUpperCase().split('-');
    if (parts.length > 6) {
      // Device ID está entre posicion 5 y el ultimo segmento (hash)
      return parts.sublist(5, parts.length - 1).join('-');
    } else if (parts.length == 6) {
      return parts[5];
    }
    return 'DEV';
  }

  String _generarCodigo(String tipo, String plan, {String? androidId}) {
    final dbPlan = _dbPlans.where((p) => p.nombre == plan).firstOrNull;
    final duration = dbPlan?.diasDuracion ?? 30;
    return LicenseService.generateLicenseCode(tipo, plan, DateTime.now().add(Duration(days: duration)), androidId ?? '');
  }

  String _getPrecio(String plan) {
    final dbPlan = _dbPlans.where((p) => p.nombre == plan).firstOrNull;
    if (dbPlan != null) {
      if (dbPlan.precio == 0) return 'Gratis';
      return '\$${dbPlan.precio.toInt()} (${dbPlan.diasDuracion} días)';
    }
    return '';
  }

  Future<void> _enviarPorWhatsApp(String telefono, String codigo, String plan) async {
    final phone = telefono.replaceAll(RegExp(r'[^\d]'), '');
    final hasCountryCode = telefono.trim().startsWith('+');
    final fullPhone = hasCountryCode ? phone : '53$phone';
    final text = '¡Hola! Aquí está tu licencia de ExpressPos\n\n'
        'Tipo: $plan\n'
        'Código: $codigo\n\n'
        'Instala la app e ingresa este código para activar tu licencia.\n\n'
        '© 2026 ExpressPos';

    final url = Uri.parse('https://wa.me/$fullPhone?text=${Uri.encodeComponent(text)}');

    try {
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      await Clipboard.setData(ClipboardData(text: '$fullPhone\n$codigo'));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Teléfono copiado')),
        );
      }
    }
  }

  Future<void> _enviarPorSms(String telefono, String codigo, String plan) async {
    final phone = telefono.replaceAll(RegExp(r'[^\d]'), '');
    final text = 'Licencia ExpressPos:\nPlan: $plan\nCódigo: $codigo\n'
        'Instalá la app e ingresá el código para activar.';

    final url = Uri.parse('sms:$phone?body=${Uri.encodeComponent(text)}');

    try {
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      await Clipboard.setData(ClipboardData(text: text));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Mensaje copiado al portapapeles')),
        );
      }
    }
  }

  void _showCrearLicenciaDialog() {
    String selectedPlan = _dbPlans.isNotEmpty ? _dbPlans.first.nombre : 'FREE';
    String selectedTipo = 'ADMIN';
    dynamic selectedCliente;
  final telefonoController = TextEditingController();
  final androidIdController = TextEditingController();

  final clientesActivos = _clientes.where((c) => c.active == true).toList();

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Crear Licencia'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Cliente:', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                DropdownButtonFormField<dynamic>(
                  value: selectedCliente,
                  hint: const Text('Seleccionar cliente (opcional)'),
                  isExpanded: true,
                  items: [
                    const DropdownMenuItem<dynamic>(
                      value: null,
                      child: Text('Sin cliente asociado'),
                    ),
                    ...clientesActivos.map((cliente) => DropdownMenuItem<dynamic>(
                      value: cliente,
                      child: Text(
                        cliente.negocio != null && cliente.negocio!.isNotEmpty
                            ? '${cliente.nombre} - ${cliente.negocio}'
                            : cliente.nombre,
                        overflow: TextOverflow.ellipsis,
                      ),
                    )),
                  ],
                  onChanged: (v) {
                    setDialogState(() {
                      selectedCliente = v;
                      if (v != null && v.telefono != null) {
                        telefonoController.text = v.telefono;
                      }
                    });
                  },
                ),
                const SizedBox(height: 16),
                const Text('Tipo de Licencia:', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  value: selectedTipo,
                  items: const [
                    DropdownMenuItem(value: 'ADMIN', child: Text('Admin (Cliente)')),
                    DropdownMenuItem(value: 'VENDEDOR', child: Text('Vendedor')),
                  ],
                  onChanged: (v) => setDialogState(() => selectedTipo = v!),
                ),
                const SizedBox(height: 16),
                const Text('Plan:', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  value: selectedPlan,
                  items: _dbPlans.map((p) => DropdownMenuItem(
                    value: p.nombre,
                    child: Text(p.precio == 0 ? '${p.nombre} - Gratis' : '${p.nombre} - \$${p.precio.toInt()} (${p.diasDuracion} días)'),
                  )).toList(),
                  onChanged: (v) => setDialogState(() => selectedPlan = v!),
                ),
                const SizedBox(height: 16),
        TextField(
          controller: telefonoController,
          keyboardType: TextInputType.phone,
          decoration: const InputDecoration(
            labelText: 'WhatsApp del cliente',
            hintText: '+53 5XX XXXX XXX',
          ),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: androidIdController,
          decoration: const InputDecoration(
            labelText: 'ID de Dispositivo del Cliente',
            hintText: 'El cliente debe proporcionar su ID',
            prefixIcon: Icon(Icons.phone_android, size: 20),
          ),
        ),
        const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Resumen:', style: TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      Text('Cliente: ${selectedCliente?.nombre ?? "Sin asignar"}'),
                      Text('Tipo: $selectedTipo'),
                      Text('Plan: $selectedPlan'),
                      Text('Precio: ${_getPrecio(selectedPlan)}'),
                    ],
                  ),
                ),
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
                if (telefonoController.text.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('El teléfono es obligatorio')),
                  );
                  return;
                }

                if (androidIdController.text.isEmpty) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Se recomienda ingresar el ID del dispositivo para vincular la licencia'),
                backgroundColor: Colors.orange,
                duration: Duration(seconds: 3),
              ),
            );
          }
          final codigo = _generarCodigo(selectedTipo, selectedPlan, androidId: androidIdController.text);
                final now = DateTime.now();
                final fechaFin = now.add(Duration(days: _dbPlans.where((p) => p.nombre == selectedPlan).firstOrNull?.diasDuracion ?? 30));

                final db = AppDatabase.instance;
                await db.createLicense(
                  id: const Uuid().v4(),
                  licenseKey: codigo,
                  tipo: selectedTipo == 'ADMIN' ? 'admin' : 'vendedor',
                  fechaInicio: now,
                  fechaFin: fechaFin,
                );

                if (selectedCliente != null) {
                  try {
                    await db.createLicenciaCliente(
                      id: const Uuid().v4(),
                      clienteId: selectedCliente.id,
                      codigo: codigo,
                      plan: selectedPlan.toLowerCase(),
                      fechaCreacion: now,
                      fechaExpiracion: fechaFin,
                    );
                  } catch (e) {
                    print('Error al asociar licencia al cliente: $e');
                  }
                }

                if (telefonoController.text.isNotEmpty) {
                  await _enviarPorWhatsApp(telefonoController.text, codigo, selectedPlan);
                }

                if (context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Licencia creada: $codigo')),
                  );
                  _loadData();
                }
              },
              child: const Text('Crear y Enviar'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Calcular estadísticas
    final activas = _licenses.where((l) => l.estado == 'activa').length;
    final vencidas = _licenses.where((l) => l.estado == 'vencida').length;
    final canceladas = _licenses.where((l) => l.estado == 'cancelada').length;

    final body = _isLoading && _licenses.isEmpty
        ? const Center(child: CircularProgressIndicator())
        : Column(
            children: [
              // Barra de búsqueda y filtros
              Container(
                padding: const EdgeInsets.all(16),
                color: Colors.grey.shade100,
                child: Column(
                  children: [
                    // Buscador
                    TextField(
                      decoration: InputDecoration(
                        hintText: 'Buscar por nombre de cliente...',
                        prefixIcon: const Icon(Icons.search),
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      ),
                      onChanged: (value) {
                        setState(() => _searchQuery = value);
                        _loadData();
                      },
                    ),
                    const SizedBox(height: 12),
                    // Filtros de estado
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          _buildFilterChip('Todas', ''),
                          const SizedBox(width: 8),
                          _buildFilterChip('Activas', 'activa'),
                          const SizedBox(width: 8),
                          _buildFilterChip('Vencidas', 'vencida'),
                          const SizedBox(width: 8),
                          _buildFilterChip('Canceladas', 'cancelada'),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // Stats
              Container(
                padding: const EdgeInsets.all(16),
                color: Colors.white,
                child: Row(
                  children: [
                    Expanded(
                      child: _buildStatItem(
                        label: 'Total',
                        value: _totalCount.toString(),
                        color: AppTheme.colorCeleste,
                      ),
                    ),
                    Expanded(
                      child: _buildStatItem(
                        label: 'Activas',
                        value: activas.toString(),
                        color: Colors.green,
                      ),
                    ),
                    Expanded(
                      child: _buildStatItem(
                        label: 'Vencidas',
                        value: vencidas.toString(),
                        color: Colors.red,
                      ),
                    ),
                    Expanded(
                      child: _buildStatItem(
                        label: 'Canceladas',
                        value: canceladas.toString(),
                        color: Colors.orange,
                      ),
                    ),
                  ],
                ),
              ),

        // Lista de licencias
        Expanded(
          child: _licenses.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.key_off, size: 64, color: Colors.grey.shade300),
                      const SizedBox(height: 16),
                      Text(
                        'No hay licencias',
                        style: TextStyle(
                          fontSize: 18,
                          color: Colors.grey.shade500,
                        ),
                      ),
                    ],
                  ),
                )
              : Column(
                  children: [
                    Expanded(
                      child: RefreshIndicator(
                        onRefresh: _loadData,
                        child: _buildGroupedLicenseList(),
                      ),
                    ),
                    // Pagination controls
                    if (_totalCount > _pageSize)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          border: Border(top: BorderSide(color: Colors.grey.shade300)),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.chevron_left),
                              onPressed: _currentPage > 0 ? () async {
                                final prev = await _loadPage(_currentPage - 1);
                                setState(() {
                                  _licenses = prev;
                                  _currentPage--;
                                  _hasMore = true;
                                });
                              } : null,
                            ),
                            Text(
                              'Página ${_currentPage + 1} de ${(_totalCount / _pageSize).ceil()}',
                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                            ),
                            IconButton(
                              icon: const Icon(Icons.chevron_right),
                              onPressed: _hasMore ? () async {
                                final next = await _loadPage(_currentPage + 1);
                                if (next.isNotEmpty) {
                                  setState(() {
                                    _licenses = next;
                                    _currentPage++;
                                    _hasMore = next.length >= _pageSize;
                                  });
                                }
                              } : null,
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
        ),
            ],
          );

    if (widget.embedded) {
      return Stack(
        children: [
          body,
          Positioned(
            bottom: 16,
            right: 16,
            child: FloatingActionButton(
              onPressed: _showCrearLicenciaDialog,
              backgroundColor: AppTheme.colorCeleste,
              child: const Icon(Icons.add, color: Colors.white),
            ),
          ),
        ],
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Todas las Licencias'),
        backgroundColor: AppTheme.colorCeleste,
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/'),
        ),
      ),
      body: body,
      floatingActionButton: FloatingActionButton(
        onPressed: _showCrearLicenciaDialog,
        backgroundColor: AppTheme.colorCeleste,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  Widget _buildLicenseCard(LicenciasClienteData licencia) {
    final estadoColor = _getEstadoBadgeColor(licencia.estado);
    final negocio = _getClienteNegocio(licencia.clienteId);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () => _showLicenseDetails(licencia),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Status icon
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: estadoColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  licencia.estado == 'activa'
                      ? Icons.check_circle
                      : licencia.estado == 'cancelada'
                          ? Icons.cancel
                          : Icons.error,
                  color: estadoColor,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              // Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Line 1: Client name
                    Text(
                      _getClienteName(licencia.clienteId),
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      overflow: TextOverflow.ellipsis,
                    ),
                    // Line 2: Business name (separate line)
                    if (negocio != null) ...[
                      const SizedBox(height: 1),
                      Text(
                        negocio,
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    const SizedBox(height: 6),
                    // Plan badge + expiry on same row
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppTheme.colorCeleste.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            _getPlanDisplay(licencia.plan),
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.colorCeleste,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            'Expira: ${_formatDate(licencia.fechaExpiracion)}',
                            style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              // Right side: status badge + cancel icon stacked vertically
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                    decoration: BoxDecoration(
                      color: estadoColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: estadoColor.withValues(alpha: 0.3)),
                    ),
                    child: Text(
                      licencia.estado.toUpperCase(),
                      style: TextStyle(color: estadoColor, fontWeight: FontWeight.bold, fontSize: 9),
                    ),
                  ),
                  if (licencia.estado == 'activa') ...[
                    const SizedBox(height: 6),
                    SizedBox(
                      width: 28,
                      height: 28,
                      child: IconButton(
                        icon: Icon(Icons.refresh, color: Colors.blue.shade600, size: 20),
                        tooltip: 'Extender licencia',
                        onPressed: () => _showExtendLicenseDialog(licencia),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ),
                    const SizedBox(height: 4),
                    SizedBox(
                      width: 28,
                      height: 28,
                      child: IconButton(
                        icon: Icon(Icons.cancel_outlined, color: Colors.orange.shade600, size: 20),
                        tooltip: 'Cancelar licencia',
                        onPressed: () => _cancelLicense(licencia),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFilterChip(String label, String value) {
    final isSelected = _filterEstado == value;
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        setState(() => _filterEstado = selected ? value : '');
        _loadData();
      },
      selectedColor: AppTheme.colorCeleste.withValues(alpha: 0.2),
      checkmarkColor: AppTheme.colorCeleste,
    );
  }

  Widget _buildStatItem({
    required String label,
    required String value,
    required Color color,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            color: Colors.grey.shade600,
          ),
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }

  /// Build grouped license list: group _licenses by clienteId,
  /// render ExpansionTile per client, children use _buildLicenseCard.
  Widget _buildGroupedLicenseList() {
    if (_licenses.isEmpty) {
      return ListView(
        children: [
          SizedBox(
            height: 200,
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.key_off, size: 64, color: Colors.grey.shade300),
                  const SizedBox(height: 16),
                  Text(
                    'No hay licencias',
                    style: TextStyle(
                      fontSize: 18,
                      color: Colors.grey.shade500,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      );
    }

    // Group licenses by clienteId
    final Map<String, List<LicenciasClienteData>> grouped = {};
    for (final lic in _licenses) {
      grouped.putIfAbsent(lic.clienteId, () => []).add(lic);
    }

    // Sort groups by client name
    final sortedKeys = grouped.keys.toList()
      ..sort((a, b) => _getClienteName(a).compareTo(_getClienteName(b)));

    return ListView(
      padding: const EdgeInsets.all(16),
      children: sortedKeys.map((clienteId) {
        final licencias = grouped[clienteId]!;
        final clienteName = _getClienteName(clienteId);
        final negocio = _getClienteNegocio(clienteId);
        final activeCount = licencias.where((l) => l.estado == 'activa').length;
        final totalCount = licencias.length;

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withValues(alpha: 0.1),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: ExpansionTile(
            tilePadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
            shape: const Border(),
            collapsedShape: const Border(),
            leading: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: AppTheme.colorCeleste.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Center(
                child: Text(
                  clienteName.isNotEmpty
                      ? clienteName[0].toUpperCase()
                      : '?',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.colorCeleste,
                  ),
                ),
              ),
            ),
            title: Text(
              clienteName,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
            subtitle: Row(
              children: [
                if (negocio != null) ...[
                  Flexible(
                    child: Text(
                      negocio,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '$activeCount/$totalCount',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: Colors.green.shade700,
                    ),
                  ),
                ),
              ],
            ),
            children: licencias.map((lic) {
              return _buildLicenseCard(lic);
            }).toList(),
          ),
        );
      }).toList(),
    );
  }

  void _showLicenseDetails(LicenciasClienteData licencia) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.5,
        minChildSize: 0.3,
        maxChildSize: 0.8,
        expand: false,
        builder: (context, scrollController) => SingleChildScrollView(
          controller: scrollController,
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Detalles de Licencia',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 20),
                _buildDetailRow('Cliente', _getClienteName(licencia.clienteId)),
                if (_getClienteNegocio(licencia.clienteId) != null)
                  _buildDetailRow('Negocio', _getClienteNegocio(licencia.clienteId)!),
              _buildDetailRow('Plan', _getPlanDisplay(licencia.plan)),
              _buildDetailRow('Estado', licencia.estado.toUpperCase()),
              _buildDetailRow('Fecha de Activación', _formatDate(licencia.fechaCreacion)),
              _buildDetailRow(
                licencia.estado == 'cancelada' ? 'Fecha de Cancelación' : 'Fecha de Expiración',
                licencia.estado == 'cancelada' && licencia.fechaCancelacion != null
                    ? _formatDate(licencia.fechaCancelacion!)
                    : _formatDate(licencia.fechaExpiracion),
              ),
              _buildDetailRow('Precio Pagado', '\$${licencia.precioPagado.toStringAsFixed(2)}'),
              if (licencia.notas != null && licencia.notas!.isNotEmpty)
                _buildDetailRow('Notas', licencia.notas!),
              const SizedBox(height: 20),
              // Código de licencia con copiar y SMS
              const Text(
                'Código de Licencia',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.grey),
              ),
              const SizedBox(height: 8),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      Expanded(
                        child: SelectableText(
                          licencia.codigo,
                          style: const TextStyle(fontFamily: 'monospace', fontSize: 14, fontWeight: FontWeight.bold),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.copy, size: 20),
                        tooltip: 'Copiar código',
                        onPressed: () {
                          Clipboard.setData(ClipboardData(text: licencia.codigo));
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Código copiado')),
                          );
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.sms, size: 20),
                        tooltip: 'Enviar por SMS',
                        onPressed: () {
                          final cliente = _clientes.where((c) => c.id == licencia.clienteId).firstOrNull;
                          if (cliente != null) {
                            _enviarPorSms(cliente.telefono, licencia.codigo, licencia.plan);
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Sin cliente asociado')),
                            );
                          }
                        },
                      ),
                    ],
                  ),
                ),
              ),
              // Botones de acción — solo para licencias activas
              if (licencia.estado == 'activa') ...[
                const SizedBox(height: 20),
                const Divider(),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () => _showExtendLicenseDialog(licencia),
                    icon: const Icon(Icons.refresh, size: 20),
                    label: const Text('Extender esta licencia'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue.shade50,
                      foregroundColor: Colors.blue.shade700,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                // Botón para extender TODAS las licencias activas de este cliente
                FutureBuilder<int>(
                  future: _countClientActiveLicenses(licencia.clienteId, licencia.id),
                  builder: (context, snapshot) {
                    final extra = snapshot.data ?? 0;
                    if (extra <= 0) return const SizedBox.shrink();
                    return SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () => _showBatchExtendDialog(licencia.clienteId),
                        icon: const Icon(Icons.groups, size: 20),
                        label: Text('Extender +$extra licencias más de este cliente'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.teal.shade700,
                          side: BorderSide(color: Colors.teal.shade200),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () => _showChangePlanDialog(licencia),
                    icon: const Icon(Icons.swap_horiz, size: 20),
                    label: const Text('Cambiar Plan'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.amber.shade50,
                      foregroundColor: Colors.amber.shade800,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: TextStyle(
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}