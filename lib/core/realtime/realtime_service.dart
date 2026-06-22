import 'package:supabase_flutter/supabase_flutter.dart';

class RealtimeService {
  final SupabaseClient _client;

  RealtimeService(this._client);

  RealtimeChannel subscribeToOrders({
    required String phone,
    required void Function(Map<String, dynamic> payload) onUpsert,
    required void Function(Map<String, dynamic> payload) onDelete,
  }) {
    return _client
        .channel('public:customer_orders')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'customer_orders',
          callback: (payload) {
            final record = payload.eventType == PostgresChangeEvent.delete
                ? payload.oldRecord
                : payload.newRecord;
            if (record['phone'] == phone ||
                record['merchant_phone'] == phone ||
                record['courier_phone'] == phone) {
              if (payload.eventType == PostgresChangeEvent.delete) {
                onDelete(payload.oldRecord);
              } else {
                onUpsert(payload.newRecord);
              }
            }
          },
        )
        .subscribe();
  }

  RealtimeChannel subscribeToTaxiRequests({
    required String phone,
    required void Function(Map<String, dynamic> payload) onNewRequest,
  }) {
    return _client
        .channel('public:taxi_requests')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'taxi_requests',
          callback: (payload) {
            final newRecord = payload.newRecord;
            onNewRequest(newRecord);
          },
        )
        .subscribe();
  }

  RealtimeChannel subscribeToTable({
    required String table,
    required String filterColumn,
    required String filterValue,
    required void Function(Map<String, dynamic> payload) onData,
    PostgresChangeEvent event = PostgresChangeEvent.all,
  }) {
    return _client
        .channel('public:$table')
        .onPostgresChanges(
          event: event,
          schema: 'public',
          table: table,
          callback: (payload) {
            final record = payload.eventType == PostgresChangeEvent.delete
                ? payload.oldRecord
                : payload.newRecord;
            if (record[filterColumn] == filterValue) {
              onData(record);
            }
          },
        )
        .subscribe();
  }

  void dispose() {
    _client.removeAllChannels();
  }
}
