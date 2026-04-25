# HARNESS.json Schema

`.claude/HARNESS.json` 은 ehr-harness 메타 스킬이 생성한 하네스의 상태 매니페스트다.
업데이트 모드가 이 파일을 읽고 비교해 변경분을 산출하고, audit 모드는 `analysis` 필드를 baseline 으로 현재 프로젝트와의 drift 를 검사한다.

## Schema (version 3) *(이전 사양 — 아래 "Schema (version 4) — EHR Cycle 도입" 섹션 참조)*

> 이 섹션은 v3 구조를 그대로 보존한다. 현재 플러그인(v1.9.0+)은 **v4 를 기본으로 기록**하고 v3 은 stamped 집합에 포함해 마이그레이션 유예 기간을 제공한다. 신규 항목/변경점은 v4 섹션을 볼 것.

```json
{
  "schema_version": 3,
  "plugin_name": "ehr-harness",
  "plugin_version": "1.3.0",
  "profile": "ehr5",
  "generated_at": "2026-04-15T12:34:56+09:00",
  "updated_at": "2026-04-15T12:34:56+09:00",
  "sources": {
    "profiles/shared/settings.json": "sha256:abc...",
    "profiles/ehr5/skeleton/AGENTS.md.skel": "sha256:def..."
  },
  "outputs": {
    ".claude/settings.json": "sha256:111...",
    "AGENTS.md": "sha256:222..."
  },
  "auth_model": {
    "common_controllers": ["GetDataList", "SaveData"],
    "auth_service_class": "AuthTableService",
    "auth_injection_methods": ["query_placeholder"],
    "auth_tables": ["THRM151_AUTH"],
    "auth_functions": ["F_COM_GET_SQL_AUTH"],
    "session_vars": ["ssnEnterCd", "ssnSabun", "ssnSearchType"]
  },
  "db_verification": {
    "ddl_path": "src/main/resources/db/tables",
    "db_access": "available",
    "b3_strategy": "ddl-first"
  },
  "ddl_authoring": {
    "enabled": true,
    "table_path": "src/main/resources/db/tables",
    "procedure_path": "src/main/resources/db/procedures",
    "function_path": "src/main/resources/db/functions",
    "naming_pattern": "{OBJECT_NAME}.sql",
    "header_template_path": "src/main/resources/db/_template.sql",
    "existing_tables": ["THRM101", "THRM151_AUTH"]
  },
  "analysis": {
    "analyzed_at": "2026-04-15T14:23:01+09:00",
    "module_map": [
      { "name": "hrm", "file_count": 120 },
      { "name": "cpn", "file_count": 95 }
    ],
    "session_vars": ["ssnEnterCd", "ssnSabun", "ssnSearchType"],
    "authSqlID": ["THRM151", "TORG101"],
    "law_counts": {
      "A_direct_controller": 45,
      "B_getData": 79,
      "B_saveData": 68,
      "C_hybrid": 12,
      "D_execPrc": 15
    },
    "critical_proc_found": [
      "P_CPN_CAL_PAY_MAIN",
      "P_HRM_POST",
      "P_HRI_AFTER_PROC_EXEC"
    ],
    "critical_proc_missing": ["P_TIM_WORK_HOUR_CHG"],
    "procedure_count": 234,
    "procedure_sample": [
      "P_CPN_CAL_PAY_MAIN",
      "P_HRI_AFTER_PROC_EXEC",
      "PKG_CPN_SEP"
    ],
    "trigger_count": 18
  }
}
```

## 신규 필드 의미 (v2)

### `auth_model`

프로젝트의 권한 주입 방식을 감별한 결과. reviewer가 조건부 검증에 사용.

| 필드 | 설명 |
|------|------|
| `common_controllers` | 실재하는 공통 컨트롤러 이름 배열. `GetDataList`, `SaveData`, `ExecPrc` 중 프로젝트에 있는 것만. 없으면 `[]`. 법칙 B 체크는 이 배열이 비어있지 않을 때만 수행. |
| `auth_service_class` | `AuthTableService` 같은 권한 서비스 클래스명. 없으면 `null`. 법칙 C 체크는 이 값이 null이 아닐 때만 수행. |
| `auth_injection_methods` | `query_placeholder` (Velocity `$query` / MyBatis `${query}`), `auth_table_join` (권한 테이블 INNER JOIN), `auth_function_call` (함수 호출) 중 프로젝트가 쓰는 방식. 빈 배열 가능. |
| `auth_tables` | `THRM151_AUTH`, `THRM152_AUTH_MENU` 등 실재하는 권한 테이블. reviewer가 `auth_table_join` 검증 시 조인 대상 확인에 사용. |
| `auth_functions` | `F_COM_GET_SQL_AUTH` 같은 권한 함수. 없으면 `[]`. |
| `session_vars` | 감지된 세션 변수 목록. 최소 `ssnEnterCd`, `ssnSabun` 포함. |

