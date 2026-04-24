# Self-Evolving EHR Harness v1.10.0 — Design Spec

| 메타 | 값 |
|---|---|
| 작성일 | 2026-04-24 |
| 대상 버전 | `ehr-harness` v1.9.5 → v1.10.0 (메이저) |
| 작업 브랜치 | `claude/self-evolving-v1.10.0` |
| 베이스 | `origin/main @ 332f642` |
| 문서 상태 | Draft → (User review) → Ready for writing-plans |

---

## 0. 동기 (Why)

현재 플러그인은 self-evolving 성숙도 **단계 2**(수동 PR + 일부 자동 기록)에 머물러 있다:

- `ehr_cycle.compounds[] / promoted[] / preferences_history[]` 에 **기록**은 됨
- 그러나 기록된 선호/지식이 **다음 세션에 자동 반영되지 않음** — 사용자가 수동으로 재입력
- 사용자 교정(correction) 신호를 캡처하는 메커니즘 자체가 없음

하네스데이터(실사용 로그 3건, ~270KB) 분석 결과 아래 **반복 페인 포인트**가 확인됨:

| 패턴 | 반복 횟수 | 해결 위치 |
|---|---|---|
| "그룹웨어 배치 매일 0시, P_YMD 이하만 연동" | 5회+ | AGENTS.md 운영 상수 |
| "파일 수정은 JSP만, 변수 추가 금지" | 3회 | 세션별 preferences 자동 주입 |
| "DB 조회만, UPDATE 는 DBA" | 3회 | AGENTS.md 권한 프로토콜 |
| "validate*() 단일 함수로 양쪽 호출" | 1회 확정 | ehr-lessons skill 함수 명명 규칙 |

Hermes / Reflexion / Voyager / Letta 의 공통 패턴은 **2단 구조**:
1. **런타임**: trace 캡처 + 메모리 append (무감독, 저위험만)
2. **배치**: 후보 선정 → constraint gate (tests + size 상한) → PR/승인 관문 → 사람 merge

이 2단 구조를 Claude Code plugin 아키텍처로 이식하되, **경량 원칙**(Sonnet 컨텍스트/토큰 예산 보호)을 최우선 제약으로 둔다.

## 1. 목표 & 비목표

### Goals
1. **단계 2 → 단계 3** 으로 성숙도 상승 — 기록된 신호가 다음 세션에 자동 반영되는 루프 완성
2. **하네스데이터에서 뽑은 4개 실지식**을 v1.10.0 에 즉시 주입 (eager 2 / lazy 2)
3. **세션 bootstrap 토큰 증가분 ≤ 500 토큰** 유지 — 하네스가 학습해도 질문당 비용 고정
4. 기존 v4 사용자는 **투명하게 v5 로 마이그레이션**, v1.9.x 동작 회귀 0

### Non-Goals
- 스킬이 스킬을 직접 rewrite (단계 4) — drift 리스크 과다
- weight 업데이트 / 임베딩 기반 클러스터링 — 경량 원칙 위반
- GitHub PR 강제 — 로컬 개발만 하는 사용자에 과함 (추후 옵션)

## 2. 핵심 설계 결정 (Brainstorming 합의)

| 축 | 결정 | 대안과의 비교 |
|---|---|---|
| 학습 신호 범위 | **correction + success 확인 하이브리드 (B)** | correction만(A): 성공 패턴 누락 / 풀 trace(C): 경량 위반 |
| 저장 구조 | **하이브리드 (C)** — raw: `.claude/learnings/pending.jsonl`, 메타: `ehr_cycle.learnings_meta` | 통합(A): HARNESS.json 비대 / 분리(B): 2군데 관리 |
| Promotion 기준 | **점수제 (C)** — success=2, correction=1, threshold=3 | N=1(A): false positive / N=3(B): 1회 합의 누락 |
| Harvest 반영 | **기존 audit 흐름 (A)** — `/harvest-learnings` 는 staged 만 생성, audit 이 3-bucket UX 로 승인 | PR 모드(B): gh 필수, 오버헤드 / 즉시 Edit(C): 사람 게이트 약화 |
| Lazy skill 배치 | **신규 `ehr-lessons` (per-profile) (B)** | 기존 `domain-knowledge` 확장(A): 역할 혼재 / shared(C): 프로파일 규칙 위반 |
| v4→v5 마이그레이션 | **자동 (A)** — strict-append + 백업 + 실패 시 rollback | 명시 명령(B): 미실행 위험 / 호환 모드(C): 코드 2경로 |

