import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:sms_autofill/sms_autofill.dart';
import 'auth_service.dart';

class PhoneAuthPage extends StatefulWidget {
  const PhoneAuthPage({super.key});

  @override
  State<PhoneAuthPage> createState() => _PhoneAuthPageState();
}

class _PhoneAuthPageState extends State<PhoneAuthPage> with CodeAutoFill {
  final AuthService _authService = AuthService();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _otpController = TextEditingController();

  String? _verificationId;
  bool _isLoading = false;
  bool _codeSent = false;
  int? _resendToken;
  int _cooldown = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    listenForCode();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _phoneController.dispose();
    _otpController.dispose();
    cancel(); // stop sms_autofill listener
    super.dispose();
  }

  @override
  void codeUpdated() {
    _otpController.text = code!;
    _verifyOTP(); // auto-submit
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

  Future<void> _verifyPhoneNumber({bool isResend = false}) async {
    final phone = _phoneController.text.trim();
    if (phone.isEmpty) return;

    setState(() => _isLoading = true);
    try {
      await _authService.verifyPhoneNumber(
        phoneNumber: phone,
        forceResendingToken: isResend ? _resendToken : null,
        onVerificationCompleted: (PhoneAuthCredential credential) async {
          final result = await _authService.signInWithPhoneCredential(
            credential,
          );
          await _authService.saveUserPhoneToFirestore(result.user!);
          if (mounted) Navigator.pushReplacementNamed(context, '/auth');
        },
        onVerificationFailed: (FirebaseAuthException e) {
          setState(() => _isLoading = false);
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Error: ${e.message}')));
        },
        onCodeSent: (String verificationId, int? resendToken) {
          setState(() {
            _verificationId = verificationId;
            _resendToken = resendToken;
            _codeSent = true;
            _isLoading = false;
          });
          _startCooldown();
        },
        onCodeAutoRetrievalTimeout: (String verificationId) {
          _verificationId = verificationId;
        },
      );
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: ${e.toString()}')));
    }
  }

  Future<void> _verifyOTP() async {
    if (_verificationId == null) return;

    setState(() => _isLoading = true);
    try {
      final credential = PhoneAuthProvider.credential(
        verificationId: _verificationId!,
        smsCode: _otpController.text.trim(),
      );

      final result = await _authService.signInWithPhoneCredential(credential);
      await _authService.saveUserPhoneToFirestore(result.user!);

      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser != null &&
          currentUser.email != null &&
          currentUser.uid != result.user!.uid) {
        try {
          await currentUser.linkWithCredential(credential);
        } catch (_) {}
      }

      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("🎉 Successfully signed in!"),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pushReplacementNamed(context, '/auth');
      }
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('❌ Invalid OTP. Please try again.')),
      );
    }
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

              // 🎨 Custom OTP Autofill field
              PinFieldAutoFill(
                controller: _otpController,
                codeLength: 6,
                onCodeChanged: (code) {
                  if (code != null && code.length == 6) {
                    _verifyOTP();
                  }
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
                  onPressed: () => _verifyPhoneNumber(isResend: true),
                  child: const Text('🔁 Resend Code'),
                ),
              TextButton(
                onPressed: () => setState(() => _codeSent = false),
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
