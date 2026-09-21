import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_routes.dart';
import '../../core/constants/app_spacing.dart';
import '../../models/business_model.dart';
import '../../providers/business_provider.dart';
import '../../widgets/common/gradient_card.dart';
import '../../widgets/common/primary_button.dart';

/// Shows business approval status after registration.
class BusinessStatusScreen extends StatelessWidget {
  const BusinessStatusScreen({super.key});

  Color _statusColor(BusinessStatus status) {
    switch (status) {
      case BusinessStatus.active:
        return AppColors.success;
      case BusinessStatus.pendingApproval:
        return AppColors.warning;
      case BusinessStatus.rejected:
        return AppColors.error;
      case BusinessStatus.suspended:
        return AppColors.mediumGray;
    }
  }

  IconData _statusIcon(BusinessStatus status) {
    switch (status) {
      case BusinessStatus.active:
        return Icons.check_circle_outline;
      case BusinessStatus.pendingApproval:
        return Icons.hourglass_top;
      case BusinessStatus.rejected:
        return Icons.cancel_outlined;
      case BusinessStatus.suspended:
        return Icons.pause_circle_outline;
    }
  }

  String _statusMessage(BusinessModel? business) {
    if (business == null) return 'No business registered yet.';
    switch (business.status) {
      case BusinessStatus.pendingApproval:
        return 'Your business "${business.businessName}" is waiting for admin approval. '
            'We will notify you once it is reviewed.';
      case BusinessStatus.active:
        return 'Your business is approved! You can now add products and generate QR codes.';
      case BusinessStatus.rejected:
        return business.rejectionReason ??
            'Your business was not approved. Please update details and contact support.';
      case BusinessStatus.suspended:
        return 'Your business account is suspended. Contact support for help.';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<BusinessProvider>(
      builder: (context, provider, _) {
        final business = provider.business;
        final status = business?.status ?? BusinessStatus.pendingApproval;

        return Scaffold(
          appBar: AppBar(
            title: const Text('Business status'),
            actions: [
              TextButton(
                onPressed: () => context.go(AppRoutes.account),
                child: const Text('Account'),
              ),
            ],
          ),
          body: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  GradientCard(
                    child: Column(
                      children: [
                        Icon(
                          _statusIcon(status),
                          size: 56,
                          color: AppColors.white,
                        ),
                        const SizedBox(height: AppSpacing.md),
                        Text(
                          status.label,
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: AppColors.white,
                          ),
                        ),
                        if (business != null) ...[
                          const SizedBox(height: AppSpacing.sm),
                          Text(
                            business.businessName,
                            style: TextStyle(
                              color: AppColors.white.withValues(alpha: 0.9),
                            ),
                          ),
                          Text(
                            '${business.businessType.label} • ${business.city}',
                            style: TextStyle(
                              fontSize: 13,
                              color: AppColors.white.withValues(alpha: 0.8),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    decoration: BoxDecoration(
                      color: _statusColor(status).withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                      border: Border.all(
                        color: _statusColor(status).withValues(alpha: 0.3),
                      ),
                    ),
                    child: Text(
                      _statusMessage(business),
                      style: const TextStyle(height: 1.5),
                    ),
                  ),
                  const Spacer(),
                  if (provider.isActive)
                    PrimaryButton(
                      label: 'Go to dashboard',
                      icon: Icons.dashboard_outlined,
                      onPressed: () => context.go(AppRoutes.dashboard),
                    )
                  else ...[
                    PrimaryButton(
                      label: provider.isLoading ? 'Checking...' : 'Refresh status',
                      icon: Icons.refresh,
                      isLoading: provider.isLoading,
                      onPressed: () async {
                        await provider.refreshStatus();
                        if (context.mounted && provider.isActive) {
                          context.go(AppRoutes.dashboard);
                        }
                      },
                    ),
                    const SizedBox(height: AppSpacing.md),
                    OutlinedButton(
                      onPressed: () => context.go(AppRoutes.account),
                      child: const Text('Complete KYC while waiting'),
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
