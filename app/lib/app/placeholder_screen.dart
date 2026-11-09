// [파일] 실제 화면이 만들어지기 전까지 경로에 끼워 두는 자리표시 화면.
// [Spec] 5장 화면 목록 / [Task] TASK-03
// [의존] 없음 (환경 변수 사용 안 함)

import 'package:flutter/material.dart';

/// 실제 화면이 만들어지기 전까지 경로에 끼워 두는 자리표시 화면.
class PlaceholderScreen extends StatelessWidget {
  /// [title]을 앱 바와 본문에 보여 준다.
  const new({required this.title, super.key});

  /// 화면 제목.
  final String title;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Center(child: Text('$title 화면 준비 중')),
    );
  }
}

// [QA] 2026-11-09 PASS
// [보안] 입력, 네트워크, 시크릿 없음.
// [유지보수] 화면 Task가 모두 끝나면 router.dart에서 참조가 사라지므로 이 파일은 삭제 대상.
