import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _notifications = true;
  bool _biometric = false;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _notifications = prefs.getBool('notifications_enabled') ?? true;
      _biometric = prefs.getBool('biometric_enabled') ?? false;
      _loading = false;
    });
  }

  Future<void> _save(String key, bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(key, value);
  }

  Future<void> _sendPasswordReset() async {
    final user = FirebaseAuth.instance.currentUser;
    final email = user?.email;
    if (email == null || email.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No email on account.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Password reset sent to $email'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to send reset: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFFE65100),
        elevation: 0,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              children: [
                const SizedBox(height: 8),
                SwitchListTile(
                  title: const Text('Push notifications'),
                  subtitle: const Text('Order updates & announcements'),
                  activeColor: const Color(0xFFE65100),
                  value: _notifications,
                  onChanged: (v) {
                    setState(() => _notifications = v);
                    _save('notifications_enabled', v);
                  },
                ),
                const Divider(height: 1),
                SwitchListTile(
                  title: const Text('Enable biometrics'),
                  subtitle: const Text('Use fingerprint/FaceID to sign in'),
                  activeColor: const Color(0xFFE65100),
                  value: _biometric,
                  onChanged: (v) {
                    setState(() => _biometric = v);
                    _save('biometric_enabled', v);
                  },
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.lock_reset),
                  title: const Text('Change password'),
                  subtitle: const Text('Send password reset email'),
                  onTap: _sendPasswordReset,
                ),
              ],
            ),
    );
  }
}
