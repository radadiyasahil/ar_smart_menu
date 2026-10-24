import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/app_routes.dart';
import '../../screens/account/account_screen.dart';
import '../../screens/analytics/analytics_screen.dart';
import '../../screens/auth/language_selection_screen.dart';
import '../../screens/auth/login_screen.dart';
import '../../screens/auth/otp_screen.dart';
import '../../screens/auth/splash_screen.dart';
import '../../screens/business/business_status_screen.dart';
import '../../screens/business/register_business_screen.dart';
import '../../screens/dashboard/dashboard_screen.dart';
import '../../screens/notifications/notifications_screen.dart';
import '../../screens/products/add_product_screen.dart';
import '../../screens/products/product_detail_screen.dart';
import '../../screens/products/products_screen.dart';
import '../../screens/qr/qr_codes_screen.dart';
import '../../widgets/navigation/main_shell.dart';

final GlobalKey<NavigatorState> rootNavigatorKey = GlobalKey<NavigatorState>();
final GlobalKey<NavigatorState> shellNavigatorKey = GlobalKey<NavigatorState>();

/// App-wide router configuration using go_router.
final GoRouter appRouter = GoRouter(
  navigatorKey: rootNavigatorKey,
  initialLocation: AppRoutes.splash,
  routes: [
    GoRoute(path: AppRoutes.splash, builder: (_, _) => const SplashScreen()),
    GoRoute(path: AppRoutes.language, builder: (_, _) => const LanguageSelectionScreen()),
    GoRoute(path: AppRoutes.login, builder: (_, _) => const LoginScreen()),
    GoRoute(
      path: AppRoutes.otp,
      builder: (_, state) => OtpScreen(
        phoneNumber: state.uri.queryParameters['phone'] ?? '',
        otpId: state.uri.queryParameters['otpId'] ?? '',
      ),
    ),
    GoRoute(path: AppRoutes.registerBusiness, builder: (_, _) => const RegisterBusinessScreen()),
    GoRoute(path: AppRoutes.businessStatus, builder: (_, _) => const BusinessStatusScreen()),
    GoRoute(
      path: AppRoutes.notifications,
      parentNavigatorKey: rootNavigatorKey,
      builder: (_, _) => const NotificationsScreen(),
    ),
    StatefulShellRoute.indexedStack(
      builder: (_, _, shell) => MainShell(navigationShell: shell),
      branches: [
        StatefulShellBranch(routes: [
          GoRoute(path: AppRoutes.dashboard, builder: (_, _) => const DashboardScreen()),
        ]),
        StatefulShellBranch(routes: [
          GoRoute(
            path: AppRoutes.products,
            builder: (_, _) => const ProductsScreen(),
            routes: [
              GoRoute(
                path: 'add',
                parentNavigatorKey: rootNavigatorKey,
                builder: (_, _) => const AddProductScreen(),
              ),
              GoRoute(
                path: ':id',
                parentNavigatorKey: rootNavigatorKey,
                builder: (_, state) => ProductDetailScreen(productId: state.pathParameters['id']!),
              ),
            ],
          ),
        ]),
        StatefulShellBranch(routes: [
          GoRoute(path: AppRoutes.qr, builder: (_, _) => const QrCodesScreen()),
        ]),
        StatefulShellBranch(routes: [
          GoRoute(path: AppRoutes.analytics, builder: (_, _) => const AnalyticsScreen()),
        ]),
        StatefulShellBranch(routes: [
          GoRoute(path: AppRoutes.account, builder: (_, _) => const AccountScreen()),
        ]),
      ],
    ),
  ],
  errorBuilder: (_, state) => Scaffold(
    body: Center(child: Text('Page not found: ${state.uri}')),
  ),
);
