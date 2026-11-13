# QA-TASK-18

- 검토일: 2026-11-13
- 판정: PASS

## 검토 파일
| 파일 | 헤더/푸터 주석 | 비고 |
|---|---|---|
| `app/lib/features/workout/domain/voice_cues.dart` | 추가함 | 프로젝트 관례대로 `//` 형식. dart format 변경 없음, analyze 0건 |
| `app/test/features/workout/domain/voice_cues_test.dart` | 해당 없음(테스트) | 12건 통과 재확인 |

## 계약 대조 (Task 표와 글자 단위 비교)
| 대상 | Task 문구 / 우선순위 | 구현 | 결과 |
|---|---|---|---|
| `RepCounted` | `'${repsInSet}회'` / normal | `'$repsInSet회'` / 기본 normal | 일치 |
| `RepCounted`에 오류가 있을 때 | 첫 번째 오류 `voiceMessage` / high, 횟수 다음 | `rep.errors.first.voiceMessage` / high, 리스트 두 번째 | 일치 |
| `SetCompleted` | `'세트 완료, ${restSec}초 쉬세요'` / high | 같음 | 일치 |
| `RestEndingSoon` | `'${remainingSec}초 뒤 다음 세트를 시작해요'` / high | 같음 | 일치 |
| `NextSetStarted` | `'다음 세트를 시작하세요'` / high | 같음 | 일치 |
| `PartialRepNoticed` | `'더 내려가세요'` / normal | 같음 | 일치 |
| `WorkoutFinished` | `'운동을 마쳤어요. 수고하셨어요.'` / high | 같음 | 일치 |
| `VoiceCues.noPerson` | `'카메라 앞에 서 주세요'` / high | 같음 | 일치 |
| `VoiceCues.slowDown` | `VoiceCue('조금 더 천천히')` / normal | 같음 | 일치 |
| `VoiceCues.askResume` | `'이어서 할까요?'` / high | 같음 | 일치 |
| `VoiceCue` | `const VoiceCue(this.text, {this.priority = VoicePriority.normal})`, `==` 구현 | `const new(...)`(Dart 3.13 문법, 호출은 `VoiceCue(...)`로 동일, `pose_error.dart`도 같은 방식), `==`/`hashCode` 구현 | 일치 |
| `cuesForEvent` | `List<VoiceCue> cuesForEvent(WorkoutEvent event)` | 같음, sealed switch로 모든 이벤트를 빠짐없이 처리 | 일치 |

- 소비 Task 대조: TASK-27(`cuesForEvent`, `VoiceCues.slowDown`의 `.text`, `.priority`), TASK-28(`noPerson`, `askResume`)이 적어 둔 계약과 일치. TASK-51은 자체 문구를 쓰고 이 파일을 쓰지 않음. TASK-52 Task 파일에는 이 파일을 참조하는 곳이 없음.
- 마지막 세트 규칙(TASK-16 QA): 매핑만 하는 순수 함수라 `SetCompleted`가 오지 않으면 "쉬세요"를 말할 일이 없음. 테스트로 확인함.

## VoiceGuide(TASK-11)와 결합했을 때의 동작 (판단)
- 대기 상태에서 반복: '4회'를 재생하고 교정(high)은 대기 칸으로 들어감. 의도대로 들림.
- 앞 문장이 아직 재생 중일 때 반복+오류: '4회'(normal)가 대기 칸에 들어갔다가 교정(high)으로 바뀌어 횟수 안내가 빠짐. 다음 반복의 '5회'(normal)도 대기 칸에 high가 있으면 버려짐. 교정을 횟수보다 앞세우는 Task 우선순위 표의 결과라 이 Task의 결함은 아님. 반복이 빠르면(0.8~2초) 횟수 안내가 자주 빠질 수 있으니 TASK-27 E2E와 사용자 최종 검증에서 체감을 확인할 것.
- 매 반복 같은 오류: 교정 문장은 같은 문장 5초 쿨다운에 걸려 대략 한 번 걸러 한 번 나오고, 'N회'는 매번 달라 쿨다운에 걸리지 않음. 같은 문장 반복을 막는 Spec 의도(Task 기능 범위의 "쿨다운은 VoiceGuide가 처리")와 맞음.
- 세트 마지막 반복의 교정(high)은 이어서 오는 `SetCompleted`/`WorkoutFinished`(high)가 대기 칸에서 대체함. 세트 전환 안내가 우선이므로 타당함.
- 휴식 3초 전 문구('3초 뒤 다음 세트를 시작해요')는 읽는 데 약 2초가 걸리고 3초 뒤 `NextSetStarted`(high)가 옴. 겹치더라도 대기 칸이 처리함.

## 보안
| 항목 | 결과 | 위치 | 설명 |
|---|---|---|---|
| 입력 검증 | 통과 | - | 사용자 입력 없음, 정수 보간뿐 |
| XSS 등 출력 처리 | 통과 | - | 웹 출력 없음(TTS/글자 안내용 고정 문구) |
| 인증 / 인가 | 해당 없음 | - | |
| 시크릿 하드코딩 | 통과 | - | 없음 |
| 로그의 민감 정보 | 통과 | - | 로그 출력 없음 |
| 새 의존성 | 통과 | - | 없음(`flutter/foundation`의 `@immutable`만 사용) |

## 유지보수성
| 항목 | 결과 | 위치 | 설명 |
|---|---|---|---|
| 중복 코드 | 통과 | - | 문구가 한곳에 모여 있음 |
| 함수 길이 | 통과 | `cuesForEvent` | 약 25줄 |
| 이름 | 통과 | - | 계약 이름 그대로 |
| 죽은 코드 | 통과 | - | 없음 |
| 테스트가 인수 조건을 검증하는가 | 통과 | 테스트 파일 | Red 표 8행 모두 있고, 오류 여러 개일 때 첫 번째만, 마지막 세트 "쉬세요" 없음, `VoiceCue` 값 비교, `askResume`까지 확인 |

## 참고 (FIX 아님)
- `rep.errors.first`는 판정기(TASK-09/15)가 넣는 순서에 기댐. 오류 간 우선순위가 필요해지면 판정 쪽에서 순서를 정해야 함.
- 위 "앞 문장 재생 중 횟수 안내 누락"이 사용자 검증에서 문제가 되면 Spec/Task 단계에서 우선순위 정책을 다시 정할 것(이 파일만 고칠 문제가 아님).

## FIX 항목 (Impl로 회귀)
- 없음

## PEER_REVIEW 사유
- 없음
