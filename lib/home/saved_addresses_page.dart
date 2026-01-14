import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geocoding/geocoding.dart';
import '../models/address.dart';
import '../home/map_picker_page.dart';

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

  late final CollectionReference<Map<String, dynamic>> _addrColl =
      FirebaseFirestore.instance
          .collection('users')
          .doc(FirebaseAuth.instance.currentUser!.uid)
          .collection('addresses');

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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Failed to reverse geocode location.")),
      );
    }
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

                    final fullAddress = '$street, $city, $state $zip';

                    // Duplicate check (fullAddress)
                    final dupSnap = await _addrColl
                        .where('fullAddress', isEqualTo: fullAddress)
                        .limit(1)
                        .get();

                    final isDuplicate =
                        dupSnap.docs.isNotEmpty &&
                        (address == null ||
                            dupSnap.docs.first.id != address.id);

                    if (isDuplicate) {
                      Fluttertoast.showToast(
                        msg: "⚠️ Address already exists",
                        toastLength: Toast.LENGTH_SHORT,
                        gravity: ToastGravity.TOP,
                        backgroundColor: Colors.orange.shade600,
                        textColor: Colors.white,
                        fontSize: 14.0,
                      );
                      return;
                    }

                    // If setting a new default, unset previous ones
                    if (_isDefault) {
                      final snapshot = await _addrColl.get();
                      for (final doc in snapshot.docs) {
                        if (address == null || doc.id != address.id) {
                          await doc.reference.update({'isDefault': false});
                        }
                      }
                    }

                    final data = {
                      'street': street,
                      'city': city,
                      'state': state,
                      'zipCode': zip,
                      'latitude': _selectedLatLng?.latitude,
                      'longitude': _selectedLatLng?.longitude,
                      'isDefault': _isDefault,
                      'fullAddress': fullAddress,
                      // createdAt is added only on create (below)
                    };

                    if (address != null) {
                      await _addrColl.doc(address.id).update(data);
                      Fluttertoast.showToast(
                        msg: "✅ Address updated successfully",
                        toastLength: Toast.LENGTH_SHORT,
                        gravity: ToastGravity.TOP,
                        backgroundColor: Colors.green.shade600,
                        textColor: Colors.white,
                        fontSize: 14.0,
                      );
                    } else {
                      await _addrColl.add({
                        ...data,
                        'createdAt': FieldValue.serverTimestamp(),
                      });
                      Fluttertoast.showToast(
                        msg: "✅ Address added successfully",
                        toastLength: Toast.LENGTH_SHORT,
                        gravity: ToastGravity.TOP,
                        backgroundColor: Colors.green.shade600,
                        textColor: Colors.white,
                        fontSize: 14.0,
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
    await _addrColl.doc(id).delete();
    Fluttertoast.showToast(
      msg: "🗑️ Address deleted",
      toastLength: Toast.LENGTH_SHORT,
      gravity: ToastGravity.TOP,
      backgroundColor: Colors.red.shade600,
      textColor: Colors.white,
      fontSize: 14.0,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Saved Addresses'),
        backgroundColor: Colors.deepOrange,
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        // Default addresses first, then newest
        stream: _addrColl
            .orderBy('isDefault', descending: true)
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(child: Text('Error loading addresses'));
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final docs = snapshot.data!.docs;
          if (docs.isEmpty) {
            return const Center(
              child: Text(
                'No saved addresses yet.',
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: docs.length,
            separatorBuilder: (_, __) => const Divider(),
            itemBuilder: (context, i) {
              final addr = Address.fromMap(docs[i].id, docs[i].data());

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
