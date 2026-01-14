import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher_string.dart';

class HelpSupportScreen extends StatelessWidget {
  const HelpSupportScreen({super.key});

  Future<void> _emailSupport(BuildContext context) async {
    const email = 'support@yourapp.com';
    final subject = Uri.encodeComponent('Driver Support Request');
    final body = Uri.encodeComponent('Describe your issue here...');
    final uri = 'mailto:$email?subject=$subject&body=$body';
    if (await canLaunchUrlString(uri)) {
      await launchUrlString(uri);
    } else {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Could not open email app')));
    }
  }

  Future<void> _callSupport(BuildContext context) async {
    const number = '+11234567890';
    final uri = 'tel:$number';
    if (await canLaunchUrlString(uri)) {
      await launchUrlString(uri);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Calling not supported on this device')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final items = <Map<String, String>>[
      {
        'q': 'How do I go online/offline?',
        'a':
            'On the Dashboard, use the toggle in the status card. You can only go online after your account is approved.',
      },
      {
        'q': 'What order statuses mean?',
        'a':
            'Assigned → Accept the order. Accepted → Head to pickup. Picked Up → Deliver to customer. Delivered → You\'re done!',
      },
      {
        'q': 'When do I get paid?',
        'a':
            'Payments are processed per delivery and summarized in the Earnings tab. Your payout schedule depends on your agreement.',
      },
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Help & Support'),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFFE65100),
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'FAQs',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFFE65100),
            ),
          ),
          const SizedBox(height: 12),
          ...items.map(
            (it) => Card(
              elevation: 0,
              child: ExpansionTile(
                title: Text(it['q']!),
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    child: Text(
                      it['a']!,
                      style: const TextStyle(color: Colors.black87),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'Contact us',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFFE65100),
            ),
          ),
          const SizedBox(height: 8),
          ListTile(
            leading: const Icon(Icons.email_outlined),
            title: const Text('Email support'),
            subtitle: const Text('support@yourapp.com'),
            onTap: () => _emailSupport(context),
          ),
          ListTile(
            leading: const Icon(Icons.call_outlined),
            title: const Text('Call support'),
            subtitle: const Text('+1 123 456 7890'),
            onTap: () => _callSupport(context),
          ),
        ],
      ),
    );
  }
}
