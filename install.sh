#!/usr/bin/env bash
# ask3 설치 — 이 저장소를 Claude Code 스킬로 연결한다.
set -euo pipefail

REPO="$(cd -P "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILL_LINK="$HOME/.claude/skills/ask3"
BIN_LINK="$HOME/.local/bin/ask3"

grn=$'\033[32m'; ylw=$'\033[33m'; red=$'\033[31m'; dim=$'\033[2m'; off=$'\033[0m'
say() { printf '%s\n' "$*"; }

# --- 의존성 확인 ---
missing=0
for c in claude codex python3; do
  if command -v "$c" >/dev/null 2>&1; then
    say "  ${grn}✓${off} $c"
  else
    say "  ${red}✗${off} $c ${dim}— 없음${off}"
    missing=1
  fi
done
if [[ $missing -eq 1 ]]; then
  say ""
  say "${red}필수 도구가 없습니다.${off}"
  say "  claude → https://claude.com/claude-code"
  say "  codex  → npm i -g @openai/codex"
  exit 1
fi

link() { # $1=대상 $2=링크경로
  local target="$1" link="$2"
  mkdir -p "$(dirname "$link")"
  if [[ -L "$link" ]]; then
    rm "$link"
  elif [[ -e "$link" ]]; then
    mv "$link" "$link.bak.$$"
    say "  ${ylw}기존 파일 백업${off} $link.bak.$$"
  fi
  ln -s "$target" "$link"
  say "  ${grn}✓${off} $link ${dim}→ $target${off}"
}

say ""
link "$REPO"          "$SKILL_LINK"
link "$REPO/ask3.sh"  "$BIN_LINK"
chmod +x "$REPO/ask3.sh"

say ""
if ! command -v ask3 >/dev/null 2>&1; then
  say "${ylw}PATH 설정 필요${off} — 셸 설정 파일에 아래 줄을 추가하세요:"
  say "  ${dim}export PATH=\"\$HOME/.local/bin:\$PATH\"${off}"
  say ""
fi
say "설치 완료. 시작하려면:"
say "  ${dim}ask3 new my-first-question${off}"
