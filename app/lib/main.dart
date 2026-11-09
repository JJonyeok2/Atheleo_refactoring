// [파일] 앱 진입점과 루트 위젯(AtheleoApp). 현재는 빈 MaterialApp 수준.
// [Spec] 8장 비기능 요구사항(플랫폼, 기술 구성) / [Task] TASK-01
// [의존] 없음 (환경 변수 사용 안 함)

import 'package:flutter/material.dart';

void main() {
  runApp(const AtheleoApp());
}

/// 앱 루트 위젯. 라우터와 테마는 TASK-03에서 교체한다.
class AtheleoApp extends StatelessWidget {
  /// 루트 위젯을 만든다.
  const new({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      title: 'Atheleo',
      home: Scaffold(),
    );
  }
}

// [QA] 2026-11-09 FIX
// [보안] 입력, 네트워크, 시크릿 없음.
// [유지보수] 라우터와 테마는 TASK-03에서 교체. `const new(...)` 생성자 문법은
//   최신 Dart 기능이라 익숙하지 않을 수 있음(analyze는 통과).
