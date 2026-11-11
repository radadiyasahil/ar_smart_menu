import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_routes.dart';
import '../../providers/auth_provider.dart';
import '../../providers/business_provider.dart';
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
import '../../screens/billing/table_billing_screen.dart';
import '../../screens/subscription/subscription_screen.dart';
import '../../widgets/navigation/main_shell.dart';

final GlobalKey<NavigatorState> rootNavigatorKey = GlobalKey<NavigatorState>();
final GlobalKey<NavigatorState> shellNavigatorKey = GlobalKey<NavigatorState>();

/// App-wide router configuration using go_router.
final GoRouter appRouter = GoRouter(
  navigatorKey: rootNavigatorKey,
  initialLocation: AppRoutes.splash,
  redirect: (BuildContext context, GoRouterState state) {
    try {
      final auth = context.read<AuthProvider>();
      final business = context.read<BusinessProvider>();

      final path = state.uri.path;
      final isAuthRoute = path == AppRoutes.login ||
          path == AppRoutes.otp ||
          path == AppRoutes.splash ||
          path == AppRoutes.language;

      if (!auth.isAuthenticated) {
        return null;
      }

      // Authenticated with no business registered
      if (!business.hasBusiness) {
        if (path != AppRoutes.registerBusiness && !isAuthRoute && path != AppRoutes.account) {
          return AppRoutes.registerBusiness;
        }
        return null;
      }

      // Authenticated but business is unapproved / rejected / suspended
      if (!business.isActive) {
        final isOperational = path == AppRoutes.dashboard ||
            path.startsWith(AppRoutes.products) ||
            path == AppRoutes.billing ||
            path == AppRoutes.qr ||
            path == AppRoutes.analytics ||
            path == AppRoutes.notifications ||
            path == AppRoutes.subscription;

        if (isOperational) {
          return AppRoutes.businessStatus;
        }
      }
    } catch (_) {
      // In case context is not ready during bootstrapping
    }
    return null;
  },
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
    GoRoute(
      path: AppRoutes.subscription,
      parentNavigatorKey: rootNavigatorKey,
      builder: (_, _) => const SubscriptionScreen(),
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
          GoRoute(path: AppRoutes.billing, builder: (_, _) => const TableBillingScreen()),
        ]),
        StatefulShellBranch(routes: [
          GoRoute(path: AppRoutes.qr, builder: (_, _) => const QrCodesScreen()),
        ]),
        StatefulShellBranch(routes: [
          GoRoute(path: AppRoutes.analytics, builder: (_, _) => const AnalyticsScreen()),
        ]),
        StatefulShellBranch(routes: [
          GoRoute(
            path: AppRoutes.account,
            builder: (_, state) => AccountScreen(
              key: ValueKey('account_${state.uri.queryParameters['tab'] ?? ''}'),
              initialTab: state.uri.queryParameters['tab'],
            ),
          ),
        ]),
      ],
    ),
  ],
  errorBuilder: (_, state) => Scaffold(
    body: Center(child: Text('Page not found: ${state.uri}')),
  ),
);
