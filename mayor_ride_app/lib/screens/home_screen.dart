import 'package:flutter/material.dart';

import '../config/app_config.dart';
import '../theme/app_theme.dart';
import '../widgets/app_shell.dart';

/// Ports index.html: hero, three feature cards, and the category rail.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AppShell(
      currentRoute: '/',
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 12),
          _Hero(),
          const SizedBox(height: 28),
          _FeatureRow(),
          const SizedBox(height: 32),
          const Eyebrow('Shop by category'),
          const SizedBox(height: 8),
          const Text(
            'Shop by category',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 16),
          _CategoryGrid(),
          const SizedBox(height: 12),
        ],
      ),
    );
  }
}

class _Hero extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        image: const DecorationImage(
          image: AssetImage('assets/images/background.jpg'),
          fit: BoxFit.cover,
        ),
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 48),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(28),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              const Color(0xFF071616).withValues(alpha: 0.62),
              const Color(0xFF0D2A27).withValues(alpha: 0.48),
            ],
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Ride further.',
              style: TextStyle(fontSize: 34, fontWeight: FontWeight.w800, height: 1.1),
            ),
            const Text(
              'Arrive ready.',
              style: TextStyle(
                fontSize: 34,
                fontWeight: FontWeight.w800,
                height: 1.1,
                color: AppColors.accent,
              ),
            ),
            const SizedBox(height: 14),
            const Text(
              'Purpose-built motorcycle gear, parts, and everyday essentials '
              'for Ghanaian riders.',
              style: TextStyle(color: AppColors.text, fontSize: 15),
            ),
            const SizedBox(height: 22),
            FilledButton(
              onPressed: () => Navigator.of(context).pushNamed('/shop'),
              child: const Text('Shop the collection'),
            ),
          ],
        ),
      ),
    );
  }
}

class _FeatureRow extends StatelessWidget {
  static const _features = [
    (Icons.shield_outlined, 'SECURE PAYMENT', '100% Secure transactions'),
    (Icons.local_shipping_outlined, 'SAME DAY DELIVERY', 'All orders within Accra'),
    (Icons.verified_outlined, 'QUALITY TRUST', 'Tried, Tested, Trusted'),
  ];

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.sizeOf(context).width >= 600;

    final cards = [
      for (final (icon, title, subtitle) in _features)
        Expanded(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 4),
            padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 12),
            decoration: BoxDecoration(
              color: AppColors.panelSoft,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AppColors.line),
            ),
            child: Column(
              children: [
                Icon(icon, color: AppColors.primary, size: 26),
                const SizedBox(height: 10),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 11.5, color: AppColors.mutedText),
                ),
              ],
            ),
          ),
        ),
    ];

    return isWide
        ? Row(children: cards)
        : Column(
            children: [
              for (final card in cards)
                Padding(padding: const EdgeInsets.only(bottom: 10), child: card),
            ],
          );
  }
}

class _CategoryGrid extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final columns = width >= 900 ? 3 : (width >= 600 ? 2 : 2);

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: StoreCategory.all.length,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: columns,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 1.3,
      ),
      itemBuilder: (context, index) {
        final category = StoreCategory.all[index];
        return _CategoryTile(category: category);
      },
    );
  }
}

class _CategoryTile extends StatelessWidget {
  const _CategoryTile({required this.category});

  final StoreCategory category;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(category.asset, fit: BoxFit.cover),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.transparent,
                  Colors.black.withValues(alpha: 0.72),
                ],
              ),
            ),
          ),
          Positioned(
            left: 14,
            bottom: 12,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  category.label,
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                ),
                const Text(
                  'Explore',
                  style: TextStyle(fontSize: 11, color: AppColors.accent),
                ),
              ],
            ),
          ),
          Positioned.fill(
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => Navigator.of(context).pushNamed(
                  '/shop',
                  arguments: {'category': category.query},
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
