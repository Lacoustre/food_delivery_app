import 'package:flutter/material.dart';

class LiveChatSupportPage extends StatefulWidget {
  const LiveChatSupportPage({super.key});

  @override
  State<LiveChatSupportPage> createState() => _LiveChatSupportPageState();
}

class _LiveChatSupportPageState extends State<LiveChatSupportPage> {
  final List<Map<String, String>> _messages = [
    {"sender": "support", "text": "👋🏾 Hello! How can we help you today?"},
  ];
  final TextEditingController _controller = TextEditingController();

  void _sendMessage() {
    final message = _controller.text.trim();
    if (message.isEmpty) return;

    setState(() {
      _messages.add({"sender": "user", "text": message});
      _controller.clear();
    });

    Future.delayed(const Duration(seconds: 1), () {
      setState(() {
        _messages.add({
          "sender": "support",
          "text": "😊 Thank you for reaching out! We’ll respond shortly.",
        });
      });
    });
  }

  Widget _buildMessage(Map<String, String> msg) {
    final isUser = msg["sender"] == "user";
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        constraints: const BoxConstraints(maxWidth: 280),
        decoration: BoxDecoration(
          color: isUser ? Colors.deepOrange : Colors.grey[200],
          borderRadius: BorderRadius.circular(20), // ✅ Rounded bubble
        ),
        child: Text(
          msg["text"]!,
          style: TextStyle(
            color: isUser ? Colors.white : Colors.black87,
            fontSize: 15,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.deepOrange,
        title: Row(
          children: [
            Image.asset('assets/images/logo.png', height: 34),
            const SizedBox(width: 10),
            const Text('Live Chat Support'),
          ],
        ),
      ),
      body: Column(
        children: [
          const Padding(
            padding: EdgeInsets.all(12),
            child: Text(
              'Business Hours: 12 PM – 7 PM (Closed on Mondays)',
              style: TextStyle(fontSize: 14, color: Colors.grey),
            ),
          ),
          const Divider(),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              itemCount: _messages.length,
              itemBuilder: (context, index) => _buildMessage(_messages[index]),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(30),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: TextField(
                        controller: _controller,
                        decoration: const InputDecoration(
                          hintText: "Type a message...",
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 12,
                          ),
                          border: InputBorder.none,
                        ),
                        textCapitalization: TextCapitalization.sentences,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  CircleAvatar(
                    backgroundColor: Colors.deepOrange,
                    child: IconButton(
                      icon: const Icon(Icons.send, color: Colors.white),
                      onPressed: _sendMessage,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
