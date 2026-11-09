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
