import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/product.dart';
import 'local_store.dart';

/// Ports the product half of database.js: read from Supabase, cache on the
/// device, and fall back to the cache (then the seed catalog) when offline.
class CatalogRepository {
  CatalogRepository(this._client, this._store);

  final SupabaseClient _client;
  final LocalStore _store;

  /// The starter catalog from DEFAULT_PRODUCTS in database.js. Local asset
  /// paths replace the `images/…` URLs the website used.
  static const List<Product> seedProducts = [
    Product(
      id: 'prod-001',
      name: 'Shark Evo Helmet',
      category: 'Helmets',
      price: 299.99,
      image: 'assets/images/Helmet.jpg',
      description:
          'High-impact protection with a lightweight shell and premium comfort fit.',
    ),
    Product(
      id: 'prod-002',
      name: 'Alpinestars Gloves',
      category: 'Gloves',
      price: 89.99,
      image: 'assets/images/gloves.jpg',
      description:
          'Rugged grip and dexterity for daily rides and track-ready performance.',
    ),
    Product(
      id: 'prod-003',
      name: 'Racing Boots',
      category: 'Boots',
      price: 199.99,
      image: 'assets/images/boot.jpg',
      description:
          'Supportive ankle protection with durable construction and all-day comfort.',
    ),
    Product(
      id: 'prod-004',
      name: 'Roadshield Jacket',
      category: 'Clothing',
      price: 449.99,
      image: 'assets/images/jackets.jpg',
      description:
          'Weather-ready riding jacket with a structured protective fit.',
    ),
    Product(
      id: 'prod-005',
      name: 'Urban Rider Backpack',
      category: 'Backpacks',
      price: 179.99,
      image: 'assets/images/bags.jpg',
      description:
          'A practical, water-resistant bag for daily commutes and weekend rides.',
    ),
    Product(
      id: 'prod-006',
      name: 'Signal Pro Kit',
      category: 'Electronics',
      price: 329.99,
      image: 'assets/images/electronics.jpg',
      description: 'Compact ride electronics to keep your journey connected.',
    ),
    Product(
      id: 'prod-007',
      name: 'SecureLock Disc Lock',
      category: 'Security',
      price: 129.99,
      image: 'assets/images/locks.jpg',
      description: 'Heavy-duty compact security for stops around town.',
    ),
    Product(
      id: 'prod-008',
      name: 'Street Grip Tyre',
      category: 'Tyres',
      price: 389.99,
      image: 'assets/images/tyre.jpg',
      description: 'Confident road grip for daily city riding.',
    ),
    Product(
      id: 'prod-009',
      name: 'Torque Exhaust',
      category: 'Exhausts',
      price: 699.99,
      image: 'assets/images/exhausts.jpg',
      description: 'A clean performance upgrade with a deep, controlled note.',
    ),
    Product(
      id: 'prod-010',
      name: 'MotoCare Body Kit',
      category: 'Parts',
      price: 259.99,
      image: 'assets/images/bodyparts.jpg',
      description: 'Replacement bodywork made for dependable fitment.',
    ),
  ];

  List<Product> readCache() {
    final cached = _store
        .readList(LocalStore.products)
        .map(Product.fromMap)
        .toList();
    return cached.isEmpty ? seedProducts : cached;
  }

  Future<void> _writeCache(List<Product> products) =>
      _store.writeList(LocalStore.products, [
        for (final product in products) product.toMap(),
      ]);

  /// Fetches live inventory. Returns null when the remote call fails so the
  /// caller can keep showing the cache instead of an empty shop.
  Future<List<Product>?> fetchRemote() async {
    try {
      final rows = await _client.from('products').select();
      final products = (rows as List)
          .whereType<Map>()
          .map((row) => Product.fromMap(row.cast<String, dynamic>()))
          .toList();
      if (products.isEmpty) return null;
      await _writeCache(products);
      return products;
    } on Exception {
      return null;
    }
  }

  /// Best-effort, like the fire-and-forget `.then().catch(() => {})` writes
  /// in database.js: the local cache (already updated by the caller) stays
  /// the source of truth even if this remote write fails.
  Future<void> save(Product product) async {
    try {
      await _client.from('products').upsert(product.toMap(), onConflict: 'id');
    } on Exception {
      // Supabase table must exist; local cache remains active until configured.
    }
  }

  Future<void> delete(String productId) async {
    try {
      await _client.from('products').delete().eq('id', productId);
    } on Exception {
      // Best-effort, see save() above.
    }
  }

  Future<void> cache(List<Product> products) => _writeCache(products);

  /// Live product changes, so an admin edit lands on every open device.
  Stream<List<Product>> watch() => _client
      .from('products')
      .stream(primaryKey: ['id'])
      .map((rows) => rows.map(Product.fromMap).toList());
}
