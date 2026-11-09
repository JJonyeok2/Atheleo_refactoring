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
