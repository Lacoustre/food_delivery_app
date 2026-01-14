import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class PhoneSignInHelper {
  static Future<User?> signInWithPhone(String phoneNumber) async {
    // First check if phone exists in Firestore
    final phoneQuery = await FirebaseFirestore.instance
        .collection('users')
        .where('phone', isEqualTo: phoneNumber)
        .get();
    
    if (phoneQuery.docs.isEmpty) {
      throw Exception('Phone number not registered');
    }
    
    // Get the email associated with this phone
    final userData = phoneQuery.docs.first.data();
    final email = userData['email'] as String;
    
    // Return the email so user can sign in with email/password
    throw Exception('Please sign in with email: $email');
  }
}