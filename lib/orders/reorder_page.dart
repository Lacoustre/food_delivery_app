import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:african_cuisine/provider/cart_provider.dart';

class ReorderPage extends StatefulWidget {
  final String orderId;

  const ReorderPage({super.key, required this.orderId});

  @override
  State<ReorderPage> createState() => _ReorderPageState();
}

class _ReorderPageState extends State<ReorderPage> {
  bool _isLoading = true;
  String _message = 'Reordering...';

  @override
  void initState() {
    super.initState();
    _handleReorder();
  }

  Future<void> _handleReorder() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('orders')
          .doc(widget.orderId)
          .get();

      if (!doc.exists) {
        throw Exception('Original order not found.');
      }

      final data = doc.data();
      final cartItems = List<Map<String, dynamic>>.from(data?['items'] ?? []);

      final cartProvider = Provider.of<CartProvider>(context, listen: false);
      cartProvider.clearCart();

      for (var item in cartItems) {
        cartProvider.addToCart({
          'name': item['name'],
          'price': item['price'],
          'image': item['image'],
          'category': item['category'],
          'quantity': item['quantity'],
          'extras': item['extras'],
          'instructions': item['instructions'],
          'reordered': true, // Used to highlight in cart
        });
      }

      Fluttertoast.showToast(
        msg: "🛍️ Items from your last order added to cart",
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.TOP,
        backgroundColor: Colors.green.shade600,
        textColor: Colors.white,
        fontSize: 14.0,
      );

      if (mounted) {
        Navigator.pushNamedAndRemoveUntil(context, '/cart', (_) => false);
      }
    } catch (e) {
      setState(() {
        _message = 'Failed to reorder: ${e.toString()}';
        _isLoading = false;
      });
      Fluttertoast.showToast(
        msg: "❌ Error: ${e.toString()}",
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.TOP,
        backgroundColor: Colors.red.shade600,
        textColor: Colors.white,
        fontSize: 14.0,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Reorder"),
        backgroundColor: Colors.deepOrange,
      ),
      body: Center(
        child: _isLoading
            ? const CircularProgressIndicator()
            : Text(
                _message,
                style: const TextStyle(fontSize: 16),
                textAlign: TextAlign.center,
              ),
      ),
    );
  }
}
