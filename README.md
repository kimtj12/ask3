# ask3

같은 질문을 **세 개의 AI 모델에 병렬로 던지고, 답변 3개 대신 비교표 한 장을 받는다.**

Claude Code 스킬 + CLI. 약 1분.

---

## 문제

방향이 안 잡힌 문제를 여러 모델에 물어보는 사람이 많다. Opus에 한 번, GPT에 한 번, 또 다른 모델에 한 번. 그리고 답변 셋을 전부 읽고 직접 통합한다.

이 방식의 비용은 파일 개수가 아니다. **같은 내용을 세 번 읽는 것**이다. 세 답변의 70%는 겹치는데 매번 전부 읽게 된다. 그러다 보면 비교 자체를 포기하고 그냥 첫 번째 답변을 쓴다.

## 해결

원본을 읽지 않는다. 대신 **합의 / 갈린 지점 / 단독 제안**만 뽑은 문서 한 장을 읽는다.

```
PROMPT.md  (질문 하나)
    │
    ├── claude -p --model claude-opus-5 --effort high     ─┐
    ├── claude -p --model claude-fable-5-1 --effort high  ─┤  병렬
    └── codex exec -m gpt-6-astra (effort high)           ─┘
                    ↓
         _runs/opus5.md, fable5.md, gpt.md      ← 열지 않는다
                    ↓
              심판 모델 1회 호출
                    ↓
              COMPARE.md                        ← 이것만 읽는다
                    ↓  (갈린 지점에 체크)
              FINAL.md
```

읽을 분량이 3배에서 0.3배가 된다.

---

## COMPARE.md 는 이렇게 생겼다

실제 출력 일부다. 질문은 "3인 팀 React 관리자 앱의 상태 관리를 정해달라".

```markdown
## 1. 합의 (그냥 채택하면 되는 것)

- 서버 상태는 TanStack Query. 셋 다 동일 (Opus5 / Fable5 / GPT).
- Redux는 3인 팀에 과하다. 셋 다 명시적으로 배제.

## 2. 갈린 지점 (여기만 결정하면 된다)

### 쟁점: 클라이언트 상태에 라이브러리를 넣을 것인가?

| 안 | 주장 | 근거 / 트레이드오프 |
|---|---|---|
| Opus5  | Zustand 추가 | 남는 전역 상태가 극소량, TS 타입 추론 우수 |
| Fable5 | Zustand 추가 | 보일러플레이트 없음, 학습 비용 최소 |
| GPT    | useState + Context | 3명 규모엔 Zustand조차 과함 |

**추천:** Zustand. 다만 전역 공유가 실제로 필요해질 때까지 GPT 안으로
시작하는 것도 방어 가능하다.

**선택:** [ ] Opus5  [ ] Fable5  [ ] GPT  [ ] 혼합 →

## 3. 단독 제안 (한 곳에서만 나온 것)

| 출처 | 제안 | 왜 볼만한가 |
|---|---|---|
| Fable5 | Query + axios 조합 | Query는 fetcher를 제공하지 않는데 나머지 둘은 언급 없음 |

## 4. 빠진 것

- 폼 상태를 어디에 둘지 — 관리자 앱의 핵심인데 세 답변 모두 다루지 않았다.
- 인증/세션 상태의 분류 — 서버 상태인지 클라이언트 상태인지 셋 다 답이 없다.
```

**4번 섹션이 예상 밖으로 쓸모 있다.** 세 답변 전부의 사각지대는 원본을 각각 읽어서는 안 보인다. 교집합의 여집합이라 비교를 거쳐야만 드러난다.

심판 모델에는 규칙 하나가 강하게 걸려 있다 — **원본에 없는 의견을 만들지 말 것.** 4번 섹션만 예외로 "빠졌다"는 지적을 허용하고, 답을 제시하는 것은 여전히 금지한다.

---

## 설치

```bash
git clone https://github.com/kimtj12/ask3.git
cd ask3 && ./install.sh
```

`install.sh` 가 하는 일:

- `~/.claude/skills/ask3` → 이 저장소 (심볼릭 링크)
- `~/.local/bin/ask3` → `ask3.sh` (심볼릭 링크)

