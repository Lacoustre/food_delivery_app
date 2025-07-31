import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class LinkPhonePage extends StatefulWidget {
  const LinkPhonePage({super.key});

  @override
  State<LinkPhonePage> createState() => _LinkPhonePageState();
}

class _LinkPhonePageState extends State<LinkPhonePage> {
  final _phoneController = TextEditingController();
  final _otpController = TextEditingController();
  String? _verificationId;
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

  Future<void> _sendCode() async {
    final phone = _phoneController.text.trim();
    if (phone.isEmpty) return;

    setState(() => _isLoading = true);

    await FirebaseAuth.instance.verifyPhoneNumber(
      phoneNumber: phone,
      verificationCompleted: (credential) async {
        _linkWithCredential(credential);
      },
      verificationFailed: (e) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("❌ Verification failed: ${e.message}")),
        );
      },
      codeSent: (verificationId, _) {
        setState(() {
          _verificationId = verificationId;
          _codeSent = true;
          _isLoading = false;
        });
        _startCooldown();
      },
      codeAutoRetrievalTimeout: (verificationId) {
        _verificationId = verificationId;
      },
    );
  }

  Future<void> _linkWithOTP() async {
    final code = _otpController.text.trim();
    if (_verificationId == null || code.isEmpty) return;

    final credential = PhoneAuthProvider.credential(
      verificationId: _verificationId!,
      smsCode: code,
    );

    await _linkWithCredential(credential);
  }

  Future<void> _linkWithCredential(PhoneAuthCredential credential) async {
    setState(() => _isLoading = true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception("No user signed in");

      // 🔐 Link phone number
      await user.linkWithCredential(credential);

      // 🔄 Refresh token so backend sees the updated auth
      await user.getIdToken(true);

      // 🗂 Optionally sync phone to Firestore
      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'phoneNumber': user.phoneNumber,
      }, SetOptions(merge: true));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("🎉 Phone number linked successfully!"),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context); // Go back to Profile or previous page
      }
    } on FirebaseAuthException catch (e) {
      String errorMessage = "Linking failed: ${e.message}";
      if (e.code == 'provider-already-linked') {
        errorMessage = "Phone number already linked.";
      } else if (e.code == 'credential-already-in-use') {
        errorMessage =
            "This phone number is already linked to another account.";
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("❌ $errorMessage"), backgroundColor: Colors.red),
      );
    } finally {
      setState(() => _isLoading = false);
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
        title: const Text("Link Phone Number"),
        backgroundColor: Colors.deepOrange,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            TextField(
              controller: _phoneController,
              decoration: const InputDecoration(
                labelText: "Phone Number",
                hintText: "+1 234 567 8900",
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.phone,
              enabled: !_codeSent,
            ),
            const SizedBox(height: 20),
            if (_codeSent)
              TextField(
                controller: _otpController,
                decoration: const InputDecoration(
                  labelText: "OTP Code",
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
              ),
            const SizedBox(height: 20),
            if (!_codeSent)
              ElevatedButton.icon(
                icon: const Icon(Icons.sms),
                label: const Text("Send Code"),
                onPressed: _isLoading ? null : _sendCode,
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size.fromHeight(50),
                  backgroundColor: Colors.deepOrange,
                ),
              )
            else ...[
              ElevatedButton.icon(
                icon: const Icon(Icons.verified),
                label: const Text("Verify & Link"),
                onPressed: _isLoading ? null : _linkWithOTP,
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size.fromHeight(50),
                  backgroundColor: Colors.green,
                ),
              ),
              const SizedBox(height: 8),
              if (_cooldown > 0)
                Text("⏱ Resend available in $_cooldown seconds")
              else
                TextButton(
                  onPressed: _isLoading ? null : _sendCode,
                  child: const Text("🔁 Resend Code"),
                ),
            ],
            if (_isLoading) const SizedBox(height: 20),
            if (_isLoading)
              const CircularProgressIndicator(color: Colors.deepOrange),
          ],
        ),
      ),
    );
  }
}
