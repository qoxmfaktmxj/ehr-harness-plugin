# Self-Evolving EHR Harness v1.10.0 — Design Spec **v2**

| 메타 | 값 |
|---|---|
| 작성일 | 2026-04-25 (v2) / 2026-04-24 (v1) |
| 대상 버전 | `ehr-harness` v1.9.5 → **v1.10.0 (minor release)** |
| 작업 브랜치 | `claude/self-evolving-v1.10.0` |
| 베이스 | `origin/main @ d6b2889` (= v1 spec 커밋) |
| 문서 상태 | v1 외부 평가 반영 (P0×5 + P1×4 + P2×3) → 재평가 대기 |
| Diff vs v1 | 본 문서 §A "v1 대비 변경 요약" 참조 |

---

## §A. v1 대비 변경 요약 (외부 평가 반영)

### 사실 검증 결과 (v1 의 잘못된 전제)

| v1 의 가정 | 실제 | v2 대응 |
|---|---|---|
| `plugins/ehr-harness/CHANGELOG.md` 가 존재해서 수정만 하면 됨 | **존재하지 않음** — README.md 안에 엔트리 누적 | 신규 생성 (또는 README 엔트리 방식 유지 결정 §10.1) |
| `lib/tests/` 디렉토리 존재 | **없음** — 현재 `lib/*.test.sh` 평면 | `tests/run-all.sh` 신규 생성, 기존 `*.test.sh` 를 runner 에 편입 |
| hook 경로 `.claude/hooks/...` 상대경로로 충분 | 동작은 하나 Claude Code 권장은 `$CLAUDE_PROJECT_DIR` 기준 | 신규 hook 부터 절대 기준 채택, 기존 2개도 같이 migration |

### v1 → v2 핵심 설계 변경 (8개)

1. **SessionStart 주입 메커니즘 재설계** — `export VAR` 가 부모 프로세스에 전파되지 않는 unix 기본 한계 인정. 채널 분리: tool-visible 은 `$CLAUDE_ENV_FILE`, model-visible 은 `hookSpecificOutput.additionalContext` (≤1KB). guard "hook stdout = 0" 은 UserPromptSubmit 에만 적용.
2. **PII redaction 강제** — capture 시 사번/이름/날짜/조직코드 정규식 redaction 의무. 200자 길이 제한은 보조 수단. `redaction_applied: true` 플래그 + sensitivity 분류.
3. **`.claude/learnings/` gitignore 강제 + fail-safe** — "권장" 아닌 "없으면 capture 비활성화". hook 이 gitignore 적용 여부 검사 후 `.flag` 로 차단.
4. **scope 분리 (project-local / plugin-dev / org-template)** — v1 의 가장 큰 결함. AGENTS.md.skel 자동 수정은 plugin-source mutation 으로 차단. 기본값은 사용자 프로젝트 산출물(`AGENTS.md`, `.claude/skills/ehr-lessons/`) 만 수정.
5. **v4→v5 마이그레이션 알고리즘 명시** — jq spread 기반 6단계, unknown field 보존 보장. canonical hash 에서 schema_version + volatile field 제외 명시.
6. **scoring 강화** — `distinct_sessions ≥ 2` 기본 요구, same-session same-topic score cap = 2.
7. **한국어 word boundary 정정** — POSIX `\b` 미작동 인정. bash 대안 `[^가-힣A-Za-z0-9]좋아[^가-힣A-Za-z0-9]` 패턴 + 화이트리스트 검증.
8. **release 표현 정정** — semver 기준 v1.10.0 은 minor. "메이저 버전" 표현 제거.

### 추가된 구조 (평가자 권고)

- **candidate_rule 필드** — capture 는 redacted snippet + signal_type 만, harvest 가 LLM 으로 정규화된 rule 추출 후 staged 에 기록.
- **auto_stage / auto_merge 의미 명시** — auto_stage 는 staged 까지만, merge 는 항상 manual.
- **EHR_AUDIT_APPROVED + staged file nonce(sha256)** — UX gate 인정 + idempotency.
- **harvest LLM 호출 cap** — 한 번 호출당 pending 상한 100건, 초과 시 분할 처리.

### 마일스톤 재구성

v1 의 12 커밋 순서 → 평가자 권고 8단계로 재배치 (위험 우선 처리). §9 참조.

---

## 0. 동기 (v1 §0 그대로)

현재 플러그인은 self-evolving 성숙도 **단계 2**(수동 PR + 일부 자동 기록)에 머물러 있다. 하네스데이터 분석 결과 "그룹웨어 배치 매일 0시" 5회 반복, "JSP만 수정, 변수 추가 금지" 3회 반복 등 self-evolving 신호가 명확. Hermes/Reflexion/Voyager/Letta 의 공통 패턴(런타임 trace 캡처 + 배치 harvest + 사람 게이트)을 Claude Code plugin 으로 이식하되 **경량 원칙(Sonnet 컨텍스트/토큰 예산 보호)** 을 최우선 제약으로 둔다.

## 1. 목표 & 비목표 (v1 §1 + 보강)

