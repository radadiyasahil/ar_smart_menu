import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../constants/app_routes.dart';
import '../../providers/business_provider.dart';

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

/// After login — cache first if available, then refresh in background.
Future<void> navigateOwnerAfterAuth(BuildContext context) async {
  final businessProvider = context.read<BusinessProvider>();

  if (businessProvider.isLoaded && businessProvider.hasBusiness) {
    routeOwnerFromCache(context, businessProvider);
    unawaited(businessProvider.refreshProfileInBackground());
    return;
  }

  await businessProvider.loadProfile(forceNetwork: true);
  if (!context.mounted) return;
  routeOwnerFromCache(context, businessProvider);
}
