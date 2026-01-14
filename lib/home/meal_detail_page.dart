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

    // For protein group, check if at least one protein is selected
    if (requiredGroups.contains('Protein')) {
      final selectedProteins = selectedExtras.values
          .where((e) => e['group'] == 'Protein')
          .toList();
      if (selectedProteins.isEmpty) return false;
    }

    // For other required groups, check normal validation
    final otherRequiredGroups = requiredGroups.where((g) => g != 'Protein').toSet();
    final selectedGroups = selectedExtras.values
        .where((e) => e['required'] == true && e.containsKey('group') && e['group'] != 'Protein')
        .map((e) => e['group'])
        .toSet();

    return otherRequiredGroups.difference(selectedGroups).isEmpty;
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
    final isUnavailable = widget.meal['available'] == false;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.meal['name']),
        backgroundColor: Colors.deepOrange,
      ),
      body: Padding(
        padding: EdgeInsets.all(
          MediaQuery.of(context).size.width * 0.04,
        ),
        child: ListView(
          children: [
            Stack(
              children: [
                ColorFiltered(
                  colorFilter: isUnavailable 
                      ? const ColorFilter.mode(Colors.grey, BlendMode.saturation)
                      : const ColorFilter.mode(Colors.transparent, BlendMode.multiply),
                  child: widget.meal['image'].toString().startsWith('http')
                      ? Image.network(
                          widget.meal['image'], 
                          height: MediaQuery.of(context).size.height * 0.25,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return Container(
                              height: MediaQuery.of(context).size.height * 0.25,
                              color: Colors.grey[300],
                              child: const Icon(Icons.image_not_supported, size: 50),
                            );
                          },
                        )
                      : Image.asset(
                          widget.meal['image'], 
                          height: MediaQuery.of(context).size.height * 0.25,
                          fit: BoxFit.cover,
                        ),
                ),
                if (isUnavailable)
                  Positioned.fill(
                    child: Container(
                      color: Colors.black.withOpacity(0.6),
                      child: const Center(
                        child: Text(
                          'UNAVAILABLE',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            SizedBox(height: MediaQuery.of(context).size.height * 0.02),
            Text(
              widget.meal['name'],
              style: TextStyle(
                fontSize: MediaQuery.of(context).size.width * 0.06,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: MediaQuery.of(context).size.height * 0.01),
            if (isUnavailable)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                  color: Colors.red.shade100,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.block, color: Colors.red, size: 16),
                    SizedBox(width: 8),
                    Text(
                      'This item is currently unavailable',
                      style: TextStyle(
                        color: Colors.red,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            Text(isUnavailable ? "This item is currently unavailable." : "Customize your meal below."),
            const SizedBox(height: 17),
            for (var entry in groupedExtras.entries)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    entry.key == 'optional'
                        ? 'Optional Extras'
                        : entry.key == 'Protein'
                        ? '${entry.key} (Required - Choose at least 1)'
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
                              
                              // Special handling for Protein group - allow multiple selections
                              if (group == 'Protein') {
                                if (selected) {
                                  selectedExtras[name] = extra;
                                } else {
                                  selectedExtras.remove(name);
                                }
                              } else {
                                // For other required groups, only allow one selection
                                selectedExtras.removeWhere(
                                  (key, e) => e['group'] == group,
                                );
                                if (selected) {
                                  selectedExtras[name] = extra;
                                }
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
              onPressed: isUnavailable ? null : () {
                if (!validateRequiredExtras()) {
                  Fluttertoast.showToast(
                    msg: "⚠️ Please select required extras first",
                    toastLength: Toast.LENGTH_SHORT,
                    gravity: ToastGravity.TOP,
                    backgroundColor: Colors.red.shade600,
                    textColor: Colors.white,
                    fontSize: 14.0,
                  );
                  return;
                }

                final cartItem = {
                  'name': widget.meal['name'],
                  'image': widget.meal['image'],
                  'category': widget.meal['category'],
                  'price': basePrice, // Store base price only
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
                    msg: "✏️ ${widget.meal['name']} updated!",
                    toastLength: Toast.LENGTH_SHORT,
                    gravity: ToastGravity.TOP,
                    backgroundColor: Colors.orange.shade600,
                    textColor: Colors.white,
                    fontSize: 14.0,
                  );
                } else {
                  cartProvider.addToCart(cartItem);
                  Fluttertoast.showToast(
                    msg: "🛍️ ${widget.meal['name']} added to cart!",
                    toastLength: Toast.LENGTH_SHORT,
                    gravity: ToastGravity.TOP,
                    backgroundColor: Colors.green.shade600,
                    textColor: Colors.white,
                    fontSize: 14.0,
                  );
                }
                Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: isUnavailable ? Colors.grey : Colors.deepOrange,
                padding: const EdgeInsets.symmetric(vertical: 15),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(11),
                ),
              ),
              child: Text(
                isUnavailable 
                    ? "Unavailable" 
                    : (widget.editingIndex != null ? "Update Cart" : "Add to Cart"),
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
