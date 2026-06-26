import '../../core/config/app_config.dart';
import '../../modules/auth/storage/local_session_store.dart';
import '../models/account_snapshot.dart';
import 'database_repository.dart';

/// تنسيق الجلسة والاستعادة من السحابة والتخزين المحلي.
class AccountRepository {
  AccountRepository._();

  static final AccountRepository instance = AccountRepository._();

  final _db = DatabaseRepository.instance;
  final _local = LocalSessionStore.instance;

  bool get isBackendReady => AppConfig.isBackendConfigured;

  Future<StoredSession?> readStoredSession() => _local.readSession();

  Future<void> persistSession({
    required String phone,
    String? token,
  }) =>
      _local.writeSession(phone: phone, token: token);

  Future<void> clearSession({String? phone}) => _local.clearSession(phone: phone);

  /// يمسح بيانات الحساب المحلية نهائياً — يُستدعى فقط عند حذف الحساب.
  Future<void> clearSnapshot(String phone) => _local.clearSnapshot(phone);

  Future<AccountSnapshot?> readLocalSnapshot(String phone) =>
      _local.readSnapshot(phone);

  Future<void> writeLocalSnapshot(String phone, AccountSnapshot snapshot) =>
      _local.writeSnapshot(phone, snapshot);

  Future<RemoteAccountBundle> fetchRemoteAccount(String phone) =>
      _db.loadAccountBundle(phone);
}
