import 'product_model.dart';

/// Ligne panier avec quantité (spec PDF module 5).
class CartLineItem {
  final Product product;
  final int quantity;

  const CartLineItem({required this.product, this.quantity = 1});

  double get lineTotal => product.price * quantity;

  String get formattedLineTotal =>
      '${lineTotal.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]} ')} FCFA';

  CartLineItem copyWith({int? quantity}) =>
      CartLineItem(product: product, quantity: quantity ?? this.quantity);
}
