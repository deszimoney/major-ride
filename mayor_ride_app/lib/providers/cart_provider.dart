import 'package:flutter/foundation.dart';

import '../config/app_config.dart';
import '../models/app_user.dart';
import '../models/cart_item.dart';
import '../models/product.dart';
import '../models/shop_order.dart';
import '../services/local_store.dart';
import '../services/order_repository.dart';

/// Ports cart.js: the in-memory/localStorage cart, delivery-method fee
/// switch, and the checkout hand-off that produces a [ShopOrder].
class CartProvider extends ChangeNotifier {
  CartProvider(this._store, this._orders) {
    _items = _store
        .readList(LocalStore.cart)
        .map(CartItem.fromMap)
        .toList();
  }

  final LocalStore _store;
  final OrderRepository _orders;

  List<CartItem> _items = [];
  DeliveryMethod _deliveryMethod = DeliveryMethod.delivery;
  String _deliveryLocation = '';

  List<CartItem> get items => List.unmodifiable(_items);
  DeliveryMethod get deliveryMethod => _deliveryMethod;
  String get deliveryLocation => _deliveryLocation;

  int get itemCount =>
      _items.fold(0, (total, item) => total + item.quantity);

  double get subtotal =>
      _items.fold(0, (total, item) => total + item.lineTotal);

  double get serviceFee => _deliveryMethod == DeliveryMethod.pickup
      ? AppConfig.pickupFee
      : AppConfig.deliveryFee;

  double get grandTotal => _items.isEmpty ? 0 : subtotal + serviceFee;

  bool get isEmpty => _items.isEmpty;

  /// Delivery requires a location; pickup does not — same rule cart.js applies
  /// both before opening the Paystack popup and before saving the order.
  bool get needsDeliveryLocation =>
      _deliveryMethod == DeliveryMethod.delivery &&
      _deliveryLocation.trim().isEmpty;

  void setDeliveryMethod(DeliveryMethod method) {
    _deliveryMethod = method;
    notifyListeners();
  }

  void setDeliveryLocation(String value) {
    _deliveryLocation = value;
    notifyListeners();
  }

  Future<void> _persist() => _store.writeList(LocalStore.cart, [
    for (final item in _items) item.toMap(),
  ]);

  Future<void> add(Product product, {AppUser? actor}) async {
    final index = _items.indexWhere((item) => item.id == product.id);
    int newQuantity;
    if (index >= 0) {
      _items[index].quantity += 1;
      newQuantity = _items[index].quantity;
    } else {
      _items.add(CartItem.fromProduct(product));
      newQuantity = 1;
    }

    if (actor != null) {
      await _orders.recordActivity(
        CartActivity(
          id: 'cart-${DateTime.now().millisecondsSinceEpoch}',
          productName: product.name,
          quantity: newQuantity,
          userName: actor.name,
          userEmail: actor.email,
          addedAt: DateTime.now(),
        ),
      );
    }

    notifyListeners();
    await _persist();
  }

  Future<void> increase(String itemId) async {
    final item = _items.where((entry) => entry.id == itemId).firstOrNull;
    if (item == null) return;
    item.quantity += 1;
    notifyListeners();
    await _persist();
  }

  Future<void> decrease(String itemId) async {
    final item = _items.where((entry) => entry.id == itemId).firstOrNull;
    if (item == null) return;
    item.quantity -= 1;
    if (item.quantity <= 0) {
      _items.removeWhere((entry) => entry.id == itemId);
    }
    notifyListeners();
    await _persist();
  }

  Future<void> remove(String itemId) async {
    _items.removeWhere((entry) => entry.id == itemId);
    notifyListeners();
    await _persist();
  }

  Future<void> clear() async {
    _items = [];
    notifyListeners();
    await _persist();
  }

  /// Builds the order row that will be written once payment succeeds.
  ShopOrder buildOrder({required AppUser user, required String reference}) =>
      ShopOrder(
        id: 'order-${DateTime.now().millisecondsSinceEpoch}',
        userId: user.id,
        userName: user.name,
        userEmail: user.email,
        items: _items.map((item) => item).toList(),
        subtotal: subtotal,
        serviceFee: serviceFee,
        total: grandTotal,
        paidAt: DateTime.now(),
        paymentReference: reference,
        deliveryMethod: _deliveryMethod,
        deliveryLocation: _deliveryLocation.trim(),
      );
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
