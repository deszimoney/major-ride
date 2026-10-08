import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app.dart';
import 'config/app_config.dart';
import 'providers/cart_provider.dart';
import 'providers/catalog_provider.dart';
import 'providers/order_provider.dart';
import 'providers/session_provider.dart';
import 'services/auth_repository.dart';
import 'services/catalog_repository.dart';
import 'services/local_store.dart';
import 'services/order_repository.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: AppConfig.supabaseUrl,
    publishableKey: AppConfig.supabaseAnonKey,
  );
  final supabase = Supabase.instance.client;
  final store = await LocalStore.open();

  final authRepository = AuthRepository(supabase);
  final catalogRepository = CatalogRepository(supabase, store);
  final orderRepository = OrderRepository(supabase, store);

  runApp(
    MultiProvider(
      providers: [
        Provider<AuthRepository>.value(value: authRepository),
        ChangeNotifierProvider(
          create: (_) => SessionProvider(authRepository, store),
        ),
        ChangeNotifierProvider(
          create: (_) => CatalogProvider(catalogRepository),
        ),
        ChangeNotifierProvider(
          create: (_) => OrderProvider(orderRepository),
        ),
        ChangeNotifierProvider(
          create: (_) => CartProvider(store, orderRepository),
        ),
      ],
      child: const MayorRideApp(),
    ),
  );
}
