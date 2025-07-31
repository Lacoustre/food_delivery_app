import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:african_cuisine/logins/auth_service.dart';

class PhoneNumberUpdatePage extends StatefulWidget {
  const PhoneNumberUpdatePage({super.key});

  @override
  State<PhoneNumberUpdatePage> createState() => _PhoneNumberUpdatePageState();
}

class _PhoneNumberUpdatePageState extends State<PhoneNumberUpdatePage> {
  final AuthService _authService = AuthService();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _otpController = TextEditingController();

  String? _verificationId;
  // ignore: unused_field
  int? _resendToken;
  bool _codeSent = false;
  bool _isLoading = false;
  int _cooldown = 0;
  Timer? _timer;

  void _startCooldown() {
    setState(() => _cooldown = 60);
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_cooldown == 0) {
        timer.cancel();
      } else {
        setState(() => _cooldown--);
      }
    });
  }

  Future<void> _sendVerificationCode() async {
    final phone = _phoneController.text.trim();
    if (phone.isEmpty) return;

    setState(() => _isLoading = true);

    await _authService.updatePhoneNumberFlow(
      newPhoneNumber: phone,
      onCodeSent: (String verificationId, int? resendToken) {
        setState(() {
          _verificationId = verificationId;
          _resendToken = resendToken;
          _codeSent = true;
          _isLoading = false;
        });
        _startCooldown();
      },
      onError: (msg) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("❌ Error: $msg")));
      },
      onAutoRetrievalTimeout: (verificationId) {
        _verificationId = verificationId;
      },
    );
  }

  Future<void> _applyPhoneUpdate() async {
    if (_verificationId == null || _otpController.text.trim().isEmpty) return;

    setState(() => _isLoading = true);
    try {
      await _authService.applyPhoneUpdate(
        _verificationId!,
        _otpController.text.trim(),
      );

      // ✅ Save phone number to Firestore
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
          'phone': user.phoneNumber,
        }, SetOptions(merge: true));
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✅ Phone number updated successfully')),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('⚠️ Failed to update: $e')));
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _phoneController.dispose();
    _otpController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Update Phone Number'),
        backgroundColor: Colors.deepOrange,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // ✅ Logo at the top
            Center(child: Image.asset('assets/images/logo.png', height: 100)),
            const SizedBox(height: 20),

            if (!_codeSent) ...[
              TextField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: 'New Phone Number',
                  hintText: '+1 234 567 8900',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                icon: const Icon(Icons.send),
                label: const Text('Send Verification Code'),
                onPressed: _isLoading ? null : _sendVerificationCode,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.deepOrange,
                  foregroundColor: Colors.white,
                ),
              ),
            ] else ...[
              const Text(
                'Enter the verification code sent to your new number',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              TextField(
                controller: _otpController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Verification Code',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                icon: const Icon(Icons.verified),
                label: const Text('Confirm Update'),
                onPressed: _isLoading ? null : _applyPhoneUpdate,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                ),
              ),
              const SizedBox(height: 8),
              if (_cooldown > 0)
                Text("⏱ Resend in $_cooldown seconds")
              else
                TextButton(
                  onPressed: _sendVerificationCode,
                  child: const Text('🔁 Resend Code'),
                ),
              TextButton(
                onPressed: () => setState(() => _codeSent = false),
                child: const Text('📞 Change Phone Number'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
