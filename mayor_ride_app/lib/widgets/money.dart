import '../config/app_config.dart';

/// Matches `formatMoney` in cart.js: `GHS 123.45`.
String formatMoney(num value) =>
    '${AppConfig.currency} ${value.toStringAsFixed(2)}';
