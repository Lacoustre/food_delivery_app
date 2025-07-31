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
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    _subscription?.cancel(); // Cancel previous listener

    _subscription = FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('notifications')
        .snapshots()
        .listen((snapshot) async {
          final unread = snapshot.docs
              .where((doc) => !(doc.data()['read'] ?? true))
              .length;

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
        });
  }

  Future<void> markAllAsRead() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final snapshot = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('notifications')
        .where('read', isEqualTo: false)
        .get();

    final batch = FirebaseFirestore.instance.batch();
    for (var doc in snapshot.docs) {
      batch.update(doc.reference, {'read': true});
    }

    await batch.commit();

    _unreadCount = 0;
    notifyListeners();
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
