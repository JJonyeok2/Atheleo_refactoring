# QA-TASK-19

- 검토일: 2026-11-13
- 판정: PASS (NaN 버림 단위는 오케스트레이터가 정해야 함. 사람 단위로 정하면 아래 "결정 시 FIX 항목"으로 Impl 회귀)

## 검토 파일
| 파일 | 헤더/푸터 주석 | 비고 |
|---|---|---|
| app/lib/pose/detector/pose_detector.dart | 추가함 | 내보내는 계약 일치 |
| app/lib/pose/detector/platform_pose_detector.dart | 추가함 | 채널 구현, 직렬화, 파싱 |
| app/test/support/fake_pose_detector.dart | 추가함 | test/support는 앞선 사례(synthetic_clip.dart, TASK-06)에 맞춰 소스로 보고 주석을 단다 |
| app/test/pose/detector/platform_pose_detector_test.dart | 달지 않음(테스트 파일) | 47건 |

헤더/푸터 추가 후 `dart format`(변경 없음), `flutter analyze` 0건, 대상 테스트 47건 통과.

## 보안
| 항목 | 결과 | 위치 | 설명 |
|---|---|---|---|
| 입력 검증 | 통과 | platform_pose_detector.dart `_parseCamera`, `_parseEvent`, `_parsePerson`, `_parsePoint`, `_int` | Map/List 타입, 점 33개, 점 숫자 4개, 정수 필드, 크기 0 이하를 검사. 형식 오류를 비유한 값, 크기 검사보다 먼저 판정(사람 목록을 끝까지 파싱한 뒤 버림 판단)해 손상된 이벤트가 조용히 사라지지 않음 |
| XSS 등 출력 처리 | 해당 없음 | | |
| 인증 / 인가 | 해당 없음 | | |
| 시크릿 하드코딩 | 통과 | | 채널 이름만 상수 |
| 로그의 민감 정보 | 통과 | | 로그 없음. FormatException에 원본 값이 들어가지만 랜드마크 숫자뿐이고 영상 없음 |
| 새 의존성 | 없음 | | |

## 유지보수성
| 항목 | 결과 | 위치 | 설명 |
|---|---|---|---|
| 중복 코드 | 통과 | | `_sendModel`을 start(실행 중 모델 변경)와 setModel이 공유 |
| 함수 길이 | 통과 | | 가장 긴 `_parseEvent` 약 27줄 |
| 이름 | 통과 | | |
| 죽은 코드 | 없음 | | |
| 테스트가 인수 조건을 검증하는가 | 통과(보완 권고 1) | test 파일 | Task Red 7건 전부와 직렬화, 정리용 stop, stop 실패, broadcast 단일 listen, 비유한 값/크기 버림까지 검증. 여러 명 중 한 명만 NaN인 경우는 테스트 없음(아래 결정과 함께 추가) |
| 내보내는 계약 | 일치 | pose_detector.dart, platform_pose_detector.dart, fake_pose_detector.dart | 생성자, 메서드, provider, Fake의 calls 형식이 Task 표 그대로 |

## Impl이 정한 동작 평가
| 동작 | 평가 |
|---|---|
| `_serial` 큐 | 적절. `_tail`이 오류를 삼켜 앞 호출이 실패해도 다음 호출이 이어진다(테스트 154행). start 채널 오류면 `_camera`가 null로 남아 isRunning false, 다시 start 가능 |
| 실행 중 start | 적절. 채널 start를 다시 부르지 않고 저장값 반환, 모델이 다를 때만 setModel. 이 setModel이 실패하면 start가 오류를 내지만 카메라는 켜진 채(isRunning true)라 호출 쪽은 "오류 = 카메라 없음"으로 가정하면 안 됨(TASK-27이 start 오류 시 stop 정리를 하는지 확인 권고, 차단 아님) |
| 응답 형식 오류 뒤 정리용 stop | 적절. 원래 FormatException을 우선한다. `_stopQuietly`가 `Exception`만 잡아 `Error`(프로그래밍 오류)는 드러나며, PlatformException, MissingPluginException은 둘 다 Exception이라 무시됨 |
| stop 실패 시 isRunning false | 적절. 다음 start는 채널 start를 부르고, Kotlin 계약상 실행 중이면 같은 값을 돌려주므로 상태가 다시 맞춰진다 |
| 이벤트 형식 오류 → 스트림 오류, 계속 수신 | 적절. 소비자가 `cancelOnError`를 쓰지 않아야 함(TASK-27, 46 구독 시 주의) |
| aspect 판정 | 적절. 이벤트의 width/height 하나로 모든 PoseFrame aspectRatio를 정하고 0 이하는 버림. start 응답의 0 이하는 FormatException으로 처리(시작 시점에는 오류로 알리는 쪽이 맞음) |
| 정수 필드 강제 | 계약(int)과 일치. 다만 Kotlin이 `inferenceMs`를 `nanoTime / 1e6` 같은 Double로 보내면 **모든 이벤트가 오류**가 된다. TASK-21에 강하게 명시 필요(아래 권고) |
| results broadcast 단일 구독 | 적절. `late final` 하나의 `receiveBroadcastStream`이라 구독자가 여럿이어도 플랫폼 listen 한 번(테스트 317행) |
| PoseDetectionResult.poses 불변성 | 부분. PoseFrame.landmarks는 읽기 전용 복사본(TASK-04)이지만 poses 목록 자체는 수정 가능하고 broadcast로 여러 구독자가 같은 객체를 받는다. Platform 파서에서 `List.unmodifiable`로 감싸는 것을 권고(차단 아님, 지금 수정하는 소비자 없음) |

