# TASK-38: 운동 기록 업로드 API

- 상태: 대기
- 선행 Task: TASK-17, TASK-34
- 실행 방식: 병렬 (그룹: G6)
- 실행 방식 근거: `app/lib/features/history/data/workout_remote_api.dart`만 새로 만듦. TASK-45와 파일, 타입이 겹치지 않음
- Spec 출처: F-11 (4장 자동 동기화 표, 6장 API, 7장)

## 왜 이렇게 나눴나
요약을 서버 형식으로 바꿔 보내고 응답을 동기화가 처리할 종류(성공, 거절, 서버 오류, 다음 회차, 로그인 필요)로 정리한다. 상태 변경과 회차 진행은 TASK-39.

## 기능 범위 (Spec 발췌)
| 메서드 | 경로 | 요청 | 응답 | 에러 |
|---|---|---|---|---|
| POST | `/api/workouts/` | 세션 전체(client_id 포함) | 201, 세션 | 400, 401, 403, 404, 409 중복 client_id(성공으로 처리), 413, 422, 429, 5xx |

| 결과 | 동기화 처리(TASK-39) |
|---|---|
| 201, 409(중복 client_id) | 저장 성공(synced) |
| 네트워크 오류 | 이번 회차 즉시 중단, 다음 회차에 다시 시도 |
| 5xx | 그 기록만 건너뛰고 다음 기록 진행, 시도 횟수 1 증가 |
| 400, 403, 404, 413, 422 등 재시도 불가 4xx | 거절(rejected), Sentry 보고 |
| 401 | refresh 갱신 시도(인터셉터), 실패하면 이번 회차 중단, 로그인 필요 |
| 429 | 이번 회차 중단, 다음 회차에 다시 시도 |

- 1차 범위에서 서버는 기록 백업 용도로만 쓴다. 랜드마크는 보내지 않는다.
- 이 Task에서 정하는 요청 본문(Q-01 확정 전 가정):
```
{"client_id": str, "exercise": "push_up"|"squat", "started_at": ISO8601 UTC, "ended_at": ISO8601 UTC,
 "routine_level": str, "total_reps": int, "avg_score": int,
 "sets": [{"set_index": int, "target_reps": int, "done_reps": int, "partial_reps": int, "rest_sec": int,
           "reps": [{"rep_index": int, "score": int, "min_angle": float, "duration_ms": int, "errors": [str]}]}]}
```
- 이 Task에서 정하는 매핑: conflict → Synced / badRequest, forbidden, notFound, clientError → Rejected / server → ServerError / network, tooManyRequests, unknown → RetryLater / unauthorized → NeedsLogin
- 거절 사유는 본문 `detail`, 없으면 `'HTTP <코드>'`. 사유에 요청 본문을 넣지 않는다

## 연결 범위

### 받아 쓰는 것
| 이름 | 위치 | 계약 |
|---|---|---|
| `apiClientProvider`, `ApiErrorKind`, `classifyError` | `app/lib/core/network/api_client.dart` | `final apiClientProvider = Provider<Dio>(...)`, `enum ApiErrorKind { network, server, badRequest, unauthorized, forbidden, notFound, conflict, tooManyRequests, clientError, unknown }`, `ApiErrorKind classifyError(Object error)` |
| `WorkoutSummary`, `SetSummary` | `app/lib/features/workout/domain/workout_summary.dart` | TASK-17 계약 그대로 |
| `FakeHttpAdapter`, `FakeResponse` | `app/test/support/fake_http_adapter.dart` | TASK-34 계약 그대로 (테스트에서만) |

### 내보내는 것 (다음 Task가 기대는 것, 바꾸면 안 됨)
| 이름 | 위치 | 계약 | 쓰는 Task |
|---|---|---|---|
| `workoutToJson` | `app/lib/features/history/data/workout_remote_api.dart` | `Map<String, dynamic> workoutToJson(WorkoutSummary summary)` | (내부) |
| `UploadOutcome` | 같은 파일 | `sealed class UploadOutcome`, `final class UploadSynced extends UploadOutcome { const UploadSynced(); }`, `final class UploadRejected extends UploadOutcome { const UploadRejected(this.reason); final String reason; }`, `final class UploadServerError extends UploadOutcome { const UploadServerError(this.statusCode); final int statusCode; }`, `final class UploadRetryLater extends UploadOutcome { const UploadRetryLater(this.kind); final ApiErrorKind kind; }`, `final class UploadNeedsLogin extends UploadOutcome { const UploadNeedsLogin(); }` | TASK-39 |
| `WorkoutRemoteApi` | 같은 파일 | `abstract class WorkoutRemoteApi { Future<UploadOutcome> upload(WorkoutSummary summary); }`, `class DioWorkoutRemoteApi implements WorkoutRemoteApi { DioWorkoutRemoteApi(Dio dio); }` | TASK-39 |
| `workoutRemoteApiProvider` | 같은 파일 | `final workoutRemoteApiProvider = Provider<WorkoutRemoteApi>(...)` | TASK-39 |

## 범위
- 위 변환과 업로드

## 범위 밖 (건드리지 않음)
- 로컬 상태 변경, 시도 횟수, 회차 진행(TASK-39), 서버 기록 조회 GET `/api/workouts/`, `/api/workouts/:id/`(2차 범위 F-18, 만들지 않음)

## 먼저 작성할 테스트 (Red)
| 테스트 이름 | 입력 / 동작 | 기대 결과 |
|---|---|---|
| 본문 형식 | 2세트 요약(partialReps 0, 2) `workoutToJson` | 위 형식, sets[1].partial_reps 2, errors는 코드 문자열, 시각은 UTC ISO8601 |
| 201과 409는 성공 (F-11) | 가짜 서버 201 / 409 | 둘 다 `UploadSynced` |
| 재시도 불가 4xx는 거절 (F-11) | 400 `{"detail": "bad"}` / 403 / 404 / 413 / 422 | `UploadRejected('bad')` / 나머지는 `UploadRejected('HTTP 403')` 형식 |
| 5xx (F-11) | 503 | `UploadServerError(503)` |
| 네트워크 오류 | `failNetwork(true)` | `UploadRetryLater(network)` |
| 429 | 429 | `UploadRetryLater(tooManyRequests)` |
| 401 갱신 실패 | `/api/workouts/` 401, refresh 401 | `UploadNeedsLogin` |

## 바뀔 것으로 예상되는 파일
- `app/lib/features/history/data/workout_remote_api.dart`
- `app/test/features/history/data/workout_remote_api_test.dart`

## 완료 조건
- [ ] 위 테스트가 모두 통과
- [ ] 기존 테스트가 깨지지 않음
- [ ] "내보내는 것"의 계약이 적힌 그대로임

## 중단 조건 (여기에 걸리면 멈추고 보고)
- 범위 밖 파일을 고쳐야 할 때
- 서버 형식이 확정되어(Q-01) 위 본문과 다를 때

## 추가 발췌 (오케스트레이터가 보충)

## 2026-11-13 설계 검토 반영
- 응답 분류를 Spec 자동 동기화 표에 맞춤: `UploadServerError`(5xx), `UploadNeedsLogin`(401) 추가, 403/404/413/422를 거절로, 429를 다음 회차로
- 서버 GET(F-18)은 2차 범위로 범위 밖에 명시
