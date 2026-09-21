/// Central route path constants for go_router navigation.
class AppRoutes {
  AppRoutes._();

  static const String splash = '/';
  static const String language = '/language';
  static const String login = '/login';
  static const String otp = '/otp';
  static const String registerBusiness = '/register-business';
  static const String businessStatus = '/business-status';
  static const String dashboard = '/dashboard';
  static const String products = '/products';
  static const String addProduct = '/products/add';
  static String productDetail(String id) => '/products/$id';
  static const String qr = '/qr';
  static const String analytics = '/analytics';
  static const String account = '/account';
  static const String notifications = '/notifications';
}
