import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class DeliveryPhotoService {
  static final ImagePicker _picker = ImagePicker();
  static final FirebaseStorage _storage = FirebaseStorage.instance;
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Take delivery photo
  static Future<String?> takeDeliveryPhoto(String orderId) async {
    try {
      final XFile? photo = await _picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 70,
        maxWidth: 1024,
        maxHeight: 1024,
      );

      if (photo == null) return null;

      return await _uploadDeliveryPhoto(orderId, File(photo.path));
    } catch (e) {
      print('Error taking photo: $e');
      return null;
    }
  }

  // Upload photo to Firebase Storage
  static Future<String?> _uploadDeliveryPhoto(String orderId, File photoFile) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return null;

      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName = 'delivery_${orderId}_${timestamp}.jpg';
      final ref = _storage.ref().child('delivery_photos').child(fileName);

      await ref.putFile(photoFile);
      final downloadUrl = await ref.getDownloadURL();

      // Save photo info to Firestore
      await _firestore.collection('delivery_photos').add({
        'orderId': orderId,
        'driverId': user.uid,
        'photoUrl': downloadUrl,
        'fileName': fileName,
        'timestamp': FieldValue.serverTimestamp(),
        'uploadedAt': DateTime.now().toIso8601String(),
      });

      // Update order with photo
      await _firestore.collection('orders').doc(orderId).update({
        'deliveryPhoto': downloadUrl,
        'photoTakenAt': FieldValue.serverTimestamp(),
      });

      return downloadUrl;
    } catch (e) {
      print('Error uploading photo: $e');
      return null;
    }
  }

  // Get delivery photos for an order
  static Future<List<Map<String, dynamic>>> getDeliveryPhotos(String orderId) async {
    try {
      final snapshot = await _firestore
          .collection('delivery_photos')
          .where('orderId', isEqualTo: orderId)
          .orderBy('timestamp', descending: true)
          .get();

      return snapshot.docs.map((doc) => {
        'id': doc.id,
        ...doc.data(),
      }).toList();
    } catch (e) {
      print('Error getting photos: $e');
      return [];
    }
  }
}