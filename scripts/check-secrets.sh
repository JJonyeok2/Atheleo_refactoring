#!/usr/bin/env bash
# 시크릿 검사기
#   --staged   : 스테이징된 변경 검사 (기본값, 커밋 직전)
#   --outgoing : 아직 원격에 올라가지 않은 커밋 전체 검사 (푸시 직전)
#   --all      : 저장소에 추적 중인 모든 파일 검사
# gitleaks가 설치돼 있으면 함께 실행하고, 없으면 내장 패턴만으로 검사한다.

set -u
mode="${1:---staged}"
root="$(git rev-parse --show-toplevel 2>/dev/null)" || { echo "git 저장소가 아닙니다." >&2; exit 1; }
cd "$root" || exit 1

fail=0
report() { echo "  [시크릿 의심] $1" >&2; fail=1; }

# 1) 검사 대상 파일 목록
case "$mode" in
  --staged)   files="$(git diff --cached --name-only --diff-filter=ACMR)" ;;
  --outgoing)
    upstream="$(git rev-parse --abbrev-ref --symbolic-full-name '@{u}' 2>/dev/null || true)"
    if [ -n "$upstream" ]; then
      files="$(git diff --name-only --diff-filter=ACMR "$upstream"...HEAD)"
    else
      files="$(git ls-files)"
    fi ;;
  --all)      files="$(git ls-files)" ;;
  *) echo "알 수 없는 옵션: $mode" >&2; exit 1 ;;
esac

[ -z "$files" ] && { echo "검사할 파일이 없습니다."; exit 0; }

# 2) 파일 이름 규칙: .env 계열, 키 파일
while IFS= read -r f; do
  base="$(basename "$f")"
  case "$base" in
    .env.example|.env.sample|.env.template) ;;
    .env|.env.*|*.pem|*.key|*.p12|*.pfx|id_rsa|id_ed25519|credentials.json|service-account*.json)
      report "$f : 업로드하면 안 되는 파일 형식" ;;
  esac
done <<< "$files"

# 3) 내용 패턴
patterns=(
  'AKIA[0-9A-Z]{16}'                                   # AWS Access Key
  'sk-ant-[A-Za-z0-9_-]{20,}'                          # Anthropic
  'sk-(proj-)?[A-Za-z0-9_-]{32,}'                      # OpenAI
  'gh[pousr]_[A-Za-z0-9]{36,}'                         # GitHub
  'xox[abprs]-[A-Za-z0-9-]{10,}'                       # Slack
  'AIza[0-9A-Za-z_-]{35}'                              # Google API
  '-----BEGIN [A-Z ]*PRIVATE KEY-----'                 # 개인 키
  'sntrys_[A-Za-z0-9_]{20,}'                           # Sentry 인증 토큰
  '(api[_-]?key|secret|token|password|passwd)["'"'"']?[[:space:]]*[:=][[:space:]]*["'"'"'][^"'"'"'[:space:]$<{]{12,}["'"'"']'
)

while IFS= read -r f; do
  [ -f "$f" ] || continue
  case "$f" in
    *.lock|package-lock.json|pnpm-lock.yaml|yarn.lock|*.png|*.jpg|*.jpeg|*.gif|*.ico|*.pdf|*.woff*) continue ;;
  esac
  if [ "$mode" = "--staged" ]; then
    content="$(git show ":$f" 2>/dev/null)"
  else
    content="$(cat "$f")"
  fi
  for p in "${patterns[@]}"; do
    hit="$(printf '%s' "$content" | grep -nEi -- "$p" | head -n 3)"
    if [ -n "$hit" ]; then
      while IFS= read -r line; do
        report "$f:${line%%:*} (패턴: ${p:0:24}...)"
      done <<< "$hit"
    fi
  done
done <<< "$files"

# 4) gitleaks가 있으면 추가 검사
if command -v gitleaks >/dev/null 2>&1; then
  if [ "$mode" = "--staged" ]; then
    gitleaks protect --staged --no-banner --redact >/dev/null 2>&1 || report "gitleaks가 시크릿을 발견했습니다 (gitleaks protect --staged -v 로 확인)"
  else
    gitleaks detect --no-banner --redact >/dev/null 2>&1 || report "gitleaks가 시크릿을 발견했습니다 (gitleaks detect -v 로 확인)"
  fi
fi

if [ "$fail" -ne 0 ]; then
  echo "시크릿 검사 실패: 위 항목을 제거하거나 환경 변수로 옮긴 뒤 다시 시도하세요." >&2
  exit 1
fi
echo "시크릿 검사 통과"
exit 0