## 3. 경량 가드 6종 (최우선 제약)

| # | 가드 | 구현 | 측정/검증 |
|---|---|---|---|
| 1 | Hook stdout 침묵 | `exec 1>&2` 리다이렉트 | `hooks.test.sh`: `stdout-bytes == 0` 어서션 |
| 2 | AGENTS.md 증가분 ≤ 1024B | skeleton 내 `<!-- EHR-LESSONS -->` 섹션만 측정 | `harness-weight.test.sh`: git baseline 대비 diff |
| 3 | SKILL.md ≤ 15360B | `ehr-lessons`, `ehr-harness` 모두 | `harness-weight.test.sh`: `wc -c` |
| 4 | Harvester 자동주입 금지 | `merge.sh::apply_staged` 는 `EHR_AUDIT_APPROVED=1` 없으면 exit 2 | `merge.test.sh`: env 없이 호출 시 exit 2 |
| 5 | Strict-append 마이그레이션 | v4 기존 필드 sha256 변경 시 rollback | `harness-state.test.sh`: migration 테스트 |
| 6 | `.claude/learnings/` gitignore 제안 | update 흐름이 제안만 기록 (강제 X) | `scenarios.test.sh` 시나리오 추가 |

## 4. 아키텍처

### 4.1 레이어 구조 (단방향)

```
┌ 런타임 레이어 (세션 중, 가벼움) ─────────────────────────────┐
│                                                            │
│  SessionStart hook         UserPromptSubmit hook           │
│  (preferences → env)       (heuristic → pending.jsonl)     │
│                                                            │
└─────────────────┬──────────────────────────────────────────┘
                  ▼
         .claude/learnings/pending.jsonl
         .claude/HARNESS.json::ehr_cycle.learnings_meta
                  │
┌ 배치 레이어 (명시 호출 시만) ──────────────────────────────┐
│                                                            │
│  /ehr-harvest-learnings                                    │
│    pending → cluster+score → staged/*.md                   │
│                                                            │
└─────────────────┬──────────────────────────────────────────┘
                  ▼
         .claude/learnings/staged/*.md
                  │
┌ 승인 레이어 (기존 audit) ────────────────────────────────┐
│                                                            │
│  /ehr-harness audit → learnings_drift 제시                 │
│    → 사용자 "예" → EHR_AUDIT_APPROVED=1 → merge.sh         │
│                                                            │
└─────────────────┬──────────────────────────────────────────┘
                  ▼
┌ 정적 지식 레이어 (Phase D, 영구) ────────────────────────┐
│                                                            │
│  AGENTS.md.skel (eager, +1KB 이내)                         │
│    ├─ 분석 요청 프로토콜                                    │
│    └─ EHR 운영 상수                                         │
│                                                            │
│  ehr-lessons/SKILL.md (lazy, 15KB 상한)                    │
│    ├─ 검증 함수 명명 규칙                                   │
│    ├─ 회신 템플릿                                           │
│    └─ (이후 promoted 지식 append)                           │
│                                                            │
└────────────────────────────────────────────────────────────┘
```

반대 방향 쓰기 없음. 세션 중 hook 이 SKILL.md/AGENTS.md 를 절대 수정하지 않음.

### 4.2 컴포넌트 목록

#### 신규 파일 (실행/테스트 12 + fixture 7 = 19)

