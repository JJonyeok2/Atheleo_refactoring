// [파일] 앱 환경 설정(서버 주소, Sentry DSN, 릴리스 여부)과 릴리스 HTTPS 검증
// [Spec] 8장 보안(설정 분리, HTTPS), 모니터링 / [Task] TASK-02
// [의존] API_BASE_URL, SENTRY_DSN (--dart-define 또는 --dart-define-from-file=.env)

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
  /// `API_BASE_URL`이 비었거나 공백뿐이면 개발용 기본 주소를 쓴다.
  factory fromEnvironment() => AppEnv(
    apiBaseUrl: resolveApiBaseUrl(
      const String.fromEnvironment(
        'API_BASE_URL',
        defaultValue: _defaultApiBaseUrl,
      ),
    ),
    sentryDsn: const String.fromEnvironment('SENTRY_DSN'),
    isRelease: kReleaseMode,
  );

  static const _defaultApiBaseUrl = 'http://10.0.2.2:8000';

  /// [raw]를 trim하고, 비었으면 개발용 기본 주소를 돌려준다.
  /// `.env`에 `API_BASE_URL=`처럼 빈 값이 정의된 경우를 막는다.
  @visibleForTesting
  static String resolveApiBaseUrl(String raw) {
    final trimmed = raw.trim();
    return trimmed.isEmpty ? _defaultApiBaseUrl : trimmed;
  }

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

// [QA] 2026-11-09 FIX
// [보안] 릴리스에서 https:// 가 아닌 주소는 StateError로 거부한다. 대소문자를 구분하므로
//        HTTPS:// 도 거부된다(안전한 쪽으로 실패). 호스트가 비어 있는지는 확인하지 않는다.
// [유지보수] .env에서 API_BASE_URL을 비워 두면 빈 문자열이 define되어 기본값이 무시된다(FIX 항목).
