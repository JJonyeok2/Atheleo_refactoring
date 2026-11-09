#!/usr/bin/env bash
# Claude Code PreToolUse 훅: Bash로 git commit / git push를 실행하기 직전에 막아서 검사한다.
# 종료 코드 2를 돌려주면 Claude Code가 해당 명령을 실행하지 않고, stderr 내용을 이유로 전달한다.

input="$(cat)"

# 훅 입력(JSON)에서 실제 실행할 명령만 꺼낸다. (경로 등 다른 필드에 섞인 단어 때문에 오탐하지 않도록)
cmd="$(printf '%s' "$input" | python3 -c 'import sys,json; print(json.load(sys.stdin).get("tool_input",{}).get("command",""))' 2>/dev/null \
    || printf '%s' "$input" | node -e 'let s="";process.stdin.on("data",d=>s+=d).on("end",()=>{try{console.log((JSON.parse(s).tool_input||{}).command||"")}catch(e){}})' 2>/dev/null)"

is_commit=0; is_push=0
printf '%s' "$cmd" | grep -Eq '(^|[;&|[:space:]])git([[:space:]]+-C[[:space:]]+[^[:space:]]+)?[[:space:]]+commit' && is_commit=1
printf '%s' "$cmd" | grep -Eq '(^|[;&|[:space:]])git([[:space:]]+-C[[:space:]]+[^[:space:]]+)?[[:space:]]+push' && is_push=1
[ "$is_commit" -eq 0 ] && [ "$is_push" -eq 0 ] && exit 0

root="${CLAUDE_PROJECT_DIR:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"
banned='(^|[^[:alnum:]])(claude|anthropic|opus|sonnet|haiku|co-authored-by|claude-session|generated with)([^[:alnum:]]|$)'

# 1) 명령줄에 직접 넣은 커밋 메시지 검사 (파일 이름 CLAUDE.md 는 예외)
if [ "$is_commit" -eq 1 ]; then
  if printf '%s' "$cmd" | sed 's/CLAUDE\.md//g' | grep -Eiq "$banned"; then
    echo "커밋 메시지에 모델명, Claude, 공동저자 트레일러를 넣을 수 없습니다. 문구를 빼고 다시 작성하세요." >&2
    exit 2
  fi
fi

# 2) 작성자 이름 확인
name="$(git -C "$root" config user.name 2>/dev/null)"
if [ "$name" != "JJonyeok" ]; then
  echo "git user.name 이 '$name' 입니다. 'git config user.name JJonyeok' 으로 설정한 뒤 다시 시도하세요." >&2
  exit 2
fi

# 3) 시크릿 검사
if [ "$is_commit" -eq 1 ]; then
  bash "$root/scripts/check-secrets.sh" --staged 1>&2 || exit 2
fi
if [ "$is_push" -eq 1 ]; then
  bash "$root/scripts/check-secrets.sh" --outgoing 1>&2 || exit 2
fi

exit 0
