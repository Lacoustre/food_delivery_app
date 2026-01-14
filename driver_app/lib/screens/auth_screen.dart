import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'login_screen.dart';
import 'signup_screen.dart';
import 'home_screen.dart';
import 'pending_approval_screen.dart';
import 'verify_email_screen.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  StreamSubscription<User?>? _authSub;
  bool _checking = false;
  bool _navigated = false;

  @override
  void initState() {
    super.initState();
    // If already signed in (cached), handle immediately
    final cached = FirebaseAuth.instance.currentUser;
    if (cached != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _handleAuth(cached));
    }
    // Also listen for changes
    _authSub = FirebaseAuth.instance.authStateChanges().listen((user) {
      if (user == null || _navigated) return;
      _handleAuth(user);
    });
  }

  Future<void> _handleAuth(User user) async {
    if (!mounted || _navigated) return;
    setState(() => _checking = true);

    try {
      // Refresh to ensure latest emailVerified
      await user.reload();
      final current = FirebaseAuth.instance.currentUser!;
      if (!current.emailVerified) {
        _go(() => const VerifyEmailScreen());
        return;
      }

      // Ensure driver doc exists (create-only attempt).
      // This respects your rules: create is allowed for the owner; update is admin-only.
      await _ensureDriverDoc(current);

      // Read status and route
      final fs = FirebaseFirestore.instance;
      final ref = fs.collection('drivers').doc(current.uid);

      DocumentSnapshot<Map<String, dynamic>> snap;
      try {
        snap = await ref.get();
      } on FirebaseException catch (e) {
        if (e.code == 'permission-denied') {
          // Likely a legacy doc missing userId → owner-read blocked.
          // Send user to Pending screen; that page will keep listening / show repair action.
          _toast(
            'We’re preparing your profile. You may need to log in with email once to repair.',
          );
          _go(() => const PendingApprovalScreen());
          return;
        }
        rethrow;
      }

      final data = snap.data() ?? {};
      final status = (data['approvalStatus'] as String?) ?? 'pending';

      switch (status) {
        case 'approved':
          _go(() => const HomeScreen());
          break;
        case 'pending':
        case 'under_review':
        case 'needs_info':
        case 'rejected':
        default:
          _go(() => const PendingApprovalScreen());
          break;
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not check account status.')),
      );
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  Future<void> _ensureDriverDoc(User u) async {
    final fs = FirebaseFirestore.instance;
    final ref = fs.collection('drivers').doc(u.uid);

    // Try a "create-only" write:
    // - If doc doesn't exist: this counts as CREATE → allowed by rules.
    // - If doc exists: this counts as UPDATE → denied for drivers; we ignore the error.
    final minimal = <String, dynamic>{
      'userId': u.uid,
      'fullName': (u.displayName?.trim().isNotEmpty == true)
          ? u.displayName!.trim()
          : (u.email ?? '—').split('@').first,
      'email': u.email ?? '—',
      'phone': u.phoneNumber ?? '—',

      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
      'source': 'auth-screen',
      'role': 'driver',
      'isActive': false,
    };

    try {
      // Check if document exists first
      final docSnapshot = await ref.get();
      
      if (!docSnapshot.exists) {
        // Only create new document if it doesn't exist
        minimal['approvalStatus'] = 'pending';
        await ref.set(minimal);
      }

    } on FirebaseException catch (_) {
      // Ignore; if it's an update denial, the doc already exists and we’ll read it next.
    }
  }

  void _go(Widget Function() builder) {
    if (_navigated || !mounted) return;
    _navigated = true;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => builder()),
    );
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  void dispose() {
    _authSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      color: Colors.orange.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Icon(
                      Icons.delivery_dining,
                      size: 50,
                      color: Colors.orange,
                    ),
                  ),
                  const SizedBox(height: 32),
                  const Text(
                    'Welcome Driver!',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Join our delivery team',
                    style: TextStyle(fontSize: 16, color: Colors.grey),
                  ),
                  const SizedBox(height: 48),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _checking
                          ? null
                          : () => Navigator.pushNamed(context, '/login'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'Login',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: _checking
                          ? null
                          : () => Navigator.pushNamed(context, '/signup'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.orange,
                        side: const BorderSide(color: Colors.orange),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'Sign Up',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (_checking)
              Container(
                color: Colors.white.withOpacity(0.6),
                child: const Center(child: CircularProgressIndicator()),
              ),
          ],
        ),
      ),
    );
  }
}
