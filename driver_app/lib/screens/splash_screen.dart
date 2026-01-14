import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart'; // for defaultTargetPlatform
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';

import 'package:driver_app/screens/auth_screen.dart';
import 'package:driver_app/screens/onboarding_screen.dart';
import 'package:driver_app/screens/home_screen.dart';
import 'package:driver_app/screens/pending_approval_screen.dart';
import 'package:driver_app/screens/verify_email_screen.dart';
import '../widgets/app_logo.dart';
import '../services/storage_service.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  static const _kOnboardingSeen = 'onboarding_seen_v1';
  static const Duration _minSplashDuration = Duration(milliseconds: 2000);
  static const Duration _maxWaitDuration = Duration(seconds: 10);

  bool _errored = false;
  String? _errorText;
  String _statusText = 'Initializing...';
  double _progress = 0.0; // for percentage text

  late AnimationController _logoAnimationController;
  late AnimationController _progressAnimationController;
  late Animation<double> _logoScaleAnimation;
  late Animation<double> _logoOpacityAnimation;
  late Animation<double> _progressAnimation; // drives the progress bar [0..1]

  Timer? _timeoutTimer;
  final Stopwatch _stopwatch = Stopwatch();

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    WidgetsBinding.instance.addPostFrameCallback((_) => _route());
  }

  void _initializeAnimations() {
    _logoAnimationController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    _progressAnimationController = AnimationController(
      value: 0.0, // start at 0 for the progress bar
      vsync: this,
    );

    _logoScaleAnimation = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(
        parent: _logoAnimationController,
        curve: Curves.elasticOut,
      ),
    );

    _logoOpacityAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _logoAnimationController,
        curve: const Interval(0.0, 0.6, curve: Curves.easeIn),
      ),
    );

    // This animation simply mirrors the controller's value (0..1) with a curve.
    _progressAnimation = CurvedAnimation(
      parent: _progressAnimationController,
      curve: Curves.easeInOut,
    );

    _logoAnimationController.forward();
  }

  @override
  void dispose() {
    _logoAnimationController.dispose();
    _progressAnimationController.dispose();
    _timeoutTimer?.cancel();
    super.dispose();
  }

  /// Smoothly animates the progress bar to [progress] and updates the status text.
  void _updateProgress(double progress, String status) {
    if (!mounted) return;
    setState(() {
      _progress = progress.clamp(0.0, 1.0);
      _statusText = status;
    });
    // Animate the controller TO the new progress value.
    _progressAnimationController.animateTo(
      _progress,
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeInOut,
    );
  }

  Future<void> _route() async {
    _stopwatch.start();

    // Set timeout -> show error UI, but don't crash the flow.
    _timeoutTimer = Timer(_maxWaitDuration, () {
      if (mounted && !_errored) {
        setState(() {
          _errored = true;
          _errorText =
              'Connection timeout. Please check your internet connection.';
        });
      }
    });

    try {
      _updateProgress(0.1, 'Loading preferences...');

      // 1) Onboarding flag - with retry logic
      bool seenOnboarding = false;
      for (int retry = 0; retry < 3; retry++) {
        try {
          await Future<void>.delayed(const Duration(milliseconds: 100));
          final prefs = await SharedPreferences.getInstance();
          seenOnboarding = prefs.getBool(_kOnboardingSeen) ?? false;
          break;
        } on PlatformException catch (e) {
          debugPrint('SharedPreferences attempt ${retry + 1} failed: $e');
          if (retry == 2) {
            debugPrint('SharedPreferences unavailable after 3 attempts: $e');
            seenOnboarding = false;
          } else {
            await Future.delayed(Duration(milliseconds: 200 * (retry + 1)));
          }
        } catch (e) {
          // Fallback on any unexpected error.
          debugPrint('SharedPreferences unexpected error: $e');
          seenOnboarding = false;
          break;
        }
      }

      _updateProgress(0.3, 'Checking authentication...');

      // 2) Firebase Auth with reload
      final auth = FirebaseAuth.instance;
      try {
        await auth.currentUser?.reload();
      } catch (e) {
        debugPrint('Failed to reload user: $e');
      }

      final user = auth.currentUser;

      _updateProgress(0.5, 'Verifying session...');

      // 3) No session → onboarding/auth
      if (user == null) {
        await _ensureMinimumSplashTime();
        if (!mounted) return;
        _navigateToScreen(
          seenOnboarding ? const AuthScreen() : const OnboardingScreen(),
        );
        return;
      }

      _updateProgress(0.6, 'Checking email verification...');

      // 4) Email verify gate only for email/password accounts
      final usesEmailPassword =
          user.providerData.any((p) => p.providerId == 'password') &&
          user.email != null;
      if (usesEmailPassword && !user.emailVerified) {
        await _ensureMinimumSplashTime();
        if (!mounted) return;
        _navigateToScreen(const VerifyEmailScreen());
        return;
      }

      _updateProgress(0.7, 'Setting up driver profile...');

      // 5) Ensure driver doc exists with better error handling
      await _ensureDriverDocument(user);

      _updateProgress(0.8, 'Checking approval status...');

      // 6) Check cached approval status first
      final cachedStatus = StorageService.getDriverApprovalStatus();
      if (cachedStatus == 'approved') {
        await _ensureMinimumSplashTime();
        if (!mounted) return;
        if (_errored) return; // don't navigate if we already show an error
        _navigateToScreen(const HomeScreen());
        return;
      }

      _updateProgress(0.9, 'Loading profile data...');

      // 7) Read status from Firestore with enhanced error handling
      final status = await _getDriverApprovalStatus(user.uid);

      _updateProgress(1.0, 'Complete!');

      // Cache the status
      await StorageService.setDriverApprovalStatus(status);

      await _ensureMinimumSplashTime();
      if (!mounted) return;
      if (_errored) return; // avoid surprising navigation after timeout error

      if (status == 'approved') {
        _navigateToScreen(const HomeScreen());
      } else {
        _navigateToScreen(const PendingApprovalScreen());
      }
    } catch (e, stackTrace) {
      debugPrint('Splash screen error: $e');
      debugPrint('Stack trace: $stackTrace');

      if (!mounted) return;
      setState(() {
        _errored = true;
        _errorText = _getUserFriendlyError(e);
      });
    } finally {
      _timeoutTimer?.cancel();
    }
  }

  Future<void> _ensureDriverDocument(User user) async {
    final fs = FirebaseFirestore.instance;
    final ref = fs.collection('drivers').doc(user.uid);

    // Check if document exists first with timeout
    DocumentSnapshot<Map<String, dynamic>>? existingDoc;
    try {
      existingDoc = await ref.get().timeout(
        const Duration(seconds: 5),
        onTimeout: () => throw TimeoutException('Document check timed out'),
      );
    } on FirebaseException catch (e) {
      if (e.code == 'permission-denied') {
        // Document might exist but we can't read it due to security rules
        debugPrint(
          'Permission denied reading driver doc - might already exist',
        );
        return;
      }
      rethrow;
    } on TimeoutException {
      debugPrint('Timeout checking driver document existence');
      throw Exception('Connection timeout while checking profile');
    }

    // Only create if document doesn't exist
    if (existingDoc == null || !existingDoc.exists) {
      final minimal = <String, dynamic>{
        'userId': user.uid,
        'fullName': (user.displayName?.trim().isNotEmpty == true)
            ? user.displayName!.trim()
            : (user.email ?? '—').split('@').first,
        'email': user.email ?? '—',
        'phone': user.phoneNumber ?? '—',
        'approvalStatus': 'pending',
        'isActive': false,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'source': 'splash-bootstrap',
        'role': 'driver',
        'appVersion': '1.0.0', // Add app version for debugging
        'platform': defaultTargetPlatform.name, // no need for BuildContext
      };

      try {
        await ref
            .set(minimal, SetOptions(merge: true))
            .timeout(
              const Duration(seconds: 8),
              onTimeout: () =>
                  throw TimeoutException('Document creation timed out'),
            );
      } on FirebaseException catch (e) {
        if (e.code == 'permission-denied') {
          // Likely an update denial when doc already exists → safe to ignore.
          debugPrint(
            'Permission denied creating driver doc - might already exist',
          );
        } else {
          rethrow;
        }
      } on TimeoutException {
        throw Exception('Connection timeout while creating profile');
      }
    }
  }

  Future<String> _getDriverApprovalStatus(String uid) async {
    final fs = FirebaseFirestore.instance;
    final ref = fs.collection('drivers').doc(uid);

    DocumentSnapshot<Map<String, dynamic>> snap;
    try {
      snap = await ref.get().timeout(
        const Duration(seconds: 5),
        onTimeout: () => throw TimeoutException('Status check timed out'),
      );
    } on FirebaseException catch (e) {
      if (e.code == 'permission-denied') {
        // Legacy/malformed doc blocks owner-read.
        // Return 'pending' to send to PendingApprovalScreen for self-healing
        debugPrint(
          'Permission denied reading driver status - treating as pending',
        );
        return 'pending';
      }
      rethrow;
    } on TimeoutException {
      throw Exception('Connection timeout while checking approval status');
    }

    final data = snap.data() ?? {};
    return (data['approvalStatus'] as String?) ?? 'pending';
  }

  Future<void> _ensureMinimumSplashTime() async {
    final elapsed = _stopwatch.elapsedMilliseconds;
    final remaining = _minSplashDuration.inMilliseconds - elapsed;
    if (remaining > 0) {
      await Future.delayed(Duration(milliseconds: remaining));
    }
  }

  void _navigateToScreen(Widget screen, {bool allowWhenErrored = false}) {
    if (!allowWhenErrored && _errored) {
      return; // guard against late nav after error
    }
    Navigator.pushReplacement(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => screen,
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
        transitionDuration: const Duration(milliseconds: 300),
      ),
    );
  }

  String _getUserFriendlyError(dynamic error) {
    final errorStr = error.toString().toLowerCase();

    if (errorStr.contains('network') || errorStr.contains('connection')) {
      return 'No internet connection. Please check your network and try again.';
    } else if (errorStr.contains('timeout')) {
      return 'Connection timed out. Please check your internet connection.';
    } else if (errorStr.contains('permission') || errorStr.contains('denied')) {
      return 'Access denied. Please try logging in again.';
    } else if (errorStr.contains('firebase')) {
      return 'Server connection failed. Please try again.';
    } else {
      return 'An unexpected error occurred. Please try again.';
    }
  }

  void _retryInitialization() {
    setState(() {
      _errored = false;
      _errorText = null;
      _progress = 0.0;
      _statusText = 'Initializing...';
    });

    _progressAnimationController.value = 0.0; // reset progress bar
    _stopwatch.reset();
    _route();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFFFF8E1), Colors.white],
            stops: [0.0, 0.4],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Animated logo (with Hero to match OnboardingScreen)
                  Hero(
                    tag: 'app_logo',
                    child: AnimatedBuilder(
                      animation: _logoAnimationController,
                      builder: (context, child) {
                        return Transform.scale(
                          scale: _logoScaleAnimation.value,
                          child: Opacity(
                            opacity: _logoOpacityAnimation.value,
                            child: const AppLogo(size: 120),
                          ),
                        );
                      },
                    ),
                  ),

                  const SizedBox(height: 60),

                  if (!_errored) ...[
                    // Progress section
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 20,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          // Progress bar
                          Container(
                            height: 6,
                            decoration: BoxDecoration(
                              color: Colors.grey[200],
                              borderRadius: BorderRadius.circular(3),
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(3),
                              child: AnimatedBuilder(
                                animation: _progressAnimation,
                                builder: (context, child) {
                                  return LinearProgressIndicator(
                                    value: _progressAnimation.value, // 0..1
                                    backgroundColor: Colors.transparent,
                                    valueColor: const AlwaysStoppedAnimation(
                                      Color(0xFFE65100),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ),

                          const SizedBox(height: 16),

                          // Status text
                          Text(
                            _statusText,
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                            textAlign: TextAlign.center,
                          ),

                          const SizedBox(height: 8),

                          // Progress percentage
                          Text(
                            '${(_progress * 100).round()}%',
                            style: const TextStyle(
                              color: Color(0xFFE65100),
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ] else ...[
                    // Error section
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.red.withOpacity(0.2)),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.red.withOpacity(0.1),
                            blurRadius: 20,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.red.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(
                              Icons.error_outline,
                              color: Colors.red,
                              size: 32,
                            ),
                          ),

                          const SizedBox(height: 16),

                          const Text(
                            'Connection Error',
                            style: TextStyle(
                              color: Colors.red,
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                            ),
                          ),

                          if (_errorText != null) ...[
                            const SizedBox(height: 8),
                            Text(
                              _errorText!,
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 14,
                              ),
                              textAlign: TextAlign.center,
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],

                          const SizedBox(height: 24),

                          // Action buttons
                          Row(
                            children: [
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: _retryInitialization,
                                  icon: const Icon(Icons.refresh, size: 18),
                                  label: const Text('Try Again'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFFE65100),
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 12,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: () {
                                    _navigateToScreen(
                                      const AuthScreen(),
                                      allowWhenErrored:
                                          true, // explicit user intent
                                    );
                                  },
                                  icon: const Icon(Icons.login, size: 18),
                                  label: const Text('Login'),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: const Color(0xFFE65100),
                                    side: const BorderSide(
                                      color: Color(0xFFE65100),
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 12,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: 40),

                  // App version or branding
                  Text(
                    'Driver App v1.0.0',
                    style: TextStyle(color: Colors.grey[400], fontSize: 12),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
