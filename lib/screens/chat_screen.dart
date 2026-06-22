import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

import '../core/theme/app_colors.dart';
import '../core/config/app_config.dart';
import '../providers/app_provider.dart';

class ChatScreen extends StatefulWidget {
  final String orderId;
  final String otherPartyName;
  final String otherPartyPhone;

  const ChatScreen({
    Key? key,
    required this.orderId,
    required this.otherPartyName,
    required this.otherPartyPhone,
  }) : super(key: key);

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  List<dynamic> _messages = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchMessages();
  }

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _fetchMessages() async {
    final provider = context.read<AppProvider>();
    final token = await provider.getValidToken();
    if (token == null) return;

    try {
      final uri = Uri.parse('\${AppConfig.normalizedDatabaseUrl}/db/chat/\${widget.orderId}');
      final response = await http.get(uri, headers: {
        'Authorization': 'Bearer \$token',
      });
      if (response.statusCode == 200) {
        setState(() {
          _messages = jsonDecode(response.body);
          _isLoading = false;
        });
        _scrollToBottom();
      }
    } catch (e) {
      print('Fetch messages error: \$e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _sendMessage(String type, String content) async {
    final provider = context.read<AppProvider>();
    final token = await provider.getValidToken();
    if (token == null) return;

    final localMsg = {
      'id': DateTime.now().millisecondsSinceEpoch.toString(),
      'message_type': type,
      'content': content,
      'sender_phone': provider.sessionPhone,
      'created_at': DateTime.now().toIso8601String(),
    };
    setState(() {
      _messages.add(localMsg);
    });
    _scrollToBottom();

    try {
      final uri = Uri.parse('\${AppConfig.normalizedDatabaseUrl}/db/chat/\${widget.orderId}');
      await http.post(
        uri,
        headers: {
          'Authorization': 'Bearer \$token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'messageType': type,
          'content': content,
          'receiverPhone': widget.otherPartyPhone,
          'senderName': provider.customerName,
        }),
      );
    } catch (e) {
      print('Send message error: \$e');
    }
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _showComingSoon() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('ميزة الرسائل الصوتية ستتوفر قريباً!', style: TextStyle(fontFamily: 'Cairo')),
        backgroundColor: Colors.orange,
        duration: Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('محادثة مع \${widget.otherPartyName}', style: const TextStyle(fontFamily: 'Cairo', fontSize: 16)),
        backgroundColor: AppColors.primary,
      ),
      body: Column(
        children: [
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(10),
                    itemCount: _messages.length,
                    itemBuilder: (context, index) {
                      final msg = _messages[index];
                      final isMe = msg['sender_phone'] == context.read<AppProvider>().sessionPhone;
                      return Align(
                        alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                        child: Container(
                          margin: const EdgeInsets.symmetric(vertical: 5),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: isMe ? AppColors.primary : Colors.grey.shade300,
                            borderRadius: BorderRadius.circular(15),
                          ),
                          child: Text(
                            msg['content'],
                            style: TextStyle(fontFamily: 'Cairo', color: isMe ? Colors.white : Colors.black),
                          ),
                        ),
                      );
                    },
                  ),
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.mic, color: Colors.grey),
                  onPressed: _showComingSoon,
                ),
                Expanded(
                  child: TextField(
                    controller: _textController,
                    decoration: InputDecoration(
                      hintText: 'اكتب رسالة...',
                      hintStyle: const TextStyle(fontFamily: 'Cairo'),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.send, color: AppColors.primary),
                  onPressed: () {
                    if (_textController.text.trim().isNotEmpty) {
                      _sendMessage('text', _textController.text.trim());
                      _textController.clear();
                    }
                  },
                ),
              ],
            ),
          )
        ],
      ),
    );
  }
}
