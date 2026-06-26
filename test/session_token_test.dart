import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:alghaith_app/core/network/api_client.dart';
import 'package:alghaith_app/modules/auth/storage/local_session_store.dart';

void main() {
  group('ApiClient session token', () {
    setUp(() {
      ApiClient.instance.setSessionToken(null);
    });

    test('starts with null token', () {
      expect(ApiClient.instance.sessionToken, isNull);
    });

    test('setSessionToken stores a token', () {
      ApiClient.instance.setSessionToken('my-session-token-123');
      expect(ApiClient.instance.sessionToken, 'my-session-token-123');
    });

    test('setSessionToken trims whitespace', () {
      ApiClient.instance.setSessionToken('  token-with-spaces  ');
      expect(ApiClient.instance.sessionToken, 'token-with-spaces');
    });

    test('setSessionToken with null clears token', () {
      ApiClient.instance.setSessionToken('some-token');
      expect(ApiClient.instance.sessionToken, 'some-token');

      ApiClient.instance.setSessionToken(null);
      expect(ApiClient.instance.sessionToken, isNull);
    });

    test('setSessionToken with empty string clears token', () {
      ApiClient.instance.setSessionToken('some-token');
      ApiClient.instance.setSessionToken('');
      expect(ApiClient.instance.sessionToken, isNull);
    });

    test('setSessionToken with whitespace-only string clears token', () {
      ApiClient.instance.setSessionToken('some-token');
      ApiClient.instance.setSessionToken('   ');
      expect(ApiClient.instance.sessionToken, isNull);
    });
  });

  group('LocalSessionStore', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('readSession returns null when no session stored', () async {
      final session = await LocalSessionStore.instance.readSession();
      expect(session, isNull);
    });

    test('writeSession then readSession returns stored session', () async {
      await LocalSessionStore.instance.writeSession(
        phone: '07701234567',
        token: 'abc-session-token',
      );
      final session = await LocalSessionStore.instance.readSession();
      expect(session, isNotNull);
      expect(session!.phone, '+9647701234567');
      expect(session.token, 'abc-session-token');
    });

    test('writeSession without token stores null token', () async {
      await LocalSessionStore.instance.writeSession(phone: '07701234567');
      final session = await LocalSessionStore.instance.readSession();
      expect(session, isNotNull);
      expect(session!.phone, '+9647701234567');
      expect(session.token, isNull);
    });

    test('writeSession with empty token removes token key', () async {
      await LocalSessionStore.instance.writeSession(
        phone: '07701234567',
        token: '  ',
      );
      final session = await LocalSessionStore.instance.readSession();
      expect(session, isNotNull);
      expect(session!.token, isNull);
    });

    test('clearSession removes stored session', () async {
      await LocalSessionStore.instance.writeSession(
        phone: '07701234567',
        token: 'some-token',
      );
      await LocalSessionStore.instance.clearSession();
      final session = await LocalSessionStore.instance.readSession();
      expect(session, isNull);
    });

    test('readSession trims whitespace from token', () async {
      await LocalSessionStore.instance.writeSession(
        phone: '07701234567',
        token: '  trimmed-token  ',
      );
      final session = await LocalSessionStore.instance.readSession();
      expect(session!.token, 'trimmed-token');
    });

    test('writeSession normalizes phone number', () async {
      await LocalSessionStore.instance.writeSession(
        phone: '07709876543',
      );
      final session = await LocalSessionStore.instance.readSession();
      expect(session!.phone, '+9647709876543');
    });

    test('multiple writeSession calls overwrite previous session', () async {
      await LocalSessionStore.instance.writeSession(
        phone: '07701111111',
        token: 'first-token',
      );
      await LocalSessionStore.instance.writeSession(
        phone: '07702222222',
        token: 'second-token',
      );
      final session = await LocalSessionStore.instance.readSession();
      expect(session!.phone, '+9647702222222');
      expect(session.token, 'second-token');
    });
  });
}
