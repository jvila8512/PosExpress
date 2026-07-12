import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:etecsa/config/theme/app_theme.dart';
import 'package:etecsa/core/database/app_database.dart';
import 'package:etecsa/features/license/presentation/screens/all_licenses_screen.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:uuid/uuid.dart';
import 'package:etecsa/core/security/license_service.dart';

class LicensesAdminScreen extends ConsumerStatefulWidget {
  final bool showCreateDialog;

  const LicensesAdminScreen({
    super.key,
    this.showCreateDialog = false,
  });

  @override
  ConsumerState<LicensesAdminScreen> createState() => _LicensesAdminScreenState();
}

class _LicensesAdminScreenState extends ConsumerState<LicensesAdminScreen> {
  List<dynamic> _clientes = [];
  List<dynamic> _licenciasCliente = []; // Lista de licencias de clientes
  List<dynamic> _licenciasProximasVencer = []; // Licencias próximas a vencer
  List<LicensePlane> _dbPlans = []; // Planes cargados desde DB
  bool _isLoading = true;
  
  // Stats counters
  int _clientesCount = 0;
  int _licenciasActivasCount = 0;
  int _licenciasVencidasCount = 0;
  int _licenciasCanceladasCount = 0;
  double _ingresosTotales = 0;

  @override
  void initState() {
    super.initState();
    _loadData();
    // Show create dialog if requested
    if (widget.showCreateDialog) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showCrearLicenciaDialog();
      });
    }
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final db = AppDatabase.instance;

    try {
      // Cargar clientes
      _clientes = await db.getAllClientes();
      _clientesCount = await db.getClientesCount();

      // Cargar licencias de clientes
      _licenciasCliente = await db.getAllLicenciasCliente();
      _licenciasActivasCount = _licenciasCliente.where((l) => l.estado == 'activa').length;
      _licenciasVencidasCount = _licenciasCliente.where((l) => l.estado == 'vencida').length;
      _licenciasCanceladasCount = _licenciasCliente.where((l) => l.estado == 'cancelada').length;

      // Cargar licencias próximas a vencer (próximos 7 días)
      _licenciasProximasVencer = await db.getLicenciasProximasVencer(7);

      // Calcular ingresos (simplificado - suma simple de licencias activas)
      _ingresosTotales = await db.getTotalLicenseIncome();

      // Cargar planes de licencia desde DB (todos, incluso inactivos para admin)
      _dbPlans = await db.getAllLicensePlanesAdmin();
    } catch (e) {
      // Si hay error (tablas no existen), usar valores por defecto
      _clientesCount = 0;
      _licenciasActivasCount = 0;
      _licenciasVencidasCount = 0;
      _licenciasCanceladasCount = 0;
      _ingresosTotales = 0;
      _dbPlans = [];
    }

    setState(() {
      _isLoading = false;
    });
  }

  String _getClienteName(String clienteId) {
    final cliente = _clientes.where((c) => c.id == clienteId).firstOrNull;
    if (cliente == null) return 'Cliente desconocido';
    if (cliente.negocio != null && cliente.negocio!.isNotEmpty) {
      return '${cliente.nombre} - ${cliente.negocio}';
    }
    return cliente.nombre;
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  Future<void> _cancelLicense(dynamic licencia) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancelar Licencia'),
        content: Text('¿Está seguro que desea cancelar la licencia de ${_getClienteName(licencia.clienteId)}?'),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Gestión de Licencias'),
        backgroundColor: AppTheme.colorCeleste,
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/'),
        ),
        actions: [
          // Badge de notificaciones de licencias próximas a vencer
          if (_licenciasProximasVencer.isNotEmpty)
            Stack(
              children: [
                IconButton(
                  icon: const Icon(Icons.notifications),
                  onPressed: () {
                    // Scroll hacia la sección de alertas
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('${_licenciasProximasVencer.length} licencias próximo a vencer'),
                        backgroundColor: Colors.orange,
                        action: SnackBarAction(
                          label: 'VER',
                          textColor: Colors.white,
                          onPressed: () {},
                        ),
                      ),
                    );
                  },
                ),
                Positioned(
                  right: 8,
                  top: 8,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                    ),
                    constraints: const BoxConstraints(
                      minWidth: 18,
                      minHeight: 18,
                    ),
                    child: Text(
                      '${_licenciasProximasVencer.length}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              ],
            ),
          // Botón para ver todas las licencias
          IconButton(
            icon: const Icon(Icons.list_alt),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const AllLicensesScreen(),
                ),
              );
            },
            tooltip: 'Ver todas las licencias',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ===== STATS CARDS =====
                  const Text('Estadísticas', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  
                  Row(
                    children: [
                      Expanded(
                        child: _buildStatCard(
                          'Clientes',
                          _clientesCount.toString(),
                          Icons.people,
                          Colors.blue,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildStatCard(
                          'Licencias Activas',
                          _licenciasActivasCount.toString(),
                          Icons.verified_user,
                          Colors.green,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildStatCard(
                          'Ingresos',
                          '\$${_ingresosTotales.toStringAsFixed(2)}',
                          Icons.attach_money,
                          Colors.purple,
                        ),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 24),
                  
                  // Botones de acción
                  const Text('Acciones', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      SizedBox(
                        width: (MediaQuery.of(context).size.width - 56) / 2,
                        child: _buildActionButton(
                          'Nuevo Cliente',
                          Icons.person_add,
                          Colors.blue,
                          () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => AgregarClienteScreen(
                                onClienteGuardado: _loadData,
                              ),
                            ),
                          ),
                        ),
                      ),
                      SizedBox(
                        width: (MediaQuery.of(context).size.width - 56) / 2,
                        child: _buildActionButton(
                          'Crear Licencia',
                          Icons.key,
                          Colors.green,
                          () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => CrearLicenciaScreen(
                                clientes: _clientes,
                                onLicenciaCreada: _loadData,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 24),
                  
                  // Lista de licencias de clientes
                  const Text('Licencias de Clientes', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  
                  if (_licenciasCliente.isEmpty)
                    const Card(
                      child: ListTile(
                        leading: Icon(Icons.info_outline),
                        title: Text('No hay licencias'),
                        subtitle: Text('Crea la primera licencia'),
                      ),
                    )
                  else
                    ...(_licenciasCliente.map((licencia) {
                      // Buscar nombre del cliente
                      final cliente = _clientes.where((c) => c.id == licencia.clienteId).firstOrNull;
                      final nombreCliente = cliente?.nombre ?? 'Cliente desconocido';
                      final negocioCliente = cliente?.negocio;
                      final nombreCompleto = negocioCliente != null && negocioCliente.isNotEmpty
                          ? '$nombreCliente - $negocioCliente'
                          : nombreCliente;
                      
                      // Determinar color del estado
                      Color estadoColor;
                      Color badgeColor;
                      switch (licencia.estado) {
                        case 'activa':
                          estadoColor = Colors.green;
                          badgeColor = Colors.green;
                          break;
                        case 'vencida':
                          estadoColor = Colors.red;
                          badgeColor = Colors.red;
                          break;
                        case 'cancelada':
                          estadoColor = Colors.grey;
                          badgeColor = Colors.orange;
                          break;
                        default:
                          estadoColor = Colors.grey;
                          badgeColor = Colors.grey;
                      }
                      
                      return Card(
                        child: ListTile(
                          leading: Icon(
                            licencia.estado == 'activa' 
                                ? Icons.check_circle 
                                : licencia.estado == 'cancelada'
                                    ? Icons.cancel
                                    : Icons.error,
                            color: estadoColor,
                          ),
                          title: Text(nombreCompleto, style: const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Expira: ${_formatDate(licencia.fechaExpiracion)}'),
                              if (licencia.estado == 'cancelada' && licencia.fechaCancelacion != null)
                                Text(
                                  'Cancelada: ${_formatDate(licencia.fechaCancelacion!)}',
                                  style: TextStyle(color: Colors.orange.shade700, fontSize: 12),
                                ),
                            ],
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: badgeColor.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: badgeColor.withValues(alpha: 0.5)),
                                ),
                                child: Text(
                                  licencia.estado.toUpperCase(),
                                  style: TextStyle(
                                    color: badgeColor,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 10,
                                  ),
                                ),
                              ),
                              // Botón de cancelar para licencias activas
                              if (licencia.estado == 'activa')
                                IconButton(
                                  icon: const Icon(Icons.cancel_outlined, color: Colors.orange),
                                  onPressed: () => _cancelLicense(licencia),
                                  tooltip: 'Cancelar licencia',
                                ),
                            ],
                          ),
                          isThreeLine: licencia.estado == 'cancelada' && licencia.fechaCancelacion != null,
                        ),
                      );
                    })),
                  
                  // ===== ALERTAS DE LICENCIAS PRÓXIMAS A VENCER =====
                  if (_licenciasProximasVencer.isNotEmpty) ...[
                    const SizedBox(height: 24),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.orange.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.orange.shade200),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.warning_amber, color: Colors.orange.shade700),
                              const SizedBox(width: 8),
                              Text(
                                'Licencias Próximas a Vencer',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.orange.shade700,
                                ),
                              ),
                              const Spacer(),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.orange,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  '${_licenciasProximasVencer.length}',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Estas licencias vencen en los próximos 7 días:',
                            style: TextStyle(color: Colors.orange.shade600),
                          ),
                          const SizedBox(height: 12),
                          ...(_licenciasProximasVencer.map((licencia) {
                            final cliente = _clientes.where((c) => c.id == licencia.clienteId).firstOrNull;
                            final nombreCliente = cliente?.nombre ?? 'Cliente desconocido';
                            final diasRestantes = licencia.fechaExpiracion.difference(DateTime.now()).inDays;
                            
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: Row(
                                children: [
                                  Icon(Icons.schedule, size: 16, color: Colors.orange.shade600),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      nombreCliente,
                                      style: const TextStyle(fontWeight: FontWeight.w500),
                                    ),
                                  ),
                                  Text(
                                    '$diasRestantes días',
                                    style: TextStyle(
                                      color: diasRestantes <= 3 ? Colors.red : Colors.orange.shade700,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          })),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon, Color color) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 12,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton(String label, IconData icon, Color color, VoidCallback onPressed) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon),
      label: Text(label),
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }

  void _showAddClienteDialog() {
    final nombreController = TextEditingController();
    final telefonoController = TextEditingController();
    final negocioController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Nuevo Cliente'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nombreController,
                decoration: const InputDecoration(labelText: 'Nombre *'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: telefonoController,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(labelText: 'Teléfono WhatsApp *'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: negocioController,
                decoration: const InputDecoration(labelText: 'Nombre del Negocio'),
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
              if (nombreController.text.isEmpty || telefonoController.text.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Nombre y teléfono son obligatorios')),
                );
                return;
              }
              
              // Guardar cliente en la base de datos
              final db = AppDatabase.instance;
              await db.addCliente(
                id: const Uuid().v4(),
                nombre: nombreController.text,
                telefono: telefonoController.text,
                negocio: negocioController.text.isNotEmpty ? negocioController.text : null,
              );
              
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Cliente guardado correctamente')),
              );
              
              // Recargar datos
              _loadData();
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
  }

  void _showCrearLicenciaDialog() {
    String selectedPlan = _dbPlans.isNotEmpty ? _dbPlans.first.nombre : 'FREE';
    String selectedTipo = 'ADMIN';
    dynamic selectedCliente;
  final telefonoController = TextEditingController();
  final androidIdController = TextEditingController();

  // Filtrar solo clientes activos
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
                // Dropdown de cliente
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
                      // Auto-completar teléfono si se selecciona cliente
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
                
          // Generar código de licencia
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
      final fechaFin = now.add(Duration(days: _getPlanDurationDays(selectedPlan)));
                
                // Guardar licencia en la base de datos
                final db = AppDatabase.instance;
                await db.createLicense(
                  id: const Uuid().v4(),
                  licenseKey: codigo,
                  tipo: selectedTipo == 'ADMIN' ? 'admin' : 'vendedor',
                  fechaInicio: now,
                  fechaFin: fechaFin,
                );
                
                // Si hay cliente seleccionado, guardar la relación en LicenciasCliente
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
                
                // Enviar por WhatsApp
                if (telefonoController.text.isNotEmpty) {
                  await _enviarPorWhatsApp(telefonoController.text, codigo, selectedPlan);
                }
                
                if (context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Licencia creada: $codigo')),
                  );
                  
                  // Recargar datos
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

  String _getPrecio(String plan) {
    final dbPlan = _dbPlans.where((p) => p.nombre == plan).firstOrNull;
    if (dbPlan != null) {
      if (dbPlan.precio == 0) return 'Gratis';
      return '\${dbPlan.precio.toInt()} (${dbPlan.diasDuracion} días)';
    }
    return '';
  }

  int _getPlanDurationDays(String plan) {
    final dbPlan = _dbPlans.where((p) => p.nombre == plan).firstOrNull;
    return dbPlan?.diasDuracion ?? 30;
  }

  String _generarCodigo(String tipo, String plan, {String? androidId}) {
    final duration = _getPlanDurationDays(plan);
    return LicenseService.generateLicenseCode(tipo, plan, DateTime.now().add(Duration(days: duration)), androidId ?? '');
  }

  Future<void> _enviarPorWhatsApp(String telefono, String codigo, String plan) async {
    final phone = telefono.replaceAll(RegExp(r'[^\d]'), '');
    // Si ya tiene +, usar dígitos tal cual. Si no, agregar código de Cuba (53).
    final hasCountryCode = telefono.trim().startsWith('+');
    final fullPhone = hasCountryCode ? phone : '53$phone';
    final text = '¡Hola! Aquí está tu licencia de PosJVL\n\n'
        'Tipo: $plan\n'
        'Código: $codigo\n\n'
        'Instala la app e ingresa este código para activar tu licencia.\n\n'
        '© 2026 PosJVL';
    
    final url = Uri.parse('https://wa.me/$fullPhone?text=${Uri.encodeComponent(text)}');
    
    try {
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      // Fallback
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
    final text = 'Licencia PosJVL:\nPlan: $plan\nCódigo: $codigo\n'
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

  /// Crear licencia de prueba NEGOCIO-2026-2027-TEST01
  Future<void> _crearLicenciaPrueba() async {
    final db = AppDatabase.instance;
    
    // Obtener fechas
    final now = DateTime.now();
    final oneYearLater = DateTime(now.year + 1, now.month, now.day);
    
    // Usar la key exacta solicitada
    final licenseKey = 'NEGOCIO-2026-2027-TEST01';
    
    // Guardar en la base de datos
    await db.createLicense(
      id: const Uuid().v4(),
      licenseKey: licenseKey,
      tipo: 'NEGOCIO',
      fechaInicio: now,
      fechaFin: oneYearLater,
      dispositivoId: '', // empty for ANY device
    );
    
    // Copiar al portapapeles y mostrar
    await Clipboard.setData(ClipboardData(text: licenseKey));
    
    if (mounted) {
      _loadData(); // Recargar datos
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Licencia de prueba creada: $licenseKey'),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 5),
          action: SnackBarAction(
            label: 'COPIADO',
            textColor: Colors.white,
            onPressed: () {},
          ),
        ),
      );
    }
  }
}

