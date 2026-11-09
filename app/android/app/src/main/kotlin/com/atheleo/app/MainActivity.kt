/*
 * [파일] Android 진입 Activity. Flutter 엔진을 띄우는 기본 FlutterActivity.
 * [Spec] 8장 비기능 요구사항(플랫폼) / [Task] TASK-01
 * [의존] 없음 (환경 변수 사용 안 함)
 */
package com.atheleo.app

import io.flutter.embedding.android.FlutterActivity

class MainActivity : FlutterActivity()

/*
 * [QA] 2026-11-09 FIX
 * [보안] 로직 없음. 플랫폼 채널은 TASK-20, 21에서 이 패키지(com.atheleo.app)에 추가.
 * [유지보수] 패키지 경로는 다음 Task와의 계약이므로 옮기지 말 것.
 */
