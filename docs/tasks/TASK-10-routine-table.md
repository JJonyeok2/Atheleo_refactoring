# TASK-10: 체형별 루틴 데이터

- 상태: 대기
- 선행 Task: TASK-04
- 실행 방식: 병렬 (그룹: G2)
- 실행 방식 근거: `app/lib/features/routine/`만 새로 만들고 TASK-09, TASK-11과 파일, 타입이 겹치지 않음
- Spec 출처: F-09 (3장, 9장 인수 조건), 7장 Profile.body_shape

## 왜 이렇게 나눴나
기존 `exerciseRoutines.js` 표를 Dart 데이터로 옮기는 조각이다. 프로필(F-13)이 체형을 바꾸면 다음 운동 목표가 바뀌도록 "현재 체형" 상태와 루틴 조회 provider도 여기서 함께 만든다.

## 기능 범위 (Spec 발췌)
- 요구사항: 기존 `exerciseRoutines.js` 이식. 체형 정보 없으면 중급 루틴
- body_shape는 8분류 중 하나 또는 null
- 루틴 표(기존 앱 기준):

| 단계 | 체형 | 운동 | 목표 횟수 | 세트 | 휴식(초) | 최소 점수 |
|---|---|---|---|---|---|---|
| 고강도 | 역삼각형, 사각체형 | 스쿼트 | 20 | 3 | 30 | 70 |
| 고강도 | 역삼각형, 사각체형 | 푸쉬업 | 15 | 3 | 30 | 70 |
| 중급 | 모래시계형, 체형 없음(기본) | 스쿼트 | 15 | 3 | 45 | 60 |
| 중급 | 모래시계형, 체형 없음(기본) | 푸쉬업 | 12 | 3 | 45 | 60 |
| 초보 | 삼각형, 이상체형, 둥근체형, 튜브체형, 마름모형 | 스쿼트 | 10 | 2 | 60 | 50 |
| 초보 | 삼각형, 이상체형, 둥근체형, 튜브체형, 마름모형 | 푸쉬업 | 8 | 2 | 60 | 50 |

- 인수 조건(F-09): 프로필 체형이 역삼각형이면 스쿼트 목표가 20회 3세트, 체형이 없으면 15회 3세트로 시작한다.
- 최소 점수는 값만 보관한다(쓰는 곳은 이번 범위에 없음).

## 연결 범위

### 받아 쓰는 것
| 이름 | 위치 | 계약 |
|---|---|---|
| `ExerciseType` | `app/lib/pose/landmarks/exercise_type.dart` | `enum ExerciseType { pushUp, squat }`, 필드 `final String code`('push_up', 'squat'), `final String label`('푸쉬업', '스쿼트'), `static ExerciseType fromCode(String code)`(모르는 값은 `ArgumentError`) |

### 내보내는 것 (다음 Task가 기대는 것, 바꾸면 안 됨)
| 이름 | 위치 | 계약 | 쓰는 Task |
|---|---|---|---|
| `BodyShape` | `app/lib/features/routine/domain/body_shape.dart` | `enum BodyShape { invertedTriangle, rectangle, hourglass, triangle, ideal, round, tube, diamond }`, 필드 `final String code`('inverted_triangle', 'rectangle', 'hourglass', 'triangle', 'ideal', 'round', 'tube', 'diamond'), `final String label`('역삼각형', '사각체형', '모래시계형', '삼각형', '이상체형', '둥근체형', '튜브체형', '마름모형'), `static BodyShape? fromCode(String? code)`(null이나 모르는 값은 null) | TASK-39, 40 |
| `RoutineLevel` | `app/lib/features/routine/domain/routine_plan.dart` | `enum RoutineLevel { advanced, intermediate, beginner }`, 필드 `final String code`('advanced', 'intermediate', 'beginner'), `final String label`('고강도', '중급', '초보') | TASK-17, 30 |
| `RoutinePlan` | 같은 파일 | `class RoutinePlan { const RoutinePlan({required ExerciseType exercise, required RoutineLevel level, required int targetReps, required int sets, required int restSec, required int minScore}); }` (값 비교 가능하게 `==` 구현) | TASK-16, 17, 24, 27 |
| `levelForBodyShape` | `app/lib/features/routine/domain/routine_table.dart` | `RoutineLevel levelForBodyShape(BodyShape? shape)` | (내부용) |
| `routineFor` | 같은 파일 | `RoutinePlan routineFor(ExerciseType exercise, BodyShape? shape)` | (provider 내부) |
| `currentBodyShapeProvider` | `app/lib/features/routine/routine_providers.dart` | `final currentBodyShapeProvider = NotifierProvider<CurrentBodyShapeNotifier, BodyShape?>(CurrentBodyShapeNotifier.new);` (초기값 null, `void set(BodyShape? shape)`) | TASK-39 |
| `routinePlanProvider` | 같은 파일 | `final routinePlanProvider = Provider.family<RoutinePlan, ExerciseType>(...)` (currentBodyShapeProvider를 watch해 `routineFor` 호출) | TASK-27, 40 |

## 범위
- 위 enum, 표, provider
- 체형 코드 문자열은 서버 확정 전 임시값(Q-01). 코드값을 한곳(`BodyShape.code`)에서만 정의

## 범위 밖 (건드리지 않음)
- 프로필 조회와 저장(TASK-42), 판정 로직 파일

## 먼저 작성할 테스트 (Red)
| 테스트 이름 | 입력 / 동작 | 기대 결과 |
|---|---|---|
| 역삼각형 스쿼트 (F-09) | `routineFor(squat, BodyShape.invertedTriangle)` | targetReps 20, sets 3, restSec 30, minScore 70 |
| 체형 없음 스쿼트 (F-09) | `routineFor(squat, null)` | 15회 3세트 45초 60, level intermediate |
| 8개 체형 단계 | 모든 BodyShape에 `levelForBodyShape` | 위 표의 단계와 일치 |
| 초보 푸쉬업 | `routineFor(pushUp, BodyShape.tube)` | 8회 2세트 60초 50 |
| 코드 왕복 | `BodyShape.fromCode('diamond')`, `fromCode(null)`, `fromCode('x')` | diamond, null, null |
| provider 반영 | ProviderContainer에서 체형 set(invertedTriangle) 후 `routinePlanProvider(squat)` | targetReps 20 (set 전에는 15) |

## 바뀔 것으로 예상되는 파일
- `app/lib/features/routine/domain/body_shape.dart`
- `app/lib/features/routine/domain/routine_plan.dart`
- `app/lib/features/routine/domain/routine_table.dart`
- `app/lib/features/routine/routine_providers.dart`
- `app/test/features/routine/routine_table_test.dart`

## 완료 조건
- [ ] 위 테스트가 모두 통과
- [ ] 기존 테스트가 깨지지 않음
- [ ] F-09 인수 조건 충족
- [ ] "내보내는 것"의 계약이 적힌 그대로임

## 중단 조건 (여기에 걸리면 멈추고 보고)
- 범위 밖 파일을 고쳐야 할 때
- 위 표와 다른 루틴 값이 필요해 보일 때

## 추가 발췌 (오케스트레이터가 보충)
