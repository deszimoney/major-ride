import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';

import '../config/app_config.dart';
import '../providers/cart_provider.dart';
import '../providers/session_provider.dart';
import '../theme/app_theme.dart';
import 'auth_sheet.dart';
import 'cart_sheet.dart';

/// Shared page frame: reproduces the sticky glass `<nav>` and footer that
/// wrap every page on the website, plus the search box wired to `shop.html`.
class AppShell extends StatelessWidget {
  const AppShell({
    super.key,
    required this.currentRoute,
    required this.body,
    this.scrollable = true,
    this.padBody = true,
  });

  final String currentRoute;
  final Widget body;
  final bool scrollable;
  final bool padBody;

  static const _navItems = [
    ('Home', '/'),
    ('Shop', '/shop'),
    ('About', '/about'),
    ('Contact', '/contact'),
  ];

  @override
  Widget build(BuildContext context) {
    final session = context.watch<SessionProvider>();
    final isWide = MediaQuery.sizeOf(context).width >= 720;

    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _NavBar(currentRoute: currentRoute, isWide: isWide),
        padBody
            ? Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: body,
              )
            : body,
        const _SiteFooter(),
      ],
    );

    return Scaffold(
      backgroundColor: AppColors.darkBg,
      body: DecoratedBox(
        decoration: appBackground,
        child: SafeArea(
          bottom: false,
          child: scrollable ? SingleChildScrollView(child: content) : content,
        ),
      ),
      floatingActionButton: session.isLoggedIn && !session.isAdmin
          ? _CartFab()
          : null,
    );
  }
}

class _CartFab extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final count = context.watch<CartProvider>().itemCount;
    return Badge(
      isLabelVisible: count > 0,
      label: Text('$count'),
      backgroundColor: AppColors.primary,
      textColor: AppColors.darkStrong,
      child: FloatingActionButton(
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.darkStrong,
        onPressed: () => showCartSheet(context),
        child: const Icon(Icons.shopping_bag_outlined),
      ),
    );
  }
}

class _NavBar extends StatelessWidget {
  const _NavBar({required this.currentRoute, required this.isWide});

  final String currentRoute;
  final bool isWide;

  @override
  Widget build(BuildContext context) {
    final session = context.watch<SessionProvider>();

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 14, 12, 10),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xB3122C2A),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.lineStrong),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              InkWell(
                onTap: () => Navigator.of(
                  context,
                ).pushNamedAndRemoveUntil('/', (route) => false),
                borderRadius: BorderRadius.circular(10),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SvgPicture.asset(
                      'assets/images/logo.svg',
                      width: 26,
                      height: 26,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      AppConfig.brandName,
                      style: const TextStyle(
                        color: AppColors.accent,
                        fontWeight: FontWeight.w800,
                        fontSize: 17,
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              if (isWide) ..._navLinks(context),
              const SizedBox(width: 12),
              if (session.isLoggedIn)
                _UserPill(session: session)
              else
                _AuthButtons(),
            ],
          ),
          const SizedBox(height: 12),
          _SearchField(),
          if (!isWide) ...[
            const SizedBox(height: 10),
            Wrap(spacing: 6, runSpacing: 6, children: _navLinks(context)),
          ],
        ],
      ),
    );
  }

  List<Widget> _navLinks(BuildContext context) {
    final session = context.watch<SessionProvider>();
    final items = [
      ...AppShell._navItems,
      if (session.isAdmin) ('Admin', '/admin'),
    ];

    return [
      for (final (label, route) in items)
        _NavLink(label: label, route: route, active: route == currentRoute),
    ];
  }
}

class _NavLink extends StatelessWidget {
  const _NavLink({
    required this.label,
    required this.route,
    required this.active,
  });

  final String label;
  final String route;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: active
          ? null
          : () => Navigator.of(
              context,
            ).pushNamedAndRemoveUntil(route, (r) => false),
      style: TextButton.styleFrom(
        foregroundColor: active ? AppColors.accent : AppColors.text,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      ),
      child: Text(label, style: const TextStyle(fontSize: 14)),
    );
  }
}

