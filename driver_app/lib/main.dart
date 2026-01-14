import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/gestures.dart' show PointerDeviceKind;
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

import 'firebase_options.dart';

// Theme
import 'theme/app_theme.dart';

// Screens
import 'screens/splash_screen.dart';
import 'package:driver_app/screens/auth_screen.dart';
import 'package:driver_app/screens/onboarding_screen.dart';
import 'package:driver_app/screens/home_screen.dart';
import 'package:driver_app/screens/pending_approval_screen.dart';
import 'package:driver_app/screens/verify_email_screen.dart';
import 'package:driver_app/screens/login_screen.dart';
import 'package:driver_app/screens/signup_screen.dart';
import 'package:driver_app/screens/phone_login_screen.dart';
import 'package:driver_app/screens/driver_dashboard_screen.dart';

// Services
import 'services/storage_service.dart';
import 'services/push_notification_service.dart';

// Background message handler (must be top-level function)
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  print('Handling background message: ${message.messageId}');
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Edge-to-edge (status/nav bars transparent where possible)
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarIconBrightness: Brightness.dark,
    ),
  );

  // Initialize core services
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  
  // Set up background message handler
  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
  
  await StorageService.init();
  
  // Initialize push notifications (with error handling)
  try {
    await PushNotificationService.initialize();
  } catch (e) {
    print('Failed to initialize push notifications: $e');
    // Continue without push notifications
  }

  runApp(const DriverApp());
}

/// Optional: access Navigator anywhere
final GlobalKey<NavigatorState> appNavigatorKey = GlobalKey<NavigatorState>();

/// Route observer (subscribe in pages with RouteAware if you need didPopNext/didPush)
// ignore: prefer_const_constructors
final RouteObserver<PageRoute<dynamic>> routeObserver =
    RouteObserver<PageRoute<dynamic>>();

class DriverApp extends StatelessWidget {
  const DriverApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Taste of African Cuisine Driver',
      navigatorKey: appNavigatorKey,
      navigatorObservers: [routeObserver],
      themeMode: ThemeMode.system,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.lightTheme, // swap to AppTheme.darkTheme when ready
      // Global scroll behavior (no glow; supports mouse/trackpad/stylus)
      scrollBehavior: const _AppScrollBehavior(),

      // Named routes for clean navigation
      initialRoute: Routes.splash,
      routes: {
        Routes.splash: (_) => const SplashScreen(),
        Routes.onboarding: (_) => const OnboardingScreen(),
        Routes.auth: (_) => const AuthScreen(),
        Routes.login: (_) => const LoginScreen(),
        Routes.signup: (_) => const SignupScreen(),
        Routes.phoneLogin: (_) => const PhoneLoginScreen(),
        Routes.verifyEmail: (_) => const VerifyEmailScreen(),
        Routes.pendingApproval: (_) => const PendingApprovalScreen(),
        Routes.home: (_) => const HomeScreen(),
        Routes.dashboard: (_) => const DriverDashboardScreen(),
      },

      // Nice fade for unknown routes (keeps UX smooth)
      onUnknownRoute: (settings) => _fade(settings, const SplashScreen()),
      debugShowCheckedModeBanner: false,
      // Optional: clamp extreme system text scaling so layouts don't break
      builder: (context, child) {
        final media = MediaQuery.of(context);
        return MediaQuery(
          data: media.copyWith(
            // cap to 1.2 to keep UI tidy; tweak as you like
            textScaler: media.textScaler.clamp(
              minScaleFactor: 0.85,
              maxScaleFactor: 1.2,
            ),
          ),
          child: child ?? const SizedBox.shrink(),
        );
      },
    );
  }
}

/// Centralized route names
abstract class Routes {
  static const splash = '/';
  static const onboarding = '/onboarding';
  static const auth = '/auth';
  static const login = '/login';
  static const signup = '/signup';
  static const phoneLogin = '/phone-login';
  static const verifyEmail = '/verify-email';
  static const pendingApproval = '/pending-approval';
  static const home = '/home';
  static const dashboard = '/dashboard';
}

/// Smooth fade route (nice for onUnknownRoute or special cases)
PageRoute _fade(RouteSettings s, Widget child) {
  return PageRouteBuilder(
    settings: s,
    pageBuilder: (_, __, ___) => child,
    transitionsBuilder: (_, a, __, c) => FadeTransition(opacity: a, child: c),
    transitionDuration: const Duration(milliseconds: 250),
  );
}

/// Global scroll behavior: removes glow & supports mouse/trackpad/stylus drag
class _AppScrollBehavior extends MaterialScrollBehavior {
  const _AppScrollBehavior();

  @override
  Set<PointerDeviceKind> get dragDevices => {
    PointerDeviceKind.touch,
    PointerDeviceKind.mouse,
    PointerDeviceKind.stylus,
    PointerDeviceKind.trackpad,
    PointerDeviceKind.unknown,
  };
}
