import 'package:atheleo/app/placeholder_screen.dart';
import 'package:atheleo/app/routes.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// 없는 경로로 이동했을 때 보여 주는 문구.
const notFoundMessage = '페이지를 찾을 수 없어요';

/// 앱 라우터를 만든다.
///
/// [enableDevMenu]가 false면 `/dev` 경로 자체를 등록하지 않는다(릴리스 빌드).
/// [refreshListenable], [redirect]는 인증 흐름(TASK-37)에서 넘긴다.
GoRouter buildRouter({
  required bool enableDevMenu,
  Listenable? refreshListenable,
  GoRouterRedirect? redirect,
}) {
  return GoRouter(
    initialLocation: AppRoutes.home,
    refreshListenable: refreshListenable,
    redirect: redirect,
    errorBuilder: (context, state) => const _NotFoundScreen(),
    routes: [
      _placeholder(AppRoutes.home, '홈'),
      _placeholder(AppRoutes.login, '로그인'),
      _placeholder(AppRoutes.signup, '회원가입'),
      _placeholder(AppRoutes.history, '기록 목록'),
      _placeholder(AppRoutes.historyDetail, '기록 상세'),
      _placeholder(AppRoutes.profile, '프로필'),
      // result가 :type으로 잡히지 않도록 workout보다 먼저 등록한다.
      _placeholder(AppRoutes.workoutResult, '운동 결과'),
      _placeholder(AppRoutes.workoutSetup, '촬영 가이드'),
      _placeholder(AppRoutes.workout, '운동'),
      if (enableDevMenu) _placeholder(AppRoutes.dev, '개발자 메뉴'),
    ],
  );
}

GoRoute _placeholder(String path, String title) => GoRoute(
  path: path,
  builder: (context, state) => PlaceholderScreen(title: title),
);

/// 앱 전역 라우터. 디버그 빌드에서만 개발자 메뉴를 등록한다.
final routerProvider = Provider<GoRouter>((ref) {
  final router = buildRouter(enableDevMenu: kDebugMode);
  ref.onDispose(router.dispose);
  return router;
});

class _NotFoundScreen extends StatelessWidget {
  const new();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: Text(notFoundMessage)));
  }
}