### Goals
1. 단계 2 → **단계 3** 성숙도 상승 — 기록된 신호의 자동 반영 루프 완성
2. 하네스데이터 4개 실지식 v1.10.0 즉시 주입 (eager 2 / lazy 2)
3. **세션 bootstrap 토큰 증가분 ≤ 500 토큰** 유지
4. 기존 v4 사용자 **투명 마이그레이션** + v1.9.x 동작 회귀 0
5. **(v2 추가)** PII 캡처 0 — redaction 검증 통과 신호만 저장
6. **(v2 추가)** 플러그인 소스 자가 수정 0 — 기본 scope=project-local

### Non-Goals (v2 명시 강화)
- 스킬이 스킬을 직접 rewrite (단계 4)
- 세션 중 plugin 소스(skel, lib, SKILL.md) 자동 수정 — `scope=plugin-dev` 명시 모드에서만 허용
- weight 업데이트 / 임베딩 클러스터링
- GitHub PR 강제 (audit gate 가 사람 게이트 역할)

## 2. 핵심 설계 결정 (브레인스토밍 합의 + v2 정정)

| 축 | v1 결정 | v2 변경 |
|---|---|---|
| 학습 신호 범위 | correction + success 하이브리드 | (유지) |
| 저장 구조 | hybrid (pending.jsonl + ehr_cycle.learnings_meta) | (유지) + **redacted snippet + candidate_rule 필드 추가** |
| Promotion 기준 | score=success×2 + correction×1, threshold=3 | + **`distinct_sessions ≥ 2`** 또는 `explicit_confirmed_rule==true`, **same-session same-topic cap=2** |
| Harvest 반영 | 기존 audit 흐름 활용 | (유지) + **scope 필드, nonce 검증** |
| Lazy skill | 신규 ehr-lessons (per-profile) | (유지) |
| v4→v5 마이그레이션 | strict-append + 백업 | + **jq spread 6단계 알고리즘**, unknown field 보존 보장 |
| **(신규) scope** | — | **project-local (기본) / plugin-dev / org-template** |
| **(신규) PII** | (200자 trim 만) | **redaction 강제 + fail-safe** |
| **(신규) SessionStart 채널** | env export | **CLAUDE_ENV_FILE + additionalContext 분리** |

## 3. 경량 가드 (v1 6종 → v2 8종)

| # | 가드 | 구현 | 측정/검증 |
|---|---|---|---|
| 1 | **UserPromptSubmit hook stdout = 0** | `exec 1>&2` | `hooks.test.sh`: byte-count == 0 |
| 2 | **SessionStart hook stdout ≤ 1KB** (JSON only) | `printf '{"hookSpecificOutput":{...}}' \| jq -c` 출력 | `hooks.test.sh`: byte-count ≤ 1024 |
| 3 | AGENTS.md 증가분 ≤ 1024B (skel 의 EHR-LESSONS 섹션만) | git baseline diff | `harness-weight.test.sh` |
| 4 | SKILL.md ≤ 15360B (`ehr-lessons`, `ehr-harness` 둘 다) | `wc -c` | `harness-weight.test.sh` |
| 5 | Harvester 자동주입 금지 | `merge.sh::apply_staged` 가 `EHR_AUDIT_APPROVED=1` + 유효 nonce 없으면 exit 2 | `merge.test.sh` |
| 6 | Strict-append 마이그레이션 | v4 모든 필드 sha256 보존 | `harness-state.test.sh` |
| 7 | **(신규) PII redaction 강제** | capture 시 `redaction_applied:true` 없으면 record drop | `learnings.test.sh` |
| 8 | **(신규) scope 격리** | `scope=plugin-dev` 명시 + cwd 검증 없으면 skel 수정 차단 | `merge.test.sh` |

## 4. 아키텍처 (v1 §4 + v2 보강)

### 4.1 레이어 구조 (v2 = v1 + scope/redaction)

