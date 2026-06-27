import 'dart:async';
import 'package:socket_io_client/socket_io_client.dart' as io;
import '../../../models/chat_message.dart';
import '../../../core/config/app_config.dart';

/// خدمة الاتصال بخادم Socket.io للرسائل الفورية
class SocketService {
  static final SocketService _instance = SocketService._();
  factory SocketService() => _instance;
  SocketService._();

  io.Socket? _socket;
  bool _isConnected = false;
  final StreamController<ChatMessage> _messageController =
      StreamController<ChatMessage>.broadcast();

  Stream<ChatMessage> get onMessage => _messageController.stream;
  bool get isConnected => _isConnected;

  String get _serverUrl => AppConfig.vpsSocketUrl;

  void connect(String room) {
    if (_socket != null) {
      _socket!.disconnect();
      _socket!.dispose();
    }

    _socket = io.io(
      _serverUrl,
      io.OptionBuilder()
          .setTransports(['websocket'])
          .disableAutoConnect()
          .build(),
    );

    _socket!.onConnect((_) {
      _isConnected = true;
      _socket!.emit('join', room);
    });

    _socket!.on('message', (data) {
      try {
        final map = data is Map ? Map<String, dynamic>.from(data) : null;
        if (map != null) {
          final msg = ChatMessage.fromMap(map);
          _messageController.add(msg);
        }
      } catch (_) {}
    });

    _socket!.onDisconnect((_) => _isConnected = false);
    _socket!.onError((_) => _isConnected = false);
    _socket!.connect();
  }

  void disconnect() {
    if (_socket != null) {
      _socket!.disconnect();
      _socket!.dispose();
      _socket = null;
    }
    _isConnected = false;
  }

  void dispose() {
    disconnect();
    _messageController.close();
  }
}
