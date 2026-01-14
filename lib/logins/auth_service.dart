import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Start phone number verification with iOS crash protection
  Future<void> verifyPhoneNumber({
    required String phoneNumber,
    required Function(PhoneAuthCredential) onVerificationCompleted,
    required Function(FirebaseAuthException) onVerificationFailed,
    required Function(String, int?) onCodeSent,
    required Function(String) onCodeAutoRetrievalTimeout,
    int? forceResendingToken,
  }) async {
    try {
      // Validate phone number format
      if (!phoneNumber.startsWith('+')) {
        onVerificationFailed(
          FirebaseAuthException(
            code: 'invalid-phone-number',
            message: 'Phone number must include country code (e.g., +1234567890)',
          ),
        );
        return;
      }

      await _auth.verifyPhoneNumber(
        phoneNumber: phoneNumber,
        verificationCompleted: (PhoneAuthCredential credential) {
          try {
            onVerificationCompleted(credential);
          } catch (e) {
            onVerificationFailed(
              FirebaseAuthException(
                code: 'verification-error',
                message: 'Verification completion failed: ${e.toString()}',
              ),
            );
          }
        },
        verificationFailed: onVerificationFailed,
        codeSent: (String verificationId, int? resendToken) {
          try {
            onCodeSent(verificationId, resendToken);
          } catch (e) {
            onVerificationFailed(
              FirebaseAuthException(
                code: 'code-sent-error',
                message: 'Code sending failed: ${e.toString()}',
              ),
            );
          }
        },
        codeAutoRetrievalTimeout: (String verificationId) {
          try {
            onCodeAutoRetrievalTimeout(verificationId);
          } catch (e) {
            // Silent fail for timeout
          }
        },
        timeout: const Duration(seconds: 60), // Reduced timeout for iOS
        forceResendingToken: forceResendingToken,
      );
    } on FirebaseAuthException catch (e) {
      onVerificationFailed(e);
    } catch (e) {
      onVerificationFailed(
        FirebaseAuthException(
          code: 'unknown',
          message: 'Phone verification failed: ${e.toString()}',
        ),
      );
    }
  }

  // Sign in using phone credentials
  Future<UserCredential> signInWithPhoneCredential(
    PhoneAuthCredential credential,
  ) async {
    return await _auth.signInWithCredential(credential);
  }

  // Save or update user phone info in Firestore with error handling
  Future<void> saveUserPhoneToFirestore(User user) async {
    try {
      final userDoc = FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid);
      await userDoc.set({
        'userId': user.uid,
        'phoneNumber': user.phoneNumber ?? '',
        'displayName': user.displayName ?? '',
        'email': user.email ?? '',
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'isPhoneVerified': true,
      }, SetOptions(merge: true)).timeout(const Duration(seconds: 10));
    } catch (e) {
      // Silently handle Firestore errors to not block authentication
      print('Failed to save user to Firestore: $e');
    }
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
