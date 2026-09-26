/// Параметры поиска, фильтрации и сортировки каталога.
class ShoeFilter {
  final String query;
  final String? category;
  final String? gender;
  final Set<String> brands;
  final int? minPrice;
  final int? maxPrice;
  final String? size;
  final bool inStockOnly;
  final bool saleOnly;
  final String sort;

  const ShoeFilter({
    this.query = '',
    this.category,
    this.gender,
    this.brands = const {},
    this.minPrice,
    this.maxPrice,
    this.size,
    this.inStockOnly = false,
    this.saleOnly = false,
    this.sort = 'default',
  });

  static const Map<String, String> sortLabels = {
    'default': 'По умолчанию',
    'new': 'Сначала новые',
    'price_asc': 'Сначала дешёвые',
    'price_desc': 'Сначала дорогие',
    'rating': 'По рейтингу',
    'name': 'По названию',
  };

  /// Количество активных фильтров (для бейджа на кнопке).
  int get activeCount =>
      (category != null ? 1 : 0) +
      (gender != null ? 1 : 0) +
      (brands.isNotEmpty ? 1 : 0) +
      (minPrice != null || maxPrice != null ? 1 : 0) +
      (size != null ? 1 : 0) +
      (inStockOnly ? 1 : 0) +
      (saleOnly ? 1 : 0);

  Map<String, String> toQuery() => {
    if (query.trim().isNotEmpty) 'q': query.trim(),
    'category': ?category,
    'gender': ?gender,
    if (brands.isNotEmpty) 'brands': brands.join(','),
    if (minPrice != null) 'min_price': '$minPrice',
    if (maxPrice != null) 'max_price': '$maxPrice',
    'size': ?size,
    if (inStockOnly) 'in_stock': '1',
    if (saleOnly) 'sale': '1',
    if (sort != 'default') 'sort': sort,
  };

  ShoeFilter copyWith({
    String? query,
    String? Function()? category,
    String? Function()? gender,
    Set<String>? brands,
    int? Function()? minPrice,
    int? Function()? maxPrice,
    String? Function()? size,
    bool? inStockOnly,
    bool? saleOnly,
    String? sort,
  }) => ShoeFilter(
    query: query ?? this.query,
    category: category != null ? category() : this.category,
    gender: gender != null ? gender() : this.gender,
    brands: brands ?? this.brands,
    minPrice: minPrice != null ? minPrice() : this.minPrice,
    maxPrice: maxPrice != null ? maxPrice() : this.maxPrice,
    size: size != null ? size() : this.size,
    inStockOnly: inStockOnly ?? this.inStockOnly,
    saleOnly: saleOnly ?? this.saleOnly,
    sort: sort ?? this.sort,
  );

  /// Сбрасывает фильтры, сохраняя строку поиска и сортировку.
  ShoeFilter cleared() => ShoeFilter(query: query, sort: sort);
}
