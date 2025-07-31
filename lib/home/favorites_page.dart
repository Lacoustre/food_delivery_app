import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:african_cuisine/home/meal_detail_page.dart';
import 'package:african_cuisine/provider/favorites_provider.dart';
import 'package:african_cuisine/provider/cart_provider.dart';
import 'package:fluttertoast/fluttertoast.dart';

class FavoritesPage extends StatelessWidget {
  const FavoritesPage({super.key});

  // Helper to normalize price from String/int/double → double
  double _extractPrice(dynamic price) {
    if (price is double) return price;
    if (price is int) return price.toDouble();
    if (price is String) {
      final cleaned = price.replaceAll(RegExp(r'[^\d.]'), '');
      return double.tryParse(cleaned) ?? 0.0;
    }
    return 0.0;
  }

  @override
  Widget build(BuildContext context) {
    final favoritesProvider = Provider.of<FavoritesProvider>(context);
    final cartProvider = Provider.of<CartProvider>(context);
    final favorites = favoritesProvider.favorites;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Your Favorites'),
        backgroundColor: Colors.deepOrange,
        actions: [
          if (favorites.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_sweep),
              tooltip: 'Clear All',
              onPressed: () => _showClearAllDialog(context, favoritesProvider),
            ),
        ],
      ),
      body: favorites.isEmpty
          ? _buildEmptyState()
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: favorites.length,
              separatorBuilder: (context, index) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final meal = favorites[index];
                return _buildFavoriteItem(
                  context,
                  meal,
                  favoritesProvider,
                  cartProvider,
                );
              },
            ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.favorite_border, size: 64, color: Colors.grey),
          const SizedBox(height: 16),
          const Text(
            "No favorites yet!",
            style: TextStyle(fontSize: 18, color: Colors.grey),
          ),
          const SizedBox(height: 8),
          Text(
            "Tap the heart icon to add meals to favorites",
            style: TextStyle(fontSize: 14, color: Colors.grey.shade500),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildFavoriteItem(
    BuildContext context,
    Map<String, dynamic> meal,
    FavoritesProvider favoritesProvider,
    CartProvider cartProvider,
  ) {
    return Dismissible(
      key: Key(meal['id']),
      direction: DismissDirection.endToStart,
      confirmDismiss: (direction) async {
        return await _showDeleteConfirmation(context, meal['name']);
      },
      onDismissed: (direction) {
        favoritesProvider.removeFromFavorites(meal);
        _showRemovedSnackbar(context, meal['name'], favoritesProvider, meal);
      },
      background: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        decoration: BoxDecoration(
          color: Colors.red,
          borderRadius: BorderRadius.circular(12),
        ),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      child: Card(
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => MealDetailPage(meal: meal)),
            );
          },
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.asset(
                    meal['image'],
                    width: 70,
                    height: 70,
                    fit: BoxFit.cover,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        meal['name'],
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        meal['price'].toString(),
                        style: TextStyle(
                          color: Colors.deepOrange,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                Column(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.favorite, color: Colors.red),
                      onPressed: () {
                        favoritesProvider.removeFromFavorites(meal);
                        _showRemovedSnackbar(
                          context,
                          meal['name'],
                          favoritesProvider,
                          meal,
                        );
                      },
                    ),
                    const SizedBox(height: 4),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.deepOrange,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                      ),
                      onPressed: () {
                        final priceValue = _extractPrice(meal['price']);
                        cartProvider.addToCart({
                          'id': meal['id'],
                          'name': meal['name'],
                          'price': priceValue,
                          'image': meal['image'],
                          'category': meal['category'],
                          'quantity': 1,
                          'extras': [],
                          'instructions': '',
                        });
                        Fluttertoast.showToast(
                          msg: "${meal['name']} added to cart",
                          toastLength: Toast.LENGTH_SHORT,
                          gravity: ToastGravity.BOTTOM,
                        );
                      },
                      child: const Text("Add to Cart"),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<bool?> _showDeleteConfirmation(
    BuildContext context,
    String mealName,
  ) async {
    return await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove Favorite'),
        content: Text(
          'Are you sure you want to remove $mealName from favorites?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Remove', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _showRemovedSnackbar(
    BuildContext context,
    String mealName,
    FavoritesProvider provider,
    Map<String, dynamic> meal,
  ) {
    final snackBar = SnackBar(
      content: Text('$mealName removed from favorites'),
      action: SnackBarAction(
        label: 'UNDO',
        textColor: Colors.deepOrange,
        onPressed: () {
          provider.addToFavorites(meal);
        },
      ),
    );
    ScaffoldMessenger.of(context).showSnackBar(snackBar);
  }

  void _showClearAllDialog(BuildContext context, FavoritesProvider provider) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear All Favorites'),
        content: const Text(
          'Are you sure you want to remove all items from your favorites?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              provider.clearAllFavorites();
              Navigator.of(context).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('All favorites cleared')),
              );
            },
            child: const Text('Clear All', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}
