/// Central configuration, ported from `supabase-config.js` and
/// `paystack-config.js` in the original web build.
class AppConfig {
  const AppConfig._();

  // --- Supabase ---------------------------------------------------------
  static const String supabaseUrl = 'https://vxqzzirmnbewpweszvev.supabase.co';
  static const String supabaseAnonKey =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InZ4cXp6aXJtbmJld3B3ZXN6dmV2Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODk0MTIxNjYsImV4cCI6MjEwNDk4ODE2Nn0.ORC33tY4tOMqCW0kKAm_Cy0RS4oED8cjB8BruGoxfi4';

  /// Mirrors `window.MRCO_SUPABASE_READY`.
  static bool get supabaseReady =>
      supabaseUrl.contains('supabase.co') && !supabaseAnonKey.contains('YOUR_');

  /// Mirrors `window.MRCO_SOCIAL_PROVIDERS`. Enable a provider here only
  /// after enabling it under Authentication > Providers in Supabase.
  static const Map<String, bool> socialProviders = {
    'google': true,
    'apple': false,
  };

  /// Deep link registered for OAuth and password-recovery redirects.
  /// Must match the scheme in AndroidManifest.xml / Info.plist and the
  /// allow-list under Authentication > URL Configuration in Supabase.
  static const String authRedirectScheme = 'mayorrideco';
  static const String authRedirectUrl = 'mayorrideco://login-callback';

  // --- Paystack ---------------------------------------------------------
  /// Public key only. The secret key must never ship inside the app.
  static const String paystackPublicKey =
      'pk_test_c429af01c19dcaaa6683e421de0aa5fbd41dd52c';

  static bool get paystackReady =>
      paystackPublicKey.startsWith('pk_') &&
      !paystackPublicKey.contains('REPLACE_WITH');

  /// Origin used as the WebView base URL during mobile checkout so the
  /// Paystack popup script runs against a real https origin.
  static const String checkoutOrigin = 'https://mayorrideco.com';

  /// Optional Supabase Edge Function that re-checks a Paystack reference
  /// with the secret key before an order is trusted. Leave empty to skip
  /// verification (matches the current website behaviour).
  static const String paymentVerifyFunction = '';

  // --- Store ------------------------------------------------------------
  static const String currency = 'GHS';
  static const double deliveryFee = 40;
  static const double pickupFee = 15;
  static const String adminEmail = 'admin@mayorrideco.com';

  static const String brandName = 'Mayor Ride Co.';
  static const String brandTagline =
      "Ghana's trusted source for premium motorcycle gear and backpacks.";
  static const String storeLocation = 'Kasoa, Ghana';
  static const String storeEmail = 'info@mayorrideco.com';
  static const String storePhone = '+233 5914 67132';
  static const String credit = 'Created by Desmond K. Appiah';
}

/// Home-screen category rail, ported from the `category-grid` in index.html.
class StoreCategory {
  const StoreCategory(this.label, this.query, this.asset);

  final String label;
  final String query;
  final String asset;

  static const List<StoreCategory> all = [
    StoreCategory('Helmets', 'Helmets', 'assets/images/Helmet.jpg'),
    StoreCategory('Clothing', 'Clothing', 'assets/images/jackets.jpg'),
    StoreCategory('Gloves', 'Gloves', 'assets/images/gloves.jpg'),
    StoreCategory('Boots', 'Boots', 'assets/images/boot.jpg'),
    StoreCategory('Backpacks', 'Backpacks', 'assets/images/bags.jpg'),
    StoreCategory('Parts & spares', 'Parts', 'assets/images/bodyparts.jpg'),
  ];
}
