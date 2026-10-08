import 'cart_item.dart';

enum DeliveryMethod {
  delivery('delivery', 'Delivery'),
  pickup('pickup', 'Pickup');

  const DeliveryMethod(this.value, this.label);

  final String value;
  final String label;

  static DeliveryMethod parse(String? raw) => raw == 'pickup' ? pickup : delivery;
}

/// A row of `public.orders`. Field names stay camelCase in Dart and are mapped
/// to the snake_case columns in [toMap] / [fromMap].
class ShopOrder {
  const ShopOrder({
    required this.id,
    required this.userId,
    required this.userName,
    required this.userEmail,
    required this.items,
    required this.subtotal,
    required this.serviceFee,
    required this.total,
    required this.paidAt,
    this.paymentStatus = 'completed',
    this.paymentProvider = 'paystack',
    this.paymentReference,
    this.deliveryMethod = DeliveryMethod.delivery,
    this.deliveryLocation = '',
    this.deliveryConfirmed = false,
    this.deliveredAt,
  });

  final String id;
  final String userId;
  final String userName;
  final String userEmail;
  final List<CartItem> items;
  final double subtotal;
  final double serviceFee;
  final double total;
  final DateTime paidAt;
  final String paymentStatus;
  final String paymentProvider;
  final String? paymentReference;
  final DeliveryMethod deliveryMethod;
  final String deliveryLocation;
  final bool deliveryConfirmed;
  final DateTime? deliveredAt;

  /// Short label the website shows: the last six characters of the id.
  String get shortId =>
      id.length <= 6 ? id : id.substring(id.length - 6);

  int get itemCount => items.fold(0, (sum, item) => sum + item.quantity);

  factory ShopOrder.fromMap(Map<String, dynamic> map) {
    final rawItems = map['items'];
    return ShopOrder(
      id: map['id'] as String,
      userId: (map['user_id'] ?? '') as String,
      userName: (map['user_name'] ?? '') as String,
      userEmail: (map['user_email'] ?? '') as String,
      items: rawItems is List
          ? rawItems
                .whereType<Map>()
                .map((item) => CartItem.fromMap(item.cast<String, dynamic>()))
                .toList()
          : const [],
      subtotal: double.tryParse('${map['subtotal']}') ?? 0,
      serviceFee: double.tryParse('${map['service_fee']}') ?? 0,
      total: double.tryParse('${map['total']}') ?? 0,
      paidAt: DateTime.tryParse('${map['paid_at']}')?.toLocal() ?? DateTime.now(),
      paymentStatus: (map['payment_status'] ?? 'completed') as String,
      paymentProvider: (map['payment_provider'] ?? 'paystack') as String,
      paymentReference: map['payment_reference'] as String?,
      deliveryMethod: DeliveryMethod.parse(map['delivery_method'] as String?),
      deliveryLocation: (map['delivery_location'] ?? '') as String,
      deliveryConfirmed: map['delivery_confirmed'] == true,
      deliveredAt: DateTime.tryParse('${map['delivered_at']}')?.toLocal(),
    );
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'user_id': userId,
    'user_name': userName,
    'user_email': userEmail,
    'items': items.map((item) => item.toMap()).toList(),
    'subtotal': subtotal,
    'service_fee': serviceFee,
    'total': total,
    'payment_status': paymentStatus,
    'payment_provider': paymentProvider,
    'payment_reference': paymentReference,
    'paid_at': paidAt.toUtc().toIso8601String(),
    'delivery_method': deliveryMethod.value,
    'delivery_location': deliveryLocation,
    'delivery_confirmed': deliveryConfirmed,
    'delivered_at': deliveredAt?.toUtc().toIso8601String(),
  };

  ShopOrder copyWith({bool? deliveryConfirmed, DateTime? deliveredAt}) =>
      ShopOrder(
        id: id,
        userId: userId,
        userName: userName,
        userEmail: userEmail,
        items: items,
        subtotal: subtotal,
        serviceFee: serviceFee,
        total: total,
        paidAt: paidAt,
        paymentStatus: paymentStatus,
        paymentProvider: paymentProvider,
        paymentReference: paymentReference,
        deliveryMethod: deliveryMethod,
        deliveryLocation: deliveryLocation,
        deliveryConfirmed: deliveryConfirmed ?? this.deliveryConfirmed,
        deliveredAt: deliveryConfirmed == false ? null : (deliveredAt ?? this.deliveredAt),
      );
}

/// Mirrors the `mrco_cart_activity` feed the admin dashboard reads.
class CartActivity {
  const CartActivity({
    required this.id,
    required this.productName,
    required this.quantity,
    required this.userName,
    required this.userEmail,
    required this.addedAt,
  });

  final String id;
  final String productName;
  final int quantity;
  final String userName;
  final String userEmail;
  final DateTime addedAt;

  factory CartActivity.fromMap(Map<String, dynamic> map) => CartActivity(
    id: '${map['id']}',
    productName: (map['productName'] ?? '') as String,
    quantity: int.tryParse('${map['quantity']}') ?? 1,
    userName: (map['userName'] ?? '') as String,
    userEmail: (map['userEmail'] ?? '') as String,
    addedAt: DateTime.tryParse('${map['addedAt']}')?.toLocal() ?? DateTime.now(),
  );

  Map<String, dynamic> toMap() => {
    'id': id,
    'productName': productName,
    'quantity': quantity,
    'userName': userName,
    'userEmail': userEmail,
    'addedAt': addedAt.toUtc().toIso8601String(),
  };
}
