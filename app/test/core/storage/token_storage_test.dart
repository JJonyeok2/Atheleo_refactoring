import 'package:atheleo/core/storage/token_storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/in_memory_token_storage.dart';

/// 읽기, 쓰기, 삭제가 모두 실패하는 저장소. 예외 메시지에 값이 섞이지 않는지 본다.
class _ThrowingStorage implements FlutterSecureStorage {
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw StateError('storage failure');
}

/// delete만 기록하며 [failKey] 삭제는 실패하는 저장소.
class _FailingDeleteStorage implements FlutterSecureStorage {
  new(this.failKey);

  final String failKey;
  final List<String> attempted = [];

  @override
  dynamic noSuchMethod(Invocation invocation) {
    if (invocation.memberName != #delete) {
      throw StateError('unexpected call');
    }
    final key = invocation.namedArguments[#key] as String;
    attempted.add(key);
    if (key == failKey) return Future<void>.error(StateError('delete failure'));
    return Future<void>.value();
  }
}

void main() {
  const tokens = AuthTokens(
    access: 'access-secret-1',
    refresh: 'refresh-secret-1',
  );

  setUp(() => FlutterSecureStorage.setMockInitialValues({}));

  group('SecureTokenStorage', () {
    test('쓰고 읽기: 새 인스턴스로도 같은 값 (앱 재시작)', () async {
      final first = SecureTokenStorage();
      await first.write(tokens);
      await first.writeUserId(7);

      final second = SecureTokenStorage();
      final read = await second.read();
      expect(read?.access, 'access-secret-1');
      expect(read?.refresh, 'refresh-secret-1');
      expect(await second.readUserId(), 7);
    });

    test('비었을 때 read, readUserId는 null', () async {
      final storage = SecureTokenStorage();
      expect(await storage.read(), isNull);
      expect(await storage.readUserId(), isNull);
    });

    test('access만 있으면 read는 null', () async {
      FlutterSecureStorage.setMockInitialValues({'auth.access': 'a'});
      expect(await SecureTokenStorage().read(), isNull);
    });

    test('refresh만 있으면 read는 null', () async {
      FlutterSecureStorage.setMockInitialValues({'auth.refresh': 'r'});
      expect(await SecureTokenStorage().read(), isNull);
    });

    test('빈 문자열 토큰은 없는 것으로 본다', () async {
      FlutterSecureStorage.setMockInitialValues({
        'auth.access': '',
        'auth.refresh': 'r',
      });
      expect(await SecureTokenStorage().read(), isNull);
    });

    test('user_id가 정수가 아니면 readUserId는 null', () async {
      for (final bad in ['abc', '', '1.5']) {
        FlutterSecureStorage.setMockInitialValues({'auth.user_id': bad});
        expect(await SecureTokenStorage().readUserId(), isNull, reason: bad);
      }
    });

    test('토큰 갱신이 사용자 id를 지우지 않는다', () async {
      final storage = SecureTokenStorage();
      await storage.writeUserId(7);
      await storage.write(const AuthTokens(access: 'new-a', refresh: 'new-r'));
      expect(await storage.readUserId(), 7);
      expect((await storage.read())?.access, 'new-a');
    });

    test('clear는 세 키를 모두 지운다', () async {
      final storage = SecureTokenStorage();
      await storage.write(tokens);
      await storage.writeUserId(7);
      await storage.clear();
      expect(await storage.read(), isNull);
      expect(await storage.readUserId(), isNull);
      expect(await SecureTokenStorage().read(), isNull);
    });

    test('clear는 첫 키 삭제가 실패해도 나머지를 시도하고 첫 예외를 던진다', () async {
      final fake = _FailingDeleteStorage('auth.access');
      final storage = SecureTokenStorage(fake);
      await expectLater(storage.clear(), throwsA(isA<StateError>()));
      expect(fake.attempted, ['auth.access', 'auth.refresh', 'auth.user_id']);
    });

    test('저장소 읽기 예외는 로그아웃 상태(null)로 본다', () async {
      final storage = SecureTokenStorage(_ThrowingStorage());
      expect(await storage.read(), isNull);
      expect(await storage.readUserId(), isNull);
    });

    test('쓰기 예외 메시지에 토큰이 없다', () async {
      final storage = SecureTokenStorage(_ThrowingStorage());
      try {
        await storage.write(tokens);
        fail('예외가 나야 한다');
      } on Object catch (e) {
        expect(e.toString(), isNot(contains('secret')));
      }
    });
  });

  group('AuthTokens', () {
    test('toString에 토큰 값이 없다', () {
      final text = tokens.toString();
      expect(text, isNot(contains('access-secret-1')));
      expect(text, isNot(contains('refresh-secret-1')));
    });
  });

  group('tokenStorageProvider', () {
    test('SecureTokenStorage를 돌려준다', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      expect(container.read(tokenStorageProvider), isA<SecureTokenStorage>());
    });
  });

  group('InMemoryTokenStorage', () {
    test('초기값을 읽는다', () async {
      final storage = InMemoryTokenStorage(tokens, 7);
      expect((await storage.read())?.access, 'access-secret-1');
      expect(await storage.readUserId(), 7);
      expect(storage.current?.refresh, 'refresh-secret-1');
      expect(storage.currentUserId, 7);
    });

    test('빈 문자열 access 또는 refresh면 read는 null', () async {
      final emptyAccess = InMemoryTokenStorage(
        const AuthTokens(access: '', refresh: 'r'),
      );
      final emptyRefresh = InMemoryTokenStorage(
        const AuthTokens(access: 'a', refresh: ''),
      );
      expect(await emptyAccess.read(), isNull);
      expect(await emptyRefresh.read(), isNull);
      final written = InMemoryTokenStorage();
      await written.write(const AuthTokens(access: '', refresh: ''));
      expect(await written.read(), isNull);
    });

    test('write는 사용자 id를 건드리지 않고 clear는 모두 지운다', () async {
      final storage = InMemoryTokenStorage(tokens, 7);
      await storage.write(const AuthTokens(access: 'n', refresh: 'm'));
      expect(storage.currentUserId, 7);
      await storage.clear();
      expect(storage.current, isNull);
      expect(storage.currentUserId, isNull);
    });
  });
}
