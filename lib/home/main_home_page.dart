import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:african_cuisine/home/meal_detail_page.dart';
import 'package:african_cuisine/home/cart_page.dart';
import 'package:african_cuisine/home/favorites_page.dart';
import 'package:african_cuisine/home/profile_page.dart';
import 'package:african_cuisine/notification/notification_page.dart';
import 'package:african_cuisine/provider/cart_provider.dart';
import 'package:african_cuisine/provider/favorites_provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:african_cuisine/home/location_selector_bar.dart';
import 'package:african_cuisine/delivery/delivery_fee_provider.dart';
import 'package:african_cuisine/provider/notification_provider.dart';

class MainFoodPage extends StatefulWidget {
  const MainFoodPage({super.key});

  @override
  State<MainFoodPage> createState() => _MainFoodPageState();
}

class _MainFoodPageState extends State<MainFoodPage> {
  static const double _initialZoom = 14.0;
  static const double _userLocationZoom = 16.0;
  static const CameraPosition _defaultLocation = CameraPosition(
    target: LatLng(41.6032, -73.0877),
    zoom: 10.0,
  );

  final List<Map<String, dynamic>> categories = [
    {'name': 'Main Dishes', 'icon': Icons.restaurant},
    {'name': 'Side Dishes', 'icon': Icons.fastfood},
    {'name': 'Pastries', 'icon': Icons.icecream},
    {'name': 'Drinks', 'icon': Icons.local_drink},
  ];

  final List<Map<String, dynamic>> meals = [
    {
      'id': 'waakye',
      'name': 'Waakye',
      'price': '\$25',
      'image': 'assets/images/waakye.png',
      'category': 'Main Dishes',
    },
    {
      'id': 'beans_plantain',
      'name': 'Beans & Plantain',
      'price': '\$20',
      'image': 'assets/images/beans_plantain.png',
      'category': 'Main Dishes',
    },
    {
      'id': 'jollof',
      'name': 'Jollof Rice',
      'price': '\$22',
      'image': 'assets/images/jollof.png',
      'category': 'Main Dishes',
    },
    {
      'id': 'banku_okro',
      'name': 'Banku and Okro Stew',
      'price': '\$18',
      'image': 'assets/images/banku.png',
      'category': 'Main Dishes',
    },
    {
      'id': 'rice_ball',
      'name': 'Rice Ball & Soup',
      'price': '\$17',
      'image': 'assets/images/rice_ball.png',
      'category': 'Main Dishes',
    },
    {
      'id': 'fried_rice',
      'name': 'Fried Rice',
      'price': '\$15',
      'image': 'assets/images/fried_rice.png',
      'category': 'Main Dishes',
    },
    {
      'id': 'fried_yam',
      'name': 'Fried Yam',
      'price': '\$12',
      'image': 'assets/images/fried_yam.png',
      'category': 'Main Dishes',
    },
    {
      'id': 'boiled_yam',
      'name': 'Boiled Yam',
      'price': '\$8',
      'image': 'assets/images/boiled_yam.png',
      'category': 'Main Dishes',
    },
    {
      'id': 'plantain_kontomire',
      'name': 'Plantain & Kontomire',
      'price': '\$10',
      'image': 'assets/images/plantain_kontomire.png',
      'category': 'Main Dishes',
    },
    {
      'id': 'shito',
      'name': 'Shito',
      'price': '\$5',
      'image': 'assets/images/shito.png',
      'category': 'Side Dishes',
    },
  ];

  final TextEditingController _searchController = TextEditingController();
  String _greeting = '';
  String _location = 'Fetching location...';
  Position? _currentPosition;
  int _selectedIndex = 0;
  String _selectedCategory = 'Main Dishes';
  GoogleMapController? _mapController;
  Set<Marker> _markers = {};
  Set<Circle> _circles = {};
  bool _isManualLocation = false;
  bool _isRefreshingLocation = false;
  final LocationAccuracy _currentAccuracy = LocationAccuracy.high;

  @override
  void initState() {
    super.initState();
    _updateGreeting();
    _getCurrentLocation();
    _reloadUser();
    Timer.periodic(const Duration(minutes: 1), (_) => _updateGreeting());
  }