**실행/테스트 (12)**
```
plugins/ehr-harness/profiles/shared/hooks/
  user-prompt-capture.sh           # Phase A: UserPromptSubmit hook
  user-prompt-capture.test.sh
  session-start-inject.sh          # Phase B: SessionStart hook
  session-start-inject.test.sh

plugins/ehr-harness/skills/ehr-harness/lib/
  learnings.sh                     # heuristic classify/score, append/rotate
  learnings.test.sh
  harvest.sh                       # Phase C: pending → cluster → staged
  harvest.test.sh
  tests/
    harness-weight.test.sh         # 경량 가드 6종 종합 테스트

plugins/ehr-harness/profiles/shared/commands/ehr/
  harvest-learnings.md             # slash command 프롬프트 정의

plugins/ehr-harness/profiles/ehr4/skills/ehr-lessons/SKILL.md   # Phase D: lazy 2개
plugins/ehr-harness/profiles/ehr5/skills/ehr-lessons/SKILL.md   # EHR5 프로파일 버전
```

**Fixture (7)**
```
plugins/ehr-harness/skills/ehr-harness/lib/fixtures/
  learnings/
    pending-5signals.jsonl          # 2주제 클러스터링 케이스
    pending-corrupt-line.jsonl      # 라인 파싱 실패 skip 케이스
    pending-rejected-pattern.jsonl  # rejected.jsonl 차단 케이스
    harness-v4-baseline.json        # migration 입력
  prompts-ko.txt                    # 한국어 correction/success 샘플 20
  prompts-en.txt                    # 영어 샘플 20
  prompts-excluded.txt              # false positive 방지 대상
```

#### 수정 파일 (12)

```
plugins/ehr-harness/.claude-plugin/plugin.json        v1.9.5 → v1.10.0
plugins/ehr-harness/CHANGELOG.md                      v1.10.0 엔트리 추가
plugins/ehr-harness/profiles/shared/settings.json     hooks 블록에 2개 이벤트 등록
plugins/ehr-harness/profiles/ehr4/skeleton/AGENTS.md.skel   eager 2개 marker 블록 삽입
plugins/ehr-harness/profiles/ehr5/skeleton/AGENTS.md.skel   동일
plugins/ehr-harness/skills/ehr-harness/SKILL.md              Step 0.7-B, Step 2-M 업데이트
plugins/ehr-harness/skills/ehr-harness/lib/HARNESS_SCHEMA.md v5 섹션 추가
plugins/ehr-harness/skills/ehr-harness/lib/harness-state.sh       v4→v5 migration 로직
plugins/ehr-harness/skills/ehr-harness/lib/harness-state.test.sh  migration 케이스 추가
plugins/ehr-harness/skills/ehr-harness/lib/audit.sh               learnings_drift 통합
plugins/ehr-harness/skills/ehr-harness/lib/merge.sh               staged 적용 + env gate
plugins/ehr-harness/skills/ehr-harness/lib/merge.test.sh          env gate 케이스 추가
```

### 4.3 퍼블릭 인터페이스 (모듈 경계)

| Unit | 공개 함수 | 의존 |
|---|---|---|
| `learnings.sh` | `ehr_learn_classify(prompt, prev_turn) → {type, score}`<br>`ehr_learn_append(record)`<br>`ehr_learn_rotate()` | 없음 (pure shell + jq) |
| `harness-state.sh` (확장) | 기존 + `ehr_state_migrate_v4_to_v5(path)`, `ehr_state_get_pref(key)` | `jq` |
| `harvest.sh` | `ehr_harvest_run(pending_path, staged_dir) → N_created`<br>`ehr_harvest_cluster_prompt(records) → prompt_text` | `learnings.sh` |
| `audit.sh` (확장) | 기존 `compute_drift()` 내부에 `learnings_drift` 섹션 추가 | `harness-state.sh` |
| `merge.sh` (확장) | 기존 + `apply_staged(staged_path, target)` — `EHR_AUDIT_APPROVED` 필수 | `audit.sh` |

각 unit 은 자기 테스트 파일이 책임 경계 정의. 외부에서 내부 변수/함수 접근 금지.

## 5. 데이터 플로우 상세

