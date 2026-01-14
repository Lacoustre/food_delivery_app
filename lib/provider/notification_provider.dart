import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:vibration/vibration.dart';
import 'package:flutter_ringtone_player/flutter_ringtone_player.dart';

class NotificationProvider extends ChangeNotifier {
  int _unreadCount = 0;
  int get unreadCount => _unreadCount;

  StreamSubscription<QuerySnapshot>? _subscription;
  bool _initialSyncDone = false;

  void startListeningToNotifications() {
    // Listen to auth state changes and restart listener accordingly
    FirebaseAuth.instance.authStateChanges().listen((user) {
      _subscription?.cancel(); // Cancel previous listener
      _unreadCount = 0;
      _initialSyncDone = false;
      notifyListeners();
      
      if (user == null) return;

      try {
        _subscription = FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('notifications')
            .where('read', isEqualTo: false)
            .snapshots()
            .listen(
              (snapshot) async {
                final unread = snapshot.docs.length;

                if (_initialSyncDone && unread > _unreadCount) {
                  await Future.delayed(const Duration(milliseconds: 300));

                  final hasVibrator = await Vibration.hasVibrator();
                  if (hasVibrator == true) {
                    Vibration.vibrate(duration: 300);
                  }

                  FlutterRingtonePlayer().playNotification();
                }

                _unreadCount = unread;
                notifyListeners();

                if (!_initialSyncDone) _initialSyncDone = true;
              },
              onError: (error) {
                // Silently handle permission errors to prevent crashes
                if (kDebugMode) {
                  print('Notification listener error: $error');
                }
                _unreadCount = 0;
                notifyListeners();
              },
            );
      } catch (e) {
        if (kDebugMode) {
          print('Failed to start notification listener: $e');
        }
      }
    });
  }

  Future<void> markAllAsRead() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final unreadQuery = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('notifications')
          .where('read', isEqualTo: false)
          .get();

      if (unreadQuery.docs.isEmpty) return;

      final batch = FirebaseFirestore.instance.batch();
      for (final doc in unreadQuery.docs) {
        batch.update(doc.reference, {'read': true});
      }
      await batch.commit();

      _unreadCount = 0;
      notifyListeners();
    } catch (e) {
      // Silently handle permission errors
      if (kDebugMode) {
        print('Mark as read error: $e');
      }
    }
  }

  void disposeListener() {
    _subscription?.cancel();
  }

  @override
  void dispose() {
    disposeListener();
    super.dispose();
  }
}
