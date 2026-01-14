import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:african_cuisine/provider/favorites_provider.dart';
import 'package:african_cuisine/services/push_notification_service.dart';
import 'package:african_cuisine/logins/login_page.dart';
import 'package:african_cuisine/home/saved_addresses_page.dart';
import 'package:african_cuisine/support/rate_orders_page.dart';
import 'package:african_cuisine/support/complaint_refund_page.dart';
import 'package:african_cuisine/support/live_chat_support_page.dart';
import 'package:african_cuisine/support/call_support_page.dart';
import 'package:african_cuisine/orders/order_history_page.dart';
import 'package:african_cuisine/orders/scheduled_orders_page.dart';
import 'package:african_cuisine/phone_number_update.dart';
import 'package:african_cuisine/logins/link_phone_page.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

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
      // Check both old and new storage paths
      final oldStorageRef = FirebaseStorage.instance.ref().child(
        'profile_pictures/${user.uid}.jpg',
      );
      final newStorageRef = FirebaseStorage.instance.ref().child(
        'users/${user.uid}/profile_picture.jpg',
      );

      try {
        // Try new path first
        await newStorageRef.getDownloadURL();
        setState(() {
          _hasCustomImage = true;
        });
        return;
      } catch (e) {
        // Try old path
        try {
          await oldStorageRef.getDownloadURL();
          setState(() {
            _hasCustomImage = true;
          });
          return;
        } catch (e) {
          // No custom image found
        }
      }

      // Check if user has photoURL set
      if (user.photoURL != null && user.photoURL!.isNotEmpty) {
        setState(() {
          _hasCustomImage = true;
        });
      } else {
        setState(() {
          _hasCustomImage = false;
        });
      }
    } catch (e) {
      // Image doesn't exist in storage
      setState(() {
        _hasCustomImage = false;
      });

      // Clear any broken photoURL from Firebase Auth
      if (user.photoURL != null) {
        try {
          await user.updatePhotoURL(null);
          await user.reload();
        } catch (updateError) {
          print('Failed to clear broken photoURL: $updateError');
        }
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
    if (user == null) {
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
      // Ensure user is authenticated and get fresh token
      await user.reload();
      final idToken = await user.getIdToken(true);
      
      if (idToken == null) {
        throw Exception('Authentication token not available');
      }

      // Check if user is properly authenticated
      if (!user.emailVerified && user.providerData.isEmpty) {
        throw FirebaseException(
          plugin: 'firebase_storage',
          code: 'unauthenticated',
          message: 'User not properly authenticated',
        );
      }

      final storageRef = FirebaseStorage.instance.ref().child(
        'users/${user.uid}/profile_picture.jpg',
      );

      // Add metadata for better organization
      final metadata = SettableMetadata(
        contentType: 'image/jpeg',
        customMetadata: {
          'userId': user.uid,
          'uploadedAt': DateTime.now().toIso8601String(),
        },
      );

      final uploadTask = storageRef.putFile(imageFile, metadata);
      
      // Monitor upload progress
      uploadTask.snapshotEvents.listen((TaskSnapshot snapshot) {
        final progress = snapshot.bytesTransferred / snapshot.totalBytes;
        debugPrint('Upload progress: ${(progress * 100).toStringAsFixed(1)}%');
      });

      final snapshot = await uploadTask;
      final downloadUrl = await snapshot.ref.getDownloadURL();

      // Update user profile with new photo URL
      await user.updatePhotoURL(downloadUrl);
      
      // Also save to Firestore for backup
      try {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .update({
              'photoURL': downloadUrl,
              'profileUpdatedAt': FieldValue.serverTimestamp(),
            });
      } catch (firestoreError) {
        // Continue even if Firestore update fails
        debugPrint('Firestore update failed: $firestoreError');
      }

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
            content: Text('✅ Profile picture updated successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } on FirebaseException catch (e) {
      setState(() {
        _isUploading = false;
      });

      String errorMessage = 'Upload failed';
      
      switch (e.code) {
        case 'storage/unauthorized':
        case 'unauthenticated':
          errorMessage = 'Please sign out and sign back in to upload images.';
          // Force re-authentication
          await FirebaseAuth.instance.signOut();
          if (mounted) {
            Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
          }
          return;
        case 'storage/canceled':
          errorMessage = 'Upload was cancelled';
          break;
        case 'storage/unknown':
          errorMessage = 'An unknown error occurred during upload';
          break;
        case 'storage/object-not-found':
          errorMessage = 'File not found during upload';
          break;
        case 'storage/bucket-not-found':
          errorMessage = 'Storage bucket not found';
          break;
        case 'storage/project-not-found':
          errorMessage = 'Project not found';
          break;
        case 'storage/quota-exceeded':
          errorMessage = 'Storage quota exceeded';
          break;
        case 'storage/retry-limit-exceeded':
          errorMessage = 'Upload retry limit exceeded. Please try again.';
          break;
        default:
          errorMessage = 'Upload failed: ${e.message}';
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
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
            SnackBar(
              content: Text('Upload failed: ${e.toString()}'),
              backgroundColor: Colors.red,
            ),
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
      // Try to delete from both storage paths
      final oldStorageRef = FirebaseStorage.instance.ref().child(
        'profile_pictures/${user.uid}.jpg',
      );
      final newStorageRef = FirebaseStorage.instance.ref().child(
        'users/${user.uid}/profile_picture.jpg',
      );

      // Try to delete from both locations
      try {
        await newStorageRef.delete();
      } catch (e) {
        print('New storage path deletion failed: $e');
      }
      
      try {
        await oldStorageRef.delete();
      } catch (e) {
        print('Old storage path deletion failed: $e');
      }

      // Clear the photoURL from Firebase Auth
      await user.updatePhotoURL(null);
      
      // Also remove from Firestore
      try {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .update({
              'photoURL': FieldValue.delete(),
              'profileUpdatedAt': FieldValue.serverTimestamp(),
            });
      } catch (firestoreError) {
        print('Firestore update failed: $firestoreError');
      }
      
      await user.reload();

      setState(() {
        _profileImagePath = null;
        _imageLoadError = false;
        _hasCustomImage = false;
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



  Widget _buildPhoneNumberSection() {
    final user = FirebaseAuth.instance.currentUser;
    
    return FutureBuilder<DocumentSnapshot>(
      future: user != null 
          ? FirebaseFirestore.instance.collection('users').doc(user.uid).get()
          : null,
      builder: (context, snapshot) {
        String? phoneNumber;
        bool isLinked = false;
        
        if (snapshot.hasData && snapshot.data!.exists) {
          final userData = snapshot.data!.data() as Map<String, dynamic>;
          phoneNumber = userData['phone'] as String?;
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
                : const Text('Link your phone number for better security'),
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
            onTap: () {
              if (isLinked) {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const PhoneNumberUpdatePage(),
                  ),
                );
              } else {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const LinkPhonePage(),
                  ),
                );
              }
            },
          ),
        );
      },
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