```
┌ 런타임 레이어 ─────────────────────────────────────────────┐
│                                                            │
│  SessionStart hook              UserPromptSubmit hook      │
│  ├─ CLAUDE_ENV_FILE write       ├─ heuristic 매칭          │
│  └─ additionalContext stdout    ├─ redaction 적용 (NEW)    │
│     (≤1KB JSON)                 ├─ candidate_rule placeholder│
│                                 └─ pending.jsonl append    │
│                                                            │
└────────────┬─────────────────────┬─────────────────────────┘
             │                     │
             ▼                     ▼
.claude/HARNESS.json     .claude/learnings/pending.jsonl
   ehr_cycle.learnings_meta   (gitignore 강제, redacted only)

┌ 배치 레이어 (명시 호출) ──────────────────────────────────┐
│                                                            │
│  /ehr-harvest-learnings                                    │
│    ├─ pending 읽기 (cap: 100건/호출)                       │
│    ├─ Claude 클러스터링 + candidate_rule 정규화            │
│    ├─ score 계산 (distinct_sessions, same-session cap)     │
│    ├─ scope 라벨 (기본 project-local)                      │
│    ├─ staged file sha256 = nonce 생성                      │
│    └─ staged/*.md 출력                                     │
│                                                            │
└─────────────────┬──────────────────────────────────────────┘
                  ▼
┌ 승인 레이어 (audit) ───────────────────────────────────────┐
│                                                            │
│  /ehr-harness audit                                        │
│    ├─ learnings_drift 섹션 (staged/*.md 제시)              │
│    ├─ 사용자 "예" → EHR_AUDIT_APPROVED=1 + EHR_NONCE=...   │
│    └─ merge.sh::apply_staged (nonce 검증)                  │
│                                                            │
└─────────────────┬──────────────────────────────────────────┘
                  ▼
┌ 정적 지식 레이어 (scope 분리) ────────────────────────────┐
│                                                            │
│  scope=project-local (기본):                               │
│    프로젝트의 AGENTS.md, .claude/skills/ehr-lessons/       │
│                                                            │
│  scope=plugin-dev (cwd=플러그인 repo 시만):                │
│    plugins/ehr-harness/profiles/*/skeleton/AGENTS.md.skel  │
│    plugins/ehr-harness/profiles/*/skills/ehr-lessons/      │
│                                                            │
│  scope=org-template (수동 승인 별도):                      │
│    조직 공통 템플릿 repo (별도 워크플로)                    │
│                                                            │
└────────────────────────────────────────────────────────────┘
```

### 4.2 컴포넌트 목록 (v1 → v2 변경분)

#### 신규 파일 (v1: 실행 12 + fixture 7 → v2: 실행 14 + fixture 8)

**v2 추가/변경된 신규 파일**:
```
plugins/ehr-harness/skills/ehr-harness/lib/
  redaction.sh                     [신규 v2] PII 정규식 라이브러리
  redaction.test.sh                [신규 v2]
  tests/
    run-all.sh                     [신규 v2] 기존 *.test.sh 통합 runner

plugins/ehr-harness/skills/ehr-harness/lib/fixtures/
  redaction-cases.txt              [신규 v2] PII 샘플 30개 (사번/이름/날짜/조직)
```

#### 수정 파일 (v1: 12 → v2: 13)

**v2 추가**: `README.md` 의 "현재 릴리즈 v1.8.0" stale 문구 정정 (v1.9.x → v1.10.0).

#### 신규 생성 vs 수정 변경

| 파일 | v1 분류 | v2 분류 | 사유 |
|---|---|---|---|
| `plugins/ehr-harness/CHANGELOG.md` | 수정 | **신규 생성** | 검증 결과 미존재 |
| `plugins/ehr-harness/profiles/shared/settings.json` 의 hook 경로 | 신규 hook 등록 | **신규 hook 등록 + 기존 2개 path migration** ($CLAUDE_PROJECT_DIR) |

### 4.3 퍼블릭 인터페이스 (v2 추가)

| Unit | 신규 공개 함수 |
|---|---|
| `redaction.sh` | `ehr_redact(text) → text_redacted, applied:bool, sensitivity:str` |
| `learnings.sh` | (v1 + ) `ehr_learn_should_capture() → bool` (gitignore + flag 검사) |
| `harvest.sh` | (v1 + ) `ehr_harvest_normalize_rule(records) → candidate_rule` |
| `merge.sh` | (v1 + ) `ehr_merge_verify_nonce(staged_path, nonce) → bool`<br>`ehr_merge_resolve_scope() → project-local\|plugin-dev` |

## 5. 데이터 플로우 (v2 핵심 변경)

### 5.1 런타임 capture (Phase A) — v2 변경 부분

**v1 → v2 처리 단계 변경**:
```
0. ehr_learn_should_capture() 사전 검사:
     - .claude/learnings/ 가 .gitignore 에 등록됐는가?
     - .claude/learnings/hook-degraded.flag 미존재?
     - HARNESS.json 의 capture_enabled != false?
   → 어느 하나라도 실패 시 silent skip exit 0

1. (v1) prompt + transcript tail 추출
2. (v1) heuristic 매칭

3. (v2 신규) ehr_redact() 적용:
     - prompt_snippet, prev_turn_snippet 양쪽
     - 정규식: 사번 \d{5,8}, 한글 이름+직책, 날짜 YYYY-MM-DD, 조직코드 등
     - 적용 결과 redaction_applied=true 보장 또는 record drop

4. (v2 변경) pending.jsonl 스키마:
   {
     "schema_version": 1,
     "ts": "2026-04-25T...",
     "session_hash": "sha256:...",          # session_id 해시화 (PII)
     "kind": "correction" | "success",
     "score_delta": 1 | 2,
     "prompt_snippet_redacted": "...",       # 200자 + redact 후
     "prev_turn_snippet_redacted": "...",
     "snippet_hash": "sha256:...",           # 원본 식별용
     "redaction_applied": true,              # 가드 7
     "sensitivity": "low" | "possible_pii",
     "candidate_rule": null,                 # harvest 단계에서 채움
     "tool_context": {"last_skill": "...", "last_tool": "..."},
     "profile": "ehr4"
   }

5. (v1) silent append, stdout = 0
```

