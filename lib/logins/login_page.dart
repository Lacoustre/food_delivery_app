import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:african_cuisine/home/main_home_page.dart';
import 'sign_up_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage>
    with SingleTickerProviderStateMixin {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
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
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> loginUser() async {
    if (_formKey.currentState!.validate()) {
      FocusScope.of(context).unfocus(); // Dismiss keyboard
      setState(() => _isLoading = true);
      try {
        await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: _emailController.text.trim(),
          password: _passwordController.text.trim(),
        );
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const MainFoodPage()),
        );
      } on FirebaseAuthException catch (e) {
        String message = "Login failed.";
        if (e.code == 'user-not-found') {
          message = "No user found for that email.";
        } else if (e.code == 'wrong-password') {
          message = "Incorrect password.";
        }
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(message)));
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Login failed: ${e.toString()}")),
        );
      } finally {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showResetPasswordDialog() {
    final resetEmailController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reset Password'),
        content: TextField(
          controller: resetEmailController,
          keyboardType: TextInputType.emailAddress,
          decoration: const InputDecoration(
            labelText: 'Enter your email',
            hintText: 'email@example.com',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final email = resetEmailController.text.trim();
              if (email.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Please enter your email')),
                );
                return;
              }
              try {
                await FirebaseAuth.instance.sendPasswordResetEmail(
                  email: email,
                );
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Password reset email sent')),
                );
                Navigator.pop(context);
              } on FirebaseAuthException catch (e) {
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(SnackBar(content: Text('Error: ${e.message}')));
              }
            },
            child: const Text('Send'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final args = ModalRoute.of(context)?.settings.arguments;
    if (args == 'logout_success') {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Logged out successfully')),
        );
      });
    }

    return Scaffold(
      appBar: AppBar(title: const Text("Welcome Back")),
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
                      'assets/images/logo.png', // adjust path if needed
                      width: 120,
                      height: 120,
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  "Login to your account",
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 30),
                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  autofillHints: const [AutofillHints.email],
                  decoration: const InputDecoration(labelText: "Email"),
                  validator: (value) =>
                      value!.isEmpty ? "Enter your email" : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _passwordController,
                  obscureText: true,
                  autofillHints: const [AutofillHints.password],
                  decoration: const InputDecoration(labelText: "Password"),
                  validator: (value) =>
                      value!.isEmpty ? "Enter your password" : null,
                ),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: _showResetPasswordDialog,
                    child: const Text('Forgot Password?'),
                  ),
                ),
                const SizedBox(height: 30),
                ElevatedButton(
                  onPressed: _isLoading ? null : loginUser,
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text("Login"),
                ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: () => Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (_) => const SignupPage()),
                  ),
                  child: const Text("Don't have an account? Sign up"),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
