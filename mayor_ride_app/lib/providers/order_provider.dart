import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/shop_order.dart';
import '../services/order_repository.dart';

/// Ports `getOrders` / `saveOrders` from database.js plus the admin
/// notification badge that reads `mrco_cart_activity`.
class OrderProvider extends ChangeNotifier {
  OrderProvider(this._repository) {
    _orders = _repository.readCache();
    _refresh();
    _watchSub = _repository.watch().listen(
      _onRemoteUpdate,
      onError: (_) {},
    );
  }

  final OrderRepository _repository;
  List<ShopOrder> _orders = const [];
  bool _loading = true;
  StreamSubscription<List<ShopOrder>>? _watchSub;

  List<ShopOrder> get orders => _orders;
  bool get loading => _loading;

  List<ShopOrder> ordersFor(String userId) =>
      _orders.where((order) => order.userId == userId).toList();

  Future<void> _refresh() async {
    final remote = await _repository.fetchRemote();
    if (remote != null) {
      _orders = remote;
    }
    _loading = false;
    notifyListeners();
  }

  void _onRemoteUpdate(List<ShopOrder> rows) {
    _orders = rows;
    unawaited(_repository.cache(rows));
    notifyListeners();
  }

  Future<void> refresh() => _refresh();

  Future<void> submit(ShopOrder order) async {
    _orders = [order, ..._orders];
    notifyListeners();
    await _repository.cache(_orders);
    await _repository.create(order);
  }

  Future<void> setDeliveryConfirmed(String orderId, bool confirmed) async {
    final index = _orders.indexWhere((order) => order.id == orderId);
    if (index < 0) return;
    final next = List<ShopOrder>.from(_orders);
    next[index] = next[index].copyWith(
      deliveryConfirmed: confirmed,
      deliveredAt: confirmed ? DateTime.now() : null,
    );
    _orders = next;
    notifyListeners();
    await _repository.cache(_orders);
    await _repository.setDeliveryConfirmed(orderId, confirmed);
  }

  // --- Reporting, mirrors renderReports() in admin.js -------------------

  double get totalReceived => _orders
      .where((order) => order.paymentStatus == 'completed')
      .fold(0, (sum, order) => sum + order.total);

  int get completedOrderCount =>
      _orders.where((order) => order.paymentStatus == 'completed').length;

  int get itemsSoldCount => _orders
      .where((order) => order.paymentStatus == 'completed')
      .fold(0, (sum, order) => sum + order.itemCount);

  int get pendingDeliveryCount => _orders
      .where(
        (order) =>
            order.paymentStatus == 'completed' && !order.deliveryConfirmed,
      )
      .length;

  /// name -> total quantity purchased, across completed orders.
  Map<String, int> get itemsPurchased {
    final totals = <String, int>{};
    for (final order in _orders) {
      if (order.paymentStatus != 'completed') continue;
      for (final item in order.items) {
        totals[item.name] = (totals[item.name] ?? 0) + item.quantity;
      }
    }
    return totals;
  }

  // --- Cart activity feed -------------------------------------------------

  List<CartActivity> get cartActivity => _repository.readActivity();

  int get unseenActivityCount => _repository.unseenActivityCount();

  Future<void> markActivitySeen() async {
    await _repository.markActivitySeen();
    notifyListeners();
  }

  @override
  void dispose() {
    _watchSub?.cancel();
    super.dispose();
  }
}
