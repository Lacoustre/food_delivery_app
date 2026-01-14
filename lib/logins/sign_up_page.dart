import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
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
  final _phoneController = TextEditingController();
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
    _phoneController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  String _normalizePhone(String raw) =>
      raw.trim().replaceAll(RegExp(r'\s+'), '');

  Future<void> _clearAuthCache() async {
    try {
      await FirebaseAuth.instance.signOut();
    } catch (e) {
      // Ignore errors during sign out
    }
  }

  Future<void> signupUser() async {
    if (!_formKey.currentState!.validate()) return;

    FocusScope.of(context).unfocus();
    setState(() => _isLoading = true);

    // Clear any cached auth state first
    await _clearAuthCache();

    User? createdUser;

    try {
      final cred = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );
      createdUser = cred.user;

      if (createdUser == null) {
        throw FirebaseAuthException(
          code: 'internal-error',
          message: 'User creation failed unexpectedly.',
        );
      }

      final uid = createdUser.uid;
      final db = FirebaseFirestore.instance;
      final usersRef = db.collection('users').doc(uid);
      final phone = _normalizePhone(_phoneController.text);

      await usersRef.set({
        'uid': uid,
        'name': _nameController.text.trim(),
        'email': createdUser.email,
        'phone': phone,
        'role': 'customer',
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      try {
        final fcmToken = await FirebaseMessaging.instance.getToken();
        if (fcmToken != null) {
          await usersRef.update({'fcmToken': fcmToken});
        }
      } catch (e) {
        // FCM token save failed - non-critical, continue
      }

      await createdUser.updateDisplayName(_nameController.text.trim());

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ Account created successfully!'),
          backgroundColor: Colors.green,
        ),
      );

      Navigator.pushReplacementNamed(context, '/auth');
    } catch (e) {
      String msg = 'Signup failed';
      if (e is FirebaseAuthException) {
        if (e.code == 'weak-password') {
          msg = 'Password is too weak';
        } else if (e.code == 'email-already-in-use') {
          msg = 'Email is already registered';
        } else if (e.code == 'invalid-email') {
          msg = 'Invalid email address';
        } else if (e.code == 'too-many-requests') {
          msg = 'Too many attempts. Please try again later.';
        } else {
          msg = e.message ?? 'Signup failed';
        }
      } else if (e is FirebaseException) {
        msg = e.code == 'permission-denied'
            ? 'Permission denied by Firestore rules.'
            : (e.message ?? 'Could not finish signup.');
      } else {
        msg = 'Network error: ${e.toString()}';
      }

      try {
        await createdUser?.delete();
      } catch (_) {
        await FirebaseAuth.instance.signOut();
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String? _validateEmail(String? value) {
    if (value == null || value.isEmpty) return "Enter your email";
    if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) {
      return "Enter a valid email address";
    }
    return null;
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

  String? _validatePhone(String? value) {
    if (value == null || value.isEmpty) {
      return "Enter your phone number";
    }
    if (!value.trim().startsWith('+')) {
      return "Include country code (e.g. +1234567890)";
    }
    final cleanPhone = value.trim().replaceAll(RegExp(r'[\s\-\(\)]'), '');
    if (cleanPhone.length < 10 || cleanPhone.length > 15) {
      return "Phone number must be 10-15 digits";
    }
    if (!RegExp(r'^\+[1-9]\d{1,14}$').hasMatch(cleanPhone)) {
      return "Invalid phone format (use +1234567890)";
    }
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
                      value == null || value.isEmpty ? "Enter your name" : null,
                  textInputAction: TextInputAction.next,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _emailController,
                  decoration: const InputDecoration(labelText: "Email"),
                  keyboardType: TextInputType.emailAddress,
                  autofillHints: const [AutofillHints.email],
                  validator: _validateEmail,
                  textInputAction: TextInputAction.next,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _phoneController,
                  decoration: const InputDecoration(
                    labelText: "Phone Number",
                    hintText: "Include country code (e.g. +1234567890)",
                  ),
                  keyboardType: TextInputType.phone,
                  validator: _validatePhone,
                  textInputAction: TextInputAction.next,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _passwordController,
                  decoration: const InputDecoration(labelText: "Password"),
                  obscureText: true,
                  validator: _validatePassword,
                  textInputAction: TextInputAction.next,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _confirmPasswordController,
                  decoration: const InputDecoration(labelText: "Confirm Password"),
                  obscureText: true,
                  validator: _confirmPassword,
                  textInputAction: TextInputAction.done,
                ),
                const SizedBox(height: 30),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : signupUser,
                    child: _isLoading
                        ? const CircularProgressIndicator()
                        : const Text("Sign Up"),
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text("Already have an account? "),
                    TextButton(
                      onPressed: () => Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(builder: (context) => const LoginPage()),
                      ),
                      child: const Text("Login"),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}