import 'dart:convert';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Favorites live in the Supabase favorites table (user_id + meal_id, the
/// same rows the webapp reads), hydrated against meals for display. Local
/// SharedPreferences copy is kept as an offline cache. Display order is
/// local-only — the table has no position column (neither did Firestore).
class FavoritesProvider extends ChangeNotifier {
  final List<Map<String, dynamic>> _favorites = [];
  final SupabaseClient _supabase = Supabase.instance.client;
  StreamSubscription<List<Map<String, dynamic>>>? _favoritesSubscription;
  StreamSubscription<AuthState>? _authSubscription;

  List<Map<String, dynamic>> get favorites => List.unmodifiable(_favorites);

  FavoritesProvider() {
    _init();
  }

  Future<void> _init() async {
    await _loadFromLocal();
    _loadFavoritesRealtime();
    // Session can arrive after startup — re-attach the stream when it does.
    _authSubscription = _supabase.auth.onAuthStateChange.listen((_) {
      _loadFavoritesRealtime();
    });
  }

  bool isFavorite(String mealId) {
    return _favorites.any((item) => item['id'] == mealId);
  }

  void addToFavorites(Map<String, dynamic> meal) {
    final user = _supabase.auth.currentUser;
    if (user == null) return;

    if (!isFavorite(meal['id'])) {
      _favorites.add(meal);
      _saveToLocal();
      _supabase
          .from('favorites')
          .upsert(
            {'user_id': user.id, 'meal_id': meal['id']},
            onConflict: 'user_id,meal_id',
          )
          .then((_) {}, onError: (e) => debugPrint('favorite add failed: $e'));
      notifyListeners();
    }
  }

  void removeFromFavorites(Map<String, dynamic> meal) {
    final user = _supabase.auth.currentUser;
    if (user == null) return;

    final index = _favorites.indexWhere((item) => item['id'] == meal['id']);
    if (index != -1) {
      _favorites.removeAt(index);
      _saveToLocal();
      _supabase
          .from('favorites')
          .delete()
          .eq('user_id', user.id)
          .eq('meal_id', meal['id'])
          .then((_) {}, onError: (e) => debugPrint('favorite remove failed: $e'));
      notifyListeners();
    }
  }

  void toggleFavorite(Map<String, dynamic> meal) {
    isFavorite(meal['id']) ? removeFromFavorites(meal) : addToFavorites(meal);
  }

  void clearAllFavorites() {
    final user = _supabase.auth.currentUser;
    if (user == null) return;

    _favorites.clear();
    _saveToLocal();
    _supabase
        .from('favorites')
        .delete()
        .eq('user_id', user.id)
        .then((_) {}, onError: (e) => debugPrint('favorites clear failed: $e'));
    notifyListeners();
  }

  void reorderFavorites(int oldIndex, int newIndex) {
    if (newIndex > oldIndex) newIndex -= 1;
    final meal = _favorites.removeAt(oldIndex);
    _favorites.insert(newIndex, meal);
    _saveToLocal();
    notifyListeners();
  }

  void _loadFavoritesRealtime() {
    final user = _supabase.auth.currentUser;
    if (user == null) return;

    _favoritesSubscription?.cancel();
    _favoritesSubscription = _supabase
        .from('favorites')
        .stream(primaryKey: ['id'])
        .eq('user_id', user.id)
        .listen((rows) async {
          final mealIds = rows.map((r) => r['meal_id'] as String).toList();
          final meals = mealIds.isEmpty
              ? <Map<String, dynamic>>[]
              : List<Map<String, dynamic>>.from(
                  await _supabase
                      .from('meals')
                      .select('id, name, price, image_url, category')
                      .inFilter('id', mealIds),
                );

          // Same display shape main_home_page builds from meals rows.
          _favorites
            ..clear()
            ..addAll(meals.map((m) => {
                  'id': m['id'],
                  'name': m['name'] ?? '',
                  'price':
                      '\$${((m['price'] ?? 0.0) as num).toStringAsFixed(2)}',
                  'image':
                      (m['image_url'] as String?) ?? 'assets/images/logo.png',
                  'category': m['category'] ?? 'Main Dishes',
                }));
          _saveToLocal();
          notifyListeners();
        });
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
    _authSubscription?.cancel();
    super.dispose();
  }
}
