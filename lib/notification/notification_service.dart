import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide User;
import 'package:vibration/vibration.dart';

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

    // Save FCM token to the Supabase profile (where the notification
    // sender and admin views read it)
    final token = await _messaging.getToken();
    final supabaseUser = Supabase.instance.client.auth.currentUser;
    if (token != null && supabaseUser != null) {
      try {
        await Supabase.instance.client
            .from('profiles')
            .update({'fcm_token': token}).eq('id', supabaseUser.id);
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

  // ====== STORAGE (Supabase user_notifications — what the notification
  // page and unread badge stream) ======
  static Future<void> _appendUserNotificationList(RemoteMessage message) async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return; // cannot save without a session

    try {
      await Supabase.instance.client.from('user_notifications').insert({
        'user_id': user.id,
        'title': message.notification?.title ?? '',
        'body': message.notification?.body ?? '',
        'type': (message.data['type'] ?? 'general').toString(),
        'read': false,
      });
    } catch (e) {
      debugPrint('❌ Failed to record notification: $e');
    }
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

  // No in-app feed write here: the background isolate has no Supabase
  // session, and the OS already displays the push itself. The old
  // Firestore array this wrote to is no longer read by anything.

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
