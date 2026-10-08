import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'config/app_config.dart';
import 'providers/session_provider.dart';
import 'screens/about_screen.dart';
import 'screens/admin_screen.dart';
import 'screens/contact_screen.dart';
import 'screens/home_screen.dart';
import 'screens/shop_screen.dart';
import 'theme/app_theme.dart';
import 'widgets/auth_sheet.dart';

class MayorRideApp extends StatefulWidget {
  const MayorRideApp({super.key});

  @override
  State<MayorRideApp> createState() => _MayorRideAppState();
}

class _MayorRideAppState extends State<MayorRideApp> {
  final _navigatorKey = GlobalKey<NavigatorState>();

  @override
  Widget build(BuildContext context) {
    // Mirrors the `location.hash.includes('type=recovery')` check in
    // auth.js: once a password-recovery deep link signs the user in, pop
    // open the "choose a new password" sheet on top of whatever page is
    // showing.
    final session = context.watch<SessionProvider>();
    if (session.consumePasswordRecoveryRequest()) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final overlayContext = _navigatorKey.currentState?.overlay?.context;
        if (overlayContext != null) {
          showAuthSheet(overlayContext, mode: AuthMode.reset);
        }
      });
    }

    return MaterialApp(
      navigatorKey: _navigatorKey,
      title: AppConfig.brandName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.build(),
      initialRoute: '/',
      onGenerateRoute: _onGenerateRoute,
    );
  }

  static Route<dynamic> _onGenerateRoute(RouteSettings settings) {
    final args = settings.arguments is Map
        ? (settings.arguments as Map).cast<String, dynamic>()
        : const <String, dynamic>{};

    Widget page;
    switch (settings.name) {
      case '/shop':
        page = ShopScreen(
          initialQuery: (args['q'] as String?) ?? '',
          initialCategory: (args['category'] as String?) ?? '',
        );
      case '/about':
        page = const AboutScreen();
      case '/contact':
        page = const ContactScreen();
      case '/admin':
        page = const AdminScreen();
      case '/':
      default:
        page = const HomeScreen();
    }

    return MaterialPageRoute(builder: (_) => page, settings: settings);
  }
}
