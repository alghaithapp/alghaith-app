import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../models/chat_thread_summary.dart';
import '../../chat/services/chat_service.dart';
import '../../chat/utils/chat_navigation.dart';
import '../../../utils/chat_thread_labels.dart';

/// نوع المحادثة للتصنيف والفلترة
enum _ThreadFilter { all, taxi, store, order, support }

extension _ThreadFilterX on _ThreadFilter {
  String get label {
    switch (this) {
      case _ThreadFilter.all:
        return 'الكل';
      case _ThreadFilter.taxi:
        return 'التكسي';
      case _ThreadFilter.store:
        return 'المتاجر';
      case _ThreadFilter.order:
        return 'الطلبات';
      case _ThreadFilter.support:
        return 'الدعم';
    }
  }

  bool matches(ChatThreadSummary thread) {
    if (this == _ThreadFilter.all) return true;
    return thread.threadType == name;
  }
}

/// بيانات نوع المحادثة للإظهار البصري
class _ThreadTypeVisual {
  final IconData icon;
  final Color color;
  final Color bgColor;
  final String label;

  const _ThreadTypeVisual({
    required this.icon,
    required this.color,
    required this.bgColor,
    required this.label,
  });
}

_ThreadTypeVisual _visualFor(String type) {
  switch (type) {
    case 'taxi':
      return const _ThreadTypeVisual(
        icon: Icons.local_taxi_rounded,
        color: Color(0xFF1565C0),
        bgColor: Color(0xFFE3F2FD),
        label: 'تكسي',
      );
    case 'store':
      return const _ThreadTypeVisual(
        icon: Icons.store_rounded,
        color: Color(0xFF2E7D32),
        bgColor: Color(0xFFE8F5E9),
        label: 'متجر',
      );
    case 'order':
      return const _ThreadTypeVisual(
        icon: Icons.receipt_long_rounded,
        color: Color(0xFFE65100),
        bgColor: Color(0xFFFFF3E0),
        label: 'طلب',
      );
    case 'support':
      return const _ThreadTypeVisual(
        icon: Icons.support_agent_rounded,
        color: Color(0xFF6A1B9A),
        bgColor: Color(0xFFF3E5F5),
        label: 'دعم',
      );
    default:
      return const _ThreadTypeVisual(
        icon: Icons.chat_bubble_outline,
        color: Color(0xFF455A64),
        bgColor: Color(0xFFECEFF1),
        label: 'محادثة',
      );
  }
}

