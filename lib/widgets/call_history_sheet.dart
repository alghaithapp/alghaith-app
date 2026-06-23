import 'package:flutter/material.dart';
import 'package:intl/intl.dart' hide TextDirection;

import '../core/theme/app_colors.dart';
import '../models/voice_call_log.dart';
import '../services/voice_call_service.dart';

class CallHistorySheet extends StatefulWidget {
  final String threadType;
  final String threadId;
  final String otherPartyName;
  final String? sessionPhone;

  const CallHistorySheet({
    super.key,
    required this.threadType,
    required this.threadId,
    required this.otherPartyName,
    this.sessionPhone,
  });

  static Future<void> show(
    BuildContext context, {
    required String threadType,
    required String threadId,
    required String otherPartyName,
    String? sessionPhone,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: CallHistorySheet(
          threadType: threadType,
          threadId: threadId,
          otherPartyName: otherPartyName,
          sessionPhone: sessionPhone,
        ),
      ),
    );
  }

  @override
  State<CallHistorySheet> createState() => _CallHistorySheetState();
}

class _CallHistorySheetState extends State<CallHistorySheet> {
  List<VoiceCallLog> _logs = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final logs = await VoiceCallService.fetchHistory(
        threadType: widget.threadType,
        threadId: widget.threadId,
        limit: 50,
      );
      if (!mounted) return;
      setState(() {
        _logs = logs;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = error.toString().replaceFirst('ApiException: ', '');
      });
    }
  }

  bool _isOutgoing(VoiceCallLog log) {
    final mine = widget.sessionPhone?.trim() ?? '';
    if (mine.isEmpty) return log.direction == 'outgoing';
    return log.callerPhone.contains(mine.replaceAll('+', '')) ||
        mine.contains(log.callerPhone.replaceAll('+', ''));
  }

  String _formatWhen(DateTime? value) {
    if (value == null) return '';
    return DateFormat('d/M/y  h:mm a', 'ar').format(value.toLocal());
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'سجل المكالمات — ${widget.otherPartyName}',
                      style: const TextStyle(
                        fontFamily: 'Cairo',
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: _load,
                    icon: const Icon(Icons.refresh),
                    tooltip: 'تحديث',
                  ),
                ],
              ),
              const SizedBox(height: 8),
              if (_loading)
                const Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (_error != null)
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    _error!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontFamily: 'Cairo', color: Colors.red),
                  ),
                )
              else if (_logs.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(24),
                  child: Text(
                    'لا توجد مكالمات مسجّلة في هذه المحادثة بعد.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: 'Cairo',
                      color: AppColors.textSecondary,
                    ),
                  ),
                )
              else
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: _logs.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final log = _logs[index];
                      final outgoing = _isOutgoing(log);
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(
                          outgoing ? Icons.call_made : Icons.call_received,
                          color: outgoing ? AppColors.primary : Colors.green,
                        ),
                        title: Text(
                          log.statusLabelAr(outgoing),
                          style: const TextStyle(
                            fontFamily: 'Cairo',
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        subtitle: Text(
                          '${_formatWhen(log.startedAt)} • ${log.durationLabel()}',
                          style: const TextStyle(fontFamily: 'Cairo', fontSize: 12),
                        ),
                      );
                    },
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
