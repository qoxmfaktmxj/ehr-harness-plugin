# Self-Evolving EHR Harness v1.10.0 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** ehr-harness 플러그인을 self-evolving 성숙도 단계 2 → 단계 3 으로 끌어올리는 v1.10.0 minor 릴리즈. 사용자 교정/성공 신호 캡처 → 배치 harvest → audit 승인 게이트 → project-local 정적 지식 반영 루프.

**Architecture:** 3-layer + 단방향. **런타임**(silent hooks: UserPromptSubmit capture / SessionStart inject) → **배치**(`/ehr-harvest-learnings` slash) → **승인**(기존 audit 흐름에 learnings_drift 통합). 정적 지식은 project-local 기본(scope=plugin-dev 명시 시만 skel 수정). 경량 가드 8종 + PII redaction + nonce 검증.

**Tech Stack:** bash 4+, jq 1.6+, git, Claude Code hooks API (UserPromptSubmit, SessionStart), Windows + Git-bash 호환.

**Authoritative Spec:** `2026-04-25-self-evolving-harness-v1.10-design-v2.md` 의 v2 본문 + §14 v2.1 patch. 충돌 시 §14 우선.

**Branch:** `claude/self-evolving-v1.10.0` (origin/main 동기화). 10 atomic commits.

---

## File Structure

### 신규 파일 (실행/테스트 14 + fixture 8)

**Phase A — Capture**
- `plugins/ehr-harness/profiles/shared/hooks/user-prompt-capture.sh` — UserPromptSubmit hook entry
- `plugins/ehr-harness/profiles/shared/hooks/user-prompt-capture.test.sh` — hook 단위 테스트
- `plugins/ehr-harness/skills/ehr-harness/lib/learnings.sh` — heuristic classify/score, append/rotate, ehr_classify_signal()
- `plugins/ehr-harness/skills/ehr-harness/lib/learnings.test.sh`
- `plugins/ehr-harness/skills/ehr-harness/lib/redaction.sh` — PII 정규식 라이브러리
- `plugins/ehr-harness/skills/ehr-harness/lib/redaction.test.sh`

**Phase B — Inject**
- `plugins/ehr-harness/profiles/shared/hooks/session-start-inject.sh`
- `plugins/ehr-harness/profiles/shared/hooks/session-start-inject.test.sh`

**Phase C — Harvest**
- `plugins/ehr-harness/profiles/shared/commands/ehr/harvest-learnings.md` — slash command 정의
- `plugins/ehr-harness/skills/ehr-harness/lib/harvest.sh`
- `plugins/ehr-harness/skills/ehr-harness/lib/harvest.test.sh`

**Phase D — Static Knowledge**
- `plugins/ehr-harness/profiles/ehr4/skills/ehr-lessons/SKILL.md`
- `plugins/ehr-harness/profiles/ehr5/skills/ehr-lessons/SKILL.md`

**Infrastructure**
- `plugins/ehr-harness/skills/ehr-harness/lib/tests/run-all.sh` — 통합 runner
- `plugins/ehr-harness/skills/ehr-harness/lib/tests/harness-weight.test.sh` — 가드 8종 종합
- `plugins/ehr-harness/CHANGELOG.md` — Keep a Changelog 형식 신규

**Fixtures (8)**
- `plugins/ehr-harness/skills/ehr-harness/lib/fixtures/learnings/pending-5signals.jsonl`
- `.../learnings/pending-corrupt-line.jsonl`
- `.../learnings/pending-rejected-pattern.jsonl`
- `.../learnings/harness-v4-baseline.json`
- `.../prompts-ko.txt`
- `.../prompts-en.txt`
- `.../prompts-excluded.txt`
- `.../redaction-cases.txt`

### 수정 파일 (13)

- `plugins/ehr-harness/.claude-plugin/plugin.json` — v1.9.5 → v1.10.0
- `README.md` — 버전 stale 정정 + CHANGELOG 링크
- `plugins/ehr-harness/profiles/shared/settings.json` — hooks 블록 갱신, 기존 path migration
- `plugins/ehr-harness/profiles/shared/hooks/db-read-only.sh` — `$CLAUDE_PROJECT_DIR` 호환 헤더 추가
- `plugins/ehr-harness/profiles/shared/hooks/vcs-no-commit.sh` — 동일
- `plugins/ehr-harness/profiles/ehr4/skeleton/AGENTS.md.skel` — eager 2개 marker 삽입
- `plugins/ehr-harness/profiles/ehr5/skeleton/AGENTS.md.skel` — 동일
- `plugins/ehr-harness/skills/ehr-harness/SKILL.md` — Step 0.7-B 마이그레이션 트리거, Step 2-M learnings_drift
- `plugins/ehr-harness/skills/ehr-harness/lib/HARNESS_SCHEMA.md` — v5 섹션
- `plugins/ehr-harness/skills/ehr-harness/lib/harness-state.sh` — v4→v5 migration
- `plugins/ehr-harness/skills/ehr-harness/lib/harness-state.test.sh` — migration 케이스
- `plugins/ehr-harness/skills/ehr-harness/lib/audit.sh` — learnings_drift 통합
- `plugins/ehr-harness/skills/ehr-harness/lib/merge.sh` — apply_staged + nonce/scope gate
- `plugins/ehr-harness/skills/ehr-harness/lib/merge.test.sh` — env gate, scope reserved 케이스

---

## Conventions (모든 task 공통)

**TDD 5-step 패턴**: 각 작업 단위는 (1) 실패 테스트 작성 → (2) FAIL 확인 → (3) 최소 구현 → (4) PASS 확인 → (5) 다음 작업 또는 stage 종료 시 commit.

**Atomic commit 단위**: stage 1개 = git commit 1개. stage 안의 작은 작업들은 working tree 에서만 누적, stage 끝에서 단일 commit.

**경량 가드 8종 (절대 위반 금지)**:
1. UserPromptSubmit hook stdout = 0 byte
2. SessionStart hook stdout ≤ 1024 byte JSON (jq -e 통과 필수)
3. AGENTS.md.skel 의 EHR-LESSONS 섹션 ≤ 1024 byte
4. SKILL.md (ehr-lessons / ehr-harness 둘 다) ≤ 15360 byte
5. `merge.sh::apply_staged` 가 `EHR_AUDIT_APPROVED=1` + 유효 nonce 없으면 exit 2
6. v4→v5 strict-append (jq spread, unknown field 보존)
7. Redaction 검사 미수행 또는 실패 record drop
8. plugin-dev scope cwd 검증 없으면 skel 수정 차단 (exit 4), org-template exit 5

**Hook silent skip 표준 헤더** (모든 hook 최상단):
```bash
#!/usr/bin/env bash
# stdout 침묵 (UserPromptSubmit) 또는 ≤1KB JSON (SessionStart)
# 모든 에러 경로 exit 0 (세션 차단 금지)
set +e

PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$(pwd)}"
HARNESS="$PROJECT_DIR/.claude/HARNESS.json"
LEARN_DIR="$PROJECT_DIR/.claude/learnings"
DEGRADED_FLAG="$PROJECT_DIR/.claude/.ehr-hook-degraded.flag"
ERR_LOG="$LEARN_DIR/errors.log"

# silent skip helpers
log_err() { mkdir -p "$LEARN_DIR" 2>/dev/null || return 0; printf '[%s] %s\n' "$(date -Iseconds 2>/dev/null || date)" "$1" >> "$ERR_LOG" 2>/dev/null || :; }
silent_exit() { exit 0; }

# pre-checks
[ -f "$HARNESS" ] || silent_exit
command -v jq >/dev/null 2>&1 || JQ_MISSING=1
```

**테스트 헤더 표준**:
```bash
#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"  # tests/ 안에 있을 경우; 평면이면 SCRIPT_DIR 그대로
FIXTURES="$LIB_DIR/fixtures"

PASS=0; FAIL=0
assert_eq()   { if [ "$1" = "$2" ]; then PASS=$((PASS+1)); else FAIL=$((FAIL+1)); echo "FAIL: expected [$2] got [$1] at $3"; fi; }
assert_match(){ if printf '%s' "$1" | grep -qE "$2"; then PASS=$((PASS+1)); else FAIL=$((FAIL+1)); echo "FAIL: [$1] !~ /$2/ at $3"; fi; }
assert_exit() { local actual=$1 expected=$2 where=$3; if [ "$actual" -eq "$expected" ]; then PASS=$((PASS+1)); else FAIL=$((FAIL+1)); echo "FAIL: exit $actual != $expected at $where"; fi; }

cleanup() { rm -rf "$TMP" 2>/dev/null || :; }
TMP="$(mktemp -d)"; trap cleanup EXIT

# ... test body ...

echo "PASS=$PASS FAIL=$FAIL"
[ "$FAIL" -eq 0 ]
```

**커밋 메시지 컨벤션**: 한국어 + Co-Authored-By. 본 plan 의 stage 별 커밋 제목은 §최종 커밋 리스트 참조.

---

## Stage 0: Repo 정리

**Goal:** v1.10 본 작업 진입 전 사전 구조 정리. CHANGELOG 신규, run-all.sh 신규, hook path migration, README 정정.

**Files:**
- Create: `plugins/ehr-harness/CHANGELOG.md`
- Create: `plugins/ehr-harness/skills/ehr-harness/lib/tests/run-all.sh`
- Modify: `README.md`, `plugins/ehr-harness/profiles/shared/settings.json`, `plugins/ehr-harness/profiles/shared/hooks/db-read-only.sh`, `plugins/ehr-harness/profiles/shared/hooks/vcs-no-commit.sh`

### Task 0.1: CHANGELOG.md 신규 생성

- [ ] **Step 1: 파일 생성** — Write `plugins/ehr-harness/CHANGELOG.md`:

```markdown
# Changelog

본 문서는 Keep a Changelog 형식을 따른다.
v1.10.0 부터 신규 릴리즈는 이 파일에 기록한다.
v1.9.x 이하 history 는 `README.md` 내 변경 이력 섹션 참조.

## [Unreleased]

### Added
- (placeholder)

## [1.10.0] — TBD (Stage 9 에서 채움)

### Added
- self-evolving 메커니즘 (런타임 capture + 배치 harvest + audit 승인)
- HARNESS_SCHEMA v5 (learnings_meta 필드)
- profile별 `ehr-lessons` skill (lazy-load, 검증 함수 명명 + 회신 템플릿)
- AGENTS.md.skel eager 지식 (분석 요청 프로토콜, EHR 운영 상수)
- correction harvester hook (UserPromptSubmit)
- preferences inject hook (SessionStart, CLAUDE_ENV_FILE + additionalContext)
- `/ehr-harvest-learnings` slash command
- PII redaction 라이브러리 + .claude/learnings/ gitignore 강제
- 경량 가드 8종 종합 테스트 (`harness-weight.test.sh`)

### Changed
- HARNESS.json schema v4 → v5 (자동 마이그레이션, strict-append)
- 기존 hooks 의 path 를 `$CLAUDE_PROJECT_DIR` 기준으로 마이그레이션

### Security
- raw 원문 sha256 금지, redacted normalized 기반으로 전환
- staged file nonce 검증 (sha256, lowercase hex 64)
- scope 격리 (project-local 기본, plugin-dev 는 cwd 검증, org-template reserved)
```

- [ ] **Step 2: 테스트 — 파일 존재 + 핵심 섹션** — README 가 아직 stale 이라 회귀 테스트는 별도. CHANGELOG 자체 검증:

```bash
test -f plugins/ehr-harness/CHANGELOG.md && \
  grep -q '^## \[1.10.0\]' plugins/ehr-harness/CHANGELOG.md && \
  echo OK
```

Expected: `OK`

### Task 0.2: README.md 버전 stale 정정

- [ ] **Step 1: 현재 README 버전 문구 검색**

```bash
grep -nE '(v1\.8|v1\.9\.[0-4])' README.md | head -10
```

- [ ] **Step 2: 정정** — `현재 릴리즈: v1.x.x` 같은 stale 라인을 찾아 다음 패턴으로 교체:

```markdown
> **현재 릴리즈**: v1.10.0 (2026-04-25)
> 자세한 변경 이력은 [`plugins/ehr-harness/CHANGELOG.md`](plugins/ehr-harness/CHANGELOG.md) 참조.
> v1.9.x 이하 history 는 본 README 의 변경 이력 섹션에 그대로 보존된다.
```

(실제 stale 줄이 발견되지 않으면 README 상단 메타 영역에 위 블록 추가.)

- [ ] **Step 3: 검증**

```bash
grep -q 'v1.10.0' README.md && grep -q 'CHANGELOG.md' README.md && echo OK
```

Expected: `OK`

### Task 0.3: tests/run-all.sh 신규 생성

- [ ] **Step 1: 파일 생성** — Write `plugins/ehr-harness/skills/ehr-harness/lib/tests/run-all.sh`:

```bash
#!/usr/bin/env bash
# Integrated test runner for ehr-harness lib.
# Discovers all *.test.sh under lib/ (excluding node_modules) and runs them.
set -uo pipefail

LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROJECT_ROOT="$(cd "$LIB_DIR/../../../.." && pwd)"

PASS=0; FAIL=0; FAILED_FILES=()

# 평면 lib/*.test.sh + tests/*.test.sh 모두 수집
mapfile -t FILES < <(find "$LIB_DIR" -maxdepth 2 -name '*.test.sh' -type f | sort)

for f in "${FILES[@]}"; do
  echo "=== $f ==="
  if bash "$f"; then
    PASS=$((PASS+1))
  else
    FAIL=$((FAIL+1))
    FAILED_FILES+=("$f")
  fi
done

echo "------------------------------------------------------------"
echo "Total: $((PASS+FAIL))  Pass: $PASS  Fail: $FAIL"
if [ "$FAIL" -gt 0 ]; then
  echo "Failed files:"
  printf '  - %s\n' "${FAILED_FILES[@]}"
  exit 1
fi
exit 0
```

- [ ] **Step 2: 실행 권한**

```bash
chmod +x plugins/ehr-harness/skills/ehr-harness/lib/tests/run-all.sh
```

- [ ] **Step 3: 회귀 검증 — 기존 13개 테스트 모두 통과 확인**

```bash
bash plugins/ehr-harness/skills/ehr-harness/lib/tests/run-all.sh
```

Expected: `Total: 13  Pass: 13  Fail: 0` (Stage 0 시점, 신규 테스트 0개)

### Task 0.4: 기존 hook path migration ($CLAUDE_PROJECT_DIR)

- [ ] **Step 1: 현재 settings.json hook 블록 백업 출력**

```bash
cat plugins/ehr-harness/profiles/shared/settings.json
```

- [ ] **Step 2: settings.json 갱신** — Write `plugins/ehr-harness/profiles/shared/settings.json`:

```json
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Bash",
        "hooks": [
          {
            "type": "command",
            "command": "bash \"$CLAUDE_PROJECT_DIR/.claude/hooks/db-read-only.sh\"",
            "timeout": 3
          },
          {
            "type": "command",
            "command": "bash \"$CLAUDE_PROJECT_DIR/.claude/hooks/vcs-no-commit.sh\"",
            "timeout": 3
          }
        ]
      }
    ]
  }
}
```

(UserPromptSubmit, SessionStart 블록은 Stage 3, 4 에서 추가.)

