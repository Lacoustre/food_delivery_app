import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// Go to the review page after signup (update path as needed)
import 'pending_approval_screen.dart';
import '../services/services.dart'; // AuthService with createAccount() and sendEmailVerification()

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  final _emailRegex = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');
  final _e164 = RegExp(r'^\+[1-9]\d{6,14}$'); // + and 7–15 digits

  // Simple rate limiting for signup attempts
  static int _signupAttempts = 0;
  static DateTime? _lastAttempt;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  bool _isRateLimited() {
    if (_lastAttempt != null) {
      final elapsed = DateTime.now().difference(_lastAttempt!);
      if (elapsed.inMinutes < 1 && _signupAttempts >= 3) return true;
      if (elapsed.inMinutes >= 1) _signupAttempts = 0; // reset after 1 min
    }
    return false;
  }

  Future<void> _signup() async {
    FocusScope.of(context).unfocus();

    // Rate limiting check
    if (_isRateLimited()) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Too many signup attempts. Please wait a minute.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    _signupAttempts++;
    _lastAttempt = DateTime.now();

    final fs = FirebaseFirestore.instance;

    final name = _nameController.text.trim();
    final emailInput = _emailController.text.trim();
    final email = emailInput.toLowerCase(); // normalize for storage/lookup
    final phone = _phoneController.text.trim();

    UserCredential? cred;

    try {
      // Extra input checks beyond the validators (defense in depth)
      if (!_isValidName(name) ||
          !_isValidEmail(email) ||
          !_isValidPhone(phone)) {
        throw FirebaseAuthException(
          code: 'invalid-input',
          message: 'Invalid input detected.',
        );
      }

      // 1) Create email/password account using AuthService
      cred = await AuthService.createAccount(email, _passwordController.text);
      final user = cred.user!;
      await user.updateDisplayName(name);

      // Best-effort email verification (non-blocking)
      try {
        await AuthService.sendEmailVerification();
      } catch (_) {}

      // (Optional) Now that we’re signed in, we *may* check if phone already claimed.
      final phoneClaim = await fs.collection('phone_index').doc(phone).get();
      final claimedBy =
          phoneClaim.data()?['userId'] ?? phoneClaim.data()?['uid'];
      if (phoneClaim.exists && claimedBy != null && claimedBy != user.uid) {
        throw FirebaseAuthException(
          code: 'phone-already-in-use',
          message: 'This phone number is already linked to another account.',
        );
      }

      // Check if phone exists in customer database
      final customerQuery = await fs
          .collection('users')
          .where('phone', isEqualTo: phone)
          .limit(1)
          .get();
      if (customerQuery.docs.isNotEmpty) {
        throw FirebaseAuthException(
          code: 'phone-already-in-use',
          message:
              'This phone number is registered as a customer. Please use a different number.',
        );
      }

      // 2) Require phone link + atomic driver doc creation (or merge)
      final ok = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (_) => _RequiredPhoneLinkDialog(
          user: user,
          phone: phone,
          driverPayload: {
            // IMPORTANT: rules expect userId == auth.uid
            'uid': user.uid, // keep for admin tooling if you use it
            'userId': user.uid,
            'fullName': name,
            'email': email, // normalized
            'phone': phone,
            'licenseNumber': null,
            'vehicleType': null,
            'role': 'driver',
            'isActive': false,
            'approvalStatus': 'pending', // default ONLY for brand-new docs
            'createdAt': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
            'source': 'driver-app',
            'signupIP': null,
          },
        ),
      );

      if (ok != true) {
        throw FirebaseAuthException(
          code: 'phone-link-required',
          message: 'Phone linking is required.',
        );
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Signup complete. Approval pending.'),
          backgroundColor: Colors.green,
        ),
      );

      // Reset rate limiting on successful signup
      _signupAttempts = 0;

      // 3) Go to Pending Approval screen (driver sees live status)
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const PendingApprovalScreen()),
      );
    } on FirebaseAuthException catch (e) {
      await _handleAuthError(e, cred);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Something went wrong: ${e.toString().length > 100 ? "Please try again." : e.toString()}',
          ),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleAuthError(
    FirebaseAuthException e,
    UserCredential? cred,
  ) async {
    String message = 'Signup failed. Please try again.';
    switch (e.code) {
      case 'weak-password':
        message =
            'Password is too weak (use 8+ chars with letters, numbers & special characters).';
        break;
      case 'email-already-in-use':
        message = 'Email is already registered.';
        break;
      case 'invalid-email':
        message = 'Invalid email address.';
        break;
      case 'phone-already-in-use':
        message = 'This phone number is already linked to another account.';
        break;
      case 'email-already-linked':
        message = 'This email is already linked to a phone number.';
        break;
      case 'phone-link-required':
        message = 'You must link your phone to finish signup.';
        break;
      case 'network-request-failed':
        message = 'Network error. Check your connection and try again.';
        break;
      case 'too-many-requests':
        message = 'Too many attempts. Please wait and try again.';
        break;
      case 'permission-denied':
        message = 'Permission denied. Please contact support.';
        break;
      case 'invalid-input':
        message = 'Invalid input detected. Please check your information.';
        break;
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 5),
        ),
      );
    }

    // Optional cleanup on error (don’t delete if flow was cancelled for phone link)
    if (e.code != 'phone-link-required') {
      try {
        await cred?.user?.delete();
      } catch (_) {}
    }
  }

  // Validation helpers
  bool _isValidName(String name) =>
      name.length >= 2 &&
      name.length <= 50 &&
      RegExp(r"^[a-zA-Z\s\-'\.]+$").hasMatch(name);

  bool _isValidEmail(String email) =>
      email.length <= 254 && _emailRegex.hasMatch(email);

  bool _isValidPhone(String phone) => _e164.hasMatch(phone);

  String? _validateName(String? v) {
    if (v == null || v.trim().isEmpty) return 'Name is required';
    final t = v.trim();
    if (t.length < 2) return 'Enter your full name (at least 2 characters)';
    if (t.length > 50) return 'Name too long (max 50 characters)';
    if (!RegExp(r"^[a-zA-Z\s\-'\.]+$").hasMatch(t)) {
      return 'Name contains invalid characters';
    }
    return null;
  }

  String? _validateEmail(String? v) {
    if (v == null || v.trim().isEmpty) return 'Email is required';
    final t = v.trim();
    if (t.length > 254) return 'Email too long';
    if (!_emailRegex.hasMatch(t)) return 'Enter a valid email';
    return null;
  }

  String? _validatePhone(String? v) {
    if (v == null || v.trim().isEmpty) return 'Phone number is required';
    if (!_e164.hasMatch(v.trim())) {
      return 'Enter phone in E.164 format, e.g. +15551234567';
    }
    return null;
  }

  String? _validatePassword(String? v) {
    if (v == null || v.isEmpty) return 'Password is required';
    if (v.length < 8) return 'Password must be at least 8 characters';
    if (v.length > 128) return 'Password too long (max 128 characters)';
    if (!RegExp(r'(?=.*[A-Za-z])').hasMatch(v)) {
      return 'Password must contain letters';
    }
    if (!RegExp(r'(?=.*\d)').hasMatch(v)) {
      return 'Password must contain numbers';
    }
    if (!RegExp(r'(?=.*[@$!%*?&])').hasMatch(v)) {
      return 'Password must contain special characters (@\$!%*?&)';
    }
    return null;
  }

  String? _validateConfirm(String? v) {
    if (v == null || v.isEmpty) return 'Please confirm your password';
    if (v != _passwordController.text) return 'Passwords do not match';
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final border = OutlineInputBorder(borderRadius: BorderRadius.circular(12));
    final theme = Theme.of(context);

    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) {
        if (!didPop) {
          // Prevent going back to onboarding, go to auth screen instead
          Navigator.pushReplacementNamed(context, '/auth');
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Driver Signup'),
          backgroundColor: Colors.transparent,
          elevation: 0,
          foregroundColor: theme.textTheme.bodyLarge?.color,
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Join Our Team!',
                    style: theme.textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Create your driver account',
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 32),

                  TextFormField(
                    controller: _nameController,
                    textCapitalization: TextCapitalization.words,
                    decoration: InputDecoration(
                      labelText: 'Full Name',
                      prefixIcon: const Icon(Icons.person_outlined),
                      border: border,
                      helperText: 'Enter your full legal name',
                    ),
                    validator: _validateName,
                  ),
                  const SizedBox(height: 16),

                  TextFormField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    autocorrect: false,
                    decoration: InputDecoration(
                      labelText: 'Email',
                      prefixIcon: const Icon(Icons.email_outlined),
                      border: border,
                    ),
                    validator: _validateEmail,
                  ),
                  const SizedBox(height: 16),

                  TextFormField(
                    controller: _phoneController,
                    keyboardType: TextInputType.phone,
                    decoration: InputDecoration(
                      labelText: 'Phone Number',
                      hintText: '+15551234567',
                      prefixIcon: const Icon(Icons.phone_outlined),
                      border: border,
                      helperText: 'Use E.164 format with country code',
                    ),
                    validator: _validatePhone,
                  ),
                  const SizedBox(height: 16),

                  TextFormField(
                    controller: _passwordController,
                    obscureText: _obscurePassword,
                    autocorrect: false,
                    enableSuggestions: false,
                    decoration: InputDecoration(
                      labelText: 'Password',
                      prefixIcon: const Icon(Icons.lock_outlined),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscurePassword
                              ? Icons.visibility
                              : Icons.visibility_off,
                        ),
                        onPressed: () => setState(
                          () => _obscurePassword = !_obscurePassword,
                        ),
                      ),
                      border: border,
                      helperText: '8+ chars with letters, numbers & symbols',
                    ),
                    validator: _validatePassword,
                  ),
                  const SizedBox(height: 16),

                  TextFormField(
                    controller: _confirmPasswordController,
                    obscureText: _obscureConfirmPassword,
                    autocorrect: false,
                    enableSuggestions: false,
                    decoration: InputDecoration(
                      labelText: 'Confirm Password',
                      prefixIcon: const Icon(Icons.lock_outlined),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscureConfirmPassword
                              ? Icons.visibility
                              : Icons.visibility_off,
                        ),
                        onPressed: () => setState(
                          () => _obscureConfirmPassword =
                              !_obscureConfirmPassword,
                        ),
                      ),
                      border: border,
                    ),
                    validator: _validateConfirm,
                  ),
                  const SizedBox(height: 24),

                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _signup,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        disabledBackgroundColor: Colors.grey.shade300,
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : const Text(
                              'Sign Up',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  Text(
                    'By signing up, you agree to our Terms of Service and Privacy Policy. Your phone number will be verified via SMS.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: Colors.grey.shade600,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ========= Phone linking (required) dialog =========
class _RequiredPhoneLinkDialog extends StatefulWidget {
  final User user;
  final String phone;
  final Map<String, dynamic> driverPayload;

  const _RequiredPhoneLinkDialog({
    required this.user,
    required this.phone,
    required this.driverPayload,
  });

  @override
  State<_RequiredPhoneLinkDialog> createState() =>
      _RequiredPhoneLinkDialogState();
}

class _RequiredPhoneLinkDialogState extends State<_RequiredPhoneLinkDialog> {
  String? _verificationId;
  int? _resendToken;
  final _codeCtrl = TextEditingController();
  bool _sending = false;
  bool _verifying = false;
  String? _error;
  Timer? _resendTimer;
  int _resendCountdown = 0;

  @override
  void initState() {
    super.initState();
    _sendCode();
  }

  @override
  void dispose() {
    _codeCtrl.dispose();
    _resendTimer?.cancel();
    super.dispose();
  }

  void _startResendTimer() {
    _resendCountdown = 60;
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        _resendCountdown--;
        if (_resendCountdown <= 0) timer.cancel();
      });
    });
  }

  Future<void> _sendCode() async {
    if (_sending) return;
    setState(() {
      _sending = true;
      _error = null;
    });

    try {
      await FirebaseAuth.instance.verifyPhoneNumber(
        phoneNumber: widget.phone,
        forceResendingToken: _resendToken,
        timeout: const Duration(seconds: 60),
        verificationCompleted: (PhoneAuthCredential credential) async {
          try {
            await widget.user.linkWithCredential(credential);
            await _writeDocsOrRollback();
          } catch (e) {
            if (!mounted) return;
            setState(
              () =>
                  _error = 'Auto verification failed. Enter the code manually.',
            );
          }
        },
        verificationFailed: (FirebaseAuthException e) {
          if (!mounted) return;
          setState(() => _error = _getReadablePhoneError(e));
        },
        codeSent: (String id, int? token) {
          if (!mounted) return;
          setState(() {
            _verificationId = id;
            _resendToken = token;
          });
          _startResendTimer();
        },
        codeAutoRetrievalTimeout: (String id) {
          _verificationId = id;
        },
      );
    } catch (e) {
      if (mounted) {
        setState(
          () => _error = 'Failed to send verification code. Please try again.',
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  String _getReadablePhoneError(FirebaseAuthException e) {
    switch (e.code) {
      case 'invalid-phone-number':
        return 'Invalid phone number format.';
      case 'too-many-requests':
        return 'Too many requests. Please try again later.';
      case 'network-request-failed':
        return 'Network error. Check your connection.';
      default:
        return e.message ?? 'Phone verification failed.';
    }
  }

  Future<void> _verifyCode() async {
    final code = _codeCtrl.text.trim();
    if ((_verificationId ?? '').isEmpty || code.length != 6) {
      setState(() => _error = 'Enter the complete 6-digit code.');
      return;
    }
    if (!RegExp(r'^\d{6}$').hasMatch(code)) {
      setState(() => _error = 'Code should only contain digits.');
      return;
    }

    setState(() {
      _verifying = true;
      _error = null;
    });

    try {
      final cred = PhoneAuthProvider.credential(
        verificationId: _verificationId!,
        smsCode: code,
      );
      await widget.user.linkWithCredential(cred);
      await _writeDocsOrRollback();
    } on FirebaseAuthException catch (e) {
      if (mounted) setState(() => _error = _getReadableVerificationError(e));
    } finally {
      if (mounted) setState(() => _verifying = false);
    }
  }

  String _getReadableVerificationError(FirebaseAuthException e) {
    switch (e.code) {
      case 'invalid-verification-code':
        return 'Invalid verification code. Please try again.';
      case 'session-expired':
        return 'Verification session expired. Please request a new code.';
      case 'credential-already-in-use':
      case 'provider-already-linked':
        return 'This phone is already linked to an account.';
      default:
        return e.message ?? 'Verification failed.';
    }
  }

  /// Atomic write:
  /// - Reuse existing driver doc by email/phone if present (admin-created)
  /// - Create phone_index
  /// - Upsert drivers doc without overwriting approvalStatus if it already exists
  /// - Create/refresh email_phone_links (email lowercased)
  Future<void> _writeDocsOrRollback() async {
    final fs = FirebaseFirestore.instance;
    final uid = widget.user.uid;
    final phoneKey = widget.phone;
    final emailLc = (widget.user.email ?? '').toLowerCase();

    try {
      // Final sanity check: no one else claimed this phone
      final claim = await fs.collection('phone_index').doc(phoneKey).get();
      final claimed = claim.data()?['userId'] ?? claim.data()?['uid'];
      if (claim.exists && claimed != uid) {
        throw FirebaseAuthException(
          code: 'phone-already-in-use',
          message: 'Phone already linked to another account.',
        );
      }

      // Find driver doc: prefer /drivers/{uid}, else by email, else by phone
      DocumentReference<Map<String, dynamic>> driverRef = fs
          .collection('drivers')
          .doc(uid);
      DocumentSnapshot<Map<String, dynamic>> snap = await driverRef.get();

      if (!snap.exists && emailLc.isNotEmpty) {
        final byEmail = await fs
            .collection('drivers')
            .where('email', isEqualTo: emailLc)
            .limit(1)
            .get();
        if (byEmail.docs.isNotEmpty) {
          driverRef = byEmail.docs.first.reference;
          snap = byEmail.docs.first;
        }
      }

      if (!snap.exists) {
        final byPhone = await fs
            .collection('drivers')
            .where('phone', isEqualTo: phoneKey)
            .limit(1)
            .get();
        if (byPhone.docs.isNotEmpty) {
          driverRef = byPhone.docs.first.reference;
          snap = byPhone.docs.first;
        }
      }

      final batch = fs.batch();

      // phone_index
      final phoneRef = fs.collection('phone_index').doc(phoneKey);
      batch.set(phoneRef, {
        'userId': uid,
        'email': emailLc,
        'verifiedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      // drivers doc (two paths so we don't overwrite approval on existing docs)
      if (!snap.exists) {
        // New driver doc -> include default approvalStatus: 'pending'
        batch.set(driverRef, {
          ...widget.driverPayload,
          'email': emailLc, // normalize
          'linkedPhone': phoneKey,
          'phoneVerified': true,
          'phoneVerifiedAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
          'lastLogin': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      } else {
        // Existing driver doc -> do NOT touch approvalStatus
        batch.set(driverRef, {
          'uid': uid,
          'userId': uid,
          'fullName': widget.driverPayload['fullName'],
          'email': emailLc,
          'phone': phoneKey,
          'role': 'driver',
          'linkedPhone': phoneKey,
          'phoneVerified': true,
          'phoneVerifiedAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
          'lastLogin': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }

      // Skip email_phone_links - not needed for driver app

      await batch.commit();

      if (!mounted) return;
      Navigator.of(context).pop(true); // success
    } catch (e) {
      // Roll back the auth phone link if Firestore write fails
      try {
        await widget.user.unlink('phone');
      } catch (_) {}
      if (mounted) {
        setState(() => _error = 'Could not finish signup. Please try again.');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: AlertDialog(
        title: const Text('Verify Your Phone'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'We sent a 6-digit code to:',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 4),
            Text(
              widget.phone,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _codeCtrl,
              keyboardType: TextInputType.number,
              maxLength: 6,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 18,
                letterSpacing: 4,
                fontWeight: FontWeight.bold,
              ),
              decoration: const InputDecoration(
                hintText: '000000',
                counterText: '',
                border: OutlineInputBorder(),
              ),
              onSubmitted: (_) => _verifyCode(),
              onChanged: (value) {
                if (value.length == 6) _verifyCode();
              },
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: Colors.red.shade200),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.error_outline,
                      color: Colors.red.shade700,
                      size: 16,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _error!,
                        style: TextStyle(
                          color: Colors.red.shade700,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: _sending || _resendCountdown > 0 ? null : _sendCode,
            child: _sending
                ? const Text('Sending...')
                : _resendCountdown > 0
                ? Text('Resend in ${_resendCountdown}s')
                : const Text('Resend Code'),
          ),
          ElevatedButton(
            onPressed: _verifying ? null : _verifyCode,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              foregroundColor: Colors.white,
            ),
            child: _verifying
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                : const Text('Verify & Continue'),
          ),
        ],
      ),
    );
  }
}
