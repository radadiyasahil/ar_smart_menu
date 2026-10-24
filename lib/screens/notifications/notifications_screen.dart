import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_routes.dart';
import '../../core/constants/app_spacing.dart';
import '../../providers/notification_provider.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => context.read<NotificationProvider>().fetchRemote());
  }

  static IconData _icon(OwnerNotificationType t) => switch (t) {
    OwnerNotificationType.productLive => Icons.celebration_rounded,
    OwnerNotificationType.productRejected => Icons.cancel_outlined,
    OwnerNotificationType.productReview => Icons.hourglass_top_rounded,
    OwnerNotificationType.businessApproved => Icons.verified_rounded,
    OwnerNotificationType.businessRejected => Icons.business_outlined,
    OwnerNotificationType.planLimit => Icons.workspace_premium_rounded,
    _ => Icons.info_outline_rounded,
  };

  static Color _color(OwnerNotificationType t) => switch (t) {
    OwnerNotificationType.productLive || OwnerNotificationType.businessApproved => AppColors.success,
    OwnerNotificationType.productRejected || OwnerNotificationType.businessRejected => AppColors.error,
    OwnerNotificationType.planLimit => AppColors.warning,
    OwnerNotificationType.productReview => AppColors.primaryOrange,
    _ => AppColors.info,
  };

  static String _time(DateTime d) {
    final diff = DateTime.now().difference(d);
    if (diff.inSeconds < 60) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return DateFormat('dd MMM').format(d);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Consumer<NotificationProvider>(
      builder: (context, notifs, _) {
        final items = notifs.notifications;

        return Scaffold(
          appBar: AppBar(
            title: const Text('Notifications'),
            actions: [
              if (items.isNotEmpty)
                TextButton(onPressed: notifs.markAllRead, child: const Text('Mark all read')),
            ],
          ),
          body: RefreshIndicator(
            onRefresh: notifs.fetchRemote,
            child: items.isEmpty
                ? ListView(children: [
                    SizedBox(
                      height: MediaQuery.of(context).size.height * 0.7,
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.notifications_none_rounded, size: 64, color: AppColors.primaryOrange.withValues(alpha: 0.45)),
                            const SizedBox(height: 12),
                            const Text('No notifications yet', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 6),
                            const Text('Alerts appear when admin approves, rejects, or publishes dishes.', textAlign: TextAlign.center, style: TextStyle(color: AppColors.mediumGray)),
                          ],
                        ),
                      ),
                    ),
                  ])
                : ListView.separated(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    itemCount: items.length,
                    separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm),
                    itemBuilder: (context, i) {
                      final n = items[i];
                      final c = _color(n.type);

                      return Material(
                        color: n.read ? (isDark ? AppColors.darkSurfaceElevated : Colors.white) : c.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                        clipBehavior: Clip.antiAlias,
                        child: InkWell(
                          onTap: () {
                            notifs.markRead(n.id);
                            if (n.productId?.isNotEmpty ?? false) {
                              context.push(AppRoutes.productDetail(n.productId!));
                            } else if (n.type == OwnerNotificationType.businessApproved || n.type == OwnerNotificationType.businessRejected) {
                              context.push(AppRoutes.account);
                            }
                          },
                          child: Container(
                            padding: const EdgeInsets.all(AppSpacing.md),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                              border: Border.all(color: n.read ? (isDark ? AppColors.darkBorder : AppColors.lightBorder) : c.withValues(alpha: 0.35), width: n.read ? 1 : 1.5),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(9),
                                  decoration: BoxDecoration(color: c.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(AppSpacing.radiusSm)),
                                  child: Icon(_icon(n.type), color: c, size: 20),
                                ),
                                const SizedBox(width: AppSpacing.md),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Expanded(child: Text(n.title, style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5, color: isDark ? Colors.white : AppColors.black))),
                                          Text(_time(n.createdAt), style: const TextStyle(fontSize: 11, color: AppColors.mediumGray)),
                                          if (!n.read) ...[
                                            const SizedBox(width: 6),
                                            Container(width: 7, height: 7, decoration: const BoxDecoration(color: AppColors.primaryOrange, shape: BoxShape.circle)),
                                          ],
                                        ],
                                      ),
                                      const SizedBox(height: 3),
                                      Text(n.body, style: TextStyle(fontSize: 12.5, height: 1.35, color: isDark ? Colors.white60 : AppColors.mediumGray)),
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
          ),
        );
      },
    );
  }
}
