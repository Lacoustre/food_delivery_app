import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:vibration/vibration.dart';
import 'package:flutter_ringtone_player/flutter_ringtone_player.dart';

class NotificationService {
  static final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  static final FlutterLocalNotificationsPlugin _local =
      FlutterLocalNotificationsPlugin();

  static BuildContext? _context;

  // ====== PUBLIC ======
  static Future<void> init(BuildContext context) async {
    _context = context;

    debugPrint('🔔 Initializing notification service');

    // Request permissions first
    await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
      criticalAlert: true,
    );

    // Request notification permission for Android 13+
    await _local.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();

    debugPrint('✅ Notification permissions requested');

    // Local notifications init
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosInit = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
      requestCriticalPermission: true,
    );
    const initSettings = InitializationSettings(
      android: androidInit,
      iOS: iosInit,
    );

    await _local.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (NotificationResponse resp) async {
        // Payload is JSON string with full data map
        if (_context == null) return;
        final payload = resp.payload;
        if (payload == null || payload.isEmpty) {
          Navigator.pushNamed(_context!, '/notifications');
          return;
        }
        try {
          final data = Map<String, dynamic>.from(jsonDecode(payload));
          _handleTapNavigationFromData(data, _context!);
        } catch (_) {
          Navigator.pushNamed(_context!, '/notifications');
        }
      },
    );

    // Android channels
    final android = _local
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();

    await android?.createNotificationChannel(
      AndroidNotificationChannel(
        'order_channel',
        'Order Updates',
        importance: Importance.max,
        description: 'Notifications for orders, system alerts, and promos',
        enableVibration: true,
        vibrationPattern: Int64List.fromList([0, 800]),
        enableLights: true,
        ledColor: const Color(0xFFFF5722),
      ),
    );

    await android?.createNotificationChannel(
      AndroidNotificationChannel(
        'critical_channel',
        'Critical Updates',
        importance: Importance.max,
        description: 'Critical order and system notifications',
        enableVibration: true,
        vibrationPattern: Int64List.fromList([0, 300, 100, 300, 100, 300]),
        enableLights: true,
        ledColor: const Color(0xFFFF0000),
        playSound: true,
      ),
    );

    // Background handler
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

    // Foreground messages
    FirebaseMessaging.onMessage.listen((message) async {
      debugPrint('📱 Foreground message received: ${message.notification?.title}');
      await _appendUserNotificationList(message);
      await _showLocal(message);
      await _playEffects(message);
      _showInAppAlert(message);
    });

    // App opened from background by tapping notification
    FirebaseMessaging.onMessageOpenedApp.listen((message) {
      if (_context == null) return;
      _handleTapNavigationFromData(message.data, _context!);
    });

    // App launched from terminated by tapping notification
    final initial = await _messaging.getInitialMessage();
    if (initial != null && _context != null) {
      _handleTapNavigationFromData(initial.data, _context!);
    }

    // Save FCM token to user doc
    final token = await _messaging.getToken();
    final user = FirebaseAuth.instance.currentUser;
    if (token != null && user != null) {
      try {
        await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
          'fcmToken': token,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
        debugPrint('✅ FCM token saved successfully');
      } catch (e) {
        debugPrint('❌ Failed to save FCM token: $e');
      }
    }
  }

  // ====== LOCAL NOTIFICATION ======
  static Future<void> _showLocal(RemoteMessage message) async {
    if (message.notification == null) return;

    debugPrint('🔔 Showing local notification: ${message.notification?.title}');

    final isCritical = _isCritical(message);
    final channelId = isCritical ? 'critical_channel' : 'order_channel';
    final channelName = isCritical ? 'Critical Updates' : 'Order Updates';

    // Encode full data as payload so tap handler can deep-link
    final payloadMap = {
      ...message.data,
      'title': message.notification?.title ?? '',
      'body': message.notification?.body ?? '',
    };
    final payload = jsonEncode(payloadMap);

    await _local.show(
      message.hashCode,
      message.notification!.title,
      message.notification!.body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          channelId,
          channelName,
          importance: Importance.max,
          priority: Priority.high,
          enableVibration: true,
          vibrationPattern: isCritical
              ? Int64List.fromList([0, 300, 100, 300, 100, 300])
              : Int64List.fromList([0, 800]),
          enableLights: true,
          ledColor: isCritical
              ? const Color(0xFFFF0000)
              : const Color(0xFFFF5722),
          autoCancel: true,
          fullScreenIntent: isCritical,
          category: AndroidNotificationCategory.message,
          visibility: NotificationVisibility.public,
          playSound: true,
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
          interruptionLevel: isCritical
              ? InterruptionLevel.critical
              : InterruptionLevel.active,
        ),
      ),
      payload: payload,
    );
    
    debugPrint('✅ Local notification shown');
  }

  // ====== TAP NAVIGATION ======
  static void _handleTapNavigationFromData(
    Map<String, dynamic> data,
    BuildContext context,
  ) {
    final type = data['type']?.toString().toLowerCase() ?? '';
    final orderId = data['orderId']?.toString();

    if (orderId != null && orderId.isNotEmpty) {
      // Deep-link to the single order detail page
      Navigator.pushNamed(
        context,
        '/orderDetail',
        arguments: {'orderId': orderId},
      );
      return;
    }

    if (type == 'chat') {
      Navigator.pushNamed(context, '/support');
    } else if (type == 'order') {
      Navigator.pushNamed(context, '/orderHistory');
    } else if (type == 'review') {
      Navigator.pushNamed(context, '/rateOrders');
    } else {
      Navigator.pushNamed(context, '/notifications');
    }
  }

  // ====== EFFECTS ======
  static Future<void> _playEffects(RemoteMessage message) async {
    debugPrint('🎵 Playing notification effects');
    
    final isCritical = _isCritical(message);
    
    // Standardized vibration patterns for consistency across devices
    try {
      if (isCritical) {
        // Critical: Triple vibration (urgent pattern)
        await Vibration.vibrate(pattern: [0, 300, 100, 300, 100, 300]);
      } else {
        // Normal: Single strong vibration (standard pattern)
        await Vibration.vibrate(duration: 800);
      }
      debugPrint('✅ Vibration triggered');
    } catch (e) {
      debugPrint('❌ Vibration failed: $e');
    }
  }

  static void _showInAppAlert(RemoteMessage message) {
    if (_context == null || message.notification == null) return;

    final isCritical = _isCritical(message);
    showDialog(
      context: _context!,
      barrierDismissible: !isCritical,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(
              _iconFor(message),
              color: isCritical ? Colors.red : Colors.orange,
              size: 24,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                message.notification!.title ?? 'Notification',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: isCritical ? Colors.red : Colors.orange,
                ),
              ),
            ),
          ],
        ),
        content: Text(message.notification!.body ?? ''),
        actions: [
          if (!isCritical)
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Dismiss'),
            ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              _handleTapNavigationFromData(message.data, _context!);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: isCritical ? Colors.red : Colors.orange,
              foregroundColor: Colors.white,
            ),
            child: const Text('View'),
          ),
        ],
      ),
    );
  }

  // ====== STORAGE (users/{uid}.notifications ARRAY) ======
  static Future<void> _appendUserNotificationList(RemoteMessage message) async {
    final user = FirebaseAuth.instance.currentUser;
    final uid = message.data['uid']?.toString() ?? user?.uid;
    if (uid == null || uid.isEmpty) return; // cannot save without uid

    final notif = {
      'id':
          message.messageId ?? DateTime.now().millisecondsSinceEpoch.toString(),
      'title': message.notification?.title ?? '',
      'body': message.notification?.body ?? '',
      'timestamp': DateTime.now().millisecondsSinceEpoch, // int ms (UI expects)
      'read': false,
      'type': (message.data['type'] ?? 'general').toString(),
      'orderId': message.data['orderId']?.toString(),
    };

    final userRef = FirebaseFirestore.instance.collection('users').doc(uid);

    await FirebaseFirestore.instance.runTransaction((tx) async {
      final snap = await tx.get(userRef);
      final List<dynamic> list =
          (snap.data()?['notifications'] as List<dynamic>?)?.toList() ?? [];
      // put newest at the top
      list.insert(0, notif);

      // Optional: cap list size
      const maxItems = 200;
      if (list.length > maxItems) {
        list.removeRange(maxItems, list.length);
      }

      tx.set(userRef, {'notifications': list}, SetOptions(merge: true));
    });
  }

  // ====== HELPERS ======
  static bool _isCritical(RemoteMessage message) {
    final t = message.data['type']?.toString().toLowerCase() ?? '';
    final title = message.notification?.title?.toLowerCase() ?? '';
    return t.contains('cancelled') ||
        t.contains('critical') ||
        title.contains('cancelled') ||
        title.contains('urgent') ||
        title.contains('important');
  }

  static IconData _iconFor(RemoteMessage m) {
    final t = m.data['type']?.toString().toLowerCase() ?? '';
    switch (t) {
      case 'order':
        return Icons.restaurant;
      case 'delivery':
        return Icons.delivery_dining;
      case 'payment':
        return Icons.payment;
      case 'chat':
        return Icons.chat;
      case 'promo':
        return Icons.local_offer;
      default:
        return Icons.notifications;
    }
  }
}

