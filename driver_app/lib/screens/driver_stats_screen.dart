import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/driver_stats_service.dart';

class DriverStatsScreen extends StatefulWidget {
  final String driverId;

  const DriverStatsScreen({Key? key, required this.driverId}) : super(key: key);

  @override
  _DriverStatsScreenState createState() => _DriverStatsScreenState();
}

class _DriverStatsScreenState extends State<DriverStatsScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('My Stats'),
        backgroundColor: Colors.amber,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: DriverStatsService.getDriverOrders(widget.driverId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error, color: Colors.red, size: 48),
                  SizedBox(height: 16),
                  Text('Error loading stats'),
                  SizedBox(height: 8),
                  ElevatedButton(
                    onPressed: () => setState(() {}),
                    child: Text('Retry'),
                  ),
                ],
              ),
            );
          }

          final orders = snapshot.data?.docs ?? [];
          final stats = DriverStatsService.calculateStats(orders);
          
          final totalDeliveries = stats['totalDeliveries'] ?? 0;
          final totalEarnings = (stats['totalEarnings'] ?? 0.0).toDouble();
          final todayDeliveries = stats['todayDeliveries'] ?? 0;
          final todayEarnings = (stats['todayEarnings'] ?? 0.0).toDouble();
          final weeklyDeliveries = stats['weeklyDeliveries'] ?? 0;
          final weeklyEarnings = (stats['weeklyEarnings'] ?? 0.0).toDouble();

          return Padding(
            padding: EdgeInsets.all(16),
            child: Column(
              children: [
                // Today Stats
                Card(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Today', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                        SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              children: [
                                Text('$todayDeliveries', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.blue)),
                                Text('Deliveries'),
                              ],
                            ),
                            Column(
                              children: [
                                Text('\$${todayEarnings.toStringAsFixed(2)}', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.green)),
                                Text('Earnings'),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),

                SizedBox(height: 16),

                // Weekly Stats
                Card(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('This Week', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                        SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              children: [
                                Text('$weeklyDeliveries', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.blue)),
                                Text('Deliveries'),
                              ],
                            ),
                            Column(
                              children: [
                                Text('\$${weeklyEarnings.toStringAsFixed(2)}', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.green)),
                                Text('Earnings'),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),

                SizedBox(height: 16),

                // All Time Stats
                Card(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('All Time', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                        SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              children: [
                                Text('$totalDeliveries', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.blue)),
                                Text('Deliveries'),
                              ],
                            ),
                            Column(
                              children: [
                                Text('\$${totalEarnings.toStringAsFixed(2)}', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.green)),
                                Text('Earnings'),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),

                SizedBox(height: 16),

                // Performance Metrics
                Card(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Performance', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                        SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              children: [
                                Text(totalDeliveries > 0 ? '\$${(totalEarnings / totalDeliveries).toStringAsFixed(2)}' : '\$0.00', 
                                     style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.orange)),
                                Text('Avg per Delivery'),
                              ],
                            ),
                            Column(
                              children: [
                                Text('${totalDeliveries > 0 ? 100 : 0}%', 
                                     style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.purple)),
                                Text('Completion Rate'),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),

                SizedBox(height: 16),

                // Info message if no data
                if (totalDeliveries == 0)
                  Card(
                    color: Colors.blue[50],
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Icon(Icons.info, color: Colors.blue),
                          SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Complete your first delivery to see stats here!',
                              style: TextStyle(color: Colors.blue[800]),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}