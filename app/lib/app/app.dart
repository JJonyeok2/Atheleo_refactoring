// [파일] 앱 루트 위젯(AtheleoApp)과 기본 테마.
// [Spec] 8장 비기능 요구사항(기술 구성) / [Task] TASK-03
// [의존] 없음 (환경 변수 사용 안 함)

import 'package:atheleo/app/router.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 앱 루트 위젯. [routerProvider]의 라우터와 기본 테마를 쓴다.
class AtheleoApp extends ConsumerWidget {
  /// 루트 위젯을 만든다. [ProviderScope] 안에서 띄워야 한다.
  const new({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp.router(
      title: 'Atheleo',
      theme: buildAppTheme(),
      routerConfig: ref.watch(routerProvider),
    );
  }
}

/// 기본 테마(Material 3). 글꼴은 플랫폼 기본(안드로이드는 Noto Sans CJK)을 쓴다.
ThemeData buildAppTheme() {
  return ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
  );
}

// [QA] 2026-11-09 PASS
// [보안] 입력, 네트워크, 시크릿 없음.
// [유지보수] 글꼴은 플랫폼 기본(안드로이드 Noto Sans CJK)에 맡김. 별도 글꼴 번들은
//   디자인 요구가 생기면 추가. buildAppTheme는 Task 계약 밖의 공개 함수(테스트 재사용 가능).
