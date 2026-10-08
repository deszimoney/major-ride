import 'product.dart';

/// One line of the cart. Serialised into the `items` jsonb column on orders,
/// using the same keys the website writes.
class CartItem {
  CartItem({
    required this.id,
    required this.name,
    required this.price,
    required this.image,
    this.quantity = 1,
  });

  final String id;
  final String name;
  final double price;
  final String image;
  int quantity;

  double get lineTotal => price * quantity;

  factory CartItem.fromProduct(Product product) => CartItem(
    id: product.id,
    name: product.name,
    price: product.price,
    image: product.image,
  );

  factory CartItem.fromMap(Map<String, dynamic> map) => CartItem(
    id: '${map['id']}',
    name: (map['name'] ?? '') as String,
    price: double.tryParse('${map['price']}') ?? 0,
    image: (map['image'] ?? '') as String,
    quantity: int.tryParse('${map['quantity']}') ?? 1,
  );

  Map<String, dynamic> toMap() => {
    'id': id,
    'name': name,
    'price': price,
    'image': image,
    'quantity': quantity,
  };
}