- [ ] **Step 3: 기존 hook 2개 헤더에 PROJECT_DIR fallback 추가** — `db-read-only.sh` 최상단 (#!/usr/bin/env bash 다음 줄) 에 다음 한 줄 삽입:

```bash
PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$(pwd)}"
```

`vcs-no-commit.sh` 동일.

- [ ] **Step 4: 회귀 — `hooks.test.sh` 가 새 path 형식에서도 통과해야 함**

```bash
bash plugins/ehr-harness/profiles/shared/hooks/hooks.test.sh
```

Expected: `PASS=N FAIL=0`

만약 기존 테스트가 상대경로 가정으로 깨지면, 테스트 안의 path 비교 로직을 `$CLAUDE_PROJECT_DIR` 인식하도록 수정 (회귀 0 원칙 — 테스트도 같이 갱신).

### Task 0.5: Stage 0 commit

- [ ] **Step 1: 변경 검토**

```bash
git status
git diff --stat
```

- [ ] **Step 2: commit**

```bash
git add plugins/ehr-harness/CHANGELOG.md README.md \
        plugins/ehr-harness/profiles/shared/settings.json \
        plugins/ehr-harness/profiles/shared/hooks/db-read-only.sh \
        plugins/ehr-harness/profiles/shared/hooks/vcs-no-commit.sh \
        plugins/ehr-harness/skills/ehr-harness/lib/tests/run-all.sh

git commit -m "$(cat <<'EOF'
chore(repo): v1.10 사전 구조 정리

- plugins/ehr-harness/CHANGELOG.md 신규 (Keep a Changelog)
- README.md 버전 stale 정정 + CHANGELOG 링크
- skills/ehr-harness/lib/tests/run-all.sh 신규 (통합 runner)
- shared/settings.json hook path 를 \$CLAUDE_PROJECT_DIR 기준으로 마이그레이션
- 기존 db-read-only.sh / vcs-no-commit.sh 헤더에 PROJECT_DIR fallback

회귀: 기존 13개 테스트 통과 (run-all.sh 로 검증).

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Stage 1: Schema v5 Migration (jq spread + unknown field 보존)

**Goal:** HARNESS.json v4 → v5 자동 마이그레이션 (strict-append). v5 의 신규 필드는 `ehr_cycle.learnings_meta` 1개. 기존 필드 sha256 변경 시 rollback. 

**Files:**
- Create: `plugins/ehr-harness/skills/ehr-harness/lib/fixtures/learnings/harness-v4-baseline.json`
- Modify: `plugins/ehr-harness/skills/ehr-harness/lib/HARNESS_SCHEMA.md`, `harness-state.sh`, `harness-state.test.sh`

### Task 1.1: HARNESS_SCHEMA.md v5 섹션 추가

- [ ] **Step 1: 현재 schema doc tail 확인**

```bash
tail -30 plugins/ehr-harness/skills/ehr-harness/lib/HARNESS_SCHEMA.md
```

- [ ] **Step 2: v5 섹션 append** — 파일 끝에 다음 섹션 추가:

```markdown

## Schema (version 5) — Learnings Meta 도입

v4 와의 차이는 `ehr_cycle.learnings_meta` 1개 객체 추가뿐. 기존 v4 필드는 모두 그대로 보존된다 (strict-append).

### `ehr_cycle.learnings_meta`

```json
{
  "ehr_cycle": {
    "compounds": [],
    "promoted": [],
    "preferences_history": [],
    "learnings_meta": {
      "last_harvest_at": null,
      "pending_count": 0,
      "promoted_count": 0,
      "rejected_count": 0,
      "staged_nonces": {},
      "promotion_policy": {
        "success_weight": 2,
        "correction_weight": 1,
        "threshold": 3,
        "distinct_sessions_min": 2,
        "same_session_cap": 2
      },
      "capture_enabled": true
    }
  }
}
```

| 필드 | 의미 |
|---|---|
| `last_harvest_at` | 마지막 `/ehr-harvest-learnings` 실행 시각. null = 한 번도 안 돌렸음. |
| `pending_count` / `promoted_count` / `rejected_count` | 누적 카운터. canonical hash 에서 제외 (volatile). |
| `staged_nonces` | `{topic: sha256_hex}`. merge 시 검증. canonical hash 제외. |
| `promotion_policy` | scoring 설정. canonical hash 포함 (설정값). |
| `capture_enabled` | false 면 capture hook 이 silent skip. canonical hash 포함. |

### Canonical hash 산정 시 제외 필드

```jq
del(
  .schema_version,
  .ehr_cycle.learnings_meta.last_harvest_at,
  .ehr_cycle.learnings_meta.pending_count,
  .ehr_cycle.learnings_meta.promoted_count,
  .ehr_cycle.learnings_meta.rejected_count,
  .ehr_cycle.learnings_meta.staged_nonces
)
```

### v4 → v5 마이그레이션 알고리즘

`harness-state.sh::ehr_state_migrate_v4_to_v5(path)` 가 6단계로 처리:

1. 백업: `.ehr-bak/harness-v4-${ts}.json`
2. jq spread 로 **unknown field 보존** + `learnings_meta` 추가
3. schema validation (`schema_version == 5 && .ehr_cycle.learnings_meta != null`)
4. unknown field 보존 검증 — `del(.schema_version, .ehr_cycle.learnings_meta)` 결과가 v4 와 동일한지 diff
5. canonical hash 갱신 (위 제외 필드 기준)
6. 원자 교체 (`mv tmp -> path`). 실패 시 백업 복원 + `migration-failed.log` + v4 fallback.
```

- [ ] **Step 3: 검증**

```bash
grep -q '^## Schema (version 5)' plugins/ehr-harness/skills/ehr-harness/lib/HARNESS_SCHEMA.md && echo OK
```

Expected: `OK`

### Task 1.2: fixture v4-baseline.json 작성

- [ ] **Step 1: 파일 생성** — Write `plugins/ehr-harness/skills/ehr-harness/lib/fixtures/learnings/harness-v4-baseline.json`:

```json
{
  "schema_version": 4,
  "plugin_name": "ehr-harness",
  "plugin_version": "1.9.5",
  "profile": "ehr4",
  "generated_at": "2026-04-15T12:00:00+09:00",
  "updated_at": "2026-04-20T09:30:00+09:00",
  "sources": {"profiles/shared/settings.json": "sha256:aaa"},
  "outputs": {".claude/settings.json": "sha256:bbb", "AGENTS.md": "sha256:ccc"},
  "auth_model": {
    "common_controllers": ["GetDataList", "SaveData"],
    "auth_service_class": "AuthTableService",
    "auth_injection_methods": ["query_placeholder"],
    "auth_tables": ["THRM151_AUTH"],
    "auth_functions": ["F_COM_GET_SQL_AUTH"],
    "session_vars": ["ssnEnterCd", "ssnSabun"]
  },
  "db_verification": {"ddl_path": null, "db_access": "available", "b3_strategy": "db-only"},
  "ddl_authoring": {"enabled": false, "table_path": null, "procedure_path": null, "function_path": null, "naming_pattern": null, "header_template_path": null, "existing_tables": []},
  "analysis": {
    "analyzed_at": "2026-04-15T14:23:01+09:00",
    "module_map": [{"name": "hrm", "file_count": 120}],
    "session_vars": ["ssnEnterCd", "ssnSabun"],
    "authSqlID": ["THRM151"],
    "law_counts": {"A_direct_controller": 45, "B_getData": 79, "B_saveData": 68, "C_hybrid": 12, "D_execPrc": 15},
    "critical_proc_found": ["P_HRM_POST"],
    "critical_proc_missing": [],
    "procedure_count": 234,
    "procedure_sample": ["P_HRM_POST"],
    "trigger_count": 18
  },
  "ehr_cycle": {
    "compounds": [{"id": "paycalc-trigger", "ts": "2026-04-18T10:00:00+09:00", "revision": 1}],
    "promoted": [],
    "preferences_history": [{"ts": "2026-04-19T11:00:00+09:00", "key": "SUGGEST_MODE", "from": "ask", "to": "silent"}]
  },
  "x_unknown_field_for_strict_append_test": "must-be-preserved"
}
```

마지막 `x_unknown_field_for_strict_append_test` 가 핵심 — strict-append 가 정상 동작하면 v5 에서도 그대로 남아있어야 함.

### Task 1.3: harness-state.sh::ehr_state_migrate_v4_to_v5 구현

- [ ] **Step 1: 테스트 먼저 작성** — `harness-state.test.sh` 끝에 다음 케이스 추가:

```bash
# === v4 → v5 migration ===
tdir="$TMP/migration"
mkdir -p "$tdir"
cp "$FIXTURES/learnings/harness-v4-baseline.json" "$tdir/HARNESS.json"

# source the lib
# shellcheck disable=SC1091
. "$LIB_DIR/harness-state.sh"

ehr_state_migrate_v4_to_v5 "$tdir/HARNESS.json"
mig_rc=$?
assert_exit "$mig_rc" 0 "migration exit"

# schema_version bumped
sv=$(jq -r .schema_version "$tdir/HARNESS.json")
assert_eq "$sv" "5" "schema_version"

# learnings_meta exists with defaults
cap=$(jq -r .ehr_cycle.learnings_meta.capture_enabled "$tdir/HARNESS.json")
assert_eq "$cap" "true" "capture_enabled default"

th=$(jq -r .ehr_cycle.learnings_meta.promotion_policy.threshold "$tdir/HARNESS.json")
assert_eq "$th" "3" "threshold default"

# unknown top-level field preserved
xu=$(jq -r .x_unknown_field_for_strict_append_test "$tdir/HARNESS.json")
assert_eq "$xu" "must-be-preserved" "unknown field preserved"

# ehr_cycle subfields preserved
cmp_id=$(jq -r '.ehr_cycle.compounds[0].id' "$tdir/HARNESS.json")
assert_eq "$cmp_id" "paycalc-trigger" "compounds preserved"

pref_to=$(jq -r '.ehr_cycle.preferences_history[0].to' "$tdir/HARNESS.json")
assert_eq "$pref_to" "silent" "preferences_history preserved"

# backup file created
ls "$tdir/.ehr-bak/" 2>/dev/null | grep -q '^harness-v4-' && assert_eq "yes" "yes" "backup created" \
  || assert_eq "no" "yes" "backup created"

# === idempotency: 재실행 시 v5 그대로 유지 (no double-migration) ===
ehr_state_migrate_v4_to_v5 "$tdir/HARNESS.json"
sv2=$(jq -r .schema_version "$tdir/HARNESS.json")
assert_eq "$sv2" "5" "idempotent v5"
```

- [ ] **Step 2: 테스트 실행 — FAIL 확인**

```bash
bash plugins/ehr-harness/skills/ehr-harness/lib/harness-state.test.sh
```

Expected: FAIL — `ehr_state_migrate_v4_to_v5: command not found`

- [ ] **Step 3: 구현** — `harness-state.sh` 끝에 다음 함수 추가:

```bash
# === v4 → v5 migration (Stage 1) ===
# Strict-append: schema_version 만 5로 올리고 learnings_meta 추가.
# 기존 필드 (unknown 포함) 모두 보존.
# Args: $1 = HARNESS.json path
# Returns: 0 ok / 1 already-v5 / 2 fatal
ehr_state_migrate_v4_to_v5() {
  local path="$1"
  local proj_dir; proj_dir="$(dirname "$path")"
  local bak_dir="$proj_dir/.ehr-bak"
  local ts; ts="$(date +%Y%m%dT%H%M%S 2>/dev/null || date)"

  [ -f "$path" ] || return 2
  command -v jq >/dev/null 2>&1 || return 2

  local sv; sv=$(jq -r '.schema_version // 0' "$path" 2>/dev/null)
  if [ "$sv" = "5" ]; then return 0; fi  # idempotent
  if [ "$sv" != "4" ]; then return 0; fi  # 다른 버전은 본 함수 미적용

  # 1. 백업
  mkdir -p "$bak_dir" || return 2
  cp "$path" "$bak_dir/harness-v4-${ts}.json" || return 2

  # 2. jq spread — unknown field 보존
  local tmp="${path}.v5tmp"
  jq '
    .schema_version = 5
    | .ehr_cycle = (.ehr_cycle // {})
    | .ehr_cycle.learnings_meta = (
        .ehr_cycle.learnings_meta // {
          "last_harvest_at": null,
          "pending_count": 0,
          "promoted_count": 0,
          "rejected_count": 0,
          "staged_nonces": {},
          "promotion_policy": {
            "success_weight": 2,
            "correction_weight": 1,
            "threshold": 3,
            "distinct_sessions_min": 2,
            "same_session_cap": 2
          },
          "capture_enabled": true
        }
      )
  ' "$path" > "$tmp" || { rm -f "$tmp"; return 2; }

  # 3. schema validation
  jq -e '.schema_version == 5 and .ehr_cycle.learnings_meta != null' "$tmp" >/dev/null || {
    rm -f "$tmp"
    cp "$bak_dir/harness-v4-${ts}.json" "$path"
    printf '[migration-failed] schema validation\n' >> "$bak_dir/migration-failed.log"
    return 2
  }

  # 4. unknown field 보존 검증 — 제외 필드 빼고 동일해야 함
  local before after
  before=$(jq -S 'del(.schema_version, .ehr_cycle.learnings_meta)' "$path")
  after=$(jq -S  'del(.schema_version, .ehr_cycle.learnings_meta)' "$tmp")
  if [ "$before" != "$after" ]; then
    rm -f "$tmp"
    cp "$bak_dir/harness-v4-${ts}.json" "$path"
    printf '[migration-failed] strict-append violation\n' >> "$bak_dir/migration-failed.log"
    return 2
  fi

  # 5. canonical hash 는 호출자가 갱신 (본 함수는 데이터만)
  # 6. 원자 교체
  mv "$tmp" "$path" || return 2
  return 0
}
```

- [ ] **Step 4: 테스트 PASS 확인**

```bash
bash plugins/ehr-harness/skills/ehr-harness/lib/harness-state.test.sh
```

Expected: 모든 추가 케이스 PASS, 기존 케이스도 PASS, `PASS=N FAIL=0`.

- [ ] **Step 5: 회귀**

```bash
bash plugins/ehr-harness/skills/ehr-harness/lib/tests/run-all.sh
```

Expected: 13 PASS (Stage 1 시점, 기존 13개 + harness-state 의 신규 케이스 추가됐지만 같은 파일이라 13건 그대로).

### Task 1.4: Stage 1 commit

- [ ] **Step 1: commit**

```bash
git add plugins/ehr-harness/skills/ehr-harness/lib/HARNESS_SCHEMA.md \
        plugins/ehr-harness/skills/ehr-harness/lib/harness-state.sh \
        plugins/ehr-harness/skills/ehr-harness/lib/harness-state.test.sh \
        plugins/ehr-harness/skills/ehr-harness/lib/fixtures/learnings/harness-v4-baseline.json

git commit -m "$(cat <<'EOF'
feat(schema): v4→v5 자동 마이그레이션 (strict-append)

- HARNESS_SCHEMA.md v5 섹션 추가 (learnings_meta 정의)
- harness-state.sh::ehr_state_migrate_v4_to_v5() 구현
  - jq spread 로 unknown field 보존
  - schema validation + 보존 검증 (diff 기반)
  - 백업 + 실패 시 rollback
  - idempotent (v5 재호출 무동작)
- fixture harness-v4-baseline.json (unknown field 포함)
- harness-state.test.sh: migration / unknown 보존 / idempotency / backup 검증

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Stage 2: Privacy-First Capture Foundation

**Goal:** PII redaction 라이브러리 + `.claude/learnings/` gitignore 강제 + capture pre-flight 검사. 이 단계는 hook 보다 먼저 — 뒤이은 capture hook 이 항상 redaction 통과한 record 만 저장하도록 토대 마련.

**Files:**
- Create: `plugins/ehr-harness/skills/ehr-harness/lib/redaction.sh`
- Create: `plugins/ehr-harness/skills/ehr-harness/lib/redaction.test.sh`
- Create: `plugins/ehr-harness/skills/ehr-harness/lib/fixtures/redaction-cases.txt`

### Task 2.1: redaction-cases fixture 작성

- [ ] **Step 1: 파일 생성** — Write `plugins/ehr-harness/skills/ehr-harness/lib/fixtures/redaction-cases.txt`:

```
# Format: <expected_count>\t<input>\t<expected_output_pattern>
# expected_count = redaction 횟수 (정수)
# expected_output_pattern = grep -E 패턴 (출력에 PII 잔존 없어야 함을 검증)
2	20236 출산휴가 검증해줘 2026-04-21 시작	\[ID\].*\[DATE\]
1	사번 12345 의 데이터 조회	\[ID\]
1	이윤정 책임에게 전달	\[NAME\]
2	박철수 수석이 2026-03-15 작성	\[NAME\].*\[DATE\]
1	조직코드 HRM001 권한	\[ORG\]
0	JSP만 수정해줘	^JSP만 수정해줘$
0	이 방향으로 확정	^이 방향으로 확정$
0	아니 다시 해줘	^아니 다시 해줘$
3	20207 사번이 2026-04-19 김민수 책임에게	\[ID\].*\[DATE\].*\[NAME\]
1	2026-04-25	\[DATE\]
1	2026-04-25T14:30:00	\[DATE\]
1	yyyy-mm-dd 형식 2026/04/25 도	\[DATE\]
0	checkMatLeave() 함수로 통합	^checkMatLeave\(\) 함수로 통합$
0	그룹웨어 배치 시점은	^그룹웨어 배치 시점은$
1	TBL_THRM151_AUTH 테이블	\[ORG\]
```

(각 줄은 `count<TAB>input<TAB>pattern`. count=0 은 PII 없음 = redaction 미발생. 이 fixture 는 v1.10 핵심 가드 7 검증.)

### Task 2.2: redaction.sh 구현 (TDD)

- [ ] **Step 1: 실패 테스트 — `redaction.test.sh` 신규**

```bash
#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB_DIR="$SCRIPT_DIR"
FIXTURES="$LIB_DIR/fixtures"

# shellcheck disable=SC1091
. "$LIB_DIR/redaction.sh"

PASS=0; FAIL=0
assert_eq() { if [ "$1" = "$2" ]; then PASS=$((PASS+1)); else FAIL=$((FAIL+1)); echo "FAIL: expected [$2] got [$1] at $3"; fi; }
assert_match(){ if printf '%s' "$1" | grep -qE "$2"; then PASS=$((PASS+1)); else FAIL=$((FAIL+1)); echo "FAIL: [$1] !~ /$2/ at $3"; fi; }

while IFS=$'\t' read -r expected_count input expected_pattern; do
  case "$expected_count" in ''|'#'*) continue ;; esac
  out=$(ehr_redact "$input")
  cnt=$(printf '%s\n' "$out" | grep -oE '\[(ID|NAME|DATE|ORG)\]' | wc -l | tr -d ' ')
  assert_eq "$cnt" "$expected_count" "count for [$input]"
  if [ "$expected_count" = "0" ]; then
    # PII 없는 입력은 출력이 입력과 동일해야 함
    assert_eq "$out" "$input" "no-op for [$input]"
  else
    assert_match "$out" "$expected_pattern" "pattern for [$input]"
  fi
done < "$FIXTURES/redaction-cases.txt"

# === ehr_redact_meta: redaction_count + redaction_failed 분리 ===
meta=$(ehr_redact_meta "20236 출산휴가 2026-04-21")
checked=$(printf '%s' "$meta" | jq -r .redaction_checked)
count=$(printf '%s' "$meta" | jq -r .redaction_count)
failed=$(printf '%s' "$meta" | jq -r .redaction_failed)
assert_eq "$checked" "true" "meta.redaction_checked"
assert_eq "$count" "2" "meta.redaction_count"
assert_eq "$failed" "false" "meta.redaction_failed"

# PII 없는 record 도 checked=true, count=0, failed=false (drop 되지 않아야 함)
meta2=$(ehr_redact_meta "JSP만 수정해줘")
c2=$(printf '%s' "$meta2" | jq -r .redaction_count)
chk2=$(printf '%s' "$meta2" | jq -r .redaction_checked)
assert_eq "$c2" "0" "no-PII count=0"
assert_eq "$chk2" "true" "no-PII still checked"

echo "PASS=$PASS FAIL=$FAIL"
[ "$FAIL" -eq 0 ]
```

- [ ] **Step 2: 실행 — FAIL 확인**

```bash
bash plugins/ehr-harness/skills/ehr-harness/lib/redaction.test.sh
```

Expected: `redaction.sh: No such file or directory`

- [ ] **Step 3: 구현** — Write `plugins/ehr-harness/skills/ehr-harness/lib/redaction.sh`:

```bash
#!/usr/bin/env bash
# PII redaction library.
# 정규식 기반: 사번 [ID], 한글 이름+직책 [NAME], 날짜 [DATE], 조직코드 [ORG].
# 본 라이브러리는 한국 EHR/HR 도메인 특화. v1.11+ 에서 Microsoft Presidio 등으로 교체 가능.

# === 정규식 ===
# 사번: 5~8자리 연속 숫자 (전후 word boundary)
EHR_RE_ID='([^0-9A-Za-z가-힣]|^)([0-9]{5,8})([^0-9A-Za-z가-힣]|$)'
# 한글 이름 (2~4자) + 직책
EHR_RE_NAME='([가-힣]{2,4})\s?(님|책임|수석|선임|대리|과장|차장|부장|팀장|매니저|연구원|전문위원)'
# 날짜: YYYY-MM-DD, YYYY/MM/DD, YYYYMMDD, ISO 8601 (T 포함)
EHR_RE_DATE='([0-9]{4}[-/.][0-9]{1,2}[-/.][0-9]{1,2}(T[0-9:]+)?)'
# 조직코드: 대문자 prefix + 영숫자 (3+ 글자), HRM001 / TBL_THRM151_AUTH 등
EHR_RE_ORG='(TBL_)?(THRM[0-9]+|HRM[0-9]+|CPN[0-9]+|TIM[0-9]+|EDU[0-9]+|LF[0-9]+)(_[A-Z]+)?'

# === 공개 함수 ===

# ehr_redact: 입력 텍스트의 PII 를 [TAG] 로 치환해 출력.
# Usage: out=$(ehr_redact "raw text")
ehr_redact() {
  local s="$1"
  # 순서: ORG → DATE → NAME → ID (덜 specific 한 ID 를 마지막에)
  s=$(printf '%s' "$s" | sed -E "s#${EHR_RE_ORG}#[ORG]#g")
  s=$(printf '%s' "$s" | sed -E "s#${EHR_RE_DATE}#[DATE]#g")
  s=$(printf '%s' "$s" | sed -E "s#${EHR_RE_NAME}#[NAME]#g")
  # ID: 전후 boundary 보존하면서 숫자만 치환
  s=$(printf '%s' "$s" | sed -E "s#${EHR_RE_ID}#\1[ID]\3#g")
  printf '%s' "$s"
}

# ehr_redact_meta: redaction 결과를 메타데이터 JSON 으로 반환.
# Output: {"redaction_checked": true, "redaction_count": N, "redaction_failed": false}
ehr_redact_meta() {
  local input="$1"
  local out
  if ! out=$(ehr_redact "$input" 2>/dev/null); then
    printf '{"redaction_checked":true,"redaction_count":0,"redaction_failed":true}\n'
    return 0
  fi
  local count
  count=$(printf '%s\n' "$out" | grep -oE '\[(ID|NAME|DATE|ORG)\]' | wc -l | tr -d ' ')
  printf '{"redaction_checked":true,"redaction_count":%s,"redaction_failed":false}\n' "$count"
}

# ehr_redact_should_drop: 메타데이터 JSON 받아 drop 여부 결정.
# Drop 조건: redaction_checked != true OR redaction_failed == true.
# (count == 0 인 정상 record 는 유지)
ehr_redact_should_drop() {
  local meta="$1"
  command -v jq >/dev/null 2>&1 || { echo true; return 0; }
  local checked failed
  checked=$(printf '%s' "$meta" | jq -r '.redaction_checked // false')
  failed=$(printf '%s' "$meta"  | jq -r '.redaction_failed  // true')
  if [ "$checked" != "true" ] || [ "$failed" = "true" ]; then
    echo true
  else
    echo false
  fi
}
```

- [ ] **Step 4: PASS 확인**

```bash
bash plugins/ehr-harness/skills/ehr-harness/lib/redaction.test.sh
```

Expected: 모든 fixture 케이스 통과, `PASS=N FAIL=0`.

### Task 2.3: gitignore 자동 추가 로직

- [ ] **Step 1: update.sh 위치 확인** — 만약 별도 update 스크립트가 있다면 그곳, 없으면 SKILL.md 의 update 흐름에 통합.

```bash
ls plugins/ehr-harness/skills/ehr-harness/lib/ | grep -i 'update\|update' || echo "update.sh 없음"
```

- [ ] **Step 2: SKILL.md update 흐름에 한 줄 추가** — `plugins/ehr-harness/skills/ehr-harness/SKILL.md` 의 "Step 4-I" (커맨드/skeleton 생성) 섹션 직후에 다음 step 삽입:

```markdown
### Step 4-J. .gitignore 자동 추가 (v1.10+)

생성/업데이트 마지막에 프로젝트 `.gitignore` 검사:

1. `.gitignore` 가 존재하지 않으면 생성.
2. 다음 라인이 없으면 추가:
   ```
   # ehr-harness self-evolving learnings (do not commit)
   .claude/learnings/
   .claude/.ehr-hook-degraded.flag
   ```
3. 추가했으면 사용자에게 알림: "프로젝트 .gitignore 에 self-evolving 캡처 디렉토리를 추가했습니다."
4. 이미 있으면 침묵.

**가드 7 + Stage 2 fail-safe**: hook 이 capture 시 이 항목들이 .gitignore 에 없으면 silent skip. 따라서 본 step 이 누락되면 self-evolving 기능 자체가 비활성. SKILL.md update 흐름에서 항상 실행.
```

- [ ] **Step 3: 검증**

```bash
grep -q 'Step 4-J' plugins/ehr-harness/skills/ehr-harness/SKILL.md && echo OK
```

Expected: `OK`

### Task 2.4: Stage 2 commit

```bash
git add plugins/ehr-harness/skills/ehr-harness/lib/redaction.sh \
        plugins/ehr-harness/skills/ehr-harness/lib/redaction.test.sh \
        plugins/ehr-harness/skills/ehr-harness/lib/fixtures/redaction-cases.txt \
        plugins/ehr-harness/skills/ehr-harness/SKILL.md

git commit -m "$(cat <<'EOF'
feat(privacy): PII redaction + .gitignore 강제 (Phase 2)

- redaction.sh: ehr_redact / ehr_redact_meta / ehr_redact_should_drop
  - 사번 [ID], 한글 이름+직책 [NAME], 날짜 [DATE], 조직코드 [ORG]
  - meta 분리: redaction_checked / count / failed (PII 없는 정상 record 유지)
- fixture redaction-cases.txt (15 케이스)
- SKILL.md Step 4-J: .gitignore 자동 추가 (.claude/learnings/, .ehr-hook-degraded.flag)

가드 7 (redaction 검사 미수행/실패 시 drop) 의 토대.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Stage 3: UserPromptSubmit Capture Hook (Phase A)

**Goal:** 사용자 발화에서 correction/success 신호 감지 → redaction 통과 → `pending.jsonl` append. stdout = 0 byte.

**Files:**
- Create: `learnings.sh`, `learnings.test.sh`, `user-prompt-capture.sh`, `user-prompt-capture.test.sh`
- Create: fixtures `prompts-ko.txt`, `prompts-en.txt`, `prompts-excluded.txt`

### Task 3.1: heuristic fixture 작성

- [ ] **Step 1: prompts-ko.txt** — 20 케이스, format: `<expected_kind>\t<input>` (`success`/`correction`/`none`):

```
success	좋아 이 방향으로 확정해줘
success	딱 그거야 진행
success	정확한 진단이네
success	완벽해 다음 단계로
success	이 방식 맞아 적용하자
success	확정 ship it
success	좋습니다 그렇게 가시죠
success	맞아 그게 정확함
correction	아니 그거 말고 다시
correction	다시 해줘 잘못된거 같아
correction	수정해줘 그 부분 틀렸어
correction	롤백해 이전 버전으로
correction	그거 빼고 다시
correction	없애줘 그 변수
correction	아니라고 다시 봐
correction	되돌려줘 원래대로
none	JSP만 수정해줘
none	그룹웨어 배치 시점은 언제야
none	checkMatLeave 함수 통합 검토
none	대출이자 계산 로직 분석
```

- [ ] **Step 2: prompts-en.txt** — 영어 케이스:

```
success	perfect ship it
success	exactly that, confirmed
success	looks right, lgtm
success	good, that works
correction	no, undo that
correction	revert that change
correction	wrong file, go back
correction	cancel, that's not it
none	check the file structure
none	what does P_HRM_POST do
```

- [ ] **Step 3: prompts-excluded.txt** — false positive 방지 (heuristic 매칭 됐어도 무시되어야 하는 케이스):

```
# 길이 < 3
좋
ok
# URL 만
https://example.com/좋아
# 짧은 명령어
git diff
# 길이 > 500 → 시그널 노이즈로 간주
좋아 그런데 이거 봐 정말 길게 쓰면 좋아 같은 단어가 우연히 들어갈 수 있고 그러면 false positive 가 발생하니까 길이 상한을 두는 게 안전한 방향이고 사용자가 일부러 의도한 학습 신호가 아니라 그냥 긴 컨텍스트 설명 안에 우연히 들어간 단어이기 때문에 noise 로 보고 무시하는 게 맞는 방향이고 이런식으로 길이가 충분히 길어지면 매칭이 무시되어야 한다는 사실을 검증하기 위한 fixture 로 충분히 길게 작성된 문장이고 길이 상한을 500자로 잡았으므로 이 문장은 그 이상이 되도록 더 길게 늘려서 작성한다 추가로 더 길게 만들기 위해 한 두 문장 더 붙여서 일정 길이를 확실히 넘기도록 한다 충분히 넘었다고 본다.
```

### Task 3.2: learnings.sh 의 ehr_classify_signal() 구현 (TDD)

- [ ] **Step 1: 실패 테스트** — Write `plugins/ehr-harness/skills/ehr-harness/lib/learnings.test.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB_DIR="$SCRIPT_DIR"
FIXTURES="$LIB_DIR/fixtures"

# shellcheck disable=SC1091
. "$LIB_DIR/learnings.sh"

PASS=0; FAIL=0
assert_eq() { if [ "$1" = "$2" ]; then PASS=$((PASS+1)); else FAIL=$((FAIL+1)); echo "FAIL: expected [$2] got [$1] at $3"; fi; }

# === ehr_classify_signal ===
classify_one() {
  local kind input expected
  while IFS=$'\t' read -r expected input; do
    case "$expected" in ''|'#'*) continue ;; esac
    kind=$(ehr_classify_signal "$input")
    assert_eq "$kind" "$expected" "classify [$input]"
  done < "$1"
}
classify_one "$FIXTURES/prompts-ko.txt"
classify_one "$FIXTURES/prompts-en.txt"