### 5.1 런타임 — 신호 캡처 (Phase A, UserPromptSubmit)

**입력**: Claude Code hook spec 상 stdin JSON — `{session_id, transcript_path, prompt, cwd, ...}`

**처리**:
1. `HARNESS.json` 미존재 또는 v4 미만 → silent skip exit 0
2. `transcript_path` 에서 최근 assistant 턴 1개 tail → `prev_turn_snippet` (200자 trim)
3. `prompt` 에 대해 heuristic 매칭 (아래 5.2)
4. 매칭 성공 시 `pending.jsonl` 에 1줄 append
5. stdout 침묵 (모든 로그는 `errors.log` 로)

**출력 스키마 (pending.jsonl 1줄)**:
```json
{
  "ts": "2026-04-24T14:32:11+09:00",
  "session_id": "abc123",
  "signal_type": "success" | "correction",
  "score_delta": 2 | 1,
  "prompt_snippet": "이 방향으로 확정해줘",
  "prev_turn_hash": "sha256:...",
  "prev_turn_snippet": "checkMatLeave() 로 리네임하고...",
  "tool_context": {"last_skill": "ehr-screen-builder", "last_tool": "Edit"},
  "profile": "ehr4"
}
```

**프라이버시**: `prompt_snippet` / `prev_turn_snippet` 은 최대 200자 trim, 전체 저장 금지.

### 5.2 Heuristic 규칙

```
# correction 신호 (+1점) — 부정/재시도
KO: 아니(야|라고)?|다시|그거 말고|수정해줘|고쳐|잘못|틀렸|되돌려|롤백|빼|없애
EN: no[,.!]|undo|revert|wrong|that's not|nope|go back|cancel

# success 확인 (+2점) — 명시 확정
KO: 좋아|딱 그거|이 방향|확정|좋습니다|맞아|정확|완벽|됐어
EN: perfect|exactly|confirmed|good|looks right|ship it|lgtm

# 제외 (false positive 방지)
- prompt 길이 < 3자 또는 > 500자 → 무시
- prompt 가 순수 URL/경로/명령어만 → 무시
- 직전 assistant 턴 없음 (세션 첫 prompt) → 무시
```

경계 어휘("좋아서") 구분을 위해 word-boundary regex 사용. False positive 사례는 `rejected.jsonl` 에 추가해 harvest 에서 차단.

### 5.3 런타임 — Preferences 자동 주입 (Phase B, SessionStart)

**흐름**:
```
SessionStart fires
  → harness-state.sh::ehr_state_get_pref(key) 로 preferences_history[] 최신값 추출
  → allowlist 6개만 env 변수로 export
  → stdout 침묵
```

**Allowlist (하드코딩)**:
```
EHR_SUGGEST_MODE    # ask | silent
EHR_RESPONSE_TONE   # concise | verbose
EHR_DB_AUTH         # readonly | full
EHR_FILE_SCOPE      # minimal | broad
EHR_LANG            # ko | ko_en
EHR_HARVEST_POLICY  # auto_stage | manual_only
```

그 외 키는 무시. preferences_history 오염되어도 예측 가능한 env만 주입.

### 5.4 배치 — Harvest (Phase C, /ehr-harvest-learnings)

**단계별 흐름**:
```
1. pending.jsonl 읽기 (last_harvest_at 이후 증분)
2. rejected.jsonl 로드 → 차단 세트 생성
3. Claude 가 주제별 클러스터링 (LLM 호출)
4. 각 주제별 점수 합산 (success×2 + correction×1)
5. threshold ≥ 3 → staged/{topic-slug}.md 생성
6. ehr_cycle.learnings_meta 갱신
7. pending.jsonl → archived/pending-YYYYMMDD.jsonl 로 rotate
```