// ================================================================
// PANTALLA COMPLETA PARA CREAR LICENCIA (sin diálogos)
// ================================================================
class CrearLicenciaScreen extends StatefulWidget {
  final List<dynamic> clientes;
  final VoidCallback onLicenciaCreada;

  const CrearLicenciaScreen({
    super.key,
    required this.clientes,
    required this.onLicenciaCreada,
  });

  @override
  State<CrearLicenciaScreen> createState() => _CrearLicenciaScreenState();
}

class _CrearLicenciaScreenState extends State<CrearLicenciaScreen> {
  String _selectedPlan = 'FREE';
  String _selectedTipo = 'ADMIN';
  dynamic _selectedCliente;
  final _telefonoController = TextEditingController();
  final _androidIdController = TextEditingController();
  bool _isLoading = false;
  List<LicensePlane> _dbPlans = [];

  // Filtrar solo clientes activos
  List<dynamic> get _clientesActivos =>
      widget.clientes.where((c) => c.active == true).toList();

  @override
  void initState() {
    super.initState();
    _loadPlans();
  }

  Future<void> _loadPlans() async {
    final db = AppDatabase.instance;
    final plans = await db.getAllLicensePlanes();
    if (mounted) {
      setState(() {
        _dbPlans = plans;
        if (_dbPlans.isNotEmpty && !_dbPlans.any((p) => p.nombre == _selectedPlan)) {
          _selectedPlan = _dbPlans.first.nombre;
        }
      });
    }
  }

