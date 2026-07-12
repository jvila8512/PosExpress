import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'dart:io';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:etecsa/core/database/app_database.dart';
import 'package:etecsa/core/database/database_provider.dart';

final productsProvider = NotifierProvider<ProductsNotifier, ProductsState>(ProductsNotifier.new);

class ProductsNotifier extends Notifier<ProductsState> {
  AppDatabase? _db;
  List<Product> _allProducts = [];

  AppDatabase get _database => _db ?? AppDatabase.instance;

  @override
  ProductsState build() {
    _db = ref.read(databaseProvider);
    Future.microtask(() => loadProducts());
    return ProductsState();
  }

  // Cargar todos los productos (para administración en vista de productos)
  // El filtro por isActive=true se aplica solo en el POS
  Future<void> loadProducts() async {
    state = state.copyWith(isLoading: true);
    try {
      final products = await (_database.select(_database.products)
            ..where((p) => p.isDeleted.equals(false))
            ..orderBy([(p) => OrderingTerm.asc(p.name)]))
          .get();
      
      final archived = await (_database.select(_database.products)
            ..where((p) => p.isDeleted.equals(true))
            ..orderBy([(p) => OrderingTerm.asc(p.name)]))
          .get();
      
      state = state.copyWith(products: products, archivedProducts: archived, isLoading: false);
      _allProducts = products;
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: 'Error al cargar');
    }
  }

  // Verificar límite de productos según plan de licencia
  Future<Map<String, dynamic>> canAddProduct() async {
    try {
      const secureStorage = FlutterSecureStorage();
      final planStr = await secureStorage.read(key: 'license_plan') ?? 'free';
      final plan = await _database.getPlanByName(planStr.toUpperCase());

      if (plan == null) {
        // Si no hay plan, permitir (fallback)
        return {'allowed': true, 'message': ''};
      }

      final currentCount = state.products.where((p) => !p.isDeleted).length;
      final maxProducts = plan.maxProductos; // plan is non-null after check above

      if (currentCount >= maxProducts) {
        return {
          'allowed': false,
          'message': 'Límite alcanzado: $currentCount/${maxProducts} productos. Actualizá tu plan para agregar más.',
        };
      }

      return {'allowed': true, 'message': '', 'current': currentCount, 'max': maxProducts};
    } catch (e) {
      debugPrint('Error checking product limit: $e');
      return {'allowed': true, 'message': ''};
    }
  }

  Future<void> addProduct({
    required String name,
    required String code,
    required double unitPrice,
    String? idOverride,
    double costPrice = 0,
    String? description,
    String? categoryId,
  }) async {
    // Validar límite de productos según licencia
    final canAdd = await canAddProduct();
    if (!canAdd['allowed']) {
      state = state.copyWith(isLoading: false, errorMessage: canAdd['message']);
      return;
    }

    state = state.copyWith(isLoading: true);
    try {
      await _database.into(_database.products).insert(
        ProductsCompanion.insert(
          id: idOverride ?? const Uuid().v4(),
          code: Value(code.isEmpty ? null : code),
          name: name,
          description: Value(description?.isEmpty ?? true ? null : description),
          categoryId: Value(categoryId),
          unitPrice: unitPrice,
          costPrice: Value(costPrice),
        ),
      );
      await loadProducts();
      // ignore: avoid_types_on_executable_parameters
    } catch (e, st) {
      debugPrint('Error adding product: $e $st');
      state = state.copyWith(isLoading: false, errorMessage: 'Error al agregar: $e');
    }
  }

  Future<void> updateProduct({
    required String id,
    required String name,
    required String code,
    required double unitPrice,
    double costPrice = 0,
    String? description,
    String? categoryId,
  }) async {
    state = state.copyWith(isLoading: true);
    try {
      await (_database.update(_database.products)..where((p) => p.id.equals(id))).write(
        ProductsCompanion(
          name: Value(name),
          code: Value(code.isEmpty ? null : code),
          description: Value(description?.isEmpty ?? true ? null : description),
          categoryId: Value(categoryId),
          unitPrice: Value(unitPrice),
          costPrice: Value(costPrice),
        ),
      );
      await loadProducts();
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: 'Error al actualizar');
    }
  }

  Future<void> deleteProduct(String id) async {
    state = state.copyWith(isLoading: true);
    try {
      await (_database.update(_database.products)..where((p) => p.id.equals(id))).write(
        const ProductsCompanion(isDeleted: Value(true)),
      );
      await loadProducts();
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: 'Error al archivar');
    }
  }

  // Restaurar producto archivado
  Future<void> restoreProduct(String id) async {
    state = state.copyWith(isLoading: true);
    try {
      await (_database.update(_database.products)..where((p) => p.id.equals(id))).write(
        const ProductsCompanion(isDeleted: Value(false)),
      );
      await loadProducts();
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: 'Error al restaurar');
    }
  }

  // Eliminación definitiva (para productos archivados)
  Future<void> permanentlyDeleteProduct(String id) async {
    state = state.copyWith(isLoading: true);
    try {
      await (_database.delete(_database.products)..where((p) => p.id.equals(id))).go();
      await loadProducts();
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: 'Error al eliminar');
    }
  }

  // Activar/desactivar producto para POS (licencias)
  Future<void> toggleActive(String id, bool isActive) async {
    try {
      await (_database.update(_database.products)..where((p) => p.id.equals(id))).write(
        ProductsCompanion(isActive: Value(isActive)),
      );
      await loadProducts();
    } catch (e) {
      state = state.copyWith(errorMessage: 'Error al actualizar');
    }
  }

  void searchProducts(String query) {
    if (query.trim().isEmpty) {
      state = state.copyWith(products: _allProducts);
      return;
    }

    final q = query.trim().toLowerCase();
    final filtered = _allProducts.where((p) =>
      p.name.toLowerCase().contains(q) ||
      (p.code?.toLowerCase().contains(q) ?? false)
    ).toList();

    state = state.copyWith(products: filtered);
  }

  // Limpiar error del state
  void clearError() {
    state = state.copyWith(errorMessage: null);
  }

  // Guardar imagen del producto en carpeta local
  static Future<String?> saveProductImage(File imageFile, String productId, String productName) async {
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final imagesDir = Directory(p.join(appDir.path, 'product_images'));
      
      if (!await imagesDir.exists()) {
        await imagesDir.create(recursive: true);
      }
      
      final extension = p.extension(imageFile.path);
      // Nombre: nombre_producto_timestamp_idúnico
      final cleanName = productName.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_').toLowerCase();
      final uniqueId = DateTime.now().millisecondsSinceEpoch;
      final newFileName = '${cleanName}_${uniqueId}$extension';
      final newPath = p.join(imagesDir.path, newFileName);
      
      await imageFile.copy(newPath);
      return newPath;
    } catch (e) {
      debugPrint('Error saving image: $e');
      return null;
    }
  }

  // Eliminar imagen del producto
  static Future<void> deleteProductImage(String? imageUrl) async {
    if (imageUrl == null) return;
    try {
      final file = File(imageUrl);
      if (await file.exists()) {
        await file.delete();
      }
    } catch (e) {
      debugPrint('Error deleting image: $e');
    }
  }
}

class ProductsState {
  final List<Product> products;
  final List<Product> archivedProducts;
  final bool isLoading;
  final String? errorMessage;

  const ProductsState({
    this.products = const [],
    this.archivedProducts = const [],
    this.isLoading = false,
    this.errorMessage,
  });

  ProductsState copyWith({
    List<Product>? products,
    List<Product>? archivedProducts,
    bool? isLoading,
    String? errorMessage,
  }) {
    return ProductsState(
      products: products ?? this.products,
      archivedProducts: archivedProducts ?? this.archivedProducts,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
    );
  }
}