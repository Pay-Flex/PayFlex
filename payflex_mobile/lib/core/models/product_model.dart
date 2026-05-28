import '../network/api_config.dart';

double _dailyMinFromMap(Map<String, dynamic> map) {
  final priceVal = map['price'];
  final price = priceVal is num ? priceVal.toDouble() : 0.0;
  final raw = map['daily_min'];
  double d;
  if (raw is num && raw.toDouble() > 0) {
    d = raw.toDouble();
  } else if (price > 0) {
    d = (price / 300).clamp(200.0, price);
  } else {
    d = 200.0;
  }
  if (price > 0 && d > price) d = price;
  return d < 1 ? 1.0 : d;
}

class Product {
  final String id;
  final String name;
  final String category;
  final double price;
  final double dailyMin;
  final String imageUrl;
  final String? imageDetail1Path;
  final String? imageDetail2Path;
  final String? imageDetail1Url;
  final String? imageDetail2Url;
  final String description;
  final bool isFeatured;

  const Product({
    required this.id,
    required this.name,
    required this.category,
    required this.price,
    required this.dailyMin,
    required this.imageUrl,
    this.imageDetail1Path,
    this.imageDetail2Path,
    this.imageDetail1Url,
    this.imageDetail2Url,
    required this.description,
    this.isFeatured = false,
  });

  factory Product.fromMap(Map<String, dynamic> map) {
    final rawId = map['id'];
    final idString = rawId == null ? '' : rawId.toString();
    final rawFeatured = map['is_featured'];
    String? trimStr(dynamic v) {
      final s = v?.toString().trim();
      return (s == null || s.isEmpty) ? null : s;
    }

    return Product(
      id: idString,
      name: (map['name'] ?? '').toString(),
      category: (map['category'] ?? '').toString(),
      price: (map['price'] as num).toDouble(),
      dailyMin: _dailyMinFromMap(map),
      imageUrl: (map['image_url'] ?? '').toString(),
      imageDetail1Path: trimStr(map['image_detail_1_path']),
      imageDetail2Path: trimStr(map['image_detail_2_path']),
      imageDetail1Url: trimStr(map['image_detail_1_url']),
      imageDetail2Url: trimStr(map['image_detail_2_url']),
      description: (map['description'] ?? '').toString(),
      isFeatured: rawFeatured is bool ? rawFeatured : (rawFeatured as num?)?.toInt() == 1,
    );
  }

  String get displayImageUrl => ApiConfig.resolveMediaUrl(imageUrl);

  String get displayDetail1Url =>
      ApiConfig.resolveMediaUrl(imageDetail1Url ?? imageDetail1Path);

  String get displayDetail2Url =>
      ApiConfig.resolveMediaUrl(imageDetail2Url ?? imageDetail2Path);

  /// Jusqu'à 3 images pour la fiche détail (couverture + galerie).
  List<String> get galleryUrls {
    final urls = <String>[];
    void add(String? raw) {
      final u = ApiConfig.resolveMediaUrl(raw);
      if (u.isNotEmpty && !urls.contains(u)) urls.add(u);
    }

    add(imageUrl);
    add(imageDetail1Url ?? imageDetail1Path);
    add(imageDetail2Url ?? imageDetail2Path);
    return urls;
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'category': category,
      'price': price,
      'daily_min': dailyMin,
      'image_url': imageUrl,
      'image_detail_1_path': imageDetail1Path,
      'image_detail_2_path': imageDetail2Path,
      'image_detail_1_url': imageDetail1Url,
      'image_detail_2_url': imageDetail2Url,
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
