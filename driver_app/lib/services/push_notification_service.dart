import 'dart:convert';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class PushNotificationService {
  static final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  static final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  // Initialize push notifications
  static Future<void> initialize() async {
    try {
      // Request permission
      NotificationSettings settings = await _messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );

      if (settings.authorizationStatus == AuthorizationStatus.authorized) {
        print('User granted permission');
        
        // Initialize local notifications
        await _initializeLocalNotifications();
        
        // Get FCM token and save to Firestore
        await _saveFCMToken();
        
        // Listen for token refresh
        _messaging.onTokenRefresh.listen(_saveFCMToken);
        
        // Handle foreground messages
        FirebaseMessaging.onMessage.listen(_handleForegroundMessage);
        
        // Handle background message taps
        FirebaseMessaging.onMessageOpenedApp.listen(_handleMessageTap);
        
        // Handle app launch from notification
        _handleAppLaunchFromNotification();
      }
    } catch (e) {
      print('Push notification initialization failed: $e');
      // Continue without push notifications
    }
  }

  // Initialize local notifications
  static Future<void> _initializeLocalNotifications() async {
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    
    const settings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );
    
    await _localNotifications.initialize(
      settings,
      onDidReceiveNotificationResponse: _onNotificationTap,
    );
  }

  // Save FCM token to Firestore
  static Future<void> _saveFCMToken([String? token]) async {
    final user = _auth.currentUser;
    if (user == null) return;
    
    try {
      token ??= await _messaging.getToken();
      if (token == null) return;
      
      await _firestore.collection('drivers').doc(user.uid).update({
        'fcmToken': token,
        'lastTokenUpdate': FieldValue.serverTimestamp(),
      });
      print('FCM token saved: $token');
    } catch (e) {
      print('Error saving FCM token: $e');
    }
  }

  // Handle foreground messages
  static Future<void> _handleForegroundMessage(RemoteMessage message) async {
    print('Received foreground message: ${message.messageId}');
    
    // Show local notification
    await _showLocalNotification(message);
    
    // Save to local notifications collection
    await _saveNotificationToFirestore(message);
  }

  // Show local notification
  static Future<void> _showLocalNotification(RemoteMessage message) async {
    const androidDetails = AndroidNotificationDetails(
      'driver_orders',
      'Driver Orders',
      channelDescription: 'Notifications for driver order updates',
      importance: Importance.high,
      priority: Priority.high,
      showWhen: true,
      icon: '@mipmap/ic_launcher',
    );
    
    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );
    
    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );
    
    await _localNotifications.show(
      message.hashCode,
      message.notification?.title ?? 'New Order Update',
      message.notification?.body ?? 'You have a new order update',
      details,
      payload: jsonEncode(message.data),
    );
  }

  // Handle notification tap
  static void _onNotificationTap(NotificationResponse response) {
    if (response.payload != null) {
      final data = jsonDecode(response.payload!);
      _navigateToOrder(data);
    }
  }

  // Handle message tap (background)
  static void _handleMessageTap(RemoteMessage message) {
    _navigateToOrder(message.data);
  }

  // Handle app launch from notification
  static Future<void> _handleAppLaunchFromNotification() async {
    final initialMessage = await _messaging.getInitialMessage();
    if (initialMessage != null) {
      _navigateToOrder(initialMessage.data);
    }
  }

  // Navigate to order based on notification data
  static void _navigateToOrder(Map<String, dynamic> data) {
    final orderId = data['orderId'];
    if (orderId != null) {
      // Navigate to order details
      // This will be implemented based on your navigation structure
      print('Navigate to order: $orderId');
    }
  }

  // Save notification to Firestore
  static Future<void> _saveNotificationToFirestore(RemoteMessage message) async {
    final user = _auth.currentUser;
    if (user == null) return;
    
    try {
      await _firestore
          .collection('drivers')
          .doc(user.uid)
          .collection('notifications')
          .add({
        'title': message.notification?.title ?? 'New Order Update',
        'body': message.notification?.body ?? 'You have a new order update',
        'data': message.data,
        'read': false,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Error saving notification: $e');
    }
  }

  // Get unread notification count
  static Stream<int> getUnreadNotificationCount() {
    final user = _auth.currentUser;
    if (user == null) return Stream.value(0);
    
    return _firestore
        .collection('drivers')
        .doc(user.uid)
        .collection('notifications')
        .where('read', isEqualTo: false)
        .snapshots()
        .map((snapshot) => snapshot.docs.length)
        .handleError((error) {
      print('Error getting notification count: $error');
      return 0;
    });
  }

  // Mark notification as read
  static Future<void> markNotificationAsRead(String notificationId) async {
    final user = _auth.currentUser;
    if (user == null) return;
    
    try {
      await _firestore
          .collection('drivers')
          .doc(user.uid)
          .collection('notifications')
          .doc(notificationId)
          .update({'read': true});
    } catch (e) {
      print('Error marking notification as read: $e');
    }
  }

  // Clear all notifications
  static Future<void> clearAllNotifications() async {
    await _localNotifications.cancelAll();
  }

  // Subscribe to order updates for assigned orders
  static Future<void> subscribeToOrderUpdates(String orderId) async {
    await _messaging.subscribeToTopic('order_$orderId');
  }

  // Unsubscribe from order updates
  static Future<void> unsubscribeFromOrderUpdates(String orderId) async {
    await _messaging.unsubscribeFromTopic('order_$orderId');
  }
}

// Background message handler (must be top-level function)
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  print('Handling background message: ${message.messageId}');
  // Handle background message processing here
}