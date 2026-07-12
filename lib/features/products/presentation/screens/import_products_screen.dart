import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:go_router/go_router.dart';
import 'package:drift/drift.dart' hide Column;
import 'package:etecsa/config/theme/app_theme.dart';
import 'package:etecsa/core/database/app_database.dart';
import 'package:etecsa/features/shared/services/KeyValueStorageService.dart';
import 'package:etecsa/features/products/presentation/providers/products_provider.dart';
import 'package:etecsa/features/products/presentation/providers/categories_provider.dart';
import 'package:uuid/uuid.dart';

/// Pantalla para importar categorías y productos desde un archivo JSON.
/// Solo accesible por super_admin.
///
/// Formato del JSON:
/// {
///   "categorias": [
///     {
///       "nombre": "Bebidas",
///       "descripcion": "Bebidas frías y calientes",
///       "color": "#FF5722",
///       "icono": "local_cafe",
///       "productos": [
///         {
///           "nombre": "Café",
///           "codigo": "CAF001",
///           "precioVenta": 150.0,
///           "precioCosto": 80.0,
///           "stock": 50,           // <-- NUEVO: stock inicial (opcional, default 0)
///           "descripcion": "Café molido 500g"
///         }
///       ]
///     }
///   ]
/// }

class ImportProductsScreen extends ConsumerStatefulWidget {
  const ImportProductsScreen({super.key});

  @override
  ConsumerState<ImportProductsScreen> createState() => _ImportProductsScreenState();
}

