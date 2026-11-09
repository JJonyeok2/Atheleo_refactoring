import 'package:atheleo/core/monitoring/error_reporter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('기본 오류 보고기: NoopErrorReporter이고 report 호출 시 예외 없음', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final reporter = container.read(errorReporterProvider);

    expect(reporter, isA<NoopErrorReporter>());
    await expectLater(
      reporter.report(
        StateError('x'),
        StackTrace.current,
        tag: 'test',
        context: const {'k': 1},
      ),
      completes,
    );
  });
}
