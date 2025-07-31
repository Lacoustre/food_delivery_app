import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';

class RatePastOrdersPage extends StatelessWidget {
  const RatePastOrdersPage({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return const Scaffold(
        body: Center(child: Text("Please log in to view your orders.")),
      );
    }

    final ordersRef = FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('orders')
        .where('status', isEqualTo: 'completed')
        .where('rated', isEqualTo: false);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Rate Past Orders'),
        backgroundColor: Colors.deepOrange,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: ordersRef.snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            debugPrint("Firestore error: ${snapshot.error}");
            return const Center(child: Text("Error loading orders."));
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(
              child: Text(
                'No completed orders to rate at the moment.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ),
            );
          }

          final docs = snapshot.data!.docs;

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: docs.length,
            separatorBuilder: (_, __) => const Divider(),
            itemBuilder: (context, index) {
              try {
                final order = docs[index];
                final orderId = order.id;
                final mealName = order['mealName']?.toString() ?? 'Meal';
                return ListTile(
                  leading: const Icon(Icons.fastfood, color: Colors.deepOrange),
                  title: Text(mealName),
                  subtitle: Text('Order ID: $orderId'),
                  trailing: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.deepOrange,
                    ),
                    onPressed: () =>
                        _showRatingDialog(context, user.uid, orderId, order),
                    child: const Text('Rate'),
                  ),
                );
              } catch (e) {
                return ListTile(
                  leading: const Icon(Icons.error, color: Colors.red),
                  title: const Text("Error loading item"),
                  subtitle: Text(e.toString()),
                );
              }
            },
          );
        },
      ),
    );
  }

  void _showRatingDialog(
    BuildContext context,
    String userId,
    String orderId,
    DocumentSnapshot order,
  ) {
    double rating = 3.0;
    final TextEditingController reviewController = TextEditingController();
    bool isSubmitting = false;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              title: const Text('Rate Your Order'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  RatingBar.builder(
                    initialRating: rating,
                    minRating: 1,
                    allowHalfRating: true,
                    itemCount: 5,
                    itemBuilder: (context, _) =>
                        const Icon(Icons.star, color: Colors.amber),
                    onRatingUpdate: (val) {
                      setStateDialog(() => rating = val);
                    },
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: reviewController,
                    decoration: const InputDecoration(
                      labelText: 'Leave a comment (optional)',
                      border: OutlineInputBorder(),
                    ),
                    maxLines: 3,
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: isSubmitting
                      ? null
                      : () async {
                          final trimmedReview = reviewController.text.trim();
                          setStateDialog(() => isSubmitting = true);

                          try {
                            final mealName =
                                order['mealName']?.toString() ?? 'Meal';

                            // Update the user's order
                            await FirebaseFirestore.instance
                                .collection('users')
                                .doc(userId)
                                .collection('orders')
                                .doc(orderId)
                                .update({
                                  'rated': true,
                                  'rating': rating,
                                  'review': trimmedReview,
                                });

                            // Save to global reviews collection
                            await FirebaseFirestore.instance
                                .collection('reviews')
                                .add({
                                  'userId': userId,
                                  'orderId': orderId,
                                  'mealName': mealName,
                                  'rating': rating,
                                  'review': trimmedReview,
                                  'timestamp': FieldValue.serverTimestamp(),
                                });

                            Navigator.pop(context);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text("Thanks for your feedback!"),
                              ),
                            );
                          } catch (e) {
                            setStateDialog(() => isSubmitting = false);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text("Error: $e")),
                            );
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.deepOrange,
                  ),
                  child: isSubmitting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('Submit'),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
