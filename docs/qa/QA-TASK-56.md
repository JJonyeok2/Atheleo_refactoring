# QA-TASK-56

- 검토일: 2026-11-13
- 판정: PASS

## 검토 파일
| 파일 | 헤더/푸터 주석 | 비고 |
|---|---|---|
| `app/lib/pose/rep/rep_counter.dart` | 갱신함 | 헤더 [Task]에 TASK-56(Impl 반영). 푸터 [유지보수]에서 해소된 두 줄(빠른 반복 무피드백, 최대 시간 규칙 없음) 삭제, 버퍼 상한 문구를 "maxRepMs 안의 프레임만" 으로 정리, 규약에 없는 [변경] 줄은 이력이 이 문서에 남으므로 삭제 |
| `app/test/pose/rep/rep_counter_test.dart` | 대상 아님(테스트 파일) | `git diff` 확인: 기존 테스트 변경은 Task가 허용한 두 곳(`expect(events, isEmpty)`, `expect(shortEvents, isEmpty)` → `TooFastRepEvent` 1개)뿐. dart format으로 인한 다른 줄 변경 없음. 나머지는 추가 테스트 |

## 보안
| 항목 | 결과 | 위치 | 설명 |
|---|---|---|---|
| 입력 검증 | 통과 | `update` | timestampMs 역행, NaN 검증은 Task 범위 밖(TASK-15 몫). 역행 시 버퍼 상한이 깨질 수 있음을 푸터에 적음 |
| XSS 등 출력 처리 | 해당 없음 |  | UI 출력 없음 |
| 인증 / 인가 | 해당 없음 |  |  |
| 시크릿 하드코딩 | 통과 |  | 없음 |
| 로그의 민감 정보 | 통과 |  | 로그 없음 |
| 새 의존성 | 통과 |  | 없음 |

## 유지보수성
| 항목 | 결과 | 위치 | 설명 |
|---|---|---|---|
| 중복 코드 | 통과 |  | `_cancel`로 취소 처리 분리 |
| 함수 길이 | 통과 |  | `update` 약 30줄 |
| 이름 | 통과 |  | `TooFastRepEvent`, `RepCancelledEvent`, `maxRepMs` 계약 이름 그대로 |
| 죽은 코드 | 통과 |  | `_finish`가 `null`을 더 이상 돌려주지 않아 반환형을 non-null로 좁힘(공개 시그니처 영향 없음) |
| 테스트가 인수 조건을 검증하는가 | 통과 | 테스트 TASK-56 그룹 | 빠른 반복(푸쉬업, 스쿼트), 빠른 반복 뒤 repIndex 1, 최저점 3초 정지, DOWN/하강 10초 초과 취소, 10초 경계(10000 정상, 10100 초과 시 취소 + 같은 프레임 up) 모두 검증 |

### 지정 검토 지점
- 순서와 경계: 하강/DOWN 프레임에서 `timestampMs - _startMs > maxRepMs`를 먼저 보고 취소, 그다음 UP 복귀 판단. 정확히 10000ms UP 복귀는 정상 반복, 초과 프레임은 취소 후 같은 프레임에 unknown 규칙(angle ≥ upDeg면 up). Task 규칙과 일치하며 테스트로 확인됨
- 취소 뒤 낮은 각도 유지: phase unknown에서는 upDeg 이상만 보므로 90, 140 프레임에서 반복이 시작되지 않음. 테스트가 매 프레임 phase unknown을 확인
- 빠른 반복과 부분 반복 우선순위: `_finish`에서 DOWN 미도달이면 먼저 `PartialRepEvent`로 끝내고, 최소 시간 판단은 DOWN 도달 반복에만 적용. 100ms 부분 반복 기존 테스트(`최저 프레임이 구간 맨 끝이거나 구간이 짧을 때`)가 계속 `PartialRepEvent`로 통과
- 소비 계약: TASK-15 파일 연결 범위 표의 `RepThresholds`(maxRepMs 기본 10000), `TooFastRepEvent({startMs, endMs}) + durationMs`, `RepCancelledEvent({startMs, cancelledMs})`와 구현이 일치. TASK-49의 "취소 뒤 phase unknown" 기대와도 일치
- 기존 소비 코드: `app/lib`에 `RepCounterEvent`를 switch로 다루는 다른 코드 없음(sealed 하위 타입 추가로 깨지는 곳 없음)

### 실행 결과
- `flutter test test/pose/rep/rep_counter_test.dart`: 20건 통과
- `flutter test`: 143건 통과
- `flutter analyze`: 이슈 없음
- `dart format --set-exit-if-changed`(두 파일): 변경 없음

## FIX 항목 (Impl로 회귀)
- 없음

## PEER_REVIEW 사유
- 없음
