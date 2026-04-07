import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../database/database_service.dart';
import '../models/product_model.dart';

// État du catalogue
class CatalogueState {
  final List<Product> products;
  final List<Product> filteredProducts;
  final String selectedCategory;
  final String searchQuery;
  final bool isLoading;
  final List<Product> cart;
  final Product? featuredProduct;

  const CatalogueState({
    this.products = const [],
    this.filteredProducts = const [],
    this.selectedCategory = 'Tous',
    this.searchQuery = '',
    this.isLoading = false,
    this.cart = const [],
    this.featuredProduct,
  });

  CatalogueState copyWith({
    List<Product>? products,
    List<Product>? filteredProducts,
    String? selectedCategory,
    String? searchQuery,
    bool? isLoading,
    List<Product>? cart,
    Product? featuredProduct,
  }) {
    return CatalogueState(
      products: products ?? this.products,
      filteredProducts: filteredProducts ?? this.filteredProducts,
      selectedCategory: selectedCategory ?? this.selectedCategory,
      searchQuery: searchQuery ?? this.searchQuery,
      isLoading: isLoading ?? this.isLoading,
      cart: cart ?? this.cart,
      featuredProduct: featuredProduct ?? this.featuredProduct,
    );
  }
}

class CatalogueNotifier extends Notifier<CatalogueState> {
  final _db = DatabaseService();

  @override
  CatalogueState build() {
    // Chargement automatique au démarrage
    Future.microtask(() => loadProducts());
    return const CatalogueState(isLoading: true);
  }

  Future<void> loadProducts() async {
    state = state.copyWith(isLoading: true);
    try {
      final maps = await _db.getCatalogueItems();
      final products = maps.map((m) => Product.fromMap(m)).toList();

      // Produit à la une
      final featuredMap = await _db.getFeaturedProduct();
      final featured = featuredMap != null ? Product.fromMap(featuredMap) : null;

      state = state.copyWith(
        products: products,
        filteredProducts: products,
        featuredProduct: featured,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false);
    }
  }

  // Filtre par catégorie
  void filterByCategory(String category) {
    state = state.copyWith(selectedCategory: category);
    _applyFilters();
  }

  // Recherche live
  void search(String query) {
    state = state.copyWith(searchQuery: query);
    _applyFilters();
  }

  void _applyFilters() {
    var filtered = state.products;

    // Filtre catégorie
    if (state.selectedCategory != 'Tous') {
      filtered = filtered.where((p) => p.category == state.selectedCategory).toList();
    }

    // Filtre recherche
    if (state.searchQuery.isNotEmpty) {
      final q = state.searchQuery.toLowerCase();
      filtered = filtered.where((p) =>
        p.name.toLowerCase().contains(q) ||
        p.category.toLowerCase().contains(q)
      ).toList();
    }

    state = state.copyWith(filteredProducts: filtered);
  }

  // Gestion Panier
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

// Provider principal du catalogue
final catalogueProvider = NotifierProvider<CatalogueNotifier, CatalogueState>(
  CatalogueNotifier.new,
);

// Catégories disponibles
const catalogueCategories = ['Tous', 'Mobilité', 'Électroménager', 'Informatique', 'Outillage', 'Électronique', 'Mobilier'];
