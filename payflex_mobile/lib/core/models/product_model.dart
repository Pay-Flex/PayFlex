class Product {
  final String id;
  final String name;
  final String category;
  final double price;
  final double dailyMin;
  final String imageUrl;
  final String description;
  final bool isFeatured;

  const Product({
    required this.id,
    required this.name,
    required this.category,
    required this.price,
    required this.dailyMin,
    required this.imageUrl,
    required this.description,
    this.isFeatured = false,
  });

  factory Product.fromMap(Map<String, dynamic> map) {
    return Product(
      id: map['id'] as String,
      name: map['name'] as String,
      category: map['category'] as String,
      price: (map['price'] as num).toDouble(),
      dailyMin: (map['daily_min'] as num).toDouble(),
      imageUrl: map['image_url'] as String,
      description: map['description'] as String,
      isFeatured: (map['is_featured'] as int) == 1,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'category': category,
      'price': price,
      'daily_min': dailyMin,
      'image_url': imageUrl,
      'description': description,
      'is_featured': isFeatured ? 1 : 0,
    };
  }

  String get formattedPrice {
    final p = price.toInt();
    if (p >= 1000000) {
      return '${(p / 1000000).toStringAsFixed(1).replaceAll('.0', '')} M FCFA';
    }
    // Format with dots as thousand separators
    final s = p.toString();
    final result = StringBuffer();
    for (int i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) result.write('.');
      result.write(s[i]);
    }
    return '${result.toString()} FCFA';
  }

  String get formattedDaily => '${dailyMin.toInt()} F/jour';
}