class _AuthButtons extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        OutlinedButton(
          onPressed: () => showAuthSheet(context, mode: AuthMode.login),
          child: const Text('Login'),
        ),
        const SizedBox(width: 8),
        FilledButton(
          onPressed: () => showAuthSheet(context, mode: AuthMode.signup),
          child: const Text('Sign Up'),
        ),
      ],
    );
  }
}

class _UserPill extends StatelessWidget {
  const _UserPill({required this.session});

  final SessionProvider session;

  @override
  Widget build(BuildContext context) {
    final user = session.currentUser!;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0x1EFFFFFF),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text('Hi, ${user.name}', style: const TextStyle(fontSize: 13)),
        ),
        const SizedBox(width: 8),
        TextButton(
          onPressed: () => session.signOut(),
          child: const Text('Log out'),
        ),
      ],
    );
  }
}

class _SearchField extends StatefulWidget {
  @override
  State<_SearchField> createState() => _SearchFieldState();
}

class _SearchFieldState extends State<_SearchField> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final query = _controller.text.trim();
    Navigator.of(context).pushNamed('/shop', arguments: {'q': query});
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _controller,
      textInputAction: TextInputAction.search,
      onSubmitted: (_) => _submit(),
      style: const TextStyle(fontSize: 14),
      decoration: InputDecoration(
        hintText: 'Search products',
        isDense: true,
        prefixIcon: const Icon(Icons.search, size: 20),
        suffixIcon: IconButton(
          icon: const Icon(Icons.arrow_forward, size: 18),
          onPressed: _submit,
        ),
        contentPadding: const EdgeInsets.symmetric(
          vertical: 10,
          horizontal: 12,
        ),
      ),
    );
  }
}

class _SiteFooter extends StatelessWidget {
  const _SiteFooter();

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.sizeOf(context).width >= 720;

    final columns = [
      _FooterColumn(
        title: AppConfig.brandName,
        children: [Text(AppConfig.brandTagline, style: _footerText)],
      ),
      _FooterColumn(
        title: 'Quick Links',
        children: [
          for (final (label, route) in AppShell._navItems)
            _FooterLink(label: label, route: route),
        ],
      ),
      _FooterColumn(
        title: 'Visit Us',
        children: [
          Text(AppConfig.storeLocation, style: _footerText),
          Text('Email: ${AppConfig.storeEmail}', style: _footerText),
          Text('Phone: ${AppConfig.storePhone}', style: _footerText),
        ],
      ),
    ];

    return Container(
      margin: const EdgeInsets.only(top: 32),
      padding: const EdgeInsets.fromLTRB(20, 28, 20, 20),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.footerStart, AppColors.darkStrong],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          isWide
              ? Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final column in columns) Expanded(child: column),
                  ],
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final column in columns)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 20),
                        child: column,
                      ),
                  ],
                ),
          const Divider(color: AppColors.line, height: 32),
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            spacing: 8,
            runSpacing: 8,
            children: [
              Text(
                '© 2024 ${AppConfig.brandName} All rights reserved.',
                style: _footerText,
              ),
              Text(AppConfig.credit, style: _footerText),
            ],
          ),
        ],
      ),
    );
  }

  static const _footerText = TextStyle(
    color: AppColors.mutedText,
    fontSize: 12.5,
  );
}

class _FooterColumn extends StatelessWidget {
  const _FooterColumn({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: AppColors.accent,
            fontWeight: FontWeight.w700,
            fontSize: 15,
          ),
        ),
        const SizedBox(height: 10),
        ...children.map(
          (child) =>
              Padding(padding: const EdgeInsets.only(bottom: 4), child: child),
        ),
      ],
    );
  }
}

class _FooterLink extends StatelessWidget {
  const _FooterLink({required this.label, required this.route});

  final String label;
  final String route;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () =>
          Navigator.of(context).pushNamedAndRemoveUntil(route, (r) => false),
      child: Text(
        label,
        style: const TextStyle(color: AppColors.mutedText, fontSize: 12.5),
      ),
    );
  }
}
