# QA-TASK-04

- 검토일: 2026-11-09
- 판정: PASS

## 검토 파일
| 파일 | 헤더/푸터 주석 | 비고 |
|---|---|---|
| app/lib/pose/landmarks/exercise_type.dart | 추가함 | enum, code/label 값, fromCode(ArgumentError) 계약 일치 |
| app/lib/pose/landmarks/pose_landmark.dart | 추가함 | PoseLandmark const 생성자, PoseFrame(33개 아니면 ArgumentError, aspectRatio 기본 1.0, operator []), BodySide, LandmarkIndex 상수 18개 값 모두 일치 |
| app/lib/pose/landmarks/landmark_clip.dart | 추가함 | const 생성자, fromJson, toJson, static parse, encode 일치. JSON 키 id/exercise/label/fps/aspect/frames/t/lm 일치 |
| app/test/pose/landmarks/landmark_clip_test.dart | 해당 없음(테스트) | 11건 |
| app/test/fixtures/clips/minimal_clip.json | 해당 없음(픽스처) | 2프레임, aspect 0.5625 |

뒤 Task 대조(docs/tasks grep): TASK-05, 06, 10, 13, 15, 19, 25, 32, 45가 적은 이름, 시그니처, 인덱스, JSON 키가 글자 그대로 일치. 불일치 없음.

## 보안
| 항목 | 결과 | 위치 | 설명 |
|---|---|---|---|
| 입력 검증 | 통과(메모) | landmark_clip.dart fromJson, _frameFromJson, _landmarkFromJson | JSON 아님, 최상위 비객체, 필드 누락/타입 오류, 모르는 운동, lm 개수, 점 원소 개수/타입이 모두 FormatException으로 정리됨(QA 탐침으로 확인). 값 범위는 미검사: `1e400`(Infinity) 좌표, fps 0 이하, aspect 0 이하가 통과하고, Infinity가 든 클립은 encode에서 JsonUnsupportedObjectError. JSON 표준에는 NaN 리터럴이 없어 NaN은 들어올 수 없음 |
| 거대 입력 | 통과(범위 밖) | parse | 크기 제한 없음. 입력은 개발자 메뉴의 로컬 파일과 테스트 픽스처뿐(로컬 전용, 서버 미전송)이라 현재 위험 낮음 |
| XSS 등 출력 처리 | 해당 없음 | - | UI 없음 |
| 인증 / 인가 | 해당 없음 | - | - |
| 시크릿 하드코딩 | 통과 | - | 없음 |
| 로그의 민감 정보 | 통과 | - | 로그 없음. FormatException 메시지에 값이 들어가나 랜드마크 좌표뿐 |
| 새 의존성 | 통과 | - | 없음(dart:convert만) |

## 유지보수성
| 항목 | 결과 | 위치 | 설명 |
|---|---|---|---|
| 중복 코드 | 경미 | landmark_clip.dart fromJson | 운동 코드를 known 목록으로 먼저 검사한 뒤 fromCode를 다시 호출(이중 탐색). ArgumentError를 FormatException으로 바꾸려는 의도라 수용. try/on ArgumentError로 줄일 수 있음 |
| 함수 길이 | 통과 | - | 모두 20줄 이하 |
| 이름 | 통과 | - | - |
| 죽은 코드 | 통과 | - | 없음 |
| ignore 주석 | 통과 | landmark_clip.dart parse | `prefer_constructors_over_static_methods` 무시는 계약(static parse) 때문이며 이유 주석 있음 |
| (3) fps, t int만 허용 | 통과(메모) | _field<int> | 클립 JSON을 쓰는 쪽은 TASK-45의 encode(Dart jsonEncode는 int를 `30`으로 씀)와 TASK-06 합성 클립뿐이라 자체 왕복은 안전. TASK-19 채널 이벤트는 LandmarkClip 파서를 거치지 않고 별도 파싱(StandardMessageCodec이 Kotlin Int/Long을 Dart int로 넘김)이라 충돌 없음. 사용자가 Python 등으로 만든 JSON에서 `30.0`이 오면 거부되지만, 계약이 `fps: int`, `t: int(ms)`이므로 명시적 거부가 맞다고 판단 |
| (4) aspect 통일 | 통과(메모) | toJson | 계약상 aspect는 클립 최상위 하나이고 TASK-19는 "좌표는 세로 화면 기준 정규화"라 한 클립 안에서 바뀌는 상황은 계약상 상정되지 않음. 직접 PoseFrame을 다른 aspect로 섞어 만들면 왕복 시 첫 값으로 통일되는 손실이 있음(푸터 기록). TASK-45 ClipRecorder가 회전 중 녹화를 허용하게 되면 그때 재검토 |
| 테스트가 인수 조건을 검증하는가 | 통과 | landmark_clip_test.dart | Red 표 7건 모두 존재 + 형식 오류, 인덱스 값, 33개 생성 추가. flutter test 35건 통과, analyze 0건(QA 재실행, 주석 추가 후 재확인) |

## FIX 항목 (Impl로 회귀)
- 없음

## 후속 권고(이번 판정과 무관, 해당 Task에서 고려)
- TASK-45: 녹화 결과에 Infinity/NaN 좌표가 섞이면 encode가 JsonUnsupportedObjectError로 실패함. MediaPipe 출력은 유한 값이 정상이지만, export에서 예외를 잡아 사용자에게 알리는 처리 권장.
- 좌표 유한성, fps > 0, aspect > 0 검증을 fromJson에 넣을지는 Spec 판단 사항(현재 계약에 없음).

## PEER_REVIEW 사유
- 해당 없음
