import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
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
import 'package:african_cuisine/phone_number_update.dart';
import 'package:image_cropper/image_cropper.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final ImagePicker _picker = ImagePicker();
  String? _profileImagePath;
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
    final user = FirebaseAuth.instance.currentUser;
    _displayNameController.text = user?.displayName ?? '';
  }

  /// Check if user has a custom profile image
  Future<void> _checkForCustomImage() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final storageRef = FirebaseStorage.instance.ref().child(
        'profile_pictures/${user.uid}.jpg',
      );

      // Try to get download URL - if it exists, user has custom image
      await storageRef.getDownloadURL();
      setState(() {
        _hasCustomImage = true;
      });
    } catch (e) {
      // Image doesn't exist in storage
      setState(() {
        _hasCustomImage = false;
      });

      // Clear any broken photoURL from Firebase Auth
      if (user.photoURL != null) {
        await user.updatePhotoURL(null);
        await user.reload();
      }
    }
  }

  // Handle simulator upload errors
  Future<void> _handleSimulatorUploadError(User user) async {
    // Wait a bit for potential upload completion
    await Future.delayed(const Duration(seconds: 3));

    try {
      final storageRef = FirebaseStorage.instance.ref().child(
        'profile_pictures/${user.uid}.jpg',
      );
      final downloadUrl = await storageRef.getDownloadURL();

      await user.updatePhotoURL(downloadUrl);
      await user.reload();

      setState(() {
        _profileImagePath = null;
        _imageLoadError = false;
        _hasCustomImage = true;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profile picture updated (simulator mode)!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (secondError) {
      // Actually failed
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Upload failed: Cannot verify upload completion'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _uploadAndSetProfileImage(File imageFile) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    setState(() {
      _isUploading = true;
    });

    try {
      final storageRef = FirebaseStorage.instance.ref().child(
        'profile_pictures/${user.uid}.jpg',
      );

      final uploadTask = storageRef.putFile(imageFile);
      final snapshot = await uploadTask;
      final downloadUrl = await snapshot.ref.getDownloadURL();

      await user.updatePhotoURL(downloadUrl);
      await user.reload();

      setState(() {
        _profileImagePath = null;
        _imageLoadError = false;
        _hasCustomImage = true;
        _isUploading = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profile picture updated successfully!'),
          ),
        );
      }
    } catch (e) {
      setState(() {
        _isUploading = false;
      });

      // Enhanced error handling for simulator issues
      if (e.toString().contains('cannot parse response') ||
          e.toString().contains('XMLHttpRequest')) {
        // Common simulator/web errors - try to verify upload
        await _handleSimulatorUploadError(user);
      } else {
        // Actual upload failure
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Upload failed: ${e.toString()}')),
          );
        }
      }
    }
  }

  /// Remove profile image and revert to default
  Future<void> _removeProfileImage() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

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
      // Delete from Firebase Storage
      final storageRef = FirebaseStorage.instance.ref().child(
        'profile_pictures/${user.uid}.jpg',
      );

      try {
        await storageRef.delete();
      } catch (storageError) {
        // Continue even if storage deletion fails
        print('Storage deletion failed: $storageError');
      }

      // Clear the photoURL from Firebase Auth
      await user.updatePhotoURL(null);
      await user.reload();

      setState(() {
        _profileImagePath = null;
        _imageLoadError = false;
        _hasCustomImage = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Profile picture removed. Using default image.'),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to remove image: ${e.toString()}')),
      );
    }
  }

  Future<void> _pickImage() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

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
    final user = FirebaseAuth.instance.currentUser;
    _displayNameController.text = user?.displayName ?? '';

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
                            await user?.updateDisplayName(newName);
                            await user?.reload();
                            setState(() {});
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
    final user = FirebaseAuth.instance.currentUser;
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
                            await user?.updateEmail(newEmail);
                            await user?.reload();
                            setState(() {});
                            Navigator.pop(context);

                            // ✅ Email updated — send verification
                            await user?.sendEmailVerification();

                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Email updated! Verification sent.',
                                ),
                              ),
                            );
                          } catch (e) {
                            // ✅ Handle re-authentication requirement
                            if (e is FirebaseAuthException &&
                                e.code == 'requires-recent-login') {
                              Navigator.pop(context); // Close dialog first
                              await _showReauthDialog(); // Show re-auth dialog
                            } else {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Failed: ${e.toString()}'),
                                ),
                              );
                            }
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

  Future<void> _showReauthDialog() async {
    final user = FirebaseAuth.instance.currentUser;
    final email = user?.email;
    final passwordController = TextEditingController();

    if (email == null) return;

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Re-authenticate'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Please enter your password to continue.'),
            const SizedBox(height: 12),
            TextField(
              controller: passwordController,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Password',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              try {
                final credential = EmailAuthProvider.credential(
                  email: email,
                  password: passwordController.text.trim(),
                );
                await user?.reauthenticateWithCredential(credential);
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Re-authenticated successfully!'),
                  ),
                );
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Re-authentication failed: ${e.toString()}'),
                  ),
                );
              }
            },
            child: const Text('Continue'),
          ),
        ],
      ),
    );
  }

  /// Get the correct image provider with proper fallback
  ImageProvider _getProfileImageProvider() {
    // Show local image if we just picked one
    if (_profileImagePath != null) {
      return FileImage(File(_profileImagePath!));
    }

    final user = FirebaseAuth.instance.currentUser;

    // If user has custom image and valid photoURL, try to show it
    if (_hasCustomImage &&
        user?.photoURL != null &&
        user!.photoURL!.isNotEmpty) {
      return NetworkImage(user.photoURL!);
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
    final user = FirebaseAuth.instance.currentUser;
    final displayName =
        user?.displayName ?? user?.email?.split('@').first ?? 'User';
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
              onTap: () => ScaffoldMessenger.of(
                context,
              ).showSnackBar(const SnackBar(content: Text('Coming Soon'))),
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
            ListTile(
              leading: const Icon(
                Icons.phone_android,
                color: Colors.deepOrange,
              ),
              title: const Text('Update Phone Number'),
              trailing: const Icon(Icons.chevron_right, size: 20),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const PhoneNumberUpdatePage(),
                  ),
                );
              },
            ),

            _buildProfileOption(
              icon: Icons.email,
              title: "Edit Email",
              onTap: _showEditEmailDialog,
            ),
            _buildProfileOption(
              icon: Icons.lock_outline,
              title: "Change Password",
              onTap: () {
                final user = FirebaseAuth.instance.currentUser;
                if (user?.email != null) {
                  FirebaseAuth.instance.sendPasswordResetEmail(
                    email: user!.email!,
                  );
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
                    await FirebaseAuth.instance.signOut();
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
