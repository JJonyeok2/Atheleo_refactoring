---
description: 시크릿 검사 후 JJonyeok 이름으로 커밋 (푸시는 요청 시에만)
argument-hint: [커밋 메시지 요지]
---

> 단계: Git 게이트

1. 사용자 최종 검증이 "통과"였는지 확인한다. 아니면 멈춘다.
2. `git status`로 변경 파일을 보여 주고, `.env*`(단 `.env.example` 제외)가 있으면 스테이징에서 뺀다.
3. 스테이징 후 `bash scripts/check-secrets.sh --staged`를 실행한다. 실패하면 잡힌 위치를 알려 주고 커밋하지 않는다.
4. `git config user.name`이 `JJonyeok`인지 확인한다.
5. 커밋 메시지를 작성한다.
   - 요지: $ARGUMENTS
   - 형식: `<type>: <한국어 요약>` (feat, fix, refactor, test, docs, chore)
   - 모델명, `Claude`, `Co-Authored-By`, `Claude-Session`, "Generated with" 문구를 넣지 않는다.
6. 메시지를 사용자에게 보여 주고 확인을 받은 뒤 커밋한다.
7. 푸시는 사용자가 따로 요청할 때만 한다.
