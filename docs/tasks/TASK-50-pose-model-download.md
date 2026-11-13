# TASK-50: 포즈 모델 파일 다운로드 스크립트와 체크섬 검사

- 상태: 대기
- 선행 Task: TASK-20
- 실행 방식: 순차
- 실행 방식 근거: 공유 빌드 설정(`build.gradle.kts`)과 `.gitignore`를 고치고, TASK-21이 이 파일에 기댐. 보안(공급망) 관련
- Spec 출처: F-01 (3장), 8장 보안, 9장 인수 조건 F-01

## 왜 이렇게 나눴나
모델 파일을 저장소에 넣지 않기로 했으므로(Spec 2026-11-13) 받는 방법과 검사를 MediaPipe 연결(TASK-21) 전에 따로 만든다. Kotlin 코드와 섞지 않아 실패 원인을 나누기 쉽다.

## 기능 범위 (Spec 발췌)
- 모델 파일은 저장소에 넣지 않고 다운로드 스크립트와 체크섬 검사로 받는다
- 포즈 모델 파일은 저장소에 넣지 않는다. 다운로드 스크립트로 받고 체크섬이 맞지 않으면 빌드를 멈춘다.
- 인수 조건(F-01): 저장소를 새로 받아 다운로드 스크립트를 실행하면 모델 파일이 받아지고, 체크섬이 다르면 오류로 멈춘다.
- 이 Task에서 정하는 것:
  - 받을 파일: `pose_landmarker_full.task`, `pose_landmarker_lite.task`(Google MediaPipe 공식 배포, 버전을 고정한 주소. `latest` 주소는 쓰지 않음)
  - 저장 위치: `app/android/app/src/main/assets/`
  - 체크섬 파일: `scripts/pose_models.sha256`(`sha256sum` 형식, 파일 이름과 SHA-256)
  - 스크립트: `scripts/download_pose_models.sh [--source <URL 또는 로컬 폴더>] [--checksums <파일>]`. 기본값은 공식 주소와 `scripts/pose_models.sha256`
    - 이미 있고 체크섬이 맞는 파일은 다시 받지 않음
    - 받은 뒤 체크섬이 다르면 그 파일을 지우고 `체크섬 불일치: <파일>`을 출력, 종료 코드 1
  - Gradle: `verifyPoseModels` 작업을 `preBuild` 앞에 둔다. 파일이 없거나 체크섬이 다르면 "scripts/download_pose_models.sh를 실행하세요" 문구로 빌드 실패
  - `.gitignore`에 `app/android/app/src/main/assets/*.task` 추가

## 연결 범위

### 받아 쓰는 것
| 이름 | 위치 | 계약 |
|---|---|---|
| Android 빌드 설정 | `app/android/app/build.gradle.kts` | TASK-01, 20이 만든 설정(CameraX 의존성 포함). 기존 블록은 고치지 않고 작업만 추가 |

### 내보내는 것 (다음 Task가 기대는 것, 바꾸면 안 됨)
| 이름 | 위치 | 계약 | 쓰는 Task |
|---|---|---|---|
| 모델 파일 | `app/android/app/src/main/assets/pose_landmarker_full.task`, `pose_landmarker_lite.task` | 스크립트로 받은 파일, Git 제외 | TASK-21 |
| `download_pose_models.sh` | `scripts/download_pose_models.sh` | 위 인자와 종료 코드(성공 0, 체크섬 불일치나 받기 실패 1) | 사용자, verify-agent |
| `verifyPoseModels` | `app/android/app/build.gradle.kts` | `preBuild`가 이 작업에 의존 | TASK-21 |

## 범위
- 위 스크립트, 체크섬 파일, Gradle 작업, `.gitignore`, 스크립트 테스트

## 범위 밖 (건드리지 않음)
- Kotlin 코드, MediaPipe 의존성(TASK-21), Dart 파일

## 먼저 작성할 테스트 (Red)
| 테스트 이름 | 입력 / 동작 | 기대 결과 |
|---|---|---|
| 정상 받기 (F-01) | `scripts/test_download_pose_models.sh`: 임시 폴더의 가짜 모델 2개와 그 체크섬 파일로 `--source`, `--checksums` 지정 | 종료 코드 0, assets(테스트용 임시 경로)에 두 파일 |
| 체크섬 불일치 (F-01) | 체크섬 파일의 값 하나를 바꿔 실행 | 종료 코드 1, 그 파일이 남지 않음, `체크섬 불일치` 출력 |
| 이미 맞는 파일 | 같은 조건으로 두 번 실행 | 두 번째는 받지 않음(파일 수정 시각 그대로) |
| Git 제외 | `git check-ignore app/android/app/src/main/assets/pose_landmarker_full.task` | 제외됨 |
| 빌드 검사 | 모델 파일 없이 `flutter build apk --debug` | `verifyPoseModels` 실패와 안내 문구(Gradle 플러그인을 받을 수 없으면 "미확인"으로 QA 보고) |

## 바뀔 것으로 예상되는 파일
- `scripts/download_pose_models.sh`
- `scripts/pose_models.sha256`
- `scripts/test_download_pose_models.sh`
- `app/android/app/build.gradle.kts`
- `.gitignore`

## 완료 조건
- [ ] 위 테스트가 모두 통과(빌드 검사는 환경상 불가하면 "미확인" 표시)
- [ ] 기존 테스트가 깨지지 않음
- [ ] 모델 파일이 Git에 올라가지 않음
- [ ] 체크섬 값의 출처(받은 주소, 받은 날짜)를 `scripts/pose_models.sha256` 주석에 남김
- [ ] "내보내는 것"의 계약이 적힌 그대로임

## 중단 조건 (여기에 걸리면 멈추고 보고)
- 범위 밖 파일을 고쳐야 할 때
- 네트워크 제한으로 공식 파일을 받을 수 없어 체크섬 값을 정할 수 없을 때(추측한 값을 넣지 말고 보고)
- 공식 배포처가 버전 고정 주소를 주지 않을 때

## 추가 발췌 (오케스트레이터가 보충)
