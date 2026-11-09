# 작업 하네스 규칙 (Spec → Task → Impl → QA → 검증)

이 저장소의 모든 작업은 아래 흐름을 따른다. 단계를 건너뛰지 않는다.

## 역할 구조

- **메인 세션 = 오케스트레이터**: 직접 코드를 쓰지 않고, 단계를 판단해 서브에이전트에게 일을 나누고 결과로 다음 단계를 정한다. 절차는 `/run`(`.claude/commands/run.md`)에 있다.
  - 서브에이전트는 다른 서브에이전트를 부를 수 없으므로, 오케스트레이터는 서브에이전트가 아니라 메인 세션이 맡는다.
- **작업 에이전트**: `spec-agent`, `task-agent`, `impl-agent`, `qa-agent`, `verify-agent`
  - 모두 시작, 완료, 중단 시점을 `docs/status/AGENT_LOG.md`에 한 줄씩 남긴다.
- **점검 에이전트**: `status-agent` (읽기 전용). `/status`로 부른다. 로그와 산출물을 읽어 진행 중, 완료, 중단, 멈춤 의심을 보고한다.
- **실행 방식**: Task 에이전트가 Task마다 병렬 / 순차를 정한다. 단순하지만 오래 걸리고 파일이 겹치지 않는 작업은 병렬(최대 3개 동시), 복잡하거나 공유 파일을 건드리거나 다른 Task의 기반이 되는 작업은 순차. 애매하면 순차.
- 진행 상태는 `docs/STATE.md`에 기록되며, 세션이 끊겨도 `/run`으로 이어서 진행한다.

```
Spec → Task → Impl(TDD) → QA ⇄ (필요 시 Codex, Antigravity 교차 피어 리뷰)
     → 자동 검증(Playwright, ESLint, Sentry) → 사용자 최종 검증(로컬 서버)
     → Git 게이트(시크릿 검사, JJonyeok 커밋)
```

## 0. 대화 규칙

- 답변은 한국어로 한다. 문장 전체를 영어로 쓰지 않는다. 코드, 명령어, 파일 경로, 라이브러리 이름 같은 고유명사만 영어를 쓴다.
- 사용자가 작업을 요청하면, 가장 먼저 그 요청이 **어느 단계에 해당하는지** 판별하고 한 줄로 밝힌다.
  - 형식: `> 단계: Impl (TASK-03 로그인 폼 검증 로직 수정)` 처럼 단계와 근거를 함께 적는다.
  - 판별 기준은 아래 "단계 판별표"를 따른다. 애매하면 더 앞 단계(Spec 쪽)로 분류한다.
- 원인 지점(파일, 함수, 라인)을 찾았으면 "어느 파트의 무엇이 문제인지"를 먼저 설명하고 수정한다.

### 단계 판별표

| 요청 내용 | 단계 |
|---|---|
| 새 기능, 화면, 흐름 추가 / 요구사항이 바뀜 / 정책이 애매함 | Spec |
| 기능은 정해졌는데 순서, 범위, 쪼개는 방식이 문제 | Task |
| 정해진 동작대로 안 됨 / 버그 / 테스트 실패 | Impl |
| 주석, 구조, 보안, 중복, 가독성 문제 | QA |
| 콘솔 에러, 린트 에러, E2E 실패, Sentry 이슈 | 자동 검증 → 원인에 따라 Impl 또는 QA로 회귀 |
| 사용자가 직접 써 보고 "부족하다"고 말함 | 사용자 최종 검증 → 피드백을 위 기준으로 다시 분류 |

## 1. Spec 단계 (`spec-agent`)

- 사용자와 대화하며 요구사항을 구체화한다. 추측으로 빈칸을 채우지 말고 질문한다.
- 산출물: `docs/spec/SPEC.md` (템플릿: `docs/templates/SPEC_TEMPLATE.md`)
- 전체 기능 목록, 사용자 흐름, 화면/API 목록, 예외 상황, 완료 기준(인수 조건)을 모두 포함한다.
- 사용자가 Spec을 승인하기 전에는 Task 단계로 넘어가지 않는다.

## 2. Task 단계 (`task-agent`)

- 승인된 Spec만 근거로, 기능을 **작은 단위**(한 번의 Impl에서 끝낼 수 있는 크기)로 쪼갠다.
- 산출물: `docs/tasks/TASK-XX-<이름>.md` (템플릿: `docs/templates/TASK_TEMPLATE.md`)
- 각 Task에는 Spec 참조 섹션, 범위, 범위 밖, 먼저 작성할 테스트, 완료 조건, 중단 조건을 적는다.
- 각 Task 파일에 **기능 범위**(이 Task에 해당하는 Spec 줄만 발췌)와 **연결 범위**(받아 쓰는 것과 내보내는 것의 계약)를 적는다.
- Impl에게는 Spec 경로를 주지 않고 Task 파일 하나만 넘긴다. Impl과 QA는 Spec을 직접 열지 않는다.
- Impl이 정보 부족으로 멈추면 오케스트레이터가 필요한 줄만 Task 파일 "추가 발췌"에 보충한다.

