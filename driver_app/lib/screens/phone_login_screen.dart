// phone_login_screen.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'home_screen.dart';
import 'pending_approval_screen.dart';

class PhoneLoginScreen extends StatefulWidget {
  const PhoneLoginScreen({super.key});

  @override
  State<PhoneLoginScreen> createState() => _PhoneLoginScreenState();
}

class _PhoneLoginScreenState extends State<PhoneLoginScreen> {
  final _phoneCtrl = TextEditingController();
  final _codeCtrl = TextEditingController();

  bool _sending = false;
  bool _verifying = false;
  String? _verificationId;
  int? _resendToken;

  final _e164 = RegExp(r'^\+[1-9]\d{6,14}$'); // basic E.164

  @override
  void dispose() {
    _phoneCtrl.dispose();
    _codeCtrl.dispose();
    super.dispose();
  }

  // ---------------- SMS flow ----------------
  Future<void> _sendCode() async {
    final phone = _phoneCtrl.text.trim();
    if (!_e164.hasMatch(phone)) {
      _toast('Enter phone in E.164 format, e.g. +15551234567');
      return;
    }

    setState(() => _sending = true);

    await FirebaseAuth.instance.verifyPhoneNumber(
      phoneNumber: phone,
      forceResendingToken: _resendToken,
      verificationCompleted: (PhoneAuthCredential credential) async {
        try {
          await FirebaseAuth.instance.signInWithCredential(credential);
          await _postSignInGates(phone);
        } catch (_) {
          // fall back to manual code entry
        }
      },
      verificationFailed: (FirebaseAuthException e) {
        if (!mounted) return;
        _toast('Verification failed: ${e.message ?? e.code}');
      },
      codeSent: (String verificationId, int? resendToken) {
        if (!mounted) return;
        setState(() {
          _verificationId = verificationId;
          _resendToken = resendToken;
        });
        _toast('Code sent. Check your SMS.');
      },
      codeAutoRetrievalTimeout: (String verificationId) {
        if (!mounted) return;
        setState(() {
          _verificationId = verificationId;
        });
      },
    );

    if (mounted) setState(() => _sending = false);
  }

  Future<void> _verifyCode() async {
    final code = _codeCtrl.text.trim();
    if ((_verificationId ?? '').isEmpty || code.length != 6) {
      _toast('Enter the 6-digit code');
      return;
    }
    if (!RegExp(r'^\d{6}$').hasMatch(code)) {
      _toast('Code should only contain digits.');
      return;
    }

    setState(() => _verifying = true);
    final phone = _phoneCtrl.text.trim();

    try {
      final cred = PhoneAuthProvider.credential(
        verificationId: _verificationId!,
        smsCode: code,
      );
      await FirebaseAuth.instance.signInWithCredential(cred);
      await _postSignInGates(phone);
    } on FirebaseAuthException catch (e) {
      _toast('Invalid code: ${e.message ?? e.code}');
    } finally {
      if (mounted) setState(() => _verifying = false);
    }
  }

  // ---------------- Driver resolution helpers ----------------

  /// Normalize approval from diverse shapes to "approved" | "pending".
  String _normalizeApproval(Map<String, dynamic> d) {
    final raw = d['approvalStatus'];
    if (raw is String) return raw.toLowerCase().trim();
    if (raw is bool) return raw ? 'approved' : 'pending';
    final alt1 = d['status'];
    if (alt1 is String) return alt1.toLowerCase().trim();
    final alt2 = d['approved'];
    if (alt2 is bool) return alt2 ? 'approved' : 'pending';
    return 'pending';
  }

  /// Prefer /drivers/{uid}; else by phone; else by phone_index.email; else by email (lowercased).
  Future<DocumentReference<Map<String, dynamic>>> _resolveDriverRef({
    required FirebaseFirestore fs,
    required User user,
    required String phone,
  }) async {
    // 1) /drivers/{uid}
    DocumentReference<Map<String, dynamic>> ref = fs
        .collection('drivers')
        .doc(user.uid);
    var snap = await ref.get();
    if (snap.exists) return ref;

    // 2) drivers.phone == phone
    if (phone.isNotEmpty) {
      final byPhone = await fs
          .collection('drivers')
          .where('phone', isEqualTo: phone)
          .limit(1)
          .get();
      if (byPhone.docs.isNotEmpty) return byPhone.docs.first.reference;
    }

    // 3) phone_index -> email
    if (phone.isNotEmpty) {
      final idx = await fs.collection('phone_index').doc(phone).get();
      final emailFromIndex =
          (idx.data()?['email'] as String?)?.toLowerCase() ?? '';
      if (emailFromIndex.isNotEmpty) {
        final byIdxEmail = await fs
            .collection('drivers')
            .where('email', isEqualTo: emailFromIndex)
            .limit(1)
            .get();
        if (byIdxEmail.docs.isNotEmpty) return byIdxEmail.docs.first.reference;
      }
    }

    // 4) user.email (if any)
    final emailLc = (user.email ?? '').toLowerCase();
    if (emailLc.isNotEmpty) {
      final byEmail = await fs
          .collection('drivers')
          .where('email', isEqualTo: emailLc)
          .limit(1)
          .get();
      if (byEmail.docs.isNotEmpty) return byEmail.docs.first.reference;
    }

    // Fallback: create at /drivers/{uid}
    return ref;
  }

