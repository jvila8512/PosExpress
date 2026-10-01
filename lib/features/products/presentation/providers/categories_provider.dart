import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:etecsa/core/database/app_database.dart';
import 'package:etecsa/core/database/database_provider.dart';

final categoriesProvider = NotifierProvider<CategoriesNotifier, CategoriesState>(CategoriesNotifier.new);

class CategoriesNotifier extends Notifier<CategoriesState> {
  AppDatabase? _db;

  AppDatabase get _database => _db ?? AppDatabase.instance;

  @override
  CategoriesState build() {
    _db = ref.read(databaseProvider);
    Future.microtask(() => loadCategories());
    return CategoriesState();
  }

  Future<void> loadCategories() async {
    state = state.copyWith(isLoading: true);
    try {
      final categories = await _database.getAllCategories();
      state = state.copyWith(categories: categories, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: 'Error al cargar');
    }
  }

  Future<void> addCategory({
    required String name,
    String? description,
    String? color,
    String? icon,
  }) async {
    state = state.copyWith(isLoading: true);
    try {
      await _database.addCategory(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        name: name,
        description: description,
        color: color,
        icon: icon,
      );
      await loadCategories();
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: 'Error al agregar');
    }
  }

  Future<void> updateCategory({
    required String id,
    required String name,
    String? description,
    String? color,
    String? icon,
  }) async {
    state = state.copyWith(isLoading: true);
    try {
      await _database.updateCategory(
        id: id,
        name: name,
        description: description,
        color: color,
        icon: icon,
      );
      await loadCategories();
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: 'Error al actualizar');
    }
  }

  Future<void> deleteCategory(String id) async {
    state = state.copyWith(isLoading: true);
    try {
      await _database.deleteCategory(id);
      await loadCategories();
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: 'Error al eliminar');
    }
  }
}

class CategoriesState {
  final List<Category> categories;
  final bool isLoading;
  final String? errorMessage;

  const CategoriesState({
    this.categories = const [],
    this.isLoading = false,
    this.errorMessage,
  });

  CategoriesState copyWith({
    List<Category>? categories,
    bool? isLoading,
    String? errorMessage,
  }) {
    return CategoriesState(
      categories: categories ?? this.categories,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
    );
  }
}
