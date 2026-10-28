import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../constants/app_routes.dart';
import '../../providers/business_provider.dart';
import '../../providers/product_provider.dart';

/// Routes owner using cached profile — no network wait.
void routeOwnerFromCache(BuildContext context, BusinessProvider provider) {
  if (!provider.hasBusiness) {
    context.go(AppRoutes.registerBusiness);
    return;
  }

  if (provider.isPendingApproval || provider.isRejected) {
    context.go(AppRoutes.businessStatus);
    return;
  }

  if (provider.isActive) {
    context.go(AppRoutes.dashboard);
    return;
  }

  context.go(AppRoutes.businessStatus);
}

/// After login — always load fresh profile and products for the authenticated account.
Future<void> navigateOwnerAfterAuth(BuildContext context) async {
  final businessProvider = context.read<BusinessProvider>();
  final productProvider = context.read<ProductProvider>();

  await businessProvider.loadProfile(forceNetwork: true);
  if (!context.mounted) return;
  unawaited(productProvider.loadProducts(force: true));
  routeOwnerFromCache(context, businessProvider);
}
