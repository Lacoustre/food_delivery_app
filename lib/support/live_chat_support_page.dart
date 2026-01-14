import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

class LiveChatSupportPage extends StatefulWidget {
  const LiveChatSupportPage({super.key});

  @override
  State<LiveChatSupportPage> createState() => _LiveChatSupportPageState();
}

class _LiveChatSupportPageState extends State<LiveChatSupportPage> {
  final TextEditingController _controller = TextEditingController();
  String? _chatId;
  User? user;

  @override
  void initState() {
    super.initState();
    FirebaseAuth.instance.authStateChanges().listen((u) {
      if (u != null) {
        setState(() => user = u);
        _initializeChat();
      }
    });
  }

  Future<void> _initializeChat() async {
    try {
      if (user == null) return;

      final existingChats = await FirebaseFirestore.instance
          .collection('support_chats')
          .where('customerId', isEqualTo: user!.uid)
          .where('status', isEqualTo: 'active')
          .get();

      if (existingChats.docs.isNotEmpty) {
        setState(() => _chatId = existingChats.docs.first.id);
      } else {
        final chatDoc = await FirebaseFirestore.instance
            .collection('support_chats')
            .add({
              'customerId': user!.uid,
              'customerName': user!.displayName ?? user!.email ?? 'Customer',
              'customerEmail': user!.email ?? '',
              'lastMessage': 'Chat started',
              'lastMessageTime': FieldValue.serverTimestamp(),
              'unreadCount': 0,
              'status': 'active',
              'createdAt': FieldValue.serverTimestamp(),
            });

        await FirebaseFirestore.instance.collection('support_messages').add({
          'chatId': chatDoc.id,
          'senderId': 'admin',
          'senderType': 'admin',
          'message':
              '👋🏾 Hello! Welcome to Taste of African Cuisine. This is Irene, how can I help you today?',
          'timestamp': FieldValue.serverTimestamp(),
          'read': false,
        });

        setState(() => _chatId = chatDoc.id);
      }
    } catch (e) {
      debugPrint('🔥 Error initializing chat: $e');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to load chat: $e')));
    }
  }

  Future<void> _sendMessage() async {
    final message = _controller.text.trim();
    if (message.isEmpty || _chatId == null || user == null) return;

    try {
      await FirebaseFirestore.instance.collection('support_messages').add({
        'chatId': _chatId,
        'senderId': user!.uid,
        'senderType': 'customer',
        'message': message,
        'timestamp': FieldValue.serverTimestamp(),
        'read': false,
      });

      await FirebaseFirestore.instance
          .collection('support_chats')
          .doc(_chatId)
          .update({
            'lastMessage': message,
            'lastMessageTime': FieldValue.serverTimestamp(),
            'unreadCount': FieldValue.increment(1),
          });

      _controller.clear();
    } catch (e) {
      debugPrint('🔥 Error sending message: $e');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to send message: $e')));
    }
  }

  Future<void> _endChat() async {
    if (_chatId == null) return;
    
    try {
      await FirebaseFirestore.instance
          .collection('support_chats')
          .doc(_chatId)
          .update({
            'status': 'closed',
            'lastMessage': 'Chat ended by customer',
            'lastMessageTime': FieldValue.serverTimestamp(),
          });
      
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Chat ended successfully')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to end chat: $e')),
      );
    }
  }

  Widget _buildMessage(Map<String, dynamic> msg) {
    final isUser = msg['senderType'] == 'customer';
    final timestamp = msg['timestamp'] as Timestamp?;

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        constraints: const BoxConstraints(maxWidth: 280),
        decoration: BoxDecoration(
          color: isUser ? Colors.deepOrange : Colors.grey[200],
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              msg['message'] ?? '',
              style: TextStyle(
                color: isUser ? Colors.white : Colors.black87,
                fontSize: 15,
              ),
            ),
            if (timestamp != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  DateFormat('h:mm a').format(timestamp.toDate()),
                  style: TextStyle(
                    color: isUser ? Colors.white70 : Colors.grey[600],
                    fontSize: 12,
                  ),
                ),
              ),
          ],
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
        actions: [
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: () {
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('End Chat'),
                  content: const Text('Are you sure you want to end this chat?'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Cancel'),
                    ),
                    TextButton(
                      onPressed: () {
                        Navigator.pop(context);
                        _endChat();
                      },
                      child: const Text('End Chat'),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          const Padding(
            padding: EdgeInsets.all(12),
            child: Text(
              'Business Hours: 12 PM – 8 PM (Closed on Mondays)',
              style: TextStyle(fontSize: 14, color: Colors.grey),
            ),
          ),
          const Divider(),
          Expanded(
            child: _chatId == null
                ? const Center(child: CircularProgressIndicator())
                : StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('support_messages')
                        .where('chatId', isEqualTo: _chatId)
                        .orderBy('timestamp', descending: false)
                        .snapshots(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }

                      if (snapshot.hasError) {
                        return Center(child: Text('Error: ${snapshot.error}'));
                      }

                      final messages = snapshot.data?.docs ?? [];
                      if (messages.isEmpty) {
                        return const Center(
                          child: Text('No messages yet. Say hi 👋🦾'),
                        );
                      }

                      return ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        itemCount: messages.length,
                        itemBuilder: (context, index) {
                          final msg =
                              messages[index].data() as Map<String, dynamic>;
                          return _buildMessage(msg);
                        },
                      );
                    },
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