// ========= BACKGROUND HANDLER =========
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();

  final uid =
      message.data['uid']?.toString() ?? FirebaseAuth.instance.currentUser?.uid;

  if (uid != null && uid.isNotEmpty) {
    final userRef = FirebaseFirestore.instance.collection('users').doc(uid);
    final notif = {
      'id':
          message.messageId ?? DateTime.now().millisecondsSinceEpoch.toString(),
      'title': message.notification?.title ?? '',
      'body': message.notification?.body ?? '',
      'timestamp': DateTime.now().millisecondsSinceEpoch,
      'read': false,
      'type': (message.data['type'] ?? 'general').toString(),
      'orderId': message.data['orderId']?.toString(),
    };

    await FirebaseFirestore.instance.runTransaction((tx) async {
      final snap = await tx.get(userRef);
      final List<dynamic> list =
          (snap.data()?['notifications'] as List<dynamic>?)?.toList() ?? [];
      list.insert(0, notif);
      const maxItems = 200;
      if (list.length > maxItems) list.removeRange(maxItems, list.length);
      tx.set(userRef, {'notifications': list}, SetOptions(merge: true));
    });
  }

  // background vibration hint
  final t = message.data['type']?.toString().toLowerCase() ?? '';
  final isCritical = t.contains('cancelled') || t.contains('critical');
  try {
    if (await Vibration.hasVibrator() ?? false) {
      if (isCritical) {
        // Critical: Triple vibration pattern
        await Vibration.vibrate(pattern: [0, 300, 100, 300, 100, 300]);
      } else {
        // Normal: Single vibration
        await Vibration.vibrate(duration: 800);
      }
    }
  } catch (e) {
    // Ignore vibration errors in background
  }
}
