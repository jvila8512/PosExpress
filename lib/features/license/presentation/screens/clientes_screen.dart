import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:etecsa/config/theme/app_colors.dart';
import 'package:etecsa/core/database/app_database.dart';
import 'package:etecsa/features/license/presentation/screens/cliente_detail_screen.dart';
import 'package:uuid/uuid.dart';

class ClientesScreen extends ConsumerStatefulWidget {
  final bool embedded;
  const ClientesScreen({super.key, this.embedded = false});

  @override
  ConsumerState<ClientesScreen> createState() => _ClientesScreenState();
}

class _ClientesScreenState extends ConsumerState<ClientesScreen> {
  List<Cliente> _clientes = [];
  List<Cliente> _filteredClientes = [];
  bool _isLoading = true;
  String _searchQuery = '';
  bool _showInactive = false;
  final TextEditingController _searchController = TextEditingController();

  // Estado para modo embedded: cliente seleccionado (detalle inline)
  Cliente? _selectedCliente;

  @override
  void initState() {
    super.initState();
    _loadClientes();
  }

  Future<void> _loadClientes() async {
    setState(() => _isLoading = true);
    try {
      final db = AppDatabase.instance;
      if (_showInactive) {
        _clientes = await db.getInactiveClientes();
      } else {
        _clientes = await db.getActiveClientes();
      }
      _filterClientes();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al cargar clientes: $e')),
        );
      }
    }
    setState(() => _isLoading = false);
  }

  void _filterClientes() {
    if (_searchQuery.isEmpty) {
      _filteredClientes = List.from(_clientes);
    } else {
      _filteredClientes = _clientes.where((cliente) {
        final query = _searchQuery.toLowerCase();
        return cliente.nombre.toLowerCase().contains(query) ||
            cliente.telefono.toLowerCase().contains(query) ||
            (cliente.negocio?.toLowerCase().contains(query) ?? false) ||
            (cliente.email?.toLowerCase().contains(query) ?? false);
      }).toList();
    }
  }

  @override
  Widget build(BuildContext context) {
    final body = Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Buscar clientes...',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        _searchController.clear();
                        setState(() => _searchQuery = '');
                        _filterClientes();
                      },
                    )
                  : null,
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(15),
                borderSide: BorderSide.none,
              ),
            ),
            onChanged: (value) {
              setState(() => _searchQuery = value);
              _filterClientes();
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              FilterChip(
                label: const Text('Inactivos'),
                selected: _showInactive,
                onSelected: (v) {
                  setState(() => _showInactive = v);
                  _loadClientes();
                },
                selectedColor: Colors.orange.shade100,
                checkmarkColor: Colors.orange,
                labelStyle: TextStyle(
                  color: _showInactive ? Colors.orange.shade800 : Colors.grey.shade600,
                  fontWeight: _showInactive ? FontWeight.bold : FontWeight.normal,
                  fontSize: 12,
                ),
              ),
              const SizedBox(width: 8),
              if (!_showInactive)
                FilterChip(
                  label: const Text('Activos'),
                  selected: true,
                  onSelected: null,
                  selectedColor: Colors.green.shade100,
                  checkmarkColor: Colors.green,
                  labelStyle: TextStyle(
                    color: Colors.green.shade800,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              const Spacer(),
              Text(
                '${_filteredClientes.length}',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _filteredClientes.isEmpty
                  ? _buildEmptyState()
                  : _buildClientesList(),
        ),
      ],
    );

    if (widget.embedded) {
      // Si hay cliente seleccionado, mostrar detalle inline
      if (_selectedCliente != null) {
        return ClienteDetailScreen(
          cliente: _selectedCliente!,
          embedded: true,
          onBack: _deselectCliente,
          onResult: (result) {
            if (result == 'edit') {
              _showClienteDialog(cliente: _selectedCliente!);
            } else if (result == 'reactivated' || result == 'inactivated') {
              _deselectCliente();
            }
          },
        );
      }
      return Stack(
        children: [
          body,
          Positioned(
            bottom: 16,
            right: 16,
            child: FloatingActionButton(
              onPressed: () => _showClienteDialog(),
              backgroundColor: AppColors.accent,
              child: const Icon(Icons.add, color: Colors.white),
            ),
          ),
        ],
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Clientes'),
        backgroundColor: AppColors.accent,
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/licenses'),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadClientes,
          ),
        ],
      ),
      body: body,
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showClienteDialog(),
        backgroundColor: AppColors.accent,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            _showInactive ? Icons.person_off_outlined : Icons.people_outline,
            size: 80,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 16),
          Text(
            _searchQuery.isEmpty
                ? (_showInactive ? 'No hay clientes inactivos' : 'No hay clientes registrados')
                : 'No se encontraron resultados',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey.shade600,
            ),
          ),
          if (_searchQuery.isEmpty && !_showInactive) ...[
            const SizedBox(height: 8),
            Text(
              'Toca + para agregar un cliente',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade500,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildClientesList() {
    return RefreshIndicator(
      onRefresh: _loadClientes,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: _filteredClientes.length,
        itemBuilder: (context, index) {
          final cliente = _filteredClientes[index];
          return _buildClienteCard(cliente);
        },
      ),
    );
  }

  Widget _buildClienteCard(Cliente cliente) {
    final isInactive = !cliente.active;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: isInactive
            ? BorderSide(color: Colors.orange.shade200, width: 1)
            : BorderSide.none,
      ),
      child: InkWell(
        onTap: () => _showClienteDetails(cliente),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: isInactive
                      ? Colors.orange.shade100
                      : AppColors.accent.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(25),
                ),
                child: Center(
                  child: Text(
                    cliente.nombre.isNotEmpty ? cliente.nombre[0].toUpperCase() : '?',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: isInactive ? Colors.orange.shade700 : AppColors.accent,
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
                            cliente.nombre,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: isInactive ? Colors.grey : null,
                            ),
                          ),
                        ),
                        if (isInactive)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.orange.shade50,
                              borderRadius: BorderRadius.circular(4),
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
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.phone, size: 14, color: Colors.grey),
                        const SizedBox(width: 4),
                        Text(
                          cliente.telefono,
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                    if (cliente.negocio != null && cliente.negocio!.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(Icons.store, size: 14, color: Colors.grey),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              cliente.negocio!,
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.grey.shade600,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              PopupMenuButton<String>(
                onSelected: (value) {
                  if (value == 'edit') {
                    _showClienteDialog(cliente: cliente);
                  } else if (value == 'licencias') {
                    _showClienteDetails(cliente);
                  } else if (value == 'delete') {
                    _confirmDeleteCliente(cliente);
                  } else if (value == 'reactivate') {
                    _reactivarCliente(cliente);
                  }
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: 'edit',
                    child: Row(
                      children: [
                        Icon(Icons.edit, size: 20),
                        SizedBox(width: 8),
                        Text('Editar'),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'licencias',
                    child: Row(
                      children: [
                        Icon(Icons.key, size: 20),
                        SizedBox(width: 8),
                        Text('Ver Licencias'),
                      ],
                    ),
                  ),
                  if (isInactive)
                    const PopupMenuItem(
                      value: 'reactivate',
                      child: Row(
                        children: [
                          Icon(Icons.check_circle, size: 20, color: Colors.green),
                          SizedBox(width: 8),
                          Text('Reactivar', style: TextStyle(color: Colors.green)),
                        ],
                      ),
                    )
                  else
                    const PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(Icons.delete, size: 20, color: Colors.red),
                          SizedBox(width: 8),
                          Text('Inactivar', style: TextStyle(color: Colors.red)),
                        ],
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

  void _reactivarCliente(Cliente cliente) async {
    final db = AppDatabase.instance;
    await db.reactivarCliente(cliente.id);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${cliente.nombre} reactivado'),
          backgroundColor: Colors.green,
        ),
      );
      _loadClientes();
    }
  }

  void _showClienteDialog({Cliente? cliente}) {
    final nombreController = TextEditingController(text: cliente?.nombre ?? '');
    final telefonoController = TextEditingController(text: cliente?.telefono ?? '');
    final negocioController = TextEditingController(text: cliente?.negocio ?? '');
    final emailController = TextEditingController(text: cliente?.email ?? '');
    final notasController = TextEditingController(text: cliente?.notas ?? '');

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(cliente == null ? 'Nuevo Cliente' : 'Editar Cliente'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nombreController,
                decoration: const InputDecoration(
                  labelText: 'Nombre *',
                  prefixIcon: Icon(Icons.person),
                ),
                textCapitalization: TextCapitalization.words,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: telefonoController,
                decoration: const InputDecoration(
                  labelText: 'Teléfono *',
                  prefixIcon: Icon(Icons.phone),
                  hintText: '+53 5XX XXXX XXX',
                ),
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: negocioController,
                decoration: const InputDecoration(
                  labelText: 'Nombre del Negocio',
                  prefixIcon: Icon(Icons.store),
                ),
                textCapitalization: TextCapitalization.words,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: emailController,
                decoration: const InputDecoration(
                  labelText: 'Email',
                  prefixIcon: Icon(Icons.email),
                ),
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: notasController,
                decoration: const InputDecoration(
                  labelText: 'Notas',
                  prefixIcon: Icon(Icons.note),
                ),
                maxLines: 2,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () async {
              if (nombreController.text.isEmpty || telefonoController.text.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Nombre y teléfono son obligatorios')),
                );
                return;
              }

              final db = AppDatabase.instance;
              try {
                if (cliente == null) {
                  await db.addCliente(
                    id: const Uuid().v4(),
                    nombre: nombreController.text,
                    telefono: telefonoController.text,
                    negocio: negocioController.text.isNotEmpty ? negocioController.text : null,
                    email: emailController.text.isNotEmpty ? emailController.text : null,
                    notas: notasController.text.isNotEmpty ? notasController.text : null,
                  );
                } else {
                  await db.updateCliente(
                    id: cliente.id,
                    nombre: nombreController.text,
                    telefono: telefonoController.text,
                    negocio: negocioController.text.isNotEmpty ? negocioController.text : null,
                    email: emailController.text.isNotEmpty ? emailController.text : null,
                    notas: notasController.text.isNotEmpty ? notasController.text : null,
                  );
                }

                if (mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(cliente == null
                          ? 'Cliente creado correctamente'
                          : 'Cliente actualizado correctamente'),
                    ),
                  );
                  _loadClientes();
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error: $e')),
                  );
                }
              }
            },
            child: Text(cliente == null ? 'Crear' : 'Guardar'),
          ),
        ],
      ),
    );
  }

  Future<void> _showClienteDetails(Cliente cliente) async {
    if (widget.embedded) {
      // Modo embedded: mostrar detalle inline (sin Navigator.push)
      setState(() => _selectedCliente = cliente);
      return;
    }

    // Modo standalone: push normal
    final result = await Navigator.push<String>(
      context,
      MaterialPageRoute(
        builder: (context) => ClienteDetailScreen(
          cliente: cliente,
        ),
      ),
    );

    if (result == 'edit' && mounted) {
      _showClienteDialog(cliente: cliente);
    } else if (result == 'reactivated' || result == 'inactivated') {
      _loadClientes();
    }
  }

  void _deselectCliente() {
    setState(() => _selectedCliente = null);
    _loadClientes(); // Refrescar lista al volver
  }



  void _confirmDeleteCliente(Cliente cliente) async {
    final db = AppDatabase.instance;
    final licencias = await db.getLicenciasByCliente(cliente.id);
    final licenciasActivas = licencias.where((l) => l.estado == 'activa').toList();

    if (!mounted) return;

    if (licenciasActivas.isNotEmpty) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('No se puede inactivar'),
          content: Text(
            '${cliente.nombre} tiene ${licenciasActivas.length} licencia${licenciasActivas.length > 1 ? "s" : ""} activa${licenciasActivas.length > 1 ? "s" : ""}.\n\nCancelá o dejá vencer las licencias antes de inactivar el cliente.',
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

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Inactivar Cliente'),
        content: Text('¿Inactivar a ${cliente.nombre}? Se ocultará de la lista de activos pero su historial se conservará.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () async {
              await db.deleteCliente(cliente.id);
              if (mounted) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Cliente inactivado')),
                );
                _loadClientes();
              }
            },
            style: FilledButton.styleFrom(backgroundColor: Colors.orange),
            child: const Text('Inactivar'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
}
