# TASK-42: 기록 상세 화면

- 상태: 대기
- 선행 Task: TASK-23, TASK-30, TASK-35, TASK-41
- 실행 방식: 순차
- 실행 방식 근거: 라우터(공유 파일) 수정
- Spec 출처: F-12 (5장 `/history/:id`, 9장 인수 조건)

## 왜 이렇게 나눴나
로컬 저장소에서 요약 하나를 읽어 세트별로 보여 준다. 그래프와 점수 배지는 이미 만든 위젯을 다시 쓴다.

## 기능 범위 (Spec 발췌)
- 기록 상세 `/history/:id`: 세트별 횟수, 반복별 점수, 오류 빈도
- 기록 화면은 로컬 DB만 읽는다(서버 조회는 2차, F-18). 조회는 현재 사용자 id 소유 기록만(비로그인이면 guest), 다른 계정의 기록을 조회하지 않는다
- 인수 조건(F-12): 기록 목록에서 세션을 누르면 세트별 횟수와 반복별 점수가 보인다.
- 이 Task에서 정하는 표시:
  - 맨 위: 운동 이름, 날짜, 총 횟수, 평균 `ScoreBadge`, 동기화 상태 칩
  - 세트마다: `'${setIndex}세트 · $doneReps / $targetReps회'`, partialReps가 1 이상이면 뒤에 `' · 덜 내려간 동작 $partialReps회'`, 반복별 점수 막대(`RepScoreChart`)
  - 오류 빈도: `topErrors` 전부, `'${label} ${count}회'`
  - `findSummary(clientId, userId: currentUserId)`가 null이면(없는 id, 다른 계정 기록) '기록을 찾을 수 없어요'

## 연결 범위

### 받아 쓰는 것
| 이름 | 위치 | 계약 |
|---|---|---|
| `workoutLocalRepositoryProvider` | `app/lib/features/history/data/workout_local_repository.dart` | `Future<WorkoutSummary?> findSummary(String clientId, {required int? userId}); Future<SyncStatus?> statusOf(String clientId);` (소유자가 다르면 null) |
| `currentUserIdProvider` | `app/lib/features/auth/application/auth_controller.dart` | `final currentUserIdProvider = Provider<int?>(...)` (비로그인 null = guest) |
| `WorkoutSummary`, `SetSummary` | `app/lib/features/workout/domain/workout_summary.dart` | TASK-17 계약 그대로 |
| `RepScoreChart` | `app/lib/features/workout/widgets/rep_score_chart.dart` | `class RepScoreChart extends StatelessWidget { const RepScoreChart({super.key, required List<int> scores}); }` |
| `ScoreBadge` | `app/lib/features/workout/widgets/score_badge.dart` | `class ScoreBadge extends StatelessWidget { const ScoreBadge({super.key, required int? score, double size = 64}); }` |
| `SyncStatusChip` | `app/lib/features/history/widgets/sync_status_chip.dart` | `class SyncStatusChip extends StatelessWidget { const SyncStatusChip({super.key, required SyncStatus status}); }` (미동기화, 동기화됨, 실패, 거절) |
| `AppRoutes` | `app/lib/app/routes.dart` | `historyDetail = '/history/:id'` |

### 내보내는 것 (다음 Task가 기대는 것, 바꾸면 안 됨)
| 이름 | 위치 | 계약 | 쓰는 Task |
|---|---|---|---|
| `HistoryDetailScreen` | `app/lib/features/history/presentation/history_detail_screen.dart` | `class HistoryDetailScreen extends ConsumerWidget { const HistoryDetailScreen({super.key, required String clientId}); }` | (라우터) |

## 범위
- 화면, 라우터 historyDetail 경로 builder 교체

## 범위 밖 (건드리지 않음)
- 서버 상세 조회 API GET `/api/workouts/:id/`(2차 범위 F-18, 만들지 않음), 실패 기록 재시도(목록 화면 TASK-41)

## 먼저 작성할 테스트 (Red)
| 테스트 이름 | 입력 / 동작 | 기대 결과 |
|---|---|---|
| 세트별 횟수 (F-12) | 2세트(10회, 8회와 부분 반복 2회, 목표 10) 요약 | '1세트 · 10 / 10회', '2세트 · 8 / 10회 · 덜 내려간 동작 2회' |
| 반복별 점수 (F-12) | 같은 요약 | `RepScoreChart` 2개, 첫 번째 scores 길이 10 |
| 오류 빈도 | puHipSag 3회 | '허리 처짐 3회' |
| 목록에서 들어오기 (F-12) | 목록 화면에서 항목 탭(TASK-41 화면과 함께) | 상세 화면 표시 |
| 없는 id와 다른 계정 기록 (F-12) | 없는 clientId / 메모리 DB에 userId 7 기록, currentUserId 8로 그 clientId | 둘 다 '기록을 찾을 수 없어요' |

## 바뀔 것으로 예상되는 파일
- `app/lib/features/history/presentation/history_detail_screen.dart`
- `app/lib/app/router.dart`
- `app/test/features/history/history_detail_screen_test.dart`

## 완료 조건
- [ ] 위 테스트가 모두 통과
- [ ] 기존 테스트가 깨지지 않음
- [ ] F-12 인수 조건 충족
- [ ] "내보내는 것"의 계약이 적힌 그대로임

## 중단 조건 (여기에 걸리면 멈추고 보고)
- 범위 밖 파일을 고쳐야 할 때

## 추가 발췌 (오케스트레이터가 보충)

- (오케스트레이터 보충, QA-TASK-03) `AppRoutes`의 경로 함수는 id를 인코딩하지 않는다. 세션 id는 앱이 만든 정수나 UUID라 그대로 써도 되지만, 사용자 입력이 경로에 들어가는 경우가 생기면 `Uri.encodeComponent`를 쓴다.

## 2026-11-13 설계 검토 반영(D2, D4)
- 로컬 DB만, 현재 사용자(비로그인은 guest) 소유만 조회(`findSummary(..., userId:)`), 다른 계정 기록 테스트 추가, 서버 GET은 2차(F-18). 선행 Task에 TASK-35 추가
