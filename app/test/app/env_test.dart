import 'package:atheleo/app/env.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AppEnv.validate', () {
    test('릴리스에서 http 거부: StateError를 던진다', () {
      const env = AppEnv(
        apiBaseUrl: 'http://a.com',
        sentryDsn: '',
        isRelease: true,
      );

      expect(env.validate, throwsStateError);
    });

    test('릴리스에서 https 허용: 예외 없음', () {
      const env = AppEnv(
        apiBaseUrl: 'https://a.com',
        sentryDsn: '',
        isRelease: true,
      );

      expect(env.validate, returnsNormally);
    });

    test('디버그에서 http 허용: 예외 없음', () {
      const env = AppEnv(
        apiBaseUrl: 'http://10.0.2.2:8000',
        sentryDsn: '',
        isRelease: false,
      );

      expect(env.validate, returnsNormally);
    });
  });

  test('기본값: define 없이 만들면 에뮬레이터 주소와 빈 DSN', () {
    final env = AppEnv.fromEnvironment();

    expect(env.apiBaseUrl, 'http://10.0.2.2:8000');
    expect(env.sentryDsn, '');
  });

  test('appEnvProvider: AppEnv를 제공한다', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    expect(container.read(appEnvProvider), isA<AppEnv>());
  });
}
