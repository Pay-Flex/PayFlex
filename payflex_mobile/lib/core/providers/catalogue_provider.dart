import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../database/database_service.dart';
import '../models/product_model.dart';
import '../network/mobile_api_service.dart';

/// Libellés par défaut (mode hors ligne / secours).
const catalogueCategories = [
  'Tous',
  'Couture',
  'Coiffure',
  'Mécanique',
  'Menuiserie',
  'Maçonnerie',
  'Soudure',
  'Électricité bâtiment',
  'Plomberie',
  'Froid et climatisation',
];

class CatalogueState {
  final List<Product> products;
  final List<Product> filteredProducts;
  final String selectedCategory;
  final String searchQuery;
  final bool isLoading;
  final List<Product> cart;
  final List<Product> featuredProducts;
  final List<String> categoryFilterOptions;

  const CatalogueState({
    this.products = const [],
    this.filteredProducts = const [],
    this.selectedCategory = 'Tous',
    this.searchQuery = '',
    this.isLoading = false,
    this.cart = const [],
    this.featuredProducts = const [],
    this.categoryFilterOptions = catalogueCategories,
  });

  CatalogueState copyWith({
    List<Product>? products,
    List<Product>? filteredProducts,
    String? selectedCategory,
    String? searchQuery,
    bool? isLoading,
    List<Product>? cart,
    List<Product>? featuredProducts,
    List<String>? categoryFilterOptions,
  }) {
    return CatalogueState(
      products: products ?? this.products,
      filteredProducts: filteredProducts ?? this.filteredProducts,
      selectedCategory: selectedCategory ?? this.selectedCategory,
      searchQuery: searchQuery ?? this.searchQuery,
      isLoading: isLoading ?? this.isLoading,
      cart: cart ?? this.cart,
      featuredProducts: featuredProducts ?? this.featuredProducts,
      categoryFilterOptions: categoryFilterOptions ?? this.categoryFilterOptions,
    );
  }
}

class CatalogueNotifier extends Notifier<CatalogueState> {
  final _db = DatabaseService();
  final _api = MobileApiService();

  @override
  CatalogueState build() {
    Future.microtask(() => loadProducts(silent: false));
    return const CatalogueState(isLoading: true);
  }

  /// [silent]: pas d’overlay plein écran (actualisation tirée ou polling).
  Future<void> loadProducts({bool silent = false}) async {
    if (!silent) {
      state = state.copyWith(isLoading: true);
    }
    try {
      List<String> filterOptions = catalogueCategories;
      try {
        final cats = await _api.fetchProductCategories();
        if (cats.isNotEmpty) {
          final labels = cats
              .map((c) => (c['label'] ?? '').toString())
              .where((s) => s.isNotEmpty)
              .toList();
          if (labels.isNotEmpty) {
            filterOptions = ['Tous', ...labels];
          }
        }
      } catch (_) {}

      List<Map<String, dynamic>> maps = [];
      try {
        maps = await _api.fetchProducts();
      } catch (_) {
        maps = [];
      }
      if (maps.isEmpty) {
        maps = await _db.getCatalogueItems();
      }
      final products = maps.map((m) => Product.fromMap(m)).toList();

      final featuredProducts = products.where((p) => p.isFeatured).toList();

      var selected = state.selectedCategory;
      if (!filterOptions.contains(selected)) {
        selected = 'Tous';
      }

      state = state.copyWith(
        products: products,
        featuredProducts: featuredProducts,
        categoryFilterOptions: filterOptions,
        selectedCategory: selected,
        isLoading: false,
      );
      _applyFilters();
    } catch (e) {
      state = state.copyWith(isLoading: false);
    }
  }

  void filterByCategory(String category) {
    state = state.copyWith(selectedCategory: category);
    _applyFilters();
  }

  void search(String query) {
    state = state.copyWith(searchQuery: query);
    _applyFilters();
  }

  void _applyFilters() {
    var filtered = state.products;

    if (state.selectedCategory != 'Tous') {
      filtered = filtered.where((p) => p.category == state.selectedCategory).toList();
    }

    if (state.searchQuery.isNotEmpty) {
      final q = state.searchQuery.toLowerCase();
      filtered = filtered.where((p) =>
          p.name.toLowerCase().contains(q) ||
          p.category.toLowerCase().contains(q)).toList();
    }

    state = state.copyWith(filteredProducts: filtered);
  }

  void addToCart(Product product) {
    if (!state.cart.any((p) => p.id == product.id)) {
      state = state.copyWith(cart: [...state.cart, product]);
    }
  }

  void removeFromCart(String productId) {
    state = state.copyWith(
      cart: state.cart.where((p) => p.id != productId).toList(),
    );
  }

  bool isInCart(String productId) => state.cart.any((p) => p.id == productId);
}

final catalogueProvider = NotifierProvider<CatalogueNotifier, CatalogueState>(
  CatalogueNotifier.new,
);
