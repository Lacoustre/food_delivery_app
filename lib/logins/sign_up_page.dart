import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'login_page.dart';

class SignupPage extends StatefulWidget {
  const SignupPage({super.key});

  @override
  State<SignupPage> createState() => _SignupPageState();
}

class _SignupPageState extends State<SignupPage>
    with SingleTickerProviderStateMixin {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;

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
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> signupUser() async {
    if (_formKey.currentState!.validate()) {
      FocusScope.of(context).unfocus(); // dismiss keyboard
      setState(() => _isLoading = true);
      try {
        final userCredential = await FirebaseAuth.instance
            .createUserWithEmailAndPassword(
              email: _emailController.text.trim(),
              password: _passwordController.text.trim(),
            );

        final user = userCredential.user;

        if (user != null) {
          // Save to Firestore
          await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .set({
                'name': _nameController.text.trim(),
                'email': user.email,
                'role': 'customer',
                'createdAt': FieldValue.serverTimestamp(),
              });

          // Set display name
          await user.updateDisplayName(_nameController.text.trim());

          await user.sendEmailVerification();

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Verification email sent. Check inbox."),
            ),
          );

          Navigator.pushReplacementNamed(context, '/verify');
        }
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Signup failed: ${e.toString()}")),
        );
      } finally {
        setState(() => _isLoading = false);
      }
    }
  }

  String? _validatePassword(String? value) {
    if (value == null || value.isEmpty) return 'Enter your password';
    if (value.length < 6) return 'Minimum 6 characters';
    return null;
  }

  String? _confirmPassword(String? value) {
    if (value != _passwordController.text) return 'Passwords do not match';
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text("Create Account")),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: ListView(
              shrinkWrap: true,
              children: [
                FadeTransition(
                  opacity: _fadeAnimation,
                  child: ScaleTransition(
                    scale: _scaleAnimation,
                    child: Image.asset(
                      'assets/images/logo.png',
                      width: 120,
                      height: 120,
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  "Sign up to get started",
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 30),
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(labelText: "Full Name"),
                  validator: (value) =>
                      value!.isEmpty ? "Enter your name" : null,
                  textInputAction: TextInputAction.next,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _emailController,
                  decoration: const InputDecoration(labelText: "Email"),
                  keyboardType: TextInputType.emailAddress,
                  autofillHints: const [AutofillHints.email],
                  validator: (value) =>
                      value!.isEmpty ? "Enter your email" : null,
                  textInputAction: TextInputAction.next,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _passwordController,
                  obscureText: true,
                  decoration: const InputDecoration(labelText: "Password"),
                  validator: _validatePassword,
                  autofillHints: const [AutofillHints.newPassword],
                  textInputAction: TextInputAction.next,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _confirmPasswordController,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: "Confirm Password",
                  ),
                  validator: _confirmPassword,
                  autofillHints: const [AutofillHints.newPassword],
                  textInputAction: TextInputAction.done,
                ),
                const SizedBox(height: 30),
                ElevatedButton(
                  onPressed: _isLoading ? null : signupUser,
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text("Sign Up"),
                ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: () => Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (_) => const LoginPage()),
                  ),
                  child: const Text("Already have an account? Login"),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
