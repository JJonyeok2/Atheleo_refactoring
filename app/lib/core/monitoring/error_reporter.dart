// [파일] 오류 보고 인터페이스(ErrorReporter)와 아무것도 하지 않는 기본 구현, provider
// [Spec] 모니터링(추론 실패, 동기화 400, 비정상 종료 보고) / [Task] TASK-02
// [의존] 없음 (Sentry 실제 연결과 SENTRY_DSN 사용은 TASK-48)

import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 오류 보고 인터페이스. 구현체는 개인 식별 정보를 보내지 않는다.
abstract class ErrorReporter {
  /// [error]를 보고한다. [tag]는 분류용, [context]는 식별 정보가 없는 부가 정보.
  Future<void> report(
    Object error,
    StackTrace? stackTrace, {
    String? tag,
    Map<String, Object?> context = const {},
  });
}

/// 아무것도 하지 않는 기본 보고기. 실제 연결 전까지 쓴다.
class NoopErrorReporter implements ErrorReporter {
  /// 상태가 없으므로 const로 만든다.
  const new();

  @override
  Future<void> report(
    Object error,
    StackTrace? stackTrace, {
    String? tag,
    Map<String, Object?> context = const {},
  }) async {}
}

/// 오류 보고기 provider. 기본값은 [NoopErrorReporter].
final errorReporterProvider = Provider<ErrorReporter>(
  (ref) => const NoopErrorReporter(),
);

// [QA] 2026-11-09 FIX
// [보안] 개인 식별 정보 미전송 규칙은 문서 주석에만 있다. context 필터링은 실제 구현(TASK-48)에서 강제할 것.
// [유지보수] 없음. 인터페이스 시그니처는 TASK-28, 39, 48이 기대므로 바꾸지 않는다.