# excluded — 모두 'none' 이어야 함 (길이/URL 등으로 무시)
while IFS= read -r line; do
  case "$line" in ''|'#'*) continue ;; esac
  kind=$(ehr_classify_signal "$line")
  assert_eq "$kind" "none" "excluded [$line]"
done < "$FIXTURES/prompts-excluded.txt"

# === score 계산 ===
assert_eq "$(ehr_score_for_kind success)" "2" "score success"
assert_eq "$(ehr_score_for_kind correction)" "1" "score correction"
assert_eq "$(ehr_score_for_kind none)" "0" "score none"

# === ehr_learn_should_capture ===
TMP="$(mktemp -d)"
mkdir -p "$TMP/.claude"
echo '{"schema_version":5,"ehr_cycle":{"learnings_meta":{"capture_enabled":true}}}' > "$TMP/.claude/HARNESS.json"
echo '.claude/learnings/' > "$TMP/.gitignore"
( export CLAUDE_PROJECT_DIR="$TMP"
  out=$(ehr_learn_should_capture && echo yes || echo no)
  assert_eq "$out" "yes" "should_capture ok" )

# gitignore 미적용 → 거부 + flag 생성
rm "$TMP/.gitignore"
( export CLAUDE_PROJECT_DIR="$TMP"
  out=$(ehr_learn_should_capture && echo yes || echo no)
  assert_eq "$out" "no" "should_capture refuse no-gitignore"
  test -f "$TMP/.claude/.ehr-hook-degraded.flag"
  assert_eq "$?" "0" "degraded flag created" )

