import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:vibration/vibration.dart';
import 'package:flutter_ringtone_player/flutter_ringtone_player.dart';

/// Unread badge count backed by the Supabase user_notifications table (the
/// per-user Firestore notifications subcollection is retired).
class NotificationProvider extends ChangeNotifier {
  int _unreadCount = 0;
  int get unreadCount => _unreadCount;

  final SupabaseClient _supabase = Supabase.instance.client;
  StreamSubscription<List<Map<String, dynamic>>>? _subscription;
  StreamSubscription<AuthState>? _authSubscription;
  bool _initialSyncDone = false;

  void startListeningToNotifications() {
    _attach();
    // Restart the listener whenever the session changes
    _authSubscription ??= _supabase.auth.onAuthStateChange.listen((_) {
      _attach();
    });
  }

  void _attach() {
    _subscription?.cancel();
    _unreadCount = 0;
    _initialSyncDone = false;
    notifyListeners();

    final user = _supabase.auth.currentUser;
    if (user == null) return;

    try {
      _subscription = _supabase
          .from('user_notifications')
          .stream(primaryKey: ['id'])
          .eq('user_id', user.id)
          .listen(
            (rows) async {
              final unread = rows.where((r) => r['read'] != true).length;

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
  }

  Future<void> markAllAsRead() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return;

    try {
      await _supabase
          .from('user_notifications')
          .update({'read': true})
          .eq('user_id', user.id)
          .eq('read', false);

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
    _authSubscription?.cancel();
    super.dispose();
  }
}
