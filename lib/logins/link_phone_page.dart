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
  int _attemptCount = 0;
  DateTime? _lastAttempt;

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

    // Rate limiting check
    if (_lastAttempt != null && 
        DateTime.now().difference(_lastAttempt!).inMinutes < 1 && 
        _attemptCount >= 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Too many attempts. Please wait before trying again.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);
    _attemptCount++;
    _lastAttempt = DateTime.now();

    try {
      await FirebaseAuth.instance.verifyPhoneNumber(
        phoneNumber: phone,
        verificationCompleted: (credential) async {
          await _linkWithCredential(credential);
        },
        verificationFailed: (e) {
          if (mounted) {
            setState(() => _isLoading = false);
            String message = 'Verification failed';
            if (e.code == 'too-many-requests') {
              message = 'Too many requests. Please try again later.';
            } else if (e.code == 'invalid-phone-number') {
              message = 'Invalid phone number format.';
            } else if (e.message != null) {
              message = e.message!;
            }
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text("❌ $message"),
                backgroundColor: Colors.red,
              ),
            );
          }
        },
        codeSent: (verificationId, _) {
          if (mounted) {
            setState(() {
              _verificationId = verificationId;
              _codeSent = true;
              _isLoading = false;
            });
            _startCooldown();
          }
        },
        codeAutoRetrievalTimeout: (verificationId) {
          _verificationId = verificationId;
        },
        timeout: const Duration(seconds: 120),
      );
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("❌ Error: ${e.toString()}"),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _linkWithOTP() async {
    final code = _otpController.text.trim();
    if (_verificationId == null || code.isEmpty || code.length != 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a valid 6-digit code'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

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
      if (user == null) {
        throw Exception("No user signed in");
      }

      // Check if phone is already linked
      final isPhoneLinked = user.providerData.any(
        (info) => info.providerId == 'phone',
      );
      
      if (isPhoneLinked) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Phone number is already linked to your account"),
              backgroundColor: Colors.orange,
            ),
          );
          Navigator.pop(context);
        }
        return;
      }

      // Link phone number
      await user.linkWithCredential(credential);

      // Refresh token
      await user.getIdToken(true);

      // Save to Firestore with timeout
      try {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .set({
              'phoneNumber': user.phoneNumber,
              'updatedAt': FieldValue.serverTimestamp(),
            }, SetOptions(merge: true))
            .timeout(const Duration(seconds: 10));
      } catch (e) {
        // Continue even if Firestore fails
        print('Firestore update failed: $e');
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("🎉 Phone number linked successfully!"),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context);
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        String errorMessage = "Linking failed";
        switch (e.code) {
          case 'provider-already-linked':
            errorMessage = "Phone number already linked to your account";
            break;
          case 'credential-already-in-use':
            errorMessage = "This phone number is linked to another account";
            break;
          case 'invalid-verification-code':
            errorMessage = "Invalid verification code";
            break;
          case 'session-expired':
            errorMessage = "Verification session expired. Please try again";
            setState(() => _codeSent = false);
            break;
          default:
            errorMessage = e.message ?? 'Linking failed';
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("❌ $errorMessage"),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("❌ Error: ${e.toString()}"),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
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
