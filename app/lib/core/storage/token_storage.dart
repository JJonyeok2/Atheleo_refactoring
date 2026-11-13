// [파일] 토큰(access, refresh)과 현재 사용자 id 암호화 저장소
//        (TokenStorage, SecureTokenStorage, tokenStorageProvider)
// [Spec] F-10 계정, 보안 / [Task] TASK-33
// [의존] flutter_secure_storage 11.x (Android 기본 옵션:
//        AES-GCM 저장 암호화 + RSA OAEP 키 래핑), 환경 변수 없음

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// access, refresh 토큰 쌍. 토큰 값은 toString에 노출하지 않는다.
class AuthTokens {
  /// 토큰 쌍을 만든다.
  const new({required this.access, required this.refresh});

  /// access 토큰.
  final String access;

  /// refresh 토큰.
  final String refresh;

  @override
  String toString() => 'AuthTokens(***)';
}

/// 토큰과 현재 사용자 id 저장소.
abstract class TokenStorage {
  /// 저장된 토큰. 둘 중 하나라도 없으면 null.
  Future<AuthTokens?> read();

  /// 토큰만 저장한다. 사용자 id는 건드리지 않는다.
  Future<void> write(AuthTokens tokens);

  /// 저장된 사용자 id. 없거나 정수가 아니면 null.
  Future<int?> readUserId();

  /// 사용자 id를 저장한다.
  Future<void> writeUserId(int userId);

  /// 토큰과 사용자 id를 모두 지운다.
  Future<void> clear();
}

const _accessKey = 'auth.access';
const _refreshKey = 'auth.refresh';
const _userIdKey = 'auth.user_id';

/// flutter_secure_storage 구현.
///
/// v11에는 encryptedSharedPreferences 옵션이 없고 Android 기본값이
/// AES-GCM 암호화라 기본 옵션을 쓴다.
class SecureTokenStorage implements TokenStorage {
  /// [storage]를 주지 않으면 기본 암호화 저장소를 쓴다.
  new([FlutterSecureStorage? storage])
    : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  /// 읽기 실패(복호화 오류 등)는 값이 없는 것으로 보고 null을 돌려준다.
  Future<String?> _safeRead(String key) async {
    try {
      return await _storage.read(key: key);
    } on Object {
      return null;
    }
  }

  @override
  Future<AuthTokens?> read() async {
    final access = await _safeRead(_accessKey);
    final refresh = await _safeRead(_refreshKey);
    if (access == null || access.isEmpty) return null;
    if (refresh == null || refresh.isEmpty) return null;
    return AuthTokens(access: access, refresh: refresh);
  }

  @override
  Future<void> write(AuthTokens tokens) async {
    await _storage.write(key: _accessKey, value: tokens.access);
    await _storage.write(key: _refreshKey, value: tokens.refresh);
  }

  @override
  Future<int?> readUserId() async {
    final raw = await _safeRead(_userIdKey);
    return raw == null ? null : int.tryParse(raw);
  }

  @override
  Future<void> writeUserId(int userId) =>
      _storage.write(key: _userIdKey, value: userId.toString());

  @override
  Future<void> clear() async {
    Object? firstError;
    StackTrace? firstStack;
    for (final key in [_accessKey, _refreshKey, _userIdKey]) {
      try {
        await _storage.delete(key: key);
      } on Object catch (e, st) {
        firstError ??= e;
        firstStack ??= st;
      }
    }
    if (firstError != null) {
      Error.throwWithStackTrace(firstError, firstStack!);
    }
  }
}

/// 앱 전체에서 쓰는 토큰 저장소.
final tokenStorageProvider = Provider<TokenStorage>(
  (ref) => SecureTokenStorage(),
);

// [QA] 2026-11-13 PASS (재검토)
// [보안] 토큰, 사용자 id는 로그, 예외 메시지, toString에 쓰지 않는다.
// [보안] 읽기 예외는 null(로그아웃 상태)로 삼키며 지금은 관측 수단이 없다.
// [보안] Android 기본 resetOnError=true라 복호화 실패 시 플러그인이
//        저장소를 비운다(재로그인 필요).
// [유지보수] write는 두 키를 차례로 써서 원자적이지 않다(access만 바뀌고
//        refresh 쓰기 실패 가능). clear는 세 키 삭제를 각각 시도하고 첫 예외를 다시 던진다.
// [유지보수] readUserId는 int.tryParse라 ' 7', '+7', '0x7'도 받는다.
//        쓰는 쪽이 writeUserId뿐이라 실제 피해는 없다.
// [FIX 반영]
