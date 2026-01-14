// lib/services/services.dart
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'driver_service.dart';

class AuthService {
  static final FirebaseAuth _auth = FirebaseAuth.instance;
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static User? get currentUser => _auth.currentUser;
  static Stream<User?> get authStateChanges => _auth.authStateChanges();

  // Email/password
  static Future<UserCredential> signInWithEmail(String email, String password) async {
    final credential = await _auth.signInWithEmailAndPassword(email: email, password: password);
    
    // Ensure driver document exists
    await _ensureDriverDocumentExists();
    
    // Save FCM token after successful login
    await DriverService.saveFCMToken();
    
    return credential;
  }
  
  static Future<void> _ensureDriverDocumentExists() async {
    final user = currentUser;
    if (user == null) return;
    
    try {
      final driverDoc = await _firestore.collection('drivers').doc(user.uid).get();
      if (!driverDoc.exists) {
        // Create basic driver document
        await _firestore.collection('drivers').doc(user.uid).set({
          'userId': user.uid,
          'email': user.email,
          'role': 'driver',
          'isActive': false,
          'approvalStatus': 'pending',
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }
    } catch (e) {
      print('Error ensuring driver document exists: $e');
    }
  }

  static Future<UserCredential> createAccount(String email, String password) {
    return _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
  }

  static Future<void> signOut() => _auth.signOut();

  // Phone authentication
  static Future<void> verifyPhoneNumber({
    required String phoneNumber,
    required Function(PhoneAuthCredential) verificationCompleted,
    required Function(FirebaseAuthException) verificationFailed,
    required Function(String, int?) codeSent,
    required Function(String) codeAutoRetrievalTimeout,
    int? forceResendingToken,
  }) {
    return _auth.verifyPhoneNumber(
      phoneNumber: phoneNumber,
      verificationCompleted: verificationCompleted,
      verificationFailed: verificationFailed,
      codeSent: codeSent,
      codeAutoRetrievalTimeout: codeAutoRetrievalTimeout,
      forceResendingToken: forceResendingToken,
    );
  }

  static Future<UserCredential> signInWithPhoneCredential(PhoneAuthCredential credential) async {
    final userCredential = await _auth.signInWithCredential(credential);
    
    // Ensure driver document exists
    await _ensureDriverDocumentExists();
    
    // Save FCM token after successful login
    await DriverService.saveFCMToken();
    
    return userCredential;
  }

  // Link phone to existing email account
  static Future<void> linkPhoneToCurrentUser(String phoneNumber) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('No authenticated user');
    
    // Create phone index document
    await _firestore.collection('phone_index').doc(phoneNumber).set({
      'userId': user.uid,
      'email': user.email,
      'createdAt': FieldValue.serverTimestamp(),
    });
    
    // Update driver profile with phone
    await _firestore.collection('drivers').doc(user.uid).update({
      'phone': phoneNumber,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// IMPORTANT: call this **after** phone linking + Firestore batch succeeds.
  static Future<void> sendEmailVerification() async {
    final user = _auth.currentUser;
    if (user == null) return;

    final settings = ActionCodeSettings(
      // Any HTTPS URL you control—user will be redirected here after verifying.
      url: 'https://your-site.example/verified', // TODO: replace with your URL
      handleCodeInApp:
          false, // uses Firebase's hosted page, no Dynamic Links needed
      // Your real identifiers:
      androidPackageName: 'com.khestra.african_cuisine',
      androidInstallApp: true,
      androidMinimumVersion: '21',
      iOSBundleId: 'com.khestra.africanCuisine',

      // If you later switch to in-app handling:
      // handleCodeInApp: true,
      // dynamicLinkDomain: 'your-domain.page.link', // set up in Firebase Console
    );

    await user.sendEmailVerification(settings);
  }

  static Future<bool> reloadAndIsEmailVerified() async {
    await _auth.currentUser?.reload();
    return _auth.currentUser?.emailVerified ?? false;
  }

  // Driver profile helper (merge-safe)
  static Future<void> createDriverProfile({
    required String fullName,
    required String phone,
    String? licenseNumber,
    String? vehicleType,
  }) async {
    final user = currentUser;
    if (user == null) {
      throw FirebaseAuthException(
        code: 'no-auth',
        message: 'No authenticated user',
      );
    }

    await _firestore.collection('drivers').doc(user.uid).set({
      'userId': user.uid,
      'fullName': fullName,
      'email': user.email,
      'phone': phone,
      'licenseNumber': licenseNumber,
      'vehicleType': vehicleType,
      'role': 'driver',
      'isActive': false,
      'approvalStatus': 'approved',
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
      'source': 'driver-app',
    }, SetOptions(merge: true));
  }
}
