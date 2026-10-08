import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/product.dart';
import '../services/catalog_repository.dart';

/// Ports `getProducts` / `saveProducts` and the `mrco-products-updated`
/// event from database.js: show the cache immediately, then reconcile with
/// Supabase, and keep listening for live changes so admin edits fan out.
class CatalogProvider extends ChangeNotifier {
  CatalogProvider(this._repository) {
    _products = _repository.readCache();
    _refresh();
    _watchSub = _repository.watch().listen(
      _onRemoteUpdate,
      onError: (_) {}, // Realtime is best-effort; cache stays authoritative.
    );
  }

  final CatalogRepository _repository;
  List<Product> _products = const [];
  StreamSubscription<List<Product>>? _watchSub;
  bool _loading = true;

  List<Product> get products => _products;
  bool get loading => _loading;

  Future<void> _refresh() async {
    final remote = await _repository.fetchRemote();
    if (remote != null) {
      _products = remote;
    }
    _loading = false;
    notifyListeners();
  }

  void _onRemoteUpdate(List<Product> rows) {
    if (rows.isEmpty) return;
    _products = rows;
    unawaited(_repository.cache(rows));
    notifyListeners();
  }

  Future<void> refresh() => _refresh();

  List<Product> search({String query = '', String category = ''}) {
    final normalizedCategory = category.trim().toLowerCase();
    return _products
        .where(
          (product) =>
              (normalizedCategory.isEmpty ||
                  product.category.toLowerCase() == normalizedCategory) &&
              product.matches(query),
        )
        .toList();
  }

  Product? byId(String id) {
    for (final product in _products) {
      if (product.id == id) return product;
    }
    return null;
  }

  Future<void> saveProduct(Product product) async {
    final index = _products.indexWhere((entry) => entry.id == product.id);
    final next = List<Product>.from(_products);
    if (index >= 0) {
      next[index] = product;
    } else {
      next.insert(0, product);
    }
    _products = next;
    notifyListeners();
    await _repository.cache(next);
    await _repository.save(product);
  }

  Future<void> deleteProduct(String productId) async {
    _products = _products.where((entry) => entry.id != productId).toList();
    notifyListeners();
    await _repository.cache(_products);
    await _repository.delete(productId);
  }

  @override
  void dispose() {
    _watchSub?.cancel();
    super.dispose();
  }
}
