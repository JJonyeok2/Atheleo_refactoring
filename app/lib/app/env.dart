import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 빌드 시 `--dart-define`으로 주입되는 앱 설정.
class AppEnv {
  /// 설정 값을 직접 지정해 만든다. 테스트와 override에서 쓴다.
  const new({
    required this.apiBaseUrl,
    required this.sentryDsn,
    required this.isRelease,
  });

  /// `--dart-define`(또는 `--dart-define-from-file=.env`) 값으로 만든다.
  factory fromEnvironment() => const AppEnv(
    apiBaseUrl: String.fromEnvironment(
      'API_BASE_URL',
      defaultValue: 'http://10.0.2.2:8000',
    ),
    sentryDsn: String.fromEnvironment('SENTRY_DSN'),
    isRelease: kReleaseMode,
  );

  /// 서버 주소. 릴리스 빌드에서는 `https://`로 시작해야 한다.
  final String apiBaseUrl;

  /// Sentry DSN. 비어 있으면 오류 보고를 연결하지 않는다.
  final String sentryDsn;

  /// 릴리스 빌드 여부.
  final bool isRelease;

  /// 릴리스 빌드에서 HTTPS가 아닌 서버 주소를 거부한다.
  void validate() {
    if (isRelease && !apiBaseUrl.startsWith('https://')) {
      throw StateError('릴리스 빌드는 HTTPS 서버 주소만 허용한다.');
    }
  }
}

/// 앱 전역 설정 provider. 테스트에서는 override로 바꿔 끼운다.
final appEnvProvider = Provider<AppEnv>((ref) => AppEnv.fromEnvironment());
