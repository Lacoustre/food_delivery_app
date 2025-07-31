import 'dart:math';

class OrderNumberGenerator {
  static final _random = Random();
  static final Set<String> _recentNumbers = <String>{};
  static const int _cacheSize = 100;

  static String generate() {
    String orderNumber;
    int attempts = 0;
    const maxAttempts = 5;

    do {
      orderNumber = _generateBaseNumber();
      if (_recentNumbers.contains(orderNumber)) {
        attempts++;
        continue;
      }
      _addToCache(orderNumber);
      break;
    } while (attempts < maxAttempts);

    return orderNumber;
  }

  static String _generateBaseNumber() {
    final now = DateTime.now();
    final randomSuffix = _random.nextInt(9000) + 1000;
    return 'ORD-${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}-'
        '${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}${now.second.toString().padLeft(2, '0')}-'
        '${randomSuffix.toString()}';
  }

  static void _addToCache(String orderNumber) {
    _recentNumbers.add(orderNumber);
    if (_recentNumbers.length > _cacheSize) {
      final List<String> numbers = _recentNumbers.toList()..sort();
      _recentNumbers
        ..clear()
        ..addAll(numbers.skip(numbers.length - _cacheSize ~/ 2));
    }
  }

  static bool isValidFormat(String orderNumber) {
    final regex = RegExp(r'^ORD-\d{8}-\d{6}-\d{4}$');
    return regex.hasMatch(orderNumber);
  }

  static DateTime? getDateFromOrderNumber(String orderNumber) {
    if (!isValidFormat(orderNumber)) return null;
    try {
      final parts = orderNumber.split('-');
      final dateStr = parts[1];
      final timeStr = parts[2];
      return DateTime(
        int.parse(dateStr.substring(0, 4)),
        int.parse(dateStr.substring(4, 6)),
        int.parse(dateStr.substring(6, 8)),
        int.parse(timeStr.substring(0, 2)),
        int.parse(timeStr.substring(2, 4)),
        int.parse(timeStr.substring(4, 6)),
      );
    } catch (_) {
      return null;
    }
  }
}