### 5.2 SessionStart 주입 (Phase B) — v2 완전 재설계

**v1 의 잘못된 부분**: hook 내 `export VAR=...` 가 부모 프로세스(Claude)에 전파 안 됨.

**v2 채널 분리**:

```bash
# session-start-inject.sh

# (1) tool-visible preference → CLAUDE_ENV_FILE
if [ -n "${CLAUDE_ENV_FILE:-}" ]; then
  printf 'export EHR_DB_AUTH=%q\n'    "$db_auth"    >> "$CLAUDE_ENV_FILE"
  printf 'export EHR_FILE_SCOPE=%q\n' "$file_scope" >> "$CLAUDE_ENV_FILE"
  printf 'export EHR_HARVEST_POLICY=%q\n' "$harvest_policy" >> "$CLAUDE_ENV_FILE"
fi

# (2) model-visible preference → additionalContext (stdout JSON, ≤1KB)
ctx=$(jq -nc \
  --arg tone     "$tone" \
  --arg lang     "$lang" \
  --arg suggest  "$suggest_mode" \
  --arg dbauth   "$db_auth" \
  '{
    hookSpecificOutput: {
      hookEventName: "SessionStart",
      additionalContext: ("EHR harness preferences: " 
        + "응답 톤=" + $tone 
        + ", 언어=" + $lang
        + ", 제안 모드=" + $suggest 
        + ", DB 권한=" + $dbauth)
    }
  }')

# 가드 2 검증
size=$(printf '%s' "$ctx" | wc -c)
if [ "$size" -le 1024 ]; then
  printf '%s' "$ctx"
else
  printf '%s' "$ctx" | head -c 1024  # 강제 절단
fi
```

**Allowlist (v1 동일, 6개)**: SUGGEST_MODE / RESPONSE_TONE / DB_AUTH / FILE_SCOPE / LANG / HARVEST_POLICY.
어떤 키를 어느 채널로 보낼지:
- env (tool-visible): DB_AUTH, FILE_SCOPE, HARVEST_POLICY
- additionalContext (model-visible): TONE, LANG, SUGGEST_MODE, + (DB_AUTH 도 model 이 알아야 하므로 양쪽)

### 5.3 Harvest (Phase C) — v2 변경

**v1 → v2 추가**:
```
3.5 (v2) candidate_rule 추출:
     Claude 가 클러스터된 records 의 redacted snippet 들을 보고
     "이 신호들이 의미하는 일관된 규칙" 을 1줄 자연어로 정규화
     → staged.candidate_rule

4. score 계산 (v2 강화):
     - score = success_count * 2 + correction_count * 1
     - distinct_sessions = 고유 session_hash 개수
     - same_session_score(topic, session) ≤ 2 (cap)
     
   promotion 조건 (AND):
     - score >= 3
     - distinct_sessions >= 2  OR  explicit_confirmed_rule==true
     - rejected.jsonl 에 동일 candidate_rule_hash 없음

5. scope 결정:
     - cwd 가 ehr-harness-plugin repo? → plugin-dev (사용자 확인 후)
     - 그 외 → project-local (기본)

6. nonce 생성:
     staged file 작성 후 sha256 계산 → ehr_cycle.learnings_meta.staged_nonces[topic] 저장

7. cap 검사:
     단일 harvest 호출 처리 pending 상한 = 100건
     초과 시 가장 오래된 100건만 처리, 나머지는 다음 호출
```

### 5.4 Audit/Merge — v2 nonce 검증

**v1 → v2**:
```
audit 단계:
  사용자 "예" → 
    export EHR_AUDIT_APPROVED=1
    export EHR_NONCE=$(cat staged/topic.md | sha256sum)
    bash merge.sh apply_staged staged/topic.md target_path

merge.sh apply_staged():
  if [ -z "$EHR_AUDIT_APPROVED" ]; then exit 2; fi
  
  expected_nonce=$(jq -r ".ehr_cycle.learnings_meta.staged_nonces[\"$topic\"]" HARNESS.json)
  actual_nonce=$(sha256sum "$staged_path" | cut -d' ' -f1)
  
  if [ "$EHR_NONCE" != "$expected_nonce" ] || [ "$actual_nonce" != "$expected_nonce" ]; then
    echo "FATAL: nonce mismatch (staged 변조 의심)" >&2
    exit 3
  fi
  
  # scope 검증 (가드 8)
  scope=$(yq '.scope' "$staged_path")
  if [ "$scope" = "plugin-dev" ]; then
    if [ "$(realpath .)" != "$(realpath $(get_plugin_repo_root))" ]; then
      echo "FATAL: plugin-dev scope 인데 cwd 가 플러그인 repo 가 아님" >&2
      exit 4
    fi
  fi
  
  # 적용 (scope 별 target 다름)
  case "$scope" in
    project-local) apply_to "AGENTS.md" ".claude/skills/ehr-lessons/SKILL.md" ;;
    plugin-dev)    apply_to "plugins/.../skeleton/AGENTS.md.skel" "..." ;;
  esac
```

