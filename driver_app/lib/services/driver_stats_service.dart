import 'package:cloud_firestore/cloud_firestore.dart';

class DriverStatsService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Get driver stats from orders collection (no separate stats collection needed)
  static Stream<QuerySnapshot> getDriverOrders(String driverId) {
    return _firestore
        .collection('orders')
        .where('driverId', isEqualTo: driverId)
        .where('deliveryStatus', isEqualTo: 'delivered')
        .snapshots();
  }

  // Calculate stats from orders
  static Map<String, dynamic> calculateStats(List<QueryDocumentSnapshot> orders) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final weekStart = now.subtract(Duration(days: now.weekday - 1));
    final weekStartDate = DateTime(weekStart.year, weekStart.month, weekStart.day);

    int totalDeliveries = orders.length;
    double totalEarnings = 0.0;
    int todayDeliveries = 0;
    double todayEarnings = 0.0;
    int weeklyDeliveries = 0;
    double weeklyEarnings = 0.0;

    for (var doc in orders) {
      final data = doc.data() as Map<String, dynamic>;
      final deliveryFee = (data['pricing']?['deliveryFee'] ?? 0.0).toDouble();
      final tip = (data['pricing']?['tip'] ?? 0.0).toDouble();
      final earnings = deliveryFee + tip;
      
      totalEarnings += earnings;

      // Check if delivered today
      final completedAt = data['completedAt'] as Timestamp?;
      if (completedAt != null) {
        final completedDate = completedAt.toDate();
        
        if (completedDate.isAfter(today)) {
          todayDeliveries++;
          todayEarnings += earnings;
        }
        
        if (completedDate.isAfter(weekStartDate)) {
          weeklyDeliveries++;
          weeklyEarnings += earnings;
        }
      }
    }

    return {
      'totalDeliveries': totalDeliveries,
      'totalEarnings': totalEarnings,
      'todayDeliveries': todayDeliveries,
      'todayEarnings': todayEarnings,
      'weeklyDeliveries': weeklyDeliveries,
      'weeklyEarnings': weeklyEarnings,
    };
  }
}