링크라서 `git pull` 하면 바로 최신이 된다. 기존 파일이 있으면 `.bak` 으로 백업한다.

### 요구사항

| 도구 | 용도 |
|---|---|
| [Claude Code](https://claude.com/claude-code) (`claude`) | Opus / Fable 호출, 심판 |
| [Codex CLI](https://github.com/openai/codex) (`codex`) | GPT 호출 |
| `python3` | 프롬프트 템플릿 치환 |

세 모델을 각각 다른 CLI로 부르기 때문에 **두 CLI 모두 로그인되어 있어야 한다.**

---

## 사용법

```bash
ask3 new pricing-strategy      # 디렉토리 + PROMPT.md 생성
cd pricing-strategy
$EDITOR PROMPT.md              # 배경 → 원하는 것 → 제약

ask3 run                       # 3개 병렬 + 비교표. 약 1분
$EDITOR COMPARE.md             # '선택:' 줄에 체크

ask3 final                     # FINAL.md 작성
```

결과물:

```
pricing-strategy/
  PROMPT.md      질문 (단일 원본)
  _runs/         원본 답변 3개 — 평소엔 열지 않는다
  COMPARE.md     읽는 유일한 파일
  FINAL.md       최종 통합본
```

`FINAL.md` 는 체크한 선택을 따르고, **체크하지 않은 쟁점은 추천안으로 임시 반영한 뒤 하단 "미결정" 목록에 남긴다.** 결정을 미룬 것과 결정한 것이 섞이지 않는다.

`[x] 혼합 → Zustand 쓰되 필터는 URL 쿼리에` 처럼 손으로 쓴 메모도 그대로 반영된다.

### Claude Code 안에서

스킬로 설치되므로 대화 중 `/ask3` 또는 "세 모델한테 물어봐" 로도 부를 수 있다. `SKILL.md` 에 Claude가 지킬 규칙이 있다 — 그중 핵심은 **COMPARE.md 를 대신 요약해 주지 말 것.** 그게 이미 요약본이다.

---

## 커스터마이징

### 심판 프롬프트

품질의 대부분이 여기서 결정된다. 마음에 안 드는 비교표가 나오면 여길 고친다.

- `compare-prompt.md` — 비교 규칙과 출력 형식
- `final-prompt.md` — 통합본 작성 규칙

### 모델 교체

환경변수로 바꾼다. 다른 조합을 쓰고 싶으면 여기만 건드리면 된다.

```bash
export ASK3_OPUS_MODEL=claude-opus-5
export ASK3_FABLE_MODEL=claude-fable-5-1
export ASK3_GPT_MODEL=gpt-6-astra
export ASK3_JUDGE_MODEL=claude-opus-5    # 비교표·최종본을 쓰는 모델
export ASK3_EFFORT=high                 # 네 호출 모두의 추론 강도
```

세 모델 모두에 공통으로 붙는 꼬리말(한국어·마크다운·서론 없이 등)은 `ask3.sh` 의 `SUFFIX` 에 있다. 답변 형식이 제각각이면 비교가 안 되기 때문에 강제한다.

---

## 알아둘 것

- **질문이 나쁘면 세 답변 다 나쁘다.** 실행 비용이 3배라 `PROMPT.md` 를 다듬는 게 평소보다 더 남는다.
- **`_runs/` 는 열지 않는다.** 안 읽으려고 만든 구조다. 특정 답변의 디테일이 필요할 때만 본다.
- 세 모델 중 하나가 실패해도 나머지 둘로 비교를 진행한다. 두 개 미만이면 중단한다. 실패 로그는 `_runs/<모델>.md.log` 에 있다.
- 답변 길이는 `PROMPT.md` 의 제약으로 조절한다. 세 모델의 기본 분량이 서로 다르다.

## 왜 세 개인가

둘이면 갈렸을 때 판단 근거가 없다. 넷이면 비교표가 다시 길어져서 원래 문제로 돌아간다. 셋은 다수결이 성립하는 최소 홀수이면서, 표 하나에 들어가는 최대치다.

---

## 라이선스

MIT