## 6. 에러 처리 (v1 §6 + v2 강화)

### 6.1 런타임 hook 실패 — v1 그대로 ("세션 절대 막지 않음", 모든 경로 exit 0)

### 6.2 마이그레이션 v4→v5 — v2 알고리즘 명시

```bash
# harness-state.sh::ehr_state_migrate_v4_to_v5(path)

1. 백업: cp "$path" ".ehr-bak/harness-v4-${ts}.json"

2. jq spread 로 unknown field 보존 마이그레이션:
   jq '
     . as $orig
     | $orig
     | .schema_version = 5
     | .ehr_cycle = (
         (.ehr_cycle // {})
         | . as $cycle
         | $cycle
         | .learnings_meta = (
             .learnings_meta // {
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
       )
   ' "$path" > "${path}.tmp"

3. schema validation (jq):
   jq -e '.schema_version == 5 and .ehr_cycle.learnings_meta != null' \
     "${path}.tmp" || rollback

4. unknown field 보존 검증:
   diff <(jq -S 'del(.schema_version,.ehr_cycle.learnings_meta)' "$path") \
        <(jq -S 'del(.schema_version,.ehr_cycle.learnings_meta)' "${path}.tmp")
   → 차이 있으면 rollback (= "기존 필드 손상")

5. canonical hash 갱신:
   - hash 산정 시 schema_version, learnings_meta.last_harvest_at,
     learnings_meta.staged_nonces 제외 (volatile)
   - 결과적으로 "내용 동일하면 hash 동일" 보장

6. 원자 교체: mv "${path}.tmp" "$path"
   실패 시 백업 복원, migration-failed.log 기록, v4 모드 fallback
```

### 6.3 PII 캡처 실패 (v2 신규)

```
redaction.sh::ehr_redact() 실패 또는 redaction_applied=false:
  → record drop (pending.jsonl 에 안 씀)
  → errors.log 에 "redaction-skip" 1줄 (PII 미저장)

.claude/learnings/ 가 gitignore 에 없음:
  → .claude/learnings/hook-degraded.flag 생성 (1회)
  → 이후 모든 capture silent skip
  → 다음 audit 실행 시 사용자에게 "gitignore 누락" 경고 표시
```

### 6.4 scope 위반 (v2 신규)

```
merge.sh 가 plugin-dev scope staged 를 project-local cwd 에서 적용 시도:
  → exit 4 (보안 차단)
  → 사용자에게 "이 staged 는 플러그인 dev 모드 전용. 플러그인 repo 에서 실행 필요" 안내
```

## 7. 테스트 전략 (v1 §7 + v2 추가)

### 7.1 신규 테스트 (v2: v1 7개 → 9개)

v1 7개 + 추가:
- `redaction.test.sh` — PII 정규식 매칭 정확도 (사번/이름/날짜/조직), redaction 후 검증
- `tests/run-all.sh` — 단일 명령으로 모든 테스트 실행

### 7.2 Fixture (v2: 4 + 3 → 4 + 3 + 1)

v1 + 추가:
- `redaction-cases.txt` — 30개 PII 샘플 (실제 하네스데이터에서 추출 후 anonymized)

### 7.3 회귀 (v2 강화)

기존 13개 + 신규 9개 = 22개. 모두 `tests/run-all.sh` 통해 단일 실행:
```bash
bash plugins/ehr-harness/skills/ehr-harness/lib/tests/run-all.sh
```

CI 추가 (기존 `.gstack/` 또는 신규 `.github/workflows/`): main 푸시 시 자동 실행.

## 8. Definition of Done (v2 강화)

- [ ] 신규 테스트 9개 모두 통과 (v1: 7 → v2: 9)
- [ ] 기존 회귀 13개 전부 재통과 (회귀 0)
- [ ] 경량 가드 8종 전부 통과 (v1: 6 → v2: 8)
  - [ ] UserPromptSubmit hook stdout = 0
  - [ ] SessionStart hook stdout ≤ 1024B JSON
  - [ ] AGENTS.md 증가분 ≤ 1024B
  - [ ] SKILL.md ≤ 15360B
  - [ ] Harvester `EHR_AUDIT_APPROVED=1` + 유효 nonce 없으면 exit 2
  - [ ] v4→v5 strict-append + unknown field 보존 검증
  - [ ] Redaction 미적용 record 자동 drop
  - [ ] plugin-dev scope cwd 검증
- [ ] PII redaction 30개 fixture 100% 통과
- [ ] gitignore 미적용 시 capture 비활성화 확인
- [ ] scope=project-local 기본 동작 확인 (skel 미수정)
- [ ] 마이그레이션 백업 + rollback + unknown field 보존 확인
- [ ] 하네스데이터 fixture 로 e2e 시뮬레이션 (pending → staged → audit, redacted 확인)
- [ ] README.md "현재 릴리즈" 문구 v1.10.0 으로 정정
- [ ] CHANGELOG.md (또는 README CHANGELOG 섹션) v1.10.0 엔트리

