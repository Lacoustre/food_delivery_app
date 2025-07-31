import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

class VerifyEmailPage extends StatefulWidget {
  const VerifyEmailPage({super.key});

  @override
  State<VerifyEmailPage> createState() => _VerifyEmailPageState();
}

class _VerifyEmailPageState extends State<VerifyEmailPage> {
  bool isEmailVerified = false;
  bool isResendEnabled = false;
  Timer? checkTimer;
  Timer? resendTimer;
  int _resendCountdown = 60;

  @override
  void initState() {
    super.initState();
    isEmailVerified = FirebaseAuth.instance.currentUser!.emailVerified;

    if (!isEmailVerified) {
      sendVerificationEmail();

      // Check verification status every 3 seconds
      checkTimer = Timer.periodic(
        const Duration(seconds: 3),
        (_) => checkEmailVerified(),
      );

      // Start resend cooldown
      startResendCooldown();
    }
  }

  Future<void> checkEmailVerified() async {
    await FirebaseAuth.instance.currentUser!.reload();
    setState(() {
      isEmailVerified = FirebaseAuth.instance.currentUser!.emailVerified;
    });

    if (isEmailVerified) {
      checkTimer?.cancel();
      resendTimer?.cancel();
      Navigator.pushReplacementNamed(context, '/home');
    }
  }

  Future<void> sendVerificationEmail() async {
    try {
      await FirebaseAuth.instance.currentUser!.sendEmailVerification();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Verification email sent.")));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Failed to send email: ${e.toString()}")),
      );
    }
  }

  void startResendCooldown() {
    setState(() {
      isResendEnabled = false;
      _resendCountdown = 60;
    });

    resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        _resendCountdown--;
      });

      if (_resendCountdown == 0) {
        timer.cancel();
        setState(() {
          isResendEnabled = true;
        });
      }
    });
  }

  @override
  void dispose() {
    checkTimer?.cancel();
    resendTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Verify Your Email")),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              "We've sent a verification link to your email.\nPlease verify to continue.",
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 30),
            ElevatedButton(
              onPressed: isResendEnabled
                  ? () {
                      sendVerificationEmail();
                      startResendCooldown();
                    }
                  : null,
              child: Text(
                isResendEnabled
                    ? "Resend Verification Email"
                    : "Resend in $_resendCountdown sec",
              ),
            ),
            TextButton(
              onPressed: () async {
                await FirebaseAuth.instance.signOut();
                if (mounted) {
                  Navigator.pushReplacementNamed(context, '/login');
                }
              },
              child: const Text("Cancel / Logout"),
            ),
          ],
        ),
      ),
    );
  }
}
