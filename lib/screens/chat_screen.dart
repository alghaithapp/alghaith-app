import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/realtime/realtime_subscription_mixin.dart';
import '../core/theme/app_colors.dart';
import '../core/network/api_exception.dart';
import '../models/chat_message.dart';
import '../providers/app_provider.dart';
import '../utils/call_navigation.dart';
import '../utils/chat_thread_labels.dart';
import '../utils/merchant_profile_fields.dart';
import '../widgets/call_history_sheet.dart';
import '../services/chat_service.dart';
import '../services/chat_thread_refresh.dart';
import '../services/supabase_service.dart';

class ChatScreen extends StatefulWidget {
  final String threadType;
  final String threadId;
  final String otherPartyName;
  final String? receiverPhone;
  final Map<String, dynamic>? merchantProfile;

  const ChatScreen({
    super.key,
    required this.threadType,
    required this.threadId,
    required this.otherPartyName,
    this.receiverPhone,
    this.merchantProfile,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen>
    with WidgetsBindingObserver, RealtimeSubscriptionMixin {
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  List<ChatMessage> _messages = [];
  bool _isLoading = true;
  bool _isSending = false;
  bool _fetchInFlight = false;
  Timer? _pollTimer;
  String? _sessionPhone;

  static const _fastPollInterval = Duration(seconds: 2);
  static const _slowPollInterval = Duration(seconds: 8);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _sessionPhone = context.read<AppProvider>().sessionPhone;
    ChatThreadRefreshHub.instance.register(
      threadType: widget.threadType,
      threadId: widget.threadId,
      onRefresh: _refreshFromExternalEvent,
    );
    _subscribeToRealtime();
    _loadMessages(forceScroll: true);
    _restartPolling(fast: true);
  }

  @override
  void dispose() {
    ChatThreadRefreshHub.instance.unregister(
      threadType: widget.threadType,
      threadId: widget.threadId,
    );
    WidgetsBinding.instance.removeObserver(this);
    _pollTimer?.cancel();
    disposeRealtime();
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _loadMessages(silent: true, forceScroll: true);
      _restartPolling(fast: true);
      return;
    }
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      _restartPolling(fast: false);
    }
  }

  void _subscribeToRealtime() {
    try {
      trackChannel(
        SupabaseService.realtime.subscribeToChatMessages(
          threadType: widget.threadType,
          threadId: widget.threadId,
          onInsert: () => _loadMessages(silent: true),
        ),
      );
    } catch (_) {
      // Realtime اختياري — يبقى polling كاحتياط.
    }
  }

  void _restartPolling({required bool fast}) {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(
      fast ? _fastPollInterval : _slowPollInterval,
      (_) => _loadMessages(silent: true),
    );
  }

  void _refreshFromExternalEvent() {
    if (!mounted) return;
    _loadMessages(silent: true, forceScroll: true);
  }

  Future<void> _loadMessages({
    bool silent = false,
    bool forceScroll = false,
  }) async {
    if (_fetchInFlight) return;
    _fetchInFlight = true;

    if (!silent && mounted) setState(() => _isLoading = true);
    try {
      final previousCount = _messages.length;
      final previousLastId =
          _messages.isNotEmpty ? _messages.last.id : null;

      final messages = await ChatService.fetchMessages(
        threadType: widget.threadType,
        threadId: widget.threadId,
      );
      if (!mounted) return;

      final hasNewMessages = messages.length > previousCount ||
          (messages.isNotEmpty &&
              messages.last.id.isNotEmpty &&
              messages.last.id != previousLastId);

      setState(() {
        _messages = messages;
        _isLoading = false;
      });

      if (hasNewMessages || forceScroll) {
        _scrollToBottom();
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => _isLoading = false);
    } finally {
      _fetchInFlight = false;
    }
  }

  String _senderDisplayName(AppProvider provider) {
    final merchantName = provider.merchantStoreName.trim();
    if (provider.userRole == 'merchant' && merchantName.isNotEmpty) {
      return merchantName;
    }
    final customerName = provider.customerName.trim();
    if (customerName.isNotEmpty) return customerName;
    return 'مستخدم';
  }

