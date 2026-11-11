/// App-wide config (WebAR, feature flags).
abstract final class AppConfig {
  /// WebAR dish viewer base — matches backend Embed/WebAr settings.
  static const String webArDishBaseUrl = String.fromEnvironment(
    'WEBAR_DISH_BASE_URL',
    defaultValue: 'http://localhost:5174/dish',
  );
}
