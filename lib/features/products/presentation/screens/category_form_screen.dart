import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:etecsa/features/products/presentation/providers/categories_provider.dart';
import 'package:etecsa/config/theme/app_colors.dart';

class CategoryFormScreen extends ConsumerStatefulWidget {
  final String? categoryId;

  const CategoryFormScreen({super.key, this.categoryId});

  @override
  ConsumerState<CategoryFormScreen> createState() => _CategoryFormScreenState();
}

class _CategoryFormScreenState extends ConsumerState<CategoryFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descController = TextEditingController();
  bool _isLoading = false;
  bool _isInitialized = false;

  bool get isEditing => widget.categoryId != null;

  @override
  void initState() {
    super.initState();
    if (isEditing) _loadCategory();
  }

  void _loadCategory() {
    final categories = ref.read(categoriesProvider).categories;
    final category = categories.where((c) => c.id == widget.categoryId).firstOrNull;
    if (category != null) {
      _nameController.text = category.name;
      _descController.text = category.description ?? '';
      _isInitialized = true;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descController.dispose();
    super.dispose();
  }

  /// Validate no duplicate category name (case-insensitive)
  String? _validateName(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'El nombre es requerido';
    }
    final trimmed = value.trim().toLowerCase();
    final categories = ref.read(categoriesProvider).categories;
    final duplicate = categories.any((c) =>
        c.name.toLowerCase() == trimmed && c.id != widget.categoryId);
    if (duplicate) {
      return 'Ya existe una categoría con ese nombre';
    }
    return null;
  }

  Future<void> _saveCategory() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    final name = _nameController.text.trim();
    final desc = _descController.text.trim();

    try {
      if (isEditing) {
        await ref.read(categoriesProvider.notifier).updateCategory(
              id: widget.categoryId!,
              name: name,
              description: desc,
            );
      } else {
        await ref.read(categoriesProvider.notifier).addCategory(
              name: name,
              description: desc,
            );
      }

      if (mounted) context.pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al guardar: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? 'Editar Categoría' : 'Nueva Categoría'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Nombre *',
                prefixIcon: Icon(Icons.category),
                border: OutlineInputBorder(),
              ),
              validator: _validateName,
              textCapitalization: TextCapitalization.words,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _descController,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Descripción',
                prefixIcon: Icon(Icons.description),
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _isLoading ? null : _saveCategory,
        icon: _isLoading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
              )
            : const Icon(Icons.save),
        label: Text(_isLoading ? 'Guardando...' : 'Guardar'),
        backgroundColor: AppColors.accent,
        foregroundColor: Colors.white,
      ),
    );
  }
}
