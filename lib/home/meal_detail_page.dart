import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:provider/provider.dart';
import 'package:african_cuisine/home/meal_extras.dart';
import 'package:african_cuisine/provider/cart_provider.dart';

class MealDetailPage extends StatefulWidget {
  final Map<String, dynamic> meal;
  final List<Map<String, dynamic>>? preselectedExtras;
  final String? prefilledInstructions;
  final int? editingIndex;

  const MealDetailPage({
    super.key,
    required this.meal,
    this.preselectedExtras,
    this.prefilledInstructions,
    this.editingIndex,
  });

  @override
  State<MealDetailPage> createState() => _MealDetailPageState();
}

class _MealDetailPageState extends State<MealDetailPage> {
  final Map<String, Map<String, dynamic>> selectedExtras = {};
  final TextEditingController instructionsController = TextEditingController();

  @override
  void initState() {
    super.initState();
    if (widget.preselectedExtras != null) {
      for (var extra in widget.preselectedExtras!) {
        selectedExtras[extra['name']] = extra;
      }
    }
    if (widget.prefilledInstructions != null) {
      instructionsController.text = widget.prefilledInstructions!;
    }
  }

  double getExtrasTotal() {
    return selectedExtras.values.fold(0.0, (sum, extra) {
      return sum +
          (extra['price'] is num
              ? (extra['price'] as num).toDouble()
              : double.tryParse(extra['price'].toString()) ?? 0.0);
    });
  }

  bool validateRequiredExtras() {
    final extras = mealExtras[widget.meal['name']] ?? [];
    final requiredGroups = extras
        .where((e) => e['required'] == true && e.containsKey('group'))
        .map((e) => e['group'])
        .toSet();

    final selectedGroups = selectedExtras.values
        .where((e) => e['required'] == true && e.containsKey('group'))
        .map((e) => e['group'])
        .toSet();

    return requiredGroups.difference(selectedGroups).isEmpty;
  }

  @override
  Widget build(BuildContext context) {
    final extras = mealExtras[widget.meal['name']] ?? [];
    final groupedExtras = <String, List<Map<String, dynamic>>>{};
    for (final extra in extras) {
      final group = extra['group'] ?? 'optional';
      groupedExtras.putIfAbsent(group, () => []).add(extra);
    }

    final basePrice = widget.meal['price'] is num
        ? (widget.meal['price'] as num).toDouble()
        : double.tryParse(
                widget.meal['price'].toString().replaceAll('\$', ''),
              ) ??
              0.0;

    final totalPrice = basePrice + getExtrasTotal();

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.meal['name']),
        backgroundColor: Colors.deepOrange,
      ),
      body: Padding(
        padding: const EdgeInsets.all(17.0),
        child: ListView(
          children: [
            Image.asset(widget.meal['image'], height: 201),
            const SizedBox(height: 17),
            Text(
              widget.meal['name'],
              style: const TextStyle(fontSize: 23, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 9),
            const Text("Customize your meal below."),
            const SizedBox(height: 17),
            for (var entry in groupedExtras.entries)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    entry.key == 'optional'
                        ? 'Optional Extras'
                        : '${entry.key} (Required - Choose 1)',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 17,
                      color: entry.key != 'optional' ? Colors.red : null,
                    ),
                  ),
                  const SizedBox(height: 9),
                  Wrap(
                    spacing: 9,
                    children: entry.value.map((extra) {
                      final name = extra['name'];
                      final price = extra['price'] ?? 0.0;
                      final isSelected = selectedExtras.containsKey(name);

                      return FilterChip(
                        label: Text(
                          price > 0
                              ? '$name +\$${price.toStringAsFixed(2)}'
                              : name,
                          style: TextStyle(
                            fontWeight: extra['required'] == true
                                ? FontWeight.bold
                                : FontWeight.normal,
                          ),
                        ),
                        selected: isSelected,
                        selectedColor: Colors.deepOrange.withOpacity(0.3),
                        onSelected: (selected) {
                          setState(() {
                            if (extra['required'] == true &&
                                extra.containsKey('group')) {
                              final group = extra['group'];
                              selectedExtras.removeWhere(
                                (key, e) => e['group'] == group,
                              );
                              if (selected) {
                                selectedExtras[name] = extra;
                              }
                            } else {
                              if (isSelected) {
                                selectedExtras.remove(name);
                              } else {
                                selectedExtras[name] = extra;
                              }
                            }
                          });
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 13),
                ],
              ),
            const Text(
              "Special Instructions",
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 7),
            TextField(
              controller: instructionsController,
              decoration: const InputDecoration(
                hintText: "e.g. No onions, sauce on the side",
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
            const SizedBox(height: 17),
            Text(
              "Total: \$${totalPrice.toStringAsFixed(2)}",
              style: const TextStyle(fontSize: 19, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 17),
            ElevatedButton(
              onPressed: () {
                if (!validateRequiredExtras()) {
                  Fluttertoast.showToast(
                    msg: "Please select required extras before adding to cart.",
                    backgroundColor: Colors.red,
                    textColor: Colors.white,
                  );
                  return;
                }

                final cartItem = {
                  'name': widget.meal['name'],
                  'image': widget.meal['image'],
                  'category': widget.meal['category'],
                  'price': totalPrice,
                  'extras': selectedExtras.values.toList(),
                  'instructions': instructionsController.text,
                  'quantity': 1,
                };

                final cartProvider = Provider.of<CartProvider>(
                  context,
                  listen: false,
                );

                if (widget.editingIndex != null) {
                  cartProvider.updateItem(widget.editingIndex!, cartItem);
                  Fluttertoast.showToast(
                    msg: "${widget.meal['name']} updated!",
                    backgroundColor: Colors.orange,
                    textColor: Colors.white,
                  );
                } else {
                  cartProvider.addToCart(cartItem);
                  Fluttertoast.showToast(
                    msg: "${widget.meal['name']} added to cart!",
                    backgroundColor: Colors.green,
                    textColor: Colors.white,
                  );
                }
                Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.deepOrange,
                padding: const EdgeInsets.symmetric(vertical: 15),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(11),
                ),
              ),
              child: Text(
                widget.editingIndex != null ? "Update Cart" : "Add to Cart",
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