**staged/*.md 포맷 예**:
```markdown
---
topic: groupware-batch-schedule
score: 5
signals: 4 (correction: 3, success: 1)  # 3*1 + 1*2 = 5
first_seen: 2026-03-12T...
last_seen: 2026-04-21T...
target: AGENTS.md.skel   # or ehr-lessons/SKILL.md
priority: eager          # or lazy
---

## 제안 반영 내용
<!-- EHR-LESSONS:BEGIN groupware-batch-schedule -->
### 그룹웨어 연동 배치 상수
- 배치 실행: 매일 00:00 (SYSDATE 기준)
- P_YMD 파라미터: 배치 기준일
- 필수: MAX(ORD_YMD) 조건에 `<= REPLACE(P_YMD, '-', '')` 포함
- 반복 실수: "미래 발령 확정 시 그룹웨어 선반영"
<!-- EHR-LESSONS:END groupware-batch-schedule -->

## 원신호 (5건)
- pending.jsonl:L12 (2026-03-12, correction)
- pending.jsonl:L47 (2026-03-15, correction)
- ...
```

**Crash-safe**: pending.jsonl 은 meta 갱신 포함 완료 후에만 rotate. 도중 실패 시 재시도 가능.

### 5.5 승인 — audit 흐름 통합

`audit.sh::compute_drift()` 에 섹션 1개 추가:
```
기존: sources drift + outputs drift + analysis drift
추가: learnings_drift   ← staged/*.md 존재 시 "학습 제안 N건"
```

사용자 "예" 응답 → `EHR_AUDIT_APPROVED=1` 세팅 → `merge.sh::apply_staged()` 호출:
- **eager 대상** (AGENTS.md.skel): marker 블록 삽입 → 다음 stamped 재생성 시 전파
- **lazy 대상** (ehr-lessons/SKILL.md): profile별 SKILL.md 에 append
- staged/*.md → `staged.applied/*.md` 로 이동

거부 시:
- staged/*.md → `staged.rejected/*.md`
- `rejected.jsonl` 에 pattern 기록 → 재학습 차단

### 5.6 충돌 해결 (audit 단계)

| 케이스 | 해결 |
|---|---|
| staged 제안 영역을 사용자가 이미 편집함 | `user-edit` 버킷 → 3-way 선택 제시 |
| 기존 marker id 와 신규 topic id 충돌 | 덮어쓰기 / 새 id 저장 선택 |
| rejected 이력 존재 | harvest 단계에서 필터링, audit 도달 안 함 |

## 6. 에러 처리 원칙

### 6.1 런타임 hook — "세션을 절대 막지 않는다"

| 상황 | 동작 |
|---|---|
| HARNESS.json 없음/파싱실패 | silent skip, exit 0 |
| jq 미설치 | silent skip + `hook-degraded.flag` 생성 (1회) |
| `.claude/learnings/` 쓰기 권한 없음 | silent skip |
| regex 에러 | 그 신호만 버림 + `errors.log` 기록 |

**철칙**: 모든 경로 exit 0. hook 이 exit ≠ 0 이면 Claude Code 가 세션 차단 가능.

### 6.2 마이그레이션 (v4→v5) — 원자성

```
1. 백업: .ehr-bak/harness-v4-${timestamp}.json
2. v5 필드 append
3. schema 검증 (jq)
4. strict-append 검증: V4 의 모든 필드 sha256 == migrated sha256 (schema_version 제외)
5. 실패 시 → 백업 복원 + migration-failed.log + v4 모드로 fallback
```

마이그레이션 실패해도 세션은 "학습 기능 비활성" 모드로 계속. 기존 기능 100% 동작.

### 6.3 배치 (harvest) — Crash-safe

| 에러 | 처리 |
|---|---|
| pending.jsonl 없음 | "신호 없음" + exit 0 |
| JSON 파싱 실패 라인 | 해당 라인 skip, errors.log 기록 |
| Claude 호출 실패 | pending 유지 + rotate 안 함 |
| staged/ 쓰기 실패 | exit 1, pending 유지 |
| meta 갱신 실패 | staged 롤백 (rm), pending 유지 |
| Ctrl+C 중단 | 중간 staged 는 `.partial` 접미사로 남김, 다음 실행에서 감지 |

### 6.4 로그 경로 일원화

```
.claude/learnings/
  pending.jsonl
  staged/
  staged.applied/
  staged.rejected/
  rejected.jsonl
  errors.log              (모든 layer 공통, 1MB rotate)
  hook-degraded.flag      (degraded 모드 감지)
  archived/
    pending-YYYYMMDD.jsonl
```

## 7. 테스트 전략

### 7.1 TDD 순서

각 Phase 내부:
```
1. test 파일 작성 (실패 확인)
2. 본체 구현 (테스트 통과)
3. 회귀: 기존 테스트 전부 재실행
4. 경량 가드 테스트 실행
5. 커밋 (atomic)
```

### 7.2 테스트 파일 책임

**신규 7개**:

| 파일 | 주요 검증 | 독립성 |
|---|---|---|
| `learnings.test.sh` | classify 정확도(한/영), score, 200자 trim, 제외 규칙 | pure shell |
| `user-prompt-capture.test.sh` | hook stdin JSON, pending.jsonl 포맷, stdout 침묵, silent-fail | learnings.sh mock |
| `session-start-inject.test.sh` | allowlist 6개만, 그 외 키 무시, HARNESS.json 부재 silent | harness-state.sh mock |
| `harvest.test.sh` | 클러스터링 프롬프트, threshold 3점, rejected 차단, rotate, crash-safe | learnings.sh real |
| `harness-weight.test.sh` | 경량 가드 6종 종합 | git diff 기반 |
| `merge.test.sh` (확장) | `EHR_AUDIT_APPROVED` 없으면 exit 2, marker 충돌, staged.applied 이동 | audit.sh mock |
| `harness-state.test.sh` (확장) | v4→v5 strict-append, 롤백, 백업 복원 | fixture 파일 |

**회귀 13개**: 기존 테스트 전부 재실행, 빨간 불 0.

### 7.3 Fixture 전략

```
plugins/ehr-harness/skills/ehr-harness/lib/fixtures/
  learnings/
    pending-5signals.jsonl          # 2주제 클러스터링 케이스
    pending-corrupt-line.jsonl      # 라인 3 JSON 깨짐 → skip
    pending-rejected-pattern.jsonl  # rejected.jsonl 차단 케이스
    harness-v4-baseline.json        # migration 입력
  prompts-ko.txt                    # 한국어 correction/success 20개
  prompts-en.txt                    # 영어 20개
  prompts-excluded.txt              # false positive 방지 (URL, 짧은 문자열)
```

Fixture 는 실제 하네스데이터에서 **익명화한 짧은 스니펫**(사번/일자/이름 제거). 사용자 프라이버시 보호.

### 7.4 실행

```bash
bash plugins/ehr-harness/skills/ehr-harness/lib/tests/run-all.sh
```

환경: bash 4+, jq 1.6+, git. Windows/MSYS/Git-bash 동작 확인 (CRLF 방어는 `scenarios.test.sh` 패턴 재사용).

## 8. 구현 마일스톤 (원자 커밋 12개)

**Phase 의존**:
```
Phase A (캡처)  ─┐ 런타임 레이어, 상호 독립
Phase B (주입)  ─┘
      ↓
Phase D-1 (AGENTS.md eager 2개 + ehr-lessons skill 생성) ← 체감 빠른 가치
      ↓
Phase C (harvest + audit 통합) ← A+B 데이터 필요
      ↓
Phase D-2 (lazy 2개 탑재)
      ↓
경량 가드 테스트 → 버전 bump
```

**12개 커밋**:

| # | 커밋 제목 | 대상 |
|---|---|---|
| 1 | test(learnings): classify/score/trim 테스트 추가 | TDD red |
| 2 | feat(learnings): heuristic 라이브러리 `learnings.sh` | TDD green |
| 3 | feat(hooks): UserPromptSubmit capture hook (Phase A) | Phase A |
| 4 | feat(schema): HARNESS v4→v5 자동 마이그레이션 + 백업 | migration |
| 5 | feat(hooks): SessionStart preferences 주입 (Phase B) | Phase B |
| 6 | feat(skel): AGENTS.md eager 2개 지식 주입 (Phase D-1) | Phase D-1 |
| 7 | feat(skills): ehr-lessons skill (EHR4/5) + lazy 2개 (Phase D-2) | Phase D-2 |
| 8 | feat(harvest): /ehr-harvest-learnings + harvest.sh (Phase C) | Phase C |
| 9 | feat(audit): learnings drift 통합 + merge EHR_AUDIT_APPROVED gate | 통합 |
| 10 | test(weight): 경량 가드 6종 + CI wiring | 가드 |
| 11 | docs(skill): SKILL.md 흐름 + CHANGELOG v1.10.0 | 문서 |
| 12 | chore: bump v1.9.5 → v1.10.0 | 버전 |

## 9. Definition of Done

- [ ] 신규 테스트 7개 모두 통과 (구현 단계별)
- [ ] 기존 회귀 테스트 13개 전부 재통과 (빨간 불 0)
- [ ] 경량 가드 6종 전부 통과
  - [ ] AGENTS.md 증가분 ≤ 1024B (ehr4, ehr5 각각)
  - [ ] SKILL.md ≤ 15360B (ehr-lessons, ehr-harness 각각)
  - [ ] Hook stdout byte-count == 0
  - [ ] Harvester `EHR_AUDIT_APPROVED` 없이 호출 시 exit 2
  - [ ] v4→v5 strict-append 검증
  - [ ] `.claude/learnings/` gitignore 제안 로직 동작
- [ ] 마이그레이션 백업 생성 + 실패 시 복원 확인
- [ ] 하네스데이터 fixture 로 end-to-end 시뮬레이션 성공 (pending → staged → audit)
- [ ] README.md 에 "self-evolving v1.10" 섹션 1~2단락 추가
- [ ] CHANGELOG.md v1.10.0 엔트리 작성

## 10. 리스크 & 완화

| 리스크 | 완화 |
|---|---|
| 한국어 heuristic false positive ("좋아서" → success?) | word-boundary regex, fixture 20개 고정, 사용자 신고 시 rejected.jsonl append |
| `/ehr-harvest-learnings` Claude 호출 비용 | 명시 호출 + `/loop 7d` 권장, threshold 3점으로 입력 압축 |
| Windows 경로/개행 이슈 | 기존 `scenarios.test.sh` CRLF 방어 패턴 재사용, fixture LF 고정 |
| v4 사용자 migration 실패 | 백업 + silent fallback → 기존 v1.9.5 동일 동작 유지 |
| ehr-lessons skill 15KB 도달 | harvest 단계에서 append 거부 + 오래된 topic 수집만 |

## 11. 성숙도 평가 (Before / After)

| 단계 | Before (v1.9.5) | After (v1.10.0) |
|---|---|---|
| 0. 정적 산출물 | ✅ | ✅ |
| 1. 매니페스트 상태 추적 | ✅ HARNESS.json v4 | ✅ v5 |
| 2. 자동 drift 감지 | ✅ audit | ✅ + learnings_drift |
| 2.5 피드백 기록 | ⚠️ 기록만 | ✅ 자동 캡처 (hook) |
| **3. 자동 반영** | ❌ 수동 재입력 | ✅ **SessionStart 주입 + audit 관문** |
| 4. 스킬 자가수정 | ❌ | ❌ (비목표) |

**결과**: 단계 2 → **단계 3** 도달.

## 12. 관련 문서

- `plugins/ehr-harness/skills/ehr-harness/lib/HARNESS_SCHEMA.md` — 스키마 v5 섹션 (본 작업에서 신설)
- `plugins/ehr-harness/CHANGELOG.md` — v1.10.0 엔트리
- `하네스데이터/` — 실사용 로그 (외부, 본 작업의 분석 원천)
- Hermes self-evolving: https://github.com/NousResearch/hermes-agent
- Reflexion (arXiv 2303.11366), Voyager (arXiv 2305.16291), Letta/MemGPT

---

**Next**: User review → writing-plans skill 로 구현 플랜 생성.
