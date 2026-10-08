/// A row of `public.products`.
class Product {
  const Product({
    required this.id,
    required this.name,
    required this.category,
    required this.description,
    required this.price,
    required this.image,
  });

  final String id;
  final String name;
  final String category;
  final String description;
  final double price;
  final String image;

  /// database.js rewrites the retired "accessories" category on read; the app
  /// applies the same migration so old rows keep showing up under Backpacks.
  static String normalizeCategory(String? raw) {
    final value = (raw ?? '').trim();
    return value.toLowerCase() == 'accessories' ? 'Backpacks' : value;
  }

  factory Product.fromMap(Map<String, dynamic> map) => Product(
    id: map['id'] as String,
    name: (map['name'] ?? '') as String,
    category: normalizeCategory(map['category'] as String?),
    description: (map['description'] ?? '') as String,
    price: double.tryParse('${map['price']}') ?? 0,
    image: (map['image'] ?? '') as String,
  );

  Map<String, dynamic> toMap() => {
    'id': id,
    'name': name,
    'category': category,
    'description': description,
    'price': price,
    'image': image,
  };

  Product copyWith({
    String? name,
    String? category,
    String? description,
    double? price,
    String? image,
  }) => Product(
    id: id,
    name: name ?? this.name,
    category: category ?? this.category,
    description: description ?? this.description,
    price: price ?? this.price,
    image: image ?? this.image,
  );

  /// Backs the search box: matches name, category and description like shop.js.
  bool matches(String query) {
    if (query.isEmpty) return true;
    return '$name $category $description'.toLowerCase().contains(
      query.toLowerCase(),
    );
  }
}
