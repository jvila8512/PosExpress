import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:etecsa/config/theme/app_colors.dart';
import 'package:etecsa/core/database/app_database.dart';

class PlanPricingScreen extends ConsumerStatefulWidget {
  final bool embedded;
  const PlanPricingScreen({super.key, this.embedded = false});

  @override
  ConsumerState<PlanPricingScreen> createState() => _PlanPricingScreenState();
}

class _PlanPricingScreenState extends ConsumerState<PlanPricingScreen> {
  List<LicensePlane> _planes = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadPlanes();
  }

  Future<void> _loadPlanes() async {
    setState(() => _isLoading = true);
    try {
      final db = AppDatabase.instance;
      _planes = await db.getAllLicensePlanesAdmin();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al cargar planes: $e')),
        );
      }
    }
    setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    final body = _isLoading
        ? const Center(child: CircularProgressIndicator())
        : _planes.isEmpty
            ? _buildEmptyState()
            : _buildPlanesList();

    if (widget.embedded) {
      return Stack(
        children: [
          body,
          Positioned(
            bottom: 16,
            right: 16,
            child: FloatingActionButton(
              onPressed: () => _showPlanDialog(),
              backgroundColor: AppColors.accent,
              child: const Icon(Icons.add, color: Colors.white),
            ),
          ),
        ],
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Planes de Precios'),
        backgroundColor: AppColors.accent,
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/licenses'),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadPlanes,
          ),
        ],
      ),
      body: body,
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showPlanDialog(),
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
            Icons.sell,
            size: 80,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 16),
          Text(
            'No hay planes configurados',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Toca + para agregar un plan',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlanesList() {
    return RefreshIndicator(
      onRefresh: _loadPlanes,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _planes.length,
        itemBuilder: (context, index) {
          final plan = _planes[index];
          return _buildPlanCard(plan);
        },
      ),
    );
  }

  Widget _buildPlanCard(LicensePlane plan) {
    Color planColor;
    IconData planIcon;
    
    switch (plan.nombre.toUpperCase()) {
      case 'FREE':
        planColor = Colors.grey;
        planIcon = Icons.sentiment_satisfied;
        break;
      case 'PRO':
        planColor = AppColors.accent;
        planIcon = Icons.star;
        break;
      case 'NEGOCIO':
        planColor = AppColors.accent;
        planIcon = Icons.business;
        break;
      case 'MAX':
        planColor = Colors.orange;
        planIcon = Icons.rocket_launch;
        break;
      case 'MAXPRO':
        planColor = Colors.deepPurple;
        planIcon = Icons.diamond;
        break;
      default:
        planColor = Colors.blue;
        planIcon = Icons.category;
    }

    return Opacity(
      opacity: plan.activa ? 1.0 : 0.6,
      child: Card(
        margin: const EdgeInsets.only(bottom: 16),
        elevation: plan.activa ? 4 : 1,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      child: Column(
        children: [
          // Header
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: planColor.withValues(alpha: 0.1),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: planColor.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(planIcon, color: planColor, size: 28),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        plan.nombre,
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: planColor,
                        ),
                      ),
                      if (plan.descripcion != null && plan.descripcion!.isNotEmpty)
                        Text(
                          plan.descripcion!,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                        ),
                    ],
                  ),
                ),
                // Status badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: plan.activa ? Colors.green : Colors.red,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    plan.activa ? 'Activo' : 'Inactivo',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Body
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                // Price and Duration
                Row(
                  children: [
                    Expanded(
                      child: _buildInfoItem(
                        Icons.attach_money,
                        'Precio',
                        '\$${plan.precio.toStringAsFixed(2)}',
                        planColor,
                      ),
                    ),
                    Expanded(
                      child: _buildInfoItem(
                        Icons.calendar_today,
                        'Duración',
                        '${plan.diasDuracion} días',
                        planColor,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                // Limits
                Row(
                  children: [
                    Expanded(
                      child: _buildInfoItem(
                        Icons.inventory_2,
                        'Productos',
                        plan.maxProductos > 10000 ? 'Ilimitado' : plan.maxProductos.toString(),
                        planColor,
                      ),
                    ),
                    Expanded(
                      child: _buildInfoItem(
                        Icons.people,
                        'Vendedores',
                        plan.maxVendedores > 50 ? 'Ilimitado' : plan.maxVendedores.toString(),
                        planColor,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
// Actions
      Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: () => _showPlanDialog(plan: plan),
              icon: const Icon(Icons.edit, size: 18),
              label: const Text('Editar'),
            ),
          ),
          const SizedBox(width: 12),
          plan.activa
              ? IconButton(
                  onPressed: () => _togglePlanActive(plan),
                  icon: const Icon(Icons.pause_circle_outline),
                  tooltip: 'Desactivar',
                  color: Colors.orange,
                  iconSize: 28,
                )
              : IconButton(
                  onPressed: () => _togglePlanActive(plan),
                  icon: const Icon(Icons.play_circle_outline),
                  tooltip: 'Activar',
                  color: Colors.green,
                  iconSize: 28,
                ),
        ],
      ),
      ],
    ),
    ),
    ],
    ),
    ),
    );
  }

  Widget _buildInfoItem(IconData icon, String label, String value, Color color) {
    return Row(
      children: [
        Icon(icon, size: 20, color: color),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade600,
              ),
            ),
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
      ],
    );
  }

  void _showPlanDialog({LicensePlane? plan}) {
    final nombreController = TextEditingController(text: plan?.nombre ?? '');
    final precioController = TextEditingController(
      text: plan?.precio.toString() ?? '',
    );
    final descripcionController = TextEditingController(text: plan?.descripcion ?? '');
    final diasController = TextEditingController(
      text: plan?.diasDuracion.toString() ?? '30',
    );
    final productosController = TextEditingController(
      text: plan?.maxProductos.toString() ?? '100',
    );
    final vendedoresController = TextEditingController(
      text: plan?.maxVendedores.toString() ?? '5',
    );

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(plan == null ? 'Nuevo Plan' : 'Editar Plan'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nombreController,
                decoration: const InputDecoration(
                  labelText: 'Nombre *',
                  prefixIcon: Icon(Icons.label),
                  hintText: 'FREE, PRO, NEGOCIO',
                ),
                textCapitalization: TextCapitalization.characters,
                enabled: plan == null, // Don't allow changing name for existing plans
              ),
              const SizedBox(height: 16),
              TextField(
                controller: precioController,
                decoration: const InputDecoration(
                  labelText: 'Precio *',
                  prefixIcon: Icon(Icons.attach_money),
                ),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: descripcionController,
                decoration: const InputDecoration(
                  labelText: 'Descripción',
                  prefixIcon: Icon(Icons.description),
                ),
                maxLines: 2,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: diasController,
                decoration: const InputDecoration(
                  labelText: 'Duración (días) *',
                  prefixIcon: Icon(Icons.calendar_today),
                ),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: productosController,
                decoration: const InputDecoration(
                  labelText: 'Máx. Productos *',
                  prefixIcon: Icon(Icons.inventory_2),
                ),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: vendedoresController,
                decoration: const InputDecoration(
                  labelText: 'Máx. Vendedores *',
                  prefixIcon: Icon(Icons.people),
                ),
                keyboardType: TextInputType.number,
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
              if (nombreController.text.isEmpty || precioController.text.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Nombre y precio son obligatorios')),
                );
                return;
              }

              final db = AppDatabase.instance;
              try {
                if (plan == null) {
                  // Crear nuevo plan
                  await db.createLicensePlan(
                    nombre: nombreController.text.toUpperCase(),
                    precio: double.tryParse(precioController.text) ?? 0,
                    descripcion: descripcionController.text.isNotEmpty 
                        ? descripcionController.text 
                        : null,
                    diasDuracion: int.tryParse(diasController.text) ?? 30,
                    maxProductos: int.tryParse(productosController.text) ?? 100,
                    maxVendedores: int.tryParse(vendedoresController.text) ?? 5,
                  );
                } else {
                  // Actualizar plan existente
                  await db.updateLicensePlan(
                    id: plan.id,
                    nombre: nombreController.text.toUpperCase(),
                    precio: double.tryParse(precioController.text),
                    descripcion: descripcionController.text.isNotEmpty 
                        ? descripcionController.text 
                        : null,
                    diasDuracion: int.tryParse(diasController.text),
                    maxProductos: int.tryParse(productosController.text),
                    maxVendedores: int.tryParse(vendedoresController.text),
                  );
                }

                if (mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(plan == null
                          ? 'Plan creado correctamente'
                          : 'Plan actualizado correctamente'),
                    ),
                  );
                  _loadPlanes();
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error: $e')),
                  );
                }
              }
            },
            child: Text(plan == null ? 'Crear' : 'Guardar'),
          ),
        ],
      ),
    );
  }

  void _togglePlanActive(LicensePlane plan) async {
    final db = AppDatabase.instance;
    try {
      await db.updateLicensePlan(
        id: plan.id,
        activa: !plan.activa,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(plan.activa
                ? 'Plan desactivado'
                : 'Plan activado'),
          ),
        );
        _loadPlanes();
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