import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:etecsa/features/products/presentation/providers/products_provider.dart';
import 'package:etecsa/features/products/presentation/providers/categories_provider.dart';
import 'package:etecsa/config/theme/app_theme.dart';
import 'package:etecsa/core/database/app_database.dart';

class ProductFormScreen extends ConsumerStatefulWidget {
  final String? productId;

  const ProductFormScreen({super.key, this.productId});

  @override
  ConsumerState<ProductFormScreen> createState() => _ProductFormScreenState();
}

class _ProductFormScreenState extends ConsumerState<ProductFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _codeController = TextEditingController();
  final _codigoCortoController = TextEditingController();
  final _priceController = TextEditingController();
  final _costController = TextEditingController();
  final _descController = TextEditingController();
  final _imagePicker = ImagePicker();
  String? _selectedCategoryId;
  String? _currentImageUrl;
  XFile? _newImageFile;
  bool _isLoading = false;
  Product? _product;
  bool _isInitialized = false;

  bool get isEditing => widget.productId != null;
  final List<Map<String, dynamic>> _wholesaleRules = [];

  /// Auto-generate codigoCorto from product name:
  /// First 3 uppercase consonants/letters of the name.
  String _generateCodigoCorto(String name) {
    if (name.trim().isEmpty) return '';
    final cleaned = name.trim().toUpperCase().replaceAll(RegExp(r'[^A-Z]'), '');
    if (cleaned.isEmpty) return '';
    // Take first 3 characters
    return cleaned.length >= 3 ? cleaned.substring(0, 3) : cleaned;
  }

  void _onNameChanged(String value) {
    // Only auto-generate if the user hasn't manually edited codigoCorto
    if (_codigoCortoController.text.isEmpty ||
        _codigoCortoController.text == _generateCodigoCorto(_nameController.text)) {
      _codigoCortoController.text = _generateCodigoCorto(value);
    }
    setState(() {});
  }

  /// Check if cost > sale price (warning, not blocking)
  bool get _costExceedsPrice {
    final cost = double.tryParse(_costController.text) ?? 0;
    final price = double.tryParse(_priceController.text) ?? 0;
    return cost > 0 && price > 0 && cost > price;
  }

  @override
  void initState() {
    super.initState();
    if (isEditing) _loadProduct();
  }

  Future<void> _loadProduct() async {
    final db = AppDatabase.instance;
    final product = await db.getProductById(widget.productId!);
    if (product != null && mounted) {
      // Obtener imageUrl del campo description (formato: IMG:ruta)
      String? imgUrl;
      try {
        final desc = product.description ?? '';
        if (desc.startsWith('IMG:')) {
          imgUrl = desc.substring(4);
        }
      } catch (_) {
        imgUrl = null;
      }
      setState(() {
        _product = product;
        _nameController.text = product.name;
        _codeController.text = product.code ?? '';
        _codigoCortoController.text = product.codigoCorto ?? '';
        _priceController.text = product.unitPrice.toString();
        _costController.text = product.costPrice.toString();
        _descController.text = product.description ?? '';
        _selectedCategoryId = product.categoryId;
        _currentImageUrl = imgUrl;
        _isInitialized = true;
      });
      // Cargar reglas de precio por mayor
      final rules = await db.getWholesaleRules(widget.productId!);
      if (mounted) {
        setState(() {
          _wholesaleRules.clear();
          for (final r in rules) {
            _wholesaleRules.add({
              'id': r['id'],
              'minQuantity': r['minQuantity'],
              'unitPrice': r['unitPrice'],
            });
          }
        });
      }
    }
  }

  Future<void> _pickImage() async {
    final XFile? image = await _imagePicker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 800,
      maxHeight: 800,
      imageQuality: 85,
    );
    if (image != null) {
      setState(() {
        _newImageFile = image;
        _currentImageUrl = null; // Limpiar imagen anterior
      });
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _codeController.dispose();
    _codigoCortoController.dispose();
    _priceController.dispose();
    _costController.dispose();
    _descController.dispose();
    super.dispose();
  }

  Future<void> _showAddWholesaleRuleDialog() async {
    final minQtyController = TextEditingController();
    final priceController = TextEditingController();
    final result = await showDialog<Map<String, double>>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Agregar regla'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: minQtyController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Cantidad mínima',
                hintText: 'ej: 24',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: priceController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(
                labelText: 'Precio unitario',
                hintText: 'ej: 800',
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
              final qty = double.tryParse(minQtyController.text);
              final price = double.tryParse(priceController.text);
              if (qty == null || qty <= 0 || price == null || price <= 0) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Ingrese valores válidos')),
                );
                return;
              }
              Navigator.pop(context, {'minQuantity': qty, 'unitPrice': price});
            },
            child: const Text('Agregar'),
          ),
        ],
      ),
    );
    if (result != null && mounted) {
      setState(() {
        _wholesaleRules.add(result);
        _wholesaleRules.sort(
          (a, b) =>
              (a['minQuantity'] as num).compareTo(b['minQuantity'] as num),
        );
      });
    }
  }

  Future<void> _saveProduct() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    final name = _nameController.text.trim();
    final code = _codeController.text.trim();
    final codigoCorto = _codigoCortoController.text.trim().toUpperCase();
    final price = double.tryParse(_priceController.text) ?? 0;
    final cost = double.tryParse(_costController.text) ?? 0;
    final desc = _descController.text.trim();

    try {
      String? imageUrl;

      // Guardar nueva imagen si se seleccionó
      if (_newImageFile != null) {
        final productId =
            widget.productId ??
            DateTime.now().millisecondsSinceEpoch.toString();
        imageUrl = await ProductsNotifier.saveProductImage(
          File(_newImageFile!.path),
          productId,
          name, // Pasar nombre del producto
        );
      }

      if (isEditing) {
        // Si hay nueva imagen, reemplaza; si no, usa la actual
        final finalImageUrl = imageUrl ?? _currentImageUrl;

        // Eliminar imagen anterior si se cambió
        if (_newImageFile != null && _currentImageUrl != null) {
          await ProductsNotifier.deleteProductImage(_currentImageUrl);
        }

        // Guardar ruta de imagen en description (como diseño intencional)
        final descParaGuardar = finalImageUrl != null
            ? 'IMG:$finalImageUrl'
            : '';

        await ref
            .read(productsProvider.notifier)
            .updateProduct(
              id: widget.productId!,
              name: name,
              code: code,
              codigoCorto: codigoCorto,
              unitPrice: price,
              costPrice: cost,
              description: descParaGuardar,
              categoryId: _selectedCategoryId,
            );
      } else {
        final productId =
            widget.productId ??
            DateTime.now().millisecondsSinceEpoch.toString();
        // Guardar ruta de imagen en description (como diseño intencional)
        final descParaGuardar = imageUrl != null ? 'IMG:$imageUrl' : '';

        await ref
            .read(productsProvider.notifier)
            .addProduct(
              idOverride: productId,
              name: name,
              code: code,
              codigoCorto: codigoCorto,
              unitPrice: price,
              costPrice: cost,
              description: descParaGuardar,
              categoryId: _selectedCategoryId,
            );

        // Verificar si el provider reportó error de límite
        final errorMsg = ref.read(productsProvider).errorMessage;
        if (errorMsg != null && errorMsg.isNotEmpty) {
          if (mounted) {
            setState(() => _isLoading = false);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(errorMsg),
                backgroundColor: Colors.red,
                duration: const Duration(seconds: 4),
              ),
            );
            // Limpiar el error del provider
            ref.read(productsProvider.notifier).clearError();
          }
          return;
        }
      }

      // Guardar reglas de precio por mayor
      final productId =
          widget.productId ?? DateTime.now().millisecondsSinceEpoch.toString();
      final db = AppDatabase.instance;
      await db.saveWholesaleRulesForProduct(productId, _wholesaleRules);

      // Mostrar mensaje de éxito (+ warning si costo > precio)
      if (mounted) {
        final snackBarMessages = <String>[];
        snackBarMessages.add(
          isEditing ? 'Producto actualizado' : 'Producto creado',
        );
        if (_costExceedsPrice) {
          snackBarMessages.add('⚠️ El costo supera el precio de venta');
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(snackBarMessages.join(' - ')),
            backgroundColor: _costExceedsPrice ? Colors.orange : Colors.green,
            duration: _costExceedsPrice
                ? const Duration(seconds: 4)
                : const Duration(seconds: 2),
          ),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final categories = ref.watch(categoriesProvider);

    if (isEditing && !_isInitialized) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? 'Editar Producto' : 'Nuevo Producto'),
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
            // Selector de imagen
            Center(
              child: GestureDetector(
                onTap: _pickImage,
                child: Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: _newImageFile != null
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.file(
                            File(_newImageFile!.path),
                            fit: BoxFit.cover,
                          ),
                        )
                      : _currentImageUrl != null
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.file(
                            File(_currentImageUrl!),
                            fit: BoxFit.cover,
                          ),
                        )
                      : Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.add_a_photo,
                              size: 32,
                              color: Colors.grey,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Agregar foto',
                              style: TextStyle(
                                color: Colors.grey.shade600,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Nombre *',
                prefixIcon: Icon(Icons.inventory_2),
                border: OutlineInputBorder(),
              ),
              onChanged: _onNameChanged,
              validator: (v) => v == null || v.trim().isEmpty
                  ? 'El nombre es requerido'
                  : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _codeController,
              decoration: const InputDecoration(
                labelText: 'Código',
                prefixIcon: Icon(Icons.qr_code),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _codigoCortoController,
              decoration: InputDecoration(
                labelText: 'Código Corto (SMS)',
                hintText: 'Ej: CLE, SCQ, LTE',
                prefixIcon: const Icon(Icons.short_text),
                border: const OutlineInputBorder(),
                helperText: 'Se genera automáticamente. Podés editarlo.',
                helperStyle: TextStyle(
                  fontSize: 11,
                  color: Colors.grey.shade500,
                ),
              ),
              textCapitalization: TextCapitalization.characters,
              maxLength: 5,
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: _selectedCategoryId,
              decoration: const InputDecoration(
                labelText: 'Categoría',
                prefixIcon: Icon(Icons.category),
                border: OutlineInputBorder(),
              ),
              items: [
                const DropdownMenuItem(
                  value: null,
                  child: Text('Sin categoría'),
                ),
                ...categories.categories.map(
                  (c) => DropdownMenuItem(value: c.id, child: Text(c.name)),
                ),
              ],
              onChanged: (v) => setState(() => _selectedCategoryId = v),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _costController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Precio de costo *',
                prefixIcon: Icon(Icons.price_check),
                border: OutlineInputBorder(),
              ),
              validator: (v) {
                if (v == null || v.isEmpty)
                  return 'El precio de costo es requerido';
                final c = double.tryParse(v);
                if (c == null || c < 0) return 'Costo inválido';
                return null;
              },
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _priceController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Precio de venta *',
                prefixIcon: Icon(Icons.attach_money),
                border: OutlineInputBorder(),
              ),
              validator: (v) {
                if (v == null || v.isEmpty)
                  return 'El precio de venta es requerido';
                final p = double.tryParse(v);
                if (p == null || p <= 0) return 'Precio inválido';
                return null;
              },
              onChanged: (_) => setState(() {}),
            ),
            // ── Precio por mayor ──
            const SizedBox(height: 20),
            const Divider(),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.groups, size: 18, color: AppTheme.colorCeleste),
                const SizedBox(width: 8),
                const Text(
                  'Precio por mayor',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              'Precios especiales según cantidad. El cliente que compre esta cantidad o más paga el precio indicado.',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 12),
            ..._wholesaleRules.asMap().entries.map((entry) {
              final i = entry.key;
              final rule = entry.value;
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        '≥ ${rule['minQuantity']} u. → \$${(rule['unitPrice'] as num).toStringAsFixed(2)} c/u',
                        style: const TextStyle(fontSize: 13),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(
                        Icons.delete,
                        size: 20,
                        color: Colors.red,
                      ),
                      onPressed: () =>
                          setState(() => _wholesaleRules.removeAt(i)),
                    ),
                  ],
                ),
              );
            }),
            OutlinedButton.icon(
              onPressed: _showAddWholesaleRuleDialog,
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Agregar regla'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppTheme.colorCeleste,
              ),
            ),
            const SizedBox(height: 16),

            // Warning: costo > precio de venta
            if (_costExceedsPrice) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.orange.shade300),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.warning_amber,
                      color: Colors.orange.shade700,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'El costo supera el precio de venta. Estás perdiendo dinero con este producto.',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.orange.shade800,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _isLoading ? null : _saveProduct,
        icon: _isLoading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : const Icon(Icons.save),
        label: Text(_isLoading ? 'Guardando...' : 'Guardar'),
        backgroundColor: AppTheme.colorMorado,
        foregroundColor: Colors.white,
      ),
    );
  }
}
