# TASK-07: 각도 이동 평균

- 상태: 대기
- 선행 Task: TASK-01
- 실행 방식: 병렬 (그룹: G1)
- 실행 방식 근거: 숫자만 다루는 독립 유틸, TASK-06과 파일이 겹치지 않음
- Spec 출처: 7장 횟수 판정 기준(이동 평균)

## 왜 이렇게 나눴나
프레임마다 흔들리는 각도를 부드럽게 만드는 작은 조각이다. 횟수 상태 머신과 분리해 두면 창 크기를 바꿔도 횟수 로직 테스트가 흔들리지 않는다.

## 기능 범위 (Spec 발췌)
- 각도는 최근 5프레임 이동 평균으로 계산한다.

## 연결 범위

### 받아 쓰는 것
없음

### 내보내는 것 (다음 Task가 기대는 것, 바꾸면 안 됨)
| 이름 | 위치 | 계약 | 쓰는 Task |
|---|---|---|---|
| `MovingAverage` | `app/lib/pose/angle/moving_average.dart` | `class MovingAverage { MovingAverage({int window = 5}); double add(double value); void reset(); bool get isFull; }` (add는 넣은 뒤의 평균을 돌려줌. 채워지기 전에는 들어온 값들의 평균. window < 1이면 `ArgumentError`) | TASK-15 |

## 범위
- 원형 버퍼 또는 큐로 구현, 합계를 유지해 O(1)

## 범위 밖 (건드리지 않음)
- 다른 모든 파일

## 먼저 작성할 테스트 (Red)
| 테스트 이름 | 입력 / 동작 | 기대 결과 |
|---|---|---|
| 채워지기 전 평균 | add(10), add(20) | 두 번째 반환값 15, isFull false |
| 5개 창 | 1,2,3,4,5,6 차례로 add | 마지막 반환값 4 (2~6 평균), isFull true |
| reset | 값 넣고 reset 후 add(7) | 7 |
| 잘못된 창 | `MovingAverage(window: 0)` | `ArgumentError` |

## 바뀔 것으로 예상되는 파일
- `app/lib/pose/angle/moving_average.dart`
- `app/test/pose/angle/moving_average_test.dart`

## 완료 조건
- [ ] 위 테스트가 모두 통과
- [ ] 기존 테스트가 깨지지 않음
- [ ] "내보내는 것"의 계약이 적힌 그대로임

## 중단 조건 (여기에 걸리면 멈추고 보고)
- 범위 밖 파일을 고쳐야 할 때

## 추가 발췌 (오케스트레이터가 보충)
