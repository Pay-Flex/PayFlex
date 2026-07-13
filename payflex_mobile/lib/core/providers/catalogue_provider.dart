import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../database/database_service.dart';
import '../models/cart_line_item.dart';
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
  final List<CartLineItem> cart;
  final List<Product> featuredProducts;
  final List<String> categoryFilterOptions;

  /// `true` lorsque les articles affichés proviennent du cache local (SQLite)
  /// parce que le serveur PayFlex était injoignable.
  final bool isOffline;

  const CatalogueState({
    this.products = const [],
    this.filteredProducts = const [],
    this.selectedCategory = 'Tous',
    this.searchQuery = '',
    this.isLoading = false,
    this.cart = const [],
    this.featuredProducts = const [],
    this.categoryFilterOptions = catalogueCategories,
    this.isOffline = false,
  });

  double get cartTotal => cart.fold(0.0, (s, l) => s + l.lineTotal);

  int get cartItemCount => cart.fold(0, (s, l) => s + l.quantity);

  CatalogueState copyWith({
    List<Product>? products,
    List<Product>? filteredProducts,
    String? selectedCategory,
    String? searchQuery,
    bool? isLoading,
    List<CartLineItem>? cart,
    List<Product>? featuredProducts,
    List<String>? categoryFilterOptions,
    bool? isOffline,
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
      isOffline: isOffline ?? this.isOffline,
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
      var reachedServer = false;
      try {
        maps = await _api.fetchProducts();
        reachedServer = true;
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
        // Hors ligne uniquement si le serveur n'a pas répondu ET qu'on affiche
        // malgré tout des articles issus du cache local.
        isOffline: !reachedServer && products.isNotEmpty,
      );
      _applyFilters();
      await restoreCartFromStorage();
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

  void addToCart(Product product, {int quantity = 1}) {
    final q = quantity < 1 ? 1 : quantity;
    final idx = state.cart.indexWhere((l) => l.product.id == product.id);
    if (idx >= 0) {
      final updated = [...state.cart];
      updated[idx] = updated[idx].copyWith(quantity: updated[idx].quantity + q);
      state = state.copyWith(cart: updated);
    } else {
      state = state.copyWith(cart: [...state.cart, CartLineItem(product: product, quantity: q)]);
    }
    _persistCart();
  }

  void setCartQuantity(String productId, int quantity) {
    if (quantity <= 0) {
      removeFromCart(productId);
      return;
    }
    state = state.copyWith(
      cart: state.cart
          .map((l) => l.product.id == productId ? l.copyWith(quantity: quantity) : l)
          .toList(),
    );
    _persistCart();
  }

  void removeFromCart(String productId) {
    state = state.copyWith(
      cart: state.cart.where((l) => l.product.id != productId).toList(),
    );
    _persistCart();
  }

  void clearCart() {
    state = state.copyWith(cart: []);
    _persistCart();
  }

  bool isInCart(String productId) => state.cart.any((l) => l.product.id == productId);

  Future<void> _persistCart() async {
    try {
      await _db.saveCartLines(state.cart.map((l) => {
            'id': l.product.id,
            'quantity': l.quantity,
          }).toList());
    } catch (_) {}
  }

  Future<void> restoreCartFromStorage() async {
    try {
      final rows = await _db.loadCartLines();
      if (rows.isEmpty) return;
      final restored = <CartLineItem>[];
      for (final row in rows) {
        final id = row['id']?.toString();
        final qty = (row['quantity'] as num?)?.toInt() ?? 1;
        if (id == null) continue;
        try {
          final p = state.products.firstWhere((x) => x.id == id);
          restored.add(CartLineItem(product: p, quantity: qty));
        } catch (_) {}
      }
      if (restored.isNotEmpty) {
        state = state.copyWith(cart: restored);
      }
    } catch (_) {}
  }
}

final catalogueProvider = NotifierProvider<CatalogueNotifier, CatalogueState>(
  CatalogueNotifier.new,
);
