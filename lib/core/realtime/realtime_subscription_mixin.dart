import 'package:supabase_flutter/supabase_flutter.dart';

mixin RealtimeSubscriptionMixin {
  final List<RealtimeChannel> _channels = [];

  RealtimeChannel trackChannel(RealtimeChannel channel) {
    _channels.add(channel);
    return channel;
  }

  void disposeRealtime() {
    for (final channel in _channels) {
      channel.unsubscribe();
    }
    _channels.clear();
  }
}
