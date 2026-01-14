import 'package:shared_preferences/shared_preferences.dart';

class StorageService {
  static SharedPreferences? _prefs;

  static Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  static Future<void> setBool(String key, bool value) async {
    await _prefs?.setBool(key, value);
  }

  static bool getBool(String key, {bool defaultValue = false}) {
    return _prefs?.getBool(key) ?? defaultValue;
  }

  static Future<void> setString(String key, String value) async {
    await _prefs?.setString(key, value);
  }

  static String getString(String key, {String defaultValue = ''}) {
    return _prefs?.getString(key) ?? defaultValue;
  }

  static Future<void> setInt(String key, int value) async {
    await _prefs?.setInt(key, value);
  }

  static int getInt(String key, {int defaultValue = 0}) {
    return _prefs?.getInt(key) ?? defaultValue;
  }

  static Future<void> remove(String key) async {
    await _prefs?.remove(key);
  }

  static Future<void> clear() async {
    await _prefs?.clear();
  }

  // Driver-specific convenience methods
  static Future<void> setDriverOnline(bool isOnline) async {
    await setBool('driver_online', isOnline);
  }

  static bool isDriverOnline() {
    return getBool('driver_online');
  }

  static Future<void> setDriverApprovalStatus(String status) async {
    await setString('driver_approval_status', status);
  }

  static String getDriverApprovalStatus() {
    return getString('driver_approval_status', defaultValue: 'pending');
  }

  static bool isDriverApproved() {
    return getDriverApprovalStatus() == 'approved';
  }

  static Future<void> setLastKnownLocation(double lat, double lng) async {
    await setString('last_lat', lat.toString());
    await setString('last_lng', lng.toString());
  }

  static Map<String, double>? getLastKnownLocation() {
    final latStr = getString('last_lat');
    final lngStr = getString('last_lng');
    if (latStr.isEmpty || lngStr.isEmpty) return null;
    
    return {
      'lat': double.tryParse(latStr) ?? 0.0,
      'lng': double.tryParse(lngStr) ?? 0.0,
    };
  }

  // Biometric approval tracking
  static Future<void> setBiometricApprovalCompleted(String userId) async {
    await setString('biometric_approval_$userId', 'completed');
  }

  static bool isBiometricApprovalCompleted(String userId) {
    return getString('biometric_approval_$userId') == 'completed';
  }

  static Future<void> clearBiometricApproval(String userId) async {
    await remove('biometric_approval_$userId');
  }

  // Phone number linking
  static Future<void> setPhoneLinked(String userId, String phone) async {
    await setString('phone_linked_$userId', phone);
  }

  static String? getLinkedPhone(String userId) {
    final phone = getString('phone_linked_$userId');
    return phone.isEmpty ? null : phone;
  }

  static Future<void> clearLinkedPhone(String userId) async {
    await remove('phone_linked_$userId');
  }
}