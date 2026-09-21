import '../../core/services/subscription_service.dart';
import '../../providers/business_provider.dart';
import '../../providers/notification_provider.dart';
import '../../providers/product_provider.dart';

Future<void> syncOwnerNotifications({
  required ProductProvider productProvider,
  required BusinessProvider businessProvider,
  required NotificationProvider notificationProvider,
  SubscriptionService? subscriptionService,
}) async {
  final subService = subscriptionService ?? SubscriptionService();
  final subscription = await subService.getCurrent();

  await notificationProvider.sync(
    products: productProvider.products,
    business: businessProvider.business,
    maxProducts: subscription?.maxProducts,
  );
}