class _ImportProductsScreenState extends ConsumerState<ImportProductsScreen> {
  bool _isLoading = false;
  bool _isPreview = false;
  String? _fileName;
  String? _errorMessage;
  List<_ImportCategory> _categories = [];
  int _totalProducts = 0;

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        if (_isLoading) return;
        if (context.canPop()) {
          context.pop();
        } else {
          context.go('/');
        }
      },
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: _isLoading
                ? null
                : () {
                    if (context.canPop()) {
                      context.pop();
                    } else {
                      context.go('/');
                    }
                  },
          ),
          title: const Text('Importar Productos'),
          backgroundColor: AppTheme.colorCeleste,
          foregroundColor: Colors.white,
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : Column(
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Instrucciones
                          _buildFormatInfo(),
                          const SizedBox(height: 20),

                          // Botón seleccionar archivo
                          if (!_isPreview) ...[
                            SizedBox(
                              width: double.infinity,
                              height: 56,
                              child: ElevatedButton.icon(
                                onPressed: _pickFile,
                                icon: const Icon(Icons.upload_file, size: 28),
                                label: const Text(
                                  'Seleccionar archivo JSON',
                                  style: TextStyle(fontSize: 16),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppTheme.colorCeleste,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                              ),
                            ),
                          ],

                          // Error
                          if (_errorMessage != null) ...[
                            const SizedBox(height: 16),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.red.shade50,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.red.shade200),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.error_outline,
                                    color: Colors.red.shade700,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      _errorMessage!,
                                      style: TextStyle(
                                        color: Colors.red.shade700,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],

                          // Preview
                          if (_isPreview) ...[
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                Icon(
                                  Icons.preview,
                                  color: AppTheme.colorCeleste,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Vista previa: $_fileName',
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.blue.shade50,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.blue.shade200),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '${_categories.length} categorías',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                  Text(
                                    '$_totalProducts productos',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                      color: Colors.green,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 16),

                            // Lista de categorías y productos
                            ..._categories.map(
                              (cat) => _buildCategoryPreview(cat),
                            ),

                            const SizedBox(height: 24),
                          ],
                        ],
                      ),
                    ),
                  ),

                  // Botones de acción siempre al fondo en preview
                  if (_isPreview)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.08),
                            blurRadius: 8,
                            offset: const Offset(0, -2),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: _reset,
                              icon: const Icon(Icons.close),
                              label: const Text('Cancelar'),
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 16,
                                ),
                                side: BorderSide(color: Colors.red.shade300),
                                foregroundColor: Colors.red,
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: _import,
                              icon: const Icon(Icons.cloud_upload),
                              label: const Text('Importar'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 16,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
      ),
    );
  }

  Widget _buildFormatInfo() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.info_outline, color: Colors.blue.shade700, size: 20),
              const SizedBox(width: 8),
              Text(
                'Instrucciones',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                  color: Colors.blue.shade800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _infoRow('El archivo JSON debe tener una lista de "categorías"'),
          _infoRow('Cada categoría contiene una lista de "productos"'),
          _infoRow('Campos obligatorios: nombre, precioVenta'),
          _infoRow(
            'Campos opcionales: codigo, precioCosto, stock, descripcion, color, icono',
          ),
          const SizedBox(height: 8),
          Text(
            'Stock inicial 0 si no se especifica. Categorías y productos duplicados se omiten.',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade600,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoRow(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.check_circle, size: 14, color: Colors.blue.shade400),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 13))),
        ],
      ),
    );
  }

  Widget _buildCategoryPreview(_ImportCategory cat) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ExpansionTile(
        leading: CircleAvatar(
          backgroundColor: AppTheme.colorCeleste.withValues(alpha: 0.1),
          child: Text(
            cat.name[0].toUpperCase(),
            style: TextStyle(
              color: AppTheme.colorCeleste,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        title: Text(
          cat.name,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text('${cat.products.length} productos'),
        children: cat.products
            .map(
              (p) => ListTile(
                dense: true,
                leading: const Icon(Icons.inventory_2_outlined, size: 18),
                title: Text(p.name),
                subtitle: Text(
                  'Venta: \$${p.salePrice.toStringAsFixed(0)} | Costo: \$${p.costPrice.toStringAsFixed(0)}',
                ),
                trailing: p.code != null
                    ? Text(
                        p.code!,
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey.shade500,
                        ),
                      )
                    : null,
              ),
            )
            .toList(),
      ),
    );
  }

  Future<void> _pickFile() async {
    setState(() {
      _errorMessage = null;
      _isLoading = true;
    });

    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
      );

      if (!mounted) return;

      if (result == null || result.files.isEmpty) {
        setState(() => _isLoading = false);
        return;
      }

      final file = File(result.files.first.path!);
      final content = await file.readAsString(encoding: utf8);
      if (!mounted) return;
      _fileName = result.files.first.name;

      // Parse JSON
      final decoded = jsonDecode(content);
      if (decoded is! Map<String, dynamic>) {
        _setError('El JSON debe ser un objeto con clave "categorias"');
        return;
      }

      final categoriasRaw = decoded['categorias'];
      if (categoriasRaw is! List) {
        _setError('La clave "categorias" debe ser una lista');
        return;
      }

      final categories = <_ImportCategory>[];
      int totalProducts = 0;

      for (int i = 0; i < categoriasRaw.length; i++) {
        final catMap = categoriasRaw[i] as Map<String, dynamic>;
        final catName = catMap['nombre']?.toString();
        if (catName == null || catName.isEmpty) {
          _setError('Categoría #${i + 1}: "nombre" es obligatorio');
          return;
        }

        final productsRaw = catMap['productos'] as List? ?? [];
        final products = <_ImportProduct>[];

        for (int j = 0; j < productsRaw.length; j++) {
          final pMap = productsRaw[j] as Map<String, dynamic>;
          final pName = pMap['nombre']?.toString();
          final pSalePrice = pMap['precioVenta'];

          if (pName == null || pName.isEmpty) {
            _setError(
              'Producto #${j + 1} en "$catName": "nombre" es obligatorio',
            );
            return;
          }
          if (pSalePrice == null) {
            _setError(
              'Producto "$pName" en "$catName": "precioVenta" es obligatorio',
            );
            return;
          }

          final rawStock = pMap['stock'];
          final stock = rawStock != null
              ? (rawStock is num
                    ? rawStock.toDouble()
                    : double.tryParse(rawStock.toString()) ?? 0.0)
              : 0.0;

          products.add(
            _ImportProduct(
              name: pName,
              code: pMap['codigo']?.toString(),
              salePrice: (pSalePrice is num)
                  ? pSalePrice.toDouble()
                  : double.tryParse(pSalePrice.toString()) ?? 0.0,
              costPrice: pMap['precioCosto'] != null
                  ? (pMap['precioCosto'] is num
                        ? (pMap['precioCosto'] as num).toDouble()
                        : double.tryParse(pMap['precioCosto'].toString()) ??
                              0.0)
                  : 0.0,
              stock: stock,
              description: pMap['descripcion']?.toString(),
            ),
          );
        }

        categories.add(
          _ImportCategory(
            name: catName,
            description: catMap['descripcion']?.toString(),
            color: catMap['color']?.toString(),
            icon: catMap['icono']?.toString(),
            products: products,
          ),
        );
        totalProducts += products.length;
      }

      if (!mounted) return;
      setState(() {
        _categories = categories;
        _totalProducts = totalProducts;
        _isPreview = true;
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) _setError('Error al leer archivo: $e');
    }
  }

  void _setError(String message) {
    setState(() {
      _errorMessage = message;
      _isLoading = false;
      _isPreview = false;
    });
  }

  void _reset() {
    setState(() {
      _isPreview = false;
      _categories = [];
      _totalProducts = 0;
      _fileName = null;
      _errorMessage = null;
    });
  }

  Future<void> _import() async {
    setState(() => _isLoading = true);

    try {
      final db = AppDatabase.instance;
      final storage = KeyValueStorageService();
      final warehouseMode = await storage.getValue('warehouse_mode_enabled') == 'true';
      int categoriesCreated = 0;
      int productsCreated = 0;
      int categoriesSkipped = 0;
      int productsSkipped = 0;

      for (final cat in _categories) {
        if (!mounted) return;
        // Check if category already exists (case-insensitive)
        final existingCats = await db.getAllCategories();
        final existing = existingCats
            .where((c) => c.name.toLowerCase() == cat.name.toLowerCase())
            .firstOrNull;

        String categoryId;
        if (existing != null) {
          categoryId = existing.id;
          categoriesSkipped++;
        } else {
          categoryId = const Uuid().v4();
          await db.addCategory(
            id: categoryId,
            name: cat.name,
            description: cat.description,
            color: cat.color,
            icon: cat.icon,
          );
          categoriesCreated++;
        }

        // Insert products
        for (final p in cat.products) {
          if (!mounted) return;
          // Check for duplicate product name in this category
          final existingProducts =
              await (db.select(db.products)..where(
                    (pr) =>
                        pr.name.equals(p.name) &
                        pr.categoryId.equals(categoryId),
                  ))
                  .get();

          if (existingProducts.isNotEmpty) {
            productsSkipped++;
            continue;
          }

          final productId = const Uuid().v4();
          await db
              .into(db.products)
              .insert(
                ProductsCompanion.insert(
                  id: productId,
                  name: p.name,
                  code: p.code != null && p.code!.isNotEmpty
                      ? Value(p.code)
                      : Value(null),
                  unitPrice: p.salePrice,
                  costPrice: Value(p.costPrice),
                  description: Value(p.description),
                  categoryId: Value(categoryId),
                ),
              );
          productsCreated++;

          // Crear lote de inventario si tiene stock > 0
          if (p.stock > 0) {
            await db.addInventoryLot(
              productId: productId,
              quantity: p.stock,
              costPerUnit: p.costPrice,
              purchaseDate: DateTime.now(),
              supplier: 'Importación',
              reference: 'IMP-${DateTime.now().millisecondsSinceEpoch}',
              location: warehouseMode ? 'almacen' : 'pv',
            );
          }
        }
      }

      if (!mounted) return;

      // Mostrar diálogo sobre el loading (sin resetear estado aún)
      await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          icon: const Icon(Icons.check_circle, color: Colors.green, size: 48),
          title: const Text('Importación completa'),
          content: Text(
            'Categorías: $categoriesCreated creadas, $categoriesSkipped existentes\n'
            'Productos: $productsCreated creados, $productsSkipped duplicados omitidos',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Aceptar'),
            ),
          ],
        ),
      );

      // Resetear estado y navegar al home
      if (mounted) {
        // Invalidar providers para que recarguen los datos nuevos
        ref.invalidate(productsProvider);
        ref.invalidate(categoriesProvider);
        setState(() {
          _isLoading = false;
          _isPreview = false;
          _categories = [];
          _totalProducts = 0;
          _fileName = null;
        });
        context.go('/');
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }
}

class _ImportCategory {
  final String name;
  final String? description;
  final String? color;
  final String? icon;
  final List<_ImportProduct> products;

  _ImportCategory({
    required this.name,
    this.description,
    this.color,
    this.icon,
    required this.products,
  });
}

class _ImportProduct {
  final String name;
  final String? code;
  final double salePrice;
  final double costPrice;
  final double stock;
  final String? description;

  _ImportProduct({
    required this.name,
    this.code,
    required this.salePrice,
    required this.costPrice,
    this.stock = 0,
    this.description,
  });
}
