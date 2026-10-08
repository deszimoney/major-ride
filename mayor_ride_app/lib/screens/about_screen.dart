import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../widgets/app_shell.dart';

/// Ports about.html: the intro block and the three numbered story cards.
class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  static const _cards = [
    (
      '01',
      'Quality you can trust',
      'We carefully select helmets, clothing, boots, and backpacks that meet '
          'the demands of real riders. Every item earns its place through fit, '
          'durability, and everyday usefulness.',
    ),
    (
      '02',
      'Made for the community',
      'From first-time riders to seasoned road veterans, we make it easier to '
          'find gear that feels right and performs when it matters.',
    ),
    (
      '03',
      'Ready for the next ride',
      'Based in Accra, we pair a focused collection with responsive service '
          'and same-day delivery across the city.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return AppShell(
      currentRoute: '/about',
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 12),
          const Eyebrow('Our story'),
          const SizedBox(height: 8),
          const Text(
            'Built for riders who take every road personally.',
            style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, height: 1.2),
          ),
          const SizedBox(height: 10),
          const Text(
            "Mayor Ride Co. is Ghana's destination for dependable motorcycle "
            'gear that brings protection, comfort, and character to every ride.',
            style: TextStyle(color: AppColors.mutedText, fontSize: 15),
          ),
          const SizedBox(height: 24),
          for (final (number, title, body) in _cards)
            Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.panelSoft,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.line),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      number,
                      style: const TextStyle(
                        color: AppColors.accent,
                        fontWeight: FontWeight.w800,
                        fontSize: 22,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 17)),
                    const SizedBox(height: 8),
                    Text(body, style: const TextStyle(color: AppColors.mutedText)),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
