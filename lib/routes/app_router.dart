import 'package:flutter/material.dart';

import 'package:go_router/go_router.dart';



import '../../screens/notifications/notifications_screen.dart';

import '../../screens/account/account_screen.dart';

import '../../screens/analytics/analytics_screen.dart';

import '../../screens/auth/language_selection_screen.dart';

import '../../screens/auth/login_screen.dart';

import '../../screens/auth/otp_screen.dart';

import '../../screens/auth/splash_screen.dart';

import '../../screens/business/business_status_screen.dart';

import '../../screens/business/register_business_screen.dart';

import '../../screens/dashboard/dashboard_screen.dart';

import '../../screens/products/add_product_screen.dart';
import '../../screens/products/product_detail_screen.dart';
import '../../screens/products/products_screen.dart';

import '../../screens/qr/qr_codes_screen.dart';

import '../../widgets/navigation/main_shell.dart';

import '../core/constants/app_routes.dart';



/// Global navigator key for programmatic navigation when needed.

final GlobalKey<NavigatorState> rootNavigatorKey = GlobalKey<NavigatorState>();



/// Shell navigator key for bottom navigation tabs.

final GlobalKey<NavigatorState> shellNavigatorKey = GlobalKey<NavigatorState>();



/// App-wide router configuration using go_router.

final GoRouter appRouter = GoRouter(

  navigatorKey: rootNavigatorKey,

  initialLocation: AppRoutes.splash,

  routes: [

    GoRoute(

      path: AppRoutes.splash,

      builder: (context, state) => const SplashScreen(),

    ),

    GoRoute(

      path: AppRoutes.language,

      builder: (context, state) => const LanguageSelectionScreen(),

    ),

    GoRoute(

      path: AppRoutes.login,

      builder: (context, state) => const LoginScreen(),

    ),

    GoRoute(

      path: AppRoutes.otp,

      builder: (context, state) {

        final phone = state.uri.queryParameters['phone'] ?? '';

        final otpId = state.uri.queryParameters['otpId'] ?? '';

        return OtpScreen(phoneNumber: phone, otpId: otpId);

      },

    ),

    GoRoute(

      path: AppRoutes.registerBusiness,

      builder: (context, state) => const RegisterBusinessScreen(),

    ),

    GoRoute(

      path: AppRoutes.businessStatus,

      builder: (context, state) => const BusinessStatusScreen(),

    ),

    GoRoute(
      path: AppRoutes.notifications,
      parentNavigatorKey: rootNavigatorKey,
      builder: (context, state) => const NotificationsScreen(),
    ),



    StatefulShellRoute.indexedStack(

      builder: (context, state, navigationShell) {

        return MainShell(navigationShell: navigationShell);

      },

      branches: [

        StatefulShellBranch(

          routes: [

            GoRoute(

              path: AppRoutes.dashboard,

              builder: (context, state) => const DashboardScreen(),

            ),

          ],

        ),

        StatefulShellBranch(

          routes: [

            GoRoute(

              path: AppRoutes.products,

              builder: (context, state) => const ProductsScreen(),

              routes: [

                GoRoute(

                  path: 'add',

                  parentNavigatorKey: rootNavigatorKey,

                  builder: (context, state) => const AddProductScreen(),

                ),

                GoRoute(

                  path: ':id',

                  parentNavigatorKey: rootNavigatorKey,

                  builder: (context, state) => ProductDetailScreen(

                    productId: state.pathParameters['id']!,

                  ),

                ),

              ],

            ),

          ],

        ),

        StatefulShellBranch(

          routes: [

            GoRoute(

              path: AppRoutes.qr,

              builder: (context, state) => const QrCodesScreen(),

            ),

          ],

        ),

        StatefulShellBranch(

          routes: [

            GoRoute(

              path: AppRoutes.analytics,

              builder: (context, state) => const AnalyticsScreen(),

            ),

          ],

        ),

        StatefulShellBranch(

          routes: [

            GoRoute(

              path: AppRoutes.account,

              builder: (context, state) => const AccountScreen(),

            ),

          ],

        ),

      ],

    ),

  ],

  errorBuilder: (context, state) => Scaffold(

    body: Center(

      child: Text('Page not found: ${state.uri}'),

    ),

  ),

);