## 9. 구현 마일스톤 (v2 — 평가자 권고 8단계)

| 단계 | 내용 | 신규/수정 파일 | 커밋 제목 |
|---|---|---|---|
| **0. Repo 정리** | README 버전 정정, CHANGELOG.md 신규 (또는 정책 확정), `lib/tests/run-all.sh` 신규, hook path → `$CLAUDE_PROJECT_DIR` 마이그레이션 | README.md, CHANGELOG.md, run-all.sh, settings.json, db-read-only.sh, vcs-no-commit.sh | `chore(repo): v1.10 사전 구조 정리` |
| **1. Schema v5 migration** | jq spread 6단계, unknown field 보존 테스트, stamped v4→v5 정상 경로, rollback | HARNESS_SCHEMA.md, harness-state.sh, harness-state.test.sh, fixtures/harness-v4-baseline.json | `feat(schema): v4→v5 자동 마이그레이션 (strict-append)` |
| **2. Privacy-first capture foundation** | `.claude/learnings/` gitignore 강제, `redaction.sh` + `redaction.test.sh`, `ehr_learn_should_capture()` | redaction.sh, redaction.test.sh, learnings.sh (일부), update.sh (gitignore 자동 추가) | `feat(privacy): PII redaction + gitignore 강제` |
| **3. UserPromptSubmit capture hook** | heuristic 매칭, redaction 호출, pending.jsonl append, stdout=0, timeout 3s | learnings.sh, learnings.test.sh, user-prompt-capture.sh, user-prompt-capture.test.sh | `feat(hooks): UserPromptSubmit capture (Phase A)` |
| **4. SessionStart injection** | CLAUDE_ENV_FILE 분기 + additionalContext JSON ≤1KB | session-start-inject.sh, session-start-inject.test.sh | `feat(hooks): SessionStart preferences 주입 (Phase B)` |
| **5. ehr-lessons skill 추가** | EHR4/5 SKILL.md, lazy 2개 (검증 함수 명명 + 회신 템플릿), AGENTS.md.skel eager 2개 (분석 프로토콜 + 운영 상수) | ehr4/skills/ehr-lessons/SKILL.md, ehr5/..., ehr4/skeleton/AGENTS.md.skel, ehr5/... | `feat(skills): ehr-lessons + AGENTS.md eager 지식 (Phase D)` |
| **6. Harvest implementation** | clustering, candidate_rule 추출, score (distinct_sessions, cap), nonce 생성, scope 라벨, LLM 호출 cap=100 | harvest.sh, harvest.test.sh, commands/ehr/harvest-learnings.md | `feat(harvest): /ehr-harvest-learnings (Phase C)` |
| **7. Audit/merge integration** | learnings_drift, EHR_AUDIT_APPROVED + nonce 검증, scope 분기, applied/rejected 전이 | audit.sh, merge.sh, merge.test.sh | `feat(audit): learnings drift + nonce gate` |
| **8. Regression + weight tests** | harness-weight.test.sh (가드 8종), Windows CRLF, jq missing, malformed JSON, redaction, migration rollback 종합 | tests/harness-weight.test.sh | `test: 경량 가드 8종 + 회귀 통합` |
| **9. Docs + version bump** | SKILL.md 흐름도, CHANGELOG v1.10.0, plugin.json 1.9.5→1.10.0 | SKILL.md, CHANGELOG.md, plugin.json | `chore: bump v1.9.5 → v1.10.0` |

(v1 의 12 커밋 → v2 의 10 커밋. 0 단계와 6 단계가 위험을 앞단으로 당김.)

## 10. 보류 항목 결정 (외부 평가자 2차 권고 + 사용자 컨펌 완료)

### 10.1 CHANGELOG 정책
- 옵션 A: `plugins/ehr-harness/CHANGELOG.md` 신규 생성 (Keep a Changelog 형식)
- 옵션 B: 기존 README.md 안의 엔트리 누적 방식 유지

**결정: A** — v1.10 부터 분리. README 기존 history 는 보존, 신규 릴리즈부터 CHANGELOG.md 로 이동. README 에는 "Latest / 주요 변경 요약 / 자세한 변경은 CHANGELOG 참조" 만 남김.

### 10.2 기존 hook path migration 범위
- 옵션 A: 신규 hook 만 `$CLAUDE_PROJECT_DIR` 채택, 기존 db-read-only/vcs-no-commit 은 그대로
- 옵션 B: 모두 마이그레이션

**결정: B** — 모두 마이그레이션. **단 구분 명시**:
- 프로젝트에 생성되는 hook script: `"$CLAUDE_PROJECT_DIR/.claude/hooks/..."`
- 플러그인에 번들된 script: `"${CLAUDE_PLUGIN_ROOT}/..."`

v1.10 의 generated project hook 은 모두 `$CLAUDE_PROJECT_DIR` 기준.

