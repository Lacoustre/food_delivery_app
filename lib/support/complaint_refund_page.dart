import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fluttertoast/fluttertoast.dart';

class ComplaintRefundPage extends StatefulWidget {
  const ComplaintRefundPage({super.key});

  @override
  State<ComplaintRefundPage> createState() => _ComplaintRefundPageState();
}

class _ComplaintRefundPageState extends State<ComplaintRefundPage> {
  final _formKey = GlobalKey<FormState>();
  final _orderIdController = TextEditingController();
  final _detailsController = TextEditingController();

  final List<String> _reasons = [
    'Wrong Order',
    'Missing Item',
    'Late Delivery',
    'Poor Quality',
    'Other',
  ];
  String? _selectedReason;

  Future<void> _submitComplaint() async {
    if (!_formKey.currentState!.validate()) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('complaints')
          .add({
            'reason': _selectedReason,
            'details': _detailsController.text.trim(),
            'orderId': _orderIdController.text.trim(),
            'timestamp': FieldValue.serverTimestamp(),
            'status': 'Pending',
          });

      Fluttertoast.showToast(msg: "Complaint submitted successfully");
      Navigator.pop(context);
    } catch (e) {
      Fluttertoast.showToast(msg: "Error: ${e.toString()}");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Complaint / Refund Request"),
        backgroundColor: Colors.deepOrange,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            // ✅ Top Logo or Banner
            Image.asset('assets/images/logo.png', height: 200),
            const SizedBox(height: 16),
            const Text(
              "Tell us what went wrong",
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              "We value your feedback. Please provide details below so we can resolve the issue.",
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 24),
            Form(
              key: _formKey,
              child: Column(
                children: [
                  DropdownButtonFormField<String>(
                    value: _selectedReason,
                    hint: const Text("Select Reason"),
                    decoration: const InputDecoration(
                      labelText: "Reason",
                      border: OutlineInputBorder(),
                    ),
                    items: _reasons
                        .map(
                          (reason) => DropdownMenuItem(
                            value: reason,
                            child: Text(reason),
                          ),
                        )
                        .toList(),
                    onChanged: (val) => setState(() => _selectedReason = val),
                    validator: (val) =>
                        val == null ? 'Please select a reason' : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _orderIdController,
                    decoration: const InputDecoration(
                      labelText: "Order ID (Optional)",
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _detailsController,
                    maxLines: 5,
                    decoration: const InputDecoration(
                      labelText: "Details",
                      alignLabelWithHint: true,
                      border: OutlineInputBorder(),
                    ),
                    validator: (val) =>
                        val!.trim().isEmpty ? 'Details required' : null,
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _submitComplaint,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.deepOrange,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      icon: const Icon(Icons.send),
                      label: const Text("Submit Complaint"),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
