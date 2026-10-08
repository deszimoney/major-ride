import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../config/app_config.dart';
import '../models/product.dart';
import '../providers/catalog_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/app_shell.dart';
import '../widgets/product_card.dart';

/// Ports shop.html/shop.js: category chips plus a query-filtered grid.
/// Route arguments accept `{ 'q': ..., 'category': ... }`, matching the
/// `?q=` / `?category=` query-string convention on the website.
class ShopScreen extends StatefulWidget {
  const ShopScreen({super.key, this.initialQuery = '', this.initialCategory = ''});

  final String initialQuery;
  final String initialCategory;

  @override
  State<ShopScreen> createState() => _ShopScreenState();
}

class _ShopScreenState extends State<ShopScreen> {
  late String _query = widget.initialQuery;
  late String _category = widget.initialCategory;
  late final _searchController = TextEditingController(text: widget.initialQuery);

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _setCategory(String category) {
    setState(() => _category = category);
  }

  @override
  Widget build(BuildContext context) {
    final catalog = context.watch<CatalogProvider>();
    final products = catalog.search(query: _query, category: _category);
    final heading = _category.isEmpty ? 'All products' : '$_category collection';

    return AppShell(
      currentRoute: '/shop',
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 8),
          const Eyebrow('The garage edit'),
          const SizedBox(height: 6),
          Text(heading, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          const Text(
            'Select a category, compare prices, and choose the gear that '
            'belongs on your next ride.',
            style: TextStyle(color: AppColors.mutedText),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _searchController,
            onSubmitted: (value) => setState(() => _query = value.trim()),
            decoration: InputDecoration(
              hintText: 'Search products',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: IconButton(
                icon: const Icon(Icons.arrow_forward),
                onPressed: () =>
                    setState(() => _query = _searchController.text.trim()),
              ),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 40,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                _CategoryChip(label: 'All', selected: _category.isEmpty, onTap: () => _setCategory('')),
                for (final category in StoreCategory.all)
                  _CategoryChip(
                    label: category.label,
                    selected: _category.toLowerCase() == category.query.toLowerCase(),
                    onTap: () => _setCategory(category.query),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          if (catalog.loading && products.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 40),
              child: Center(child: CircularProgressIndicator(color: AppColors.primary)),
            )
          else if (products.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 40),
              child: Center(
                child: Text(
                  'No products match your search. Try another keyword.',
                  style: TextStyle(color: AppColors.mutedText),
                ),
              ),
            )
          else
            _ProductGrid(products: products),
          const SizedBox(height: 12),
        ],
      ),
    );
  }
}

class _CategoryChip extends StatelessWidget {
  const _CategoryChip({required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) => onTap(),
        selectedColor: AppColors.primary,
        backgroundColor: const Color(0x14FFFFFF),
        labelStyle: TextStyle(
          color: selected ? AppColors.darkStrong : AppColors.text,
          fontWeight: FontWeight.w600,
          fontSize: 13,
        ),
        side: BorderSide(color: selected ? AppColors.primary : AppColors.line),
        shape: const StadiumBorder(),
      ),
    );
  }
}

class _ProductGrid extends StatelessWidget {
  const _ProductGrid({required this.products});

  final List<Product> products;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final columns = width >= 1000 ? 4 : (width >= 700 ? 3 : (width >= 460 ? 2 : 1));

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: products.length,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: columns,
        mainAxisSpacing: 16,
        crossAxisSpacing: 16,
        childAspectRatio: columns == 1 ? 1.15 : 0.72,
      ),
      itemBuilder: (context, index) => ProductCard(product: products[index]),
    );
  }
}