### 10.3 한국어 word boundary 구현
- 옵션 A: bash POSIX 패턴 `[^가-힣A-Za-z0-9]좋아[^가-힣A-Za-z0-9]` (의존성 0)
- 옵션 B: Node 기반 Unicode classifier (정확도 ↑, Node 의존성 추가)

**결정: A + 격리 조건** — `learnings.sh` 안에 흩뿌리지 말고 단일 함수 `ehr_classify_signal()` 로 격리. v1.11+ 에서 Node 교체 가능하도록 인터페이스 안정화.

테스트 기준:
- positive signal fixture: 100% recall
- known false-positive fixture: 100% reject
- 일반 heuristic macro accuracy ≥ 90%

### 10.4 분석 버그 (analyze.sh::collect_law_counts) 동시 수정 여부
평가자 P1-5 지적 — `C_hybrid` 가 controller subset 이 아닌 전체 Java 기준이라 `A_direct_controller` 왜곡 가능.

- 옵션 A: v1.10 scope 외, 별도 follow-up issue 로 spawn
- 옵션 B: v1.10 단계 0 에 포함

**결정: A + 회귀 보호** — v1.10 scope 외, 별도 follow-up issue. **단 v1.10 의 `tests/run-all.sh` 는 기존 `analyze.test.sh` 를 반드시 포함**한다 ("수정 안 함 ≠ 회귀 방치"). 실제 수정은 v1.11 또는 별도 패치.

## 11. 리스크 & 완화 (v1 + v2 보강)

| 리스크 | 완화 |
|---|---|
| 한국어 heuristic false positive | word-boundary POSIX 대안, fixture 30개, rejected.jsonl 동적 추가 |
| `/ehr-harvest-learnings` LLM 호출 비용 | 명시 호출 + 호출당 100건 cap + 권장 빈도 주 1회 |
| Windows 경로/개행 | 기존 `scenarios.test.sh` CRLF 패턴 재사용, fixture LF 고정 |
| v4 사용자 마이그레이션 실패 | 백업 + silent fallback + unknown field 보존 검증 |
| ehr-lessons 15KB 도달 | harvest 가 append 거부 + 오래된 topic 통합 권유 |
| **(v2)** PII 노출 | redaction 강제 + gitignore 강제 + record drop fail-safe |
| **(v2)** 플러그인 소스 자가 수정 | scope=project-local 기본 + cwd 검증 + nonce |
| **(v2)** SessionStart 채널 오인 (env vs context) | 채널별 allowlist 분리 + 테스트 |

## 12. 성숙도 평가 (Before / After) — v1 동일

단계 2 → **단계 3** 도달.

## 13. v1 spec 과의 호환성

- v1 spec (`2026-04-24-self-evolving-harness-v1.10-design.md`) 은 비교용으로 보존.
- 본 v2 가 권위 있는 설계 문서.
- writing-plans 스킬 호출 시 v2 (+ §14 v2.1 patch) 만 참조.

## 14. v2.1 Implementation Guard Patch (외부 평가자 2차 권고 반영)

v2 가 외부 평가에서 "조건부 통과" 판정을 받으며 추가된 8개 구현 안정성·프라이버시 정밀도 보강. v2 본문과 충돌 시 **본 §14 가 우선**한다.

### 14.1 SessionStart JSON size handling — `head -c` 절단 금지

**문제**: v2 §5.2 의 `head -c 1024` 는 (1) UTF-8 멀티바이트 중간 절단 (2) JSON 닫는 `}` 절단 → invalid JSON 가능.

**수정안**:
- `additionalContext` **문자열만 먼저 축약**, JSON 은 항상 마지막에 `jq -nc` 로 생성.
- 출력 직전 `wc -c <= 1024` 및 `jq -e .` 두 검증 모두 통과해야 함.
- 실패 시 stdout 0, exit 0 (silent skip).

**구현 패턴**:
```bash
max_ctx_bytes=700  # JSON 오버헤드 여유

additional_context=$(printf 'EHR harness preferences: 응답 톤=%s, 언어=%s, 제안 모드=%s, DB 권한=%s' \
  "$tone" "$lang" "$suggest_mode" "$db_auth")

# 문자열만 byte 단위 축약 (UTF-8 안전한 절단)
additional_context=$(printf '%s' "$additional_context" | awk -v max="$max_ctx_bytes" '
  { s=$0; while (length(s) > max) s=substr(s, 1, length(s)-1); print s }')

ctx=$(jq -nc --arg ctx "$additional_context" '{
  hookSpecificOutput: { hookEventName: "SessionStart", additionalContext: $ctx }
}')

if [ "$(printf '%s' "$ctx" | wc -c)" -le 1024 ] && printf '%s' "$ctx" | jq -e . >/dev/null 2>&1; then
  printf '%s' "$ctx"
else
  exit 0
fi
```

**테스트 추가** (`session-start-inject.test.sh`):
- long Korean context input → output ≤ 1024B
- `jq -e .` 통과
- no partial UTF-8 / no broken JSON

### 14.2 Redaction state fields — 의미 분리

