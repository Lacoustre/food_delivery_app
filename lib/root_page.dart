import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:african_cuisine/home/onboarding_page.dart';
import 'package:african_cuisine/logins/auth_gate.dart';

class RootPage extends StatefulWidget {
  const RootPage({super.key});

  @override
  State<RootPage> createState() => _RootPageState();
}

class _RootPageState extends State<RootPage> {
  bool? _showOnboarding;

  @override
  void initState() {
    super.initState();
    _checkFirstLaunch();
  }

  Future<void> _checkFirstLaunch() async {
    final prefs = await SharedPreferences.getInstance();
    final firstLaunch = prefs.getBool('first_launch') ?? true;
    setState(() => _showOnboarding = firstLaunch);
  }

  void _onOnboardingComplete() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('first_launch', false);
    setState(() => _showOnboarding = false);
  }

  @override
  Widget build(BuildContext context) {
    if (_showOnboarding == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_showOnboarding == true) {
      return OnboardingPage(onComplete: _onOnboardingComplete);
    }

    return const AuthGate();
  }
}
