import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class CartProvider extends ChangeNotifier {
  final List<Map<String, dynamic>> _cartItems = [];
  DateTime? _lastSaved;

  List<Map<String, dynamic>> get cartItems => _cartItems;

  List<CartItem> get items => _cartItems.map(CartItem.fromMap).toList();

  double get totalPrice => _cartItems.fold(0.0, (sum, item) {
    final price = item['price'] is num
        ? (item['price'] as num).toDouble()
        : double.tryParse(item['price'].toString()) ?? 0.0;
    final quantity = item['quantity'] ?? 1;
    return sum + (price * quantity);
  });

  void addToCart(Map<String, dynamic> meal) {
    final index = _cartItems.indexWhere(
      (item) =>
          item['name'] == meal['name'] &&
          item['price'] == meal['price'] &&
          item['instructions'] == meal['instructions'] &&
          _areExtrasEqual(item['extras'], meal['extras']),
    );

    if (index != -1) {
      _cartItems[index]['quantity'] =
          (_cartItems[index]['quantity'] ?? 1) + (meal['quantity'] ?? 1);
    } else {
      _cartItems.add({
        'name': meal['name'],
        'price': meal['price'],
        'image': meal['image'],
        'category': meal['category'],
        'quantity': meal['quantity'] ?? 1,
        'extras': meal['extras'] ?? [],
        'instructions': meal['instructions'] ?? '',
      });
    }

    _saveCart();
    notifyListeners();
  }

  void incrementQuantity(int index) {
    if (index >= 0 && index < _cartItems.length) {
      _cartItems[index]['quantity'] = (_cartItems[index]['quantity'] ?? 1) + 1;
      _saveCart();
      notifyListeners();
    }
  }

  void updateItem(int index, Map<String, dynamic> updatedItem) {
    if (index >= 0 && index < _cartItems.length) {
      _cartItems[index] = {
        'name': updatedItem['name'],
        'price': updatedItem['price'],
        'image': updatedItem['image'],
        'category': updatedItem['category'],
        'quantity': updatedItem['quantity'] ?? 1,
        'extras': updatedItem['extras'] ?? [],
        'instructions': updatedItem['instructions'] ?? '',
      };
      _saveCart();
      notifyListeners();
    }
  }

  void updateQuantity(int index, int newQuantity) {
    if (index >= 0 && index < _cartItems.length && newQuantity > 0) {
      _cartItems[index]['quantity'] = newQuantity;
    } else if (newQuantity <= 0) {
      removeItem(index);
      return;
    }
    _saveCart();
    notifyListeners();
  }

  void removeItem(int index) {
    if (index >= 0 && index < _cartItems.length) {
      _cartItems.removeAt(index);
      _saveCart();
      notifyListeners();
    }
  }

  Future<void> clearCart() async {
    _cartItems.clear();
    _lastSaved = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('cartItems');
    await prefs.remove('cartTimestamp');

    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final cartRef = FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('cart');
      final snapshot = await cartRef.get();
      for (var doc in snapshot.docs) {
        await doc.reference.delete();
      }
    }

    notifyListeners();
  }

  bool _areExtrasEqual(List<dynamic>? extras1, List<dynamic>? extras2) {
    if (extras1 == null && extras2 == null) return true;
    if (extras1 == null || extras2 == null) return false;
    if (extras1.length != extras2.length) return false;

    final sorted1 = [...extras1]
      ..sort((a, b) => a['name'].compareTo(b['name']));
    final sorted2 = [...extras2]
      ..sort((a, b) => a['name'].compareTo(b['name']));

    for (int i = 0; i < sorted1.length; i++) {
      if (sorted1[i]['name'] != sorted2[i]['name'] ||
          sorted1[i]['price'] != sorted2[i]['price']) {
        return false;
      }
    }

    return true;
  }

  Future<void> _saveCart() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('cartItems', jsonEncode(_cartItems));
    _lastSaved = DateTime.now();
    await prefs.setString('cartTimestamp', _lastSaved!.toIso8601String());

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final cartRef = FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('cart');

    final existingDocs = await cartRef.get();
    for (var doc in existingDocs.docs) {
      await doc.reference.delete();
    }

    for (var item in _cartItems) {
      await cartRef.add(item);
    }
  }

  Future<void> loadCart() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final cartRef = FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('cart');

    final snapshot = await cartRef.get();

    _cartItems.clear();
    for (var doc in snapshot.docs) {
      _cartItems.add(doc.data());
    }

    notifyListeners();
  }

  bool validateAllRequiredExtras(
    Map<String, List<Map<String, dynamic>>> mealExtras,
  ) {
    for (var item in _cartItems) {
      final mealName = item['name'];
      final availableExtras = mealExtras[mealName] ?? [];
      final selectedExtras = item['extras'] ?? [];

      final requiredGroups = availableExtras
          .where((e) => e['required'] == true && e.containsKey('group'))
          .map((e) => e['group'])
          .toSet();

      final selectedGroups = selectedExtras
          .where((e) => e.containsKey('group'))
          .map((e) => e['group'])
          .toSet();

      if (!selectedGroups.containsAll(requiredGroups)) {
        return false;
      }
    }
    return true;
  }
}

class CartItem {
  final String name;
  final double price;
  final int quantity;
  final String image;
  final String category;
  final List<dynamic> extras;
  final String instructions;

  CartItem({
    required this.name,
    required this.price,
    required this.quantity,
    required this.image,
    required this.category,
    required this.extras,
    required this.instructions,
  });

  factory CartItem.fromMap(Map<String, dynamic> map) {
    return CartItem(
      name: map['name'] ?? '',
      price: map['price'] is num
          ? (map['price'] as num).toDouble()
          : double.tryParse(map['price'].toString()) ?? 0.0,
      quantity: map['quantity'] ?? 1,
      image: map['image'] ?? '',
      category: map['category'] ?? '',
      extras: map['extras'] ?? [],
      instructions: map['instructions'] ?? '',
    );
  }
}