  @override
  void dispose() {
    _mapController?.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _reloadUser() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      await user.reload();
      setState(() {});
    }
  }

  void _updateGreeting() {
    final hour = DateTime.now().hour;
    final greeting = hour < 12
        ? 'Good Morning'
        : (hour < 17 ? 'Good Afternoon' : 'Good Evening');
    if (mounted) setState(() => _greeting = greeting);
  }

  String _getUserDisplayName() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return 'User';

    if (user.displayName != null && user.displayName!.isNotEmpty) {
      return user.displayName!.split(' ').first;
    }

    if (user.email != null && user.email!.isNotEmpty) {
      final localPart = user.email!.split('@').first;
      return localPart.split(RegExp(r'[._]')).first.capitalize();
    }

    return 'User';
  }

  Future<void> _getCurrentLocation() async {
    setState(() => _isRefreshingLocation = true);
    try {
      await _checkLocationPermission();
    } catch (e) {
      _handleLocationError(e);
    } finally {
      if (mounted) setState(() => _isRefreshingLocation = false);
    }
  }

  Future<void> _checkLocationPermission() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      _showLocationServiceDisabledAlert();
      return;
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        _showLocationPermissionDeniedAlert();
        return;
      }
    }
    if (permission == LocationPermission.deniedForever) {
      _showLocationPermissionPermanentlyDeniedAlert();
      return;
    }

    await _getCurrentPosition();
  }

  Future<void> _getCurrentPosition() async {
    final pos = await Geolocator.getCurrentPosition(
      desiredAccuracy: _currentAccuracy,
    ).timeout(const Duration(seconds: 15));
    final places = await placemarkFromCoordinates(
      pos.latitude,
      pos.longitude,
    ).timeout(const Duration(seconds: 5));

    if (!mounted) return;
    setState(() {
      _currentPosition = pos;
      _isManualLocation = false;
      _location = places.isNotEmpty
          ? '${places.first.street}, ${places.first.locality}'
          : '${pos.latitude.toStringAsFixed(4)}, ${pos.longitude.toStringAsFixed(4)}';
    });

    _updateMarkers();
    _updateLocationCircle();
    if (_mapController != null) _centerMapOnUser();

    // Update delivery fee with provider
    final deliveryProvider = Provider.of<DeliveryFeeProvider>(
      context,
      listen: false,
    );
    await deliveryProvider.updateDeliveryFee(pos);
  }

  void _updateMarkers() {
    if (_currentPosition == null) return;
    _markers = {
      Marker(
        markerId: const MarkerId('user'),
        position: LatLng(
          _currentPosition!.latitude,
          _currentPosition!.longitude,
        ),
        infoWindow: InfoWindow(title: _location),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange),
      ),
    };
  }

  void _updateLocationCircle() {
    if (_currentPosition == null) return;
    _circles = {
      Circle(
        circleId: const CircleId('accuracy'),
        center: LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
        radius: _currentPosition!.accuracy,
        fillColor: Colors.blue.withValues(alpha: 0.2),
        strokeColor: Colors.blue,
        strokeWidth: 1,
      ),
    };
  }

  Future<void> _centerMapOnUser() async {
    if (_currentPosition == null || _mapController == null) return;
    await _mapController!.animateCamera(
      CameraUpdate.newLatLngZoom(
        LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
        _userLocationZoom,
      ),
    );
  }

  void _showLocationServiceDisabledAlert() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Location Services Disabled'),
        content: const Text(
          'Please enable location services to use this feature.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Geolocator.openLocationSettings();
            },
            child: const Text('Open Settings'),
          ),
        ],
      ),
    );
  }

  void _showLocationPermissionDeniedAlert() {
    setState(() {
      _location = 'Location permission denied';
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Location permission is required for accurate delivery'),
      ),
    );
  }

  void _showLocationPermissionPermanentlyDeniedAlert() {
    setState(() {
      _location = 'Location permission permanently denied';
    });
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Location Permission Required'),
        content: const Text(
          'Please enable location permissions in app settings to use this feature.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Geolocator.openAppSettings();
            },
            child: const Text('Open Settings'),
          ),
        ],
      ),
    );
  }

  void _handleLocationError(dynamic e) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('Location error: ${e.toString()}')));
  }

  @override
  Widget build(BuildContext context) {
    final cartProvider = Provider.of<CartProvider>(context);
    final favoritesProvider = Provider.of<FavoritesProvider>(context);
    final query = _searchController.text.toLowerCase().trim();
    final filteredMeals = meals.where((m) {
      return m['category'] == _selectedCategory &&
          (query.isEmpty ||
              (m['name'] as String).toLowerCase().contains(query));
    }).toList();
    final displayName = _getUserDisplayName();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Taste of African Cuisine'),
        backgroundColor: Colors.deepOrange,
        actions: [
          Consumer<NotificationProvider>(
            builder: (context, notifProvider, _) => Stack(
              alignment: Alignment.center,
              children: [
                IconButton(
                  icon: const Icon(Icons.notifications),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const NotificationPage(),
                      ),
                    );
                  },
                ),
                if (notifProvider.unreadCount > 0)
                  Positioned(
                    right: 10,
                    top: 12,
                    child: TweenAnimationBuilder<double>(
                      tween: Tween(begin: 1.0, end: 1.2),
                      duration: const Duration(milliseconds: 500),
                      curve: Curves.easeInOut,
                      builder: (context, scale, child) {
                        return Transform.scale(scale: scale, child: child);
                      },
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(
                          color: Colors.red,
                          shape: BoxShape.circle,
                        ),
                        constraints: const BoxConstraints(
                          minWidth: 16,
                          minHeight: 16,
                        ),
                        child: Text(
                          '${notifProvider.unreadCount}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),

      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        selectedItemColor: Colors.deepOrange,
        unselectedItemColor: Colors.grey[600],
        backgroundColor: Colors.white,
        type: BottomNavigationBarType.fixed,
        elevation: 10,
        selectedLabelStyle: const TextStyle(fontWeight: FontWeight.bold),
        unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w500),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(
            icon: Icon(Icons.shopping_cart),
            label: 'Cart',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.favorite),
            label: 'Favorites',
          ),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
        ],
        onTap: (index) {
          setState(() => _selectedIndex = index);
          if (index == 1) {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const CartPage()),
            );
          } else if (index == 2) {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const FavoritesPage()),
            );
          } else if (index == 3) {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ProfilePage()),
            );
          }
        },
      ),

      body: SafeArea(
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$_greeting, $displayName 👋',
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 40,
                    child: LocationSelectorBar(
                      currentLocation: _location,
                      isManual: _isManualLocation,
                      onLocationUpdated:
                          (newLocation, isManual, position) async {
                            setState(() {
                              _location = newLocation;
                              _isManualLocation = isManual;
                              if (position != null) {
                                _currentPosition = position;
                                _updateMarkers();
                                _updateLocationCircle();
                                if (_mapController != null) {
                                  _centerMapOnUser();
                                }
                              }
                            });

                            if (position != null) {
                              final deliveryProvider =
                                  Provider.of<DeliveryFeeProvider>(
                                    context,
                                    listen: false,
                                  );
                              await deliveryProvider.updateDeliveryFee(
                                position,
                              );
                            }

                            if (!isManual) {
                              WidgetsBinding.instance.addPostFrameCallback((_) {
                                if (mounted) {
                                  _getCurrentLocation();
                                }
                              });
                            }
                          },
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (_currentPosition != null || _isManualLocation)
                    SizedBox(
                      height: 80,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Stack(
                          children: [
                            GoogleMap(
                              initialCameraPosition: _currentPosition != null
                                  ? CameraPosition(
                                      target: LatLng(
                                        _currentPosition!.latitude,
                                        _currentPosition!.longitude,
                                      ),
                                      zoom: _initialZoom,
                                    )
                                  : _defaultLocation,
                              myLocationEnabled: !_isManualLocation,
                              myLocationButtonEnabled: false,
                              zoomControlsEnabled: false,
                              markers: _markers,
                              circles: _circles,
                              onMapCreated: (controller) {
                                _mapController = controller;
                                if (_currentPosition != null)
                                  _centerMapOnUser();
                              },
                            ),
                            if (!_isManualLocation)
                              Positioned(
                                bottom: 4,
                                right: 4,
                                child: FloatingActionButton.small(
                                  onPressed: _isRefreshingLocation
                                      ? null
                                      : _getCurrentLocation,
                                  backgroundColor: Colors.white,
                                  child: _isRefreshingLocation
                                      ? const SizedBox(
                                          width: 12,
                                          height: 12,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                          ),
                                        )
                                      : const Icon(
                                          Icons.refresh,
                                          size: 16,
                                          color: Colors.deepOrange,
                                        ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Search for meals...',
                      prefixIcon: const Icon(Icons.search),
                      filled: true,
                      fillColor: Colors.grey[200],
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 40,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: categories.length,
                      itemBuilder: (_, i) {
                        final cat = categories[i];
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ChoiceChip(
                            label: Text(cat['name']),
                            avatar: Icon(cat['icon'], size: 16),
                            selected: _selectedCategory == cat['name'],
                            onSelected: (_) =>
                                setState(() => _selectedCategory = cat['name']),
                            selectedColor: Colors.deepOrange,
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),

            Expanded(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: filteredMeals.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.search_off,
                              size: 50,
                              color: Colors.grey[400],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'No meals found',
                              style: TextStyle(
                                fontSize: 18,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      )
                    : GridView.builder(
                        padding: EdgeInsets.only(
                          bottom: MediaQuery.of(context).padding.bottom + 16,
                        ),
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 2,
                              childAspectRatio: 0.88,
                              mainAxisSpacing: 12,
                              crossAxisSpacing: 12,
                            ),
                        itemCount: filteredMeals.length,
                        itemBuilder: (_, idx) {
                          final m = filteredMeals[idx];
                          final cleanPrice =
                              double.tryParse(
                                (m['price'] as String).replaceAll(
                                  RegExp(r'[^\d.]'),
                                  '',
                                ),
                              ) ??
                              0.0;
                          final mealMap = {
                            'id': m['id'],
                            'name': m['name'],
                            'price': cleanPrice,
                            'image': m['image'],
                            'category': m['category'],
                          };
                          final fav = favoritesProvider.isFavorite(m['id']);

                          return Card(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: InkWell(
                              onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => MealDetailPage(meal: mealMap),
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Stack(
                                    children: [
                                      ClipRRect(
                                        borderRadius:
                                            const BorderRadius.vertical(
                                              top: Radius.circular(12),
                                            ),
                                        child: Image.asset(
                                          m['image'],
                                          height: 100,
                                          width: double.infinity,
                                          fit: BoxFit.cover,
                                        ),
                                      ),
                                      Positioned(
                                        top: 4,
                                        right: 4,
                                        child: IconButton(
                                          icon: Icon(
                                            fav
                                                ? Icons.favorite
                                                : Icons.favorite_border,
                                            color: fav
                                                ? Colors.red
                                                : Colors.white,
                                          ),
                                          onPressed: () {
                                            favoritesProvider.toggleFavorite(
                                              mealMap,
                                            );
                                            Fluttertoast.showToast(
                                              msg: fav
                                                  ? "${m['name']} removed from favorites"
                                                  : "${m['name']} added to favorites",
                                            );
                                          },
                                        ),
                                      ),
                                    ],
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.all(8.0),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          m['name'],
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        const SizedBox(height: 4),
                                        Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.spaceBetween,
                                          children: [
                                            Text(
                                              m['price'],
                                              style: const TextStyle(
                                                color: Colors.deepOrange,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                            IconButton(
                                              icon: const Icon(
                                                Icons.add_circle,
                                              ),
                                              color: Colors.deepOrange,
                                              iconSize: 20,
                                              onPressed: () {
                                                final existingIndex =
                                                    cartProvider.cartItems
                                                        .indexWhere(
                                                          (item) =>
                                                              item['id'] ==
                                                                  m['id'] &&
                                                              (item['extras'] ==
                                                                      null ||
                                                                  item['extras']
                                                                      .isEmpty),
                                                        );

                                                if (existingIndex != -1) {
                                                  cartProvider.incrementQuantity(
                                                    existingIndex,
                                                  ); // You must define this in CartProvider
                                                  Fluttertoast.showToast(
                                                    msg:
                                                        "${m['name']} quantity increased",
                                                  );
                                                } else {
                                                  cartProvider.addToCart({
                                                    'id': m['id'],
                                                    'name': m['name'],
                                                    'price': cleanPrice,
                                                    'image': m['image'],
                                                    'category': m['category'],
                                                    'quantity': 1,
                                                    'extras':
                                                        [], // default to empty
                                                  });
                                                  Fluttertoast.showToast(
                                                    msg:
                                                        "${m['name']} added to cart",
                                                  );
                                                }
                                              },
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
            ),
          ],
        ),
      ),
    );
  }
}

extension StringCasingExtension on String {
  String capitalize() {
    if (isEmpty) return '';
    return '${this[0].toUpperCase()}${substring(1)}';
  }
}
