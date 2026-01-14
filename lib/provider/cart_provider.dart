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
    final price = _asDouble(item['price']);
    final quantity = (item['quantity'] ?? 1) as int;

    // Calculate extras price - only add if extra has a price > 0
    final extras = (item['extras'] ?? []) as List;
    final extrasPrice = extras.fold(0.0, (extrasSum, extra) {
      final extraPrice = _asDouble(extra['price'] ?? 0);
      return extraPrice > 0 ? extrasSum + extraPrice : extrasSum;
    });

    return sum + ((price + extrasPrice) * quantity);
  });

  // --- helper normalizers (used only for matching) ---
  static double _asDouble(dynamic v) {
    if (v is num) return v.toDouble();
    return double.tryParse(v?.toString() ?? '0') ?? 0.0;
  }

  static String _normNote(dynamic v) =>
      (v ?? '').toString().trim().toLowerCase();

  // Keep your original order-insensitive comparison
  bool _areExtrasEqual(List<dynamic>? extras1, List<dynamic>? extras2) {
    if (extras1 == null && extras2 == null) return true;
    if (extras1 == null || extras2 == null) return false;
    if (extras1.length != extras2.length) return false;

    // Create sets of extra names for comparison
    final set1 = extras1.map((e) => e['name'].toString()).toSet();
    final set2 = extras2.map((e) => e['name'].toString()).toSet();
    
    return set1.length == set2.length && set1.containsAll(set2);
  }

  void addToCart(Map<String, dynamic> meal) {
    // normalize inputs for matching
    final incomingName = (meal['name'] ?? '').toString();
    final incomingPrice = _asDouble(meal['price']);
    final incomingNote = _normNote(meal['instructions']);
    final incomingExtras = (meal['extras'] ?? []) as List;

    final index = _cartItems.indexWhere((item) {
      final sameName = (item['name'] ?? '').toString() == incomingName;
      final samePrice = _asDouble(item['price']) == incomingPrice;
      final sameNote = _normNote(item['instructions']) == incomingNote;
      final sameExtras = _areExtrasEqual(
        (item['extras'] ?? []) as List?,
        incomingExtras,
      );
      return sameName && samePrice && sameNote && sameExtras;
    });

    if (index != -1) {
      _cartItems[index]['quantity'] =
          (_cartItems[index]['quantity'] ?? 1) + (meal['quantity'] ?? 1);
    } else {
      _cartItems.add({
        'name': incomingName,
        'price': incomingPrice,
        'image': meal['image'],
        'category': meal['category'],
        'quantity': meal['quantity'] ?? 1,
        'extras': incomingExtras,
        // store normalized note so future comparisons match
        'instructions': incomingNote,
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
        'name': (updatedItem['name'] ?? '').toString(),
        'price': _asDouble(updatedItem['price']),
        'image': updatedItem['image'],
        'category': updatedItem['category'],
        'quantity': updatedItem['quantity'] ?? 1,
        'extras': updatedItem['extras'] ?? [],
        'instructions': _normNote(updatedItem['instructions']),
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
      final data = doc.data();
      // normalize note on load too (keeps matching consistent)
      data['instructions'] = _normNote(data['instructions']);
      _cartItems.add(data);
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
      price: CartProvider._asDouble(map['price']),
      quantity: (map['quantity'] ?? 1) as int,
      image: map['image'] ?? '',
      category: map['category'] ?? '',
      extras: map['extras'] ?? [],
      instructions: CartProvider._normNote(map['instructions']),
    );
  }
}