  String _getPrecio(String plan) {
    final dbPlan = _dbPlans.where((p) => p.nombre == plan).firstOrNull;
    if (dbPlan != null) {
      if (dbPlan.precio == 0) return 'Gratis';
      return '\${dbPlan.precio.toInt()} (${dbPlan.diasDuracion} días)';
    }
    return '';
  }

  int _getPlanDurationDays(String plan) {
    final dbPlan = _dbPlans.where((p) => p.nombre == plan).firstOrNull;
    return dbPlan?.diasDuracion ?? 30;
  }

  String _generarCodigo(String tipo, String plan, {String? androidId}) {
    final duration = _getPlanDurationDays(plan);
    return LicenseService.generateLicenseCode(tipo, plan, DateTime.now().add(Duration(days: duration)), androidId ?? '');
  }

  Future<void> _enviarPorWhatsApp(String telefono, String codigo, String plan) async {
    final phone = telefono.replaceAll(RegExp(r'[^\d]'), '');
    final hasCountryCode = telefono.trim().startsWith('+');
    final fullPhone = hasCountryCode ? phone : '53$phone';
    final text = '¡Hola! Aquí está tu licencia de PosJVL\n\n'
        'Tipo: $plan\n'
        'Código: $codigo\n\n'
        'Instala la app e ingresa este código para activar tu licencia.\n\n'
        '© 2026 PosJVL';
    
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

  Future<void> _crearLicencia() async {
    if (_telefonoController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('El teléfono es obligatorio')),
      );
      return;
    }
    