### `db_verification`

| 필드 | 설명 |
|------|------|
| `ddl_path` | repo 내 DDL 테이블 폴더 경로 (있을 때만). 없으면 `null`. |
| `db_access` | `available` (DB 접속 가능) / `unavailable` (접속 불가) / `dump-only` (DDL 덤프만). |
| `b3_strategy` | reviewer가 B3(컬럼 ↔ DDL) 검증 시 사용할 전략. `ddl-first` (DDL 파일 우선) / `db-only` (DB만) / `manual-required` (수동 확인). |

### `ddl_authoring`

신규 DDL 파일 자동 생성 기능 설정. screen-builder가 참조.

| 필드 | 설명 |
|------|------|
| `enabled` | `true` 면 screen-builder가 DDL 파일 자동 생성 가능. DDL 폴더가 없으면 `false`. |
| `table_path` / `procedure_path` / `function_path` | 각 객체 타입별 디렉토리 경로. 없으면 `null`. 트리거는 치명 등급 위험으로 지원 안 함. |
| `naming_pattern` | 기존 파일 명명 규칙 추출. 예: `{OBJECT_NAME}.sql`, `TBL_{OBJECT_NAME}.sql`, `YYYYMMDD_{OBJECT_NAME}.sql`. |
| `header_template_path` | 기존 DDL의 헤더 주석 템플릿. 없으면 `null`. |
| `existing_tables` | 중복 방지용 기존 테이블 이름 세트. |

### `analysis` (v3 신규)

프로젝트 심층 분석 결과 스냅샷. audit 모드가 drift 계산의 기준점으로 사용한다. SKILL.md `Step 2-N` 에서 `analyze.sh::build_analysis_json` 이 생성하고, `Step AUDIT-1` 이 현재 프로젝트 상태와 비교하여 drift 를 산출한다. AGENTS.md 의 `## 분석 스냅샷` 섹션에 렌더된 값이 이 필드와 동기화된다.

| 필드 | 설명 |
|------|------|
| `analyzed_at` | 이 스냅샷이 생성된 시각 (ISO 8601). audit 리포트에 "N일 전 분석" 표시용. |
| `module_map` | `{name, file_count}` 배열. 모듈 추가/삭제/크기 변화 감지. |
| `session_vars` | 감지된 세션 변수 배열. 권한 모델 변화 감지. |
| `authSqlID` | 권한 쿼리 매퍼 ID 배열. |
| `law_counts` | 법칙 A/B/C/D별 카운트 객체. 절대값 5 이상 OR 10% 이상 변화시 drift 보고. |
| `critical_proc_found` | 코드에서 호출 확인된 치명 프로시저. 추가 시 상급 drift (reviewer 체크 영향). |
| `critical_proc_missing` | 고정 목록에 있지만 코드에 없는 것. 참고용. |
| `procedure_count` | 전체 프로시저 호출 수. |
| `procedure_sample` | 상위 20개 프로시저 이름 (비교 안 함, 정보성). |
| `trigger_count` | 전체 트리거 호출 수. |

**저장 원칙**: 전체 목록이 큰 필드는 `_count` + `_sample`만 기록. 전체는 `procedure-tracer` 스킬이 동적 grep.

**기록 시점**: `analysis` 는 fresh/legacy-adopt/stamped 재생성/audit 적용 시마다 새로 기록된다. audit 전략 `2 (보고서만)` 는 `analyzed_at` 만 갱신하고 다른 필드는 그대로 둔다 (baseline 유지).

## 기존 필드 의미 (v1 그대로)

