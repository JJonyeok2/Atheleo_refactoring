# Task 목록 (F-01 ~ F-14)

- 근거: `docs/spec/SPEC.md` (승인됨, 2026-11-09)
- 범위: 우선순위 "필수" F-01 ~ F-14. 2차(F-15 ~ F-17)는 Task로 만들지 않음
- 병렬 그룹은 최대 3개 동시. 같은 그룹 Task끼리 예상 수정 파일이 겹치지 않음을 확인함
- 순서 번호가 같은 행은 같은 시점에 함께 돌려도 된다

## 실행 순서

| 순서 | Task | 실행 방식 | 그룹 | 선행 Task | 예상 수정 파일 |
|---|---|---|---|---|---|
| 1 | TASK-01 Flutter 프로젝트 생성과 의존성 | 순차 | - | - | app/pubspec.yaml, app/analysis_options.yaml, app/android/app/build.gradle.kts, AndroidManifest(main, debug), app/lib/main.dart |
| 2 | TASK-02 환경 설정과 오류 보고 인터페이스 | 순차 | - | 01 | app/lib/app/env.dart, app/lib/core/monitoring/error_reporter.dart, app/.env.example |
| 3 | TASK-03 앱 뼈대(라우터, 테마) | 순차 | - | 02 | app/lib/app/{routes,router,app,placeholder_screen}.dart, app/lib/main.dart |
| 4 | TASK-04 랜드마크 모델과 클립 JSON | 순차 | - | 01 | app/lib/pose/landmarks/*, app/test/fixtures/clips/* |
| 5 | TASK-05 관절 각도와 좌우 선택 | 순차 | - | 04 | app/lib/pose/angle/joint_angle.dart |
| 6 | TASK-06 테스트용 합성 클립 생성기 | 병렬 | G1 | 05 | app/test/support/synthetic_clip*.dart |
| 6 | TASK-07 각도 이동 평균 | 병렬 | G1 | 01 | app/lib/pose/angle/moving_average.dart |
| 7 | TASK-08 횟수 상태 머신 | 순차 | - | 06, 07 | app/lib/pose/rep/rep_counter.dart |
| 8 | TASK-09 자세 오류 판정 | 병렬 | G2 | 08 | app/lib/pose/judge/* |
| 8 | TASK-10 체형별 루틴 데이터 | 병렬 | G2 | 04 | app/lib/features/routine/* |
| 8 | TASK-11 음성 안내 서비스 | 병렬 | G2 | 01 | app/lib/core/tts/* |
| 9 | TASK-12 반복 점수와 점수 등급 | 병렬 | G3 | 09 | app/lib/pose/score/rep_score.dart |
| 9 | TASK-13 전신 인식, 정면 판정, 주 인물 선택 | 병렬 | G3 | 05, 06 | app/lib/pose/body/body_check.dart |
| 9 | TASK-26 추적 감시(미검출, 저사양) | 병렬 | G3 | 01 | app/lib/features/workout/domain/tracking_monitor.dart |
| 10 | TASK-14 촬영 가이드 상태 머신 | 순차 | - | 13 | app/lib/features/workout/domain/setup_guide_controller.dart |
| 11 | TASK-15 프레임 분석기 | 순차 | - | 07, 08, 09, 12 | app/lib/pose/analyzer/rep_analyzer.dart |
| 12 | TASK-16 세트와 휴식 세션 컨트롤러 | 병렬 | G4 | 10, 15 | app/lib/features/workout/domain/workout_session_controller.dart |
| 12 | TASK-17 운동 결과 요약 모델 | 병렬 | G4 | 10, 12, 15 | app/lib/features/workout/domain/workout_summary.dart |
| 12 | TASK-22 스켈레톤 오버레이 위젯 | 병렬 | G4 | 04 | app/lib/features/workout/widgets/skeleton_overlay.dart |
| 13 | TASK-18 운동 이벤트별 음성 문구 | 병렬 | G5 | 11, 16 | app/lib/features/workout/domain/voice_cues.dart |
| 13 | TASK-23 점수 배지 위젯 | 병렬 | G5 | 03, 12 | app/lib/features/workout/widgets/score_badge.dart |
| 13 | TASK-24 휴식 오버레이 위젯 | 병렬 | G5 | 03 | app/lib/features/workout/widgets/rest_overlay.dart |
| 14 | TASK-19 자세 추정 채널 계약(Dart) | 순차 | - | 04 | app/lib/pose/detector/*, app/test/support/fake_pose_detector.dart |
| 15 | TASK-20 Android 카메라 미리보기 | 순차 | - | 19 | build.gradle.kts, kotlin/com/atheleo/app/{MainActivity,pose/CameraController,pose/PoseChannelHandler}.kt |
| 16 | TASK-21 MediaPipe Pose Landmarker 연결 | 순차 | - | 20 | build.gradle.kts, kotlin/.../pose/{PoseLandmarkerHelper,PoseChannelHandler,PoseEventMapper}.kt, assets/*.task |
| 17 | TASK-25 촬영 가이드 화면(권한 포함) | 순차 | - | 14, 19, 21 | app/lib/core/permission/*, workout/widgets/camera_preview_view.dart, workout/presentation/setup_guide_screen.dart, app/lib/app/router.dart |
| 18 | TASK-27 운동 진행 컨트롤러 | 순차 | - | 11, 13, 15, 16, 17, 18, 19 | app/lib/core/clock.dart, app/lib/features/workout/application/* |
| 19 | TASK-28 운동 중 예외 처리 | 순차 | - | 26, 27 | app/lib/features/workout/application/workout_controller.dart |
| 20 | TASK-29 운동 화면 | 순차 | - | 22, 23, 24, 25, 28 | workout/presentation/workout_screen.dart, app/lib/app/router.dart |
| 21 | TASK-30 운동 결과 화면(표시) | 순차 | - | 23, 27 | workout/presentation/workout_result_screen.dart, workout/widgets/rep_score_chart.dart, router.dart |
| 22 | TASK-31 로컬 DB 스키마(drift) | 순차 | - | 01 | app/lib/core/storage/app_database.dart, history/domain/sync_status.dart |
| 23 | TASK-32 운동 기록 로컬 저장소 | 순차 | - | 17, 31 | app/lib/features/history/data/workout_local_repository.dart |
| 24 | TASK-33 토큰 암호화 저장소 | 순차 | - | 01 | app/lib/core/storage/token_storage.dart, app/test/support/in_memory_token_storage.dart |
| 25 | TASK-34 API 클라이언트 | 순차 | - | 02, 33 | app/lib/core/network/{api_client,session_events}.dart, app/test/support/fake_http_adapter.dart |
| 26 | TASK-35 인증 저장소와 로그인 상태 | 순차 | - | 34 | app/lib/features/auth/{data,application}/* |
| 27 | TASK-36 로그인, 회원가입 화면 | 순차 | - | 03, 35 | app/lib/features/auth/{domain,presentation}/*, routes.dart, router.dart |
| 28 | TASK-37 인증 가드와 만료 이동 | 순차 | - | 27, 36 | app/lib/app/auth_redirect.dart, router.dart |
| 29 | TASK-38 운동 기록 업로드 API | 병렬 | G6 | 17, 34 | app/lib/features/history/data/workout_remote_api.dart |
| 29 | TASK-45 랜드마크 클립 기록과 내보내기 | 병렬 | G6 | 13, 19, 27 | app/lib/features/dev/{domain,data}/* |
| 30 | TASK-39 동기화 서비스 | 순차 | - | 32, 35, 38 | app/lib/core/network/network_status.dart, history/application/sync_service.dart |
| 31 | TASK-40 결과 화면 저장과 로그인 안내 | 순차 | - | 30, 36, 39 | workout/application/result_save_controller.dart, workout/widgets/result_save_section.dart, router.dart |
| 32 | TASK-41 기록 목록 화면 | 순차 | - | 32, 37, 39 | history/{domain/group_by_day,widgets/sync_status_chip,presentation/history_list_screen}.dart, router.dart |
| 33 | TASK-42 기록 상세 화면 | 순차 | - | 23, 30, 41 | history/presentation/history_detail_screen.dart, router.dart |
| 34 | TASK-43 프로필 저장소와 상태 | 순차 | - | 10, 35 | app/lib/features/profile/{data,application}/* |
| 35 | TASK-44 프로필 화면 | 순차 | - | 36, 37, 43 | profile/presentation/profile_screen.dart, router.dart |
| 36 | TASK-46 개발자 메뉴 화면 | 순차 | - | 25, 45 | dev/presentation/dev_menu_screen.dart, router.dart |
| 37 | TASK-47 홈 화면 | 순차 | - | 10, 32, 35, 46 | home/presentation/home_screen.dart, router.dart |
| 38 | TASK-48 Sentry 연결 | 순차 | - | 28, 39, 47 | app/lib/core/monitoring/sentry_error_reporter.dart, app/lib/main.dart |

- 경로 앞부분 생략: `workout/`, `history/`, `profile/`, `dev/`, `home/`은 `app/lib/features/` 아래, `kotlin/`은 `app/android/app/src/main/kotlin/`, `router.dart`, `routes.dart`는 `app/lib/app/`. 각 Task의 테스트 파일은 표에서 뺐다.
- TASK-31, 33은 선행이 TASK-01뿐이라 더 일찍 돌려도 된다. 순차 Task끼리 겹치지 않게 위 순서를 기본으로 둔다.

## 기능별 대응

| 기능 | 핵심 Task | 인수 조건을 테스트로 확인하는 Task |
|---|---|---|
| F-01 자세 추정 | 19, 20, 21 | 19(채널 계약), 21(실기기 수동), 22, 29 |
| F-02 각도, 좌우 선택 | 05 | 05, 06 |
| F-03 횟수 | 07, 08 | 08, 15 |
| F-04 오류 판정 | 09 | 09, 15 |
| F-05 반복 점수 | 12 | 12, 15, 23, 29 |
| F-06 음성 안내 | 11, 18 | 11, 27 |
| F-07 시각 피드백, 촬영 가이드 | 13, 14, 22, 23, 25 | 14, 25 |
| F-08 세트와 휴식 | 16 | 16, 27, 29 |
| F-09 체형별 루틴 | 10 | 10, 47 |
| F-10 회원가입, 로그인 | 33, 34, 35, 36, 37 | 33, 34, 35, 37 |
| F-11 저장과 동기화 | 31, 32, 38, 39, 40 | 38, 39, 40, 41 |
| F-12 기록 조회 | 41, 42 | 41, 42 |
| F-13 프로필 | 43, 44 | 43, 44 |
| F-14 랜드마크 내보내기 | 45, 46 | 03, 45, 46 |
| 비기능: 모니터링 | 02, 28, 39, 48 | 48 |

## 결정 필요

| ID | 내용 | 상태 |
|---|---|---|
| D-01 | 횟수 판정 기준과 깊이 부족 기준이 동시에 성립할 수 없던 문제 | Spec 수정으로 해결 (2026-11-09, 7장 판정 기준과 F-03, F-04 인수 조건 변경) |

## Spec 변경(2026-11-09 7장) 반영 기록

반영 완료(2026-11-09). task-agent가 직접 반영했다. 의존 관계와 실행 순서는 바뀌지 않았다.

| Task | 반영 내용 |
|---|---|
| TASK-04 | `LandmarkIndex`에 leftHeel 29, rightHeel 30 추가(TASK-05 계약 문구도 맞춤) |
| TASK-06 | `kneeForwardRatio` 삭제, `hipOffset`(`HipOffset { below, above }`)과 `heelLiftRatio` 추가 |
| TASK-08 | UP 160, 하강 시작 145, DOWN 120. `RepCounterEvent`(`RepEvent`, `PartialRepEvent`) 반환, `partialCount`. F-03 새 인수 조건 |
| TASK-09 | 오류 코드 6종(`PU_HIP_PIKE`, `SQ_HEEL_LIFT` 추가, `SQ_KNEE_FORWARD` 삭제), 깊이 기준 90도, `ErrorThresholds` 필드 변경. F-04 새 인수 조건 |
| TASK-12 | 감점표 갱신(들림 -20, 뒤꿈치 -15) |
| TASK-15 | `AnalyzerOutput`(`RepResult`, `PartialRep`) 반환, 75점 테스트를 기본 기준(105도)으로, D-01 주의 문단 삭제 |
| TASK-16 | `onPartialRep`, `PartialRepNoticed` 이벤트, `partialsPerSet` 상태 |
| TASK-17 | `SetSummary.partialReps`, `WorkoutSummary.totalPartialReps`, `buildSummary(partialsPerSet:)` |
| TASK-18 | `PartialRepNoticed` → '더 내려가세요' |
| TASK-27 | `PartialRep` 처리 경로와 테스트 추가 |
| TASK-30 | 결과 화면에 부분 반복 수 따로 표시 |
| TASK-31, 32, 38, 42 | WorkoutSet `partial_reps`(로컬 DB 컬럼, 저장소 복원, 업로드 본문, 기록 상세 표시) |

## 보류

| 항목 | 이유 | 다음 행동 |
|---|---|---|
| 서버(Django) Task | Spec Q-01: 백엔드 저장소 미확인. 앱은 저장소 인터페이스와 가짜 서버(`FakeHttpAdapter`)로 진행 | Q-01 해결 후 서버 Task 추가(인증, 프로필, 운동 업로드 API, sentry-sdk, docker-compose) |
| 서버 응답 형식 가정 | TASK-35, 38, 43이 Q-01 확정 전 형식을 가정함 | Q-01 해결 후 해당 Task의 "추가 발췌"에 실제 형식 보충 |
| 실기기 확인 | Spec Q-02: 테스트 기기 미정. TASK-20, 21의 수동 확인 항목 | 기기 확정 후 verify 단계에서 확인 |
| 판정 기준 1차 보정 | Spec Q-05: TASK-15 완료 직후 본인 영상으로 보정 권장 | TASK-45(클립 내보내기)가 먼저 필요하면 순서 조정 검토 |

## QA에서 올라온 후속 후보 (오케스트레이터 판단 대기)

| 출처 | 내용 | 처리 |
|---|---|---|
| QA-TASK-01 | 릴리스 빌드가 디버그 키로 서명됨. 배포 전 서명 설정 Task 필요 | Spec 범위 밖(출시 제외)이라 보류 |
| QA-TASK-01 | `sqlite3_flutter_libs`는 지원 종료 패키지. drift_flutter가 간접 의존하므로 직접 의존 목록에서 빼는 것 검토 | TASK-31(drift 스키마) 때 확인 |
| QA-TASK-01 | 매니페스트 테스트가 문자열 포함 검사. 검사 항목이 늘면 XML 파싱으로 교체 | 보류 |
| TASK-01 | APK 빌드 미확인 (plugins-artifacts.gradle.org 차단) | 도메인 허용 후 확인 |
| QA-TASK-04 | 클립 JSON 값 범위 검증 없음(좌표 유한성, fps > 0, aspect > 0). 현재 계약에 없음 | 실데이터 수집(Q-05) 때 Spec에서 판단 |
| QA-TASK-04 | 한 클립 안에서 aspect가 바뀌면 저장 시 첫 프레임 값으로 통일됨 | 회전 중 녹화를 허용할 경우 재검토 |
