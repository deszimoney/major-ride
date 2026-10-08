import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Device-side cache that plays the role `localStorage` plays on the website.
/// The keys match `STORAGE_KEYS` in database.js so the two stay recognisable
/// side by side, and the app still renders when Supabase is unreachable.
class LocalStore {
  LocalStore(this._prefs);

  final SharedPreferences _prefs;

  static const String products = 'mrco_products';
  static const String orders = 'mrco_orders';
  static const String currentUser = 'mrco_current_user';
  static const String cart = 'mrco_cart';
  static const String cartActivity = 'mrco_cart_activity';
  static const String cartActivitySeen = 'mrco_cart_activity_seen';

  static Future<LocalStore> open() async =>
      LocalStore(await SharedPreferences.getInstance());

  List<Map<String, dynamic>> readList(String key) {
    final raw = _prefs.getString(key);
    if (raw == null || raw.isEmpty) return const [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const [];
      return decoded
          .whereType<Map>()
          .map((entry) => entry.cast<String, dynamic>())
          .toList();
    } on FormatException {
      return const [];
    }
  }

  Future<void> writeList(String key, List<Map<String, dynamic>> value) =>
      _prefs.setString(key, jsonEncode(value));

  Map<String, dynamic>? readMap(String key) {
    final raw = _prefs.getString(key);
    if (raw == null || raw.isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      return decoded is Map ? decoded.cast<String, dynamic>() : null;
    } on FormatException {
      return null;
    }
  }

  Future<void> writeMap(String key, Map<String, dynamic> value) =>
      _prefs.setString(key, jsonEncode(value));

  String? readString(String key) => _prefs.getString(key);

  Future<void> writeString(String key, String value) =>
      _prefs.setString(key, value);

  Future<void> remove(String key) => _prefs.remove(key);
}