  /// Maintain phone_index and email_phone_links together (best-effort).
  Future<void> _upsertLinkDocs({
    required FirebaseFirestore fs,
    required String uid,
    required String phone,
    required List<String> emailCandidates, // already lowercased
  }) async {
    final now = FieldValue.serverTimestamp();
    final emailLc = emailCandidates.firstWhere(
      (e) => e.trim().isNotEmpty,
      orElse: () => '',
    );

    final batch = fs.batch();

    // Always maintain phone_index
    final phoneRef = fs.collection('phone_index').doc(phone);
    if (emailLc.isNotEmpty) {
      batch.set(phoneRef, {
        'userId': uid,
        'email': emailLc,
        'verifiedAt': now,
        'updatedAt': now,
      }, SetOptions(merge: true));

      // Also maintain email -> phone link (lets email login find this phone account)
      final linkRef = fs.collection('email_phone_links').doc(emailLc);
      batch.set(linkRef, {
        'email': emailLc,
        'phone': phone,
        'uid': uid,
        'linkedAt': now,
      }, SetOptions(merge: true));
    } else {
      // No email known yet; keep index without email field
      batch.set(phoneRef, {
        'userId': uid,
        'verifiedAt': now,
        'updatedAt': now,
      }, SetOptions(merge: true));
    }

    await batch.commit();
  }

  // ---------------- Post-sign-in gates ----------------
  /// Runs AFTER successful phone sign-in.
  /// Creates or updates driver profile (without clobbering approval) and routes.
  Future<void> _postSignInGates(String phoneUsed) async {
    final auth = FirebaseAuth.instance;
    final fs = FirebaseFirestore.instance;
    final user = auth.currentUser;
    if (user == null) return;

    try {
      // Resolve driver doc using multiple keys
      final driverRef = await _resolveDriverRef(
        fs: fs,
        user: user,
        phone: phoneUsed,
      );
      final existing = await driverRef.get();
      final now = FieldValue.serverTimestamp();

      String fallbackName = 'Driver';
      if ((user.displayName ?? '').trim().isNotEmpty) {
        fallbackName = user.displayName!.trim();
      }

      final emailLcFromUser = (user.email ?? '').toLowerCase();

      if (!existing.exists) {
        // New doc -> start as pending (do NOT auto-approve)
        await driverRef.set({
          'userId': user.uid,
          'fullName': fallbackName,
          'email': emailLcFromUser,
          'phone': phoneUsed,
          'role': 'driver',
          'isActive': false,
          'approvalStatus': 'pending',
          'createdAt': now,
          'updatedAt': now,
          'lastLogin': now,
          'source': 'phone-login',
          'linkedPhone': phoneUsed,
          'phoneVerified': true,
          'phoneVerifiedAt': now,
        }, SetOptions(merge: true));
      } else {
        final d = existing.data() ?? {};
        // Patch essentials, but DO NOT touch approvalStatus if it exists
        final patch = <String, dynamic>{
          'userId': d['userId'] ?? user.uid,
          'fullName': d['fullName'] ?? fallbackName,
          'email': (d['email'] as String?)?.toLowerCase() ?? emailLcFromUser,
          'phone': phoneUsed,
          'role': (d['role'] as String? ?? 'driver').toLowerCase(),
          'updatedAt': now,
          'lastLogin': now,
          'linkedPhone': phoneUsed,
          'phoneVerified': true,
          'phoneVerifiedAt': now,
        };
        await driverRef.set(patch, SetOptions(merge: true));
      }

      // Re-read to pick up any email stored on the driver (for linking)
      final finalSnap = await driverRef.get();
      final data = finalSnap.data() ?? {};
      final role = ((data['role'] as String?) ?? 'driver').toLowerCase().trim();
      final approval = _normalizeApproval(data);

      // Upsert link docs: prefer user.email, else driver.email
      final emailLcFromDriver = (data['email'] as String?)?.toLowerCase() ?? '';
      await _upsertLinkDocs(
        fs: fs,
        uid: user.uid,
        phone: phoneUsed,
        emailCandidates: [emailLcFromUser, emailLcFromDriver],
      );

      if (role != 'driver') {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('This account is not registered as a driver.'),
            backgroundColor: Colors.red,
          ),
        );
        await auth.signOut();
        return;
      }

      if (!mounted) return;
      if (approval == 'approved') {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const HomeScreen()),
          (_) => false,
        );
      } else {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const PendingApprovalScreen()),
          (_) => false,
        );
      }
    } catch (e) {
      _toast('Error setting up profile: $e');
    }
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  // ---------------- UI ----------------
  @override
  Widget build(BuildContext context) {
    final border = OutlineInputBorder(borderRadius: BorderRadius.circular(12));
    final codeStep = _verificationId != null;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Login with Phone'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.black87,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Enter your phone number',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _phoneCtrl,
                enabled: !codeStep && !_sending,
                keyboardType: TextInputType.phone,
                decoration: InputDecoration(
                  hintText: '+15551234567',
                  prefixIcon: const Icon(Icons.phone),
                  border: border,
                ),
              ),
              const SizedBox(height: 16),

              if (codeStep) ...[
                const Text(
                  'Enter the 6-digit code',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _codeCtrl,
                  keyboardType: TextInputType.number,
                  maxLength: 6,
                  decoration: InputDecoration(
                    hintText: '123456',
                    prefixIcon: const Icon(Icons.sms),
                    counterText: '',
                    border: border,
                  ),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: _sending
                      ? null
                      : () {
                          // allow changing number mid-flow
                          setState(() {
                            _verificationId = null;
                            _resendToken = null; // reset throttling context
                            _codeCtrl.clear();
                          });
                        },
                  child: const Text('Change number'),
                ),
              ],

              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: codeStep
                      ? (_verifying ? null : _verifyCode)
                      : (_sending ? null : _sendCode),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: codeStep
                      ? (_verifying
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                            : const Text('Verify & Login'))
                      : (_sending
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                            : const Text('Send code')),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
