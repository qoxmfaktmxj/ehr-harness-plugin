# HARNESS.json Schema

`.claude/HARNESS.json` 은 ehr-harness 메타 스킬이 생성한 하네스의 상태 매니페스트다.
업데이트 모드가 이 파일을 읽고 비교해 변경분을 산출한다.

## Schema (version 2)

```json
{
  "schema_version": 2,
  "plugin_name": "ehr-harness",
  "plugin_version": "1.1.0",
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

## 기존 필드 의미 (v1 그대로)

| 필드 | 설명 |
|------|------|
| `schema_version` | 매니페스트 자체 스키마 버전. **v2로 bump됨**. v1 매니페스트는 legacy 처리. |
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
| `legacy` | 매니페스트 없음 + 하네스 흔적 있음 (AGENTS.md 등) 또는 schema_version ≠ 2 | adopt vs 전체 재생성 vs 취소 |
| `stamped` | 매니페스트 존재 + schema_version == 2 | 업데이트 모드 (3-bucket diff) |

## 마이그레이션 (v1 → v2)

v1 매니페스트는 `hs_is_legacy` 가 `legacy` 로 분류하여 사용자에게 adopt 여부를 묻는다. adopt 선택 시 Step 4-G 가 새 감별 결과와 함께 v2 매니페스트를 기록한다.
