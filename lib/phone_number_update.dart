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
  bool _codeSent = false;
  bool _isLoading = false;
  int _cooldown = 0;
  Timer? _timer;
  int _attemptCount = 0;
  DateTime? _lastAttempt;

  @override
  void initState() {
    super.initState();
    _loadCurrentPhone();
  }

  void _loadCurrentPhone() {
    final user = FirebaseAuth.instance.currentUser;
    if (user?.phoneNumber != null) {
      _phoneController.text = user!.phoneNumber!;
    }
  }

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
    if (phone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a phone number'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

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

    await _authService.updatePhoneNumberFlow(
      newPhoneNumber: phone,
      onCodeSent: (String verificationId, int? resendToken) {
        if (mounted) {
          setState(() {
            _verificationId = verificationId;
            _codeSent = true;
            _isLoading = false;
          });
          _startCooldown();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Verification code sent!'),
              backgroundColor: Colors.green,
            ),
          );
        }
      },
      onError: (msg) {
        if (mounted) {
          setState(() => _isLoading = false);
          String message = 'Verification failed';
          if (msg.contains('too-many-requests')) {
            message = 'Too many requests. Please try again later.';
          } else if (msg.contains('invalid-phone-number')) {
            message = 'Invalid phone number format.';
          } else {
            message = msg;
          }
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text("❌ $message"),
              backgroundColor: Colors.red,
            ),
          );
        }
      },
      onAutoRetrievalTimeout: (verificationId) {
        _verificationId = verificationId;
      },
    );
  }

  Future<void> _applyPhoneUpdate() async {
    final code = _otpController.text.trim();
    if (_verificationId == null || code.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter the verification code'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    if (code.length != 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a valid 6-digit code'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      await _authService.applyPhoneUpdate(_verificationId!, code);

      // Save phone number to Firestore with timeout
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
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
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Phone number updated successfully!'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context);
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        String message = 'Update failed';
        switch (e.code) {
          case 'invalid-verification-code':
            message = 'Invalid verification code';
            break;
          case 'session-expired':
            message = 'Verification session expired. Please try again';
            setState(() => _codeSent = false);
            break;
          case 'too-many-requests':
            message = 'Too many requests. Please try again later';
            break;
          default:
            message = e.message ?? 'Update failed';
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ $message'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Error: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
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
