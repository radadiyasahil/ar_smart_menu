import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'core/services/subscription_service.dart';
import 'core/theme/app_theme.dart';
import 'core/utils/owner_notifications_sync.dart';
import 'providers/analytics_provider.dart';
import 'providers/auth_provider.dart';
import 'providers/business_provider.dart';
import 'providers/notification_provider.dart';
import 'providers/product_provider.dart';
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

  await themeProvider.hydrate();
  await notificationProvider.hydrate();

  // Fast path: local cache only — UI shows in ~1s, no network blocking startup.
  await authProvider.hydrateFromCache();
  if (authProvider.isAuthenticated) {
    await businessProvider.hydrateFromCache();
    await productProvider.hydrateFromCache();
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
        ],
        child: const ArSmartMenuApp(),
      ),
    ),
  );

  // Background sync after first frame — does not block UI paint.
  if (authProvider.isAuthenticated) {
    unawaited(businessProvider.refreshProfileInBackground());
    unawaited(analyticsProvider.load());
    unawaited(
      syncOwnerNotifications(
        productProvider: productProvider,
        businessProvider: businessProvider,
        notificationProvider: notificationProvider,
        subscriptionService: SubscriptionService(),
      ),
    );
  }
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
