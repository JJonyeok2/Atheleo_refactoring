# Atheleo (리팩토링)

카메라 하나로 푸쉬업, 스쿼트 횟수와 자세를 실시간으로 판정하고 음성으로 교정 안내하는 Android 앱입니다.
기존 React Native iOS 앱([JJonyeok2/Atheleo](https://github.com/JJonyeok2/Atheleo))을 Flutter로 전체 리팩토링합니다.

- 자세 추정: MediaPipe Pose Landmarker (기기 내 추론)
- 앱: iOS -> Flutter (Android)
- 서버: Django REST (인증, 프로필, 운동 기록)

## 진행 방식

[Claude_Harness](https://github.com/JJonyeok2/Claude_Harness) 흐름(Spec → Task → Impl(TDD) → QA → 검증)을 따릅니다.

- 요구사항: `docs/spec/SPEC.md`
- 진행 상태: `docs/STATE.md`
- 작업 기록: `docs/status/AGENT_LOG.md`
