import 'package:flutter/material.dart';

class LoginChoicePage extends StatefulWidget {
  const LoginChoicePage({super.key});

  @override
  State<LoginChoicePage> createState() => _LoginChoicePageState();
}

class _LoginChoicePageState extends State<LoginChoicePage>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    );

    _fadeAnimation = Tween<double>(
      begin: 0,
      end: 1,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeIn));

    _scaleAnimation = Tween<double>(
      begin: 0.8,
      end: 1,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutBack));

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text("Sign In"),
        backgroundColor: theme.colorScheme.primary,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              FadeTransition(
                opacity: _fadeAnimation,
                child: ScaleTransition(
                  scale: _scaleAnimation,
                  child: Image.asset(
                    'assets/images/logo.png', // Update if needed
                    width: 300,
                    height: 300,
                    fit: BoxFit.contain,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                "Welcome to Taste of African Cuisine!",
                textAlign: TextAlign.center,
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                "Please choose how you want to sign in",
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(color: Colors.grey),
              ),
              const SizedBox(height: 40),
              ElevatedButton.icon(
                icon: const Icon(Icons.email),
                label: const Text("Sign in with Email"),
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size.fromHeight(50),
                ),
                onPressed: () {
                  Navigator.pushNamed(context, '/login');
                },
              ),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                icon: const Icon(Icons.phone),
                label: const Text("Sign in with Phone"),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(50),
                  side: BorderSide(color: Colors.deepOrange),
                ),
                onPressed: () {
                  Navigator.pushNamed(context, '/phone-auth');
                },
              ),
              const SizedBox(height: 30),
              TextButton(
                onPressed: () {
                  Navigator.pushNamed(context, '/signup');
                },
                child: const Text("Don't have an account? Sign up"),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