rm -rf "$TMP"
echo "PASS=$PASS FAIL=$FAIL"
[ "$FAIL" -eq 0 ]
```

- [ ] **Step 2: 실행 — FAIL 확인**

Expected: `learnings.sh: No such file or directory`.

- [ ] **Step 3: 구현** — Write `plugins/ehr-harness/skills/ehr-harness/lib/learnings.sh`:

```bash
#!/usr/bin/env bash
# Self-evolving learnings library.
# - ehr_classify_signal: heuristic 매칭 (한국어 + 영어, word-boundary POSIX 대안)
# - ehr_score_for_kind: success=2 / correction=1 / none=0
# - ehr_learn_should_capture: gitignore 강제 + capture_enabled 검사
# - ehr_learn_append: pending.jsonl append (호출자가 redaction 완료 record 전달)

# === 어휘 ===
# 한국어 word-boundary 대안: 좌우 모두 한글/영숫자가 아닌 문자 또는 line edge
KO_BOUND='([^가-힣A-Za-z0-9]|^)'
KO_BOUND_R='([^가-힣A-Za-z0-9]|$)'

# success 어휘 (한국어)
EHR_LEX_SUCCESS_KO='(좋아|딱 그거|이 방향|확정|좋습니다|맞아|정확|완벽|됐어|이 방식)'
# correction 어휘 (한국어)
EHR_LEX_CORR_KO='(아니|다시|그거 말고|수정해줘|고쳐|잘못|틀렸|되돌려|롤백|빼고|없애|아니라고)'
# 영어 (대소문자 무시)
EHR_LEX_SUCCESS_EN='(perfect|exactly|confirmed|looks right|ship it|lgtm|good[, ])'
EHR_LEX_CORR_EN='(no[,. ]|undo|revert|wrong|that.s not|nope|go back|cancel)'

# === 공개 함수 ===

# ehr_classify_signal: 입력 prompt 분류
# 출력: success | correction | none
ehr_classify_signal() {
  local s="$1"
  local len=${#s}
  # 제외 1: 길이 < 3
  if [ "$len" -lt 3 ]; then echo none; return 0; fi
  # 제외 2: 길이 > 500
  if [ "$len" -gt 500 ]; then echo none; return 0; fi
  # 제외 3: 순수 URL
  if printf '%s' "$s" | grep -qE '^https?://[^ ]+$'; then echo none; return 0; fi
  # 제외 4: 순수 git/shell 명령
  if printf '%s' "$s" | grep -qE '^(git|cd|ls|cat|grep|rm|cp|mv|find) '; then echo none; return 0; fi

  # success 우선 (둘 다 매칭되면 success — 양성 신호 우대)
  if printf '%s' "$s" | grep -qE "${KO_BOUND}${EHR_LEX_SUCCESS_KO}${KO_BOUND_R}" \
     || printf '%s' "$s" | grep -qiE "${EHR_LEX_SUCCESS_EN}"; then
    echo success; return 0
  fi

  if printf '%s' "$s" | grep -qE "${KO_BOUND}${EHR_LEX_CORR_KO}${KO_BOUND_R}" \
     || printf '%s' "$s" | grep -qiE "${EHR_LEX_CORR_EN}"; then
    echo correction; return 0
  fi

  echo none
}

ehr_score_for_kind() {
  case "$1" in
    success)    echo 2 ;;
    correction) echo 1 ;;
    *)          echo 0 ;;
  esac
}

# ehr_learn_should_capture: capture pre-flight
# 0 = 진행, 1 = silent skip
ehr_learn_should_capture() {
  local proj="${CLAUDE_PROJECT_DIR:-$(pwd)}"
  local harness="$proj/.claude/HARNESS.json"
  local gi="$proj/.gitignore"
  local flag="$proj/.claude/.ehr-hook-degraded.flag"

  [ -f "$harness" ] || return 1

  # capture_enabled 확인 (jq 없으면 fallback: 텍스트 검사)
  if command -v jq >/dev/null 2>&1; then
    local enabled; enabled=$(jq -r '.ehr_cycle.learnings_meta.capture_enabled // true' "$harness" 2>/dev/null)
    [ "$enabled" = "true" ] || return 1
  fi

  # gitignore 강제
  if [ -f "$gi" ] && grep -qE '^\.claude/learnings/' "$gi"; then
    :
  else
    mkdir -p "$proj/.claude" 2>/dev/null
    : > "$flag"  # degraded flag (one-shot)
    return 1
  fi

  return 0
}

# ehr_learn_append: pending.jsonl append. 호출자가 redaction 완료 JSON 라인 전달.
# Args: $1 = JSON record (1 line)
ehr_learn_append() {
  local proj="${CLAUDE_PROJECT_DIR:-$(pwd)}"
  local pending="$proj/.claude/learnings/pending.jsonl"
  local rec="$1"
  mkdir -p "$(dirname "$pending")" 2>/dev/null || return 1
  printf '%s\n' "$rec" >> "$pending" || return 1
  return 0
}
```

- [ ] **Step 4: PASS 확인**

```bash
bash plugins/ehr-harness/skills/ehr-harness/lib/learnings.test.sh
```

Expected: `PASS=N FAIL=0`. fixture 모든 케이스 + capture pre-flight + degraded flag.

### Task 3.3: user-prompt-capture.sh 구현 (TDD)

- [ ] **Step 1: 실패 테스트** — Write `plugins/ehr-harness/profiles/shared/hooks/user-prompt-capture.test.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HOOK="$SCRIPT_DIR/user-prompt-capture.sh"

PASS=0; FAIL=0
assert_eq() { if [ "$1" = "$2" ]; then PASS=$((PASS+1)); else FAIL=$((FAIL+1)); echo "FAIL: expected [$2] got [$1] at $3"; fi; }

TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
mkdir -p "$TMP/.claude"
echo '{"schema_version":5,"ehr_cycle":{"learnings_meta":{"capture_enabled":true}}}' > "$TMP/.claude/HARNESS.json"
echo '.claude/learnings/' > "$TMP/.gitignore"

# === 가드 1: stdout = 0 byte ===
input='{"prompt":"좋아 이 방향으로 확정","transcript_path":"/dev/null","session_id":"test1"}'
out_bytes=$(CLAUDE_PROJECT_DIR="$TMP" bash "$HOOK" <<<"$input" | wc -c | tr -d ' ')
assert_eq "$out_bytes" "0" "stdout 0 byte (success signal)"

# pending.jsonl 에 record 추가됐는지
test -f "$TMP/.claude/learnings/pending.jsonl"
assert_eq "$?" "0" "pending.jsonl created"

kind=$(jq -r .kind "$TMP/.claude/learnings/pending.jsonl")
assert_eq "$kind" "success" "kind=success"

redact_chk=$(jq -r .redaction_checked "$TMP/.claude/learnings/pending.jsonl")
assert_eq "$redact_chk" "true" "redaction_checked=true"

# === none 신호는 append 안 함 ===
rm -f "$TMP/.claude/learnings/pending.jsonl"
input2='{"prompt":"JSP 파일 위치 알려줘","transcript_path":"/dev/null","session_id":"test2"}'
CLAUDE_PROJECT_DIR="$TMP" bash "$HOOK" <<<"$input2" >/dev/null
test ! -f "$TMP/.claude/learnings/pending.jsonl"
assert_eq "$?" "0" "no append for kind=none"

# === gitignore 미적용 → silent skip + degraded flag ===
rm -f "$TMP/.gitignore"
input3='{"prompt":"좋아 진행","transcript_path":"/dev/null","session_id":"test3"}'
out=$(CLAUDE_PROJECT_DIR="$TMP" bash "$HOOK" <<<"$input3" 2>&1)
assert_eq "$?" "0" "exit 0 even when refused"
test -f "$TMP/.claude/.ehr-hook-degraded.flag"
assert_eq "$?" "0" "degraded flag set"

# === HARNESS.json 부재 → silent exit 0 ===
rm -f "$TMP/.claude/HARNESS.json"
echo '.claude/learnings/' > "$TMP/.gitignore"
CLAUDE_PROJECT_DIR="$TMP" bash "$HOOK" <<<"$input" >/dev/null
assert_eq "$?" "0" "exit 0 when no HARNESS.json"

echo "PASS=$PASS FAIL=$FAIL"
[ "$FAIL" -eq 0 ]
```

- [ ] **Step 2: 실행 — FAIL 확인**

```bash
bash plugins/ehr-harness/profiles/shared/hooks/user-prompt-capture.test.sh
```

Expected: hook 파일 부재로 stdout=0 byte 어서션 실패 또는 입력 처리 실패.

- [ ] **Step 3: 구현** — Write `plugins/ehr-harness/profiles/shared/hooks/user-prompt-capture.sh`:

```bash
#!/usr/bin/env bash
# UserPromptSubmit hook — correction/success heuristic capture.
# 가드 1: stdout = 0 byte (모든 경로에서 stdout 침묵).
set +e

PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$(pwd)}"
LEARN_DIR="$PROJECT_DIR/.claude/learnings"
DEGRADED="$PROJECT_DIR/.claude/.ehr-hook-degraded.flag"

# stderr 로 모든 stdout 리다이렉트 (가드 1)
exec 3>&1 1>&2

silent_exit() { exec 1>&3 3>&-; exit 0; }

# 의존성 검사
command -v jq >/dev/null 2>&1 || silent_exit

# stdin JSON 읽기 (Claude Code hook spec)
INPUT="$(cat)"
[ -n "$INPUT" ] || silent_exit

PROMPT=$(printf '%s' "$INPUT" | jq -r '.prompt // empty')
SESSION_ID=$(printf '%s' "$INPUT" | jq -r '.session_id // empty')
TRANSCRIPT=$(printf '%s' "$INPUT" | jq -r '.transcript_path // empty')

[ -n "$PROMPT" ] || silent_exit

# lib 로드
LIB="$(dirname "$0")/../../skills/ehr-harness/lib"
# 플러그인 cache 위치도 시도 (settings.json 의 path 가 generated 라 어렵게 잡힐 수 있음)
[ -f "$LIB/learnings.sh" ] || LIB="${CLAUDE_PLUGIN_ROOT:-}/skills/ehr-harness/lib"
[ -f "$LIB/learnings.sh" ] || silent_exit

# shellcheck disable=SC1091
. "$LIB/learnings.sh" 2>/dev/null || silent_exit
# shellcheck disable=SC1091
. "$LIB/redaction.sh" 2>/dev/null || silent_exit

# pre-flight (capture_enabled, gitignore 강제)
ehr_learn_should_capture || silent_exit

# 분류
KIND=$(ehr_classify_signal "$PROMPT")
[ "$KIND" = "none" ] && silent_exit

SCORE=$(ehr_score_for_kind "$KIND")

# transcript 마지막 assistant 턴 1개 tail (있으면)
PREV_TURN=""
if [ -f "$TRANSCRIPT" ]; then
  PREV_TURN=$(grep -E '"role":\s*"assistant"' "$TRANSCRIPT" 2>/dev/null \
              | tail -1 \
              | jq -r '.content // empty' 2>/dev/null \
              | head -c 400)
fi

# redaction
PROMPT_RED=$(ehr_redact "$(printf '%s' "$PROMPT" | head -c 200)")
PREV_RED=$(ehr_redact "$(printf '%s' "$PREV_TURN" | head -c 200)")
META=$(ehr_redact_meta "$PROMPT")

# drop?
DROP=$(ehr_redact_should_drop "$META")
[ "$DROP" = "true" ] && silent_exit

# session/snippet hash (redacted 기반)
SESSION_HASH="sha256:$(printf '%s' "$SESSION_ID" | sha256sum 2>/dev/null | awk '{print $1}')"
SNIPPET_HASH="sha256:$(printf '%s%s' "$PROMPT_RED" "$PREV_RED" | sha256sum 2>/dev/null | awk '{print $1}')"

# profile (HARNESS 에서)
PROFILE=$(jq -r '.profile // "ehr5"' "$PROJECT_DIR/.claude/HARNESS.json" 2>/dev/null)
TS=$(date -Iseconds 2>/dev/null || date)

