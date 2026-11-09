// [파일] 앱 진입점. 설정 검증, 세로 고정 후 ProviderScope로 AtheleoApp을 띄운다.
// [Spec] 8장 비기능 요구사항(플랫폼, 기술 구성, 세로 고정) / [Task] TASK-01, TASK-03
// [의존] API_BASE_URL, SENTRY_DSN (AppEnv.fromEnvironment 경유)

import 'package:atheleo/app/app.dart';
import 'package:atheleo/app/env.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

export 'package:atheleo/app/app.dart' show AtheleoApp;

Future<void> main() => bootstrap();

/// 앱을 시작한다.
///
/// [env]가 없으면 `AppEnv.fromEnvironment()`를 쓴다. 설정이 잘못됐으면
/// (릴리스 + https 아님) `StateError`를 던지고 앱을 띄우지 않는다.
/// [run]은 테스트에서 `runApp` 대신 끼워 넣는다.
Future<void> bootstrap({
  AppEnv? env,
  void Function(Widget app) run = runApp,
}) async {
  WidgetsFlutterBinding.ensureInitialized();
  (env ?? AppEnv.fromEnvironment()).validate();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  run(const ProviderScope(child: AtheleoApp()));
}

// [QA] 2026-11-09 PASS
// [보안] 입력, 네트워크, 시크릿 없음.
// [유지보수] 라우터와 테마는 TASK-03에서 교체. `const new(...)` 생성자 문법은
//   최신 Dart 기능이라 익숙하지 않을 수 있음(analyze는 통과).
