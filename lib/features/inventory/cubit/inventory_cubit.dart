import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:uuid/uuid.dart';

import '../../../core/data/shop_repository.dart';
import '../../../core/models/shop_models.dart';

class InventoryState extends Equatable {
  final bool loading;
  final List<Product> products;
  final List<Category> categories;
  final String query;

  const InventoryState({
    this.loading = false,
    this.products = const [],
    this.categories = const [],
    this.query = '',
  });

  InventoryState copyWith({
    bool? loading,
    List<Product>? products,
    List<Category>? categories,
    String? query,
  }) {
    return InventoryState(
      loading: loading ?? this.loading,
      products: products ?? this.products,
      categories: categories ?? this.categories,
      query: query ?? this.query,
    );
  }

  @override
  List<Object?> get props => [loading, products, categories, query];
}

class InventoryCubit extends Cubit<InventoryState> {
  InventoryCubit(this._repo) : super(const InventoryState());
  final ShopRepository _repo;
  final _uuid = const Uuid();

  Future<void> load() async {
    emit(state.copyWith(loading: true));
    final products = await _repo.getProducts(query: state.query);
    final categories = await _repo.getCategories();
    emit(state.copyWith(loading: false, products: products, categories: categories));
  }

  Future<void> setQuery(String q) async {
    emit(state.copyWith(query: q));
    await load();
  }

  Future<void> saveProduct({
    String? id,
    required String name,
    String barcode = '',
    String? categoryId,
    required double buyPrice,
    required double sellPrice,
    double quantity = 0,
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    if (id == null) {
      await _repo.upsertProduct(Product(
        id: _uuid.v4(),
        name: name,
        barcode: barcode,
        categoryId: categoryId,
        buyPrice: buyPrice,
        sellPrice: sellPrice,
        quantity: quantity,
        createdAt: now,
      ));
    } else {
      final existing =
          state.products.where((p) => p.id == id).toList(growable: false);
      final oldQty = existing.isEmpty ? quantity : existing.first.quantity;
      await _repo.upsertProduct(Product(
        id: id,
        name: name,
        barcode: barcode,
        categoryId: categoryId,
        buyPrice: buyPrice,
        sellPrice: sellPrice,
        quantity: oldQty,
        createdAt: now,
      ));
    }
    await load();
  }

  Future<void> adjustStock(String id, double delta) async {
    final p = state.products.firstWhere((e) => e.id == id);
    await _repo.upsertProduct(Product(
      id: p.id,
      name: p.name,
      barcode: p.barcode,
      categoryId: p.categoryId,
      buyPrice: p.buyPrice,
      sellPrice: p.sellPrice,
      quantity: (p.quantity + delta).clamp(0, 1e9).toDouble(),
      createdAt: p.createdAt,
    ));
    await load();
  }

  Future<void> deleteProduct(String id) async {
    await _repo.deleteProduct(id);
    await load();
  }

  Future<void> addCategory(String name) async {
    await _repo.addCategory(Category(id: _uuid.v4(), name: name));
    await load();
  }

  Future<void> deleteCategory(String id) async {
    await _repo.deleteCategory(id);
    await load();
  }
}
