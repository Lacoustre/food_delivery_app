import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher_string.dart';

class AboutScreen extends StatefulWidget {
  const AboutScreen({super.key});

  @override
  State<AboutScreen> createState() => _AboutScreenState();
}

class _AboutScreenState extends State<AboutScreen> {
  String _version = '';
  String _build = '';

  @override
  void initState() {
    super.initState();
    _loadInfo();
  }

  Future<void> _loadInfo() async {
    final info = await PackageInfo.fromPlatform();
    setState(() {
      _version = info.version;
      _build = info.buildNumber;
    });
  }

  Future<void> _open(String url) async {
    if (await canLaunchUrlString(url)) {
      await launchUrlString(url, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('About'),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFFE65100),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.article_outlined),
            tooltip: 'Licenses',
            onPressed: () => showLicensePage(
              context: context,
              applicationName: 'Taste of African Cuisine Driver',
              applicationVersion: 'v$_version ($_build)',
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          ListTile(
            leading: const CircleAvatar(child: Icon(Icons.local_dining)),
            title: const Text('Taste of African Cuisine Driver'),
            subtitle: Text('Version $_version (build $_build)'),
          ),
          const SizedBox(height: 8),
          const Text(
            'This app helps drivers deliver authentic African cuisine quickly and reliably.',
            style: TextStyle(fontSize: 14, color: Colors.black87),
          ),
          const SizedBox(height: 24),
          ListTile(
            leading: const Icon(Icons.privacy_tip_outlined),
            title: const Text('Privacy Policy'),
            onTap: () => _open('https://example.com/privacy'),
          ),
          ListTile(
            leading: const Icon(Icons.rule_folder_outlined),
            title: const Text('Terms of Service'),
            onTap: () => _open('https://example.com/terms'),
          ),
          const SizedBox(height: 8),
          const Text(
            '© ${2025} Your Company. All rights reserved.',
            style: TextStyle(color: Colors.grey),
          ),
        ],
      ),
    );
  }
}
