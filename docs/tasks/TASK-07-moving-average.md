# TASK-07: 각도 이동 평균(시간 기준 창)

- 상태: 대기 (2026-11-09 시작 후 중단. 프레임 수 기준으로 만든 미완성 파일이 남아 있음, 아래 "범위" 참고)
- 선행 Task: TASK-01
- 실행 방식: 병렬 (그룹: G1)
- 실행 방식 근거: 숫자만 다루는 독립 유틸, TASK-06과 파일이 겹치지 않음
- Spec 출처: 7장 횟수 판정 기준(이동 평균), 시간 기준

## 왜 이렇게 나눴나
프레임마다 흔들리는 각도를 부드럽게 만드는 작은 조각이다. 횟수 상태 머신과 분리해 두면 창 크기를 바꿔도 횟수 로직 테스트가 흔들리지 않는다. 창을 시간으로 잡아 15fps와 30fps에서 같은 정도로 부드러워지게 한다.

## 기능 범위 (Spec 발췌)
- 상태 전이(UP, 하강, DOWN)는 이동 평균 각도로 판정한다. 이동 평균 창은 프레임 수가 아니라 시간 기준(최근 약 150ms, 최소 1프레임)으로 해 fps에 덜 민감하게 한다.
- 프레임 타임스탬프는 판정 분석(이동 평균 창 등)에서만 쓴다.
- 이 Task에서 정하는 규칙:
  - 창에 남는 값: 가장 최근 값은 항상 남고, 그 밖의 값은 `최근 타임스탬프 − 그 값의 타임스탬프 < windowMs`일 때만 남는다
  - 30fps(약 33ms 간격)에서 windowMs 150이면 5개, 15fps(약 67ms 간격)이면 3개가 평균된다
  - NaN, Infinity 값은 버리고 현재 평균을 돌려준다(비어 있으면 0)
  - 타임스탬프가 직전 값보다 작으면 `ArgumentError`(호출하는 쪽이 reset 후 다시 넣어야 함)

## 연결 범위

### 받아 쓰는 것
없음

### 내보내는 것 (다음 Task가 기대는 것, 바꾸면 안 됨)
| 이름 | 위치 | 계약 | 쓰는 Task |
|---|---|---|---|
| `MovingAverage` | `app/lib/pose/angle/moving_average.dart` | `class MovingAverage { MovingAverage({int windowMs = 150}); double add(double value, int timestampMs); void reset(); int get length; }` (add는 넣은 뒤 창 안 값들의 평균을 돌려줌. length는 지금 창에 든 값 개수. windowMs < 1이면 `ArgumentError`) | TASK-15 |

## 범위
- 위 클래스(큐에 (타임스탬프, 값)을 넣고 합계를 유지, 오래된 값은 앞에서 빼기)
- 기존 미완성 파일 `app/lib/pose/angle/moving_average.dart`와 `app/test/pose/angle/moving_average_test.dart`(Git에 올라가지 않은 상태, 프레임 수 창 `window`, `isFull` 기준)는 새 계약 기준으로 다시 작성한다. 옛 계약(`window`, `isFull`)은 남기지 않는다. NaN/Infinity를 버리는 처리 방식은 참고해도 된다

## 범위 밖 (건드리지 않음)
- 다른 모든 파일

## 먼저 작성할 테스트 (Red)
| 테스트 이름 | 입력 / 동작 | 기대 결과 |
|---|---|---|
| 30fps 창 | t = 0, 33, 67, 100, 133, 167에 값 1~6 add | 다섯 번째 반환값 3(1~5 평균), 여섯 번째 반환값 4(2~6 평균), length 5 |
| 15fps 창 | t = 0, 67, 133, 200에 값 10, 20, 30, 40 add | 마지막 반환값 30(20~40 평균), length 3 |
| 최소 1프레임 | t 0에 10, t 1000에 50 add | 50, length 1 |
| reset | 값 넣고 reset 후 t 0에 7 add | 7, length 1 |
| 유한하지 않은 값 | add(10, 0), add(NaN, 33) | 두 번째 반환값 10, length 1 |
| 잘못된 입력 | `MovingAverage(windowMs: 0)` / t 100 다음 t 50 add | 둘 다 `ArgumentError` |

## 바뀔 것으로 예상되는 파일
- `app/lib/pose/angle/moving_average.dart` (다시 작성)
- `app/test/pose/angle/moving_average_test.dart` (다시 작성)

## 완료 조건
- [ ] 위 테스트가 모두 통과
- [ ] 기존 테스트가 깨지지 않음
- [ ] 옛 계약(`window`, `isFull`)이 코드와 테스트에 남아 있지 않음
- [ ] "내보내는 것"의 계약이 적힌 그대로임

## 중단 조건 (여기에 걸리면 멈추고 보고)
- 범위 밖 파일을 고쳐야 할 때

## 추가 발췌 (오케스트레이터가 보충)

## 2026-11-13 설계 검토 반영
- 창을 5프레임에서 시간 기준 150ms(최소 1프레임)로 변경. `add`에 타임스탬프 인자 추가, `isFull` 대신 `length`
- 남아 있는 미완성 파일은 새 계약으로 다시 작성
