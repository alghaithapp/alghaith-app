import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../models/chat_thread_summary.dart';
import '../../services/chat_service.dart';
import '../../utils/chat_navigation.dart';
import '../../utils/chat_thread_labels.dart';

/// صندوق رسائل موحّد — زبون، تاجر، سائق، مندوب.
class ChatInboxScreen extends StatefulWidget {
  const ChatInboxScreen({super.key});

  @override
  State<ChatInboxScreen> createState() => _ChatInboxScreenState();
}

typedef MerchantChatInboxScreen = ChatInboxScreen;

class _ChatInboxScreenState extends State<ChatInboxScreen> {
  List<ChatThreadSummary> _threads = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadInbox();
  }

  Future<void> _loadInbox() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final threads = await ChatService.fetchInbox();
      if (!mounted) return;
      setState(() {
        _threads = threads;
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _error = error.toString().replaceFirst('ApiException: ', '');
      });
    }
  }

  String _threadLabel(ChatThreadSummary thread) {
    return ChatThreadLabels.contextLabel(thread);
  }

  Future<void> _openThread(ChatThreadSummary thread) async {
    await ChatNavigation.open(
      context,
      threadType: thread.threadType,
      threadId: thread.threadId,
      otherPartyName: ChatThreadLabels.title(thread),
      receiverPhone: thread.otherPartyPhone,
    );
    if (!mounted) return;
    await _loadInbox();
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text(
            'الرسائل داخل التطبيق',
            style: TextStyle(fontFamily: 'Cairo', fontSize: 16),
          ),
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          actions: [
            IconButton(
              onPressed: _loadInbox,
              icon: const Icon(Icons.refresh),
              tooltip: 'تحديث',
            ),
          ],
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _error!,
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontFamily: 'Cairo'),
                          ),
                          const SizedBox(height: 16),
                          FilledButton(
                            onPressed: _loadInbox,
                            child: const Text(
                              'إعادة المحاولة',
                              style: TextStyle(fontFamily: 'Cairo'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                : _threads.isEmpty
                    ? const Center(
                        child: Text(
                          'لا توجد رسائل بعد.\nكل محادثاتك مع الطلبات والمتاجر والتكسي تظهر هنا.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontFamily: 'Cairo',
                            color: AppColors.textSecondary,
                          ),
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _loadInbox,
                        child: ListView.separated(
                          padding: const EdgeInsets.all(12),
                          itemCount: _threads.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 8),
                          itemBuilder: (context, index) {
                            final thread = _threads[index];
                            return Material(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(14),
                              child: ListTile(
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                leading: CircleAvatar(
                                  backgroundColor:
                                      AppColors.primary.withValues(alpha: 0.12),
                                  child: const Icon(
                                    Icons.chat_bubble_outline,
                                    color: AppColors.primary,
                                  ),
                                ),
                                title: Text(
                                  ChatThreadLabels.title(thread),
                                  style: const TextStyle(
                                    fontFamily: 'Cairo',
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                subtitle: Text(
                                  ChatThreadLabels.subtitle(thread),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontFamily: 'Cairo'),
                                ),
                                onTap: () => _openThread(thread),
                              ),
                            );
                          },
                        ),
                      ),
      ),
    );
  }
}
