/// Модель спортивной обуви.
class Shoe {
  final int id;
  final String name;
  final String brand;
  final String category;
  final String gender;
  final int price;
  final int oldPrice;
  final String color;
  final List<String> sizes;
  final String material;
  final String surface;
  final int weight;
  final String description;
  final String imageUrl;
  final bool inStock;
  final bool deleted;
  final String? deletedAt;
  final double rating;
  final int reviewsCount;
  final bool isFavorite;

  const Shoe({
    required this.id,
    required this.name,
    required this.brand,
    required this.category,
    required this.gender,
    required this.price,
    this.oldPrice = 0,
    this.color = '',
    this.sizes = const [],
    this.material = '',
    this.surface = '',
    this.weight = 0,
    this.description = '',
    this.imageUrl = '',
    this.inStock = true,
    this.deleted = false,
    this.deletedAt,
    this.rating = 0,
    this.reviewsCount = 0,
    this.isFavorite = false,
  });

  /// Пустая модель для формы добавления.
  factory Shoe.empty() => const Shoe(id: 0, name: '', brand: '', category: 'running', gender: 'unisex', price: 0);

  bool get isNew => id == 0;
  bool get onSale => oldPrice > price;
  int get discountPercent => onSale ? ((oldPrice - price) * 100 / oldPrice).round() : 0;
  String get fullName => '$brand $name';

  factory Shoe.fromJson(Map<String, dynamic> j) => Shoe(
    id: j['id'] as int,
    name: j['name'] as String,
    brand: j['brand'] as String,
    category: j['category'] as String,
    gender: j['gender'] as String,
    price: j['price'] as int,
    oldPrice: (j['old_price'] ?? 0) as int,
    color: (j['color'] ?? '') as String,
    sizes: ((j['sizes'] ?? []) as List).map((e) => e.toString()).toList(),
    material: (j['material'] ?? '') as String,
    surface: (j['surface'] ?? '') as String,
    weight: (j['weight'] ?? 0) as int,
    description: (j['description'] ?? '') as String,
    imageUrl: (j['image_url'] ?? '') as String,
    inStock: (j['in_stock'] ?? true) as bool,
    deleted: (j['deleted'] ?? false) as bool,
    deletedAt: j['deleted_at'] as String?,
    rating: ((j['rating'] ?? 0) as num).toDouble(),
    reviewsCount: (j['reviews_count'] ?? 0) as int,
    isFavorite: (j['is_favorite'] ?? false) as bool,
  );

  /// Данные для создания/редактирования на сервере.
  Map<String, dynamic> toJson() => {
    'name': name,
    'brand': brand,
    'category': category,
    'gender': gender,
    'price': price,
    'old_price': oldPrice,
    'color': color,
    'sizes': sizes,
    'material': material,
    'surface': surface,
    'weight': weight,
    'description': description,
    'image_url': imageUrl,
    'in_stock': inStock,
  };

  Shoe copyWith({bool? isFavorite, double? rating, int? reviewsCount}) => Shoe(
    id: id,
    name: name,
    brand: brand,
    category: category,
    gender: gender,
    price: price,
    oldPrice: oldPrice,
    color: color,
    sizes: sizes,
    material: material,
    surface: surface,
    weight: weight,
    description: description,
    imageUrl: imageUrl,
    inStock: inStock,
    deleted: deleted,
    deletedAt: deletedAt,
    rating: rating ?? this.rating,
    reviewsCount: reviewsCount ?? this.reviewsCount,
    isFavorite: isFavorite ?? this.isFavorite,
  );
}

/// Страница результатов (для постраничной подгрузки).
class ShoePage {
  final List<Shoe> items;
  final int total;
  const ShoePage(this.items, this.total);
}

/// Справочные данные для фильтров.
class CatalogMeta {
  final List<String> brands;
  final List<String> sizes;
  final int minPrice;
  final int maxPrice;

  const CatalogMeta({required this.brands, required this.sizes, required this.minPrice, required this.maxPrice});

  factory CatalogMeta.fromJson(Map<String, dynamic> j) => CatalogMeta(
    brands: List<String>.from(j['brands'] as List),
    sizes: List<String>.from(j['sizes'] as List),
    minPrice: j['min_price'] as int,
    maxPrice: j['max_price'] as int,
  );
}
