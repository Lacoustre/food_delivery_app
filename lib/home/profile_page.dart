import 'dart:io';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:african_cuisine/provider/favorites_provider.dart';
import 'package:african_cuisine/logins/login_page.dart';
import 'package:african_cuisine/home/saved_addresses_page.dart';
import 'package:african_cuisine/support/rate_orders_page.dart';
import 'package:african_cuisine/support/complaint_refund_page.dart';
import 'package:african_cuisine/support/live_chat_support_page.dart';
import 'package:african_cuisine/support/call_support_page.dart';
import 'package:african_cuisine/orders/order_history_page.dart';
import 'package:african_cuisine/orders/scheduled_orders_page.dart';
import 'package:image_cropper/image_cropper.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final ImagePicker _picker = ImagePicker();
  String? _profileImagePath;
  String? _profileName;
  String? _avatarUrl;
  final _displayNameController = TextEditingController();
  // ignore: unused_field
  bool _imageLoadError = false;
  bool _hasCustomImage = false;
  bool _isUploading = false;

  @override
  void initState() {
    super.initState();
    _loadDisplayName();
    _checkForCustomImage();
  }

  void _loadDisplayName() {
    _loadProfile();
  }

  /// Load display name + avatar from the Supabase profile.
  Future<void> _loadProfile() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;
    try {
      final row = await Supabase.instance.client
          .from('profiles')
          .select('name, avatar_url')
          .eq('id', user.id)
          .maybeSingle();
      if (!mounted) return;
      setState(() {
        _profileName = row?['name'] as String?;
        _avatarUrl = row?['avatar_url'] as String?;
        _displayNameController.text = _profileName ?? '';
        _hasCustomImage = _avatarUrl != null && _avatarUrl!.isNotEmpty;
      });
    } catch (_) {}
  }

  Future<void> _checkForCustomImage() async {
    // covered by _loadProfile
  }

  Future<void> _uploadAndSetProfileImage(File imageFile) async {
    if (Supabase.instance.client.auth.currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please sign in to upload profile picture'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _isUploading = true;
    });

    try {
      final supabase = Supabase.instance.client;
      final supabaseUser = supabase.auth.currentUser;
      if (supabaseUser == null) {
        throw Exception('Not signed in');
      }

      // Upload to the Supabase avatars bucket (owner-scoped folder);
      // upsert replaces the previous photo, cache-buster keeps the stable
      // public URL fresh in image caches.
      final path = '${supabaseUser.id}/profile.jpg';
      await supabase.storage.from('avatars').upload(
            path,
            imageFile,
            fileOptions: const FileOptions(
              contentType: 'image/jpeg',
              upsert: true,
            ),
          );
      final downloadUrl =
          '${supabase.storage.from('avatars').getPublicUrl(path)}'
          '?v=${DateTime.now().millisecondsSinceEpoch}';

      await supabase
          .from('profiles')
          .update({'avatar_url': downloadUrl}).eq('id', supabaseUser.id);

      setState(() {
        _profileImagePath = null;
        _imageLoadError = false;
        _hasCustomImage = true;
        _avatarUrl = downloadUrl;
        _isUploading = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Profile picture updated successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      setState(() {
        _isUploading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Upload failed: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }

  /// Remove profile image and revert to default
  Future<void> _removeProfileImage() async {
    if (Supabase.instance.client.auth.currentUser == null) return;

    // Show confirmation dialog
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove Profile Picture'),
        content: const Text(
          'Are you sure you want to remove your profile picture and use the default image?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Remove', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (shouldDelete != true) return;

    try {
      final supabase = Supabase.instance.client;
      final supabaseUser = supabase.auth.currentUser;
      if (supabaseUser != null) {
        try {
          await supabase.storage
              .from('avatars')
              .remove(['${supabaseUser.id}/profile.jpg']);
        } catch (e) {
          debugPrint('Avatar deletion failed: $e');
        }
        try {
          await supabase
              .from('profiles')
              .update({'avatar_url': null}).eq('id', supabaseUser.id);
        } catch (e) {
          debugPrint('Profile avatar clear failed: $e');
        }
      }

      setState(() {
        _profileImagePath = null;
        _imageLoadError = false;
        _hasCustomImage = false;
        _avatarUrl = null;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ Profile picture removed. Using default image.'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to remove image: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _pickImage() async {
    if (Supabase.instance.client.auth.currentUser == null) return;

    try {
      final source = await showModalBottomSheet<ImageSource>(
        context: context,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
        builder: (context) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Choose Profile Picture',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                ListTile(
                  leading: const Icon(
                    Icons.camera_alt,
                    color: Colors.deepOrange,
                  ),
                  title: const Text('Take Photo'),
                  onTap: () => Navigator.of(context).pop(ImageSource.camera),
                ),
                ListTile(
                  leading: const Icon(
                    Icons.photo_library,
                    color: Colors.deepOrange,
                  ),
                  title: const Text('Choose from Gallery'),
                  onTap: () => Navigator.of(context).pop(ImageSource.gallery),
                ),
                if (_hasCustomImage)
                  ListTile(
                    leading: const Icon(Icons.delete, color: Colors.red),
                    title: const Text('Remove Current Picture'),
                    onTap: () {
                      Navigator.of(context).pop();
                      _removeProfileImage();
                    },
                  ),
              ],
            ),
          ),
        ),
      );

      if (source == null) return;

      final XFile? pickedFile = await _picker.pickImage(
        source: source,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 80,
      );
      if (pickedFile == null) return;

      final croppedImage = await _cropImage(pickedFile.path);
      if (croppedImage == null) return;

      setState(() {
        _profileImagePath = croppedImage.path;
      });

      await _uploadAndSetProfileImage(croppedImage);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Image selection failed: ${e.toString()}')),
      );
    }
  }

  Future<void> _showEditProfileDialog() async {
    _displayNameController.text = _profileName ?? '';

    await showDialog(
      context: context,
      builder: (context) {
        bool isLoading = false;

        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              title: const Text('Edit Profile'),
              content: TextField(
                controller: _displayNameController,
                decoration: const InputDecoration(
                  labelText: 'Display Name',
                  border: OutlineInputBorder(),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isLoading
                      ? null
                      : () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: isLoading
                      ? null
                      : () async {
                          final newName = _displayNameController.text.trim();
                          if (newName.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Name cannot be empty'),
                              ),
                            );
                            return;
                          }

                          setStateDialog(() => isLoading = true);
                          try {
                            final supabaseUser =
                                Supabase.instance.client.auth.currentUser;
                            if (supabaseUser != null) {
                              await Supabase.instance.client
                                  .from('profiles')
                                  .update({'name': newName})
                                  .eq('id', supabaseUser.id);
                            }
                            setState(() => _profileName = newName);
                            Navigator.of(context).pop();
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Profile updated successfully!'),
                              ),
                            );
                          } catch (e) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Update failed: ${e.toString()}'),
                              ),
                            );
                          } finally {
                            setStateDialog(() => isLoading = false);
                          }
                        },
                  child: isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<File?> _cropImage(String path) async {
    final croppedFile = await ImageCropper().cropImage(
      sourcePath: path,
      aspectRatio: const CropAspectRatio(ratioX: 1, ratioY: 1),
      compressFormat: ImageCompressFormat.jpg,
      compressQuality: 85,
      uiSettings: [
        AndroidUiSettings(
          toolbarTitle: 'Crop Image',
          toolbarColor: Colors.deepOrange,
          toolbarWidgetColor: Colors.white,
          hideBottomControls: true,
          initAspectRatio: CropAspectRatioPreset.square,
          lockAspectRatio: true,
        ),
        IOSUiSettings(title: 'Crop Image'),
      ],
    );
    return croppedFile != null ? File(croppedFile.path) : null;
  }

  Future<void> _showEditEmailDialog() async {
    final user = Supabase.instance.client.auth.currentUser;
    final emailController = TextEditingController(text: user?.email ?? '');

    await showDialog(
      context: context,
      builder: (context) {
        bool isLoading = false;

        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              title: const Text('Edit Email'),
              content: TextField(
                controller: emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  labelText: 'New Email',
                  border: OutlineInputBorder(),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isLoading ? null : () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: isLoading
                      ? null
                      : () async {
                          final newEmail = emailController.text.trim();
                          if (newEmail.isEmpty || !newEmail.contains('@')) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Enter a valid email'),
                              ),
                            );
                            return;
                          }

                          setStateDialog(() => isLoading = true);
                          try {
                            // Supabase emails a confirmation link to the
                            // new address; the change applies on confirm.
                            await Supabase.instance.client.auth.updateUser(
                              UserAttributes(email: newEmail),
                            );
                            setState(() {});
                            Navigator.pop(context);

                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Confirmation sent — check the new email to finish the change.',
                                ),
                              ),
                            );
                          } catch (e) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Failed: ${e.toString()}'),
                              ),
                            );
                          } finally {
                            setStateDialog(() => isLoading = false);
                          }
                        },
                  child: isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Update'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  /// Get the correct image provider with proper fallback
  ImageProvider _getProfileImageProvider() {
    // Show local image if we just picked one
    if (_profileImagePath != null) {
      return FileImage(File(_profileImagePath!));
    }

    // If user has a custom image with a valid URL, show it
    if (_hasCustomImage && _avatarUrl != null && _avatarUrl!.isNotEmpty) {
      return NetworkImage(_avatarUrl!);
    }

    // Default image
    return const AssetImage('assets/images/default_user.png');
  }

  // New method to build profile image section with delete functionality
  Widget _buildProfileImageSection() {
    return Stack(
      children: [
        GestureDetector(
          onTap: _isUploading ? null : _pickImage,
          child: Stack(
            children: [
              CircleAvatar(
                radius: 50,
                backgroundImage: _getProfileImageProvider(),
              ),
              if (_isUploading)
                const Positioned.fill(
                  child: CircleAvatar(
                    radius: 50,
                    backgroundColor: Colors.black54,
                    child: CircularProgressIndicator(color: Colors.white),
                  ),
                ),
            ],
          ),
        ),
        // Camera icon (bottom right)
        if (!_isUploading)
          Positioned(
            bottom: 0,
            right: 0,
            child: GestureDetector(
              onTap: _pickImage,
              child: _circleActionIcon(Icons.camera_alt),
            ),
          ),
        // Delete icon (top right) - only show if user has custom image
        if (!_isUploading && _hasCustomImage)
          Positioned(
            top: 0,
            right: 0,
            child: GestureDetector(
              onTap: _removeProfileImage,
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: const BoxDecoration(
                  color: Colors.red,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black26,
                      blurRadius: 4,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                child: const Icon(Icons.delete, size: 18, color: Colors.white),
              ),
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = Supabase.instance.client.auth.currentUser;
    final displayName =
        _profileName ?? user?.email?.split('@').first ?? 'User';
    final email = user?.email ?? 'No email';
    final favoritesCount = Provider.of<FavoritesProvider>(
      context,
    ).favorites.length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        backgroundColor: Colors.deepOrange,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            // Profile Image Section with delete functionality
            _buildProfileImageSection(),

            const SizedBox(height: 16),

            // User Info Section
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  displayName,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                GestureDetector(
                  onTap: _showEditProfileDialog,
                  child: const Padding(
                    padding: EdgeInsets.only(left: 8),
                    child: Icon(Icons.edit, color: Colors.deepOrange, size: 18),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(email, style: const TextStyle(color: Colors.grey)),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.deepOrange.shade50,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                '❤️ Favorites: $favoritesCount',
                style: TextStyle(
                  color: Colors.deepOrange.shade700,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),

            // Optional: Add delete button below profile info
            const SizedBox(height: 16),
            if (_hasCustomImage)
              SizedBox(
                width: double.infinity,
                child: TextButton.icon(
                  onPressed: _removeProfileImage,
                  icon: const Icon(Icons.delete, color: Colors.red, size: 16),
                  label: const Text(
                    'Remove Profile Picture',
                    style: TextStyle(color: Colors.red),
                  ),
                  style: TextButton.styleFrom(
                    backgroundColor: Colors.red.shade50,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),

            const Divider(height: 32),

            // Profile Options
            _buildSectionHeader('Delivery Preferences'),
            _buildProfileOption(
              icon: Icons.location_on,
              title: "Saved Addresses",
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const SavedAddressesPage(),
                ),
              ),
            ),
            _buildProfileOption(
              icon: Icons.calendar_today,
              title: "Scheduled Orders",
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ScheduledOrdersPage()),
              ),
            ),

            _buildSectionHeader('Help & Support'),
            _buildProfileOption(
              icon: Icons.star_rate,
              title: "Rate Past Orders",
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const RatePastOrdersPage()),
              ),
            ),
            _buildProfileOption(
              icon: Icons.help_outline,
              title: "Complaint/Refund Request",
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ComplaintRefundPage()),
              ),
            ),
            _buildProfileOption(
              icon: Icons.chat,
              title: "Live Chat Support",
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const LiveChatSupportPage()),
              ),
            ),
            _buildProfileOption(
              icon: Icons.call,
              title: "Call Support",
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const CallSupportPage()),
              ),
            ),

            _buildSectionHeader('Orders'),
            _buildProfileOption(
              icon: Icons.receipt_long,
              title: "Order History",
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const OrderHistoryPage()),
              ),
            ),

            _buildSectionHeader('Account Settings'),

            _buildPhoneNumberSection(),

            _buildProfileOption(
              icon: Icons.email,
              title: "Edit Email",
              onTap: _showEditEmailDialog,
            ),
            _buildProfileOption(
              icon: Icons.lock_outline,
              title: "Change Password",
              onTap: () {
                final user = Supabase.instance.client.auth.currentUser;
                if (user?.email != null) {
                  Supabase.instance.client.auth
                      .resetPasswordForEmail(user!.email!);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Password reset email sent.")),
                  );
                }
              },
            ),

            const SizedBox(height: 24),

            // Sign Out Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () async {
                  final shouldSignOut = await showDialog<bool>(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text('Sign Out'),
                      content: const Text('Are you sure you want to sign out?'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context, false),
                          child: const Text('Cancel'),
                        ),
                        ElevatedButton(
                          onPressed: () => Navigator.pop(context, true),
                          child: const Text('Sign Out'),
                        ),
                      ],
                    ),
                  );

                  if (shouldSignOut == true) {
                    await Supabase.instance.client.auth.signOut();
                    Navigator.of(context).pushAndRemoveUntil(
                      MaterialPageRoute(builder: (_) => const LoginPage()),
                      (_) => false,
                    );
                  }
                },
                icon: const Icon(Icons.logout),
                label: const Text('Sign Out'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.deepOrange,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _circleActionIcon(IconData icon) {
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: const BoxDecoration(
        color: Colors.deepOrange,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(color: Colors.black26, blurRadius: 4, offset: Offset(0, 2)),
        ],
      ),
      child: Icon(icon, size: 18, color: Colors.white),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(top: 16, bottom: 8),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          title,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.deepOrange,
          ),
        ),
      ),
    );
  }



  Widget _buildPhoneNumberSection() {
    final supabaseUser = Supabase.instance.client.auth.currentUser;
    return FutureBuilder<Map<String, dynamic>?>(
      future: supabaseUser != null
          ? Supabase.instance.client
                .from('profiles')
                .select('phone')
                .eq('id', supabaseUser.id)
                .maybeSingle()
          : Future.value(null),
      builder: (context, snapshot) {
        String? phoneNumber;
        bool isLinked = false;

        if (snapshot.hasData) {
          phoneNumber = snapshot.data?['phone'] as String?;
          isLinked = phoneNumber != null && phoneNumber.isNotEmpty;
        }
        
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            leading: Icon(
              isLinked ? Icons.phone_android : Icons.phone_android_outlined,
              color: isLinked ? Colors.green : Colors.deepOrange,
            ),
            title: Text(isLinked ? 'Phone Number' : 'Add Phone Number'),
            subtitle: isLinked
                ? Text(phoneNumber!)
                : const Text('Add your phone number for order updates'),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (isLinked)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.green.shade100,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      'Linked',
                      style: TextStyle(
                        color: Colors.green.shade700,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                const SizedBox(width: 8),
                const Icon(Icons.chevron_right),
              ],
            ),
            onTap: () => _showEditPhoneDialog(phoneNumber),
          ),
        );
      },
    );
  }

  /// Phone is a plain profile field now — OTP verification went away with
  /// Firebase phone auth (Supabase phone OTP would need a Twilio account).
  void _showEditPhoneDialog(String? currentPhone) {
    final controller = TextEditingController(text: currentPhone ?? '');
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Phone Number'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.phone,
          decoration: const InputDecoration(
            labelText: 'Phone number',
            hintText: '+1 555 555 5555',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final phone =
                  controller.text.trim().replaceAll(RegExp(r'\s+'), '');
              final supabaseUser =
                  Supabase.instance.client.auth.currentUser;
              if (supabaseUser == null) return;
              try {
                await Supabase.instance.client
                    .from('profiles')
                    .update({'phone': phone.isEmpty ? null : phone})
                    .eq('id', supabaseUser.id);
                if (ctx.mounted) Navigator.pop(ctx);
                if (mounted) {
                  setState(() {}); // refresh the phone section
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('✅ Phone number saved')),
                  );
                }
              } catch (e) {
                if (ctx.mounted) {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    SnackBar(content: Text('Failed to save: $e')),
                  );
                }
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileOption({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Icon(icon, color: Colors.deepOrange),
        title: Text(title),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}
