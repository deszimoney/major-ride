// Basic unit tests for pure logic that doesn't need Supabase or a widget
// tree. A full widget smoke test would need to fake SupabaseClient, which
// is out of scope for this starter test file.

import 'package:flutter_test/flutter_test.dart';
import 'package:mayor_ride_app/models/product.dart';
import 'package:mayor_ride_app/theme/app_theme.dart';
import 'package:mayor_ride_app/widgets/money.dart';

void main() {
  test('formatMoney matches the website format (GHS 123.45)', () {
    expect(formatMoney(299.99), 'GHS 299.99');
    expect(formatMoney(0), 'GHS 0.00');
  });

  test('Product.normalizeCategory migrates the retired accessories category', () {
    expect(Product.normalizeCategory('Accessories'), 'Backpacks');
    expect(Product.normalizeCategory('Helmets'), 'Helmets');
  });

  test('Product.matches searches name, category, and description', () {
    const product = Product(
      id: 'prod-001',
      name: 'Shark Evo Helmet',
      category: 'Helmets',
      description: 'High-impact protection with a lightweight shell.',
      price: 299.99,
      image: 'assets/images/Helmet.jpg',
    );

    expect(product.matches('shark'), isTrue);
    expect(product.matches('lightweight'), isTrue);
    expect(product.matches('boots'), isFalse);
  });

  test('AppTheme.build produces a usable dark ThemeData', () {
    final theme = AppTheme.build();
    expect(theme.scaffoldBackgroundColor, AppColors.darkBg);
  });
}
