import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'core/theme/app_theme.dart';
import 'providers/analytics_provider.dart';
import 'providers/auth_provider.dart';
import 'providers/business_provider.dart';
import 'providers/notification_provider.dart';
import 'providers/product_provider.dart';
import 'providers/table_orders_provider.dart';
import 'providers/theme_provider.dart';
import 'routes/app_router.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await EasyLocalization.ensureInitialized();

  final authProvider = AuthProvider();
  final businessProvider = BusinessProvider();
  final productProvider = ProductProvider();
  final analyticsProvider = AnalyticsProvider();
  final themeProvider = ThemeProvider();
  final notificationProvider = NotificationProvider();
  final tableOrdersProvider = TableOrdersProvider();

  await themeProvider.hydrate();

  // Restore persisted owner session across page refresh and reloads (no logout on refresh)
  await authProvider.loadSession();
  await businessProvider.hydrateFromCache();
  await notificationProvider.hydrate(businessProvider.business?.id);
  if (authProvider.isAuthenticated) {
    unawaited(businessProvider.refreshProfileInBackground());
    final bId = businessProvider.business?.id;
    if (bId != null && bId.isNotEmpty && businessProvider.isActive) {
      tableOrdersProvider.startPolling(bId);
    }
  }

  runApp(
    EasyLocalization(
      supportedLocales: const [Locale('en'), Locale('hi')],
      path: 'assets/translations',
      fallbackLocale: const Locale('en'),
      child: MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: authProvider),
          ChangeNotifierProvider.value(value: businessProvider),
          ChangeNotifierProvider.value(value: productProvider),
          ChangeNotifierProvider.value(value: analyticsProvider),
          ChangeNotifierProvider.value(value: themeProvider),
          ChangeNotifierProvider.value(value: notificationProvider),
          ChangeNotifierProvider.value(value: tableOrdersProvider),
        ],
        child: const ArSmartMenuApp(),
      ),
    ),
  );
}

/// Root widget — configures theme, localization, and routing.
class ArSmartMenuApp extends StatelessWidget {
  const ArSmartMenuApp({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();

    return MaterialApp.router(
      title: 'AR Smart Menu',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeProvider.themeMode,
      localizationsDelegates: context.localizationDelegates,
      supportedLocales: context.supportedLocales,
      locale: context.locale,
      routerConfig: appRouter,
    );
  }
}
