import 'package:flutter/material.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';

import 'firebase_options.dart';
import 'config/env_config.dart';

import 'package:african_cuisine/provider/cart_provider.dart';
import 'package:african_cuisine/provider/favorites_provider.dart';
import 'package:african_cuisine/delivery/delivery_fee_provider.dart';
import 'package:african_cuisine/provider/notification_provider.dart';
import 'package:african_cuisine/notification/notification_service.dart';
import 'package:african_cuisine/services/restaurant_hours_service.dart';
import 'package:african_cuisine/services/order_status_service.dart';
import 'package:african_cuisine/services/review_notification_service.dart';

// Screens
import 'package:african_cuisine/logins/splash_screen.dart';
import 'package:african_cuisine/root_page.dart';
import 'package:african_cuisine/logins/auth_gate.dart';
import 'package:african_cuisine/logins/login_choice_page.dart';
import 'package:african_cuisine/logins/login_page.dart';
import 'package:african_cuisine/logins/sign_up_page.dart';
import 'package:african_cuisine/logins/phone_auth_page.dart';

import 'package:african_cuisine/logins/verify_account_page.dart';

import 'package:african_cuisine/logins/onboarding_page.dart';
import 'package:african_cuisine/payment/payment_page.dart';
import 'package:african_cuisine/home/main_home_page.dart';
import 'package:african_cuisine/payment/confirmation_page.dart';
import 'package:african_cuisine/orders/order_detail_page.dart';
import 'package:african_cuisine/orders/order_history_page.dart';
import 'package:african_cuisine/orders/reorder_page.dart';
import 'package:african_cuisine/support/call_support_page.dart';
import 'package:african_cuisine/home/cart_page.dart';
import 'package:african_cuisine/logins/link_phone_page.dart';
import 'package:african_cuisine/notification/notification_page.dart';
import 'package:african_cuisine/support/live_chat_support_page.dart';

// 🔑 Used to access context outside widgets (e.g. inside initState)
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 🎯 Stripe Setup
  Stripe.publishableKey = EnvConfig.stripePublishableKey;
  Stripe.merchantIdentifier = EnvConfig.stripeMerchantId;
  await Stripe.instance.applySettings();

  // 🔥 Firebase Init
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // ⏯️ Launch App
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => CartProvider()),
        ChangeNotifierProvider(create: (_) => FavoritesProvider()),
        ChangeNotifierProvider(create: (_) => DeliveryFeeProvider()),
        ChangeNotifierProvider(create: (_) => NotificationProvider()),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  void initState() {
    super.initState();

    // 🧠 Wait for widget tree to be built before using context
    Future.delayed(Duration.zero, () async {
      final context = navigatorKey.currentContext!;
      // 🛎️ Start listening to notifications
      Provider.of<NotificationProvider>(
        context,
        listen: false,
      ).startListeningToNotifications();

      // 🔔 Initialize FCM or notification logic
      await NotificationService.init(context);

      // 🕒 Start restaurant hours auto-schedule
      RestaurantHoursService().startAutoSchedule();

      // 📧 Start order status monitoring for email notifications
      OrderStatusService().startListening();

      // ⭐ Check for review notifications
      ReviewNotificationService.checkForReviewNotifications(context);
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey,
      debugShowCheckedModeBanner: false,
      title: EnvConfig.appName,
      theme: _buildAppTheme(),
      darkTheme: _buildDarkTheme(),
      themeMode: ThemeMode.light,
      home: const SplashScreen(),
      routes: {
        '/root': (context) => const RootPage(),
        '/auth': (context) => const AuthGate(),
        '/choice': (context) => const LoginChoicePage(),
        '/login': (context) => const LoginPage(),
        '/signup': (context) => const SignupPage(),
        '/verify-account': (context) => const VerifyAccountPage(),
        '/payment': (context) => const PaymentPage(),
        '/home': (context) => const MainFoodPage(),
        '/callSupport': (context) => const CallSupportPage(),
        '/cart': (context) => const CartPage(),
        '/link-phone': (context) => const LinkPhonePage(),
        '/notifications': (context) => const NotificationPage(),
        '/support': (context) => const LiveChatSupportPage(),
        '/onboarding': (context) => const OnboardingPage(),
        '/orderHistory': (context) => const OrderHistoryPage(),
      },
      onGenerateRoute: _generateRoute,
    );
  }

  Route<dynamic>? _generateRoute(RouteSettings settings) {
    switch (settings.name) {
      case '/confirmation':
        final orderId = settings.arguments as String;
        return _animatedRoute(ConfirmationPage(orderId: orderId));
      case '/orderDetails':
        final args = settings.arguments as Map<String, dynamic>;
        if (args.containsKey('orderId')) {
          // Handle orderId-only navigation from notifications
          final orderId = args['orderId'] as String;
          return _animatedRoute(OrderDetailPage.byId(orderId));
        } else {
          // Handle full orderData navigation
          final orderData = args;
          return _animatedRoute(OrderDetailPage(orderData: orderData));
        }
      case '/orderDetail':
        // Handle notification tap navigation
        final args = settings.arguments as Map<String, dynamic>;
        final orderId = args['orderId'] as String;
        return _animatedRoute(OrderDetailPage.byId(orderId));
      case '/reorder':
        final orderId = settings.arguments as String;
        return _animatedRoute(ReorderPage(orderId: orderId));
      default:
        return MaterialPageRoute(
          builder: (_) =>
              const Scaffold(body: Center(child: Text('404 - Page not found'))),
        );
    }
  }

  PageRouteBuilder _animatedRoute(Widget page) {
    return PageRouteBuilder(
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionsBuilder: (context, animation, _, child) {
        const begin = Offset(1.0, 0.0);
        const end = Offset.zero;
        final tween = Tween(
          begin: begin,
          end: end,
        ).chain(CurveTween(curve: Curves.ease));
        return SlideTransition(position: animation.drive(tween), child: child);
      },
      transitionDuration: const Duration(milliseconds: 300),
    );
  }

  ThemeData _buildAppTheme() => ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: Colors.deepOrange,
      brightness: Brightness.light,
    ),
    scaffoldBackgroundColor: const Color(0xFFFDF1EC),
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.deepOrange,
      elevation: 0,
      iconTheme: IconThemeData(color: Colors.white),
      titleTextStyle: TextStyle(
        color: Colors.white,
        fontSize: 20,
        fontWeight: FontWeight.bold,
      ),
      centerTitle: true,
    ),
    inputDecorationTheme: InputDecorationTheme(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      filled: true,
      fillColor: Colors.grey.shade100,
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.deepOrange,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    ),
  );

  ThemeData _buildDarkTheme() => ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: Colors.deepOrange,
      brightness: Brightness.dark,
    ),
    scaffoldBackgroundColor: Colors.black,
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.black,
      elevation: 0,
      iconTheme: IconThemeData(color: Colors.white),
      titleTextStyle: TextStyle(
        color: Colors.white,
        fontSize: 20,
        fontWeight: FontWeight.bold,
      ),
      centerTitle: true,
    ),
  );
}
