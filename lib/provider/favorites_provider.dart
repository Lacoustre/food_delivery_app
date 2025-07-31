import 'dart:convert';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FavoritesProvider extends ChangeNotifier {
  final List<Map<String, dynamic>> _favorites = [];
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  StreamSubscription<QuerySnapshot>? _favoritesSubscription;

  List<Map<String, dynamic>> get favorites => List.unmodifiable(_favorites);

  FavoritesProvider() {
    _init();
  }

  Future<void> _init() async {
    await _ensureUserLoggedIn();
    await _loadFromLocal();
    _loadFavoritesRealtime();
  }

  Future<void> _ensureUserLoggedIn() async {
    if (FirebaseAuth.instance.currentUser == null) {
      await FirebaseAuth.instance.signInAnonymously();
    }
  }

  bool isFavorite(String mealId) {
    return _favorites.any((item) => item['id'] == mealId);
  }

  void addToFavorites(Map<String, dynamic> meal) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final updatedMeal = {
      ...meal,
      'favoritedBy': user.uid,
      'profilePhoto': user.photoURL ?? '',
    };

    if (!isFavorite(meal['id'])) {
      _favorites.add(updatedMeal);
      _saveToLocal();
      _addToFirebase(updatedMeal);
      notifyListeners();
    }
  }

  void removeFromFavorites(Map<String, dynamic> meal) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final index = _favorites.indexWhere((item) => item['id'] == meal['id']);
    if (index != -1) {
      _favorites.removeAt(index);
      _saveToLocal();
      _firestore
          .collection('users')
          .doc(user.uid)
          .collection('favorites')
          .doc(meal['id'])
          .delete();
      notifyListeners();
    }
  }

  void toggleFavorite(Map<String, dynamic> meal) {
    isFavorite(meal['id']) ? removeFromFavorites(meal) : addToFavorites(meal);
  }

  void clearAllFavorites() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final batch = _firestore.batch();
    final favoritesRef = _firestore
        .collection('users')
        .doc(user.uid)
        .collection('favorites');

    for (final meal in _favorites) {
      final docRef = favoritesRef.doc(meal['id']);
      batch.delete(docRef);
    }

    _favorites.clear();
    _saveToLocal();
    batch.commit();
    notifyListeners();
  }

  void reorderFavorites(int oldIndex, int newIndex) {
    if (newIndex > oldIndex) newIndex -= 1;
    final meal = _favorites.removeAt(oldIndex);
    _favorites.insert(newIndex, meal);
    _saveToLocal();
    _syncToFirebase();
    notifyListeners();
  }

  void _loadFavoritesRealtime() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    _favoritesSubscription = _firestore
        .collection('users')
        .doc(user.uid)
        .collection('favorites')
        .snapshots()
        .listen((querySnapshot) {
          _favorites
            ..clear()
            ..addAll(querySnapshot.docs.map((doc) => doc.data()));
          _saveToLocal();
          notifyListeners();
        });
  }

  Future<void> _addToFirebase(Map<String, dynamic> meal) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    await _firestore
        .collection('users')
        .doc(user.uid)
        .collection('favorites')
        .doc(meal['id'])
        .set(meal);
  }

  Future<void> _syncToFirebase() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final batch = _firestore.batch();
    final favoritesRef = _firestore
        .collection('users')
        .doc(user.uid)
        .collection('favorites');

    for (final meal in _favorites) {
      final docRef = favoritesRef.doc(meal['id']);
      batch.set(docRef, meal);
    }

    await batch.commit();
  }

  Future<void> _saveToLocal() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('favorites', jsonEncode(_favorites));
  }

  Future<void> _loadFromLocal() async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = prefs.getString('favorites');
    if (encoded != null) {
      final List decoded = jsonDecode(encoded);
      _favorites
        ..clear()
        ..addAll(decoded.map((e) => Map<String, dynamic>.from(e)));
    }
  }

  @override
  void dispose() {
    _favoritesSubscription?.cancel();
    super.dispose();
  }
}
