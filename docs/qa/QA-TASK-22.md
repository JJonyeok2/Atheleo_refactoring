# QA-TASK-22

- 검토일: 2026-11-13
- 판정: PASS

## 검토 파일
| 파일 | 헤더/푸터 주석 | 비고 |
|---|---|---|
| `app/lib/features/workout/widgets/skeleton_overlay.dart` | 헤더는 Impl이 이미 작성(규칙 충족), 푸터 추가함 | dart format 변경 없음, analyze 0건 |
| `app/test/features/workout/widgets/skeleton_overlay_test.dart` | 테스트 파일이라 달지 않음 | 14건 통과 |

## 계약 / 설계 대조
| 항목 | 결과 | 근거 |
|---|---|---|
| `kPoseConnections` 35개 = 공식 POSE_CONNECTIONS | 일치 | `google-ai-edge/mediapipe` 저장소 `mediapipe/python/solutions/pose_connections.py` 원문을 받아 집합 비교. 35개, 중복 없음, 집합 동일. 얼굴(0-1-2-3-7, 0-4-5-6-8, 9-10), 팔/손(11~22), 몸통(11-23, 12-24, 23-24), 다리/발(23~32) |
| `projectLandmarks` 반전, 회전, 비율 맞춤 없음 | 계약과 맞음 | Task "이 Task에서 정하는 것"과 2026-11-13 설계 검토: 회전, 전면 반전은 Kotlin 책임, 비율 상자는 TASK-25 `CameraPreviewView`(AspectRatio 상자 안에 overlay를 겹치고 회전, 반전하지 않음). "반전하지 않음" 테스트(16번 x 0.2 → dx 80)로 확인 |
| `projectLandmarks` 시그니처 | 계약 그대로 | `(PoseFrame, Size, {double minVisibility = 0.5}) → List<Offset?>`, 길이 33(PoseFrame 생성자가 33개 강제) |
| `SkeletonOverlay` 생성자 인자 순서 | 영향 없음 | `required this.frame, super.key, this.color` 순서는 계약 표기와 다르지만 모두 named 인자라 호출부(TASK-29, 46의 `SkeletonOverlay(frame: ...)`)에 영향 없음. 이름, 타입, 기본값(Colors.white), const 모두 동일 |
| frame null | 계약대로 | painter가 바로 return, 위젯은 부모 크기를 채움(테스트로 확인) |
| 부모를 꽉 채움 | 계약대로 | `CustomPaint(size: Size.infinite)`가 부모 제약 최대값으로 맞춰짐. TASK-25의 유한 비율 상자 전제에서 문제없음 |
| 소비 Task 29, 46 | 일치 | 두 Task 파일의 `SkeletonOverlay` 계약 문구가 TASK-22와 글자 그대로 같음. TASK-25는 `overlay: Widget?`만 받으므로 직접 의존 없음 |

## 동작 세부
| 항목 | 결과 | 설명 |
|---|---|---|
| 비유한 좌표 | 통과 | x, y가 NaN/무한이면 null. visibility NaN은 `>=` 비교가 false라 null. 테스트 있음 |
| visibility 경계 | 통과 | `>= 0.5`는 보임, 0.49는 숨김(Task "0.5 미만은 그리지 않음"과 일치). 테스트 있음 |
| 선 생략 | 통과 | 양 끝 중 하나라도 null이면 선을 그리지 않음 |
| shouldRepaint | 통과 | frame 참조 또는 color가 바뀔 때만 다시 그림. 프레임마다 새 PoseFrame이 오므로 매 프레임 갱신, 같은 객체면 생략 |
| 매 프레임 리스트 생성 | 문제 없음 | 프레임당 Offset 33개 리스트 1개, Paint 2개. 30fps 기준 부담 무시 가능 |

## 보안
| 항목 | 결과 | 위치 | 설명 |
|---|---|---|---|
| 입력 검증 | 통과 | 31행 | 비유한 값, 낮은 가시성 걸러냄. 길이는 PoseFrame이 보장 |
| XSS 등 출력 처리 | 해당 없음 |  | 캔버스 그리기만 함 |
| 인증 / 인가 | 해당 없음 |  |  |
| 시크릿 하드코딩 | 통과 |  | 없음 |
| 로그의 민감 정보 | 통과 |  | 로그 없음 |
| 새 의존성 | 통과 |  | flutter/material, 내부 pose_landmark만 사용 |

## 유지보수성
| 항목 | 결과 | 위치 | 설명 |
|---|---|---|---|
| 중복 코드 | 통과 |  | 없음 |
| 함수 길이 | 통과 | paint 24줄 | 50줄 미만 |
| 이름 | 통과 |  | 명확 |
| 죽은 코드 | 통과 |  | 없음 |
| 테스트가 인수 조건을 검증하는가 | 통과 |  | Task 표의 6개 테스트 모두 있고 경계, 비유한, minVisibility, 비율, 크기 0, 연결 인덱스 범위까지 추가. 연결 목록 내용 자체는 개수와 범위만 테스트하므로 공식 목록 대조는 이 QA에서 수행 |

## 참고 (FIX 아님)
- 0~1 범위를 벗어난 좌표(MediaPipe는 프레임 밖 점을 약간 벗어난 값으로 줄 수 있음)는 클리핑하지 않아 비율 상자 밖 검은 여백에 그려질 수 있음. 필요하면 TASK-25 쪽에서 ClipRect 고려. 푸터에 기록함.
- 부모 제약이 무한(예: 스크롤 안에 직접 배치)이면 `Size.infinite` 때문에 크기 오류. 현재 소비처(TASK-29, 46)는 모두 TASK-25 비율 상자 안이라 해당 없음. 푸터에 기록함.

## FIX 항목 (Impl로 회귀)
- 없음

## PEER_REVIEW 사유
- 없음