/// صندوق رسائل موحّد مع فلترة وتمييز بصري حسب نوع المحادثة.
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
  _ThreadFilter _selectedFilter = _ThreadFilter.all;

  List<ChatThreadSummary> get _filteredThreads {
    return _threads.where((t) => _selectedFilter.matches(t)).toList();
  }

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

  Future<void> _openThread(ChatThreadSummary thread) async {
    setState(() {
      final idx = _threads.indexWhere(
        (t) =>
            t.threadType == thread.threadType &&
            t.threadId == thread.threadId &&
            t.otherPartyPhone == thread.otherPartyPhone,
      );
      if (idx >= 0) {
        final updated = ChatThreadSummary(
          threadType: thread.threadType,
          threadId: thread.threadId,
          otherPartyPhone: thread.otherPartyPhone,
          otherPartyName: thread.otherPartyName,
          threadTitle: thread.threadTitle,
          contextLabel: thread.contextLabel,
          lastMessage: thread.lastMessage,
          lastAt: thread.lastAt,
          unreadCount: 0,
          hasUnread: false,
        );
        _threads[idx] = updated;
      }
    });
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

  Future<void> _confirmAndDeleteThread(ChatThreadSummary thread) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text(
          'حذف المحادثة',
          style: TextStyle(fontFamily: 'Cairo'),
        ),
        content: const Text(
          'سيتم حذف هذه المحادثة بالكامل من قاعدة البيانات بما فيها الصور والمكالمات. لا يمكن التراجع.',
          style: TextStyle(fontFamily: 'Cairo'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('إلغاء', style: TextStyle(fontFamily: 'Cairo')),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('حذف', style: TextStyle(fontFamily: 'Cairo')),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    try {
      await ChatService.deleteThread(
        threadType: thread.threadType,
        threadId: thread.threadId,
        otherPartyPhone: thread.otherPartyPhone,
      );
      if (!mounted) return;
      setState(() {
        _threads.removeWhere(
          (t) =>
              t.threadType == thread.threadType &&
              t.threadId == thread.threadId &&
              t.otherPartyPhone == thread.otherPartyPhone,
        );
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تم حذف المحادثة', style: TextStyle(fontFamily: 'Cairo')),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            error.toString().replaceFirst('ApiException: ', ''),
            style: const TextStyle(fontFamily: 'Cairo'),
          ),
        ),
      );
    }
  }

  String _formatTime(DateTime? date) {
    if (date == null) return '';
    final now = DateTime.now();
    final diff = now.difference(date);
    if (diff.inMinutes < 1) return 'الآن';
    if (diff.inHours < 1) return 'منذ ${diff.inMinutes} د';
    if (diff.inDays < 1) {
      return '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    }
    if (diff.inDays == 1) return 'أمس';
    if (diff.inDays < 7) return 'منذ ${diff.inDays} أيام';
    return '${date.year}/${date.month.toString().padLeft(2, '0')}/${date.day.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredThreads;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text(
            'المحادثات',
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
        body: Column(
          children: [
            _buildFilterBar(),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _error != null
                      ? _buildError()
                      : filtered.isEmpty
                          ? _buildEmpty()
                          : _buildThreadList(filtered),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
      ),
      child: SizedBox(
        height: 36,
        child: ListView(
          scrollDirection: Axis.horizontal,
          children: _ThreadFilter.values.map((filter) {
            final selected = filter == _selectedFilter;
            final count = filter == _ThreadFilter.all
                ? _threads.length
                : _threads.where((t) => t.threadType == filter.name).length;
            return Padding(
              padding: const EdgeInsets.only(left: 8),
              child: ChoiceChip(
                label: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      filter.label,
                      style: TextStyle(
                        fontFamily: 'Cairo',
                        fontSize: 13,
                        color: selected ? Colors.white : Colors.black87,
                        fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                      ),
                    ),
                    if (count > 0) ...[
                      const SizedBox(width: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                        decoration: BoxDecoration(
                          color: selected ? Colors.white24 : Colors.black12,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '$count',
                          style: TextStyle(
                            fontFamily: 'Cairo',
                            fontSize: 11,
                            color: selected ? Colors.white70 : Colors.black54,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                selected: selected,
                selectedColor: AppColors.primary,
                backgroundColor: Colors.grey.shade100,
                side: BorderSide.none,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
                onSelected: (_) => setState(() => _selectedFilter = filter),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.cloud_off_rounded, size: 48, color: Colors.grey.shade400),
            const SizedBox(height: 12),
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
    );
  }

  Widget _buildEmpty() {
    final icon = _selectedFilter == _ThreadFilter.all
        ? Icons.chat_bubble_outline
        : _visualFor(_selectedFilter.name).icon;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 64, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          Text(
            _selectedFilter == _ThreadFilter.all
                ? 'لا توجد محادثات بعد.'
                : 'لا توجد محادثات ${_selectedFilter.label}',
            style: const TextStyle(
              fontFamily: 'Cairo',
              color: AppColors.textSecondary,
              fontSize: 15,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildThreadList(List<ChatThreadSummary> threads) {
    return RefreshIndicator(
      onRefresh: _loadInbox,
      child: ListView.separated(
        padding: const EdgeInsets.all(12),
        itemCount: threads.length,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (context, index) {
          final thread = threads[index];
          return _ThreadCard(
            thread: thread,
            visual: _visualFor(thread.threadType),
            timeLabel: _formatTime(thread.lastAt),
            onTap: () => _openThread(thread),
            onDelete: () => _confirmAndDeleteThread(thread),
          );
        },
      ),
    );
  }
}

/// بطاقة محادثة واحدة مع تمييز بصري حسب النوع.
class _ThreadCard extends StatelessWidget {
  final ChatThreadSummary thread;
  final _ThreadTypeVisual visual;
  final String timeLabel;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _ThreadCard({
    required this.thread,
    required this.visual,
    required this.timeLabel,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final hasUnread = thread.hasUnread;

    return Dismissible(
      key: ValueKey(
        '${thread.threadType}:${thread.threadId}:${thread.otherPartyPhone}',
      ),
      direction: DismissDirection.endToStart,
      confirmDismiss: (_) async {
        onDelete();
        return false;
      },
      background: Container(
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.only(left: 20),
        decoration: BoxDecoration(
          color: Colors.red.shade400,
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Icon(Icons.delete_outline, color: Colors.white),
      ),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            color: hasUnread ? Colors.white : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: hasUnread
                ? Border.all(color: visual.color.withValues(alpha: 0.3), width: 1.2)
                : Border.all(color: Colors.grey.shade200),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: hasUnread ? 0.06 : 0.03),
                blurRadius: hasUnread ? 12 : 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildAvatar(),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              ChatThreadLabels.title(thread),
                              style: TextStyle(
                                fontFamily: 'Cairo',
                                fontSize: 14,
                                fontWeight: hasUnread ? FontWeight.w800 : FontWeight.w600,
                                color: Colors.black87,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 6),
                          _buildTypeBadge(),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              thread.lastMessage,
                              style: TextStyle(
                                fontFamily: 'Cairo',
                                fontSize: 13,
                                color: hasUnread ? Colors.black54 : Colors.grey.shade500,
                                fontWeight: hasUnread ? FontWeight.w500 : FontWeight.normal,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (timeLabel.isNotEmpty) ...[
                            const SizedBox(width: 6),
                            Text(
                              timeLabel,
                              style: TextStyle(
                                fontFamily: 'Cairo',
                                fontSize: 11,
                                color: Colors.grey.shade400,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                if (hasUnread) ...[
                  const SizedBox(width: 8),
                  Container(
                    constraints: const BoxConstraints(minWidth: 20, minHeight: 20),
                    height: 20,
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    decoration: BoxDecoration(
                      color: visual.color,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Center(
                      child: Text(
                        thread.unreadCount > 99 ? '99+' : '${thread.unreadCount}',
                        style: const TextStyle(
                          fontFamily: 'Cairo',
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
                const SizedBox(width: 4),
                IconButton(
                  icon: Icon(
                    Icons.delete_outline,
                    color: Colors.grey.shade400,
                    size: 20,
                  ),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                  tooltip: 'حذف',
                  onPressed: onDelete,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAvatar() {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: visual.bgColor,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(visual.icon, color: visual.color, size: 24),
        ),
        if (thread.hasUnread)
          Positioned(
            top: -3,
            left: -3,
            child: Container(
              width: 14,
              height: 14,
              decoration: BoxDecoration(
                color: const Color(0xFF25D366),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2.5),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildTypeBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: visual.bgColor,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        visual.label,
        style: TextStyle(
          fontFamily: 'Cairo',
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: visual.color,
        ),
      ),
    );
  }
}
