# TASK-41: 기록 목록 화면

- 상태: 대기
- 선행 Task: TASK-32, TASK-37, TASK-39
- 실행 방식: 순차
- 실행 방식 근거: 라우터(공유 파일) 수정
- Spec 출처: F-11, F-12 (4장 정상 흐름 기록 2번, 5장 `/history`, 9장 인수 조건 F-11, F-12)

## 왜 이렇게 나눴나
로컬 DB 스트림을 날짜별로 묶어 보여 준다. 동기화 상태가 바뀌면 스트림으로 바로 반영되므로 F-11의 "미동기화 → 동기화됨" 표시를 여기서 확인한다.

## 기능 범위 (Spec 발췌)
- 기록 목록 `/history`: 날짜별 세션, 미동기화 표시
- 인수 조건:
  - F-11: 기록 목록에 "미동기화"로 보이고, 네트워크 복구 후 자동으로 "동기화됨"이 된다. 서버가 400을 주면 "저장 실패"로 표시된다.
  - F-12: 기록 목록에서 세션을 누르면 (상세로 이동한다)
- 이 Task에서 정하는 표시:
  - 날짜 머리글 `yyyy년 M월 d일 (E)`(intl, ko), 같은 날짜끼리 묶음, 최신 날짜 먼저
  - 항목: 운동 이름(`ExerciseType.label`), 시작 시각 `HH:mm`, `'$totalReps회 · 평균 $avgScore점'`, 동기화 상태 칩(`SyncStatus.label`)
  - 비었으면 '아직 운동 기록이 없어요'
  - 화면이 열릴 때와 당겨서 새로고침할 때 `syncPending()` 호출
  - 항목 탭 → `AppRoutes.historyDetailPath(clientId)`

## 연결 범위

### 받아 쓰는 것
| 이름 | 위치 | 계약 |
|---|---|---|
| `workoutLocalRepositoryProvider`, `SessionListItem` | `app/lib/features/history/data/workout_local_repository.dart` | `Stream<List<SessionListItem>> watchSessions({DateTime? from, DateTime? to});`, `class SessionListItem { const SessionListItem({required String clientId, required ExerciseType exercise, required DateTime startedAt, required int totalReps, required int avgScore, required SyncStatus syncStatus}); }` |
| `SyncStatus` | `app/lib/features/history/domain/sync_status.dart` | `enum SyncStatus { pending, synced, rejected }`, `label`('미동기화', '동기화됨', '저장 실패') |
| `syncServiceProvider` | `app/lib/features/history/application/sync_service.dart` | `Future<void> syncPending()` |
| `AppRoutes` | `app/lib/app/routes.dart` | `history = '/history'`, `static String historyDetailPath(String id)` |

### 내보내는 것 (다음 Task가 기대는 것, 바꾸면 안 됨)
| 이름 | 위치 | 계약 | 쓰는 Task |
|---|---|---|---|
| `groupByDay` | `app/lib/features/history/domain/group_by_day.dart` | `List<MapEntry<DateTime, List<SessionListItem>>> groupByDay(List<SessionListItem> items)` (키는 현지 시각 자정, 최신 날짜 먼저) | (내부) |
| `SyncStatusChip` | `app/lib/features/history/widgets/sync_status_chip.dart` | `class SyncStatusChip extends StatelessWidget { const SyncStatusChip({super.key, required SyncStatus status}); }` | TASK-42 |
| `HistoryListScreen` | `app/lib/features/history/presentation/history_list_screen.dart` | `class HistoryListScreen extends ConsumerWidget { const HistoryListScreen({super.key}); }` | (라우터) |

## 범위
- 위 함수, 위젯, 화면, 라우터 history 경로 builder 교체

## 범위 밖 (건드리지 않음)
- 상세 화면(TASK-42), 서버에서 기록 받아오기(이번 범위 밖)

## 먼저 작성할 테스트 (Red)
| 테스트 이름 | 입력 / 동작 | 기대 결과 |
|---|---|---|
| 미동기화 표시 (F-11) | 스트림에 pending 1건 | '미동기화' 칩 |
| 동기화됨으로 바뀜 (F-11) | 같은 항목이 synced로 다시 발행 | '동기화됨' 칩 |
| 저장 실패 (F-11) | rejected | '저장 실패' 칩 |
| 날짜별 묶음 | 11월 8일 1건, 9일 2건 | 머리글 2개, 9일이 위 |
| 상세로 이동 (F-12) | 항목 탭 | 경로 `/history/<clientId>` |
| 빈 목록 | 빈 스트림 | '아직 운동 기록이 없어요' |
| 열릴 때 동기화 | 화면 표시 | 가짜 동기화 서비스 syncPending 1회 |

## 바뀔 것으로 예상되는 파일
- `app/lib/features/history/domain/group_by_day.dart`
- `app/lib/features/history/widgets/sync_status_chip.dart`
- `app/lib/features/history/presentation/history_list_screen.dart`
- `app/lib/app/router.dart`
- `app/test/features/history/history_list_screen_test.dart`

## 완료 조건
- [ ] 위 테스트가 모두 통과
- [ ] 기존 테스트가 깨지지 않음
- [ ] F-11 인수 조건(표시) 충족
- [ ] "내보내는 것"의 계약이 적힌 그대로임

## 중단 조건 (여기에 걸리면 멈추고 보고)
- 범위 밖 파일을 고쳐야 할 때

## 추가 발췌 (오케스트레이터가 보충)
