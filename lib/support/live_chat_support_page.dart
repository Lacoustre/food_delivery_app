import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Live chat backed by Supabase support_chats/support_messages — the same
/// tables the admin panel's Support page streams, so both sides see one
/// conversation. The welcome greeting is rendered as a static bubble (RLS
/// forbids a customer inserting an admin-typed message row).
class LiveChatSupportPage extends StatefulWidget {
  const LiveChatSupportPage({super.key});

  @override
  State<LiveChatSupportPage> createState() => _LiveChatSupportPageState();
}

class _LiveChatSupportPageState extends State<LiveChatSupportPage> {
  final TextEditingController _controller = TextEditingController();
  final SupabaseClient _supabase = Supabase.instance.client;
  String? _chatId;

  static const _welcomeText =
      '👋🏾 Hello! Welcome to Taste of African Cuisine. This is Irene, how can I help you today?';

  @override
  void initState() {
    super.initState();
    _initializeChat();
  }

  Future<void> _initializeChat() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return;

      final existing = await _supabase
          .from('support_chats')
          .select('id')
          .eq('customer_id', user.id)
          .eq('status', 'active')
          .limit(1)
          .maybeSingle();

      if (existing != null) {
        setState(() => _chatId = existing['id'] as String);
      } else {
        final chat = await _supabase
            .from('support_chats')
            .insert({
              'customer_id': user.id,
              'last_message': 'Chat started',
              'last_message_time': DateTime.now().toIso8601String(),
              'unread_count': 0,
              'status': 'active',
            })
            .select('id')
            .single();

        setState(() => _chatId = chat['id'] as String);
      }
    } catch (e) {
      debugPrint('🔥 Error initializing chat: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to load chat: $e')));
    }
  }

  Future<void> _sendMessage() async {
    final message = _controller.text.trim();
    final user = _supabase.auth.currentUser;
    if (message.isEmpty || _chatId == null || user == null) return;

    try {
      await _supabase.from('support_messages').insert({
        'chat_id': _chatId,
        'sender_id': user.id,
        'sender_type': 'customer',
        'message': message,
        'read': false,
      });

      final chat = await _supabase
          .from('support_chats')
          .select('unread_count')
          .eq('id', _chatId!)
          .single();
      await _supabase.from('support_chats').update({
        'last_message': message,
        'last_message_time': DateTime.now().toIso8601String(),
        'unread_count': ((chat['unread_count'] as int?) ?? 0) + 1,
      }).eq('id', _chatId!);

      _controller.clear();
    } catch (e) {
      debugPrint('🔥 Error sending message: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to send message: $e')));
    }
  }

  Future<void> _endChat() async {
    if (_chatId == null) return;

    try {
      await _supabase.from('support_chats').update({
        'status': 'closed',
        'last_message': 'Chat ended by customer',
        'last_message_time': DateTime.now().toIso8601String(),
      }).eq('id', _chatId!);

      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Chat ended successfully')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to end chat: $e')),
      );
    }
  }

  Widget _buildBubble({
    required String message,
    required bool isUser,
    DateTime? time,
  }) {
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
              message,
              style: TextStyle(
                color: isUser ? Colors.white : Colors.black87,
                fontSize: 15,
              ),
            ),
            if (time != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  DateFormat('h:mm a').format(time.toLocal()),
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

  Widget _buildMessage(Map<String, dynamic> msg) {
    final isUser = msg['sender_type'] == 'customer';
    final createdAt = msg['created_at'] as String?;
    return _buildBubble(
      message: msg['message'] as String? ?? '',
      isUser: isUser,
      time: createdAt != null ? DateTime.tryParse(createdAt) : null,
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
              'Business Hours: Tue-Sat 11 AM – 9 PM (Fri to 8 PM)',
              style: TextStyle(fontSize: 14, color: Colors.grey),
            ),
          ),
          const Divider(),
          Expanded(
            child: _chatId == null
                ? const Center(child: CircularProgressIndicator())
                : StreamBuilder<List<Map<String, dynamic>>>(
                    stream: _supabase
                        .from('support_messages')
                        .stream(primaryKey: ['id'])
                        .eq('chat_id', _chatId!)
                        .order('created_at', ascending: true),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }

                      if (snapshot.hasError) {
                        return Center(child: Text('Error: ${snapshot.error}'));
                      }

                      final messages = snapshot.data ?? [];

                      return ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        itemCount: messages.length + 1,
                        itemBuilder: (context, index) {
                          if (index == 0) {
                            // Static greeting — not a DB row
                            return _buildBubble(
                              message: _welcomeText,
                              isUser: false,
                            );
                          }
                          return _buildMessage(messages[index - 1]);
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