| 필드 | 설명 |
|------|------|
| `schema_version` | 매니페스트 자체 스키마 버전. **현재 v4** (EHR Cycle 도입). v3 도 stamped 로 허용(마이그레이션 유예). v1/v2 는 legacy 처리. |
| `plugin_name` | 항상 `"ehr-harness"`. |
| `plugin_version` | 생성 당시 plugin.json 의 version. 사람이 읽기 쉬운 정보 + 빠른 비교용. |
| `profile` | `"ehr4"` 또는 `"ehr5"`. 프로파일이 바뀌면 거의 모든 파일이 충돌하므로 별도 처리. |
| `generated_at` | 최초 생성 시각 (이후 변하지 않음). |
| `updated_at` | 마지막 업데이트 시각. |
| `sources` | 플러그인 측 원본 파일들의 sha. 키는 plugin root 기준 상대 경로. 비교 대상: 현재 파일의 sha. 다르면 = 플러그인이 갱신됨. |
| `outputs` | 프로젝트에 생성한 결과물들의 sha. 키는 프로젝트 root 기준 상대 경로. 비교 대상: 현재 파일의 sha. 다르면 = 사용자가 편집함. |

## bucket 분류 규칙 (v1 그대로)

각 출력 파일에 대해:

| 소스 변경 | 사용자 편집 | bucket |
|-----------|-------------|--------|
| no  | no  | `unchanged` |
| yes | no  | `safe-update` |
| no  | yes | `user-only` (그대로 둠) |
| yes | yes | `conflict` |

소스 파일은 보통 1:1 매핑이지만, 프로파일 스킬처럼 1:1 인 경우와 `shared/settings.json` 처럼 단일 출력으로 가는 경우 모두 같은 규칙으로 처리된다. 매핑은 `harness-state.sh` 의 `SOURCE_MAP` 빌더에서 단일 출처로 정의한다.

## 진입 모드 (HARNESS_MODE)

| 값 | 조건 | 동작 |
|----|------|------|
| `fresh` | 매니페스트 없음 + 하네스 흔적 없음 | 기존 흐름(전체 생성) |
| `legacy` | 매니페스트 없음 + 하네스 흔적 있음 (AGENTS.md 등) 또는 schema_version ∉ {3, 4} | adopt vs 전체 재생성 vs 취소 |
| `stamped` | 매니페스트 존재 + schema_version ∈ {3, 4} | 업데이트 모드 (3-bucket diff, 플러그인 업데이트) |
| `audit` | 매니페스트 존재 + schema_version ∈ {3, 4} + 사용자가 audit 키워드로 트리거 | 저장된 `analysis` vs 현재 재실행한 `analysis` 를 diff → 드리프트 검사 + 반자동 반영 (신규) |

> 허용 집합(`{3, 4}`)은 [harness-state.sh](./harness-state.sh) 의 `HS_SCHEMA_VERSION_STAMPED` 가 단일 출처. v3 사용자가 v1.9.0+ 플러그인으로 업그레이드했을 때 즉시 legacy 로 재분류되지 않도록 공존 허용.

## 마이그레이션 (v1/v2 → 현재)

v1/v2 매니페스트는 `hs_is_legacy` 가 `legacy` 로 분류하여 사용자에게 adopt 여부를 묻는다. adopt 선택 시 Step 4-G 가 새 감별 결과 + analysis 스냅샷과 함께 **현재 버전(v4)** 매니페스트를 기록한다.

- v1 → v4: 완전 재생성 (analysis 최초 기록). 이전 stamped 상태가 없으므로 audit 진입 시 baseline 모드로 동작.
- v2 → v4: auth_model/db_verification/ddl_authoring 유지 + analysis 추가. audit 가 바로 의미있는 drift 를 반환하려면 최소 1 회의 재생성이 필요하다 (analysis 없이는 비교 baseline 이 없음).
- v3 → v4: **자동 유예** — v3 매니페스트는 stamped 로 계속 인식되고 다음 하네스 업데이트 시 `ehr_cycle` 섹션 + 신규 `outputs[]` 엔트리를 추가하며 `schema_version` 이 4 로 갱신된다. 사용자 adopt 플로우 없이 진행.

## Schema (version 4) — EHR Cycle 도입

v3 에 **`ehr_cycle` 섹션**을 추가하고 `outputs[]` 에 신규 7개 엔트리를 기록한다.

