---
description: 특정 Task의 QA만 다시 실행
argument-hint: [Task 번호]
---

> 단계: QA (TASK-$ARGUMENTS)

`qa-agent`에게 TASK-$ARGUMENTS에서 바뀐 파일의 헤더/푸터 주석, 보안, 유지보수성 검토를 맡겨라.
결과 파일 `docs/qa/QA-TASK-$ARGUMENTS.md`의 판정과 주요 지적 사항을 사용자에게 요약한다.
