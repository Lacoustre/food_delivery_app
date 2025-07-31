import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:african_cuisine/payment/payment_page.dart';
import 'package:african_cuisine/provider/cart_provider.dart';
import 'package:african_cuisine/home/meal_extras.dart';
import 'package:african_cuisine/home/meal_detail_page.dart';

class CartPage extends StatefulWidget {
  const CartPage({super.key});

  @override
  State<CartPage> createState() => _CartPageState();
}

class _CartPageState extends State<CartPage> {
  double safeToDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) {
      return double.tryParse(value.replaceAll(RegExp(r'[^\d.]'), '')) ?? 0.0;
    }
    return 0.0;
  }

  double calculateItemTotal(Map<String, dynamic> item) {
    final double basePrice = safeToDouble(item['price']);
    final int quantity = item['quantity'] ?? 1;

    double extrasTotal = 0.0;
    final extras = item['extras'] as List?;
    if (extras != null) {
      for (final extra in extras) {
        if (extra is Map<String, dynamic>) {
          extrasTotal += safeToDouble(extra['price']);
        }
      }
    }

    return (basePrice * quantity) + (extrasTotal * quantity);
  }

  bool hasRequiredExtras(Map<String, dynamic> item) {
    final String mealName = item['name'] as String;
    final List<Map<String, dynamic>> extrasOptions = mealExtras[mealName] ?? [];
    final List<dynamic> selectedExtras = item['extras'] as List? ?? [];

    final requiredGroups = extrasOptions
        .where((e) => e['required'] == true && e.containsKey('group'))
        .map((e) => e['group'] as String)
        .toSet();

    final selectedGroups = selectedExtras
        .whereType<Map<String, dynamic>>()
        .where((e) => e['required'] == true && e.containsKey('group'))
        .map((e) => e['group'] as String)
        .toSet();

    return requiredGroups.difference(selectedGroups).isEmpty;
  }

  bool allRequiredExtrasSelected() {
    final cartItems = Provider.of<CartProvider>(
      context,
      listen: false,
    ).cartItems;
    return cartItems.every(hasRequiredExtras);
  }

  @override
  Widget build(BuildContext context) {
    final cartProvider = Provider.of<CartProvider>(context);
    final cartItems = cartProvider.cartItems;

    final subtotal = cartItems.fold(
      0.0,
      (sum, item) => sum + calculateItemTotal(item),
    );
    final tax = subtotal * 0.0735;
    final total = subtotal + tax;
    final canCheckout = allRequiredExtrasSelected() && cartItems.isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Your Cart'),
        backgroundColor: Colors.deepOrange,
        centerTitle: true,
      ),
      backgroundColor: const Color(0xFFFDF1EC),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: cartItems.isEmpty
            ? const Center(child: Text("Your cart is empty."))
            : Column(
                children: [
                  Expanded(
                    child: ListView.separated(
                      itemCount: cartItems.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (_, index) {
                        final item = cartItems[index];
                        final itemTotal = calculateItemTotal(item);
                        final quantity = item['quantity'] ?? 1;
                        final missingRequired = !hasRequiredExtras(item);

                        return Card(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: missingRequired
                                ? const BorderSide(
                                    color: Colors.red,
                                    width: 1.5,
                                  )
                                : BorderSide.none,
                          ),
                          color: Colors.grey.shade100,
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(10),
                                      child: Image.asset(
                                        item['image'],
                                        width: 60,
                                        height: 60,
                                        fit: BoxFit.cover,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            item['name'],
                                            style: const TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          if (missingRequired)
                                            const Text(
                                              "⚠️ Required selection missing",
                                              style: TextStyle(
                                                color: Colors.red,
                                                fontSize: 12,
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                    Row(
                                      children: [
                                        IconButton(
                                          icon: const Icon(
                                            Icons.edit,
                                            color: Colors.blue,
                                          ),
                                          onPressed: () => Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (_) => MealDetailPage(
                                                meal: item,
                                                preselectedExtras:
                                                    (item['extras'] as List?)
                                                        ?.cast<
                                                          Map<String, dynamic>
                                                        >(),
                                                prefilledInstructions:
                                                    item['instructions']
                                                        as String?,
                                                editingIndex: index,
                                              ),
                                            ),
                                          ),
                                        ),
                                        IconButton(
                                          icon: const Icon(
                                            Icons.delete,
                                            color: Colors.red,
                                          ),
                                          onPressed: () =>
                                              cartProvider.removeItem(index),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                if (item['extras'] != null &&
                                    (item['extras'] as List).isNotEmpty)
                                  Padding(
                                    padding: const EdgeInsets.only(left: 8),
                                    child: Text(
                                      (item['extras'] as List)
                                          .cast<Map<String, dynamic>>()
                                          .map<String>(
                                            (e) =>
                                                '${e['name']}${safeToDouble(e['price']) > 0 ? " (+\$${safeToDouble(e['price']).toStringAsFixed(2)})" : ""}',
                                          )
                                          .join(', '),
                                      style: const TextStyle(
                                        fontSize: 13,
                                        color: Colors.black87,
                                      ),
                                    ),
                                  ),
                                Padding(
                                  padding: const EdgeInsets.only(top: 8),
                                  child: Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        "Total: \$${itemTotal.toStringAsFixed(2)}",
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14,
                                          color: Colors.deepOrange,
                                        ),
                                      ),
                                      Row(
                                        children: [
                                          IconButton(
                                            icon: const Icon(Icons.remove),
                                            onPressed: () {
                                              if (quantity > 1) {
                                                cartProvider.updateQuantity(
                                                  index,
                                                  quantity - 1,
                                                );
                                              } else {
                                                cartProvider.removeItem(index);
                                              }
                                            },
                                          ),
                                          Text(
                                            quantity.toString(),
                                            style: const TextStyle(
                                              fontSize: 16,
                                            ),
                                          ),
                                          IconButton(
                                            icon: const Icon(Icons.add),
                                            onPressed: () =>
                                                cartProvider.updateQuantity(
                                                  index,
                                                  quantity + 1,
                                                ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  const Divider(height: 24),
                  Column(
                    children: [
                      SummaryRow(label: "Subtotal", amount: subtotal),
                      SummaryRow(label: "Tax (7.35%)", amount: tax),
                      SummaryRow(label: "Total", amount: total, bold: true),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Column(
                    children: [
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: canCheckout
                              ? () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => const PaymentPage(),
                                    ),
                                  );
                                }
                              : null,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: canCheckout
                                ? Colors.deepOrange
                                : Colors.grey[400],
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: Text(
                            canCheckout
                                ? "Proceed to Checkout"
                                : "Complete Required Selections",
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: canCheckout
                                  ? Colors.white
                                  : Colors.grey[600],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          icon: const Icon(
                            Icons.storefront,
                            color: Colors.deepOrange,
                          ),
                          label: const Text(
                            "Continue Shopping",
                            style: TextStyle(
                              color: Colors.deepOrange,
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                          ),
                          onPressed: () {
                            Navigator.pushNamedAndRemoveUntil(
                              context,
                              '/home',
                              (route) => false,
                            );
                          },
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Colors.deepOrange),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
      ),
    );
  }
}

class SummaryRow extends StatelessWidget {
  final String label;
  final double amount;
  final bool bold;

  const SummaryRow({
    super.key,
    required this.label,
    required this.amount,
    this.bold = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 15,
              fontWeight: bold ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          Text(
            "\$${amount.toStringAsFixed(2)}",
            style: TextStyle(
              fontSize: 15,
              fontWeight: bold ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }
}
