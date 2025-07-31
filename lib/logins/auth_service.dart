import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Start phone number verification
  Future<void> verifyPhoneNumber({
    required String phoneNumber,
    required Function(PhoneAuthCredential) onVerificationCompleted,
    required Function(FirebaseAuthException) onVerificationFailed,
    required Function(String, int?) onCodeSent,
    required Function(String) onCodeAutoRetrievalTimeout,
    int? forceResendingToken,
  }) async {
    await _auth.verifyPhoneNumber(
      phoneNumber: phoneNumber,
      verificationCompleted: onVerificationCompleted,
      verificationFailed: onVerificationFailed,
      codeSent: onCodeSent,
      codeAutoRetrievalTimeout: onCodeAutoRetrievalTimeout,
      timeout: const Duration(seconds: 60),
      forceResendingToken: forceResendingToken,
    );
  }

  // Sign in using phone credentials
  Future<UserCredential> signInWithPhoneCredential(
    PhoneAuthCredential credential,
  ) async {
    return await _auth.signInWithCredential(credential);
  }

  // Save or update user phone info in Firestore
  Future<void> saveUserPhoneToFirestore(User user) async {
    final userDoc = FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid);
    await userDoc.set({
      'userId': user.uid,
      'phoneNumber': user.phoneNumber ?? '',
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  // Send OTP to update the current user's phone number
  Future<void> updatePhoneNumberFlow({
    required String newPhoneNumber,
    required Function(String verificationId, int? resendToken) onCodeSent,
    required Function(String message) onError,
    required Function(String verificationId) onAutoRetrievalTimeout,
  }) async {
    try {
      await _auth.verifyPhoneNumber(
        phoneNumber: newPhoneNumber,
        verificationCompleted: (PhoneAuthCredential credential) async {
          await _auth.currentUser?.updatePhoneNumber(credential);
          await saveUserPhoneToFirestore(_auth.currentUser!);
        },
        verificationFailed: (FirebaseAuthException e) {
          onError(e.message ?? 'Verification failed');
        },
        codeSent: onCodeSent,
        codeAutoRetrievalTimeout: onAutoRetrievalTimeout,
        timeout: const Duration(seconds: 60),
      );
    } catch (e) {
      onError(e.toString());
    }
  }

  // Finalize phone number update after OTP verification
  Future<void> applyPhoneUpdate(String verificationId, String smsCode) async {
    final credential = PhoneAuthProvider.credential(
      verificationId: verificationId,
      smsCode: smsCode,
    );
    await _auth.currentUser?.updatePhoneNumber(credential);
    await saveUserPhoneToFirestore(_auth.currentUser!);
  }

  // 🔗 Link phone number to an already signed-in user (e.g., email user)
  Future<void> linkPhoneToCurrentUser({
    required String verificationId,
    required String smsCode,
  }) async {
    final credential = PhoneAuthProvider.credential(
      verificationId: verificationId,
      smsCode: smsCode,
    );

    final currentUser = _auth.currentUser;
    if (currentUser == null) {
      throw FirebaseAuthException(
        code: 'no-current-user',
        message: 'No user is currently signed in',
      );
    }

    await currentUser.linkWithCredential(credential);
    await saveUserPhoneToFirestore(currentUser);
  }
}
