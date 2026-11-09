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
