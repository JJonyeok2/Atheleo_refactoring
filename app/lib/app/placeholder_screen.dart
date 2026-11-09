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