# record 조립
RECORD=$(jq -nc \
  --arg ts "$TS" \
  --arg sh "$SESSION_HASH" \
  --arg kind "$KIND" \
  --argjson score "$SCORE" \
  --arg pr "$PROMPT_RED" \
  --arg pv "$PREV_RED" \
  --arg snh "$SNIPPET_HASH" \
  --argjson meta "$META" \
  --arg prof "$PROFILE" \
  '{
    schema_version: 1,
    ts: $ts,
    session_hash: $sh,
    kind: $kind,
    score_delta: $score,
    prompt_snippet_redacted: $pr,
    prev_turn_snippet_redacted: $pv,
    snippet_hash: $snh,
    redaction_checked: $meta.redaction_checked,
    redaction_count: $meta.redaction_count,
    redaction_failed: $meta.redaction_failed,
    sensitivity: (if ($meta.redaction_count // 0) > 0 then "possible_pii" else "low" end),
    candidate_rule: null,
    tool_context: {},
    profile: $prof
  }')

ehr_learn_append "$RECORD" 2>/dev/null
silent_exit
```

- [ ] **Step 4: 실행 권한 + PASS 확인**

```bash
chmod +x plugins/ehr-harness/profiles/shared/hooks/user-prompt-capture.sh
bash plugins/ehr-harness/profiles/shared/hooks/user-prompt-capture.test.sh
```

Expected: `PASS=N FAIL=0`.

### Task 3.4: Stage 3 commit

```bash
git add plugins/ehr-harness/skills/ehr-harness/lib/learnings.sh \
        plugins/ehr-harness/skills/ehr-harness/lib/learnings.test.sh \
        plugins/ehr-harness/skills/ehr-harness/lib/fixtures/prompts-ko.txt \
        plugins/ehr-harness/skills/ehr-harness/lib/fixtures/prompts-en.txt \
        plugins/ehr-harness/skills/ehr-harness/lib/fixtures/prompts-excluded.txt \
        plugins/ehr-harness/profiles/shared/hooks/user-prompt-capture.sh \
        plugins/ehr-harness/profiles/shared/hooks/user-prompt-capture.test.sh

git commit -m "$(cat <<'EOF'
feat(hooks): UserPromptSubmit capture (Phase A)

- learnings.sh:
  - ehr_classify_signal (한국어 word-boundary POSIX 대안 + 영어)
  - ehr_score_for_kind (success=2 / correction=1)
  - ehr_learn_should_capture (gitignore 강제 + degraded flag)
  - ehr_learn_append (pending.jsonl)
- user-prompt-capture.sh:
  - stdout = 0 byte (가드 1)
  - redaction 통과 record 만 저장 (가드 7)
  - session/snippet hash = redacted 기반 sha256
  - candidate_rule placeholder (harvest 가 채움)
- fixture: prompts-ko (20), prompts-en (10), prompts-excluded (5)

회귀: 기존 13개 + 신규 learnings/redaction/hook 테스트 통과.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Stage 4: SessionStart Injection (Phase B)

**Goal:** preferences_history 의 최신값 → CLAUDE_ENV_FILE (tool-visible) + additionalContext JSON (model-visible). stdout ≤ 1024 byte JSON, jq -e 검증. jq 없으면 env 만 + stdout 0.

**Files:**
- Create: `session-start-inject.sh`, `session-start-inject.test.sh`
- Modify: `plugins/ehr-harness/profiles/shared/settings.json` — SessionStart hook 등록

### Task 4.1: 테스트 먼저

- [ ] **Step 1: 테스트 작성** — Write `plugins/ehr-harness/profiles/shared/hooks/session-start-inject.test.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HOOK="$SCRIPT_DIR/session-start-inject.sh"

PASS=0; FAIL=0
assert_eq() { if [ "$1" = "$2" ]; then PASS=$((PASS+1)); else FAIL=$((FAIL+1)); echo "FAIL: expected [$2] got [$1] at $3"; fi; }
assert_le() { if [ "$1" -le "$2" ]; then PASS=$((PASS+1)); else FAIL=$((FAIL+1)); echo "FAIL: $1 > $2 at $3"; fi; }

TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
mkdir -p "$TMP/.claude"

# preferences_history 가 있는 v5 HARNESS
cat > "$TMP/.claude/HARNESS.json" <<'JSON'
{
  "schema_version": 5,
  "profile": "ehr4",
  "ehr_cycle": {
    "preferences_history": [
      {"ts":"2026-04-20T10:00:00+09:00","key":"SUGGEST_MODE","from":"ask","to":"silent"},
      {"ts":"2026-04-21T10:00:00+09:00","key":"DB_AUTH","from":"full","to":"readonly"},
      {"ts":"2026-04-22T10:00:00+09:00","key":"RESPONSE_TONE","from":"verbose","to":"concise"},
      {"ts":"2026-04-23T10:00:00+09:00","key":"LANG","from":"ko","to":"ko"}
    ],
    "learnings_meta": {"capture_enabled": true}
  }
}
JSON

# CLAUDE_ENV_FILE 모의
ENVF="$TMP/env_inject"
: > "$ENVF"

# === 가드 2: stdout ≤ 1024 byte JSON ===
out=$(CLAUDE_PROJECT_DIR="$TMP" CLAUDE_ENV_FILE="$ENVF" bash "$HOOK" </dev/null)
out_bytes=$(printf '%s' "$out" | wc -c | tr -d ' ')
assert_le "$out_bytes" "1024" "stdout ≤ 1024"

# JSON valid
printf '%s' "$out" | jq -e . >/dev/null
assert_eq "$?" "0" "stdout is valid JSON"

# additionalContext 키 존재
ctx=$(printf '%s' "$out" | jq -r '.hookSpecificOutput.additionalContext // empty')
test -n "$ctx"
assert_eq "$?" "0" "additionalContext present"

# 한국어/영어 키워드 포함
printf '%s' "$ctx" | grep -q "DB" || { FAIL=$((FAIL+1)); echo "FAIL: ctx missing DB"; }
PASS=$((PASS+1))

# === CLAUDE_ENV_FILE 에 export 라인 기록 ===
grep -q '^export EHR_DB_AUTH=' "$ENVF"
assert_eq "$?" "0" "env file has DB_AUTH"
grep -q '^export EHR_FILE_SCOPE=' "$ENVF"
assert_eq "$?" "0" "env file has FILE_SCOPE"

# === jq 없을 때 fallback (PATH 에서 jq 제거 시뮬) ===
PATH_NOJQ="$(printf '%s' "$PATH" | tr ':' '\n' | grep -vE '/jq' | paste -sd: -)"
out2=$(CLAUDE_PROJECT_DIR="$TMP" CLAUDE_ENV_FILE="$ENVF" PATH="$PATH_NOJQ" bash "$HOOK" </dev/null)
b2=$(printf '%s' "$out2" | wc -c | tr -d ' ')
assert_eq "$b2" "0" "stdout 0 when jq missing"

# === HARNESS.json 부재 → silent skip ===
rm "$TMP/.claude/HARNESS.json"
out3=$(CLAUDE_PROJECT_DIR="$TMP" CLAUDE_ENV_FILE="$ENVF" bash "$HOOK" </dev/null)
b3=$(printf '%s' "$out3" | wc -c | tr -d ' ')
assert_eq "$b3" "0" "stdout 0 when no HARNESS"

echo "PASS=$PASS FAIL=$FAIL"
[ "$FAIL" -eq 0 ]
```

- [ ] **Step 2: 실행 — FAIL 확인**

Expected: hook 파일 없음 → 모든 어서션 fail.

### Task 4.2: session-start-inject.sh 구현

- [ ] **Step 1: 구현** — Write `plugins/ehr-harness/profiles/shared/hooks/session-start-inject.sh`:

```bash
#!/usr/bin/env bash
# SessionStart hook — preferences inject.
# 가드 2: stdout ≤ 1024 byte JSON (jq -e 통과).
# - tool-visible: $CLAUDE_ENV_FILE 에 export 라인 추가
# - model-visible: hookSpecificOutput.additionalContext (≤1KB)
# jq 없으면 env 만, stdout 0.
set +e

PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$(pwd)}"
HARNESS="$PROJECT_DIR/.claude/HARNESS.json"

[ -f "$HARNESS" ] || exit 0

# preferences_history 의 최신 key 별 to 값 추출 (allowlist 6개)
get_pref() {
  local key="$1" default="$2"
  command -v jq >/dev/null 2>&1 || { printf '%s' "$default"; return; }
  local v; v=$(jq -r --arg k "$key" '
    [.ehr_cycle.preferences_history[]? | select(.key == $k)] 
    | if length > 0 then .[-1].to else empty end
  ' "$HARNESS" 2>/dev/null)
  [ -z "$v" ] && v="$default"
  printf '%s' "$v"
}

SUGGEST_MODE=$(get_pref SUGGEST_MODE ask)
RESPONSE_TONE=$(get_pref RESPONSE_TONE concise)
DB_AUTH=$(get_pref DB_AUTH full)
FILE_SCOPE=$(get_pref FILE_SCOPE minimal)
LANG=$(get_pref LANG ko)
HARVEST_POLICY=$(get_pref HARVEST_POLICY manual_only)

# (1) tool-visible — CLAUDE_ENV_FILE
if [ -n "${CLAUDE_ENV_FILE:-}" ]; then
  {
    printf 'export EHR_DB_AUTH=%q\n'         "$DB_AUTH"
    printf 'export EHR_FILE_SCOPE=%q\n'      "$FILE_SCOPE"
    printf 'export EHR_HARVEST_POLICY=%q\n'  "$HARVEST_POLICY"
  } >> "$CLAUDE_ENV_FILE" 2>/dev/null
fi

# (2) model-visible — additionalContext JSON
# jq 없으면 silent (env 만 처리)
command -v jq >/dev/null 2>&1 || exit 0

MAX=700
CTX_RAW="EHR harness preferences: 응답 톤=${RESPONSE_TONE}, 언어=${LANG}, 제안 모드=${SUGGEST_MODE}, DB 권한=${DB_AUTH}, 파일 스코프=${FILE_SCOPE}, harvest=${HARVEST_POLICY}"

# byte-safe 축약 (UTF-8 안전)
CTX=$(printf '%s' "$CTX_RAW" | awk -v max="$MAX" '
  { s=$0; while (length(s) > max) s=substr(s, 1, length(s)-1); print s }
')

JSON=$(jq -nc --arg ctx "$CTX" '{
  hookSpecificOutput: {
    hookEventName: "SessionStart",
    additionalContext: $ctx
  }
}')

# 가드 2: 1024 + jq -e
SIZE=$(printf '%s' "$JSON" | wc -c | tr -d ' ')
if [ "$SIZE" -le 1024 ] && printf '%s' "$JSON" | jq -e . >/dev/null 2>&1; then
  printf '%s' "$JSON"
fi
exit 0
```

- [ ] **Step 2: 권한 + 테스트 PASS**

```bash
chmod +x plugins/ehr-harness/profiles/shared/hooks/session-start-inject.sh
bash plugins/ehr-harness/profiles/shared/hooks/session-start-inject.test.sh
```

Expected: `PASS=N FAIL=0`.

### Task 4.3: settings.json 갱신 (UserPromptSubmit + SessionStart 등록)

- [ ] **Step 1: settings.json 재작성** — Write `plugins/ehr-harness/profiles/shared/settings.json`:

```json
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Bash",
        "hooks": [
          {
            "type": "command",
            "command": "bash \"$CLAUDE_PROJECT_DIR/.claude/hooks/db-read-only.sh\"",
            "timeout": 3
          },
          {
            "type": "command",
            "command": "bash \"$CLAUDE_PROJECT_DIR/.claude/hooks/vcs-no-commit.sh\"",
            "timeout": 3
          }
        ]
      }
    ],
    "UserPromptSubmit": [
      {
        "matcher": "*",
        "hooks": [
          {
            "type": "command",
            "command": "bash \"$CLAUDE_PROJECT_DIR/.claude/hooks/user-prompt-capture.sh\"",
            "timeout": 3
          }
        ]
      }
    ],
    "SessionStart": [
      {
        "matcher": "*",
        "hooks": [
          {
            "type": "command",
            "command": "bash \"$CLAUDE_PROJECT_DIR/.claude/hooks/session-start-inject.sh\"",
            "timeout": 3
          }
        ]
      }
    ]
  }
}
```

- [ ] **Step 2: 회귀**

```bash
bash plugins/ehr-harness/skills/ehr-harness/lib/tests/run-all.sh
bash plugins/ehr-harness/profiles/shared/hooks/hooks.test.sh
```

Expected: 모든 통과.

### Task 4.4: Stage 4 commit

```bash
git add plugins/ehr-harness/profiles/shared/hooks/session-start-inject.sh \
        plugins/ehr-harness/profiles/shared/hooks/session-start-inject.test.sh \
        plugins/ehr-harness/profiles/shared/settings.json

git commit -m "$(cat <<'EOF'
feat(hooks): SessionStart preferences 주입 (Phase B)

- session-start-inject.sh:
  - tool-visible: CLAUDE_ENV_FILE 에 export EHR_* 라인 (DB_AUTH, FILE_SCOPE, HARVEST_POLICY)
  - model-visible: hookSpecificOutput.additionalContext (≤1KB, jq -e 검증)
  - byte-safe 축약 (UTF-8 안전, head -c 절단 금지)
  - jq 없음 → env 만, stdout 0 (가드 2 fallback)
- settings.json: UserPromptSubmit + SessionStart 블록 등록

회귀: 기존 hooks.test.sh 통과 + 신규 session-start-inject.test.sh 통과.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Stage 5: ehr-lessons Skill + AGENTS.md eager 지식 (Phase D)

**Goal:** 하네스데이터 4개 지식 즉시 주입. eager 2개는 AGENTS.md.skel marker 블록, lazy 2개는 신규 ehr-lessons skill (per-profile).

**Files:**
- Create: `profiles/ehr4/skills/ehr-lessons/SKILL.md`, `profiles/ehr5/skills/ehr-lessons/SKILL.md`
- Modify: `profiles/ehr4/skeleton/AGENTS.md.skel`, `profiles/ehr5/skeleton/AGENTS.md.skel`

### Task 5.1: AGENTS.md.skel eager marker 블록 삽입 (EHR4)

- [ ] **Step 1: 현재 skel 확인 — 끝부분에 marker 삽입할 위치 찾기**

```bash
tail -20 plugins/ehr-harness/profiles/ehr4/skeleton/AGENTS.md.skel
```

- [ ] **Step 2: skel 끝에 EHR-LESSONS 섹션 추가** — 파일 끝에 다음 블록 append (총 byte 1024 이내 — 가드 3):

```markdown

<!-- EHR-LESSONS:BEGIN db-auth-protocol -->
## 분석 요청 프로토콜

DB 작업 권한 분리 (모든 EHR 분석 대화의 신뢰 기초):

- **조회 (SELECT, USER_SOURCE 등)**: 자유롭게 진행 가능. 결과는 사용자에게 제시.
- **수정 (UPDATE / INSERT / DELETE / DDL / 프로시저 ALTER)**: AI가 직접 실행 금지. SQL 스니펫 제시 후 사용자 또는 DBA 가 검토·실행.
- **재확인 불필요**: 사용자가 "DB 수정하지마" 라고 말해도 본 프로토콜은 기본 동작이라 추가 확인 응답 불필요.
<!-- EHR-LESSONS:END db-auth-protocol -->

<!-- EHR-LESSONS:BEGIN ehr-operational-constants -->
## EHR 운영 상수

- **그룹웨어 연동 배치**: 매일 00:00 (SYSDATE 기준). `P_YMD` 파라미터가 배치 기준일. 미래 발령 누출 방지에 `MAX(ORD_YMD) <= REPLACE(P_YMD, '-', '')` 조건 필수.
- **근무스케줄 처리 실패 진단**: TSYS903 에러 로그 → TTIM001/TTIM120 중복 데이터 우선 확인.
<!-- EHR-LESSONS:END ehr-operational-constants -->
```

- [ ] **Step 3: 가드 3 검증** — 두 marker 블록 합산 ≤ 1024 byte:

```bash
awk '/<!-- EHR-LESSONS:BEGIN/,/<!-- EHR-LESSONS:END/' \
  plugins/ehr-harness/profiles/ehr4/skeleton/AGENTS.md.skel | wc -c
```

Expected: 1024 이하 숫자.

### Task 5.2: AGENTS.md.skel eager (EHR5)

- [ ] **Step 1: 동일 블록을 EHR5 에도** — 같은 marker 블록을 `plugins/ehr-harness/profiles/ehr5/skeleton/AGENTS.md.skel` 끝에 append. 본문은 동일 (운영 상수는 ehr4/ehr5 공통).

- [ ] **Step 2: 가드 3 검증 (EHR5)**

```bash
awk '/<!-- EHR-LESSONS:BEGIN/,/<!-- EHR-LESSONS:END/' \
  plugins/ehr-harness/profiles/ehr5/skeleton/AGENTS.md.skel | wc -c
```

Expected: 1024 이하.

### Task 5.3: ehr-lessons skill 생성 (EHR4)

- [ ] **Step 1: 디렉토리 + SKILL.md** — Write `plugins/ehr-harness/profiles/ehr4/skills/ehr-lessons/SKILL.md`:

```markdown
---
name: ehr-lessons
description: EHR 작업 누적 지식 (검증 함수 명명 규칙, 회신 템플릿, 향후 harvest promoted 지식). 화면 검증 / 회신 작성 / 신규 표준 적용 시 호출.
---

# ehr-lessons (EHR4)

이 스킬은 **lazy-load** 누적 지식 저장소다. 매 세션 자동 로드 X — 명시 호출 시만.

향후 `/ehr-harvest-learnings` → audit 승인 흐름이 본 SKILL.md 끝에 새 섹션을 append 한다 (가드 4: 15360B 상한).

---

## 1. 검증 함수 명명 규칙

EHR4 화면 검증 로직(`*AppDet.jsp`) 작성 시 다음 패턴 준수:

```
함수명: validate{특수휴가종류}{검증항목}()
       또는 check{축약명}()  (단일 함수가 여러 검증을 통합 처리)

예 (✓):
  validateChildbirthVacationStartDate()
  checkMatLeave(sYmd)
  validateSpecialVacationStartDate()

예 (✗):
  isChildbirthVacation()      # 동사+is 형은 boolean 만
  getChildbirthYmd()          # 검증이 아니라 조회
  여러 함수 분산 (서버 + JSP)  # 단일 책임 원칙 위반
```

**핵심 규약**:
- **단일 함수가 dateCheck() / logicValidation() 양쪽에서 호출**되도록 작성. 변수 추가 최소화.
- **JSP 만 수정**, 서버 Controller/Service 신규 생성 자제 (사용자가 명시 요청한 경우 외).
- 기존 함수명 변경 시 caller 검색하여 일괄 갱신.

---

## 2. 회신 템플릿 (인사담당자/개발자/관리자 분기)

EHR 도메인 분석 결과를 회신할 때 3섹션 구조:

```markdown
## 1. 분석 결과 (기술)
- 근본 원인:
- 영향 테이블/함수:
- 검증 SQL:

## 2. 담당자용 회신 (비기술)
- 현상:
- 처리 방향:
- 1줄 요약:

## 3. 개발자용 수정 제시
- 수정 파일:
- 수정 줄 번호:
- SQL/코드 스니펫 (DBA 검토 후 실행):
```

**숫자로 설명하기 원칙**: 추상 설명 대신 실제 DB 값 + 공식 제시 (예: "법정이자 781,369 - 상환이자 455,890 = 325,479").

---

## 3. (이후 harvest 지식 append 영역)

`/ehr-harvest-learnings` 승인 시 본 섹션 아래에 marker 블록으로 추가됨. 사용자는 자유 편집 가능.

`<!-- EHR-LESSONS:BEGIN ... -->` ~ `<!-- EHR-LESSONS:END ... -->` 마커 보존.
```

- [ ] **Step 2: 가드 4 검증**

```bash
wc -c < plugins/ehr-harness/profiles/ehr4/skills/ehr-lessons/SKILL.md
```

Expected: 15360 이하.

### Task 5.4: ehr-lessons skill (EHR5)

- [ ] **Step 1: EHR5 용 SKILL.md** — Write `plugins/ehr-harness/profiles/ehr5/skills/ehr-lessons/SKILL.md`:

(EHR4 와 거의 동일하나 헤더만 `# ehr-lessons (EHR5)` 로 변경. 본문은 동일 — EHR4/5 모두 같은 EHR 도메인 규약을 공유.)

- [ ] **Step 2: 가드 4 검증** (EHR5 측 SKILL.md 도 ≤ 15360B).

### Task 5.5: Stage 5 commit

```bash
git add plugins/ehr-harness/profiles/ehr4/skeleton/AGENTS.md.skel \
        plugins/ehr-harness/profiles/ehr5/skeleton/AGENTS.md.skel \
        plugins/ehr-harness/profiles/ehr4/skills/ehr-lessons/SKILL.md \
        plugins/ehr-harness/profiles/ehr5/skills/ehr-lessons/SKILL.md

git commit -m "$(cat <<'EOF'
feat(skills): ehr-lessons + AGENTS.md eager 지식 (Phase D)

- AGENTS.md.skel (ehr4/ehr5) marker 블록 2개 추가:
  - db-auth-protocol (분석 요청 프로토콜)
  - ehr-operational-constants (그룹웨어 배치, TSYS903)
  → 가드 3 통과 (≤ 1024B per profile)

- ehr-lessons skill (per-profile) lazy-load:
  - 검증 함수 명명 규칙
  - 회신 템플릿 (3섹션)
  - 향후 harvest promoted 지식 append 영역
  → 가드 4 통과 (≤ 15360B per profile)

하네스데이터 분석에서 도출한 4개 지식 즉시 반영.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Stage 6: Harvest Implementation (Phase C)

**Goal:** `/ehr-harvest-learnings` slash → pending 클러스터링 + score(distinct_sessions, cap) + nonce + scope → staged. LLM 호출 cap=100/run.

**Files:**
- Create: `harvest.sh`, `harvest.test.sh`, `commands/ehr/harvest-learnings.md`
- Create: fixture `pending-5signals.jsonl`, `pending-rejected-pattern.jsonl`, `pending-corrupt-line.jsonl`

### Task 6.1: pending fixture 작성

- [ ] **Step 1: pending-5signals.jsonl** — 2주제 클러스터링 케이스:

```jsonl
{"schema_version":1,"ts":"2026-04-21T10:00:00+09:00","session_hash":"sha256:s001","kind":"correction","score_delta":1,"prompt_snippet_redacted":"[ID] 그룹웨어 배치 시점 다시 봐","prev_turn_snippet_redacted":"[DATE] 발령이 즉시 반영","snippet_hash":"sha256:h001","redaction_checked":true,"redaction_count":2,"redaction_failed":false,"sensitivity":"possible_pii","candidate_rule":null,"tool_context":{"last_skill":"ehr-procedure-tracer","last_tool":"Read"},"profile":"ehr4"}
{"schema_version":1,"ts":"2026-04-22T10:00:00+09:00","session_hash":"sha256:s002","kind":"correction","score_delta":1,"prompt_snippet_redacted":"P_YMD 조건 빠졌어","prev_turn_snippet_redacted":"MAX(ORD_YMD) 만 체크","snippet_hash":"sha256:h002","redaction_checked":true,"redaction_count":0,"redaction_failed":false,"sensitivity":"low","candidate_rule":null,"tool_context":{},"profile":"ehr4"}
{"schema_version":1,"ts":"2026-04-23T10:00:00+09:00","session_hash":"sha256:s003","kind":"success","score_delta":2,"prompt_snippet_redacted":"좋아 P_YMD 이하 조건 확정","prev_turn_snippet_redacted":"AND S1.ORD_YMD <= REPLACE(P_YMD ...)","snippet_hash":"sha256:h003","redaction_checked":true,"redaction_count":0,"redaction_failed":false,"sensitivity":"low","candidate_rule":null,"tool_context":{},"profile":"ehr4"}
{"schema_version":1,"ts":"2026-04-23T11:00:00+09:00","session_hash":"sha256:s004","kind":"success","score_delta":2,"prompt_snippet_redacted":"이 방향 맞음 진행","prev_turn_snippet_redacted":"checkMatLeave 단일 함수","snippet_hash":"sha256:h004","redaction_checked":true,"redaction_count":0,"redaction_failed":false,"sensitivity":"low","candidate_rule":null,"tool_context":{},"profile":"ehr4"}
{"schema_version":1,"ts":"2026-04-24T10:00:00+09:00","session_hash":"sha256:s005","kind":"correction","score_delta":1,"prompt_snippet_redacted":"여러 함수 말고 합치자","prev_turn_snippet_redacted":"3개 함수 분리 제시","snippet_hash":"sha256:h005","redaction_checked":true,"redaction_count":0,"redaction_failed":false,"sensitivity":"low","candidate_rule":null,"tool_context":{},"profile":"ehr4"}
```

(주제 1 = 그룹웨어 배치 (record 1,2,3): correction×2 + success×1 = 4점, distinct_sessions=3 → promotion 통과.
 주제 2 = 함수 통합 (record 4,5): success×1 + correction×1 = 3점, distinct_sessions=2 → 통과.)

- [ ] **Step 2: pending-corrupt-line.jsonl** — 라인 3 깨진 JSON:

```
{"schema_version":1,"ts":"2026-04-21T10:00:00+09:00","kind":"correction","score_delta":1}
{"schema_version":1,"ts":"2026-04-22T10:00:00+09:00","kind":"success","score_delta":2}
{not valid json line, should be skipped}
{"schema_version":1,"ts":"2026-04-24T10:00:00+09:00","kind":"correction","score_delta":1}
```

- [ ] **Step 3: pending-rejected-pattern.jsonl** — 1개 record (rejected.jsonl 시뮬과 함께):

```
{"schema_version":1,"ts":"2026-04-25T10:00:00+09:00","session_hash":"sha256:srx","kind":"success","score_delta":2,"prompt_snippet_redacted":"이전에 거부됐던 규칙 재시도","prev_turn_snippet_redacted":"...","snippet_hash":"sha256:rejected_topic_hash","redaction_checked":true,"redaction_count":0,"redaction_failed":false,"sensitivity":"low","candidate_rule":null,"tool_context":{},"profile":"ehr4"}
```

### Task 6.2: harvest.sh 구현 (TDD)

- [ ] **Step 1: 테스트** — Write `plugins/ehr-harness/skills/ehr-harness/lib/harvest.test.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB_DIR="$SCRIPT_DIR"
FIXTURES="$LIB_DIR/fixtures"

# shellcheck disable=SC1091
. "$LIB_DIR/harvest.sh"

PASS=0; FAIL=0
assert_eq() { if [ "$1" = "$2" ]; then PASS=$((PASS+1)); else FAIL=$((FAIL+1)); echo "FAIL: expected [$2] got [$1] at $3"; fi; }
assert_ge() { if [ "$1" -ge "$2" ]; then PASS=$((PASS+1)); else FAIL=$((FAIL+1)); echo "FAIL: $1 < $2 at $3"; fi; }

TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
mkdir -p "$TMP/.claude/learnings"
echo '{"schema_version":5,"profile":"ehr4","ehr_cycle":{"learnings_meta":{"capture_enabled":true,"promotion_policy":{"success_weight":2,"correction_weight":1,"threshold":3,"distinct_sessions_min":2,"same_session_cap":2}}}}' > "$TMP/.claude/HARNESS.json"

# === 점수 계산 단위 테스트 ===
# success×1 + correction×2 = 4 ; distinct_sessions=3 → pass
# (실제 클러스터링은 LLM 의존이므로, 본 단위는 score 계산만 검증)
score=$(ehr_harvest_score 1 2)
assert_eq "$score" "4" "score(success=1, correction=2)"

# distinct_sessions 카운트
cp "$FIXTURES/learnings/pending-5signals.jsonl" "$TMP/.claude/learnings/pending.jsonl"
ds=$(ehr_harvest_distinct_sessions "$TMP/.claude/learnings/pending.jsonl")
assert_ge "$ds" "3" "distinct_sessions ≥ 3"

# === corrupt line skip ===
cp "$FIXTURES/learnings/pending-corrupt-line.jsonl" "$TMP/.claude/learnings/pending.jsonl"
valid=$(ehr_harvest_count_valid "$TMP/.claude/learnings/pending.jsonl")
assert_eq "$valid" "3" "valid lines skip corrupt"

# === LLM cap=100 ===
yes '{"schema_version":1,"ts":"2026-04-21T10:00:00+09:00","kind":"correction","score_delta":1}' \
  | head -150 > "$TMP/.claude/learnings/pending.jsonl"
capped=$(ehr_harvest_take_first "$TMP/.claude/learnings/pending.jsonl" 100 | wc -l | tr -d ' ')
assert_eq "$capped" "100" "cap to 100"

# === nonce 형식 ===
echo "test content" > "$TMP/staged-test.md"
nonce=$(ehr_harvest_nonce "$TMP/staged-test.md")
printf '%s' "$nonce" | grep -qE '^[a-f0-9]{64}$'
assert_eq "$?" "0" "nonce format ^[a-f0-9]{64}$"

echo "PASS=$PASS FAIL=$FAIL"
[ "$FAIL" -eq 0 ]
```

- [ ] **Step 2: 실행 — FAIL 확인**

Expected: `harvest.sh: No such file or directory`.

- [ ] **Step 3: 구현** — Write `plugins/ehr-harness/skills/ehr-harness/lib/harvest.sh`:

```bash
#!/usr/bin/env bash
# Harvest helper library — pending → staged 변환의 단위 함수들.
# 클러스터링 자체는 Claude (slash command 본문) 가 수행. 본 lib 은 결정적 부분만.

# ehr_harvest_score: success_count + correction_count → 점수
# 정책은 HARNESS.json 의 promotion_policy 가 우선. 본 함수는 단순 합산용 fallback.
ehr_harvest_score() {
  local s=${1:-0} c=${2:-0}
  echo $((s * 2 + c * 1))
}

# ehr_harvest_distinct_sessions: pending.jsonl 의 unique session_hash 수
ehr_harvest_distinct_sessions() {
  local p="$1"
  [ -f "$p" ] || { echo 0; return; }
  command -v jq >/dev/null 2>&1 || { echo 0; return; }
  jq -r '.session_hash // empty' "$p" 2>/dev/null | sort -u | grep -c .
}

# ehr_harvest_count_valid: 유효 JSON 라인 수 (corrupt skip)
ehr_harvest_count_valid() {
  local p="$1" cnt=0
  [ -f "$p" ] || { echo 0; return; }
  while IFS= read -r line; do
    [ -z "$line" ] && continue
    if printf '%s' "$line" | jq -e . >/dev/null 2>&1; then
      cnt=$((cnt+1))
    fi
  done < "$p"
  echo "$cnt"
}

# ehr_harvest_take_first: 처음 N 라인만 (LLM cap)
ehr_harvest_take_first() {
  local p="$1" n="${2:-100}"
  head -n "$n" "$p"
}

# ehr_harvest_nonce: staged file 의 sha256 (lowercase hex 64)
ehr_harvest_nonce() {
  local f="$1"
  sha256sum "$f" 2>/dev/null | awk '{print $1}'
}
```

- [ ] **Step 4: PASS**

```bash
bash plugins/ehr-harness/skills/ehr-harness/lib/harvest.test.sh
```

Expected: `PASS=N FAIL=0`.

### Task 6.3: /ehr-harvest-learnings slash command

- [ ] **Step 1: command 파일** — Write `plugins/ehr-harness/profiles/shared/commands/ehr/harvest-learnings.md`:

```markdown
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
   - `score = success×2 + correction×1`
   - `distinct_sessions` (unique session_hash 수)
   - `same_session_cap`: 같은 session_hash 의 같은 topic 최대 +2점
   - 통과 조건: `score ≥ threshold (default 3)` AND (`distinct_sessions ≥ 2` OR `explicit_confirmed_rule`)
6. 통과 주제마다:
   - `candidate_rule` (1줄 자연어 정규화) 추출
   - `staged/{topic-slug}.md` 생성 (front-matter: score, signals, scope=project-local 기본, target=AGENTS.md|ehr-lessons/SKILL.md)
   - `nonce = sha256sum(staged_file) | awk '{print $1}'`
   - `ehr_cycle.learnings_meta.staged_nonces[topic] = nonce` 갱신
7. pending.jsonl → `archived/pending-YYYYMMDD.jsonl` rotate.
8. ehr_cycle.learnings_meta 갱신 (last_harvest_at, counter들).
9. 보고: 생성된 staged 개수, 다음 단계는 `/ehr-harness audit` 으로 승인.

## 가드

- LLM 호출 cap = 100 records/call
- staged file scope 기본 `project-local`. cwd 가 ehr-harness-plugin repo 일 때만 사용자 확인 후 `plugin-dev` 라벨.
- 본 명령이 직접 AGENTS.md / SKILL.md 를 수정하지 않음 (가드 5 — merge 는 audit 승인 후만).

## 출력 예

```
[ehr-harvest] pending: 47 records (valid 45, skipped 2)
[ehr-harvest] clusters: 2 topics
  - groupware-batch-schedule: score=5 (success×1, correction×3), distinct_sessions=3 → PROMOTED
  - validation-fn-naming: score=3 (success×1, correction×1), distinct_sessions=2 → PROMOTED
[ehr-harvest] staged 2 files at .claude/learnings/staged/
[ehr-harvest] next: /ehr-harness audit 으로 승인
```
```

### Task 6.4: Stage 6 commit

```bash
git add plugins/ehr-harness/skills/ehr-harness/lib/harvest.sh \
        plugins/ehr-harness/skills/ehr-harness/lib/harvest.test.sh \
        plugins/ehr-harness/skills/ehr-harness/lib/fixtures/learnings/pending-5signals.jsonl \
        plugins/ehr-harness/skills/ehr-harness/lib/fixtures/learnings/pending-corrupt-line.jsonl \
        plugins/ehr-harness/skills/ehr-harness/lib/fixtures/learnings/pending-rejected-pattern.jsonl \
        plugins/ehr-harness/profiles/shared/commands/ehr/harvest-learnings.md

git commit -m "$(cat <<'EOF'
feat(harvest): /ehr-harvest-learnings + harvest.sh (Phase C)

- harvest.sh: 결정적 단위 함수 (score, distinct_sessions, count_valid,
  take_first, nonce). 클러스터링/candidate_rule 추출은 slash 본문이 수행.
- harvest.test.sh: corrupt skip, distinct_sessions, cap=100, nonce 형식 검증
- /ehr-harvest-learnings slash: 흐름 문서화 + 출력 형식
- fixtures: pending-5signals (2 주제 클러스터링), corrupt-line, rejected-pattern

승격 조건: score ≥ 3 AND (distinct_sessions ≥ 2 OR explicit_confirmed_rule).
LLM cap 100/call. nonce = sha256 lowercase hex 64 (가드 5 토대).

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Stage 7: Audit/Merge Integration

**Goal:** audit 의 `compute_drift()` 에 `learnings_drift` 추가. 사용자 승인 시 `EHR_AUDIT_APPROVED=1 + EHR_NONCE` 세팅 후 `merge.sh::apply_staged()` 호출. scope 분기 (project-local / plugin-dev / org-template reserved).

**Files:**
- Modify: `audit.sh`, `merge.sh`, `merge.test.sh`

### Task 7.1: merge.sh::apply_staged 구현 (TDD)

- [ ] **Step 1: 테스트 — merge.test.sh 끝에 추가**

```bash
# === apply_staged: env gate + nonce + scope ===
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
mkdir -p "$TMP/.claude/learnings/staged"
echo '{"schema_version":5,"profile":"ehr4","ehr_cycle":{"learnings_meta":{"staged_nonces":{}}}}' > "$TMP/.claude/HARNESS.json"

cat > "$TMP/.claude/learnings/staged/test-topic.md" <<'EOF'
---
topic: test-topic
score: 4
scope: project-local
target: ehr-lessons/SKILL.md
---

## 제안 본문
<!-- EHR-LESSONS:BEGIN test-topic -->
test rule
<!-- EHR-LESSONS:END test-topic -->
EOF

NONCE=$(sha256sum "$TMP/.claude/learnings/staged/test-topic.md" | awk '{print $1}')

# nonce HARNESS 에 등록 (harvest 가 했을 일)
jq --arg t test-topic --arg n "$NONCE" '.ehr_cycle.learnings_meta.staged_nonces[$t] = $n' \
   "$TMP/.claude/HARNESS.json" > "$TMP/h.tmp" && mv "$TMP/h.tmp" "$TMP/.claude/HARNESS.json"

# === gate 1: EHR_AUDIT_APPROVED 없으면 exit 2 ===
( cd "$TMP" && bash "$LIB_DIR/merge.sh" apply_staged ".claude/learnings/staged/test-topic.md" )
assert_exit "$?" "2" "no AUDIT_APPROVED → exit 2"

# === gate 2: nonce mismatch → exit 3 ===
( cd "$TMP" && EHR_AUDIT_APPROVED=1 EHR_NONCE="0000000000000000000000000000000000000000000000000000000000000000" \
   bash "$LIB_DIR/merge.sh" apply_staged ".claude/learnings/staged/test-topic.md" )
assert_exit "$?" "3" "nonce mismatch → exit 3"

# === gate 3: org-template reserved → exit 5 ===
sed -i 's/scope: project-local/scope: org-template/' "$TMP/.claude/learnings/staged/test-topic.md"
NONCE2=$(sha256sum "$TMP/.claude/learnings/staged/test-topic.md" | awk '{print $1}')
jq --arg t test-topic --arg n "$NONCE2" '.ehr_cycle.learnings_meta.staged_nonces[$t] = $n' \
   "$TMP/.claude/HARNESS.json" > "$TMP/h.tmp" && mv "$TMP/h.tmp" "$TMP/.claude/HARNESS.json"
( cd "$TMP" && EHR_AUDIT_APPROVED=1 EHR_NONCE="$NONCE2" \
   bash "$LIB_DIR/merge.sh" apply_staged ".claude/learnings/staged/test-topic.md" )
assert_exit "$?" "5" "org-template reserved → exit 5"

# === project-local 적용 성공 → staged.applied 이동 ===
sed -i 's/scope: org-template/scope: project-local/' "$TMP/.claude/learnings/staged/test-topic.md"
NONCE3=$(sha256sum "$TMP/.claude/learnings/staged/test-topic.md" | awk '{print $1}')
jq --arg t test-topic --arg n "$NONCE3" '.ehr_cycle.learnings_meta.staged_nonces[$t] = $n' \
   "$TMP/.claude/HARNESS.json" > "$TMP/h.tmp" && mv "$TMP/h.tmp" "$TMP/.claude/HARNESS.json"

mkdir -p "$TMP/.claude/skills/ehr-lessons"
echo '# ehr-lessons (project-local)' > "$TMP/.claude/skills/ehr-lessons/SKILL.md"

( cd "$TMP" && EHR_AUDIT_APPROVED=1 EHR_NONCE="$NONCE3" \
   bash "$LIB_DIR/merge.sh" apply_staged ".claude/learnings/staged/test-topic.md" )
assert_exit "$?" "0" "project-local apply success"

# staged.applied 이동
test -f "$TMP/.claude/learnings/staged.applied/test-topic.md"
assert_eq "$?" "0" "moved to staged.applied"

# SKILL.md 에 marker 블록 추가
grep -q 'EHR-LESSONS:BEGIN test-topic' "$TMP/.claude/skills/ehr-lessons/SKILL.md"
assert_eq "$?" "0" "SKILL.md updated"
```

- [ ] **Step 2: FAIL 확인** — apply_staged 함수 부재.

- [ ] **Step 3: 구현** — `merge.sh` 끝에 추가:

```bash
# === apply_staged (Stage 7) ===
# v1.10 self-evolving merge entry. audit 흐름이 EHR_AUDIT_APPROVED=1 + EHR_NONCE 세팅 후 호출.
# Args: $1 = staged file path (relative to PROJECT_DIR or absolute)
# Exit codes: 0 ok / 2 no approval / 3 nonce mismatch / 4 plugin-dev cwd 위반 / 5 org-template / 6 unknown scope
apply_staged() {
  local staged="$1"
  local proj="${CLAUDE_PROJECT_DIR:-$(pwd)}"
  [[ "$staged" = /* ]] || staged="$proj/$staged"

  # gate 1: env
  if [ -z "${EHR_AUDIT_APPROVED:-}" ] || [ -z "${EHR_NONCE:-}" ]; then
    echo "FATAL: EHR_AUDIT_APPROVED + EHR_NONCE 필수" >&2
    return 2
  fi

  [ -f "$staged" ] || { echo "FATAL: staged file not found: $staged" >&2; return 2; }

  # gate 2: nonce
  local actual_nonce; actual_nonce=$(sha256sum "$staged" | awk '{print $1}')
  if ! printf '%s' "$EHR_NONCE" | grep -qE '^[a-f0-9]{64}$'; then
    echo "FATAL: EHR_NONCE format invalid (expect ^[a-f0-9]{64}$)" >&2
    return 3
  fi
  if [ "$actual_nonce" != "$EHR_NONCE" ]; then
    echo "FATAL: nonce mismatch (staged 변조 의심)" >&2
    return 3
  fi

  # 추가: HARNESS.json 의 staged_nonces[topic] 과도 비교
  local topic; topic=$(awk '/^topic:/ {print $2; exit}' "$staged")
  local registered; registered=$(jq -r --arg t "$topic" '.ehr_cycle.learnings_meta.staged_nonces[$t] // empty' "$proj/.claude/HARNESS.json" 2>/dev/null)
  if [ -n "$registered" ] && [ "$registered" != "$actual_nonce" ]; then
    echo "FATAL: HARNESS staged_nonces mismatch" >&2
    return 3
  fi

  # scope 결정
  local scope; scope=$(awk '/^scope:/ {print $2; exit}' "$staged")
  scope="${scope:-project-local}"

  case "$scope" in
    project-local)
      _apply_project_local "$staged"
      ;;
    plugin-dev)
      # cwd 가 플러그인 repo 인지 검증
      if ! grep -q '"name": "ehr-harness"' "$proj/plugins/ehr-harness/.claude-plugin/plugin.json" 2>/dev/null; then
        echo "FATAL: plugin-dev scope 인데 cwd 가 플러그인 repo 가 아님" >&2
        return 4
      fi
      _apply_plugin_dev "$staged"
      ;;
    org-template)
      echo "FATAL: org-template scope is reserved in v1.10" >&2
      return 5
      ;;
    *)
      echo "FATAL: unknown scope: $scope" >&2
      return 6
      ;;
  esac

  # 적용 후: staged.applied 이동
  mkdir -p "$proj/.claude/learnings/staged.applied"
  mv "$staged" "$proj/.claude/learnings/staged.applied/"
  return 0
}

_apply_project_local() {
  local staged="$1" proj="${CLAUDE_PROJECT_DIR:-$(pwd)}"
  local target; target=$(awk '/^target:/ {print $2; exit}' "$staged")
  case "$target" in
    AGENTS.md|AGENTS.md.skel)
      _append_marker_block "$staged" "$proj/AGENTS.md"
      ;;
    ehr-lessons/SKILL.md|ehr-lessons*)
      mkdir -p "$proj/.claude/skills/ehr-lessons"
      [ -f "$proj/.claude/skills/ehr-lessons/SKILL.md" ] || \
        echo "# ehr-lessons (project-local)" > "$proj/.claude/skills/ehr-lessons/SKILL.md"
      _append_marker_block "$staged" "$proj/.claude/skills/ehr-lessons/SKILL.md"
      ;;
    *)
      echo "FATAL: unknown target: $target" >&2
      return 1
      ;;
  esac
}

_apply_plugin_dev() {
  local staged="$1" proj="${CLAUDE_PROJECT_DIR:-$(pwd)}"
  local target; target=$(awk '/^target:/ {print $2; exit}' "$staged")
  local profile; profile=$(jq -r '.profile // "ehr5"' "$proj/.claude/HARNESS.json")
  case "$target" in
    AGENTS.md.skel)
      _append_marker_block "$staged" "$proj/plugins/ehr-harness/profiles/$profile/skeleton/AGENTS.md.skel"
      ;;
    ehr-lessons/SKILL.md|ehr-lessons*)
      _append_marker_block "$staged" "$proj/plugins/ehr-harness/profiles/$profile/skills/ehr-lessons/SKILL.md"
      ;;
    *)
      echo "FATAL: unknown target (plugin-dev): $target" >&2
      return 1
      ;;
  esac
}

# staged 의 marker 블록을 target 끝에 append
_append_marker_block() {
  local staged="$1" target="$2"
  awk '/<!-- EHR-LESSONS:BEGIN/,/<!-- EHR-LESSONS:END/' "$staged" >> "$target"
}

# script 직접 실행 시 dispatcher
if [ "${BASH_SOURCE[0]}" = "$0" ]; then
  case "${1:-}" in
    apply_staged) shift; apply_staged "$@" ;;
    *) echo "Usage: merge.sh apply_staged <staged-file>" >&2; exit 1 ;;
  esac
fi
```

- [ ] **Step 4: 테스트 PASS**

```bash
bash plugins/ehr-harness/skills/ehr-harness/lib/merge.test.sh
```

Expected: `PASS=N FAIL=0`.

### Task 7.2: audit.sh learnings_drift 통합

- [ ] **Step 1: 현재 compute_drift 위치**

```bash
grep -n 'compute_drift\|drift_section' plugins/ehr-harness/skills/ehr-harness/lib/audit.sh | head
```

- [ ] **Step 2: compute_drift 끝에 learnings_drift 호출 추가** — `audit.sh` 의 `compute_drift()` 함수 내, 기존 drift 산출 직후에 다음 블록 추가:

```bash
# === Stage 7: learnings_drift ===
ehr_audit_learnings_drift() {
  local proj="${CLAUDE_PROJECT_DIR:-$(pwd)}"
  local staged_dir="$proj/.claude/learnings/staged"
  [ -d "$staged_dir" ] || { echo "[]"; return; }
  local files; files=$(ls "$staged_dir"/*.md 2>/dev/null)
  [ -z "$files" ] && { echo "[]"; return; }
  local arr="["
  for f in $files; do
    local topic score; topic=$(awk '/^topic:/ {print $2; exit}' "$f")
    score=$(awk '/^score:/ {print $2; exit}' "$f")
    arr+="{\"topic\":\"$topic\",\"score\":${score:-0},\"path\":\"$f\"},"
  done
  arr="${arr%,}]"
  echo "$arr"
}
```

`compute_drift()` 본체에서 출력 직전에:
```bash
LEARNINGS_DRIFT=$(ehr_audit_learnings_drift)
# 기존 drift JSON 에 .learnings 키 추가
```

(audit.sh 의 정확한 출력 포맷에 맞춰 통합. 함수 시그니처 보존.)

- [ ] **Step 3: 회귀**

```bash
bash plugins/ehr-harness/skills/ehr-harness/lib/audit.test.sh
```

Expected: 기존 케이스 모두 통과.

### Task 7.3: SKILL.md Step 0.7-B + Step 2-M 갱신

- [ ] **Step 1: SKILL.md 의 audit 모드 설명에 learnings_drift 한 단락 추가** — `plugins/ehr-harness/skills/ehr-harness/SKILL.md` 의 Step 2-M 또는 audit 흐름 섹션에 다음 추가:

```markdown
### learnings_drift (v1.10+)

`/ehr-harvest-learnings` 가 생성한 `.claude/learnings/staged/*.md` 가 있으면 audit 결과의 `learnings_drift` 섹션에 표시. 사용자 승인 시 다음을 실행:

```bash
export EHR_AUDIT_APPROVED=1
export EHR_NONCE="$(sha256sum staged/<topic>.md | awk '{print $1}')"
bash skills/ehr-harness/lib/merge.sh apply_staged staged/<topic>.md
```

scope 별 적용 대상:
- `project-local` (기본): 프로젝트의 `AGENTS.md` 또는 `.claude/skills/ehr-lessons/SKILL.md`
- `plugin-dev` (cwd = 플러그인 repo): `plugins/ehr-harness/profiles/<profile>/...`
- `org-template`: v1.10 reserved, exit 5
```

### Task 7.4: Stage 7 commit

```bash
git add plugins/ehr-harness/skills/ehr-harness/lib/merge.sh \
        plugins/ehr-harness/skills/ehr-harness/lib/merge.test.sh \
        plugins/ehr-harness/skills/ehr-harness/lib/audit.sh \
        plugins/ehr-harness/skills/ehr-harness/SKILL.md

git commit -m "$(cat <<'EOF'
feat(audit): learnings_drift 통합 + merge nonce/scope gate

- merge.sh::apply_staged:
  - gate 1: EHR_AUDIT_APPROVED + EHR_NONCE 둘 다 필수 (가드 5)
  - gate 2: nonce 형식 ^[a-f0-9]{64}$, staged 파일 sha256 일치
  - gate 3: HARNESS staged_nonces[topic] 일치
  - scope 분기:
    - project-local (기본): .claude 산출물만 수정
    - plugin-dev: cwd 가 플러그인 repo 인지 plugin.json 검증 (가드 8)
    - org-template: v1.10 reserved, exit 5
  - 적용 후 staged → staged.applied 이동
- audit.sh::ehr_audit_learnings_drift: staged/*.md 를 drift 로 표시
- SKILL.md: audit 흐름에 learnings_drift 섹션 + 사용자 승인 절차

회귀: 기존 audit/merge 테스트 통과.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Stage 8: Regression + Weight Tests

**Goal:** 가드 8종 종합 테스트 + Windows CRLF / jq missing / malformed JSON 회귀. run-all.sh 가 모든 테스트 발견.

**Files:**
- Create: `plugins/ehr-harness/skills/ehr-harness/lib/tests/harness-weight.test.sh`

### Task 8.1: harness-weight.test.sh 작성

- [ ] **Step 1: 테스트 파일** — Write `plugins/ehr-harness/skills/ehr-harness/lib/tests/harness-weight.test.sh`:

```bash
#!/usr/bin/env bash
# 가드 8종 종합 검증.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_ROOT="$(cd "$SCRIPT_DIR/../../../.." && pwd)"
PROJECT_ROOT="$(cd "$PLUGIN_ROOT/../.." && pwd)"

PASS=0; FAIL=0
assert_le() { if [ "$1" -le "$2" ]; then PASS=$((PASS+1)); else FAIL=$((FAIL+1)); echo "FAIL: $1 > $2 ($3)"; fi; }
assert_eq() { if [ "$1" = "$2" ]; then PASS=$((PASS+1)); else FAIL=$((FAIL+1)); echo "FAIL: expected [$2] got [$1] ($3)"; fi; }

# === 가드 1: UserPromptSubmit hook stdout = 0 ===
mkdir -p /tmp/weight_test/.claude
echo '{"schema_version":5,"profile":"ehr4","ehr_cycle":{"learnings_meta":{"capture_enabled":true}}}' > /tmp/weight_test/.claude/HARNESS.json
echo '.claude/learnings/' > /tmp/weight_test/.gitignore
b1=$(CLAUDE_PROJECT_DIR=/tmp/weight_test bash "$PLUGIN_ROOT/profiles/shared/hooks/user-prompt-capture.sh" \
  <<<'{"prompt":"좋아 진행","session_id":"w1","transcript_path":"/dev/null"}' | wc -c | tr -d ' ')
assert_eq "$b1" "0" "Guard 1: capture hook stdout=0"

# === 가드 2: SessionStart stdout ≤ 1024 + valid JSON ===
ENVF=$(mktemp)
out=$(CLAUDE_PROJECT_DIR=/tmp/weight_test CLAUDE_ENV_FILE="$ENVF" \
  bash "$PLUGIN_ROOT/profiles/shared/hooks/session-start-inject.sh" </dev/null)
b2=$(printf '%s' "$out" | wc -c | tr -d ' ')
assert_le "$b2" "1024" "Guard 2: SessionStart ≤ 1024"
if [ "$b2" -gt 0 ]; then
  printf '%s' "$out" | jq -e . >/dev/null
  assert_eq "$?" "0" "Guard 2: valid JSON"
fi
rm -f "$ENVF" /tmp/weight_test/.claude/HARNESS.json

# === 가드 3: AGENTS.md.skel EHR-LESSONS 섹션 ≤ 1024 ===
for prof in ehr4 ehr5; do
  s=$(awk '/<!-- EHR-LESSONS:BEGIN/,/<!-- EHR-LESSONS:END/' \
    "$PLUGIN_ROOT/profiles/$prof/skeleton/AGENTS.md.skel" | wc -c | tr -d ' ')
  assert_le "$s" "1024" "Guard 3: $prof AGENTS.md.skel learnings ≤ 1024"
done

# === 가드 4: SKILL.md ≤ 15360 ===
for f in "$PLUGIN_ROOT/skills/ehr-harness/SKILL.md" \
         "$PLUGIN_ROOT/profiles/ehr4/skills/ehr-lessons/SKILL.md" \
         "$PLUGIN_ROOT/profiles/ehr5/skills/ehr-lessons/SKILL.md"; do
  s=$(wc -c < "$f")
  assert_le "$s" "15360" "Guard 4: $(basename $(dirname $f))/$(basename $f) ≤ 15360"
done

# === 가드 5: merge.sh apply_staged 무권한 호출 → exit 2 ===
( cd /tmp && bash "$PLUGIN_ROOT/skills/ehr-harness/lib/merge.sh" apply_staged /tmp/nonexistent.md ) >/dev/null 2>&1
assert_eq "$?" "2" "Guard 5: no AUDIT_APPROVED → exit 2"

# === 가드 6: v4→v5 strict-append (회귀 — harness-state.test 의 케이스가 통과해야) ===
bash "$PLUGIN_ROOT/skills/ehr-harness/lib/harness-state.test.sh" >/dev/null
assert_eq "$?" "0" "Guard 6: v4→v5 migration test passes"

# === 가드 7: redaction drop 회귀 (PII 잔존 record drop) ===
bash "$PLUGIN_ROOT/skills/ehr-harness/lib/redaction.test.sh" >/dev/null
assert_eq "$?" "0" "Guard 7: redaction test passes"

# === 가드 8: org-template scope reserved → exit 5 ===
mkdir -p /tmp/weight_test/.claude/learnings/staged
cat > /tmp/weight_test/.claude/learnings/staged/g8.md <<'EOF'
---
topic: g8
score: 4
scope: org-template
target: AGENTS.md
---
EOF
echo '{"schema_version":5,"profile":"ehr4","ehr_cycle":{"learnings_meta":{"staged_nonces":{}}}}' > /tmp/weight_test/.claude/HARNESS.json
N=$(sha256sum /tmp/weight_test/.claude/learnings/staged/g8.md | awk '{print $1}')
jq --arg n "$N" '.ehr_cycle.learnings_meta.staged_nonces.g8 = $n' /tmp/weight_test/.claude/HARNESS.json > /tmp/weight_test/.claude/h.tmp && mv /tmp/weight_test/.claude/h.tmp /tmp/weight_test/.claude/HARNESS.json
( cd /tmp/weight_test && EHR_AUDIT_APPROVED=1 EHR_NONCE="$N" \
  bash "$PLUGIN_ROOT/skills/ehr-harness/lib/merge.sh" apply_staged ".claude/learnings/staged/g8.md" ) >/dev/null 2>&1
assert_eq "$?" "5" "Guard 8: org-template → exit 5"

rm -rf /tmp/weight_test

echo "PASS=$PASS FAIL=$FAIL"
[ "$FAIL" -eq 0 ]
```

- [ ] **Step 2: 실행**

```bash
chmod +x plugins/ehr-harness/skills/ehr-harness/lib/tests/harness-weight.test.sh
bash plugins/ehr-harness/skills/ehr-harness/lib/tests/harness-weight.test.sh
```

Expected: `PASS=N FAIL=0`.

### Task 8.2: run-all.sh 가 신규 테스트 모두 발견하는지

- [ ] **Step 1: 통합 실행**

```bash
bash plugins/ehr-harness/skills/ehr-harness/lib/tests/run-all.sh
```

Expected: 기존 13개 + 신규 (redaction, learnings, harvest, harness-weight, user-prompt-capture, session-start-inject) = 19+ 테스트 통과.

### Task 8.3: Stage 8 commit

```bash
git add plugins/ehr-harness/skills/ehr-harness/lib/tests/harness-weight.test.sh

git commit -m "$(cat <<'EOF'
test: 경량 가드 8종 종합 + 회귀 통합 (Stage 8)

- harness-weight.test.sh: 가드 8종 종합 검증
  - Guard 1: UserPromptSubmit stdout = 0
  - Guard 2: SessionStart stdout ≤ 1024 + valid JSON
  - Guard 3: AGENTS.md.skel learnings 섹션 ≤ 1024 (ehr4/ehr5)
  - Guard 4: SKILL.md ≤ 15360 (ehr-harness, ehr-lessons×2)
  - Guard 5: merge no AUDIT_APPROVED → exit 2
  - Guard 6: v4→v5 strict-append
  - Guard 7: redaction drop
  - Guard 8: org-template reserved exit 5
- run-all.sh 통과: 기존 13 + 신규 6+ 테스트.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Stage 9: Docs + Version Bump

**Goal:** SKILL.md 흐름도 갱신, CHANGELOG v1.10.0 entry 채우기, plugin.json 1.10.0 bump.

**Files:**
- Modify: `plugins/ehr-harness/.claude-plugin/plugin.json`, `plugins/ehr-harness/CHANGELOG.md`, `plugins/ehr-harness/skills/ehr-harness/SKILL.md`

### Task 9.1: plugin.json bump

- [ ] **Step 1: 버전 변경**

```bash
sed -i 's/"version": "1.9.5"/"version": "1.10.0"/' plugins/ehr-harness/.claude-plugin/plugin.json
cat plugins/ehr-harness/.claude-plugin/plugin.json
```

Expected: `"version": "1.10.0"`.

### Task 9.2: CHANGELOG.md v1.10.0 엔트리 확정

- [ ] **Step 1: TBD 를 실제 날짜로** — `plugins/ehr-harness/CHANGELOG.md` 에서 `## [1.10.0] — TBD` 를 다음으로 교체:

```markdown
## [1.10.0] — 2026-04-25

### Added
- self-evolving 메커니즘 (런타임 capture + 배치 harvest + audit 승인)
- HARNESS_SCHEMA v5 (`ehr_cycle.learnings_meta`)
- profile별 `ehr-lessons` skill (lazy-load, 검증 함수 명명 + 회신 템플릿)
- AGENTS.md.skel eager 지식 (분석 요청 프로토콜, EHR 운영 상수)
- correction harvester hook (UserPromptSubmit, redaction 강제)
- preferences inject hook (SessionStart, CLAUDE_ENV_FILE + additionalContext)
- `/ehr-harvest-learnings` slash command
- PII redaction 라이브러리 + `.claude/learnings/` gitignore 강제
- 경량 가드 8종 종합 테스트 (`harness-weight.test.sh`)
- 통합 테스트 runner (`lib/tests/run-all.sh`)

### Changed
- `HARNESS.json` schema v4 → v5 자동 마이그레이션 (strict-append, jq spread)
- 기존 hook path 를 `$CLAUDE_PROJECT_DIR` 기준으로 마이그레이션
- README 변경 이력 정책: v1.10 부터 신규 릴리즈는 본 CHANGELOG 로 분리

### Security
- raw 원문 sha256 금지 → redacted normalized 기반 sha256
- staged file nonce 검증 (sha256 lowercase hex 64)
- scope 격리: project-local (기본) / plugin-dev (cwd 검증) / org-template (reserved)
```

### Task 9.3: SKILL.md 흐름도 갱신

- [ ] **Step 1: SKILL.md 상단 또는 적절한 섹션에 self-evolving 흐름 추가** — 기존 흐름 설명 직후:

```markdown
### Self-Evolving Loop (v1.10+)

```
사용자 발화
   ↓
[UserPromptSubmit hook] → redaction → pending.jsonl  (런타임, stdout 0)
   ↓
[SessionStart hook] → CLAUDE_ENV_FILE + additionalContext  (런타임, ≤1KB)
   ↓ (주 1회 명시 호출)
/ehr-harvest-learnings
   ↓ → cluster + score(distinct_sessions, cap) + nonce
.claude/learnings/staged/*.md
   ↓
/ehr-harness audit → learnings_drift 표시
   ↓ 사용자 "예"
EHR_AUDIT_APPROVED=1 + EHR_NONCE → merge.sh apply_staged
   ↓ scope 분기
project-local: AGENTS.md / .claude/skills/ehr-lessons/SKILL.md
plugin-dev   : profiles/*/skeleton/AGENTS.md.skel / profiles/*/skills/ehr-lessons/SKILL.md
```
```

### Task 9.4: 최종 회귀 + Stage 9 commit

- [ ] **Step 1: 전체 회귀**

```bash
bash plugins/ehr-harness/skills/ehr-harness/lib/tests/run-all.sh
```

Expected: 전체 PASS, 0 FAIL.

- [ ] **Step 2: commit**

```bash
git add plugins/ehr-harness/.claude-plugin/plugin.json \
        plugins/ehr-harness/CHANGELOG.md \
        plugins/ehr-harness/skills/ehr-harness/SKILL.md

git commit -m "$(cat <<'EOF'
chore: bump v1.9.5 → v1.10.0

- plugin.json: 1.9.5 → 1.10.0 (minor release)
- CHANGELOG.md v1.10.0 엔트리 (Added/Changed/Security)
- SKILL.md self-evolving loop 흐름도 추가

self-evolving 단계 2 → 단계 3 도달.
가드 8종 통과, 회귀 0, 외부 평가자 v2.1 권고 모두 반영.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## 최종 커밋 리스트 검증

```bash
git log --oneline origin/main..HEAD
```

Expected (10 commits):
```
chore: bump v1.9.5 → v1.10.0
test: 경량 가드 8종 종합 + 회귀 통합 (Stage 8)
feat(audit): learnings_drift 통합 + merge nonce/scope gate
feat(harvest): /ehr-harvest-learnings + harvest.sh (Phase C)
feat(skills): ehr-lessons + AGENTS.md eager 지식 (Phase D)
feat(hooks): SessionStart preferences 주입 (Phase B)
feat(hooks): UserPromptSubmit capture (Phase A)
feat(privacy): PII redaction + .gitignore 강제 (Phase 2)
feat(schema): v4→v5 자동 마이그레이션 (strict-append)
chore(repo): v1.10 사전 구조 정리
```

---

## Self-Review

**1. Spec coverage** — v2 + §14 v2.1 의 모든 P0/P1 항목 task 매핑:

| 평가자 항목 | 반영 task |
|---|---|
| §14.1 SessionStart head -c 금지 | Task 4.2 (awk byte-safe + jq -e 검증) |
| §14.2 redaction_checked/count/failed | Task 2.2 (`ehr_redact_meta`), Task 3.3 (record 스키마) |
| §14.3 redacted-based hash | Task 3.3 (`SESSION_HASH`/`SNIPPET_HASH` redacted 기반) |
| §14.4 EHR_NONCE 형식 | Task 7.1 (정규식 검증), Task 8.1 Guard 5 |
| §14.5 org-template reserved | Task 7.1 (case 분기 exit 5), Task 8.1 Guard 8 |
| §14.6 volatile hash 범위 | Task 1.1 (HARNESS_SCHEMA v5 섹션 명시) |
| §14.7 jq missing fallback | Task 4.2 (구현), Task 4.1 fixture |
| §14.8 degraded.flag 위치 | `.claude/.ehr-hook-degraded.flag` 모든 코드/테스트 일관 |
| §10.1 CHANGELOG | Task 0.1 |
| §10.2 hook path migration | Task 0.4 |
| §10.3 word boundary 격리 | Task 3.2 (`ehr_classify_signal()` 단일 함수) |
| §10.4 analyze.sh 회귀 보호 | Task 0.3 (run-all.sh 가 analyze.test.sh 포함) |

**2. Placeholder scan** — TBD 1건 (CHANGELOG `[1.10.0] — TBD`) 은 Task 9.2 에서 의도적으로 채움. 그 외 placeholder 없음.

**3. Type consistency** — `ehr_redact`, `ehr_redact_meta`, `ehr_redact_should_drop`, `ehr_classify_signal`, `ehr_score_for_kind`, `ehr_learn_should_capture`, `ehr_learn_append`, `ehr_harvest_*`, `apply_staged`, `_apply_project_local`, `_apply_plugin_dev`, `_append_marker_block` 모든 호출자/정의 일치 확인.

**4. 가드 8종 vs Stage 매핑**:
- Guard 1 (UserPromptSubmit stdout=0): Stage 3, Stage 8.1
- Guard 2 (SessionStart ≤1KB JSON): Stage 4, Stage 8.1
- Guard 3 (AGENTS.md ≤1KB): Stage 5, Stage 8.1
- Guard 4 (SKILL.md ≤15KB): Stage 5, Stage 8.1
- Guard 5 (merge env gate): Stage 7, Stage 8.1
- Guard 6 (strict-append migration): Stage 1, Stage 8.1
- Guard 7 (redaction drop): Stage 2, Stage 3, Stage 8.1
- Guard 8 (scope 격리): Stage 7, Stage 8.1

빠진 가드 없음.

---

## Execution Handoff

**Plan complete and saved to `docs/superpowers/plans/2026-04-25-self-evolving-harness-v1.10-implementation-plan.md`.**

본 plan 은 v2 + §14 v2.1 patch 를 권위 spec 으로 삼아 작성됨. 10 atomic commit, TDD 5-step 패턴, 가드 8종 보호.

다음 두 실행 옵션:

**1. Subagent-Driven (recommended)** — Stage 별로 fresh subagent 디스패치, Stage 간 사용자 리뷰 체크포인트, 빠른 이터레이션. **REQUIRED SUB-SKILL: superpowers:subagent-driven-development**.

**2. Inline Execution** — 같은 세션에서 executing-plans 로 일괄 실행, 단계별 체크포인트. **REQUIRED SUB-SKILL: superpowers:executing-plans**.

어느 접근으로 갈까요?
