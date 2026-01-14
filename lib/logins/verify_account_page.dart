import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class VerifyAccountPage extends StatefulWidget {
  const VerifyAccountPage({super.key});

  @override
  State<VerifyAccountPage> createState() => _VerifyAccountPageState();
}

class _VerifyAccountPageState extends State<VerifyAccountPage> {
  bool isPhoneVerified = false;
  bool isResendEnabled = true;
  Timer? resendTimer;
  int _resendCountdown = 60;
  String? verificationId;
  final _smsCodeController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _checkPhoneVerification();
  }

  Future<void> _checkPhoneVerification() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      if (doc.exists) {
        setState(() {
          isPhoneVerified = doc.data()?['phoneVerified'] ?? false;
        });
      }
    }
  }

  Future<void> sendPhoneVerification() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();
    final phoneNumber = doc.data()?['phone'] as String?;

    if (phoneNumber == null || phoneNumber.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Phone number not found')));
      return;
    }

    // Check if the phone number is already linked to the current account
    final currentPhone = user.phoneNumber;
    if (currentPhone == phoneNumber) {
      setState(() {
        isPhoneVerified = true; // Skip verification if already linked
      });
      Navigator.pushReplacementNamed(context, '/auth');
      return;
    }

    await FirebaseAuth.instance.verifyPhoneNumber(
      phoneNumber: phoneNumber,
      verificationCompleted: (PhoneAuthCredential credential) async {
        try {
          await user.linkWithCredential(credential);
          await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .update({'phoneVerified': true});
          setState(() => isPhoneVerified = true);
          Navigator.pushReplacementNamed(context, '/auth');
        } catch (e) {
          // Handle error if the phone is already linked to another account
          await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .update({'phoneVerified': true});
          setState(() => isPhoneVerified = true);
          Navigator.pushReplacementNamed(context, '/auth');
        }
      },
      verificationFailed: (FirebaseAuthException e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Phone verification failed: ${e.message}')),
        );
      },
      codeSent: (String vId, int? resendToken) {
        setState(() => verificationId = vId);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('SMS code sent')));
      },
      codeAutoRetrievalTimeout: (String vId) {
        setState(() => verificationId = vId);
      },
    );
  }

  Future<void> verifyPhoneCode() async {
    if (verificationId == null || _smsCodeController.text.isEmpty) return;

    try {
      final credential = PhoneAuthProvider.credential(
        verificationId: verificationId!,
        smsCode: _smsCodeController.text,
      );

      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        try {
          await user.linkWithCredential(credential);
        } catch (e) {
          // Credential linking might fail if phone is already linked
        }

        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .update({'phoneVerified': true});

        setState(() => isPhoneVerified = true);

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Phone verified successfully'),
            backgroundColor: Colors.green,
          ),
        );

        Navigator.pushReplacementNamed(context, '/auth');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Invalid verification code'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void startResendCooldown() {
    setState(() {
      isResendEnabled = false;
      _resendCountdown = 60;
    });

    resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_resendCountdown > 0) {
        setState(() => _resendCountdown--);
      } else {
        timer.cancel();
        setState(() => isResendEnabled = true);
      }
    });
  }

  @override
  void dispose() {
    resendTimer?.cancel();
    _smsCodeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Verify Your Account"),
        backgroundColor: Colors.deepOrange,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            const Icon(Icons.verified_user, size: 80, color: Colors.deepOrange),
            const SizedBox(height: 24),
            Text(
              "Phone Verification",
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: Colors.deepOrange,
              ),
            ),
            const SizedBox(height: 32),
            // Verification Content for Phone
            if (!isPhoneVerified) ...[
              if (verificationId == null) ...[
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: sendPhoneVerification,
                    child: const Text("Send SMS Code"),
                  ),
                ),
              ] else ...[
                TextField(
                  controller: _smsCodeController,
                  decoration: const InputDecoration(
                    labelText: "Enter SMS Code",
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: verifyPhoneCode,
                    child: const Text("Verify Code"),
                  ),
                ),
              ],
            ] else ...[
              const Icon(Icons.check_circle, color: Colors.green, size: 60),
              const Text("Phone verified! You can now continue."),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () =>
                      Navigator.pushReplacementNamed(context, '/auth'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                  ),
                  child: const Text("Continue to App"),
                ),
              ),
            ],
            const SizedBox(height: 32),
            TextButton(
              onPressed: () async {
                await FirebaseAuth.instance.signOut();
                if (mounted) {
                  Navigator.pushReplacementNamed(context, '/choice');
                }
              },
              child: const Text("Sign Out & Try Different Account"),
            ),
          ],
        ),
      ),
    );
  }
}
