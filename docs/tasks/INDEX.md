# Task 목록 (F-01 ~ F-14)

- 근거: `docs/spec/SPEC.md` (승인됨, 2026-11-09 최초 승인, 2026-11-13 설계 검토 반영 승인)
- 범위: 우선순위 "필수" F-01 ~ F-14. 2차(F-15 ~ F-18)는 Task로 만들지 않음(서버 기록 조회 GET과 재설치 복원 F-18 포함)
- 병렬 그룹은 최대 3개 동시. 같은 그룹 Task끼리 예상 수정 파일이 겹치지 않음을 확인함
- 순서 번호가 같은 행은 같은 시점에 함께 돌려도 된다
- 선행 Task 표기: 받아 쓰는 `app/lib` 계약을 내보내는 Task는 모두 적는다. 테스트 지원 파일(`app/test/support/`)만 받아 쓰는 경우, 그 Task가 다른 선행 Task를 거쳐 이미 끝나 있으면 생략한 곳이 있다(실행 순서는 아래 표가 보장)

## 실행 순서

| 순서 | Task | 실행 방식 | 그룹 | 선행 Task | 예상 수정 파일 |
|---|---|---|---|---|---|
| 1 | TASK-01 Flutter 프로젝트 생성과 의존성 (완료) | 순차 | - | - | app/pubspec.yaml, app/analysis_options.yaml, app/android/app/build.gradle.kts, AndroidManifest(main, debug), app/lib/main.dart |
| 2 | TASK-02 환경 설정과 오류 보고 인터페이스 (완료) | 순차 | - | 01 | app/lib/app/env.dart, app/lib/core/monitoring/error_reporter.dart, app/.env.example |
| 3 | TASK-03 앱 뼈대(라우터, 테마) (완료) | 순차 | - | 02 | app/lib/app/{routes,router,app,placeholder_screen}.dart, app/lib/main.dart |
| 4 | TASK-04 랜드마크 모델과 클립 JSON (완료) | 순차 | - | 01 | app/lib/pose/landmarks/*, app/test/fixtures/clips/* |
| 5 | TASK-05 관절 각도와 좌우 선택 (완료) | 순차 | - | 04 | app/lib/pose/angle/joint_angle.dart |
| 6 | TASK-06 테스트용 합성 클립 생성기 | 병렬 | G1 | 05 | app/test/support/synthetic_clip*.dart |
| 6 | TASK-07 각도 이동 평균(시간 기준 창) | 병렬 | G1 | 01 | app/lib/pose/angle/moving_average.dart (다시 작성) |
| 7 | TASK-08 횟수 상태 머신(원시 각도 최저점) | 순차 | - | 06, 07 | app/lib/pose/rep/rep_counter.dart |
| 8 | TASK-09 자세 오류 판정 | 병렬 | G2 | 08 | app/lib/pose/judge/* |
| 8 | TASK-10 체형별 루틴 데이터 | 병렬 | G2 | 04 | app/lib/features/routine/* |
| 8 | TASK-11 음성 안내 서비스(글자 안내 대체 포함) | 병렬 | G2 | 01 | app/lib/core/tts/* |
| 9 | TASK-12 반복 점수와 점수 등급 | 병렬 | G3 | 09 | app/lib/pose/score/rep_score.dart |
| 9 | TASK-13 전신 인식, 정면 판정, 주 인물, 자세 게이트 | 병렬 | G3 | 05, 06 | app/lib/pose/body/body_check.dart |
| 9 | TASK-26 추적 감시(미검출, 저사양, reset) | 병렬 | G3 | 01 | workout/domain/tracking_monitor.dart |
| 10 | TASK-14 촬영 가이드 상태 머신(운동별 조건과 문구) | 순차 | - | 13 | workout/domain/setup_guide_controller.dart |
| 11 | TASK-15 프레임 분석기 | 순차 | - | 07, 08, 09, 12 | app/lib/pose/analyzer/rep_analyzer.dart |
| 12 | TASK-49 분석기 측정 쪽 유지 규칙과 자세 게이트 (새) | 순차 | - | 06, 08, 13, 15 | app/lib/pose/analyzer/rep_analyzer.dart |
| 13 | TASK-16 세트와 휴식 세션 컨트롤러 | 병렬 | G4 | 10, 15 | workout/domain/workout_session_controller.dart |
| 13 | TASK-17 운동 결과 요약 모델 | 병렬 | G4 | 10, 12, 15 | workout/domain/workout_summary.dart |
| 13 | TASK-22 스켈레톤 오버레이 위젯 | 병렬 | G4 | 04 | workout/widgets/skeleton_overlay.dart |
| 14 | TASK-18 운동 이벤트별 음성 문구 | 병렬 | G5 | 11, 16 | workout/domain/voice_cues.dart |
| 14 | TASK-23 점수 배지 위젯 | 병렬 | G5 | 03, 12 | workout/widgets/score_badge.dart |
| 14 | TASK-24 휴식 오버레이 위젯 | 병렬 | G5 | 03 | workout/widgets/rest_overlay.dart |
| 15 | TASK-19 자세 추정 채널 계약(Dart) | 순차 | - | 04 | app/lib/pose/detector/*, app/test/support/fake_pose_detector.dart |
| 16 | TASK-20 Android 카메라 미리보기(회전, 반전, 화면 꺼짐 방지) | 순차 | - | 19 | build.gradle.kts, kotlin/com/atheleo/app/{MainActivity,pose/CameraController,pose/PoseChannelHandler}.kt, src/test/kotlin/.../CameraStartInfoTest.kt |
| 17 | TASK-50 포즈 모델 다운로드 스크립트와 체크섬 (새) | 순차 | - | 20 | scripts/{download_pose_models.sh,pose_models.sha256,test_download_pose_models.sh}, build.gradle.kts, .gitignore |
| 18 | TASK-21 MediaPipe Pose Landmarker 연결 | 순차 | - | 20, 50 | build.gradle.kts, kotlin/.../pose/{PoseLandmarkerHelper,PoseChannelHandler,PoseEventMapper}.kt, src/test/kotlin/.../PoseEventMapperTest.kt |
| 19 | TASK-25 촬영 가이드 화면(권한, 미리보기 비율) | 순차 | - | 03, 06, 13, 14, 19, 21 | app/lib/core/permission/*, workout/widgets/camera_preview_view.dart, workout/presentation/setup_guide_screen.dart, router.dart |
| 20 | TASK-51 촬영 가이드 음성 안내와 글자 안내 띠 (새) | 순차 | - | 06, 11, 14, 19, 25 | workout/presentation/setup_guide_screen.dart |
| 21 | TASK-27 운동 진행 컨트롤러 | 순차 | - | 11, 13, 16, 17, 18, 19, 49 | app/lib/core/clock.dart, workout/application/{workout_view_state,workout_controller}.dart |
| 22 | TASK-52 휴식, 일시정지 중 분석 중단과 분석기 초기화 (새) | 순차 | - | 06, 16, 19, 27, 49 | workout/application/workout_controller.dart |
| 23 | TASK-28 운동 중 예외 처리 | 순차 | - | 02, 18, 19, 26, 27, 52 | workout/application/workout_controller.dart |
| 24 | TASK-29 운동 화면(표시) | 순차 | - | 03, 11, 22, 23, 24, 25, 27, 28 | workout/presentation/workout_screen.dart, router.dart |
| 25 | TASK-53 운동 화면 조작(일시정지, 종료, 뒤로 가기 확인) (새) | 순차 | - | 16, 27, 28, 29, 52 | workout/presentation/workout_screen.dart |
| 26 | TASK-30 운동 결과 화면(표시) | 순차 | - | 23, 27 | workout/presentation/workout_result_screen.dart, workout/widgets/rep_score_chart.dart, router.dart |
| 27 | TASK-31 로컬 DB 스키마(drift) | 순차 | - | 01 | app/lib/core/storage/app_database.dart, history/domain/sync_status.dart |
| 28 | TASK-32 운동 기록 로컬 저장소(소유자별) | 순차 | - | 17, 31 | history/data/workout_local_repository.dart |
| 29 | TASK-54 기록 guest 귀속과 동기화 실패 횟수 (새) | 순차 | - | 31, 32 | history/data/workout_local_repository.dart |
| 30 | TASK-33 토큰과 사용자 id 암호화 저장소 | 순차 | - | 01 | app/lib/core/storage/token_storage.dart, app/test/support/in_memory_token_storage.dart |
| 31 | TASK-34 API 클라이언트 | 순차 | - | 02, 33 | app/lib/core/network/{api_client,session_events}.dart, app/test/support/fake_http_adapter.dart |
| 32 | TASK-35 인증 저장소와 로그인 상태 | 순차 | - | 33, 34 | app/lib/features/auth/{data,application}/* |
| 33 | TASK-36 로그인, 회원가입 화면 | 순차 | - | 03, 35 | app/lib/features/auth/{domain,presentation}/*, routes.dart, router.dart |
| 34 | TASK-37 인증 가드와 토큰 만료 이동 | 순차 | - | 03, 34, 35, 36 | app/lib/app/auth_redirect.dart, router.dart |
| 35 | TASK-38 운동 기록 업로드 API | 병렬 | G6 | 17, 34 | history/data/workout_remote_api.dart |
| 35 | TASK-45 랜드마크 클립 기록과 내보내기 | 병렬 | G6 | 13, 19, 27 | app/lib/features/dev/{domain,data}/* |
| 36 | TASK-39 동기화 서비스(오류별 처리, 수동 재시도) | 순차 | - | 02, 31, 32, 35, 38, 54 | app/lib/core/network/network_status.dart, history/application/sync_service.dart |
| 37 | TASK-55 자동 동기화 실행 시점과 guest 귀속 (새) | 순차 | - | 03, 33, 34, 35, 39, 54 | history/application/sync_service.dart, app/lib/app/app_startup.dart, app/lib/main.dart, app/test/smoke_test.dart |
| 38 | TASK-40 결과 화면 저장과 로그인 안내 | 순차 | - | 27, 30, 31, 32, 35, 36, 39, 55 | workout/application/result_save_controller.dart, workout/widgets/result_save_section.dart, router.dart |
| 39 | TASK-41 기록 목록 화면 | 순차 | - | 31, 32, 35, 37, 39, 54, 55 | history/{domain/group_by_day,widgets/sync_status_chip,presentation/history_list_screen}.dart, router.dart |
| 40 | TASK-42 기록 상세 화면 | 순차 | - | 23, 30, 35, 41 | history/presentation/history_detail_screen.dart, router.dart |
| 41 | TASK-43 프로필 저장소와 상태 | 순차 | - | 10, 34, 35 | app/lib/features/profile/{data,application}/* |
| 42 | TASK-44 프로필 화면 | 순차 | - | 36, 37, 43 | profile/presentation/profile_screen.dart, router.dart |
| 43 | TASK-46 개발자 메뉴 화면 | 순차 | - | 03, 22, 25, 45 | dev/presentation/dev_menu_screen.dart, router.dart |
| 44 | TASK-47 홈 화면 | 순차 | - | 03, 10, 27, 32, 35, 46 | home/presentation/home_screen.dart, router.dart |
| 45 | TASK-48 Sentry 연결 | 순차 | - | 02, 03, 28, 39, 47, 55 | app/lib/core/monitoring/sentry_error_reporter.dart, app/lib/main.dart |

- 경로 앞부분 생략: `workout/`, `history/`, `profile/`, `dev/`, `home/`은 `app/lib/features/` 아래, `kotlin/`은 `app/android/app/src/main/kotlin/`, `src/test/kotlin/`은 `app/android/app/src/test/kotlin/`, `build.gradle.kts`는 `app/android/app/build.gradle.kts`, `router.dart`, `routes.dart`는 `app/lib/app/`. 각 Task의 테스트 파일은 표에서 뺐다(TASK-55의 `smoke_test.dart`는 기존 파일 수정이라 적음).
- TASK-31, 33은 선행이 TASK-01뿐이고, TASK-19 → 20 → 50 → 21은 TASK-04만 필요해 더 일찍 돌려도 된다. 순차 Task끼리 겹치지 않게 위 순서를 기본으로 둔다.
- 같은 파일을 차례로 고치는 묶음(앞 Task가 통과한 뒤 다음 Task): `rep_analyzer.dart` 15 → 49, `workout_controller.dart` 27 → 52 → 28, `setup_guide_screen.dart` 25 → 51, `workout_screen.dart` 29 → 53, `workout_local_repository.dart` 32 → 54, `sync_service.dart` 39 → 55, `main.dart` 55 → 48, `build.gradle.kts` 20 → 50 → 21.

## 기능별 대응

| 기능 | 핵심 Task | 인수 조건을 테스트로 확인하는 Task |
|---|---|---|
| F-01 자세 추정, 카메라 유지, 모델 다운로드 | 19, 20, 21, 25, 26, 27, 28, 50 | 19(채널 계약), 20, 21(실기기 수동), 22, 25(카메라 유지), 26, 28(측정 초기화), 29, 50(체크섬) |
| F-02 각도, 측정 쪽 유지 | 05, 49 | 05, 06, 49 |
| F-03 횟수, 자세 게이트, 초기화 | 07, 08, 13, 15, 49, 52 | 08, 13, 15(15/30fps), 49(게이트), 52(rep_index, 재개) |
| F-04 오류 판정, 원시 최저점 | 08, 09 | 08, 09, 15 |
| F-05 반복 점수 | 12 | 12, 15, 23, 29 |
| F-06 음성 안내, 글자 대체 | 11, 16, 18, 27, 51 | 11, 16, 18, 27(휴식 3초 전), 29(글자 띠), 51(가이드 상태, 3·2·1) |
| F-07 시각 피드백, 촬영 가이드 | 13, 14, 20, 21, 22, 23, 25 | 13, 14, 22, 25, 49(스쿼트 게이트) |
| F-08 세트, 휴식, 화면 꺼짐 방지, 뒤로 가기 | 16, 20, 27, 28, 52, 53 | 16, 20(수동), 27, 28(휴식 중 미검출), 29, 52(휴식 중 미투입), 53(뒤로 가기) |
| F-09 체형별 루틴 | 10 | 10, 47 |
| F-10 회원가입, 로그인, 사용자 id, 만료 | 33, 34, 35, 36, 37, 40 | 33, 34, 35, 37, 40(needLogin) |
| F-11 저장과 동기화 | 31, 32, 38, 39, 40, 54, 55 | 38, 39, 40, 41, 54, 55 |
| F-12 기록 조회(로컬 DB, 소유자별) | 32, 41, 42, 54 | 32, 41, 42, 54 |
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
| TASK-05(재작업), 06, 09, 13, 15, 19 | QA-TASK-05 1안: `selectSide`가 세 점 묶음 중 길이 0이나 유한하지 않은 좌표가 있는 쪽을 쓰지 않음(시그니처 유지). 받아 쓰는 쪽 설명 문구 동기화, TASK-06 점 겹침 금지 문구, TASK-15 테스트 보강, TASK-19 추가 발췌에 NaN/Infinity와 aspectRatio 0 이하 프레임 버림 (2026-11-09) |

## 2026-11-13 설계 검토 반영

반영 완료(2026-11-13). Spec 변경 이력 2026-11-13 행(D1~D4, 설계 보완 18건, Q-06, Q-07)을 Task에 반영했다. 구현 완료된 TASK-01~05 파일은 고치지 않고, 바뀌어야 할 부분은 뒤 Task나 새 Task가 맡는다.

### 새 Task

| Task | 역할 | 끼어든 자리 |
|---|---|---|
| TASK-49 | 분석기 측정 쪽 유지(세트 시작 때 결정, 0.5초 유지 시만 변경), 푸쉬업 게이트(수평 30도, 매 프레임), 스쿼트 게이트(수직 30도, 처음 UP 전) | TASK-15 다음, TASK-27 앞 |
| TASK-50 | 포즈 모델 다운로드 스크립트, SHA-256 체크섬, Gradle `verifyPoseModels`, `.gitignore` | TASK-20 다음, TASK-21 앞 |
| TASK-51 | 촬영 가이드 상태 변화 음성, 3·2·1과 '시작', 글자 안내 띠 | TASK-25 다음 |
| TASK-52 | 휴식, 일시정지 중 분석기 미투입, 다음 세트와 재개 때 `analyzer.reset()`(rep_index 1부터), 재개 경로 `resume()` 하나로 | TASK-27 다음, TASK-28 앞 |
| TASK-53 | 운동 화면 일시정지/재개, 종료 버튼, 뒤로 가기 종료 확인 창, 이어서 하기 대화상자 | TASK-29 다음 |
| TASK-54 | `claimGuestSessions`, `recordServerFailure`(5xx만, 5회 상한 failed), `retryFailed`(수동 재시도 상태 되돌리기) | TASK-32 다음, TASK-39 앞 |
| TASK-55 | `SyncService.start()`(앱 시작 복원, 로그인, 네트워크 복구 때 동기화), 로그인 시 guest 귀속, `AppStartup`으로 앱 시작 즉시 서비스 생성 | TASK-39 다음, TASK-40 앞 |

### 바뀐 Task

| Task | 바뀐 내용 | 반영한 Spec 항목 |
|---|---|---|
| TASK-06 | `bodyTiltDeg`(푸쉬업 게이트), `poseFor(frameIndex, angle)`, pushUp 엎드림/squat 선 자세 명시. 중단 후 남은 파일 없음 | 자세 게이트, 측정 쪽 유지 |
| TASK-07 | 창을 시간 기준 150ms(최소 1프레임)로, `add(value, timestampMs)`, `length`. untracked `moving_average.dart`와 테스트는 새 계약 기준으로 다시 작성 | 이동 평균 시간 기준 |
| TASK-08 | `update(rawAngle:)`, minAngle과 bottomMs를 원시 각도 최저점 주변 3프레임 중앙값으로, reset 뒤 repIndex 1 | 깊이 판정, rep_index |
| TASK-09 | 깊이는 `rep.minAngle`(원시) 기준 명시, `SQ_TORSO_LEAN` 45도 유지와 보정 대상 주석 | 깊이 판정, 45도 보정 대상 |
| TASK-11 | 한국어 TTS 없으면 글자 모드(`isKoreanAvailable`, `captions`, `unavailableNotice` 한 번), `voiceCaptionProvider` | 한국어 TTS 미지원 |
| TASK-13 | `passesPostureGate`(푸쉬업 수평 30도, 스쿼트 수직 30도) | 자세 게이트, Q-07 |
| TASK-14 | 운동별 컨트롤러, `notInPosture`, 운동별 거리 안내와 준비 자세 문구, ready '시작' | 운동별 가이드 조건, 거리 안내(D1) |
| TASK-15 | 시간 기준 이동 평균, RepCounter에 원시 각도, reset 규칙, 15/30fps 테스트. 측정 쪽 유지와 게이트는 TASK-49로 분리 | 이동 평균, 깊이 판정 |
| TASK-16 | `RestEndingSoon`(휴식 종료 3초 전 한 번), nowMs는 앱 시계 | 음성 추가, 시계 단일화 |
| TASK-18 | `RestEndingSoon` 문구 | 휴식 종료 3초 전 음성 |
| TASK-19 | `start`가 `PoseCameraInfo`(textureId, width, height) 반환, 실행 중 start는 같은 값, `isRunning`, 회전/전면 반전/화면 꺼짐 방지는 Kotlin 책임 | 카메라 유지, 미리보기 비율, 반전 일치, 화면 꺼짐 방지 |
| TASK-20 | `CameraStartInfo`, 텍스처 회전과 전면 반전, `FLAG_KEEP_SCREEN_ON`을 start/stop에 묶음 | 같음 |
| TASK-21 | 모델 파일은 TASK-50이 받음(assets 커밋 제외), 세로 기준 크기, 후면 반전 없음 | 모델 다운로드 |
| TASK-22 | 뒤집지 않음 명시, 부모가 미리보기 비율 상자 | 반전 일치 |
| TASK-25 | 운동별 문구, `CameraPreviewView(camera:)` 비율 유지, 운동 화면으로 넘어갈 때 stop 안 함. 음성은 TASK-51로 분리 | 카메라 유지, 비율, 거리 안내 |
| TASK-26 | `reset()` 의미 확정(미검출과 fps 창 초기화, lite 유지) | 복귀/재개 시 성능 측정 초기화 |
| TASK-27 | `WorkoutViewState.camera`, 세션 시간은 `clockProvider`만, 휴식 종료 3초 전 음성, dispose 시 stop. `activeWorkoutProvider` 삭제. 선행을 TASK-49로 | 시계 단일화, 카메라 유지, D3 |
| TASK-28 | 휴식 중 미검출 무시, 다음 세트에서 감시 reset, 재개와 복귀 때 측정 초기화, 자동 재개는 TASK-52 `resume()` | 휴식 중 미검출, 성능 측정 초기화 |
| TASK-29 | 비율 상자 안 스켈레톤, 글자 안내 띠. 조작은 TASK-53으로 분리 | 비율, 글자 안내 |
| TASK-31 | `userId` nullable(guest), `syncAttempts`, `SyncStatus.failed`, 라벨 4종 | 데이터 모델 |
| TASK-32 | 저장, 목록, 상세, 대기 목록에 소유자 인자, `watchStatus`. guest 귀속과 시도 횟수는 TASK-54 | 로컬 기록 소유 규칙 |
| TASK-33 | 사용자 id 저장(`readUserId`, `writeUserId`) | 사용자 id 저장 |
| TASK-34 | `ApiErrorKind`에 forbidden, tooManyRequests, clientError. refresh 실패 시 사용자 id도 삭제. 내보내기 표에 `sessionEventsProvider`, `FakeResponse` | 동기화 오류별 처리 |
| TASK-35 | `AuthState.userId`, `currentUserIdProvider`, 로그아웃/만료가 로컬 기록을 지우지 않음 | 사용자 id, D4 |
| TASK-36 | 내보내기 표에 `validateNickname`, `AppRoutes.loginLocation` 명시 | 계약 표기 |
| TASK-37 | 운동 경로(`/workout/...`)에서는 만료 이동 안 함, 운동 밖은 로그인으로, `/history`는 로그인 불필요 | D3, D4 |
| TASK-38 | `UploadServerError`(5xx), `UploadNeedsLogin`(401), 403/404/413/422 거절, 429 다음 회차. 서버 GET은 2차(F-18) | 동기화 오류별 처리, D2 |
| TASK-39 | 오류별 처리, 5xx만 5회 상한, 현재 사용자 소유만, `retryFailed`, 'sync_failed' 보고. 실행 시점은 TASK-55 | 동기화, Q-06 |
| TASK-40 | 비로그인과 만료 모두 guest 저장 후 needLogin 안내, 로그인 뒤 반영은 `watchStatus`, failed 문구 | D3, D4 |
| TASK-41 | 로컬 DB만, 현재 사용자(guest) 기록만, 상태 4종, 실패 '다시 시도', 서버 GET은 2차 | D2, D4, 수동 재시도 |
| TASK-42 | 현재 사용자 소유만 조회, 서버 GET은 2차 | D2 |
| TASK-43 | 내보내기 표에 `profileControllerProvider`, `ApiErrorKind` 최신 값 | 계약 표기 |
| TASK-46 | `PoseCameraInfo`, `CameraPreviewView(camera:)` 계약, `cameraPermissionProvider` 행 분리 | 계약 표기 |
| TASK-47 | 오늘 요약을 현재 사용자 기록으로 한정 | 로컬 기록 소유 규칙 |
| TASK-48 | 'sync_failed' 보고, user_id 제거, `AppStartup` 구조 유지 | 모니터링 |

- 바뀌지 않은 Task: TASK-10, 12, 17, 23, 24, 30, 44, 45
- 선행 Task 표기 보강: TASK-25(03, 06), 28(02, 19, 27), 29(03, 11, 27), 39(31, 32), 40(27, 31), 41(31, 55), 43(34), 46(03, 22), 47(03, 27), 48(02, 03, 55)

### 순서 변경

| 변경 | 이유 |
|---|---|
| TASK-15 다음에 TASK-49를 끼우고 TASK-27의 선행을 15 → 49로 | 분석기 최종 계약(측정 쪽, 게이트)이 운동 컨트롤러 전에 있어야 함 |
| TASK-20과 21 사이에 TASK-50 | MediaPipe 연결 전에 모델 파일과 빌드 검사가 있어야 함 |
| TASK-25 다음에 TASK-51 | 같은 화면 파일을 차례로 고침 |
| TASK-27과 28 사이에 TASK-52 | 예외 처리의 자동 재개가 `resume()`(분석기 초기화) 경로에 기댐 |
| TASK-29 다음에 TASK-53 | 같은 화면 파일, `confirmResume`(TASK-28)과 `resume()`(TASK-52)에 기댐 |
| TASK-32와 33 사이에 TASK-54 | 동기화(TASK-39)가 시도 횟수 메서드에 기댐 |
| TASK-39와 40 사이에 TASK-55 | 결과 화면과 기록 화면이 자동 동기화 서비스(앱 시작 생성)에 기댐, TASK-48이 `AppStartup` 구조에 기댐 |
| TASK-37 선행에서 TASK-27 제거(03, 34로) | 만료 이동을 경로로 판단(D3), 운동 컨트롤러에 기대지 않음 |
| 병렬 그룹 G1~G6 구성은 그대로 | 새 Task는 모두 같은 파일을 이어 고치거나 공유 파일(빌드 설정, 진입점)을 건드려 순차 |

### 구현 완료 Task(01~05)와 겹치는 부분

| 완료 Task | 겹치는 부분 | 처리 |
|---|---|---|
| TASK-05 `selectSide` | 측정 쪽을 세트 동안 유지해야 함 | `selectSide`는 그대로(프레임 하나만 판단). 시간에 걸친 유지는 TASK-49가 분석기에서 처리 |
| TASK-05 `angleDeg` 길이 0 → 0도 | 0도가 이동 평균에 들어가면 안 됨 | TASK-15(고를 수 없는 프레임 건너뜀), TASK-49(측정 쪽 각도 0이면 정상 프레임 아님) |
| TASK-03 `main.dart` `bootstrap` | 앱 시작 즉시 동기화 서비스 생성 | TASK-55가 run 위젯을 `AppStartup`으로 감쌈. 시그니처와 validate 순서 유지, 기존 bootstrap 테스트 2건 유지 |
| TASK-03 `routes.dart`, `router.dart` | 로그인 위치 함수, 각 화면 builder 교체, 만료 이동 | TASK-36(`loginLocation` 추가), 25, 29, 30, 37, 40~47(builder와 redirect) |
| TASK-01 `build.gradle.kts`, `.gitignore` | 모델 파일 Git 제외와 빌드 전 체크섬 검사 | TASK-50이 작업만 추가(기존 블록 유지) |
| TASK-04 `PoseFrame.aspectRatio` | 채널 width/height로 채움 | TASK-19가 `width / height`로 채움(TASK-04 계약 변경 없음) |

## 보류

| 항목 | 이유 | 다음 행동 |
|---|---|---|
| 서버(Django) Task | Spec Q-01: 백엔드 저장소 미확인. 앱은 저장소 인터페이스와 가짜 서버(`FakeHttpAdapter`)로 진행 | Q-01 해결 후 서버 Task 추가(인증, 프로필, 운동 업로드 API, sentry-sdk, docker-compose) |
| 서버 응답 형식 가정 | TASK-35, 38, 43이 Q-01 확정 전 형식을 가정함 | Q-01 해결 후 해당 Task의 "추가 발췌"에 실제 형식 보충 |
| 실기기 확인 | Spec Q-02: 테스트 기기 미정. TASK-20, 21의 수동 확인 항목(반전, 화면 꺼짐 방지, 카메라 유지) | 기기 확정 후 verify 단계에서 확인 |
| 판정 기준 1차 보정 | Spec Q-05: 횟수 각도, `SQ_TORSO_LEAN` 45도, 푸쉬업 게이트 30도, 스쿼트 게이트 30도. TASK-49 완료 직후 본인 영상으로 보정 권장 | TASK-45(클립 내보내기)가 먼저 필요하면 순서 조정 검토 |
| 모델 파일 체크섬 값 | TASK-50은 공식 배포처에서 실제로 받은 파일로만 체크섬을 정함. 네트워크 제한이면 중단 조건 | 도메인 허용 또는 사용자가 받은 파일로 값 확정 |

## QA에서 올라온 후속 후보 (오케스트레이터 판단 대기)

| 출처 | 내용 | 처리 |
|---|---|---|
| QA-TASK-01 | 릴리스 빌드가 디버그 키로 서명됨. 배포 전 서명 설정 Task 필요 | Spec 범위 밖(출시 제외)이라 보류 |
| QA-TASK-01 | `sqlite3_flutter_libs`는 지원 종료 패키지. drift_flutter가 간접 의존하므로 직접 의존 목록에서 빼는 것 검토 | TASK-31(drift 스키마) 때 확인 |
| QA-TASK-01 | 매니페스트 테스트가 문자열 포함 검사. 검사 항목이 늘면 XML 파싱으로 교체 | 보류 |
| TASK-01 | APK 빌드 미확인 (plugins-artifacts.gradle.org 차단) | 도메인 허용 후 확인. TASK-20, 21, 50의 빌드 확인도 같은 제약 |
| QA-TASK-04 | 클립 JSON 값 범위 검증 없음(좌표 유한성, fps > 0, aspect > 0). 현재 계약에 없음 | 실데이터 수집(Q-05) 때 Spec에서 판단 |
| QA-TASK-04 | 한 클립 안에서 aspect가 바뀌면 저장 시 첫 프레임 값으로 통일됨 | 회전 중 녹화를 허용할 경우 재검토 |
