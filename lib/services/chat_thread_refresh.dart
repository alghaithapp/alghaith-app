typedef ChatThreadRefreshCallback = void Function();

/// يربط شاشة المحادثة المفتوحة بإشعارات push لتحديث فوري.
class ChatThreadRefreshHub {
  ChatThreadRefreshHub._();

  static final ChatThreadRefreshHub instance = ChatThreadRefreshHub._();

  final Map<String, ChatThreadRefreshCallback> _listeners = {};

  String _key(String threadType, String threadId) =>
      '${threadType.trim()}:${threadId.trim()}';

  void register({
    required String threadType,
    required String threadId,
    required ChatThreadRefreshCallback onRefresh,
  }) {
    _listeners[_key(threadType, threadId)] = onRefresh;
  }

  void unregister({
    required String threadType,
    required String threadId,
  }) {
    _listeners.remove(_key(threadType, threadId));
  }

  bool isActive({
    required String threadType,
    required String threadId,
  }) {
    return _listeners.containsKey(_key(threadType, threadId));
  }

  bool notifyIfActive({
    required String threadType,
    required String threadId,
  }) {
    final callback = _listeners[_key(threadType, threadId)];
    if (callback == null) return false;
    callback();
    return true;
  }
}
