import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'home_screen.dart';
import 'pending_approval_screen.dart';

class VerifyEmailScreen extends StatefulWidget {
  const VerifyEmailScreen({super.key});

  @override
  State<VerifyEmailScreen> createState() => _VerifyEmailScreenState();
}

class _VerifyEmailScreenState extends State<VerifyEmailScreen> {
  bool _busy = false;
  int _cooldown = 0;
  Timer? _cooldownTimer;

  @override
  void dispose() {
    _cooldownTimer?.cancel();
    super.dispose();
  }

  Future<void> _startCooldown([int seconds = 30]) async {
    _cooldownTimer?.cancel();
    setState(() => _cooldown = seconds);
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return t.cancel();
      if (_cooldown <= 1) {
        t.cancel();
        setState(() => _cooldown = 0);
      } else {
        setState(() => _cooldown--);
      }
    });
  }

  Future<void> _resend() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    if (_cooldown > 0) return;

    setState(() => _busy = true);
    try {
      await user.sendEmailVerification();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Verification email sent.')),
        );
      }
      await _startCooldown();
    } on FirebaseAuthException catch (e) {
      final msg = switch (e.code) {
        'too-many-requests' => 'Too many requests. Please wait a moment.',
        'network-request-failed' => 'Network error. Check connection & retry.',
        _ => 'Could not send email. Try again later.',
      };
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(msg)));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not send email. Try again later.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _continue() async {
    final auth = FirebaseAuth.instance;
    final user = auth.currentUser;
    if (user == null) return;

    setState(() => _busy = true);
    try {
      await user.reload();
      final refreshed = auth.currentUser!;
      if (!refreshed.emailVerified) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Please verify your email first.')),
          );
        }
        return;
      }

      // Ensure driver doc exists (create/merge) then read status.
      final fs = FirebaseFirestore.instance;
      final ref = fs.collection('drivers').doc(refreshed.uid);

      final bootstrap = <String, dynamic>{
        'userId': refreshed.uid,
        'fullName': (refreshed.displayName?.trim().isNotEmpty == true)
            ? refreshed.displayName!.trim()
            : (refreshed.email ?? '—').split('@').first,
        'email': refreshed.email ?? '—',
        'phone': refreshed.phoneNumber ?? '—',
        'approvalStatus': 'pending',
        'isActive': false,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'source': 'verify-email-bootstrap',
        'role': 'driver',
      };

      try {
        await ref.set(bootstrap, SetOptions(merge: true));
      } on FirebaseException {
        // If rules treat this as an UPDATE and deny, ignore—we just need to read next.
      }

      DocumentSnapshot<Map<String, dynamic>> snap;
      try {
        snap = await ref.get();
      } on FirebaseException catch (e) {
        if (e.code == 'permission-denied') {
          // Malformed legacy doc (e.g., missing userId) → owner-read blocked.
          // Route to Pending; that screen can keep polling / show repair path.
          if (!mounted) return;
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const PendingApprovalScreen()),
          );
          return;
        }
        rethrow;
      }

      final status = (snap.data()?['approvalStatus'] as String?) ?? 'pending';

      if (!mounted) return;
      if (status == 'approved') {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const HomeScreen()),
        );
      } else {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const PendingApprovalScreen()),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _signOut() async {
    await FirebaseAuth.instance.signOut();
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final canResend = _cooldown == 0 && !_busy;

    return Scaffold(
      appBar: AppBar(title: const Text('Verify your email')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "We've sent a verification link to your email.",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            const Text(
              "Open the link to verify your account, then tap Continue.",
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                ElevatedButton(
                  onPressed: canResend ? _resend : null,
                  child: Text(
                    _cooldown > 0 ? 'Resend in $_cooldown s' : 'Resend email',
                  ),
                ),
                const SizedBox(width: 12),
                OutlinedButton(
                  onPressed: _busy ? null : _continue,
                  child: const Text("I've verified — Continue"),
                ),
              ],
            ),
            const Spacer(),
            TextButton(
              onPressed: _busy ? null : _signOut,
              child: const Text('Sign out'),
            ),
          ],
        ),
      ),
    );
  }
}
