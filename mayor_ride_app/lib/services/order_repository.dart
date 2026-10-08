import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/shop_order.dart';
import 'local_store.dart';

/// Ports the order half of database.js plus the `mrco_cart_activity` feed the
/// admin notifications panel reads.
class OrderRepository {
  OrderRepository(this._client, this._store);

  final SupabaseClient _client;
  final LocalStore _store;

  List<ShopOrder> readCache() =>
      _store.readList(LocalStore.orders).map(ShopOrder.fromMap).toList();

  Future<void> _writeCache(List<ShopOrder> orders) =>
      _store.writeList(LocalStore.orders, [
        for (final order in orders) order.toMap(),
      ]);

  Future<List<ShopOrder>?> fetchRemote() async {
    try {
      final rows = await _client
          .from('orders')
          .select()
          .order('paid_at', ascending: false);
      final orders = (rows as List)
          .whereType<Map>()
          .map((row) => ShopOrder.fromMap(row.cast<String, dynamic>()))
          .toList();
      await _writeCache(orders);
      return orders;
    } on Exception {
      return null;
    }
  }

  /// Best-effort, like the fire-and-forget `.then().catch(() => {})` writes
  /// in database.js: the order is already in the local cache by the time
  /// this runs, so a remote failure here must not undo the checkout the
  /// customer just completed.
  Future<void> create(ShopOrder order) async {
    try {
      await _client.from('orders').insert(order.toMap());
    } on Exception {
      // Supabase table must exist; local cache remains active until configured.
    }
  }

  Future<void> setDeliveryConfirmed(String orderId, bool confirmed) async {
    try {
      await _client
          .from('orders')
          .update({
            'delivery_confirmed': confirmed,
            'delivered_at': confirmed
                ? DateTime.now().toUtc().toIso8601String()
                : null,
          })
          .eq('id', orderId);
    } on Exception {
      // Best-effort, see create() above.
    }
  }

  Future<void> cache(List<ShopOrder> orders) => _writeCache(orders);

  Stream<List<ShopOrder>> watch() => _client
      .from('orders')
      .stream(primaryKey: ['id'])
      .order('paid_at', ascending: false)
      .map((rows) => rows.map(ShopOrder.fromMap).toList());

  // --- Cart activity ----------------------------------------------------
  // Device-local, exactly as on the website: the feed is never uploaded.

  List<CartActivity> readActivity() =>
      _store.readList(LocalStore.cartActivity).map(CartActivity.fromMap).toList();

  Future<void> recordActivity(CartActivity activity) async {
    final existing = readActivity();
    final next = [activity, ...existing].take(100).toList();
    await _store.writeList(LocalStore.cartActivity, [
      for (final entry in next) entry.toMap(),
    ]);
  }

  DateTime? get activitySeenAt {
    final raw = _store.readString(LocalStore.cartActivitySeen);
    return raw == null ? null : DateTime.tryParse(raw)?.toLocal();
  }

  Future<void> markActivitySeen() => _store.writeString(
    LocalStore.cartActivitySeen,
    DateTime.now().toUtc().toIso8601String(),
  );

  int unseenActivityCount() {
    final seenAt = activitySeenAt;
    if (seenAt == null) return readActivity().length;
    return readActivity().where((entry) => entry.addedAt.isAfter(seenAt)).length;
  }
}