```json
{
  "schema_version": 4,
  "plugin_version": "1.9.0",
  "profile": "ehr5",

  // ... 기존 v3 필드 전부 유지 ...

  "outputs": {
    // 기존 항목에 더해:
    ".claude/commands/ehr/ideate.md":    "sha256:...",
    ".claude/commands/ehr/plan.md":      "sha256:...",
    ".claude/commands/ehr/work.md":      "sha256:...",
    ".claude/commands/ehr/review.md":    "sha256:...",
    ".claude/commands/ehr/compound.md":  "sha256:...",
    ".claude/agents/db-impact-reviewer.md": "sha256:..."
  },

  "ehr_cycle": {
    "version": 1,
    "compounds": [
      {
        "id": "2026-04-18-paycalc-trigger",
        "ts": "2026-04-18T14:22:01+09:00",
        "level": "L2",
        "domain": "code_map",
        "files": ["reference/CODE_MAP.md"],
        "revision": 1
      }
    ],
    "promoted": [
      {
        "id": "pay-closing-no-direct-update",
        "ts": "2026-04-20T09:15:00+09:00",
        "src_compound_id": "pay-closing-no-direct-update",
        "target_file": "agents/release-reviewer.md",
        "backup": ".ehr-bak/release-reviewer.md.20260420T091500.bak",
        "retain": false,
        "backup_cleaned": false
      }
    ],
    "preferences_history": [
      {
        "ts": "2026-04-18T16:40:00+09:00",
        "key": "SUGGEST_MODE",
        "from": "ask",
        "to": "silent",
        "trigger": "역질문하지마"
      }
    ]
  }
}
```

### `ehr_cycle` 필드 의미

| 필드 | 타입 | 설명 |
|---|---|---|
| `version` | int | ehr_cycle 서브스키마 버전 (현재 1) |
| `compounds[]` | array | L2 회수 이력 |
| `compounds[].id` | string | 마커 slug-id |
| `compounds[].ts` | ISO-8601 | 최초 생성 시각 |
| `compounds[].level` | `"L2"`\|`"L3"` | 쓰기 층위 (L3 은 별도 `promoted[]` 에도 기록) |
| `compounds[].domain` | enum | `code_map`\|`db_map`\|`domain_knowledge`\|`preferences` |
| `compounds[].files[]` | array | 블록이 작성된 파일 경로 |
| `compounds[].revision` | int | 같은 id 갱신 횟수 (자동 승급 트리거 근거) |
| `promoted[]` | array | L3 승급 이력 |
| `promoted[].backup` | path | `.ehr-bak/` 내 백업 경로 |
| `promoted[].retain` | bool | `true` 면 자동 정리 제외 |
| `promoted[].backup_cleaned` | bool | `BACKUP_RETENTION_DAYS` 만료로 백업 삭제됨 — 복원 불가 |
| `preferences_history[]` | array | 선호 변경 로그 |

### 4대 불변식 (재생성 시 절대 침해 금지)

1. 사용자의 L2 지식 (`EHR-COMPOUND` 블록)
2. 사용자의 L3 승급 (`EHR-PROMOTED` 블록)
3. 사용자의 협업 선호 (`EHR-PREFERENCES` 블록)
4. 사용자 작업물 (`.ehr-bak/`, `docs/ehr/*`)

### v3 → v4 마이그레이션

`HARNESS.json.schema_version == 3` 감지 시:
1. `ehr_cycle: { version:1, compounds:[], promoted:[], preferences_history:[] }` 주입
2. `outputs[]` 에 신규 7개 엔트리(커맨드 5 + 에이전트 1 + 해시는 생성 후 계산) 추가
3. `schema_version: 4`, `plugin_version: "1.9.0"` 기록

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
| `last_harvest_at` | 마지막 `/ehr-harvest-learnings` 실행 시각. null = 미실행. |
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

`harness-state.sh::ehr_state_migrate_v4_to_v5(path)` 가 6단계 처리:

1. 백업: `.ehr-bak/harness-v4-${ts}.json`
2. jq spread 로 unknown field 보존 + `learnings_meta` 추가
3. schema validation (`schema_version == 5 && .ehr_cycle.learnings_meta != null`)
4. unknown field 보존 검증 — `del(.schema_version, .ehr_cycle.learnings_meta)` 결과가 v4 와 동일한지 diff
5. canonical hash 갱신 (위 제외 필드 기준)
6. 원자 교체. 실패 시 백업 복원 + `migration-failed.log` + v4 fallback.