  Future<void> _sendMessage() async {
    final content = _textController.text.trim();
    if (content.isEmpty || _isSending) return;

    final provider = context.read<AppProvider>();
    final senderPhone = provider.sessionPhone ?? '';
    final senderName = _senderDisplayName(provider);
    final local = ChatMessage(
      id: 'local-${DateTime.now().millisecondsSinceEpoch}',
      threadType: widget.threadType,
      threadId: widget.threadId,
      senderPhone: senderPhone,
      receiverPhone: widget.receiverPhone,
      senderName: senderName,
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
        senderName: senderName,
      );
      await _loadMessages(silent: true, forceScroll: true);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _messages = _messages.where((m) => m.id != local.id).toList();
      });
      _textController.text = content;
      final message = error is ApiException
          ? error.message
          : 'تعذر إرسال الرسالة، حاول مجدداً';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            message,
            style: const TextStyle(fontFamily: 'Cairo'),
          ),
          duration: const Duration(seconds: 5),
        ),
      );
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    });
  }

  bool _isMine(ChatMessage msg) {
    final mine = _sessionPhone ?? context.read<AppProvider>().sessionPhone ?? '';
    if (mine.isEmpty) return false;
    final normalizedMine = mine.replaceAll(RegExp(r'\D'), '');
    final normalizedSender = msg.senderPhone.replaceAll(RegExp(r'\D'), '');
    if (normalizedMine.isEmpty || normalizedSender.isEmpty) {
      return msg.senderPhone == mine;
    }
    return normalizedMine.endsWith(normalizedSender.substring(
          normalizedSender.length >= 9 ? normalizedSender.length - 9 : 0,
        )) ||
        normalizedSender.endsWith(normalizedMine.substring(
          normalizedMine.length >= 9 ? normalizedMine.length - 9 : 0,
        )) ||
        normalizedMine == normalizedSender;
  }

  bool get _canCall {
    if (widget.receiverPhone?.trim().isEmpty ?? true) return false;
    if (widget.threadType != 'store' && widget.merchantProfile == null) {
      return true;
    }
    return MerchantProfileFields.isAcceptingCustomerCalls(widget.merchantProfile);
  }

  Future<void> _startCall() async {
    final phone = widget.receiverPhone?.trim() ?? '';
    if (phone.isEmpty) return;

    final blocked =
        MerchantProfileFields.callsUnavailableMessageAr(widget.merchantProfile);
    if (blocked != null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            blocked,
            style: const TextStyle(fontFamily: 'Cairo'),
          ),
        ),
      );
      return;
    }

    final provider = context.read<AppProvider>();
    await CallNavigation.openOutgoing(
      context,
      threadType: widget.threadType,
      threadId: widget.threadId,
      otherPartyName: widget.otherPartyName,
      receiverPhone: phone,
      callerName: _senderDisplayName(provider),
      merchantProfile: widget.merchantProfile,
    );
  }

  Future<void> _showCallHistory() async {
    await CallHistorySheet.show(
      context,
      threadType: widget.threadType,
      threadId: widget.threadId,
      otherPartyName: widget.otherPartyName,
      sessionPhone: _sessionPhone ?? context.read<AppProvider>().sessionPhone,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.otherPartyName,
                style: const TextStyle(fontFamily: 'Cairo', fontSize: 16),
              ),
              Text(
                ChatThreadLabels.chatScreenSubtitle(
                  threadType: widget.threadType,
                  threadId: widget.threadId,
                ),
                style: const TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 11,
                  fontWeight: FontWeight.normal,
                ),
              ),
            ],
          ),
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          actions: [
            IconButton(
              onPressed: () => _loadMessages(forceScroll: true),
              icon: const Icon(Icons.refresh),
              tooltip: 'تحديث',
            ),
            IconButton(
              onPressed: _showCallHistory,
              icon: const Icon(Icons.history),
              tooltip: 'سجل المكالمات',
            ),
            if (_canCall)
              IconButton(
                onPressed: _startCall,
                icon: const Icon(Icons.call),
                tooltip: 'اتصال صوتي',
              ),
          ],
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
                              alignment: isMe
                                  ? Alignment.centerRight
                                  : Alignment.centerLeft,
                              child: Container(
                                margin: const EdgeInsets.symmetric(vertical: 4),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 10,
                                ),
                                constraints: BoxConstraints(
                                  maxWidth:
                                      MediaQuery.of(context).size.width * 0.78,
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
                                    color:
                                        isMe ? Colors.white : Colors.black87,
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
                          : const Icon(Icons.send_rounded,
                              color: AppColors.primary),
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
