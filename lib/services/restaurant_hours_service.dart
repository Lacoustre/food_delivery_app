import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Open/closed status lives in the Supabase `settings` table
/// (key='restaurant', value jsonb) — the same row the admin panel manages
/// and the webapp banner reads. Status writes only succeed for admin
/// sessions (RLS); for customers they fail silently, same as the old
/// Firestore rules.
class RestaurantHoursService {
  bool _isOpenNow = false;
  static final RestaurantHoursService _instance =
      RestaurantHoursService._internal();
  factory RestaurantHoursService() => _instance;
  RestaurantHoursService._internal();

  Timer? _timer;
  SupabaseClient get _supabase => Supabase.instance.client;

  void startAutoSchedule() {
    // Check every minute (or more frequently during opening/closing times)
    _timer = Timer.periodic(const Duration(minutes: 1), (_) {
      _updateRestaurantStatus();
    });

    // Initial check
    _updateRestaurantStatus();
  }

  void stopAutoSchedule() {
    _timer?.cancel();
  }

  Future<Map<String, dynamic>?> _fetchSettingsValue() async {
    final row = await _supabase
        .from('settings')
        .select('value')
        .eq('key', 'restaurant')
        .maybeSingle();
    return row?['value'] as Map<String, dynamic>?;
  }

  Future<void> _updateRestaurantStatus() async {
    try {
      final now = DateTime.now();
      final currentTime = TimeOfDay.fromDateTime(now);
      final currentDay = _getDayOfWeek(now.weekday);

      final value = await _fetchSettingsValue();
      if (value == null) return;

      // Admin panel writes businessHours; accept the legacy hours key too.
      final hours = (value['businessHours'] ?? value['hours'])
          as Map<String, dynamic>?;
      if (hours == null) return;

      final daySchedule = hours[currentDay] as Map<String, dynamic>?;

      if (daySchedule == null || daySchedule['closed'] == true) {
        _isOpenNow = false;
        return;
      }

      final openTime = _parseTime(daySchedule['open']);
      final closeTime = _parseTime(daySchedule['close']);

      // Deliberately does not write back. This value is derived from
      // businessHours, which every client and the server can read directly —
      // caching it into a shared setting only created a way for it to be
      // wrong. It last wrote `false` at closing time and, with no admin
      // running the app afterwards, left the server refusing orders through
      // the whole of the next day's opening hours.
      if (openTime != null && closeTime != null) {
        _isOpenNow = _isTimeInRange(currentTime, openTime, closeTime);
      }
    } catch (e) {
      // Silently handle permission errors
      debugPrint('Restaurant status update skipped: $e');
    }
  }


  String _getDayOfWeek(int weekday) {
    const days = [
      'monday',
      'tuesday',
      'wednesday',
      'thursday',
      'friday',
      'saturday',
      'sunday',
    ];
    return days[weekday - 1];
  }

  TimeOfDay? _parseTime(String? timeString) {
    if (timeString == null) return null;
    final parts = timeString.split(':');
    if (parts.length != 2) return null;

    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);

    if (hour == null || minute == null) return null;
    return TimeOfDay(hour: hour, minute: minute);
  }

  bool _isTimeInRange(TimeOfDay current, TimeOfDay open, TimeOfDay close) {
    final currentMinutes = current.hour * 60 + current.minute;
    final openMinutes = open.hour * 60 + open.minute;
    final closeMinutes = close.hour * 60 + close.minute;

    if (closeMinutes > openMinutes) {
      // Same day (e.g., 9:00 AM to 10:00 PM)
      return currentMinutes >= openMinutes && currentMinutes < closeMinutes;
    } else {
      // Crosses midnight (e.g., 10:00 PM to 2:00 AM)
      return currentMinutes >= openMinutes || currentMinutes < closeMinutes;
    }
  }

  Future<bool> isRestaurantOpen() async {
    try {
      await _updateRestaurantStatus();
      return _isOpenNow;
    } catch (e) {
      return false;
    }
  }

  Stream<bool> restaurantStatusStream() {
    return _supabase
        .from('settings')
        .stream(primaryKey: ['key'])
        .eq('key', 'restaurant')
        .map((rows) {
          if (rows.isEmpty) return false;
          final value = rows.first['value'] as Map<String, dynamic>?;
          return (value?['isOpen'] as bool?) ?? false;
        })
        .handleError((error) {
          debugPrint('Restaurant status stream error: $error');
        });
  }
}
