// ignore: unused_import
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';

class NotificationService {
  static final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  static final FlutterLocalNotificationsPlugin _localPlugin =
      FlutterLocalNotificationsPlugin();

  static Future<void> init(BuildContext context) async {
    // iOS Permissions
    await _messaging.requestPermission(alert: true, badge: true, sound: true);

    // Local notification init
    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );
    const initSettings = InitializationSettings(android: androidSettings);
    await _localPlugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) async {
        _handleTapNavigation(response.payload, context);
      },
    );

    // 🔔 Android Channel Registration
    await _localPlugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(
          const AndroidNotificationChannel(
            'order_channel',
            'Order Updates',
            importance: Importance.high,
            description: 'Notifications for orders, system alerts, and promos',
          ),
        );

    // 🔄 Background Handler Registration
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

    // 🟡 Foreground
    FirebaseMessaging.onMessage.listen((message) {
      _showLocalNotification(message);
      _saveToFirestore(message);
    });

    // 🚪 Opened from background or terminated
    FirebaseMessaging.onMessageOpenedApp.listen((message) {
      _handleTapNavigation(message.data['type'], context, message.data);
    });

    // 🔑 Save FCM Token to Firestore
    final token = await _messaging.getToken();
    final user = FirebaseAuth.instance.currentUser;
    if (token != null && user != null) {
      await FirebaseFirestore.instance.collection('users').doc(user.uid).update(
        {'fcmToken': token},
      );
    }
  }

  // 🔄 Show Local Notification
  static void _showLocalNotification(RemoteMessage message) {
    if (message.notification == null) return;

    _localPlugin.show(
      message.hashCode,
      message.notification!.title,
      message.notification!.body,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'order_channel',
          'Order Updates',
          importance: Importance.max,
          priority: Priority.high,
        ),
      ),
      payload: message.data['type'],
    );
  }

  // 🚀 Navigate on Notification Tap
  static void _handleTapNavigation(
    String? type,
    BuildContext context, [
    Map<String, dynamic>? data,
  ]) {
    if (type == 'order' && data != null && data['orderId'] != null) {
      Navigator.pushNamed(
        context,
        '/orderDetails',
        arguments: {'orderId': data['orderId']},
      );
    } else {
      Navigator.pushNamed(context, '/notifications');
    }
  }

  // 📝 Save Notification to Firestore
  static void _saveToFirestore(RemoteMessage message) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('notifications')
        .add({
          'title': message.notification?.title ?? '',
          'body': message.notification?.body ?? '',
          'timestamp': FieldValue.serverTimestamp(),
          'read': false,
          'type': message.data['type'] ?? '',
          'orderId': message.data['orderId'] ?? '',
        });
  }
}

// ✅ Background Handler (must be top-level)
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();

  final user = FirebaseAuth.instance.currentUser;
  final userId = user?.uid ?? 'unknown';

  await FirebaseFirestore.instance
      .collection('users')
      .doc(userId)
      .collection('notifications')
      .add({
        'title': message.notification?.title ?? '',
        'body': message.notification?.body ?? '',
        'timestamp': FieldValue.serverTimestamp(),
        'read': false,
        'type': message.data['type'] ?? '',
        'orderId': message.data['orderId'] ?? '',
      });
}