**문제**: v2 의 `redaction_applied:true` 가 없으면 drop 정책이, PII 없는 정상 prompt 까지 drop 시킴.

**수정안**: 단일 boolean 을 3개 필드로 분리.

```json
{
  "redaction_checked": true,
  "redaction_count": 0,
  "redaction_failed": false,
  "sensitivity": "low" | "possible_pii"
}
```

**Drop 조건** (AND 가 아닌 OR — 셋 중 하나라도 충족 시 drop):
- `redaction_checked != true` (검사 자체가 안 돔)
- `redaction_failed == true` (스캐너 오류)
- redaction 후 잔존 PII 패턴이 detected

**유지 조건**: `redaction_checked == true && redaction_failed == false` 이면 `redaction_count == 0` 이어도 저장 가능 (PII 없는 정상 record).

**가드 7 갱신**: "Redaction 미적용 record drop" → "Redaction 검사 미수행 또는 실패 record drop".

### 14.3 Privacy-safe hashes — raw 원문 기반 sha256 금지

**문제**: 사번/날짜/조직코드는 값공간이 좁아 dictionary/brute-force 가능. raw 원문 sha256 도 PII 파생값.

**수정안 (단순 옵션 채택)**:
- `snippet_hash` = `sha256(redacted_normalized_snippet)` — dedupe 목적이면 redacted 기반으로 충분
- `session_hash` = `sha256(redacted_session_marker)` — session linkage 목적
- HMAC + project_secret 옵션은 v1.11+ 보강 (secret 저장 위치 결정 필요해서 v1.10 scope 외)

`pending.jsonl` 스키마:
```json
{
  "schema_version": 1,
  "ts": "2026-04-25T...",
  "session_hash": "sha256:<redacted-session-marker>",
  "kind": "correction" | "success",
  "score_delta": 1 | 2,
  "prompt_snippet_redacted": "...",
  "prev_turn_snippet_redacted": "...",
  "snippet_hash": "sha256:<redacted-content>",
  "redaction_checked": true,
  "redaction_count": 0,
  "redaction_failed": false,
  "sensitivity": "low",
  "candidate_rule": null,
  "tool_context": {"last_skill": "...", "last_tool": "..."},
  "profile": "ehr4"
}
```

### 14.4 EHR_NONCE 형식 정확성

**문제**: v2 §5.4 의 `export EHR_NONCE=$(cat staged/topic.md | sha256sum)` → 출력이 `<hash>  -` 두 토큰 → merge 의 `cut -d' ' -f1` 비교와 mismatch.

**수정안**:
```bash
export EHR_NONCE="$(sha256sum "$staged_path" | awk '{print $1}')"
```

**검증**:
- 정규식 `^[a-f0-9]{64}$` 통과 필수
- `merge.test.sh` 에 케이스 추가:
  - 정상: 64자리 lowercase hex
  - 거부: `<hash>  -` 형태, 대문자 hex, 길이 미달

### 14.5 org-template scope reserved (v1.10)

**수정안**: `merge.sh::apply_staged()` 의 scope switch:
```bash
case "$scope" in
  project-local) apply_project_local ;;
  plugin-dev)    apply_plugin_dev ;;
  org-template)
    echo "FATAL: org-template scope is reserved in v1.10" >&2
    exit 5
    ;;
  *)
    echo "FATAL: unknown scope: $scope" >&2
    exit 6
    ;;
esac
```

`merge.test.sh` 에 reserved scope exit 5 / unknown exit 6 케이스 추가.

### 14.6 v4→v5 canonical hash volatile 제외 범위 확장

**문제**: v2 §6.2 는 `schema_version`, `last_harvest_at`, `staged_nonces` 만 제외. counter 들이 hash 에 포함되면 harvest 만 해도 hash 변동 → "내용 동일 → hash 동일" 의도 깨짐.

**수정안** — 제외 범위 확장:
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

**유지** (설정값 성격 → hash 포함):
- `learnings_meta.promotion_policy` (success_weight, threshold 등)
- `learnings_meta.capture_enabled`

### 14.7 jq missing fallback — Phase B 명시

**수정안**: `session-start-inject.sh` 에 jq 의존 분기 명시.
- jq 있음 → JSON additionalContext 출력 + `CLAUDE_ENV_FILE` 둘 다
- jq 없음 → `CLAUDE_ENV_FILE` 만 처리, stdout 0, exit 0
- v2.1 에 명시 + 테스트 케이스 (`jq` PATH 제거 후 hook 실행, exit 0 + stdout empty 검증)

### 14.8 hook-degraded.flag 위치

**수정안**: `.claude/learnings/hook-degraded.flag` → `.claude/.ehr-hook-degraded.flag` (learnings 디렉토리 외부).

**근거**: gitignore 미적용 상황에서 `.claude/learnings/` 안에 파일 만드는 모양이 어색. `.claude/` 직접에 두면 명확.

**테스트 추가**: errors.log 와 flag 모두 민감 데이터 미저장 검증.

---

**Next**: writing-plans 스킬 호출 → 10단계 implementation plan 생성 → TDD 실행.
