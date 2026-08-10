import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:etecsa/features/products/presentation/providers/categories_provider.dart';
import 'package:etecsa/features/shared/widgets/side_menu.dart';
import 'package:etecsa/config/theme/app_colors.dart';
import 'package:etecsa/core/database/app_database.dart' show Category;

class CategoriesScreen extends ConsumerStatefulWidget {
  const CategoriesScreen({super.key});

  @override
  ConsumerState<CategoriesScreen> createState() => _CategoriesScreenState();
}

class _CategoriesScreenState extends ConsumerState<CategoriesScreen> {
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  final _searchController = TextEditingController();
  bool _isSearching = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final categories = ref.watch(categoriesProvider);
    final filteredCategories = _isSearching
        ? categories.categories
            .where((c) => c.name.toLowerCase().contains(_searchController.text.toLowerCase()))
            .toList()
        : categories.categories;

    return Scaffold(
      key: _scaffoldKey,
      drawer: SideMenu(scaffoldKey: _scaffoldKey),
      appBar: AppBar(
        title: _isSearching
            ? TextField(
                controller: _searchController,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: 'Buscar categorías...',
                  border: InputBorder.none,
                  hintStyle: TextStyle(color: Colors.white70),
                  filled: true,
                  fillColor: Colors.white24,
                ),
                style: TextStyle(color: Colors.white, fontSize: 16),
                cursorColor: Colors.white,
                onChanged: (_) => setState(() {}),
              )
            : const Text('Categorías'),
        leading: IconButton(
          icon: _isSearching ? const Icon(Icons.arrow_back) : const Icon(Icons.menu),
          onPressed: () {
            if (_isSearching) {
              setState(() {
                _isSearching = false;
                _searchController.clear();
              });
            } else {
              _scaffoldKey.currentState?.openDrawer();
            }
          },
        ),
        actions: [
          IconButton(
            icon: Icon(_isSearching ? Icons.close : Icons.search),
            onPressed: () {
              setState(() {
                _isSearching = !_isSearching;
                if (!_isSearching) {
                  _searchController.clear();
                }
              });
            },
          ),
        ],
      ),
      body: categories.isLoading
          ? const Center(child: CircularProgressIndicator())
          : filteredCategories.isEmpty
              ? _buildEmptyState(context, ref)
              : _buildCategoriesList(context, ref, filteredCategories),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/categories/new'),
        icon: const Icon(Icons.add),
        label: const Text('Nueva'),
        backgroundColor: AppColors.accent,
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, WidgetRef ref) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.category_outlined, size: 80, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          Text(
            _isSearching ? 'Sin resultados' : 'No hay categorías',
            style: TextStyle(fontSize: 20, color: Colors.grey.shade500),
          ),
          const SizedBox(height: 8),
          Text(
            _isSearching ? 'Intentá con otro nombre' : 'Crea categorías para organizar tus productos',
            style: TextStyle(color: Colors.grey.shade400),
          ),
          if (!_isSearching) ...[
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => context.push('/categories/new'),
              icon: const Icon(Icons.add),
              label: const Text('Agregar categoría'),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCategoriesList(BuildContext context, WidgetRef ref, List<Category> categories) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: categories.length,
      itemBuilder: (context, index) {
        final category = categories[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: AppColors.accent.withValues(alpha: 0.1),
              child: Icon(Icons.category, color: AppColors.accent),
            ),
            title: Text(category.name, style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: category.description != null ? Text(category.description!) : null,
            trailing: PopupMenuButton(
              itemBuilder: (context) => [
                const PopupMenuItem(value: 'edit', child: Row(children: [Icon(Icons.edit), SizedBox(width: 8), Text('Editar')])),
                const PopupMenuItem(value: 'delete', child: Row(children: [Icon(Icons.delete, color: Colors.red), SizedBox(width: 8), Text('Eliminar', style: TextStyle(color: Colors.red))])),
              ],
              onSelected: (value) {
                if (value == 'edit') {
                  context.push('/categories/edit/${category.id}');
                } else if (value == 'delete') {
                  _showDeleteConfirmation(context, ref, category);
                }
              },
            ),
            onTap: () => context.push('/categories/edit/${category.id}'),
          ),
        );
      },
    );
  }

  void _showDeleteConfirmation(BuildContext context, WidgetRef ref, Category category) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar Categoría'),
        content: Text('¿Estás seguro de eliminar "${category.name}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () {
              ref.read(categoriesProvider.notifier).deleteCategory(category.id);
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
  }
}
