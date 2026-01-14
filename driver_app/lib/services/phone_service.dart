import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class PhoneService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Check if a phone number is already linked to another account
  static Future<bool> isPhoneNumberAvailable(String phoneNumber) async {
    try {
      final doc = await _firestore.collection('phone_index').doc(phoneNumber).get();
      return !doc.exists;
    } catch (e) {
      throw Exception('Failed to check phone availability: $e');
    }
  }

  /// Check if an email is already linked to a phone number
  static Future<bool> isEmailAvailableForPhoneLinking(String email) async {
    try {
      final doc = await _firestore.collection('email_phone_links').doc(email).get();
      return !doc.exists;
    } catch (e) {
      throw Exception('Failed to check email phone linking: $e');
    }
  }

  /// Link a phone number to a user account (driver only)
  static Future<void> linkPhoneToUser({
    required String userId,
    required String email,
    required String phoneNumber,
  }) async {
    try {
      final batch = _firestore.batch();

      // Create phone index entry
      final phoneRef = _firestore.collection('phone_index').doc(phoneNumber);
      batch.set(phoneRef, {
        'uid': userId,
        'email': email,
        'linkedAt': FieldValue.serverTimestamp(),
        'appType': 'driver', // Ensure this is only for driver app
      });

      // Create email-phone link
      final emailPhoneRef = _firestore.collection('email_phone_links').doc(email);
      batch.set(emailPhoneRef, {
        'email': email,
        'phone': phoneNumber,
        'uid': userId,
        'linkedAt': FieldValue.serverTimestamp(),
        'appType': 'driver',
      });

      await batch.commit();
    } catch (e) {
      throw Exception('Failed to link phone to user: $e');
    }
  }

  /// Get the phone number linked to a user
  static Future<String?> getLinkedPhoneNumber(String userId) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user?.email == null) return null;

      final doc = await _firestore.collection('email_phone_links').doc(user!.email!).get();
      if (doc.exists) {
        final data = doc.data();
        return data?['phone'] as String?;
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  /// Unlink a phone number from a user account
  static Future<void> unlinkPhoneFromUser(String userId, String email) async {
    try {
      final linkedPhone = await getLinkedPhoneNumber(userId);
      if (linkedPhone == null) return;

      final batch = _firestore.batch();

      // Remove phone index entry
      final phoneRef = _firestore.collection('phone_index').doc(linkedPhone);
      batch.delete(phoneRef);

      // Remove email-phone link
      final emailPhoneRef = _firestore.collection('email_phone_links').doc(email);
      batch.delete(emailPhoneRef);

      await batch.commit();
    } catch (e) {
      throw Exception('Failed to unlink phone from user: $e');
    }
  }

  /// Validate phone number format (E.164)
  static bool isValidPhoneNumber(String phoneNumber) {
    final e164Regex = RegExp(r'^\+[1-9]\d{6,14}$');
    return e164Regex.hasMatch(phoneNumber.trim());
  }

  /// Format phone number for display
  static String formatPhoneForDisplay(String phoneNumber) {
    if (phoneNumber.length >= 10) {
      // Simple US format: +1 (555) 123-4567
      if (phoneNumber.startsWith('+1') && phoneNumber.length == 12) {
        return '${phoneNumber.substring(0, 2)} (${phoneNumber.substring(2, 5)}) ${phoneNumber.substring(5, 8)}-${phoneNumber.substring(8)}';
      }
    }
    return phoneNumber; // Return as-is if not US format
  }
}