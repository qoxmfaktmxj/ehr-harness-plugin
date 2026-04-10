# HARNESS.json Schema

`.claude/HARNESS.json` 은 ehr-harness 메타 스킬이 생성한 하네스의 상태 매니페스트다.
업데이트 모드가 이 파일을 읽고 비교해 변경분을 산출한다.

## Schema (version 1)

```json
{
  "schema_version": 1,
  "plugin_name": "ehr-harness",
  "plugin_version": "1.0.0",
  "profile": "ehr5",
  "generated_at": "2026-04-10T12:34:56+09:00",
  "updated_at": "2026-04-10T12:34:56+09:00",
  "sources": {
    "profiles/shared/settings.json": "sha256:abc...",
    "profiles/ehr5/skeleton/AGENTS.md.skel": "sha256:def..."
  },
  "outputs": {
    ".claude/settings.json": "sha256:111...",
    "AGENTS.md": "sha256:222..."
  }
}
```

## 필드 의미

| 필드 | 설명 |
|------|------|
| `schema_version` | 매니페스트 자체 스키마 버전. 호환되지 않게 바뀌면 +1. |
| `plugin_name` | 항상 `"ehr-harness"`. |
| `plugin_version` | 생성 당시 plugin.json 의 version. 사람이 읽기 쉬운 정보 + 빠른 비교용. |
| `profile` | `"ehr4"` 또는 `"ehr5"`. 프로파일이 바뀌면 거의 모든 파일이 충돌하므로 별도 처리. |
| `generated_at` | 최초 생성 시각 (이후 변하지 않음). |
| `updated_at` | 마지막 업데이트 시각. |
| `sources` | 플러그인 측 원본 파일들의 sha. 키는 plugin root 기준 상대 경로. 비교 대상: 현재 파일의 sha. 다르면 = 플러그인이 갱신됨. |
| `outputs` | 프로젝트에 생성한 결과물들의 sha. 키는 프로젝트 root 기준 상대 경로. 비교 대상: 현재 파일의 sha. 다르면 = 사용자가 편집함. |

## bucket 분류 규칙

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
| `legacy` | 매니페스트 없음 + 하네스 흔적 있음 (AGENTS.md 등) | adopt vs 전체 재생성 vs 취소 |
| `stamped` | 매니페스트 존재 + schema_version 정상 | 업데이트 모드 (3-bucket diff) |
