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
// [보안] 시작 시 AppEnv.validate()를 반드시 거쳐 릴리스 빌드의 http 주소를 막는다(bootstrap).
// [유지보수] 순서: ensureInitialized → validate → 세로 고정 → run. bootstrap은 테스트용
//   주입 지점(Task 계약 밖 공개 함수). AtheleoApp re-export는 기존 smoke 테스트 호환용,
//   다른 Task는 app/app.dart에서 import함. Sentry 초기화(TASK-48)는 run 자리에 붙일 것.
