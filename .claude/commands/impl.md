---
description: Task 하나를 TDD로 구현
argument-hint: [Task 번호, 예: 03]
---

> 단계: Impl (TASK-$ARGUMENTS)

1. `docs/tasks/TASK-$ARGUMENTS-*.md`를 찾는다.
2. Task 파일에 "기능 범위"와 "연결 범위"가 채워져 있는지 확인한다. 비어 있으면 `task-agent`에게 채우게 한다.
   그다음 **Task 파일 경로와 검증 명령만** `impl-agent`에게 넘긴다. Spec 경로는 넘기지 않는다.
   Impl이 정보 부족으로 중단하면 `/run` 3장 절차대로 필요한 줄만 "추가 발췌"에 붙이고 다시 실행한다.
3. Red, Green, Refactor 결과를 받으면 바로 `qa-agent`에게 같은 Task로 QA를 맡긴다.
4. QA 판정에 따라:
   - `PASS` → 사용자에게 알리고 `/verify` 진행을 제안
   - `FIX` → 고칠 항목을 `impl-agent`에게 다시 넘김 (최대 2회, 그 이상은 사용자에게 보고)
   - `PEER_REVIEW` → `/peer-review $ARGUMENTS both` 절차를 바로 실행 (Computer Use로 Codex, Antigravity 교차 검증)
