---
name: ask3
description: 같은 질문을 Opus5 / Fable5 / GPT 세 모델에 병렬로 던지고, 합의·갈린 지점·단독 제안만 뽑은 비교표 한 장으로 받는다. 방향이 안 정해진 문제(설계 결정, 전략, 기획, 구조 선택)를 여러 관점으로 검토할 때 사용. 트리거 - "/ask3", "세 모델한테 물어봐", "여러 모델로 비교해줘", "이거 방향 좀 잡아줘".
---

# ask3

`ask3` CLI (`~/.local/bin/ask3` → `~/.claude/skills/ask3/ask3.sh`) 로 세 모델의 답변을 모으고 비교표를 만든다.
사용자가 세 답변 원문을 읽는 일이 없도록 하는 것이 목적이다.

## 흐름

1. **`ask3 new <이름>`** — 태스크 디렉토리 + `PROMPT.md` 스캐폴드 생성
2. 사용자와 함께 `PROMPT.md` 작성 (배경 → 원하는 것 → 제약)
3. **`cd <이름> && ask3 run`** — 3개 모델 병렬 실행 → `_runs/*.md` → `COMPARE.md`. 보통 1~2분
4. 사용자가 `COMPARE.md` 의 **선택:** 줄에 표시
5. **`ask3 final`** — `FINAL.md` 작성

## 결과물

```
<이름>/
  PROMPT.md    질문 (단일 원본)
  _runs/       원본 답변 3개 — 평소엔 열지 않음
  COMPARE.md   사용자가 읽는 유일한 파일
  FINAL.md     최종 통합본
```

## Claude가 지킬 것

- 3단계 실행 후 **`COMPARE.md` 를 사용자에게 요약해 주지 마라.** 그게 이미 요약본이다. 파일 경로만 알려주고 읽게 한다.
- 다만 `## 4. 빠진 것` 섹션은 짚어준다. 사용자가 놓치기 쉽고, 여기서 `PROMPT.md` 를 고쳐 재실행할지 결정한다.
- `_runs/*.md` 원본은 사용자가 명시적으로 요청할 때만 읽는다. 컨텍스트만 잡아먹는다.
- `PROMPT.md` 가 모호하면 `ask3 run` 전에 다듬어라. 질문이 나쁘면 세 답변 다 나쁘다. 실행 비용이 3배라 사전 정리가 남는다.
- 실행이 실패하면 `_runs/<모델>.md.log` 를 본다.

## 조정

- 심판 프롬프트: `~/.claude/skills/ask3/compare-prompt.md`
- 최종본 프롬프트: `~/.claude/skills/ask3/final-prompt.md`
- 모델 교체: `ASK3_OPUS_MODEL` / `ASK3_FABLE_MODEL` / `ASK3_GPT_MODEL` / `ASK3_JUDGE_MODEL`