## 3. Impl 단계 (`impl-agent`) — TDD

1. **Red**: Task의 "먼저 작성할 테스트"를 실패하는 테스트로 작성하고, 실패하는 것을 실행으로 확인한다.
2. **Green**: 테스트를 통과시키는 최소한의 코드를 작성한다.
3. **Refactor**: 테스트가 통과하는 상태를 유지하며 정리한다.
- Task 범위 밖의 파일은 고치지 않는다. 필요하면 멈추고 보고한다.
- 테스트 없이 구현 코드를 먼저 쓰지 않는다.

## 4. QA 단계 (`qa-agent`)

- Impl이 만들거나 바꾼 파일에 헤더/푸터 주석을 단다. 규칙: `docs/conventions/file-header-footer.md`
- 보안(입력 검증, 인증/인가, XSS, 시크릿 노출, 의존성)과 유지보수성(중복, 이름, 함수 길이, 죽은 코드)을 검토한다.
- 산출물: `docs/qa/QA-TASK-XX.md` (템플릿: `docs/templates/QA_REPORT_TEMPLATE.md`)
- 판정: `PASS` / `FIX`(Impl로 회귀) / `PEER_REVIEW`(외부 리뷰어 교차 검증 필요)

### 피어 리뷰 (Codex, Antigravity 교차 검증)

- QA가 `PEER_REVIEW`로 판정하거나, 사용자가 대화 중에 "피어 리뷰 해", "교차 검증 돌려", "Codex로 리뷰 받아 봐" 같이 말하면 `/peer-review` 절차를 메인 세션에서 실행한다.
  - 리뷰어를 지정하지 않으면 Codex와 Antigravity 둘 다 돌린다.
  - Task 번호가 없으면 가장 최근에 QA를 마친 Task를 대상으로 하고, 어떤 Task로 잡았는지 먼저 밝힌다.
- Computer Use로 리뷰어 앱을 직접 열어 요청서를 보내고 답변을 받아 온다. Computer Use를 쓸 수 없으면 Codex는 `codex exec --sandbox read-only`, 그것도 안 되면 사용자에게 붙여 넣기를 부탁한다.
- 리뷰어에게는 **의견만** 받는다. 리뷰어 앱이 수정, 실행 승인을 물어도 승인하지 않고, 리뷰 전후 `git status`가 달라지면 멈추고 보고한다.
- 두 리뷰어가 같은 문제를 지적하면 반영 대상, 한쪽만 지적하면 직접 확인 후 판단, 서로 반대면 사용자에게 묻는다.

## 5. 자동 검증 (`verify-agent`)

순서대로 실행하고 하나라도 실패하면 원인을 분류해 회귀한다.

1. 단위 테스트: `npm test` (또는 프로젝트 테스트 명령)
2. 타입 검사: `npx tsc --noEmit` (TypeScript 프로젝트일 때)
3. 린트: `npx eslint . --max-warnings=0`
4. E2E: `npx playwright test` (콘솔 에러, 네트워크 실패도 확인)
5. Sentry: 개발 환경 이벤트에서 새 이슈가 생겼는지 확인 (Sentry MCP나 `sentry-cli`가 있을 때). DSN은 환경 변수로만 쓴다.

## 6. 사용자 최종 검증

- 로컬 서버를 띄우고(`npm run dev` 등) 주소와 확인할 시나리오 목록을 사용자에게 준다.
- 사용자가 말한 부족한 점은 `docs/feedback/FEEDBACK.md`에 적고, 단계 판별표로 분류해 해당 단계로 되돌린다.
- 사용자가 "통과"라고 말하기 전에는 Git 게이트로 넘어가지 않는다.

## 7. Git 게이트

- 커밋 전 `scripts/check-secrets.sh --staged`를 실행한다. `.env`, API 키, 토큰, 개인 키가 하나라도 잡히면 커밋하지 않는다.
- `.env*` 파일은 `.env.example`을 제외하고 절대 스테이징하지 않는다.
- 커밋 작성자는 `JJonyeok`으로 한다.
- 커밋 메시지에 모델명이나 `Claude`라는 이름을 쓰지 않는다. `Co-Authored-By`, `Claude-Session`, "Generated with" 같은 트레일러를 붙이지 않는다.
- 커밋과 푸시는 사용자가 요청할 때만 한다.

## 산출물 경로 요약

| 단계 | 파일 |
|---|---|
| Spec | `docs/spec/SPEC.md` |
| Task | `docs/tasks/TASK-XX-*.md` |
| QA | `docs/qa/QA-TASK-XX.md` |
| 피어 리뷰 | `docs/review/REVIEW-TASK-XX.md` |
| 사용자 피드백 | `docs/feedback/FEEDBACK.md` |
