# TASK-38: 운동 기록 업로드 API

- 상태: 대기
- 선행 Task: TASK-17, TASK-34
- 실행 방식: 병렬 (그룹: G6)
- 실행 방식 근거: `app/lib/features/history/data/workout_remote_api.dart`만 새로 만듦. TASK-45와 파일, 타입이 겹치지 않음
- Spec 출처: F-11 (6장 API, 7장, 4장 예외 흐름 서버 400)

## 왜 이렇게 나눴나
요약을 서버 형식으로 바꿔 보내고 응답을 "동기화됨 / 저장 실패 / 다시 시도" 셋 중 하나로 정리한다. 재시도 일정은 TASK-39.

## 기능 범위 (Spec 발췌)
| 메서드 | 경로 | 요청 | 응답 | 에러 |
|---|---|---|---|---|
| POST | `/api/workouts/` | 세션 전체(client_id 포함) | 201, 세션 | 400, 401, 409 중복 client_id(성공으로 처리) |

- 5xx와 네트워크 오류만 재시도, 400은 rejected, 409는 synced
- 랜드마크는 보내지 않는다.
- 이 Task에서 정하는 요청 본문(Q-01 확정 전 가정):
```
{"client_id": str, "exercise": "push_up"|"squat", "started_at": ISO8601 UTC, "ended_at": ISO8601 UTC,
 "routine_level": str, "total_reps": int, "avg_score": int,
 "sets": [{"set_index": int, "target_reps": int, "done_reps": int, "partial_reps": int, "rest_sec": int,
           "reps": [{"rep_index": int, "score": int, "min_angle": float, "duration_ms": int, "errors": [str]}]}]}
```
- 401은 dio 인터셉터가 갱신을 시도한 뒤에도 실패한 경우로, 다시 시도 대상(로그인 후 다시 보냄)

## 연결 범위

### 받아 쓰는 것
| 이름 | 위치 | 계약 |
|---|---|---|
| `apiClientProvider`, `ApiErrorKind`, `classifyError` | `app/lib/core/network/api_client.dart` | `final apiClientProvider = Provider<Dio>(...)`, `enum ApiErrorKind { network, server, badRequest, unauthorized, notFound, conflict, unknown }`, `ApiErrorKind classifyError(Object error)` |
| `WorkoutSummary`, `SetSummary` | `app/lib/features/workout/domain/workout_summary.dart` | TASK-17 계약 그대로 |
| `FakeHttpAdapter`, `FakeResponse` | `app/test/support/fake_http_adapter.dart` | TASK-34 계약 그대로 (테스트에서만) |

### 내보내는 것 (다음 Task가 기대는 것, 바꾸면 안 됨)
| 이름 | 위치 | 계약 | 쓰는 Task |
|---|---|---|---|
| `workoutToJson` | `app/lib/features/history/data/workout_remote_api.dart` | `Map<String, dynamic> workoutToJson(WorkoutSummary summary)` | (내부) |
| `UploadOutcome` | 같은 파일 | `sealed class UploadOutcome`, `final class UploadSynced extends UploadOutcome { const UploadSynced(); }`, `final class UploadRejected extends UploadOutcome { const UploadRejected(this.reason); final String reason; }`, `final class UploadRetryLater extends UploadOutcome { const UploadRetryLater(this.kind); final ApiErrorKind kind; }` | TASK-39 |
| `WorkoutRemoteApi` | 같은 파일 | `abstract class WorkoutRemoteApi { Future<UploadOutcome> upload(WorkoutSummary summary); }`, `class DioWorkoutRemoteApi implements WorkoutRemoteApi { DioWorkoutRemoteApi(Dio dio); }` | TASK-39 |
| `workoutRemoteApiProvider` | 같은 파일 | `final workoutRemoteApiProvider = Provider<WorkoutRemoteApi>(...)` | TASK-39 |

## 범위
- 위 변환과 업로드

## 범위 밖 (건드리지 않음)
- 로컬 상태 변경, 재시도 일정(TASK-39), 기록 조회 API(GET, 이번 범위에서 쓰지 않음)

## 먼저 작성할 테스트 (Red)
| 테스트 이름 | 입력 / 동작 | 기대 결과 |
|---|---|---|
| 본문 형식 | 2세트 요약(partialReps 0, 2) `workoutToJson` | 위 형식, sets[1].partial_reps 2, errors는 코드 문자열, 시각은 UTC ISO8601 |
| 201 | 가짜 서버 201 | `UploadSynced` |
| 409는 성공 (F-11) | 409 | `UploadSynced` |
| 400은 실패 (F-11) | 400 `{"detail": "bad"}` | `UploadRejected('bad')` |
| 5xx 재시도 (F-11) | 503 | `UploadRetryLater(server)` |
| 네트워크 재시도 (F-11) | `failNetwork(true)` | `UploadRetryLater(network)` |

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
