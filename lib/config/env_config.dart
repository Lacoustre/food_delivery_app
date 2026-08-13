class EnvConfig {
  // Stripe Configuration
  static const String stripePublishableKey = 
      'pk_test_51RhyZy6fFqiEr2dukNkDAFO9m6PG4bYH24U2qXyJ7032ZNvsVPpU2PbI4f6IFdApSLr4vqo7qsOBOmN3yrHwqKdU00GRVSX8vT';
  static const String stripeMerchantId = 'merchant.com.khestra.africanCuisine';
  
  // Google Maps API Key
  static const String googleMapsApiKey = 'AIzaSyBvOkBwgGlbUiuS-oSiQuLymdqO6l6jIQ4';

  // Supabase Configuration
  static const String supabaseUrl = 'https://peimbksjyjcxmurwwmnn.supabase.co';
  static const String supabaseAnonKey =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InBlaW1ia3NqeWpjeG11cnd3bW5uIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODY0OTkxNDgsImV4cCI6MjEwMjA3NTE0OH0.UE2yZ04qKvjyz15W259FiG4KFw-wNK8SOAD50ywiMeE';

  // App Configuration
  static const String appName = 'Taste of African Cuisine';
  
  // Environment check
  static bool get isProduction => const bool.fromEnvironment('dart.vm.product');
  static bool get isDevelopment => !isProduction;
}