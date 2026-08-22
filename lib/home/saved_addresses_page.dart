import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geocoding/geocoding.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/address.dart';
import '../home/map_picker_page.dart';

/// Saved addresses live in the Supabase addresses table (owner-only RLS),
/// replacing the per-user Firestore subcollection.
class SavedAddressesPage extends StatefulWidget {
  const SavedAddressesPage({super.key});

  @override
  State<SavedAddressesPage> createState() => _SavedAddressesPageState();
}

class _SavedAddressesPageState extends State<SavedAddressesPage> {
  final _formKey = GlobalKey<FormState>();
  final _streetController = TextEditingController();
  final _cityController = TextEditingController();
  final _stateController = TextEditingController();
  final _zipController = TextEditingController();
  bool _isDefault = false;
  LatLng? _selectedLatLng;

  final SupabaseClient _supabase = Supabase.instance.client;
  String get _userId => _supabase.auth.currentUser!.id;

  Future<void> _pickLocationAndFillFields() async {
    final LatLng? picked = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const MapPickerPage()),
    );
    if (picked == null) return;

    try {
      final placemarks = await placemarkFromCoordinates(
        picked.latitude,
        picked.longitude,
      );

      if (placemarks.isNotEmpty) {
        final place = placemarks.first;
        setState(() {
          _selectedLatLng = picked;
          _streetController.text = place.street ?? '';
          _cityController.text = place.locality ?? '';
          _stateController.text = place.administrativeArea ?? '';
          _zipController.text = place.postalCode ?? '';
        });
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Failed to reverse geocode location.")),
      );
    }
  }

  void _showToast(String msg, Color background) {
    Fluttertoast.showToast(
      msg: msg,
      toastLength: Toast.LENGTH_SHORT,
      gravity: ToastGravity.TOP,
      backgroundColor: background,
      textColor: Colors.white,
      fontSize: 14.0,
    );
  }

  void _showAddressDialog({Address? address}) {
    if (address != null) {
      _streetController.text = address.street;
      _cityController.text = address.city;
      _stateController.text = address.state;
      _zipController.text = address.zipCode;
      _selectedLatLng = (address.latitude != null && address.longitude != null)
          ? LatLng(address.latitude!, address.longitude!)
          : null;
      _isDefault = address.isDefault;
    } else {
      _streetController.clear();
      _cityController.clear();
      _stateController.clear();
      _zipController.clear();
      _isDefault = false;
      _selectedLatLng = null;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: MediaQuery.of(ctx).viewInsets,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  '📍 Address Details',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const Divider(),
                const SizedBox(height: 8),
                ElevatedButton.icon(
                  icon: const Icon(Icons.map),
                  label: const Text('Pick Location'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.deepOrange,
                  ),
                  onPressed: _pickLocationAndFillFields,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _streetController,
                  decoration: const InputDecoration(
                    labelText: 'Street',
                    prefixIcon: Icon(Icons.home),
                  ),
                  validator: (v) => v!.isEmpty ? 'Required' : null,
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _cityController,
                  decoration: const InputDecoration(
                    labelText: 'City',
                    prefixIcon: Icon(Icons.location_city),
                  ),
                  validator: (v) => v!.isEmpty ? 'Required' : null,
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _stateController,
                  decoration: const InputDecoration(
                    labelText: 'State',
                    prefixIcon: Icon(Icons.map),
                  ),
                  validator: (v) => v!.isEmpty ? 'Required' : null,
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _zipController,
                  decoration: const InputDecoration(
                    labelText: 'Zip Code',
                    prefixIcon: Icon(Icons.local_post_office),
                  ),
                  validator: (v) => v!.isEmpty ? 'Required' : null,
                ),
                const SizedBox(height: 10),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Set as default address'),
                  value: _isDefault,
                  onChanged: (val) => setState(() => _isDefault = val),
                  secondary: const Icon(Icons.star),
                ),
                const SizedBox(height: 20),
                ElevatedButton.icon(
                  onPressed: () async {
                    if (!_formKey.currentState!.validate()) return;

                    final street = _streetController.text.trim();
                    final city = _cityController.text.trim();
                    final state = _stateController.text.trim();
                    final zip = _zipController.text.trim();

                    // Duplicate check on the address fields themselves
                    var dupQuery = _supabase
                        .from('addresses')
                        .select('id')
                        .eq('user_id', _userId)
                        .eq('street', street)
                        .eq('city', city)
                        .eq('state', state)
                        .eq('zip', zip);
                    final dups = await dupQuery.limit(2);
                    final isDuplicate = dups.any(
                      (row) => address == null || row['id'] != address.id,
                    );

                    if (isDuplicate) {
                      _showToast(
                        "⚠️ Address already exists",
                        Colors.orange.shade600,
                      );
                      return;
                    }

                    // If setting a new default, unset previous ones
                    if (_isDefault) {
                      await _supabase
                          .from('addresses')
                          .update({'is_default': false})
                          .eq('user_id', _userId);
                    }

                    final data = {
                      'street': street,
                      'city': city,
                      'state': state,
                      'zip': zip,
                      'lat': _selectedLatLng?.latitude,
                      'lng': _selectedLatLng?.longitude,
                      'is_default': _isDefault,
                    };

                    if (address != null) {
                      await _supabase
                          .from('addresses')
                          .update(data)
                          .eq('id', address.id);
                      _showToast(
                        "✅ Address updated successfully",
                        Colors.green.shade600,
                      );
                    } else {
                      await _supabase
                          .from('addresses')
                          .insert({...data, 'user_id': _userId});
                      _showToast(
                        "✅ Address added successfully",
                        Colors.green.shade600,
                      );
                    }

                    if (mounted) Navigator.pop(ctx);
                  },
                  icon: const Icon(Icons.save),
                  label: Text(address == null ? 'Add Address' : 'Save Changes'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.deepOrange,
                    minimumSize: const Size.fromHeight(48),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _deleteAddress(String id) async {
    await _supabase.from('addresses').delete().eq('id', id);
    _showToast("🗑️ Address deleted", Colors.red.shade600);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Saved Addresses'),
        backgroundColor: Colors.deepOrange,
      ),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: _supabase
            .from('addresses')
            .stream(primaryKey: ['id'])
            .eq('user_id', _userId),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(child: Text('Error loading addresses'));
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          // Default first, then newest — sorted client-side since the
          // realtime stream builder only supports one order key.
          final rows = [...snapshot.data!];
          rows.sort((a, b) {
            final defaultCmp = ((b['is_default'] as bool? ?? false) ? 1 : 0)
                .compareTo((a['is_default'] as bool? ?? false) ? 1 : 0);
            if (defaultCmp != 0) return defaultCmp;
            return (b['created_at'] as String? ?? '')
                .compareTo(a['created_at'] as String? ?? '');
          });

          if (rows.isEmpty) {
            return const Center(
              child: Text(
                'No saved addresses yet.',
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: rows.length,
            separatorBuilder: (_, __) => const Divider(),
            itemBuilder: (context, i) {
              final addr = Address.fromRow(rows[i]);

              return ListTile(
                leading: const Icon(
                  Icons.location_on,
                  color: Colors.deepOrange,
                ),
                title: Row(
                  children: [
                    Expanded(child: Text('${addr.street}, ${addr.city}')),
                    if (addr.isDefault)
                      const Padding(
                        padding: EdgeInsets.only(left: 8),
                        child: Chip(
                          label: Text(
                            'Default',
                            style: TextStyle(color: Colors.white),
                          ),
                          backgroundColor: Colors.green,
                          visualDensity: VisualDensity.compact,
                        ),
                      ),
                  ],
                ),
                subtitle: Text('${addr.state} ${addr.zipCode}'),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit),
                      onPressed: () => _showAddressDialog(address: addr),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete),
                      onPressed: () => _deleteAddress(addr.id),
                    ),
                  ],
                ),
                onTap: () {
                  Navigator.pop(context, addr);
                },
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.deepOrange,
        onPressed: () => _showAddressDialog(),
        child: const Icon(Icons.add),
      ),
    );
  }
}
