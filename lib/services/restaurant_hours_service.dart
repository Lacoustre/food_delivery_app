import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

class RestaurantHoursService {
  static final RestaurantHoursService _instance =
      RestaurantHoursService._internal();
  factory RestaurantHoursService() => _instance;
  RestaurantHoursService._internal();

  Timer? _timer;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

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

  Future<void> _updateRestaurantStatus() async {
    try {
      final now = DateTime.now();
      final currentTime = TimeOfDay.fromDateTime(now);
      final currentDay = _getDayOfWeek(now.weekday);

      final hoursDoc = await _firestore
          .collection('settings')
          .doc('restaurant')
          .get();

      if (!hoursDoc.exists) {
        return; // Skip if no settings document
      }

      final hoursData = hoursDoc.data()!;
      final hours = hoursData['hours'] as Map<String, dynamic>?;

      if (hours == null) return;

      final daySchedule = hours[currentDay] as Map<String, dynamic>?;

      if (daySchedule == null || daySchedule['closed'] == true) {
        await _setRestaurantStatus(false);
        return;
      }

      final openTime = _parseTime(daySchedule['open']);
      final closeTime = _parseTime(daySchedule['close']);

      if (openTime != null && closeTime != null) {
        final isOpen = _isTimeInRange(currentTime, openTime, closeTime);
        await _setRestaurantStatus(isOpen);
      }
    } catch (e) {
      // Silently handle permission errors
      debugPrint('Restaurant status update skipped: $e');
    }
  }

  Future<void> _setRestaurantStatus(bool isOpen) async {
    try {
      await _firestore.collection('settings').doc('restaurant').set({
        'isOpen': isOpen,
        'lastUpdated': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('Failed to update restaurant status: $e');
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
      final statusDoc = await _firestore
          .collection('settings')
          .doc('restaurant')
          .get();

      if (statusDoc.exists) {
        return statusDoc.data()?['isOpen'] ?? false;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  Stream restaurantStatusStream() {
    return _firestore
        .collection('settings')
        .doc('restaurant')
        .snapshots()
        .map((doc) => doc.data()?['isOpen'] ?? false)
        .handleError((error) {
          debugPrint('Restaurant status stream error: $error');
        });
  }
}
