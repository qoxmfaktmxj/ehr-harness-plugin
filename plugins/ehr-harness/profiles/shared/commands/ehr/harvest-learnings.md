---
description: pending.jsonl 의 학습 신호를 클러스터링·점수화해 staged 패치로 변환. audit 흐름이 사용자 승인 후 반영.
---

# /ehr-harvest-learnings

본 명령은 **명시 호출 시만** 실행 (런타임 부하 0). 권장 빈도: 주 1회 또는 `/loop 7d`.

## 흐름

1. `.claude/learnings/pending.jsonl` 읽기. 라인 cap = 100 (초과 시 가장 오래된 100건만, 나머지는 다음 호출).
2. corrupt JSON 라인 skip + `errors.log` 기록.
3. `.claude/learnings/rejected.jsonl` 의 candidate_rule_hash 차단.
4. 신호를 주제별 클러스터링 (Claude 자연어 추론).
5. 각 주제별:
   - `score = success×2 + correction×1` (HARNESS.json `promotion_policy` SoT)
   - `distinct_sessions` (unique session_hash 수)
   - `same_session_cap`: 같은 session_hash 의 같은 topic 최대 +2점
   - 통과 조건: `score ≥ threshold (default 3)` AND (`distinct_sessions ≥ 2` OR `explicit_confirmed_rule`)
6. 통과 주제마다:
   - `candidate_rule` (1줄 자연어 정규화) 추출
   - `staged/{topic-slug}.md` 생성 (front-matter: score, signals, scope=project-local 기본, target=AGENTS.md|ehr-lessons/SKILL.md)
   - `nonce = sha256 lowercase hex 64` (실 구현은 sha256sum / shasum / node fallback)
   - `ehr_cycle.learnings_meta.staged_nonces[topic] = nonce` 갱신
7. pending.jsonl → `archived/pending-YYYYMMDD.jsonl` rotate.
8. ehr_cycle.learnings_meta 갱신 (last_harvest_at, counter).
9. 보고: 생성된 staged 개수, 다음 단계는 `/ehr-harness audit` 으로 승인.

## 가드

- LLM 호출 cap = 100 records/call (`ehr_harvest_take_first 100`)
- staged file scope 기본 `project-local`. cwd 가 ehr-harness-plugin repo 일 때만 사용자 확인 후 `plugin-dev` 라벨.
- 본 명령이 직접 AGENTS.md / SKILL.md 를 수정하지 않음 (가드 5 — merge 는 audit 승인 후만).
- auto_stage 의미: staged 까지만 자동, merge 는 항상 manual.

## 출력 예

```
[ehr-harvest] pending: 47 records (valid 45, skipped 2)
[ehr-harvest] clusters: 2 topics
  - groupware-batch-schedule: score=5 (success×1, correction×3), distinct_sessions=3 → PROMOTED
  - validation-fn-naming: score=3 (success×1, correction×1), distinct_sessions=2 → PROMOTED
[ehr-harvest] staged 2 files at .claude/learnings/staged/
[ehr-harvest] next: /ehr-harness audit 으로 승인
```
