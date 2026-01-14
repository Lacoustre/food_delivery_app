import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:sms_autofill/sms_autofill.dart';

class PhoneAuthPage extends StatefulWidget {
  const PhoneAuthPage({super.key});

  @override
  State<PhoneAuthPage> createState() => _PhoneAuthPageState();
}

class _PhoneAuthPageState extends State<PhoneAuthPage> with CodeAutoFill {
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _otpController = TextEditingController();

  String? _verificationId;
  int? _resendToken;
  bool _codeSent = false;
  bool _isLoading = false;

  int _cooldown = 0;
  Timer? _timer;

  int _attemptCount = 0;
  DateTime? _lastAttempt;

  @override
  void initState() {
    super.initState();
    listenForCode(); // sms_autofill
  }

  @override
  void dispose() {
    _timer?.cancel();
    _phoneController.dispose();
    _otpController.dispose();
    cancel(); // stop sms_autofill listener
    super.dispose();
  }

  // Auto-filled code callback
  @override
  void codeUpdated() {
    if (code != null && code!.length == 6) {
      _otpController.text = code!;
      _verifyOTP();
    }
  }

  void _startCooldown() {
    setState(() => _cooldown = 60);
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_cooldown <= 0) {
        t.cancel();
      } else {
        setState(() => _cooldown--);
      }
    });
  }

  Future<void> _verifyPhoneNumber({bool isResend = false}) async {
    final phone = _phoneController.text.trim();

    if (phone.isEmpty) {
      _toast('Please enter a phone number');
      return;
    }
    if (!phone.startsWith('+') || phone.length < 10) {
      _toast('Include country code (e.g., +1234567890)');
      return;
    }

    // Simple rate limit: 3 attempts per minute
    if (_lastAttempt != null &&
        DateTime.now().difference(_lastAttempt!).inMinutes < 1 &&
        _attemptCount >= 3) {
      _toast('Too many attempts. Please wait a minute.');
      return;
    }

    setState(() => _isLoading = true);
    _attemptCount++;
    _lastAttempt = DateTime.now();

    await FirebaseAuth.instance.verifyPhoneNumber(
      phoneNumber: phone,
      forceResendingToken: isResend ? _resendToken : null,
      verificationCompleted: (PhoneAuthCredential credential) async {
        // Instant verification or auto-retrieval
        try {
          await _applyCredential(credential, expectedPhone: phone);
          if (!mounted) return;
          _toast('Phone verified');
          Navigator.pushReplacementNamed(context, '/auth');
        } on FirebaseAuthException catch (e) {
          if (!mounted) return;
          _handleAuthError(e);
        } catch (e) {
          if (!mounted) return;
          _toast('Sign in failed: $e', error: true);
        }
      },
      verificationFailed: (FirebaseAuthException e) {
        if (!mounted) return;
        setState(() => _isLoading = false);
        _handleAuthError(e);
      },
      codeSent: (String verificationId, int? resendToken) {
        if (!mounted) return;
        setState(() {
          _verificationId = verificationId;
          _resendToken = resendToken;
          _codeSent = true;
          _isLoading = false;
        });
        _startCooldown();
      },
      codeAutoRetrievalTimeout: (String verificationId) {
        _verificationId = verificationId;
      },
      timeout: const Duration(seconds: 60),
    );
  }

  Future<void> _verifyOTP() async {
    if (_verificationId == null) return;
    final sms = _otpController.text.trim();
    if (sms.length != 6) return;

    setState(() => _isLoading = true);
    try {
      final credential = PhoneAuthProvider.credential(
        verificationId: _verificationId!,
        smsCode: sms,
      );
      await _applyCredential(credential);
      if (!mounted) return;
      _toast('🎉 Successfully signed in!');
      Navigator.pushReplacementNamed(context, '/auth');
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);

      if (e.code == 'invalid-verification-code') {
        _toast('Invalid verification code.', error: true);
      } else if (e.code == 'session-expired') {
        _toast('Session expired. Please request a new code.', error: true);
        setState(() => _codeSent = false);
      } else {
        _handleAuthError(e);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      _toast('Verification failed: $e', error: true);
    }
  }

  /// Decide whether to LINK (if a user is already signed in) or SIGN IN (no user).
  Future<void> _applyCredential(
    PhoneAuthCredential cred, {
    String? expectedPhone,
  }) async {
    final current = FirebaseAuth.instance.currentUser;

    UserCredential result;
    if (current != null && current.phoneNumber == null) {
      // Link phone to existing account (email/password user)
      result = await current.linkWithCredential(cred);
    } else {
      // Pure phone sign-in (or user already has phone)
      result = await FirebaseAuth.instance.signInWithCredential(cred);
    }

    final user = result.user!;
    // Save phone + verified flag in Firestore (merge)
    final phone = expectedPhone ?? user.phoneNumber;
    if (phone != null && phone.isNotEmpty) {
      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'phone': phone,
        'phoneVerified': true,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    }
    if (mounted) setState(() => _isLoading = false);
  }

  void _handleAuthError(FirebaseAuthException e) {
    String message = 'Verification failed.';

    switch (e.code) {
      case 'too-many-requests':
        message = 'Too many requests. Try again later.';
        break;
      case 'invalid-phone-number':
        message = 'Invalid phone number format. Use +1234567890';
        break;
      case 'app-not-authorized':
        message = 'App not authorized for phone auth.';
        break;
      case 'captcha-check-failed':
        message = 'reCAPTCHA failed. Please try again.';
        break;
      case 'quota-exceeded':
        message = 'SMS quota exceeded. Try again later.';
        break;
      case 'credential-already-in-use':
        message = 'This phone number is already linked to another account.';
        break;
      case 'provider-already-linked':
        message = 'Phone already linked to this account.';
        break;
      default:
        message = e.message ?? message;
    }

    _toast(message, error: true);
  }

  void _toast(String msg, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: error ? Colors.red : Colors.green,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('📱 Phone Sign In'),
        backgroundColor: Colors.deepOrange,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Image.asset(
              'assets/images/logo.png',
              height: 120,
              fit: BoxFit.contain,
            ),
            const SizedBox(height: 10),
            Text(
              "Sign in using your phone number",
              style: theme.textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 30),

            if (!_codeSent) ...[
              TextField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: 'Phone Number',
                  hintText: '+1 234 567 8900',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.phone),
                  helperText: 'Include country code (e.g., +1 for US)',
                ),
                autofillHints: const [AutofillHints.telephoneNumber],
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                icon: const Icon(Icons.send),
                label: const Text('Send Verification Code'),
                onPressed: _isLoading ? null : () => _verifyPhoneNumber(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.deepOrange,
                  minimumSize: const Size.fromHeight(50),
                ),
              ),
            ] else ...[
              const Text('Enter the 6-digit code sent to your phone'),
              const SizedBox(height: 20),
              PinFieldAutoFill(
                controller: _otpController,
                codeLength: 6,
                onCodeChanged: (c) {
                  if (c != null && c.length == 6) _verifyOTP();
                },
                decoration: BoxLooseDecoration(
                  gapSpace: 12,
                  strokeWidth: 2,
                  strokeColorBuilder: FixedColorBuilder(Colors.deepOrange),
                  bgColorBuilder: FixedColorBuilder(Colors.deepOrange.shade50),
                  textStyle: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                icon: const Icon(Icons.verified),
                label: const Text('Verify Code'),
                onPressed: _isLoading ? null : _verifyOTP,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  minimumSize: const Size.fromHeight(50),
                ),
              ),
              const SizedBox(height: 8),
              if (_cooldown > 0)
                Text("⏱ Resend available in $_cooldown seconds")
              else
                TextButton(
                  onPressed: _isLoading
                      ? null
                      : () => _verifyPhoneNumber(isResend: true),
                  child: const Text('🔁 Resend Code'),
                ),
              TextButton(
                onPressed: _isLoading
                    ? null
                    : () => setState(() => _codeSent = false),
                child: const Text('📞 Change Phone Number'),
              ),
            ],

            if (_isLoading)
              const Padding(
                padding: EdgeInsets.only(top: 20),
                child: CircularProgressIndicator(color: Colors.deepOrange),
              ),
          ],
        ),
      ),
    );
  }
}
