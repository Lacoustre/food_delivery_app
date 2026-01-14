import 'dart:convert';
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
import 'package:african_cuisine/delivery/delivery_fee_provider.dart';
import 'package:african_cuisine/provider/notification_provider.dart';
import 'package:african_cuisine/home/map_picker_page.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_google_places/flutter_google_places.dart';
import 'package:google_maps_webservice/places.dart';
import 'package:african_cuisine/widgets/review_reminder_banner.dart';
import 'package:african_cuisine/config/env_config.dart';

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

  List<Map<String, dynamic>> meals = [];
  List<Map<String, dynamic>> popularMeals = [];
  bool _mealsLoading = true;
  bool _popularLoading = true;

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
  final LocationAccuracy _currentAccuracy = LocationAccuracy.high;
  bool _isRestaurantOpen = true;
  bool _showClosedDialog = true;
  StreamSubscription<DocumentSnapshot>? _restaurantStatusSubscription;

  @override
  void initState() {
    super.initState();
    _updateGreeting();
    _getCurrentLocation();
    _reloadUser();
    _listenToRestaurantStatus();
    _loadMealsFromFirebase();
    _loadPopularMeals();
    Timer.periodic(const Duration(minutes: 1), (_) => _updateGreeting());
  }

  @override
  void dispose() {
    _mapController?.dispose();
    _searchController.dispose();
    _restaurantStatusSubscription?.cancel();
    super.dispose();
  }

  void _listenToRestaurantStatus() {
    _restaurantStatusSubscription = FirebaseFirestore.instance
        .collection('settings')
        .doc('restaurant')
        .snapshots()
        .listen((snapshot) {
          if (snapshot.exists && mounted) {
            setState(() {
              _isRestaurantOpen = snapshot.data()?['isOpen'] ?? true;
            });
          }
        });
  }

  void _loadMealsFromFirebase() {
    FirebaseFirestore.instance
        .collection('meals')
        .where('active', isEqualTo: true)
        .snapshots()
        .listen((snapshot) {
      if (mounted) {
        setState(() {
          meals = snapshot.docs.map((doc) {
            final data = doc.data();
            var imageUrl = data['imageUrl'] ?? 'assets/images/logo.png';
            imageUrl = imageUrl.replaceAll('&amp;', '&');
            final available = data['available'] ?? true;
            return {
              'id': doc.id,
              'name': data['name'] ?? 'Unknown',
              'price': '\$${(data['price'] ?? 0.0).toStringAsFixed(2)}',
              'image': imageUrl,
              'category': data['category'] ?? 'Main Dishes',
              'available': available,
            };
          }).toList();
          _mealsLoading = false;
        });
      }
    });
  }

  void _loadPopularMeals() async {
    try {
      final ordersSnapshot = await FirebaseFirestore.instance
          .collection('orders')
          .limit(100)
          .get();
      
      Map<String, Map<String, dynamic>> mealStats = {};
      
      for (var doc in ordersSnapshot.docs) {
        final order = doc.data();
        if (order['items'] != null) {
          for (var item in order['items']) {
            final mealName = item['name'] ?? '';
            final quantity = item['quantity'] ?? 1;
            
            if (mealStats.containsKey(mealName)) {
              mealStats[mealName]!['count'] = (mealStats[mealName]!['count'] ?? 0) + quantity;
            } else {
              mealStats[mealName] = {
                'name': mealName,
                'count': quantity,
              };
            }
          }
        }
      }
      
      // Get top 5 most ordered meals
      final sortedMeals = mealStats.values.toList()
        ..sort((a, b) => (b['count'] ?? 0).compareTo(a['count'] ?? 0));
      
      final topMealNames = sortedMeals.take(5).map((m) => m['name']).toList();
      
      // Get meal details for popular items
      if (topMealNames.isNotEmpty) {
        final mealsSnapshot = await FirebaseFirestore.instance
            .collection('meals')
            .where('active', isEqualTo: true)
            .where('name', whereIn: topMealNames)
            .get();
        
        if (mounted) {
          setState(() {
            popularMeals = mealsSnapshot.docs.map((doc) {
              final data = doc.data();
              var imageUrl = data['imageUrl'] ?? 'assets/images/logo.png';
              imageUrl = imageUrl.replaceAll('&amp;', '&');
              return {
                'id': doc.id,
                'name': data['name'] ?? 'Unknown',
                'price': '\$${(data['price'] ?? 0.0).toStringAsFixed(2)}',
                'image': imageUrl,
                'category': data['category'] ?? 'Main Dishes',
                'available': data['available'] ?? true,
                'orderCount': mealStats[data['name']]?['count'] ?? 0,
              };
            }).toList();
            
            // Sort by order count
            popularMeals.sort((a, b) => (b['orderCount'] ?? 0).compareTo(a['orderCount'] ?? 0));
            _popularLoading = false;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _popularLoading = false;
          });
        }
      }
    } catch (e) {
      print('Error loading popular meals: $e');
      if (mounted) {
        setState(() {
          _popularLoading = false;
        });
      }
    }
  }

  String _mapCategory(String mealName) {
    final name = mealName.toLowerCase();
    if (name.contains('sprite') || name.contains('coke') || name.contains('fanta') || 
        name.contains('water') || name.contains('juice') || name.contains('malt') || 
        name.contains('sobolo')) {
      return 'Drinks';
    } else if (name.contains('shito')) {
      return 'Side Dishes';
    } else {
      return 'Main Dishes';
    }
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

  Widget _buildUserGreeting() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return Text(
        '$_greeting, User 👋',
        style: const TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.bold,
        ),
      );
    }

    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance.collection('users').doc(user.uid).get(),
      builder: (context, snapshot) {
        String displayName = 'User';
        
        if (snapshot.hasData && snapshot.data!.exists) {
          final userData = snapshot.data!.data() as Map<String, dynamic>;
          displayName = userData['name']?.toString().split(' ').first ?? 'User';
        } else if (user.displayName != null && user.displayName!.isNotEmpty) {
          displayName = user.displayName!.split(' ').first;
        } else if (user.email != null && user.email!.isNotEmpty) {
          final localPart = user.email!.split('@').first;
          displayName = localPart.split(RegExp(r'[._]')).first.capitalize();
        }
        
        return Text(
          '$_greeting, $displayName 👋',
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        );
      },
    );
  }

  Future<void> _getCurrentLocation() async {
    try {
      await _checkLocationPermission();
    } catch (e) {
      _handleLocationError(e);
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

  void _showLocationDialog() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Colors.white, Colors.orange.shade50],
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade100,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      Icons.location_on,
                      color: Colors.orange.shade700,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Set Location',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close, color: Colors.grey, size: 20),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextField(
                controller: controller,
                decoration: InputDecoration(
                  hintText: 'Type your address...',
                  prefixIcon: Icon(Icons.search, color: Colors.orange.shade600),
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.orange.shade200),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: Colors.orange.shade400,
                      width: 2,
                    ),
                  ),
                ),
                autofocus: true,
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () async {
                        Navigator.pop(context);
                        await _showPlacesAutocomplete();
                      },
                      icon: const Icon(Icons.search, size: 18),
                      label: const Text('Search'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.teal.shade400,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () async {
                        Navigator.pop(context);
                        final pickedLocation = await Navigator.push<LatLng>(
                          context,
                          MaterialPageRoute(
                            builder: (_) => MapPickerPage(
                              initialPosition: _currentPosition != null
                                  ? LatLng(
                                      _currentPosition!.latitude,
                                      _currentPosition!.longitude,
                                    )
                                  : null,
                            ),
                          ),
                        );
                        if (pickedLocation != null) {
                          await _updateLocationFromMap(pickedLocation);
                        }
                      },
                      icon: const Icon(Icons.map, size: 18),
                      label: const Text('Map'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue.shade400,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    _getCurrentLocation();
                  },
                  icon: const Icon(Icons.my_location, size: 18),
                  label: const Text('Use Current Location'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange.shade500,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text(
                        'Cancel',
                        style: TextStyle(color: Colors.grey.shade600),
                      ),
                    ),
                  ),
                  Expanded(
                    child: TextButton(
                      onPressed: () async {
                        final text = controller.text.trim();
                        if (text.isNotEmpty) {
                          Navigator.pop(context);
                          await _updateLocationFromAddress(text);
                        }
                      },
                      child: Text(
                        'Save',
                        style: TextStyle(
                          color: Colors.orange.shade700,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showPlacesAutocomplete() async {
    try {
      final prediction = await PlacesAutocomplete.show(
        context: context,
        apiKey: EnvConfig.googleMapsApiKey,
        mode: Mode.overlay,
        language: 'en',
        components: [Component(Component.country, 'us')],
        types: ['address'],
        strictbounds: false,
      );

      if (prediction != null && mounted) {
        final places = GoogleMapsPlaces(
          apiKey: EnvConfig.googleMapsApiKey,
        );

        final detail = await places.getDetailsByPlaceId(prediction.placeId!);
        final geometry = detail.result.geometry!;
        final location = geometry.location;

        final position = Position(
          latitude: location.lat,
          longitude: location.lng,
          timestamp: DateTime.now(),
          accuracy: 100.0,
          altitude: 0.0,
          altitudeAccuracy: 0.0,
          heading: 0.0,
          headingAccuracy: 0.0,
          speed: 0.0,
          speedAccuracy: 0.0,
        );

        if (mounted) {
          setState(() {
            _currentPosition = position;
            _isManualLocation = true;
            _location = prediction.description ?? 'Selected location';
            _updateMarkers();
            _updateLocationCircle();
          });

          if (_mapController != null) {
            await _mapController!.animateCamera(
              CameraUpdate.newLatLngZoom(
                LatLng(location.lat, location.lng),
                _userLocationZoom,
              ),
            );
          }

          final deliveryProvider = Provider.of<DeliveryFeeProvider>(
            context,
            listen: false,
          );
          await deliveryProvider.updateDeliveryFee(position);
        }
      }
    } catch (e) {
      debugPrint('Places autocomplete error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error searching for places')),
        );
      }
    }
  }

  Future<void> _updateLocationFromMap(LatLng pickedLocation) async {
    try {
      final places = await placemarkFromCoordinates(
        pickedLocation.latitude,
        pickedLocation.longitude,
      );

      final position = Position(
        latitude: pickedLocation.latitude,
        longitude: pickedLocation.longitude,
        timestamp: DateTime.now(),
        accuracy: 100.0,
        altitude: 0.0,
        altitudeAccuracy: 0.0,
        heading: 0.0,
        headingAccuracy: 0.0,
        speed: 0.0,
        speedAccuracy: 0.0,
      );

      setState(() {
        _currentPosition = position;
        _isManualLocation = true;
        _location = places.isNotEmpty
            ? '${places.first.street}, ${places.first.locality}'
            : '${pickedLocation.latitude.toStringAsFixed(4)}, ${pickedLocation.longitude.toStringAsFixed(4)}';
        _updateMarkers();
        _updateLocationCircle();
      });

      if (_mapController != null) {
        await _mapController!.animateCamera(
          CameraUpdate.newLatLngZoom(pickedLocation, _userLocationZoom),
        );
      }

      final deliveryProvider = Provider.of<DeliveryFeeProvider>(
        context,
        listen: false,
      );
      await deliveryProvider.updateDeliveryFee(position);
    } catch (e) {
      debugPrint('Error updating location from map: $e');
    }
  }

  Future<void> _updateLocationFromAddress(String newLocation) async {
    setState(() {
      _location = newLocation;
      _isManualLocation = true;
      _currentPosition = null;
    });

    try {
      final locations = await locationFromAddress(newLocation);
      if (locations.isNotEmpty) {
        final position = Position(
          latitude: locations.first.latitude,
          longitude: locations.first.longitude,
          timestamp: DateTime.now(),
          accuracy: 100.0,
          altitude: 0.0,
          altitudeAccuracy: 0.0,
          heading: 0.0,
          headingAccuracy: 0.0,
          speed: 0.0,
          speedAccuracy: 0.0,
        );

        setState(() {
          _currentPosition = position;
          _updateMarkers();
          _updateLocationCircle();
        });

        if (_mapController != null) {
          await _mapController!.animateCamera(
            CameraUpdate.newLatLngZoom(
              LatLng(position.latitude, position.longitude),
              _userLocationZoom,
            ),
          );
        }

        final deliveryProvider = Provider.of<DeliveryFeeProvider>(
          context,
          listen: false,
        );
        await deliveryProvider.updateDeliveryFee(position);
      }
    } catch (e) {
      debugPrint('Geocoding failed: $e');
    }
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
        child: Stack(
          children: [
            Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildUserGreeting(),
                      const SizedBox(height: 8),
                      InkWell(
                        onTap: () => _showLocationDialog(),
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          height: 36,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.grey[300]!),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.location_on,
                                size: 18,
                                color: Colors.deepOrange,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _location,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    color: Colors.black87,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              Icon(
                                Icons.edit,
                                size: 16,
                                color: Colors.grey[600],
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      if (_currentPosition != null || _isManualLocation)
                        SizedBox(
                          height: 60,
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: GoogleMap(
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
                                if (_currentPosition != null) {
                                  _centerMapOnUser();
                                }
                              },
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
                        height: 35,
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
                                onSelected: (_) => setState(
                                  () => _selectedCategory = cat['name'],
                                ),
                                selectedColor: Colors.deepOrange,
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
                const ReviewReminderBanner(),
                
                // Popular Items Section
                if (!_popularLoading && popularMeals.isNotEmpty)
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.trending_up, color: Colors.deepOrange, size: 20),
                            const SizedBox(width: 8),
                            const Text(
                              'Popular Items',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          height: 120,
                          child: ListView.builder(
                            scrollDirection: Axis.horizontal,
                            itemCount: popularMeals.length,
                            itemBuilder: (context, index) {
                              final meal = popularMeals[index];
                              final cleanPrice = double.tryParse(
                                (meal['price'] as String).replaceAll(RegExp(r'[^\d.]'), ''),
                              ) ?? 0.0;
                              final mealMap = {
                                'id': meal['id'],
                                'name': meal['name'],
                                'price': cleanPrice,
                                'image': meal['image'],
                                'category': meal['category'],
                              };
                              final isUnavailable = meal['available'] == false;
                              
                              return Container(
                                width: 140,
                                margin: const EdgeInsets.only(right: 12),
                                child: Card(
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: InkWell(
                                    onTap: isUnavailable ? null : () => Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => MealDetailPage(meal: mealMap),
                                      ),
                                    ),
                                    borderRadius: BorderRadius.circular(12),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Stack(
                                          children: [
                                            ClipRRect(
                                              borderRadius: const BorderRadius.vertical(
                                                top: Radius.circular(12),
                                              ),
                                              child: ColorFiltered(
                                                colorFilter: isUnavailable 
                                                    ? const ColorFilter.mode(Colors.grey, BlendMode.saturation)
                                                    : const ColorFilter.mode(Colors.transparent, BlendMode.multiply),
                                                child: (meal['image'].startsWith('http') || meal['image'].startsWith('https'))
                                                    ? Image.network(
                                                        meal['image'],
                                                        height: 60,
                                                        width: double.infinity,
                                                        fit: BoxFit.cover,
                                                        errorBuilder: (context, error, stackTrace) {
                                                          return Image.asset(
                                                            'assets/images/logo.png',
                                                            height: 60,
                                                            width: double.infinity,
                                                            fit: BoxFit.cover,
                                                          );
                                                        },
                                                      )
                                                    : Image.asset(
                                                        meal['image'],
                                                        height: 60,
                                                        width: double.infinity,
                                                        fit: BoxFit.cover,
                                                        errorBuilder: (context, error, stackTrace) {
                                                          return Image.asset(
                                                            'assets/images/logo.png',
                                                            height: 60,
                                                            width: double.infinity,
                                                            fit: BoxFit.cover,
                                                          );
                                                        },
                                                      ),
                                              ),
                                            ),
                                            Positioned(
                                              top: 4,
                                              left: 4,
                                              child: Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                decoration: BoxDecoration(
                                                  color: Colors.deepOrange,
                                                  borderRadius: BorderRadius.circular(8),
                                                ),
                                                child: Text(
                                                  '#${index + 1}',
                                                  style: const TextStyle(
                                                    color: Colors.white,
                                                    fontSize: 10,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                        Padding(
                                          padding: const EdgeInsets.all(8.0),
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                meal['name'],
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 12,
                                                ),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                              const SizedBox(height: 2),
                                              Row(
                                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                children: [
                                                  Text(
                                                    meal['price'],
                                                    style: const TextStyle(
                                                      color: Colors.deepOrange,
                                                      fontWeight: FontWeight.bold,
                                                      fontSize: 11,
                                                    ),
                                                  ),
                                                  Text(
                                                    '${meal['orderCount']} orders',
                                                    style: TextStyle(
                                                      color: Colors.grey[600],
                                                      fontSize: 9,
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
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: _mealsLoading
                        ? const Center(
                            child: CircularProgressIndicator(
                              color: Colors.deepOrange,
                            ),
                          )
                        : filteredMeals.isEmpty
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
                              bottom: 80,
                              top: popularMeals.isNotEmpty ? 8 : 0,
                            ),
                            gridDelegate:
                                const SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: 2,
                                  childAspectRatio: 1.0,
                                  mainAxisSpacing: 8,
                                  crossAxisSpacing: 8,
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

                              final isUnavailable = m['available'] == false;
                              
                              return Card(
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: InkWell(
                                  onTap: isUnavailable ? null : () => Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) =>
                                          MealDetailPage(meal: mealMap),
                                    ),
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Stack(
                                        children: [
                                          ClipRRect(
                                            borderRadius:
                                                const BorderRadius.vertical(
                                                  top: Radius.circular(12),
                                                ),
                                            child: ColorFiltered(
                                              colorFilter: isUnavailable 
                                                  ? const ColorFilter.mode(Colors.grey, BlendMode.saturation)
                                                  : const ColorFilter.mode(Colors.transparent, BlendMode.multiply),
                                              child: (m['image'].startsWith('http') || m['image'].startsWith('https'))
                                                  ? Image.network(
                                                      m['image'],
                                                      height: 70,
                                                      width: double.infinity,
                                                      fit: BoxFit.cover,
                                                      loadingBuilder: (context, child, loadingProgress) {
                                                        if (loadingProgress == null) return child;
                                                        return Container(
                                                          height: 70,
                                                          width: double.infinity,
                                                          color: Colors.grey[200],
                                                          child: const Center(
                                                            child: CircularProgressIndicator(strokeWidth: 2),
                                                          ),
                                                        );
                                                      },
                                                      errorBuilder: (context, error, stackTrace) {
                                                        return Image.asset(
                                                          'assets/images/logo.png',
                                                          height: 70,
                                                          width: double.infinity,
                                                          fit: BoxFit.cover,
                                                        );
                                                      },
                                                    )
                                                  : Image.asset(
                                                      m['image'],
                                                      height: 70,
                                                      width: double.infinity,
                                                      fit: BoxFit.cover,
                                                      errorBuilder: (context, error, stackTrace) {
                                                        return Image.asset(
                                                          'assets/images/logo.png',
                                                          height: 70,
                                                          width: double.infinity,
                                                          fit: BoxFit.cover,
                                                        );
                                                      },
                                                    ),
                                            ),
                                          ),
                                          if (isUnavailable)
                                            Positioned.fill(
                                              child: Container(
                                                decoration: BoxDecoration(
                                                  color: Colors.black.withOpacity(0.6),
                                                  borderRadius: const BorderRadius.vertical(
                                                    top: Radius.circular(12),
                                                  ),
                                                ),
                                                child: const Center(
                                                  child: Text(
                                                    'UNAVAILABLE',
                                                    textAlign: TextAlign.center,
                                                    style: TextStyle(
                                                      color: Colors.white,
                                                      fontWeight: FontWeight.bold,
                                                      fontSize: 12,
                                                    ),
                                                  ),
                                                ),
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
                                                favoritesProvider
                                                    .toggleFavorite(mealMap);
                                                Fluttertoast.showToast(
                                                  msg: fav
                                                      ? "❤️ ${m['name']} removed from favorites"
                                                      : "❤️ ${m['name']} added to favorites",
                                                  toastLength:
                                                      Toast.LENGTH_SHORT,
                                                  gravity: ToastGravity.TOP,
                                                  backgroundColor: const Color(
                                                    0xFF2E7D32,
                                                  ),
                                                  textColor: Colors.white,
                                                  fontSize: 16.0,
                                                );
                                              },
                                            ),
                                          ),
                                        ],
                                      ),
                                      Padding(
                                        padding: const EdgeInsets.all(6.0),
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
                                            const SizedBox(height: 2),
                                            Row(
                                              mainAxisAlignment:
                                                  MainAxisAlignment
                                                      .spaceBetween,
                                              children: [
                                                Text(
                                                  m['price'],
                                                  style: const TextStyle(
                                                    color: Colors.deepOrange,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                                IconButton(
                                                  icon: Icon(
                                                    isUnavailable ? Icons.block : Icons.add_circle,
                                                  ),
                                                  color: isUnavailable ? Colors.grey : Colors.deepOrange,
                                                  iconSize: 20,
                                                  onPressed: isUnavailable ? null : () {
                                                    Navigator.push(
                                                      context,
                                                      MaterialPageRoute(
                                                        builder: (_) =>
                                                            MealDetailPage(
                                                              meal: mealMap,
                                                            ),
                                                      ),
                                                    );
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
            if (!_isRestaurantOpen && _showClosedDialog)
              Container(
                color: Colors.black.withOpacity(0.8),
                child: Center(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxHeight: MediaQuery.of(context).size.height * 0.8,
                      maxWidth: MediaQuery.of(context).size.width * 0.9,
                    ),
                    child: Container(
                      margin: const EdgeInsets.all(20),
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.2),
                            blurRadius: 10,
                            offset: const Offset(0, 5),
                          ),
                        ],
                      ),
                      child: SingleChildScrollView(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const SizedBox(width: 24),
                                const Icon(
                                  Icons.store_mall_directory_outlined,
                                  size: 48,
                                  color: Colors.red,
                                ),
                                IconButton(
                                  onPressed: () =>
                                      setState(() => _showClosedDialog = false),
                                  icon: const Icon(
                                    Icons.close,
                                    color: Colors.grey,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'Restaurant Closed',
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: Colors.red,
                              ),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'We are currently closed, but you can still schedule orders for later!',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.grey,
                              ),
                            ),
                            const SizedBox(height: 16),
                            const Text(
                              'Business Hours:',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const Text(
                              'Tuesday - Saturday: 11:00 AM - 8:00 PM',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey,
                              ),
                            ),
                            const Text(
                              'Sunday & Monday: Closed',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey,
                              ),
                            ),
                            const SizedBox(height: 16),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                onPressed: () {
                                  setState(() => _showClosedDialog = false);
                                },
                                icon: const Icon(Icons.schedule),
                                label: const Text('Schedule Order'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.deepOrange,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 12,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
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
