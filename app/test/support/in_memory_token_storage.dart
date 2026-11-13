// [파일] 테스트용 메모리 TokenStorage 구현(InMemoryTokenStorage)
// [Spec] F-10 계정 / [Task] TASK-33
// [의존] app/lib/core/storage/token_storage.dart, 환경 변수 없음

import 'package:atheleo/core/storage/token_storage.dart';

/// 테스트용 메모리 저장소. 실제 암호화 저장소 없이 인증, API 테스트에 쓴다.
class InMemoryTokenStorage implements TokenStorage {
  new([AuthTokens? initial, int? userId]) : _tokens = initial, _userId = userId;

  AuthTokens? _tokens;
  int? _userId;

  AuthTokens? get current => _tokens;
  int? get currentUserId => _userId;

  @override
  Future<AuthTokens?> read() async {
    final t = _tokens;
    if (t == null || t.access.isEmpty || t.refresh.isEmpty) return null;
    return t;
  }

  @override
  Future<void> write(AuthTokens tokens) async => _tokens = tokens;

  @override
  Future<int?> readUserId() async => _userId;

  @override
  Future<void> writeUserId(int userId) async => _userId = userId;

  @override
  Future<void> clear() async {
    _tokens = null;
    _userId = null;
  }
}

// [QA] 2026-11-13 PASS (재검토)
// [보안] 테스트 전용. lib에서 import하지 않는다.
// [유지보수] read는 빈 문자열 토큰을 없음(null)으로 본다(SecureTokenStorage와
//        같은 의미). current는 저장값 그대로. QA-TASK-33 FIX 1.
// [FIX 반영]