    setState(() => _isLoading = true);
    
    try {
      // Generar código de licencia
      if (_androidIdController.text.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Se recomienda ingresar el ID del dispositivo para vincular la licencia'),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 3),
          ),
        );
      }
      final codigo = _generarCodigo(_selectedTipo, _selectedPlan, androidId: _androidIdController.text);
      final now = DateTime.now();
      final fechaFin = now.add(Duration(days: _getPlanDurationDays(_selectedPlan)));
      
      // Guardar licencia en la base de datos
      final db = AppDatabase.instance;
      await db.createLicense(
        id: const Uuid().v4(),
        licenseKey: codigo,
        tipo: _selectedTipo == 'ADMIN' ? 'admin' : 'vendedor',
        fechaInicio: now,
        fechaFin: fechaFin,
      );
      
      // Si hay cliente seleccionado, guardar la relación en LicenciasCliente
      if (_selectedCliente != null) {
        try {
          await db.createLicenciaCliente(
            id: const Uuid().v4(),
            clienteId: _selectedCliente.id,
            codigo: codigo,
            plan: _selectedPlan.toLowerCase(),
            fechaCreacion: now,
            fechaExpiracion: fechaFin,
          );
        } catch (e) {
          print('Error al asociar licencia al cliente: $e');
        }
      }
      
      // Enviar por WhatsApp
      if (_telefonoController.text.isNotEmpty) {
        await _enviarPorWhatsApp(_telefonoController.text, codigo, _selectedPlan);
      }
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Licencia creada: $codigo')),
        );
        
        // Recargar datos
        widget.onLicenciaCreada();
        
        // Volver a la pantalla anterior
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  void dispose() {
    _telefonoController.dispose();
    _androidIdController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Crear Licencia'),
        backgroundColor: AppTheme.colorCeleste,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Dropdown de cliente
            const Text('Cliente:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 8),
            DropdownButtonFormField<dynamic>(
              value: _selectedCliente,
              hint: const Text('Seleccionar cliente (opcional)'),
              isExpanded: true,
              items: [
                const DropdownMenuItem<dynamic>(
                  value: null,
                  child: Text('Sin cliente asociado'),
                ),
                ..._clientesActivos.map((cliente) => DropdownMenuItem<dynamic>(
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
                setState(() {
                  _selectedCliente = v;
                  // Auto-completar teléfono si se selecciona cliente
                  if (v != null && v.telefono != null) {
                    _telefonoController.text = v.telefono;
                  }
                });
              },
            ),
            
            const SizedBox(height: 24),
            
            // Tipo de Licencia
            const Text('Tipo de Licencia:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              value: _selectedTipo,
              isExpanded: true,
              items: const [
                DropdownMenuItem(value: 'ADMIN', child: Text('Admin (Cliente)')),
                DropdownMenuItem(value: 'VENDEDOR', child: Text('Vendedor')),
              ],
              onChanged: (v) => setState(() => _selectedTipo = v!),
            ),
            
            const SizedBox(height: 24),
            
            // Plan - Sin overflow usando DropdownMenuItem con textoFlexible
            const Text('Plan:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade300),
                borderRadius: BorderRadius.circular(8),
              ),
            child: DropdownButton<String>(
              value: _selectedPlan,
              isExpanded: true,
              underline: const SizedBox(),
              items: _dbPlans.map((p) => DropdownMenuItem(
                value: p.nombre,
                child: Flexible(child: Text(p.precio == 0 ? '${p.nombre} - Gratis' : '${p.nombre} - \$${p.precio.toInt()} (${p.diasDuracion} días)')),
              )).toList(),
              onChanged: (v) => setState(() => _selectedPlan = v!),
            ),
            ),
            
            const SizedBox(height: 24),
            
        // Teléfono
        TextField(
          controller: _telefonoController,
          keyboardType: TextInputType.phone,
          decoration: const InputDecoration(
            labelText: 'WhatsApp del cliente',
            hintText: '+53 5XX XXXX XXX',
            border: OutlineInputBorder(),
          ),
        ),

        const SizedBox(height: 24),

        // Android ID del dispositivo del cliente
        TextField(
          controller: _androidIdController,
          decoration: const InputDecoration(
            labelText: 'ID de Dispositivo del Cliente',
            hintText: 'El cliente debe proporcionar su ID',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.phone_android, size: 20),
          ),
        ),

        const SizedBox(height: 24),
            
            // Resumen
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Resumen:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 8),
                  Text('Cliente: ${_selectedCliente?.nombre ?? "Sin asignar"}'),
                  const SizedBox(height: 4),
                  Text('Tipo: $_selectedTipo'),
                  const SizedBox(height: 4),
                  Text('Plan: $_selectedPlan'),
                  const SizedBox(height: 4),
                  Text('Precio: ${_getPrecio(_selectedPlan)}'),
                ],
              ),
            ),
            
            const SizedBox(height: 32),
            
            // Botones
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: const Text('Cancelar'),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _crearLicencia,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Text('Crear y Enviar'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ================================================================
// PANTALLA COMPLETA PARA AGREGAR CLIENTE (sin diálogos)
// ================================================================
class AgregarClienteScreen extends StatefulWidget {
  final VoidCallback onClienteGuardado;

  const AgregarClienteScreen({
    super.key,
    required this.onClienteGuardado,
  });

  @override
  State<AgregarClienteScreen> createState() => _AgregarClienteScreenState();
}

class _AgregarClienteScreenState extends State<AgregarClienteScreen> {
  final _nombreController = TextEditingController();
  final _telefonoController = TextEditingController();
  final _negocioController = TextEditingController();
  bool _isLoading = false;

  Future<void> _guardarCliente() async {
    if (_nombreController.text.isEmpty || _telefonoController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nombre y teléfono son obligatorios')),
      );
      return;
    }
    
    setState(() => _isLoading = true);
    
    try {
      // Guardar cliente en la base de datos
      final db = AppDatabase.instance;
      await db.addCliente(
        id: const Uuid().v4(),
        nombre: _nombreController.text,
        telefono: _telefonoController.text,
        negocio: _negocioController.text.isNotEmpty ? _negocioController.text : null,
      );
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Cliente guardado correctamente')),
        );
        
        // Recargar datos
        widget.onClienteGuardado();
        
        // Volver a la pantalla anterior
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  void dispose() {
    _nombreController.dispose();
    _telefonoController.dispose();
    _negocioController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Nuevo Cliente'),
        backgroundColor: AppTheme.colorCeleste,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _nombreController,
              decoration: const InputDecoration(
                labelText: 'Nombre *',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.person),
              ),
              textCapitalization: TextCapitalization.words,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _telefonoController,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: 'Teléfono WhatsApp *',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.phone),
                hintText: '+53 5XX XXXX XXX',
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _negocioController,
              decoration: const InputDecoration(
                labelText: 'Nombre del Negocio',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.store),
              ),
              textCapitalization: TextCapitalization.words,
            ),
            const SizedBox(height: 32),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: const Text('Cancelar'),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _guardarCliente,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Text('Guardar'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}