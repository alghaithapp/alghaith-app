import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/realtime/realtime_subscription_mixin.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/network/api_exception.dart';
import '../../../models/chat_message.dart';
import '../../../providers/app_provider.dart';
import '../../../utils/call_navigation.dart';
import '../../../utils/chat_thread_labels.dart';
import '../../../utils/helpers.dart';
import '../../../utils/merchant_profile_fields.dart';
import '../../../widgets/app_image.dart';
import '../../../widgets/call_history_sheet.dart';
import '../../../services/image_storage_service.dart';
import '../../../services/incoming_call_coordinator.dart';
import '../../../services/voice_call_service.dart';
import '../../../services/feature_config.dart';
import '../services/chat_service.dart';
import '../services/chat_thread_refresh.dart';
import '../services/socket_service.dart';
import '../utils/chat_message_presenter.dart';
import '../widgets/sticker_picker_sheet.dart';
import '../../../services/supabase_service.dart';

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
  final Map<String, String> _localImagePaths = {};
  bool _isLoading = true;
  bool _isLoadingOlder = false;
  bool _hasMoreOlder = true;
  bool _isSending = false;
  bool _fetchInFlight = false;
  bool _fetchNewInFlight = false;
  Timer? _pollTimer;
  Timer? _callPollTimer;
  final Set<String> _handledIncomingCallIds = {};
  String? _sessionPhone;

  final SocketService _socketService = SocketService();
  StreamSubscription? _socketSub;

  static const _initialLimit = 30;
  static const _loadMoreLimit = 30;
  static const _fastPollInterval = Duration(seconds: 20);
  static const _slowPollInterval = Duration(seconds: 120);

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

    if (FeatureConfig().chatV2) {
      final room = '${widget.threadType}:${widget.threadId}';
      _socketService.connect(room);
      _socketSub = _socketService.onMessage.listen((ChatMessage msg) {
        if (!mounted) return;
        if (_messages.any((m) => m.id == msg.id)) return;
        setState(() {
          _messages = [..._messages, msg];
        });
        _scrollToBottom();
        _markThreadRead();
      });
    }
    _loadInitialMessages();
    _restartPolling(fast: true);
    _startIncomingCallPolling();
  }

  @override
  void dispose() {
    ChatThreadRefreshHub.instance.unregister(
      threadType: widget.threadType,
      threadId: widget.threadId,
    );
    WidgetsBinding.instance.removeObserver(this);
    _pollTimer?.cancel();
    _callPollTimer?.cancel();
    _socketSub?.cancel();
    _socketService.disconnect();
    _scrollController.removeListener(_onScroll);
    disposeRealtime();
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant ChatScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.threadType == widget.threadType &&
        oldWidget.threadId == widget.threadId) {
      return;
    }

    ChatThreadRefreshHub.instance.unregister(
      threadType: oldWidget.threadType,
      threadId: oldWidget.threadId,
    );
    ChatThreadRefreshHub.instance.register(
      threadType: widget.threadType,
      threadId: widget.threadId,
      onRefresh: _refreshFromExternalEvent,
    );

    disposeRealtime();
    _pollTimer?.cancel();
    _callPollTimer?.cancel();
    _socketSub?.cancel();
    _socketService.disconnect();
    _handledIncomingCallIds.clear();
    _messages = [];
    _isLoading = true;
    _hasMoreOlder = true;
    _isSending = false;
    _textController.clear();
    _subscribeToRealtime();
    if (FeatureConfig().chatV2) {
      final room = '${widget.threadType}:${widget.threadId}';
      _socketService.connect(room);
      _socketSub = _socketService.onMessage.listen((msg) {
        if (!mounted) return;
        if (_messages.any((m) => m.id == msg.id)) return;
        setState(() {
          _messages = [..._messages, msg];
        });
        _scrollToBottom();
        _markThreadRead();
      });
    }
    _loadInitialMessages();
    _restartPolling(fast: true);
    _startIncomingCallPolling();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _pollNewMessages();
      _restartPolling(fast: true);
      _startIncomingCallPolling();
      return;
    }
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      _restartPolling(fast: false);
      _callPollTimer?.cancel();
    }
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    if (_isLoadingOlder || !_hasMoreOlder) return;
    if (_scrollController.position.pixels <= 100.0) {
      _loadOlderMessages();
    }
  }

  void _startIncomingCallPolling() {
    _callPollTimer?.cancel();
    _callPollTimer = Timer.periodic(const Duration(seconds: 8), (_) {
      unawaited(_pollIncomingCalls());
    });
    unawaited(_pollIncomingCalls());
  }

  Future<void> _pollIncomingCalls() async {
    try {
      final pending = await VoiceCallService.fetchPendingCalls();
      for (final record in pending) {
        final callId = record['id']?.toString() ?? '';
        if (callId.isEmpty || _handledIncomingCallIds.contains(callId)) continue;

        final threadType = record['thread_type']?.toString() ?? '';
        final threadId = record['thread_id']?.toString() ?? '';
        if (threadType != widget.threadType || threadId != widget.threadId) {
          continue;
        }

        final status = record['status']?.toString() ?? '';
        if (status != 'ringing') continue;

        _handledIncomingCallIds.add(callId);
        if (_handledIncomingCallIds.length > 16) {
          _handledIncomingCallIds.remove(_handledIncomingCallIds.first);
        }

        IncomingCallCoordinator.present({
          'eventKey': 'call:incoming',
          'threadType': threadType,
          'threadId': threadId,
          'channelName': record['channel_name']?.toString() ?? '',
          'callerName': record['caller_name']?.toString() ?? 'متصل',
          'callerPhone': record['caller_phone']?.toString() ?? '',
          'callLogId': callId,
        });
        break;
      }
    } catch (_) {
      // الاستطلاع احتياطي — لا يعطل المحادثة.
    }
  }

  void _subscribeToRealtime() {
    try {
      trackChannel(
        SupabaseService.realtime.subscribeToChatMessages(
          threadType: widget.threadType,
          threadId: widget.threadId,
          onInsert: () => _pollNewMessages(),
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
      (_) => _pollNewMessages(),
    );
  }

  void _refreshFromExternalEvent() {
    if (!mounted) return;
    _pollNewMessages();
  }

  Future<void> _loadInitialMessages() async {
    if (_fetchInFlight) return;
    _fetchInFlight = true;

    if (mounted) setState(() => _isLoading = true);
    try {
      final messages = await ChatService.fetchMessages(
        threadType: widget.threadType,
        threadId: widget.threadId,
        limit: _initialLimit,
        offset: 0,
      );
      if (!mounted) return;

      setState(() {
        _messages = messages.reversed.toList();
        _hasMoreOlder = messages.length >= _initialLimit;
        _isLoading = false;
      });

      _scrollToBottom();
      await _markThreadRead();
    } catch (_) {
      if (!mounted) return;
      setState(() => _isLoading = false);
    } finally {
      _fetchInFlight = false;
    }
  }

  Future<void> _loadOlderMessages() async {
    if (_isLoadingOlder || !_hasMoreOlder || _fetchInFlight) return;
    _isLoadingOlder = true;

    final offset = _messages.length;
    if (mounted) setState(() => _isLoadingOlder = true);
    try {
      final messages = await ChatService.fetchMessages(
        threadType: widget.threadType,
        threadId: widget.threadId,
        limit: _loadMoreLimit,
        offset: offset,
      );
      if (!mounted) return;

      final reversed = messages.reversed.toList();
      setState(() {
        _messages = [...reversed, ..._messages];
        _hasMoreOlder = messages.length >= _loadMoreLimit;
        _isLoadingOlder = false;
      });
      await _markThreadRead();
    } catch (_) {
      if (!mounted) return;
      setState(() => _isLoadingOlder = false);
    } finally {
      _isLoadingOlder = false;
    }
  }

  Future<void> _pollNewMessages() async {
    if (_fetchNewInFlight || _messages.isEmpty) return;
    _fetchNewInFlight = true;

    final newest = _messages.last;
    final afterTimestamp = newest.createdAt?.toIso8601String();
    if (afterTimestamp == null) {
      _fetchNewInFlight = false;
      return;
    }
    try {
      final messages = await ChatService.fetchMessages(
        threadType: widget.threadType,
        threadId: widget.threadId,
        limit: _initialLimit,
        after: afterTimestamp,
      );
      if (!mounted || messages.isEmpty) return;

      final reversed = messages.reversed.toList();
      setState(() {
        _messages = [..._messages, ...reversed];
      });
      _scrollToBottom();
      await _markThreadRead();
    } catch (_) {
      // silent
    } finally {
      _fetchNewInFlight = false;
    }
  }

  Future<void> _markThreadRead() async {
    try {
      await ChatService.markThreadRead(
        threadType: widget.threadType,
        threadId: widget.threadId,
        otherPartyPhone: widget.receiverPhone,
      );
    } catch (_) {}
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
      await _pollNewMessages();
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
    if (!mounted) return;
    await _pollNewMessages();
  }

  Future<void> _openStickerPicker() async {
    if (_isSending) return;
    await StickerPickerSheet.show(
      context,
      onStickerSelected: _sendSticker,
    );
  }

  Future<void> _pickAndSendImage() async {
    if (_isSending) return;

    final picked = await AppHelpers.pickImage(context);
    if (picked == null || !mounted) return;

    final provider = context.read<AppProvider>();
    final senderPhone = provider.sessionPhone ?? '';
    if (senderPhone.isEmpty) return;

    final senderName = _senderDisplayName(provider);
    final localId = 'local-${DateTime.now().millisecondsSinceEpoch}';
    final local = ChatMessage(
      id: localId,
      threadType: widget.threadType,
      threadId: widget.threadId,
      senderPhone: senderPhone,
      receiverPhone: widget.receiverPhone,
      senderName: senderName,
      messageType: 'image',
      content: picked.path,
      createdAt: DateTime.now(),
    );

    setState(() {
      _isSending = true;
      _localImagePaths[localId] = picked.path;
      _messages = [..._messages, local];
    });
    _scrollToBottom();

    try {
      final imageUrl = await ImageStorageService.uploadImageFile(
        File(picked.path),
        role: 'chat',
        ownerType: 'user',
        ownerId: senderPhone,
      );
      if (imageUrl == null || imageUrl.trim().isEmpty) {
        throw StateError('تعذر رفع الصورة.');
      }

      await ChatService.sendMessage(
        threadType: widget.threadType,
        threadId: widget.threadId,
        content: imageUrl.trim(),
        receiverPhone: widget.receiverPhone,
        senderName: senderName,
        messageType: 'image',
      );
      if (!mounted) return;
      setState(() {
        _localImagePaths.remove(localId);
        _messages = _messages.where((m) => m.id != localId).toList();
      });
      await _pollNewMessages();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _localImagePaths.remove(localId);
        _messages = _messages.where((m) => m.id != localId).toList();
      });
      final message = error is ApiException
          ? error.message
          : 'تعذر إرسال الصورة، حاول مجدداً';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            message,
            style: const TextStyle(fontFamily: 'Cairo'),
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  void _openImagePreview(String imageRef) {
    showDialog<void>(
      context: context,
      barrierColor: Colors.black87,
      builder: (dialogContext) => Dialog(
        insetPadding: const EdgeInsets.all(16),
        backgroundColor: Colors.transparent,
        child: Stack(
          children: [
            InteractiveViewer(
              child: AppImage(
                imageData: imageRef,
                fit: BoxFit.contain,
              ),
            ),
            Positioned(
              top: 8,
              left: 8,
              child: IconButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                icon: const Icon(Icons.close, color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _sendSticker(String sticker) async {
    final content = sticker.trim();
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
      messageType: 'sticker',
      content: content,
      createdAt: DateTime.now(),
    );

    setState(() {
      _isSending = true;
      _messages = [..._messages, local];
    });
    _scrollToBottom();

    try {
      await ChatService.sendMessage(
        threadType: widget.threadType,
        threadId: widget.threadId,
        content: content,
        receiverPhone: widget.receiverPhone,
        senderName: senderName,
        messageType: 'sticker',
      );
      await _pollNewMessages();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _messages = _messages.where((m) => m.id != local.id).toList();
      });
      final message = error is ApiException
          ? error.message
          : 'تعذر إرسال الملصق، حاول مجدداً';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            message,
            style: const TextStyle(fontFamily: 'Cairo'),
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  String _formatMessageTime(DateTime? date) {
    if (date == null) return '';
    return '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }

  bool _isDifferentDay(int index) {
    if (index <= 0 || index >= _messages.length) return false;
    final current = _messages[index].createdAt;
    final previous = _messages[index - 1].createdAt;
    if (current == null || previous == null) return false;
    return current.year != previous.year ||
        current.month != previous.month ||
        current.day != previous.day;
  }

  String _dateLabel(DateTime date) {
    final now = DateTime.now();
    if (date.year == now.year && date.month == now.month && date.day == now.day) {
      return 'اليوم';
    }
    final yesterday = now.subtract(const Duration(days: 1));
    if (date.year == yesterday.year && date.month == yesterday.month && date.day == yesterday.day) {
      return 'أمس';
    }
    return '${date.year}/${date.month.toString().padLeft(2, '0')}/${date.day.toString().padLeft(2, '0')}';
  }

  int _totalItemCount() {
    int count = _messages.length;
    if (_isLoadingOlder) count++;
    for (int i = 1; i < _messages.length; i++) {
      if (_isDifferentDay(i)) count++;
    }
    if (_messages.isNotEmpty && _messages.first.createdAt != null) count++;
    return count;
  }

  Widget _buildListItem(int rawIndex) {
    int msgIndex = 0;
    int listIdx = 0;

    if (_isLoadingOlder) {
      if (rawIndex == 0) {
        return const Padding(
          padding: EdgeInsets.symmetric(vertical: 12),
          child: Center(
            child: SizedBox(
              width: 24, height: 24,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
        );
      }
      listIdx = 1;
    }

    if (_messages.isNotEmpty && _messages.first.createdAt != null) {
      if (rawIndex == listIdx) {
        return _buildDateSeparator(_messages.first.createdAt!);
      }
      listIdx++;
    }

    for (int i = 0; i < _messages.length; i++) {
      if (i > 0 && _isDifferentDay(i)) {
        if (rawIndex == listIdx) {
          return _buildDateSeparator(_messages[i].createdAt!);
        }
        listIdx++;
      }
      if (rawIndex == listIdx) {
        msgIndex = i;
        break;
      }
      listIdx++;
    }

    if (msgIndex >= _messages.length) return const SizedBox.shrink();
    final msg = _messages[msgIndex];
    return _buildMessageBubble(msg, _isMine(msg));
  }

  Widget _buildDateSeparator(DateTime date) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          const Expanded(child: Divider(color: Color(0xFFE0E0E0))),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                _dateLabel(date),
                style: TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 12,
                  color: Colors.grey.shade600,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          const Expanded(child: Divider(color: Color(0xFFE0E0E0))),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(ChatMessage msg, bool isMe) {
    if (ChatMessagePresenter.isCall(msg)) {
      return Center(
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 8),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.grey.shade200,
            borderRadius: BorderRadius.circular(18),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isMe ? Icons.call_made_rounded : Icons.call_received_rounded,
                size: 18,
                color: isMe ? AppColors.primary : Colors.redAccent,
              ),
              const SizedBox(width: 8),
              Text(
                ChatMessagePresenter.callLabel(msg, isMine: isMe),
                style: const TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 13,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (ChatMessagePresenter.isSticker(msg)) {
      return Align(
        alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                msg.content,
                style: const TextStyle(fontSize: 72, height: 1.1),
              ),
              if (msg.createdAt != null)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(
                    _formatMessageTime(msg.createdAt),
                    style: TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 11,
                      color: Colors.grey.shade500,
                    ),
                  ),
                ),
            ],
          ),
        ),
      );
    }

    if (ChatMessagePresenter.isImage(msg)) {
      final maxWidth = MediaQuery.of(context).size.width * 0.68;
      final localPath = _localImagePaths[msg.id];
      final imageChild = localPath != null
          ? Image.file(
              File(localPath),
              width: maxWidth,
              height: maxWidth * 0.75,
              fit: BoxFit.cover,
            )
          : AppImage(
              imageData: msg.content,
              width: maxWidth,
              height: maxWidth * 0.75,
              fit: BoxFit.cover,
              borderRadius: BorderRadius.circular(14),
            );

      return Align(
        alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
        child: GestureDetector(
          onTap: localPath == null ? () => _openImagePreview(msg.content) : null,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                margin: const EdgeInsets.symmetric(vertical: 4),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.black12),
                ),
                clipBehavior: Clip.antiAlias,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    imageChild,
                    if (localPath != null)
                      Container(
                        width: maxWidth,
                        height: maxWidth * 0.75,
                        color: Colors.black38,
                        child: const CircularProgressIndicator(color: Colors.white),
                      ),
                  ],
                ),
              ),
              if (msg.createdAt != null)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(
                    _formatMessageTime(msg.createdAt),
                    style: TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 11,
                      color: Colors.grey.shade500,
                    ),
                  ),
                ),
            ],
          ),
        ),
      );
    }

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
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
          color: isMe ? AppColors.primary : Colors.grey.shade200,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              msg.content,
              style: TextStyle(
                fontFamily: 'Cairo',
                color: isMe ? Colors.white : Colors.black87,
              ),
            ),
            if (msg.createdAt != null)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Align(
                  alignment: AlignmentDirectional.bottomEnd,
                  child: Text(
                    _formatMessageTime(msg.createdAt),
                    style: TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 10,
                      height: 1.0,
                      color: isMe ? Colors.white60 : Colors.grey.shade400,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
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
              onPressed: () => _loadInitialMessages(),
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
                          itemCount: _totalItemCount(),
                          itemBuilder: (context, index) =>
                              _buildListItem(index),
                        ),
                      ),
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: _isSending ? null : _pickAndSendImage,
                      icon: const Icon(
                        Icons.image_outlined,
                        color: AppColors.primary,
                      ),
                      tooltip: 'إرسال صورة',
                    ),
                    IconButton(
                      onPressed: _isSending ? null : _openStickerPicker,
                      icon: const Icon(
                        Icons.sticky_note_2_outlined,
                        color: AppColors.primary,
                      ),
                      tooltip: 'ملصقات',
                    ),
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
