class EnvConfig {
  // Stripe Configuration
  static const String stripePublishableKey = 
      'pk_test_51RhyZy6fFqiEr2dukNkDAFO9m6PG4bYH24U2qXyJ7032ZNvsVPpU2PbI4f6IFdApSLr4vqo7qsOBOmN3yrHwqKdU00GRVSX8vT';
  static const String stripeMerchantId = 'merchant.com.khestra.africanCuisine';
  
  // Google Maps API Key
  static const String googleMapsApiKey = 'AIzaSyBvOkBwgGlbUiuS-oSiQuLymdqO6l6jIQ4';
  
  // App Configuration
  static const String appName = 'Taste of African Cuisine';
  
  // Environment check
  static bool get isProduction => const bool.fromEnvironment('dart.vm.product');
  static bool get isDevelopment => !isProduction;
}