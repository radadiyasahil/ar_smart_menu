import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_routes.dart';
import '../../core/constants/app_spacing.dart';
import '../../providers/notification_provider.dart';

/// In-app notification center for owners.
class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  IconData _iconFor(OwnerNotificationType type) {
    switch (type) {
      case OwnerNotificationType.productLive:
        return Icons.celebration_outlined;
      case OwnerNotificationType.productRejected:
        return Icons.error_outline;
      case OwnerNotificationType.productReview:
        return Icons.hourglass_top_outlined;
      case OwnerNotificationType.businessApproved:
        return Icons.verified_outlined;
      case OwnerNotificationType.businessRejected:
        return Icons.business_outlined;
      case OwnerNotificationType.planLimit:
        return Icons.workspace_premium_outlined;
      case OwnerNotificationType.info:
        return Icons.info_outline;
    }
  }

  Color _colorFor(OwnerNotificationType type) {
    switch (type) {
      case OwnerNotificationType.productLive:
      case OwnerNotificationType.businessApproved:
        return AppColors.success;
      case OwnerNotificationType.productRejected:
      case OwnerNotificationType.businessRejected:
        return AppColors.error;
      case OwnerNotificationType.planLimit:
        return AppColors.warning;
      default:
        return AppColors.info;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<NotificationProvider>(
      builder: (context, notifications, _) {
        final items = notifications.notifications;

        return Scaffold(
          appBar: AppBar(
            title: const Text('Notifications'),
            actions: [
              if (items.isNotEmpty)
                TextButton(
                  onPressed: notifications.markAllRead,
                  child: const Text('Mark all read'),
                ),
            ],
          ),
          body: items.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.notifications_none_outlined,
                          size: 64,
                          color: AppColors.primaryOrange.withValues(alpha: 0.45),
                        ),
                        const SizedBox(height: AppSpacing.md),
                        const Text(
                          'No notifications yet',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        const Text(
                          'We\'ll alert you when products go live, get rejected, or your plan limit is near.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: AppColors.mediumGray),
                        ),
                      ],
                    ),
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  itemCount: items.length,
                  separatorBuilder: (_, _) =>
                      const SizedBox(height: AppSpacing.sm),
                  itemBuilder: (context, index) {
                    final item = items[index];
                    final color = _colorFor(item.type);
                    return Material(
                      color: item.read
                          ? Theme.of(context).colorScheme.surface
                          : color.withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                      clipBehavior: Clip.antiAlias,
                      child: InkWell(
                        onTap: () {
                          notifications.markRead(item.id);
                          if (item.productId != null) {
                            context.push(
                              AppRoutes.productDetail(item.productId!),
                            );
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.all(AppSpacing.md),
                          decoration: BoxDecoration(
                            borderRadius:
                                BorderRadius.circular(AppSpacing.radiusMd),
                            border: Border.all(
                              color: item.read
                                  ? AppColors.borderGray
                                  : color.withValues(alpha: 0.25),
                            ),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: color.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(
                                    AppSpacing.radiusSm,
                                  ),
                                ),
                                child: Icon(
                                  _iconFor(item.type),
                                  color: color,
                                  size: 22,
                                ),
                              ),
                              const SizedBox(width: AppSpacing.md),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            item.title,
                                            style: TextStyle(
                                              fontWeight: FontWeight.w600,
                                              color: item.read
                                                  ? AppColors.mediumGray
                                                  : null,
                                            ),
                                          ),
                                        ),
                                        if (!item.read)
                                          Container(
                                            width: 8,
                                            height: 8,
                                            decoration: BoxDecoration(
                                              color: AppColors.primaryOrange,
                                              shape: BoxShape.circle,
                                            ),
                                          ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      item.body,
                                      style: const TextStyle(
                                        fontSize: 13,
                                        height: 1.4,
                                        color: AppColors.mediumGray,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
        );
      },
    );
  }
}
