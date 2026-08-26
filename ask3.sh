#!/usr/bin/env bash
# ask3 — 같은 질문을 Opus5 / Fable5 / GPT 에 병렬로 던지고, 비교표 한 장으로 받는다.
set -euo pipefail

OPUS_MODEL="${ASK3_OPUS_MODEL:-claude-opus-5}"
FABLE_MODEL="${ASK3_FABLE_MODEL:-claude-fable-5}"
GPT_MODEL="${ASK3_GPT_MODEL:-gpt-5.6-sol}"
JUDGE_MODEL="${ASK3_JUDGE_MODEL:-claude-opus-5}"

# 심볼릭 링크를 따라 실제 스크립트 위치를 찾는다
_src="${BASH_SOURCE[0]}"
while [[ -L "$_src" ]]; do
  _dir="$(cd -P "$(dirname "$_src")" && pwd)"
  _src="$(readlink "$_src")"
  [[ "$_src" != /* ]] && _src="$_dir/$_src"
done
SKILL_DIR="$(cd -P "$(dirname "$_src")" && pwd)"

# 세 모델에 공통으로 붙는 꼬리말. 답변 형태를 맞춰야 비교가 된다.
SUFFIX=$'\n\n---\n답변 규칙: 한국어. 마크다운. 서론·인사·맺음말 없이 본론만. 결론을 먼저 쓰고 근거를 뒤에.'

c_dim=$'\033[2m'; c_grn=$'\033[32m'; c_red=$'\033[31m'; c_bld=$'\033[1m'; c_off=$'\033[0m'
say() { printf '%s\n' "$*" >&2; }
die() { printf '%serror:%s %s\n' "$c_red" "$c_off" "$*" >&2; exit 1; }

need_prompt() {
  [[ -f PROMPT.md ]] || die "PROMPT.md 가 없습니다. 'ask3 new <이름>' 으로 만드세요."
  [[ -s PROMPT.md ]] || die "PROMPT.md 가 비어 있습니다."
}

# ---------- new ----------
cmd_new() {
  local name="${1:-}"
  [[ -n "$name" ]] || die "사용법: ask3 new <태스크-이름>"
  [[ -e "$name" ]] && die "'$name' 이 이미 있습니다."
  mkdir -p "$name/_runs"
  cat > "$name/PROMPT.md" <<'TPL'
<!-- 여기에 질문 하나만. 세 모델에 그대로 전달됩니다. -->
<!-- 배경 → 원하는 것 → 제약 순으로 쓰면 답변 품질이 올라갑니다. -->

## 배경


## 원하는 것


## 제약
TPL
  say "${c_grn}생성${c_off} $name/PROMPT.md"
  say ""
  say "  1. $name/PROMPT.md 에 질문 작성"
  say "  2. cd $name && ask3 run"
}

# ---------- run ----------
run_claude() {
  local model="$1" out="$2" prompt="$3"
  if claude -p --model "$model" "$prompt" > "$out" 2> "$out.log"; then
    [[ -s "$out" ]] || { echo "(빈 응답)" > "$out"; return 1; }
    return 0
  fi
  { echo "## 실행 실패 ($model)"; echo; sed -n '1,40p' "$out.log"; } > "$out"
  return 1
}

run_codex() {
  local model="$1" out="$2" prompt="$3"
  if codex exec --skip-git-repo-check -s read-only --color never \
       -m "$model" -o "$out" "$prompt" > "$out.log" 2>&1; then
    [[ -s "$out" ]] || { echo "(빈 응답)" > "$out"; return 1; }
    return 0
  fi
  { echo "## 실행 실패 ($model)"; echo; sed -n '1,40p' "$out.log"; } > "$out"
  return 1
}

cmd_run() {
  need_prompt
  mkdir -p _runs
  local prompt; prompt="$(cat PROMPT.md)$SUFFIX"
  local t0=$SECONDS

  say "${c_bld}3개 모델 병렬 실행${c_off} ${c_dim}(opus5 / fable5 / gpt)${c_off}"

  run_claude "$OPUS_MODEL"  _runs/opus5.md  "$prompt" & local p1=$!
  run_claude "$FABLE_MODEL" _runs/fable5.md "$prompt" & local p2=$!
  run_codex  "$GPT_MODEL"   _runs/gpt.md    "$prompt" & local p3=$!

  local ok=0
  for pair in "$p1:opus5" "$p2:fable5" "$p3:gpt"; do
    local pid="${pair%%:*}" nm="${pair##*:}"
    if wait "$pid"; then
      say "  ${c_grn}✓${c_off} $nm  ${c_dim}$(wc -c < "_runs/$nm.md" | tr -d ' ')자${c_off}"
      ok=$((ok+1))
    else
      say "  ${c_red}✗${c_off} $nm  ${c_dim}_runs/$nm.md.log 확인${c_off}"
    fi
  done
  [[ $ok -ge 2 ]] || die "성공한 답변이 $ok 개뿐입니다. 비교를 건너뜁니다."

  say ""
  say "${c_bld}비교표 생성${c_off} ${c_dim}($JUDGE_MODEL)${c_off}"
  local judge; judge="$(build_compare_prompt)"
  claude -p --model "$JUDGE_MODEL" "$judge" > COMPARE.md 2> _runs/compare.log \
    || die "비교 생성 실패. _runs/compare.log 확인"
  [[ -s COMPARE.md ]] || die "COMPARE.md 가 비었습니다. _runs/compare.log 확인"

  say "  ${c_grn}✓${c_off} COMPARE.md  ${c_dim}$((SECONDS - t0))초${c_off}"
  say ""
  say "다음: COMPARE.md 의 '갈린 지점' 에서 선택 표시 → ${c_bld}ask3 final${c_off}"
}

build_compare_prompt() {
  python3 - "$SKILL_DIR/compare-prompt.md" <<'PY'
import sys, pathlib
tpl = pathlib.Path(sys.argv[1]).read_text(encoding="utf-8")
def rd(p):
    f = pathlib.Path(p)
    return f.read_text(encoding="utf-8").strip() if f.exists() else "(답변 없음 — 이 모델은 실패했다. 비교에서 제외하라.)"
out = (tpl.replace("{{PROMPT}}",  rd("PROMPT.md"))
          .replace("{{OPUS5}}",   rd("_runs/opus5.md"))
          .replace("{{FABLE5}}",  rd("_runs/fable5.md"))
          .replace("{{GPT}}",     rd("_runs/gpt.md")))
sys.stdout.write(out)
PY
}

# ---------- final ----------
cmd_final() {
  need_prompt
  [[ -f COMPARE.md ]] || die "COMPARE.md 가 없습니다. 먼저 'ask3 run' 을 실행하세요."
  [[ -f FINAL.md ]] && { cp FINAL.md "FINAL.md.bak"; say "${c_dim}기존 FINAL.md → FINAL.md.bak${c_off}"; }

  say "${c_bld}최종본 작성${c_off} ${c_dim}($JUDGE_MODEL)${c_off}"
  local p
  p="$(cat "$SKILL_DIR/final-prompt.md")

---

## PROMPT.md

$(cat PROMPT.md)

---

## COMPARE.md (사용자가 선택 표시함)

$(cat COMPARE.md)

---

## 원본 답변 — Opus5

$(cat _runs/opus5.md 2>/dev/null || echo '(없음)')

---

## 원본 답변 — Fable5

$(cat _runs/fable5.md 2>/dev/null || echo '(없음)')

---

## 원본 답변 — GPT

$(cat _runs/gpt.md 2>/dev/null || echo '(없음)')"

  claude -p --model "$JUDGE_MODEL" "$p" > FINAL.md 2> _runs/final.log \
    || die "최종본 생성 실패. _runs/final.log 확인"
  [[ -s FINAL.md ]] || die "FINAL.md 가 비었습니다. _runs/final.log 확인"
  say "  ${c_grn}✓${c_off} FINAL.md"
}

# ---------- dispatch ----------
case "${1:-}" in
  new)   shift; cmd_new "$@" ;;
  run)   shift; cmd_run "$@" ;;
  final) shift; cmd_final "$@" ;;
  ""|-h|--help|help)
    cat >&2 <<HLP
ask3 — 같은 질문을 세 모델에 던지고 비교표 한 장으로 받는다.

  ask3 new <이름>   태스크 디렉토리 + PROMPT.md 생성
  ask3 run          3개 모델 병렬 실행 → COMPARE.md 생성
  ask3 final        선택 표시한 COMPARE.md → FINAL.md 작성

모델 (환경변수로 교체 가능)
  opus5   $OPUS_MODEL      \$ASK3_OPUS_MODEL
  fable5  $FABLE_MODEL     \$ASK3_FABLE_MODEL
  gpt     $GPT_MODEL       \$ASK3_GPT_MODEL
  심판    $JUDGE_MODEL     \$ASK3_JUDGE_MODEL

심판 프롬프트를 고치려면: $SKILL_DIR/compare-prompt.md
HLP
    ;;
  *) die "모르는 명령: $1  (ask3 --help)" ;;
esac
