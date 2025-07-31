import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:african_cuisine/home/main_home_page.dart';
import 'package:african_cuisine/logins/login_choice_page.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _navigateAfterSplash();
  }

  Future<void> _navigateAfterSplash() async {
    await Future.delayed(const Duration(seconds: 3));

    final user = FirebaseAuth.instance.currentUser;

    if (user != null && user.emailVerified) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const MainFoodPage()),
      );
    } else {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const LoginChoicePage()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFF5E1),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Opacity(
              opacity: 0.9,
              child: Image.asset(
                'assets/images/logo.png',
                width: 200,
                height: 200,
                fit: BoxFit.contain,
              ),
            ),
            const SizedBox(height: 24),
            const CircularProgressIndicator(
              color: Colors.deepOrange,
              strokeWidth: 2.5,
            ),
          ],
        ),
      ),
    );
  }
}
