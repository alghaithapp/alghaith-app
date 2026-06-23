import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/theme/app_colors.dart';
import '../models/chat_message.dart';
import '../providers/app_provider.dart';
import '../services/chat_service.dart';

class ChatScreen extends StatefulWidget {
  final String threadType;
  final String threadId;
  final String otherPartyName;
  final String? receiverPhone;

  const ChatScreen({
    super.key,
    required this.threadType,
    required this.threadId,
    required this.otherPartyName,
    this.receiverPhone,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  List<ChatMessage> _messages = [];
  bool _isLoading = true;
  bool _isSending = false;
  Timer? _pollTimer;
  String? _sessionPhone;

  @override
  void initState() {
    super.initState();
    _sessionPhone = context.read<AppProvider>().sessionPhone;
    _loadMessages();
    _pollTimer = Timer.periodic(const Duration(seconds: 5), (_) => _loadMessages(silent: true));
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadMessages({bool silent = false}) async {
    if (!silent && mounted) setState(() => _isLoading = true);
    try {
      final messages = await ChatService.fetchMessages(
        threadType: widget.threadType,
        threadId: widget.threadId,
      );
      if (!mounted) return;
      setState(() {
        _messages = messages;
        _isLoading = false;
      });
      _scrollToBottom();
    } catch (_) {
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  Future<void> _sendMessage() async {
    final content = _textController.text.trim();
    if (content.isEmpty || _isSending) return;

    final provider = context.read<AppProvider>();
    final senderPhone = provider.sessionPhone ?? '';
    final local = ChatMessage(
      id: 'local-${DateTime.now().millisecondsSinceEpoch}',
      threadType: widget.threadType,
      threadId: widget.threadId,
      senderPhone: senderPhone,
      receiverPhone: widget.receiverPhone,
      senderName: provider.customerName,
      content: content,
      createdAt: DateTime.now(),
    );

    setState(() {
      _isSending = true;
      _messages = [..._messages, local];
    });
    _textController.clear();
    _scrollToBottom();

    try {
      await ChatService.sendMessage(
        threadType: widget.threadType,
        threadId: widget.threadId,
        content: content,
        receiverPhone: widget.receiverPhone,
        senderName: provider.customerName,
      );
      await _loadMessages(silent: true);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'تعذر إرسال الرسالة، حاول مجدداً',
              style: TextStyle(fontFamily: 'Cairo'),
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 120), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  bool _isMine(ChatMessage msg) {
    final mine = _sessionPhone ?? context.read<AppProvider>().sessionPhone ?? '';
    if (mine.isEmpty) return false;
    return msg.senderPhone.contains(mine.replaceAll('+', '')) ||
        mine.contains(msg.senderPhone.replaceAll('+', '')) ||
        msg.senderPhone == mine;
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            'محادثة مع ${widget.otherPartyName}',
            style: const TextStyle(fontFamily: 'Cairo', fontSize: 16),
          ),
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
        ),
        body: Column(
          children: [
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _messages.isEmpty
                      ? const Center(
                          child: Text(
                            'ابدأ المحادثة الآن داخل التطبيق',
                            style: TextStyle(
                              fontFamily: 'Cairo',
                              color: AppColors.textSecondary,
                            ),
                          ),
                        )
                      : ListView.builder(
                          controller: _scrollController,
                          padding: const EdgeInsets.all(12),
                          itemCount: _messages.length,
                          itemBuilder: (context, index) {
                            final msg = _messages[index];
                            final isMe = _isMine(msg);
                            return Align(
                              alignment:
                                  isMe ? Alignment.centerRight : Alignment.centerLeft,
                              child: Container(
                                margin: const EdgeInsets.symmetric(vertical: 4),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 10,
                                ),
                                constraints: BoxConstraints(
                                  maxWidth: MediaQuery.of(context).size.width * 0.78,
                                ),
                                decoration: BoxDecoration(
                                  color: isMe
                                      ? AppColors.primary
                                      : Colors.grey.shade200,
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: Text(
                                  msg.content,
                                  style: TextStyle(
                                    fontFamily: 'Cairo',
                                    color: isMe ? Colors.white : Colors.black87,
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
            ),
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _textController,
                        textInputAction: TextInputAction.send,
                        onSubmitted: (_) => _sendMessage(),
                        decoration: InputDecoration(
                          hintText: 'اكتب رسالة...',
                          hintStyle: const TextStyle(fontFamily: 'Cairo'),
                          filled: true,
                          fillColor: Colors.grey.shade100,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(22),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 10,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      onPressed: _isSending ? null : _sendMessage,
                      icon: _isSending
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.send_rounded, color: AppColors.primary),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