### NaN/Infinity 버림 단위 (오케스트레이터 결정 권고)
- 현재: 한 사람의 점 하나라도 비유한 값이면 이벤트 전체를 버린다(`platform_pose_detector.dart` `_parseEvent`의 `people.any(...)`).
- Task 문구: "좌표가 NaN/Infinity이거나 aspectRatio가 0 이하인 **프레임**은 버리고 다음 프레임을 기다린다". 이 코드베이스에서 `PoseFrame`은 사람 한 명 단위이고 aspectRatio도 PoseFrame 필드라 사람 단위로 읽을 수 있지만, "다음 프레임을 기다린다"는 카메라 프레임(이벤트) 단위로도 읽힌다. **문구상 모호**하다.
- 위험 비교
  - 이벤트 단위(현재): numPoses 2에서 구경꾼 점이 계속 NaN이면 주 인물 프레임까지 계속 사라져 사람 미검출이나 반복 누락이 생긴다. 실제 MediaPipe 출력에서 NaN이 나올 일은 드물어 확률은 낮다.
  - 사람 단위: 주 인물이 버려진 그 프레임만 구경꾼이 주 인물로 뽑힐 수 있다(TASK-13 선택 규칙이 프레임마다 다시 고르므로 기존에도 있는 위험). 모두 버려졌을 때 빈 poses를 내보내면 "사람 없음"으로 오인되므로 그때는 이벤트를 버려야 한다.
- QA 의견: 사람 단위가 영향 범위가 작아 낫다. 규칙 제안 "비유한 값이 있는 사람만 뺀다. 원래 한 명 이상이었는데 모두 빠지면 이벤트를 버린다(빈 목록으로 내보내지 않음). 크기 0 이하는 이벤트 전체를 버린다."

결정 시 FIX 항목(사람 단위로 정했을 때만)
- [ ] platform_pose_detector.dart `_parseEvent` — `people.any(...) return null`을 사람 단위 필터로 바꾸고, 원래 비어 있지 않은데 결과가 비면 null
- [ ] platform_pose_detector_test.dart — 2명 중 한 명만 NaN이면 나머지 한 명만 담긴 결과, 2명 모두 NaN이면 결과 없음 테스트 추가
- Task 파일 "추가 발췌"에 결정 문구를 먼저 보충할 것

## 다른 Task 보충 권고 (차단 아님)
1. TASK-21(필요하면 TASK-20): 채널 값 타입 고정 문구 추가. "`t`, `inferenceMs`, `width`, `height`, `textureId`는 Int 또는 Long(Double 금지, `inferenceMs`는 ms 정수로 반올림), 좌표 x, y, z, v는 Float 또는 Double". `PoseEventMapperTest`에 정수 필드가 `Double`이 아님을 확인하는 단언 추가.
2. TASK-25/27 경합(설계 검토 2번): 감지기 계약만으로는 막히지 않는다. 감지기는 호출 순서대로 처리할 뿐이라, 가이드 화면 dispose가 운동 화면 start보다 늦게 stop을 부르면(go_router 전환에서 이전 화면 dispose는 새 화면 init 뒤에 일어남) 운동 중 카메라가 꺼진다. 다만 TASK-25가 이미 "운동 화면으로 넘기지 않고 나갈 때만 stop"과 전환 시 'stop' 없음 테스트를 갖고 있어 규칙상으로는 막혀 있다. 보충 권고는 TASK-25에 "운동 화면으로 넘어간다는 표시는 이동 호출 **전에 동기적으로** 세우고, dispose는 그 표시만 보고 stop 여부를 정한다" 한 줄. 참조 카운트는 지금 규모에선 불필요하나, TASK-46(개발자 메뉴)처럼 같은 감지기를 쓰는 화면이 늘면 "stop은 마지막 소유자만" 규칙(acquire/release)을 검토.
3. TASK-25, 27, 46 테스트 작성 주의: FakePoseDetector는 broadcast라 구독 전에 emit한 값은 사라진다. 화면/컨트롤러가 start와 listen을 마친 뒤(pump 또는 start 완료 대기 후) emit해야 하며, 그렇지 않으면 테스트가 이유 없이 실패하거나 "아무 일도 없음"을 잘못 통과시킨다. 각 Task "먼저 작성할 테스트"에 한 줄 보충 권고. Fake에 `hasListener` 같은 확인용 getter를 더하는 것은 계약 변경이라 넣지 않았다.
4. TASK-27: start가 실행 중 모델 변경 실패로 오류를 내면 카메라는 켜져 있으므로, 컨트롤러 start 실패 처리에서 stop 정리를 할지 정해 둘 것. 이벤트 스트림 구독은 `cancelOnError: false`(기본) 유지.

## FIX 항목 (Impl로 회귀)
- 없음(NaN 단위 결정이 사람 단위로 나면 위 "결정 시 FIX 항목")

## PEER_REVIEW 사유
- 해당 없음
