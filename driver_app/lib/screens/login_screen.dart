import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:local_auth/local_auth.dart';
import '../firebase_options.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'home_screen.dart';
import 'pending_approval_screen.dart';
import 'verify_email_screen.dart';
import '../widgets/app_logo.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  // --- Controllers / Focus ---
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _emailFocusNode = FocusNode();
  final _passwordFocusNode = FocusNode();
  final _keyboardFocusNode = FocusNode();

  // --- UI State ---
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _biometricEnabled = false;
  bool _rememberMe = false;

  // --- Security ---
  int _failedAttempts = 0;
  DateTime? _lastFailedAttempt;
  static const int _maxFailedAttempts = 5;
  static const int _lockoutDurationMinutes = 15;
  Timer? _lockoutTimer;
  bool _isLockedOut = false;

  // Biometrics + secure storage
  final LocalAuthentication _localAuth = LocalAuthentication();
  final FlutterSecureStorage _secure = const FlutterSecureStorage();

  // Email/password validation
  final _emailRegex = RegExp(
    r'^[a-zA-Z0-9.!#$%&*+/=?^_`{|}~-]+@[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?(?:\.[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?)*$',
  );
  static const int _maxPasswordLength = 128;
  static const int _minPasswordLength = 6;
  static const int _maxEmailLength = 254;

  // SharedPreferences keys (non-sensitive)
  static const _kRememberMe = 'remember_me';
  static const _kSavedEmail = 'saved_email';
  static const _kBiometricEnabled = 'biometric_enabled';
  static const _kFailedAttempts = 'failed_attempts';
  static const _kLastFailedAttempt = 'last_failed_attempt';

  // Secure storage keys (sensitive) - with device binding
  static const _kSecEmail = 'sec_email_v2';
  static const _kSecPassword = 'sec_password_v2';
  static const _kDeviceId = 'device_id';

  // Platform storage options
  AndroidOptions _aOptions() => const AndroidOptions(
    encryptedSharedPreferences: true,
    resetOnError: true,
  );

  IOSOptions _iOptions() => const IOSOptions(
    accessibility: KeychainAccessibility.first_unlock_this_device,
    synchronizable: false,
  );

  @override
  void initState() {
    super.initState();
    _initializeScreen();
    // Ensure keyboard listener can receive events
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _keyboardFocusNode.requestFocus();
    });
  }

  Future<void> _initializeScreen() async {
    await _loadSecurityState();
    await _checkBiometricAvailability();
    await _loadSavedPreferences();
    _setupFormBehavior();
    _startLockoutTimerIfNeeded();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _emailFocusNode.dispose();
    _passwordFocusNode.dispose();
    _keyboardFocusNode.dispose();
    _lockoutTimer?.cancel();
    super.dispose();
  }

  // ---------------- Security state ----------------
  Future<void> _loadSecurityState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _failedAttempts = prefs.getInt(_kFailedAttempts) ?? 0;
      final lastFailedMs = prefs.getInt(_kLastFailedAttempt);

      if (lastFailedMs != null) {
        _lastFailedAttempt = DateTime.fromMillisecondsSinceEpoch(lastFailedMs);
        _updateLockoutState();
      }
    } catch (e) {
      debugPrint('Load security state error: $e');
    }
  }

  void _updateLockoutState() {
    if (_lastFailedAttempt != null && _failedAttempts >= _maxFailedAttempts) {
      final timeSinceLastFailure = DateTime.now().difference(
        _lastFailedAttempt!,
      );
      _isLockedOut = timeSinceLastFailure.inMinutes < _lockoutDurationMinutes;
    } else {
      _isLockedOut = false;
    }
  }

  void _startLockoutTimerIfNeeded() {
    if (_isLockedOut && _lastFailedAttempt != null) {
      final remaining =
          _lockoutDurationMinutes -
          DateTime.now().difference(_lastFailedAttempt!).inMinutes;
      if (remaining > 0) {
        _lockoutTimer = Timer.periodic(const Duration(minutes: 1), (timer) {
          _updateLockoutState();
          if (!_isLockedOut) {
            timer.cancel();
            if (mounted) setState(() {});
          }
        });
      }
    }
  }

  Future<void> _recordFailedAttempt() async {
    try {
      _failedAttempts++;
      _lastFailedAttempt = DateTime.now();

      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_kFailedAttempts, _failedAttempts);
      await prefs.setInt(
        _kLastFailedAttempt,
        _lastFailedAttempt!.millisecondsSinceEpoch,
      );

      _updateLockoutState();
      _startLockoutTimerIfNeeded();
    } catch (e) {
      debugPrint('Record failed attempt error: $e');
    }
  }

  Future<void> _resetFailedAttempts() async {
    try {
      _failedAttempts = 0;
      _lastFailedAttempt = null;
      _isLockedOut = false;

      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_kFailedAttempts);
      await prefs.remove(_kLastFailedAttempt);

      _lockoutTimer?.cancel();
    } catch (e) {
      debugPrint('Reset failed attempts error: $e');
    }
  }

  String _getRemainingLockoutTime() {
    if (_lastFailedAttempt == null) return '';
    final remaining =
        _lockoutDurationMinutes -
        DateTime.now().difference(_lastFailedAttempt!).inMinutes;
    return remaining > 0 ? '${remaining}m' : '';
  }

  // ---------------- Device binding ----------------
  Future<String> _ensureDeviceId() async {
    try {
      final existing = await _secure.read(
        key: _kDeviceId,
        aOptions: _aOptions(),
        iOptions: _iOptions(),
      );
      if (existing != null && existing.isNotEmpty) return existing;

      final rand = Random.secure();
      final bytes = List<int>.generate(16, (_) => rand.nextInt(256));
      final id = base64Url.encode(bytes);

      await _secure.write(
        key: _kDeviceId,
        value: id,
        aOptions: _aOptions(),
        iOptions: _iOptions(),
      );
      return id;
    } catch (e) {
      debugPrint('Device ID error: $e');
      return 'device-default';
    }
  }

  // ---------------- Input helpers ----------------
  bool _isValidInput(String input, {bool isEmail = false}) {
    if (isEmail) {
      return input.length <= _maxEmailLength &&
          !input.contains('<script>') &&
          !input.contains('javascript:') &&
          !input.contains('data:');
    } else {
      return input.length <= _maxPasswordLength &&
          !input.contains('<script>') &&
          !input.contains('javascript:');
    }
  }

  void _setupFormBehavior() {
    _emailController.addListener(() {
      final text = _emailController.text;
      final trimmed = text.trimRight();
      if (text != trimmed && text.length > trimmed.length) {
        _emailController.value = _emailController.value.copyWith(
          text: trimmed,
          selection: TextSelection.collapsed(offset: trimmed.length),
          composing: TextRange.empty,
        );
      }
    });
  }

  Future<void> _checkBiometricAvailability() async {
    try {
      final isSupported = await _localAuth.isDeviceSupported();
      final canCheck = await _localAuth.canCheckBiometrics;
      final available = await _localAuth.getAvailableBiometrics();
      final prefs = await SharedPreferences.getInstance();
      final userEnabled = prefs.getBool(_kBiometricEnabled) ?? false;

      setState(() {
        _biometricEnabled =
            isSupported && canCheck && available.isNotEmpty && userEnabled;
      });
    } catch (e) {
      debugPrint('Biometric availability error: $e');
      setState(() => _biometricEnabled = false);
    }
  }

  Future<void> _loadSavedPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedEmail = prefs.getString(_kSavedEmail);
      final rememberMe = prefs.getBool(_kRememberMe) ?? false;

      if (savedEmail != null &&
          rememberMe &&
          _isValidInput(savedEmail, isEmail: true)) {
        _emailController.text = savedEmail;
      }
      setState(() => _rememberMe = rememberMe);
    } catch (e) {
      debugPrint('Load prefs error: $e');
    }
  }

  Future<void> _saveCredentialsIfNeeded() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      if (_rememberMe) {
        final email = _emailController.text.trim().toLowerCase();
        final password = _passwordController.text;

        if (!_isValidInput(email, isEmail: true) || !_isValidInput(password)) {
          debugPrint('Invalid input detected, not saving credentials');
          return;
        }

        await prefs.setString(_kSavedEmail, email);
        await prefs.setBool(_kRememberMe, true);

        final deviceId = await _ensureDeviceId();

        await _secure.write(
          key: _kSecEmail,
          value: email,
          aOptions: _aOptions(),
          iOptions: _iOptions(),
        );
        await _secure.write(
          key: _kSecPassword,
          value: password,
          aOptions: _aOptions(),
          iOptions: _iOptions(),
        );
        await _secure.write(
          key: _kDeviceId,
          value: deviceId,
          aOptions: _aOptions(),
          iOptions: _iOptions(),
        );

        final user = FirebaseAuth.instance.currentUser;
        if (user != null &&
            await _localAuth.isDeviceSupported() &&
            await _localAuth.canCheckBiometrics) {
          final available = await _localAuth.getAvailableBiometrics();
          if (available.isNotEmpty) {
            await prefs.setBool(_kBiometricEnabled, true);
            setState(() => _biometricEnabled = true);
          }
        }
      } else {
        await _clearSavedCredentials();
      }
    } catch (e) {
      debugPrint('Save creds error: $e');
    }
  }

  Future<void> _clearSavedCredentials() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_kSavedEmail);
      await prefs.setBool(_kRememberMe, false);
      await prefs.setBool(_kBiometricEnabled, false);
      setState(() => _biometricEnabled = false);

      await _secure.delete(
        key: _kSecEmail,
        aOptions: _aOptions(),
        iOptions: _iOptions(),
      );
      await _secure.delete(
        key: _kSecPassword,
        aOptions: _aOptions(),
        iOptions: _iOptions(),
      );
    } catch (e) {
      debugPrint('Clear creds error: $e');
    }
  }

  // ---------------- Approval normalization ----------------
  String _normalizeApproval(Map<String, dynamic> d) {
    final raw = d['approvalStatus'];
    if (raw is String) return raw.toLowerCase().trim();
    if (raw is bool) return raw ? 'approved' : 'pending';

    final alt1 = d['status'];
    if (alt1 is String) return alt1.toLowerCase().trim();

    final alt2 = d['approved'];
    if (alt2 is bool) return alt2 ? 'approved' : 'pending';

    // Legacy: treat isActive: true as approved when no explicit status exists
    final active = d['isActive'];
    if (active is bool && active) return 'approved';

    return 'pending';
  }

  // ---------------- Driver doc resolution ----------------
  Future<DocumentReference<Map<String, dynamic>>> _resolveDriverRef({
    required User user,
    required FirebaseFirestore fs,
    required String emailLc,
  }) async {
    // 1) Prefer /drivers/{uid}
    DocumentReference<Map<String, dynamic>> driverRef = fs
        .collection('drivers')
        .doc(user.uid);
    DocumentSnapshot<Map<String, dynamic>> snap = await driverRef.get();
    if (snap.exists) return driverRef;

    // 2) Try by normalized email
    if (emailLc.isNotEmpty) {
      final byEmail = await fs
          .collection('drivers')
          .where('email', isEqualTo: emailLc)
          .limit(1)
          .get();
      if (byEmail.docs.isNotEmpty) return byEmail.docs.first.reference;
    }

    // 3) Try by original email (legacy casing)
    final origEmail = user.email ?? '';
    if (origEmail.isNotEmpty && origEmail != emailLc) {
      final byEmailOrig = await fs
          .collection('drivers')
          .where('email', isEqualTo: origEmail)
          .limit(1)
          .get();
      if (byEmailOrig.docs.isNotEmpty) return byEmailOrig.docs.first.reference;
    }

    // 4) If user has linked phone, try by phone
    final phone = user.phoneNumber ?? '';
    if (phone.isNotEmpty) {
      final byPhone = await fs
          .collection('drivers')
          .where('phone', isEqualTo: phone)
          .limit(1)
          .get();
      if (byPhone.docs.isNotEmpty) return byPhone.docs.first.reference;
    }

    // 5) Look up email->phone link, then find by phone
    if (emailLc.isNotEmpty) {
      final link = await fs.collection('email_phone_links').doc(emailLc).get();
      final linkedPhone = (link.data()?['phone'] as String?) ?? '';
      if (linkedPhone.isNotEmpty) {
        final byLinkedPhone = await fs
            .collection('drivers')
            .where('phone', isEqualTo: linkedPhone)
            .limit(1)
            .get();
        if (byLinkedPhone.docs.isNotEmpty) {
          return byLinkedPhone.docs.first.reference;
        }
      }
    }

    // Nothing found -> create at /drivers/{uid}
    return driverRef;
  }

  /// Syncs phone-related indices if the user already has a phone provider linked.
  /// If not, it backfills driver.phone from email_phone_links (if present).
  Future<void> _syncPhoneLinks({
    required FirebaseFirestore fs,
    required User user,
    required String emailLc,
    required DocumentReference<Map<String, dynamic>> driverRef,
    required Map<String, dynamic> currentData,
  }) async {
    final phoneFromAuth = user.phoneNumber ?? '';
    final now = FieldValue.serverTimestamp();

    if (phoneFromAuth.isNotEmpty) {
      final batch = fs.batch();
      // phone_index/{+E164}
      final phoneRef = fs.collection('phone_index').doc(phoneFromAuth);
      batch.set(phoneRef, {
        'userId': user.uid,
        'email': emailLc,
        'verifiedAt': now,
        'updatedAt': now,
      }, SetOptions(merge: true));

      // email_phone_links/{emailLc}
      final linkRef = fs.collection('email_phone_links').doc(emailLc);
      batch.set(linkRef, {
        'email': emailLc,
        'phone': phoneFromAuth,
        'uid': user.uid,
        'linkedAt': now,
      }, SetOptions(merge: true));

      // driver doc phone flags
      batch.set(driverRef, {
        'phone': phoneFromAuth,
        'linkedPhone': phoneFromAuth,
        'phoneVerified': true,
        'phoneVerifiedAt': now,
        'updatedAt': now,
      }, SetOptions(merge: true));

      await batch.commit();
      return;
    }

    // No phone provider linked: best-effort backfill from existing email_phone_links
    if (emailLc.isNotEmpty) {
      final link = await fs.collection('email_phone_links').doc(emailLc).get();
      final linkedPhone = (link.data()?['phone'] as String?)?.trim() ?? '';
      final existingPhone = (currentData['phone'] as String?)?.trim() ?? '';
      if (linkedPhone.isNotEmpty &&
          (existingPhone.isEmpty || existingPhone == '—')) {
        await driverRef.set({
          'phone': linkedPhone,
          'linkedPhone': linkedPhone,
          'updatedAt': now,
        }, SetOptions(merge: true));
      }
    }
  }

  /// If there is an older approved driver doc (by email/phone),
  /// adopt its approval into the canonical /drivers/{uid} doc.
  Future<void> _adoptApprovalFromDuplicates({
    required FirebaseFirestore fs,
    required User user,
    required DocumentReference<Map<String, dynamic>> canonicalRef,
    required String emailLc,
  }) async {
    final now = FieldValue.serverTimestamp();
    final List<DocumentSnapshot<Map<String, dynamic>>> candidates = [];

    // By email
    if (emailLc.isNotEmpty) {
      final byEmail = await fs
          .collection('drivers')
          .where('email', isEqualTo: emailLc)
          .get();
      candidates.addAll(byEmail.docs);
    }

    // By phone
    final phone = user.phoneNumber ?? '';
    if (phone.isNotEmpty) {
      final byPhone = await fs
          .collection('drivers')
          .where('phone', isEqualTo: phone)
          .get();
      candidates.addAll(byPhone.docs);
    }

    DocumentSnapshot<Map<String, dynamic>>? approvedDoc;
    for (final ds in candidates) {
      if (ds.id == user.uid) continue;
      final data = ds.data() ?? {};
      if (_normalizeApproval(data) == 'approved') {
        approvedDoc = ds;
        break;
      }
    }

    if (approvedDoc != null) {
      await canonicalRef.set({
        'approvalStatus': 'approved',
        'isActive': true,
        'updatedAt': now,
        'mergedFrom': approvedDoc.id,
        'legacyRef': approvedDoc.reference.path,
      }, SetOptions(merge: true));

      // Optional: mark legacy as merged (non-destructive)
      await approvedDoc.reference.set({
        'mergedInto': canonicalRef.path,
        'mergedAt': now,
      }, SetOptions(merge: true));
    }
  }

  // ---------------- Auth flows ----------------
  Future<void> _forgotPassword() async {
    final email = _emailController.text.trim();
    if (!_emailRegex.hasMatch(email) || !_isValidInput(email, isEmail: true)) {
      _showErrorSnackBar('Enter a valid email to reset password.');
      return;
    }

    try {
      setState(() => _isLoading = true);
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
      _showSuccessSnackBar('Password reset email sent to $email');
    } on FirebaseAuthException catch (e) {
      var message = 'Could not send reset email. Try again later.';
      switch (e.code) {
        case 'user-not-found':
          message = 'No account found with this email address.';
          break;
        case 'too-many-requests':
          message = 'Too many requests. Please wait before trying again.';
          break;
        case 'invalid-email':
          message = 'Invalid email address format.';
          break;
      }
      _showErrorSnackBar(message);
    } catch (e) {
      _showErrorSnackBar('An unexpected error occurred. Please try again.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _login({
    bool bypassValidation = false,
    bool isBiometric = false,
  }) async {
    if (_isLockedOut && !isBiometric) {
      _showErrorSnackBar(
        'Too many failed attempts. Try again in ${_getRemainingLockoutTime()}.',
      );
      return;
    }

    FocusScope.of(context).unfocus();
    if (!bypassValidation && !_formKey.currentState!.validate()) return;

    final rawEmail = _emailController.text.trim();
    final emailLc = rawEmail.toLowerCase();
    final password = _passwordController.text;

    if (!_isValidInput(emailLc, isEmail: true) || !_isValidInput(password)) {
      _showErrorSnackBar(
        'Invalid input detected. Please check your credentials.',
      );
      return;
    }

    setState(() => _isLoading = true);

    // Ensure Firebase is initialized
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
    }

    final auth = FirebaseAuth.instance;
    final fs = FirebaseFirestore.instance;

    try {
      // 1) Sign in
      await auth.signInWithEmailAndPassword(email: emailLc, password: password);
      await auth.currentUser?.reload();
      final user = auth.currentUser;
      if (user == null) {
        throw FirebaseAuthException(code: 'internal-error');
      }

      // Reset failed attempts on successful login
      await _resetFailedAttempts();

      // Save credentials if remember me is checked (securely)
      await _saveCredentialsIfNeeded();

      // 2) Email verification gate
      if (!user.emailVerified) {
        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const VerifyEmailScreen()),
        );
        return;
      }

      // 3) Resolve driver doc (uid -> emailLc -> emailOrig -> phone -> email_phone_links)
      DocumentReference<Map<String, dynamic>> driverRef =
          await _resolveDriverRef(user: user, fs: fs, emailLc: emailLc);
      DocumentSnapshot<Map<String, dynamic>> snap = await driverRef.get();

      final fallbackName = (user.displayName?.trim().isNotEmpty == true)
          ? user.displayName!.trim()
          : emailLc.split('@').first;

      // 4) Create doc if not found (default pending)
      if (!snap.exists) {
        await driverRef.set({
          'userId': user.uid,
          'fullName': fallbackName,
          'email': user.email?.toLowerCase() ?? emailLc,
          'phone': user.phoneNumber ?? '—',
          'licenseNumber': null,
          'vehicleType': null,
          'role': 'driver',
          'isActive': false,
          'approvalStatus': 'pending',
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
          'source': 'driver-app/login-self-heal',
          'lastLogin': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
        snap = await driverRef.get();
      }

      Map<String, dynamic> d = snap.data() ?? {};

      // 5) Normalize role/approval
      String role = ((d['role'] as String?) ?? 'driver').toLowerCase().trim();
      String approval = _normalizeApproval(d);

      // 6) Patch essentials (don't touch approval)
      await driverRef.set({
        'userId': d['userId'] ?? user.uid,
        'fullName': d['fullName'] ?? fallbackName,
        'email':
            (d['email'] as String?)?.toLowerCase() ??
            (user.email?.toLowerCase() ?? emailLc),
        'role': role,
        'updatedAt': FieldValue.serverTimestamp(),
        'lastLogin': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      // 7) Sync phone indices/links (safe: only writes link docs if phone provider is linked)
      await _syncPhoneLinks(
        fs: fs,
        user: user,
        emailLc: emailLc,
        driverRef: driverRef,
        currentData: d,
      );

      // 8) Adopt approval from any duplicate approved docs into /drivers/{uid}
      await _adoptApprovalFromDuplicates(
        fs: fs,
        user: user,
        canonicalRef: driverRef,
        emailLc: emailLc,
      );

      // Re-read after sync/adoption in case status changed
      d = (await driverRef.get()).data() ?? {};
      role = ((d['role'] as String?) ?? 'driver').toLowerCase().trim();
      approval = _normalizeApproval(d);

      // Guard: ensure this is a driver account
      if (role != 'driver') {
        await auth.signOut();
        await _clearSavedCredentials();
        _showErrorSnackBar(
          'This account is not registered as a driver. Please contact support.',
        );
        return;
      }

      if (!mounted) return;

      _showSuccessSnackBar('Welcome back!');

      // Route based on approval
      if (approval == 'approved') {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const HomeScreen()),
        );
      } else {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const PendingApprovalScreen()),
        );
      }
    } on FirebaseAuthException catch (e) {
      if (!isBiometric) {
        await _recordFailedAttempt();
      }

      var message = 'Login failed. Please try again.';
      switch (e.code) {
        case 'user-not-found':
          message = 'No driver found with this email.';
          break;
        case 'wrong-password':
          message = 'Incorrect password.';
          break;
        case 'invalid-email':
          message = 'Invalid email address.';
          break;
        case 'user-disabled':
          message = 'This account has been disabled. Contact support.';
          break;
        case 'network-request-failed':
          message = 'Network error. Check your connection and try again.';
          break;
        case 'too-many-requests':
          message =
              'Too many requests from Firebase. Please wait and try again.';
          break;
        case 'permission-denied':
          message = 'Permission denied. Please contact support.';
          break;
        case 'invalid-credential':
          message =
              'Invalid login credentials. Please check your email and password.';
          break;
      }

      if (_failedAttempts >= _maxFailedAttempts - 2 && !isBiometric) {
        message +=
            ' Warning: Account will be temporarily locked after ${_maxFailedAttempts - _failedAttempts} more failed attempts.';
      }

      _showErrorSnackBar(message);
    } catch (e) {
      if (!isBiometric) {
        await _recordFailedAttempt();
      }
      _showErrorSnackBar('Something went wrong. Please try again.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ---------------- Biometrics ----------------
  Future<void> _authenticateWithBiometric() async {
    if (_isLockedOut) {
      _showErrorSnackBar(
        'Account temporarily locked. Try again in ${_getRemainingLockoutTime()}.',
      );
      return;
    }

    try {
      setState(() => _isLoading = true);

      // Verify device binding
      final storedDeviceId = await _secure.read(
        key: _kDeviceId,
        aOptions: _aOptions(),
        iOptions: _iOptions(),
      );
      final currentDeviceId = await _ensureDeviceId();

      if (storedDeviceId != null && storedDeviceId != currentDeviceId) {
        await _clearSavedCredentials();
        throw Exception('Device mismatch detected');
      }

      final didAuth = await _localAuth.authenticate(
        localizedReason: 'Authenticate to sign in to your driver account',
        options: const AuthenticationOptions(
          biometricOnly: true,
          stickyAuth: true,
        ),
      );

      if (!didAuth) return;

      final savedEmail = await _secure.read(
        key: _kSecEmail,
        aOptions: _aOptions(),
        iOptions: _iOptions(),
      );
      final savedPassword = await _secure.read(
        key: _kSecPassword,
        aOptions: _aOptions(),
        iOptions: _iOptions(),
      );

      if (savedEmail != null &&
          savedPassword != null &&
          _isValidInput(savedEmail, isEmail: true) &&
          _isValidInput(savedPassword)) {
        _emailController.text = savedEmail;
        _passwordController.text = savedPassword;
        await _login(bypassValidation: true, isBiometric: true);
      } else {
        await _clearSavedCredentials();
        _showErrorSnackBar(
          'No valid saved credentials. Sign in manually and enable "Remember me".',
        );
      }
    } catch (e) {
      await _recordFailedAttempt();
      _showErrorSnackBar('Biometric authentication failed. Please try again.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ---------------- Validation ----------------
  String? _validateEmail(String? value) {
    if (value == null || value.trim().isEmpty) return 'Email is required';
    final email = value.trim();
    if (email.length > _maxEmailLength) return 'Email is too long';
    if (!_emailRegex.hasMatch(email)) return 'Enter a valid email address';
    if (!_isValidInput(email, isEmail: true)) {
      return 'Invalid characters in email';
    }
    final lower = email.toLowerCase();
    if (lower.contains('script') || lower.contains('javascript')) {
      return 'Invalid email format';
    }
    return null;
  }

  String? _validatePassword(String? value) {
    if (value == null || value.isEmpty) return 'Password is required';
    if (value.length < _minPasswordLength) {
      return 'Password must be at least $_minPasswordLength characters';
    }
    if (value.length > _maxPasswordLength) return 'Password is too long';
    if (!_isValidInput(value)) return 'Invalid characters in password';

    const weak = [
      'password',
      '123456',
      'password123',
      'admin',
      'qwerty',
      '12345678',
    ];
    if (weak.contains(value.toLowerCase())) {
      return 'Please use a stronger password';
    }
    if (RegExp(r'(.)\1{4,}').hasMatch(value)) {
      return 'Password cannot have repeated characters';
    }
    return null;
  }

  // ---------------- Snackbars ----------------
  void _showErrorSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        duration: const Duration(seconds: 4),
      ),
    );
  }

  void _showSuccessSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle_outline, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  // ---------------- Build ----------------
  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) {
        if (!didPop) {
          Navigator.pushReplacementNamed(context, '/auth');
        }
      },
      child: Scaffold(
        body: Stack(
          children: [
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xFFFFF8E1), Colors.white],
                ),
              ),
              child: SafeArea(
                child: RawKeyboardListener(
                  focusNode: _keyboardFocusNode,
                  onKey: (RawKeyEvent event) {
                    if (event is RawKeyDownEvent &&
                        event.logicalKey == LogicalKeyboardKey.enter &&
                        !_isLoading &&
                        !_isLockedOut) {
                      _login();
                    }
                  },
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        children: [
                          const SizedBox(height: 20),
                          const AppLogo(size: 100),
                          const SizedBox(height: 40),

                          Card(
                            elevation: 4,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(24),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Welcome Back!',
                                    style: TextStyle(
                                      fontSize: 24,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFFE65100),
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  const Text(
                                    'Sign in to continue delivering',
                                    style: TextStyle(
                                      fontSize: 16,
                                      color: Colors.grey,
                                    ),
                                  ),
                                  const SizedBox(height: 24),

                                  // Lockout warning
                                  if (_isLockedOut) _buildLockoutWarning(),

                                  // Email
                                  TextFormField(
                                    key: const Key('email_field'),
                                    controller: _emailController,
                                    focusNode: _emailFocusNode,
                                    keyboardType: TextInputType.emailAddress,
                                    textInputAction: TextInputAction.next,
                                    autofillHints: const [AutofillHints.email],
                                    enabled: !_isLoading && !_isLockedOut,
                                    autocorrect: false,
                                    enableSuggestions: false,
                                    onFieldSubmitted: (_) =>
                                        _passwordFocusNode.requestFocus(),
                                    decoration: InputDecoration(
                                      labelText: 'Email Address',
                                      hintText: 'Enter your email',
                                      helperText:
                                          'We\'ll use this to send you important updates',
                                      prefixIcon: const Icon(
                                        Icons.email_outlined,
                                        color: Color(0xFFE65100),
                                      ),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      focusedBorder: const OutlineInputBorder(
                                        borderSide: BorderSide(
                                          color: Color(0xFFE65100),
                                          width: 2,
                                        ),
                                      ),
                                      errorBorder: const OutlineInputBorder(
                                        borderSide: BorderSide(
                                          color: Colors.red,
                                        ),
                                      ),
                                      disabledBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        borderSide: BorderSide(
                                          color: Colors.grey.shade300,
                                        ),
                                      ),
                                    ),
                                    validator: _validateEmail,
                                  ),
                                  const SizedBox(height: 16),

                                  // Password
                                  TextFormField(
                                    key: const Key('password_field'),
                                    controller: _passwordController,
                                    focusNode: _passwordFocusNode,
                                    obscureText: _obscurePassword,
                                    textInputAction: TextInputAction.done,
                                    autofillHints: const [
                                      AutofillHints.password,
                                    ],
                                    enabled: !_isLoading && !_isLockedOut,
                                    autocorrect: false,
                                    enableSuggestions: false,
                                    onFieldSubmitted: (_) {
                                      if (!_isLoading && !_isLockedOut) {
                                        _login();
                                      }
                                    },
                                    decoration: InputDecoration(
                                      labelText: 'Password',
                                      hintText: 'Enter your password',
                                      prefixIcon: const Icon(
                                        Icons.lock_outlined,
                                        color: Color(0xFFE65100),
                                      ),
                                      suffixIcon: IconButton(
                                        icon: Icon(
                                          _obscurePassword
                                              ? Icons.visibility
                                              : Icons.visibility_off,
                                          color: const Color(0xFFE65100),
                                        ),
                                        onPressed: _isLoading || _isLockedOut
                                            ? null
                                            : () => setState(
                                                () => _obscurePassword =
                                                    !_obscurePassword,
                                              ),
                                        tooltip: _obscurePassword
                                            ? 'Show password'
                                            : 'Hide password',
                                      ),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      focusedBorder: const OutlineInputBorder(
                                        borderSide: BorderSide(
                                          color: Color(0xFFE65100),
                                          width: 2,
                                        ),
                                      ),
                                      errorBorder: const OutlineInputBorder(
                                        borderSide: BorderSide(
                                          color: Colors.red,
                                        ),
                                      ),
                                      disabledBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        borderSide: BorderSide(
                                          color: Colors.grey.shade300,
                                        ),
                                      ),
                                    ),
                                    validator: _validatePassword,
                                  ),

                                  const SizedBox(height: 16),

                                  // Failed attempts warning
                                  if (_failedAttempts > 0 &&
                                      _failedAttempts < _maxFailedAttempts &&
                                      !_isLockedOut) ...[
                                    Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: Colors.orange.shade50,
                                        border: Border.all(
                                          color: Colors.orange.shade200,
                                        ),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Row(
                                        children: [
                                          Icon(
                                            Icons.warning_amber,
                                            color: Colors.orange.shade700,
                                            size: 16,
                                          ),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Text(
                                              'Failed attempts: $_failedAttempts/$_maxFailedAttempts. '
                                              'Account will be locked after $_maxFailedAttempts failed attempts.',
                                              style: TextStyle(
                                                color: Colors.orange.shade700,
                                                fontSize: 12,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(height: 16),
                                  ],

                                  // Remember + Forgot
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Flexible(
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Checkbox(
                                              value: _rememberMe,
                                              onChanged:
                                                  _isLoading || _isLockedOut
                                                  ? null
                                                  : (value) => setState(
                                                      () => _rememberMe =
                                                          value ?? false,
                                                    ),
                                              activeColor: const Color(
                                                0xFFE65100,
                                              ),
                                            ),
                                            const Flexible(
                                              child: Text(
                                                'Remember me',
                                                style: TextStyle(fontSize: 14),
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Flexible(
                                        child: TextButton(
                                          onPressed: _isLoading
                                              ? null
                                              : _forgotPassword,
                                          child: const Text(
                                            'Forgot password?',
                                            style: TextStyle(
                                              color: Color(0xFFE65100),
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),

                                  const SizedBox(height: 8),

                                  // Sign In Button
                                  SizedBox(
                                    width: double.infinity,
                                    child: ElevatedButton(
                                      key: const Key('login_button'),
                                      onPressed: _isLoading || _isLockedOut
                                          ? null
                                          : _login,
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: const Color(
                                          0xFFE65100,
                                        ),
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 16,
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                        ),
                                        elevation: 2,
                                        disabledBackgroundColor:
                                            Colors.grey.shade300,
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
                                          : Text(
                                              _isLockedOut
                                                  ? 'Account Locked'
                                                  : 'Sign In',
                                              style: const TextStyle(
                                                fontSize: 16,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                    ),
                                  ),

                                  // Biometric Sign In
                                  if (_biometricEnabled && !_isLockedOut) ...[
                                    const SizedBox(height: 12),
                                    SizedBox(
                                      width: double.infinity,
                                      child: OutlinedButton.icon(
                                        key: const Key('biometric_button'),
                                        icon: const Icon(
                                          Icons.fingerprint,
                                          color: Color(0xFFE65100),
                                        ),
                                        label: const Text(
                                          'Sign In with Biometrics',
                                          style: TextStyle(
                                            color: Color(0xFFE65100),
                                          ),
                                        ),
                                        style: OutlinedButton.styleFrom(
                                          padding: const EdgeInsets.symmetric(
                                            vertical: 16,
                                          ),
                                          side: const BorderSide(
                                            color: Color(0xFFE65100),
                                          ),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                          ),
                                          disabledForegroundColor: Colors.grey,
                                        ),
                                        onPressed: _isLoading
                                            ? null
                                            : _authenticateWithBiometric,
                                      ),
                                    ),
                                  ],

                                  const SizedBox(height: 16),

                                  // Divider
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Divider(color: Colors.grey[300]),
                                      ),
                                      Padding(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 16,
                                        ),
                                        child: Text(
                                          'OR',
                                          style: TextStyle(
                                            color: Colors.grey[600],
                                          ),
                                        ),
                                      ),
                                      Expanded(
                                        child: Divider(color: Colors.grey[300]),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 16),

                                  // Phone Login (assumes a named route exists)
                                  SizedBox(
                                    width: double.infinity,
                                    child: OutlinedButton.icon(
                                      key: const Key('phone_login_button'),
                                      icon: const Icon(
                                        Icons.phone_android,
                                        color: Color(0xFFE65100),
                                      ),
                                      label: const Text(
                                        'Login with Phone',
                                        style: TextStyle(
                                          color: Color(0xFFE65100),
                                        ),
                                      ),
                                      style: OutlinedButton.styleFrom(
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 16,
                                        ),
                                        side: const BorderSide(
                                          color: Color(0xFFE65100),
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                        ),
                                        disabledForegroundColor: Colors.grey,
                                      ),
                                      onPressed: _isLoading
                                          ? null
                                          : () => Navigator.pushNamed(
                                              context,
                                              '/phone-auth',
                                            ),
                                    ),
                                  ),

                                  // Security info
                                  const SizedBox(height: 16),
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.security,
                                        color: Colors.grey.shade600,
                                        size: 16,
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          'Your login is secured with encryption and device verification.',
                                          style: TextStyle(
                                            color: Colors.grey.shade600,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),

                          const SizedBox(height: 24),

                          // Sign Up Option
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Text(
                                "Don't have an account? ",
                                style: TextStyle(color: Colors.grey),
                              ),
                              TextButton(
                                onPressed: _isLoading
                                    ? null
                                    : () => Navigator.pushNamed(
                                        context,
                                        '/signup',
                                      ),
                                child: const Text(
                                  'Sign Up',
                                  style: TextStyle(
                                    color: Color(0xFFE65100),
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),

                          // Debug info (remove in production)
                          if (_failedAttempts > 0) ...[
                            const SizedBox(height: 16),
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.grey.shade100,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                'Debug: Failed attempts: $_failedAttempts, Locked: $_isLockedOut',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),

            // Loading Overlay
            if (_isLoading) Positioned.fill(child: _buildLoadingOverlay()),
          ],
        ),
      ),
    );
  }

  // --- UI helpers ---
  Widget _buildLockoutWarning() {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        border: Border.all(color: Colors.red.shade200),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(Icons.lock_clock, color: Colors.red.shade700, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Account temporarily locked due to failed login attempts. Try again in ${_getRemainingLockoutTime()}.',
              style: TextStyle(color: Colors.red.shade700, fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingOverlay() {
    return Container(
      color: Colors.black.withOpacity(0.3),
      child: const Center(
        child: Card(
          child: Padding(
            padding: EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(color: Color(0xFFE65100)),
                SizedBox(height: 16),
                Text('Signing you in...', style: TextStyle(fontSize: 16)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
