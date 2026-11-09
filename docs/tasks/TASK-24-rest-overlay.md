# TASK-24: 휴식 오버레이 위젯

- 상태: 대기
- 선행 Task: TASK-03
- 실행 방식: 병렬 (그룹: G5)
- 실행 방식 근거: `app/lib/features/workout/widgets/rest_overlay.dart`만 새로 만듦. 값만 받는 위젯이라 다른 Task 결과에 의존하지 않음
- Spec 출처: F-08 (5장 휴식 화면, 9장 인수 조건)

## 왜 이렇게 나눴나
휴식 화면은 운동 화면 위 오버레이다. 상태를 모르는 표시 전용 위젯으로 만들어 운동 화면 Task를 가볍게 한다.

## 기능 범위 (Spec 발췌)
- 휴식: 운동 화면 위 오버레이. 카운트다운, 다음 세트 정보, 건너뛰기
- 인수 조건(F-08): 10회를 채우면 세트가 2로 바뀌고 휴식 카운트다운이 나온다.
- 이 Task에서 정하는 문구: 제목 '휴식', 큰 숫자 `'$remainingSec'`, 안내 `'다음 세트 $nextSet / $totalSets · 목표 $targetReps회'`, 버튼 '건너뛰기'

## 연결 범위

### 받아 쓰는 것
없음 (Flutter 기본 위젯만)

### 내보내는 것 (다음 Task가 기대는 것, 바꾸면 안 됨)
| 이름 | 위치 | 계약 | 쓰는 Task |
|---|---|---|---|
| `RestOverlay` | `app/lib/features/workout/widgets/rest_overlay.dart` | `class RestOverlay extends StatelessWidget { const RestOverlay({super.key, required int remainingSec, required int nextSet, required int totalSets, required int targetReps, required VoidCallback onSkip}); }` (반투명 검은 배경으로 부모를 덮음) | TASK-28 |

## 범위
- 위 위젯

## 범위 밖 (건드리지 않음)
- 타이머(TASK-16, 26)

## 먼저 작성할 테스트 (Red)
| 테스트 이름 | 입력 / 동작 | 기대 결과 |
|---|---|---|
| 카운트다운 표시 (F-08) | remainingSec 30, nextSet 2, totalSets 3, targetReps 10 | '30', '다음 세트 2 / 3 · 목표 10회' 표시 |
| 건너뛰기 | '건너뛰기' 탭 | onSkip 1회 호출 |
| 값 변경 | remainingSec 30 → 29로 다시 pump | '29' 표시 |

## 바뀔 것으로 예상되는 파일
- `app/lib/features/workout/widgets/rest_overlay.dart`
- `app/test/features/workout/widgets/rest_overlay_test.dart`

## 완료 조건
- [ ] 위 테스트가 모두 통과
- [ ] 기존 테스트가 깨지지 않음
- [ ] "내보내는 것"의 계약이 적힌 그대로임

## 중단 조건 (여기에 걸리면 멈추고 보고)
- 범위 밖 파일을 고쳐야 할 때

## 추가 발췌 (오케스트레이터가 보충)
