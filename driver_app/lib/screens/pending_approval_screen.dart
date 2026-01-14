import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'home_screen.dart';
import '../services/storage_service.dart';

class PendingApprovalScreen extends StatefulWidget {
  const PendingApprovalScreen({super.key});

  @override
  State<PendingApprovalScreen> createState() => _PendingApprovalScreenState();
}

class _PendingApprovalScreenState extends State<PendingApprovalScreen>
    with TickerProviderStateMixin {
  bool _busy = false;
  String _status = 'pending';
  String? _error;
  String? _rejectionReason;
  DateTime? _submittedAt;
  DateTime? _lastUpdated;
  Map<String, dynamic>? _driverData;

  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _sub;
  late AnimationController _pulseController;
  late AnimationController _fadeController;
  late Animation<double> _pulseAnimation;
  late Animation<double> _fadeAnimation;

  Timer? _autoRefreshTimer;
  int _refreshCount = 0;
  static const int _maxAutoRefresh = 10;

  // Status-specific colors and icons
  final Map<String, MaterialColor> _statusColors = {
    'pending': Colors.orange,
    'approved': Colors.green,
    'rejected': Colors.red,
    'under_review': Colors.blue,
    'needs_info': Colors.amber,
  };

  final Map<String, IconData> _statusIcons = {
    'pending': Icons.hourglass_empty,
    'approved': Icons.check_circle,
    'rejected': Icons.cancel,
    'under_review': Icons.visibility,
    'needs_info': Icons.info,
  };

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _start();
    _startAutoRefresh();
  }

  void _initializeAnimations() {
    _pulseController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _pulseAnimation = Tween<double>(begin: 0.8, end: 1.2).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _fadeController, curve: Curves.easeIn));

    _pulseController.repeat(reverse: true);
    _fadeController.forward();
  }

  void _startAutoRefresh() {
    // Auto-refresh every 30 seconds for the first 10 times, then every 5 minutes
    _autoRefreshTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      if (_refreshCount < _maxAutoRefresh && _status == 'pending') {
        _refresh(isAutoRefresh: true);
        _refreshCount++;
      } else {
        // Switch to less frequent refreshes
        timer.cancel();
        _autoRefreshTimer = Timer.periodic(const Duration(minutes: 5), (timer) {
          if (_status == 'pending') {
            _refresh(isAutoRefresh: true);
          }
        });
      }
    });
  }

  Future<void> _start() async {
    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      await _ensureDriverDoc();
      _listenForStatusChanges();
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = _getReadableError(e);
        });
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _getReadableError(dynamic error) {
    final errorStr = error.toString().toLowerCase();
    if (errorStr.contains('permission-denied')) {
      return 'Access denied. Please contact support.';
    } else if (errorStr.contains('network')) {
      return 'Network error. Check your connection and try again.';
    } else if (errorStr.contains('not signed in')) {
      return 'Authentication required. Please sign in again.';
    } else {
      return 'Something went wrong. Please try refreshing.';
    }
  }

  Future<void> _ensureDriverDoc() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw 'Not signed in';

    final ref = FirebaseFirestore.instance.collection('drivers').doc(user.uid);
    final snap = await ref.get();

    if (!snap.exists) {
      // Create new document - approval status should be set during signup
      final base = <String, dynamic>{
        'userId': user.uid,
        'fullName': (user.displayName ?? 'Driver').trim(),
        'email': (user.email ?? '').trim(),
        'phone': (user.phoneNumber ?? '').trim(),
        'approvalStatus': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'source': 'driver-app/pending-screen',
        'applicationStep': 'submitted',
      };
      await ref.set(base, SetOptions(merge: true));
      setState(() {
        _submittedAt = DateTime.now();
      });
      return;
    }

    // Store driver data and extract timestamps
    final data = snap.data()!;
    _driverData = data;

    if (data['createdAt'] != null) {
      _submittedAt = (data['createdAt'] as Timestamp).toDate();
    }
    if (data['updatedAt'] != null) {
      _lastUpdated = (data['updatedAt'] as Timestamp).toDate();
    }

    // Only patch missing critical fields, NEVER override approval status
    final update = <String, dynamic>{};
    if (data['userId'] == null) update['userId'] = user.uid;
    if (data['createdAt'] == null) {
      update['createdAt'] = FieldValue.serverTimestamp();
    }

    // Always update the timestamp when accessing this screen
    update['lastAccessedAt'] = FieldValue.serverTimestamp();
    update['updatedAt'] = FieldValue.serverTimestamp();

    if (update.isNotEmpty) {
      await ref.set(update, SetOptions(merge: true));
    }
  }

  void _listenForStatusChanges() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    _sub?.cancel();
    _sub = FirebaseFirestore.instance
        .collection('drivers')
        .doc(user.uid)
        .snapshots()
        .listen(
          (doc) async {
            if (!doc.exists) return;

            final data = doc.data()!;
            final status = (data['approvalStatus'] as String?) ?? 'pending';
            final rejectionReason = data['rejectionReason'] as String?;

            if (!mounted) return;

            // Cache the approval status
            await StorageService.setDriverApprovalStatus(status);

            final previousStatus = _status;
            setState(() {
              _status = status;
              _rejectionReason = rejectionReason;
              _driverData = data;
              _error = null;

              if (data['updatedAt'] != null) {
                _lastUpdated = (data['updatedAt'] as Timestamp).toDate();
              }
            });

            // Show status change notification
            if (previousStatus != status && previousStatus.isNotEmpty) {
              _showStatusChangeNotification(status);
            }

            // Handle approved status with celebration
            if (status == 'approved') {
              _showApprovalCelebration();
              _autoRefreshTimer?.cancel();

              // Delay navigation to show celebration
              Timer(const Duration(seconds: 2), () {
                if (mounted) {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (_) => const HomeScreen()),
                  );
                }
              });
            }
          },
          onError: (e) {
            if (mounted) {
              setState(() {
                _error = _getReadableError(e);
              });
            }
          },
        );
  }

  void _showStatusChangeNotification(String newStatus) {
    String message =
        'Status updated to ${newStatus.replaceAll('_', ' ').toUpperCase()}';
    Color backgroundColor = _statusColors[newStatus] ?? Colors.blue;

    if (newStatus == 'approved') {
      message = '🎉 Congratulations! Your application has been approved!';
      backgroundColor = Colors.green;
    } else if (newStatus == 'rejected') {
      message = '❌ Your application has been rejected. See details below.';
      backgroundColor = Colors.red;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: backgroundColor,
        duration: const Duration(seconds: 4),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        action: SnackBarAction(
          label: 'OK',
          textColor: Colors.white,
          onPressed: () {},
        ),
      ),
    );
  }

  void _showApprovalCelebration() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.celebration, color: Colors.orange, size: 64),
            const SizedBox(height: 16),
            const Text(
              'Welcome to the team!',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            const Text(
              'Your driver application has been approved. You can now start accepting deliveries!',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 24),
            const LinearProgressIndicator(color: Colors.orange),
            const SizedBox(height: 16),
            const Text(
              'Taking you to your dashboard...',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _refresh({bool isAutoRefresh = false}) async {
    if (!isAutoRefresh) {
      setState(() => _busy = true);
    }

    try {
      await _ensureDriverDoc();
      if (!isAutoRefresh) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Status refreshed'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted && !isAutoRefresh) {
        setState(() => _error = _getReadableError(e));
      }
    } finally {
      if (mounted && !isAutoRefresh) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _signOut() async {
    final confirm = await showDialog<bool>(
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
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Sign Out'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await FirebaseAuth.instance.signOut();
      _autoRefreshTimer?.cancel();
      await _sub?.cancel();
      if (mounted) {
        Navigator.pushReplacementNamed(context, '/auth');
      }
    }
  }

  String _getStatusDescription(String status) {
    switch (status) {
      case 'pending':
        return 'Your application is in our review queue. We\'ll notify you once it\'s been reviewed.';
      case 'under_review':
        return 'An administrator is currently reviewing your application details.';
      case 'approved':
        return 'Congratulations! Your application has been approved. Welcome to the team!';
      case 'rejected':
        return 'Your application has been rejected. Please see the reason below and contact support if needed.';
      case 'needs_info':
        return 'Additional information is required to process your application.';
      default:
        return 'Application status: ${status.replaceAll('_', ' ')}';
    }
  }

  String _getTimeAgo(DateTime? dateTime) {
    if (dateTime == null) return 'Unknown';

    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays > 0) {
      return '${difference.inDays} day${difference.inDays > 1 ? 's' : ''} ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} hour${difference.inHours > 1 ? 's' : ''} ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes} minute${difference.inMinutes > 1 ? 's' : ''} ago';
    } else {
      return 'Just now';
    }
  }

  Widget _buildStatusCard() {
    final color = _statusColors[_status] ?? Colors.grey;
    final icon = _statusIcons[_status] ?? Icons.help;

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            colors: [color.shade50, Colors.white],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Column(
          children: [
            // Status Icon with animation
            if (_status == 'pending')
              AnimatedBuilder(
                animation: _pulseAnimation,
                builder: (context, child) => Transform.scale(
                  scale: _pulseAnimation.value,
                  child: Icon(icon, size: 64, color: color),
                ),
              )
            else
              Icon(icon, size: 64, color: color),

            const SizedBox(height: 16),

            // Status Title
            Text(
              _status == 'approved'
                  ? 'Application Approved!'
                  : _status == 'rejected'
                  ? 'Application Rejected'
                  : 'Application ${_status.replaceAll('_', ' ').toUpperCase()}',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: color.shade800,
              ),
              textAlign: TextAlign.center,
            ),

            const SizedBox(height: 8),

            // Status Description
            Text(
              _getStatusDescription(_status),
              style: const TextStyle(
                fontSize: 16,
                color: Colors.grey,
                height: 1.4,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimelineCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Application Timeline',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),

            // Timeline entries
            _buildTimelineEntry(
              'Application Submitted',
              _getTimeAgo(_submittedAt),
              Icons.send,
              Colors.blue,
              isCompleted: true,
            ),

            _buildTimelineEntry(
              'Under Review',
              _status == 'pending' ? 'Waiting...' : _getTimeAgo(_lastUpdated),
              Icons.visibility,
              Colors.orange,
              isCompleted: _status != 'pending',
            ),

            _buildTimelineEntry(
              'Decision',
              _status == 'approved'
                  ? 'Approved!'
                  : _status == 'rejected'
                  ? 'Rejected'
                  : 'Pending...',
              _status == 'approved'
                  ? Icons.check_circle
                  : _status == 'rejected'
                  ? Icons.cancel
                  : Icons.hourglass_empty,
              _status == 'approved'
                  ? Colors.green
                  : _status == 'rejected'
                  ? Colors.red
                  : Colors.grey,
              isCompleted: _status == 'approved' || _status == 'rejected',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimelineEntry(
    String title,
    String subtitle,
    IconData icon,
    MaterialColor color, {
    bool isCompleted = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isCompleted ? color : Colors.grey.shade300,
            ),
            child: Icon(
              icon,
              color: isCompleted ? Colors.white : Colors.grey,
              size: 20,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: isCompleted ? Colors.black87 : Colors.grey,
                  ),
                ),
                Text(
                  subtitle,
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRejectionCard() {
    if (_status != 'rejected' || _rejectionReason == null) {
      return const SizedBox.shrink();
    }

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.red.shade200),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.error_outline, color: Colors.red.shade700),
                const SizedBox(width: 8),
                const Text(
                  'Rejection Reason',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              _rejectionReason!,
              style: const TextStyle(fontSize: 14, height: 1.4),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.support_agent),
                    label: const Text('Contact Support'),
                    onPressed: () {
                      // Implement contact support functionality
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Support contact feature coming soon'),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.refresh),
                    label: const Text('Reapply'),
                    onPressed: () {
                      // Implement reapplication functionality
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Reapplication process coming soon'),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _fadeController.dispose();
    _autoRefreshTimer?.cancel();
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        Navigator.pushReplacementNamed(context, '/auth');
        return false;
      },
      child: Scaffold(
        backgroundColor: Colors.grey.shade50,
        appBar: AppBar(
          title: const Text('Account Review'),
          backgroundColor: Colors.white,
          elevation: 0,
          foregroundColor: Colors.black87,
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _busy ? null : () => _refresh(),
              tooltip: 'Refresh status',
            ),
            PopupMenuButton(
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'help',
                  child: ListTile(
                    leading: Icon(Icons.help_outline),
                    title: Text('Help & FAQ'),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
                const PopupMenuItem(
                  value: 'contact',
                  child: ListTile(
                    leading: Icon(Icons.support_agent),
                    title: Text('Contact Support'),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
                const PopupMenuItem(
                  value: 'signout',
                  child: ListTile(
                    leading: Icon(Icons.logout, color: Colors.red),
                    title: Text(
                      'Sign Out',
                      style: TextStyle(color: Colors.red),
                    ),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ],
              onSelected: (value) {
                switch (value) {
                  case 'signout':
                    _signOut();
                    break;
                  case 'help':
                  case 'contact':
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Feature coming soon')),
                    );
                    break;
                }
              },
            ),
          ],
        ),
        body: FadeTransition(
          opacity: _fadeAnimation,
          child: RefreshIndicator(
            onRefresh: () => _refresh(),
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Main Status Card
                  _buildStatusCard(),

                  const SizedBox(height: 20),

                  // Timeline Card
                  _buildTimelineCard(),

                  const SizedBox(height: 20),

                  // Rejection Card (if applicable)
                  _buildRejectionCard(),

                  // Error Display
                  if (_error != null) ...[
                    Card(
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.red.shade200),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.error_outline,
                                  color: Colors.red.shade700,
                                ),
                                const SizedBox(width: 8),
                                const Text(
                                  'Error',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              _error!,
                              style: const TextStyle(color: Colors.red),
                            ),
                            const SizedBox(height: 16),
                            ElevatedButton.icon(
                              icon: const Icon(Icons.refresh),
                              label: const Text('Try Again'),
                              onPressed: _busy ? null : () => _refresh(),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],

                  // Tips Card
                  Card(
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.lightbulb_outline,
                                color: Colors.amber.shade700,
                              ),
                              const SizedBox(width: 8),
                              const Text(
                                'Tips',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            '• Review times typically range from 24-72 hours\n'
                            '• Make sure all required documents are submitted\n'
                            '• Check your email for any additional requests\n'
                            '• This screen updates automatically when your status changes',
                            style: TextStyle(fontSize: 14, height: 1.4),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Loading indicator
                  if (_busy)
                    const Center(
                      child: Card(
                        child: Padding(
                          padding: EdgeInsets.all(16),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              CircularProgressIndicator(strokeWidth: 2),
                              SizedBox(width: 16),
                              Text('Refreshing...'),
                            ],
                          ),
                        ),
                      ),
                    ),

                  const SizedBox(height: 16),

                  // Footer info
                  Center(
                    child: Text(
                      'Last updated: ${_getTimeAgo(_lastUpdated)}',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
