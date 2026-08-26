import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide User;
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
      final row = await Supabase.instance.client
          .from('orders')
          .select('*, order_items(*)')
          .eq('id', widget.orderId)
          .maybeSingle();

      if (row == null) {
        throw Exception('Original order not found.');
      }

      final cartItems = List<Map<String, dynamic>>.from(row['order_items'] ?? []);

      if (!mounted) return;
      final cartProvider = Provider.of<CartProvider>(context, listen: false);
      cartProvider.clearCart();

      for (var item in cartItems) {
        cartProvider.addToCart({
          'id': item['meal_id'],
          'name': item['name'],
          'price': item['unit_price'],
          // Reordering doesn't have the meal's current image/category on
          // hand (order_items only stores what was actually charged) —
          // the cart UI falls back to a placeholder for these.
          'image': null,
          'category': null,
          'quantity': item['quantity'],
          'extras': const [],
          'instructions': item['notes'] ?? '',
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
