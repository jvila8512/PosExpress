import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:etecsa/features/products/presentation/providers/products_provider.dart';
import 'package:etecsa/features/products/presentation/providers/categories_provider.dart';
import 'package:etecsa/features/products/presentation/screens/product_form_screen.dart';
import 'package:etecsa/features/shared/widgets/side_menu.dart';
import 'package:etecsa/config/theme/app_theme.dart';
import 'package:etecsa/core/database/app_database.dart' show Product;
import 'package:etecsa/core/services/export_service.dart';
import 'package:etecsa/features/shared/widgets/export_options_dialog.dart';

class ProductsScreen extends ConsumerStatefulWidget {
  const ProductsScreen({super.key});

  @override
  ConsumerState<ProductsScreen> createState() => _ProductsScreenState();
}

class _ProductsScreenState extends ConsumerState<ProductsScreen> {
  final _searchController = TextEditingController();
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  bool _isSearching = false;
  bool _showArchived = false;

  @override
  Widget build(BuildContext context) {
    final products = ref.watch(productsProvider);
    final colors = Theme.of(context).colorScheme;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) context.go('/');
      },
      child: Scaffold(
      key: _scaffoldKey,
      drawer: SideMenu(scaffoldKey: _scaffoldKey),
      appBar: AppBar(
        title: _isSearching
          ? TextField(
              controller: _searchController,
              autofocus: true,
              decoration: InputDecoration(
                hintText: 'Buscar productos...',
                border: InputBorder.none,
                hintStyle: TextStyle(color: Colors.white70),
                filled: true,
                fillColor: Colors.white24,
              ),
              style: TextStyle(color: Colors.white, fontSize: 16),
              cursorColor: Colors.white,
              onChanged: (value) {
                ref.read(productsProvider.notifier).searchProducts(value);
              },
            )
          : const Text('Productos'),
      actions: [
        PopupMenuButton<String>(
          icon: const Icon(Icons.download, size: 22),
          tooltip: 'Exportar',
      onSelected: (value) async {
        try {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Exportando...'), duration: Duration(seconds: 1)),
          );
          final filePath = value == 'excel'
              ? await ExportService.instance.exportProductsExcel()
              : await ExportService.instance.exportProductsPdf();
          if (mounted) {
            ExportOptionsDialog.show(context, filePath: filePath, shareText: 'Lista de Productos');
          }
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Error: $e')),
            );
          }
        }
      },
          itemBuilder: (_) => [
            const PopupMenuItem(value: 'excel', child: Row(children: [Icon(Icons.table_chart, size: 20), SizedBox(width: 8), Text('Excel (.xlsx)')])),
            const PopupMenuItem(value: 'pdf', child: Row(children: [Icon(Icons.picture_as_pdf, size: 20), SizedBox(width: 8), Text('PDF')])),
          ],
        ),
        IconButton(
            icon: Icon(_showArchived ? Icons.inventory_2 : Icons.archive_outlined),
            tooltip: _showArchived ? 'Ver activos' : 'Ver archivados',
            onPressed: () {
              setState(() => _showArchived = !_showArchived);
            },
          ),
          IconButton(
            icon: Icon(_isSearching ? Icons.close : Icons.search),
            onPressed: () {
              setState(() {
                _isSearching = !_isSearching;
                if (!_isSearching) {
                  _searchController.clear();
                  ref.read(productsProvider.notifier).loadProducts();
                }
              });
            },
          ),
        ],
      ),
      body: products.isLoading
          ? const Center(child: CircularProgressIndicator())
          : (_showArchived 
              ? (products.archivedProducts.isEmpty 
                  ? _buildEmptyState('No hay productos archivados')
                  : _buildProductsList(products.archivedProducts, isArchived: true))
              : (products.products.isEmpty 
                  ? _buildEmptyState()
                  : _buildProductsList(products.products))),
      floatingActionButton: _showArchived 
          ? null 
          : FloatingActionButton.extended(
              onPressed: () => context.push('/products/new'),
              icon: const Icon(Icons.add),
              label: const Text('Nuevo'),
              backgroundColor: AppTheme.colorMorado,
            ),
    ),
    );
  }

  Widget _buildEmptyState([String message = 'No hay productos']) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            _showArchived ? Icons.archive_outlined : Icons.inventory_2_outlined,
            size: 80,
            color: Colors.grey.shade300,
          ),
          const SizedBox(height: 16),
          Text(
            'No hay productos',
            style: TextStyle(
              fontSize: 20,
              color: Colors.grey.shade500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Agrega tu primer producto',
            style: TextStyle(color: Colors.grey.shade400),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () => context.push('/products/new'),
            icon: const Icon(Icons.add),
            label: const Text('Agregar producto'),
          ),
        ],
      ),
    );
  }

  Widget _buildProductsList(List<Product> products, {bool isArchived = false}) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: products.length,
      itemBuilder: (context, index) {
        final product = products[index];
        return _buildProductCard(product, isArchived: isArchived);
      },
    );
  }

  Widget _buildProductCard(Product product, {bool isArchived = false}) {
    final isInactive = !product.isActive;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      color: isArchived 
          ? Colors.orange.shade50 
          : (isInactive ? Colors.red.shade50 : null),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: AppTheme.colorCeleste.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Center(
            child: Text(
              product.name.isNotEmpty ? product.name[0].toUpperCase() : 'P',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppTheme.colorCeleste,
              ),
            ),
          ),
        ),
        title: Text(
          product.name,
          style: TextStyle(
            fontWeight: FontWeight.bold, 
            fontSize: 14,
            color: isInactive ? Colors.red.shade300 : null,
          ),
        ),
        subtitle: Text(
          '\$${product.unitPrice.toStringAsFixed(2)}',
          style: TextStyle(
            color: isInactive ? Colors.red.shade300 : AppTheme.colorMorado,
            fontWeight: FontWeight.bold,
            fontSize: 13,
          ),
),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!isArchived) ...[
              Switch(
                value: product.isActive,
                activeColor: Colors.green,
                onChanged: (value) {
                  ref.read(productsProvider.notifier).toggleActive(product.id, value);
                },
              ),
            ],
            PopupMenuButton(
              icon: Icon(
                isArchived ? Icons.unarchive : Icons.more_vert,
                color: isArchived ? Colors.orange : null,
              ),
              itemBuilder: (context) => isArchived 
              ? [
                  PopupMenuItem(
                    value: 'restore',
                    child: Row(
                      children: [
                        Icon(Icons.unarchive, color: Colors.green),
                        SizedBox(width: 8),
                        Text('Restaurar', style: TextStyle(color: Colors.green)),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'delete',
                    child: Row(
                      children: [
                        Icon(Icons.delete_forever, color: Colors.red),
                        SizedBox(width: 8),
                        Text('Eliminar definitivo', style: TextStyle(color: Colors.red)),
                      ],
                    ),
                  ),
                ]
              : [
                  const PopupMenuItem(
                    value: 'edit',
                    child: Row(
                      children: [
                        Icon(Icons.edit),
                        SizedBox(width: 8),
                        Text('Editar'),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'toggle',
                    child: Row(
                      children: [
                        Icon(product.isActive ? Icons.visibility_off : Icons.visibility),
                        SizedBox(width: 8),
                        Text(product.isActive ? 'Desactivar' : 'Activar'),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'archive',
                    child: Row(
                      children: [
                        Icon(Icons.archive, color: Colors.orange),
                        SizedBox(width: 8),
                        Text('Archivar', style: TextStyle(color: Colors.orange)),
                      ],
                    ),
                  ),
                ],
          onSelected: (value) {
            if (value == 'edit') {
              context.push('/products/edit/${product.id}');
            } else if (value == 'archive') {
              _showArchiveConfirmation(product);
            } else if (value == 'restore') {
              ref.read(productsProvider.notifier).restoreProduct(product.id);
            } else if (value == 'delete') {
              _showDeleteConfirmation(product);
            } else if (value == 'toggle') {
              ref.read(productsProvider.notifier).toggleActive(product.id, !product.isActive);
            }
          },
        ),
          ],
        ),
        onTap: () => context.push('/products/edit/${product.id}'),
      ),
    );
  }

  void _showArchiveConfirmation(Product product) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Archivar Producto'),
        content: Text('¿Estás seguro de archivar "${product.name}"?\nPodrás recuperarlo después.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () {
              ref.read(productsProvider.notifier).deleteProduct(product.id);
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
            ),
            child: const Text('Archivar'),
          ),
        ],
      ),
    );
  }

  void _showDeleteConfirmation(Product product) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar Producto'),
        content: Text('¿Estás seguro de eliminar "${product.name}"?\nEsta acción no se puede deshacer.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () {
              // Si está archivado, eliminación definitiva; si no, soft delete
              if (product.isDeleted) {
                ref.read(productsProvider.notifier).permanentlyDeleteProduct(product.id);
              } else {
                ref.read(productsProvider.notifier).deleteProduct(product.id);
              }
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
  }
}