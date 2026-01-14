import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;
  String _statusText = 'Loading...';

  @override
  void initState() {
    super.initState();
    _setupAnimations();
    _navigateAfterSplash();
  }

  void _setupAnimations() {
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );

    _fadeAnimation = Tween<double>(begin: 0, end: 1)
        .animate(CurvedAnimation(parent: _controller, curve: Curves.easeIn));

    _scaleAnimation = Tween<double>(begin: 0.8, end: 1)
        .animate(CurvedAnimation(parent: _controller, curve: Curves.elasticOut));

    _controller.forward();
  }

  Future<void> _navigateAfterSplash() async {
    try {
      // Show loading for minimum time
      await Future.delayed(const Duration(milliseconds: 2000));
      
      setState(() => _statusText = 'Checking authentication...');
      
      // Check if user is already logged in
      final user = FirebaseAuth.instance.currentUser;
      final prefs = await SharedPreferences.getInstance();
      final hasSeenOnboarding = prefs.getBool('hasSeenOnboarding') ?? false;
      
      if (user != null) {
        // User is logged in - let auth gate handle verification checks
        setState(() => _statusText = 'Welcome back!');
        await Future.delayed(const Duration(milliseconds: 500));
        if (mounted) Navigator.pushReplacementNamed(context, '/auth');
      } else {
        // No user logged in
        if (!hasSeenOnboarding) {
          // First time user - show onboarding
          setState(() => _statusText = 'Welcome to African Cuisine!');
          await Future.delayed(const Duration(milliseconds: 500));
          if (mounted) Navigator.pushReplacementNamed(context, '/onboarding');
        } else {
          // Returning user - show login options
          setState(() => _statusText = 'Please sign in...');
          await Future.delayed(const Duration(milliseconds: 500));
          if (mounted) Navigator.pushReplacementNamed(context, '/choice');
        }
      }
    } catch (e) {
      // Handle errors gracefully
      setState(() => _statusText = 'Something went wrong...');
      await Future.delayed(const Duration(milliseconds: 1000));
      if (mounted) Navigator.pushReplacementNamed(context, '/choice');
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFF5E1),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            FadeTransition(
              opacity: _fadeAnimation,
              child: ScaleTransition(
                scale: _scaleAnimation,
                child: Column(
                  children: [
                    Image.asset(
                      'assets/images/logo.png',
                      width: 200,
                      height: 200,
                      fit: BoxFit.contain,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Taste of African Cuisine',
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Colors.deepOrange,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 40),
            const CircularProgressIndicator(
              color: Colors.deepOrange,
              strokeWidth: 3,
            ),
            const SizedBox(height: 16),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: Text(
                _statusText,
                key: ValueKey(_statusText),
                style: const TextStyle(
                  color: Colors.grey,
                  fontSize: 14,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
