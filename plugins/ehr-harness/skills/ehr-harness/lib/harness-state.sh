#!/usr/bin/env bash
# harness-state.sh — HARNESS.json 읽기/쓰기/diff 헬퍼
#
# 사용 예:
#   source harness-state.sh
#   hs_sha256 path/to/file
#   hs_load_manifest .claude/HARNESS.json
#   hs_classify_file ".claude/HARNESS.json" "src.skel" "/abs/src.skel" "out.md" "/abs/out.md"

set -u

HS_SCHEMA_VERSION=4
# 이전 버전 중 stamped 로 간주하는 값 (마이그레이션 유예).
# v3 사용자가 v1.9.0 플러그인으로 업데이트했을 때 즉시 legacy 로 재분류되어
# adopt 플로우에 빠지는 혼란을 막는다. 다음 업데이트 시 매니페스트가 v4 로 갱신된다.
HS_SCHEMA_VERSION_STAMPED="3 4"

# ── sha256 계산 (cross-platform) ──
hs_sha256() {
  local path="$1"
  if [ ! -f "$path" ]; then
    echo ""
    return 0
  fi
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum "$path" | awk '{print "sha256:"$1}'
  elif command -v shasum >/dev/null 2>&1; then
    shasum -a 256 "$path" | awk '{print "sha256:"$1}'
  else
    node -e "
      const fs=require('fs'),c=require('crypto');
      const h=c.createHash('sha256').update(fs.readFileSync(process.argv[1])).digest('hex');
      console.log('sha256:'+h);
    " "$path"
  fi
}

# ── 매니페스트 읽기 (없으면 빈 객체) ──
hs_load_manifest() {
  local path="$1"
  if [ ! -f "$path" ]; then
    echo "{}"
    return 0
  fi
  cat "$path"
}

# ── 매니페스트가 legacy 인지 (= 없거나 schema_version 누락) ──
# return code: 0 = legacy, 1 = stamped
hs_is_legacy() {
  local path="$1"
  if [ ! -f "$path" ]; then
    return 0  # legacy
  fi
  local sv
  sv=$(MFP="$path" node -e "
    try{
      const m=JSON.parse(require('fs').readFileSync(process.env.MFP,'utf8'));
      process.stdout.write(String(m.schema_version||''));
    }catch(e){process.stdout.write('');}
  ")
  if [ -z "$sv" ]; then
    return 0  # legacy (missing schema_version)
  fi
  # HS_SCHEMA_VERSION_STAMPED 에 포함되면 stamped (v3/v4 공존 허용)
  for allowed in $HS_SCHEMA_VERSION_STAMPED; do
    if [ "$sv" = "$allowed" ]; then
      return 1  # stamped
    fi
  done
  return 0  # legacy (version not in allowed set)
}

# ── 매니페스트에서 outputs[path] 의 sha 조회 ──
hs_get_output_sha() {
  local manifest_path="$1"
  local key="$2"
  MFP="$manifest_path" KEY="$key" node -e "
    try{
      const m=JSON.parse(require('fs').readFileSync(process.env.MFP,'utf8'));
      process.stdout.write((m.outputs && m.outputs[process.env.KEY]) || '');
    }catch(e){process.stdout.write('');}
  "
}

# ── 매니페스트에서 sources[path] 의 sha 조회 ──
hs_get_source_sha() {
  local manifest_path="$1"
  local key="$2"
  MFP="$manifest_path" KEY="$key" node -e "
    try{
      const m=JSON.parse(require('fs').readFileSync(process.env.MFP,'utf8'));
      process.stdout.write((m.sources && m.sources[process.env.KEY]) || '');
    }catch(e){process.stdout.write('');}
  "
}

# ── 단일 출력 파일을 5가지 bucket 으로 분류 ──
# args: manifest_path source_key source_abs output_key output_abs
# print one of: unchanged | safe-update | user-only | conflict | new
hs_classify_file() {
  local manifest_path="$1"
  local source_key="$2"
  local source_abs="$3"
  local output_key="$4"
  local output_abs="$5"

  local stored_src stored_out current_src current_out
  stored_src=$(hs_get_source_sha "$manifest_path" "$source_key")
  stored_out=$(hs_get_output_sha "$manifest_path" "$output_key")
  current_src=$(hs_sha256 "$source_abs")
  current_out=$(hs_sha256 "$output_abs")

  # 매니페스트에도 없고 출력 파일도 없음 → 새 파일
  if [ -z "$stored_out" ] && [ -z "$current_out" ]; then
    echo "new"
    return 0
  fi
  # 매니페스트에는 있지만 출력 파일이 사라짐 → 새 파일로 취급(다시 만들면 됨)
  if [ -z "$current_out" ]; then
    echo "new"
    return 0
  fi
  # 출력은 있는데 매니페스트에 기록 없음 → user-only 로 취급(상위에서 legacy 처리할 것)
  if [ -z "$stored_out" ]; then
    echo "user-only"
    return 0
  fi

  local src_changed=0 user_edited=0
  if [ "$stored_src" != "$current_src" ]; then src_changed=1; fi
  if [ "$stored_out" != "$current_out" ]; then user_edited=1; fi

  if [ $src_changed -eq 0 ] && [ $user_edited -eq 0 ]; then
    echo "unchanged"
  elif [ $src_changed -eq 1 ] && [ $user_edited -eq 0 ]; then
    echo "safe-update"
  elif [ $src_changed -eq 0 ] && [ $user_edited -eq 1 ]; then
    echo "user-only"
  else
    echo "conflict"
  fi
}

# ── 매니페스트 새로 작성 ──
# args: manifest_path plugin_version profile sources_json outputs_json
#       [generated_at] [auth_model_json] [db_verification_json] [ddl_authoring_json] [analysis_json]
#       [ehr_cycle_json]
# v4 확장: 11번째 인자 ehr_cycle_json.
#   - "null" 또는 빈 값: 기존 manifest 의 ehr_cycle 을 보존 (없으면 기본 빈 구조 주입).
#   - 유효 JSON: 해당 값으로 덮어씀.
# 불변식 3: EHR-PREFERENCES 는 CLAUDE.md 에 저장되므로 본 함수는 관여하지 않음.
hs_write_manifest() {
  local manifest_path="$1"
  local plugin_version="$2"
  local profile="$3"
  local sources_json="$4"
  local outputs_json="$5"
  local generated_at="${6:-$(date -Iseconds 2>/dev/null || date +%Y-%m-%dT%H:%M:%S%z)}"
  local auth_model_json="${7:-null}"
  local db_verification_json="${8:-null}"
  local ddl_authoring_json="${9:-null}"
  local analysis_json="${10:-null}"
  local ehr_cycle_json="${11:-null}"
  local updated_at
  updated_at=$(date -Iseconds 2>/dev/null || date +%Y-%m-%dT%H:%M:%S%z)

  mkdir -p "$(dirname "$manifest_path")"

  MFP="$manifest_path" \
  PV="$plugin_version" \
  PROF="$profile" \
  SRC_JSON="$sources_json" \
  OUT_JSON="$outputs_json" \
  AUTH_JSON="$auth_model_json" \
  DBV_JSON="$db_verification_json" \
  DDL_JSON="$ddl_authoring_json" \
  ANA_JSON="$analysis_json" \
  EHR_JSON="$ehr_cycle_json" \
  GEN="$generated_at" \
  UPD="$updated_at" \
  SV="$HS_SCHEMA_VERSION" \
  node -e "
    const fs=require('fs');
    const parse = (s, name) => {
      if (!s || s==='null') return null;
      try { return JSON.parse(s); }
      catch(e) { console.error('hs_write_manifest: invalid JSON for ' + name + ': ' + e.message); process.exit(1); }
    };
    // ehr_cycle 보존 규칙: 인자 null 이면 기존 매니페스트에서 승계, 없으면 기본 구조.
    let ehrCycle = parse(process.env.EHR_JSON, 'ehr_cycle');
    if (ehrCycle == null) {
      try {
        const prev = JSON.parse(fs.readFileSync(process.env.MFP, 'utf8'));
        if (prev && prev.ehr_cycle) ehrCycle = prev.ehr_cycle;
      } catch(e) { /* no previous manifest — fall through */ }
    }
    if (ehrCycle == null) {
      ehrCycle = { version: 1, compounds: [], promoted: [], preferences_history: [] };
    }
    const m={
      schema_version: Number(process.env.SV),
      plugin_name: 'ehr-harness',
      plugin_version: process.env.PV,
      profile: process.env.PROF,
      generated_at: process.env.GEN,
      updated_at: process.env.UPD,
      sources: JSON.parse(process.env.SRC_JSON),
      outputs: JSON.parse(process.env.OUT_JSON),
      auth_model: parse(process.env.AUTH_JSON, 'auth_model'),
      db_verification: parse(process.env.DBV_JSON, 'db_verification'),
      ddl_authoring: parse(process.env.DDL_JSON, 'ddl_authoring'),
      analysis: parse(process.env.ANA_JSON, 'analysis'),
      ehr_cycle: ehrCycle,
    };
    fs.writeFileSync(process.env.MFP, JSON.stringify(m, null, 2));
  "
}

# ── 매니페스트에서 ehr_cycle 객체 JSON 문자열로 반환 (없으면 빈 구조) ──
hs_get_ehr_cycle() {
  local manifest_path="$1"
  MFP="$manifest_path" node -e "
    const empty = { version: 1, compounds: [], promoted: [], preferences_history: [] };
    try {
      const m = JSON.parse(require('fs').readFileSync(process.env.MFP, 'utf8'));
      process.stdout.write(JSON.stringify(m.ehr_cycle || empty));
    } catch(e) {
      process.stdout.write(JSON.stringify(empty));
    }
  "
}

# ── plugin.json 에서 version 읽기 ──
hs_plugin_version() {
  local plugin_root="$1"
  PR="$plugin_root" node -e "
    try{
      const p=process.env.PR + '/.claude-plugin/plugin.json';
      const m=JSON.parse(require('fs').readFileSync(p,'utf8'));
      process.stdout.write(m.version||'unknown');
    }catch(e){process.stdout.write('unknown');}
  "
}

# ── 매니페스트에서 generated_at 읽기 (없으면 빈 문자열) ──
hs_get_generated_at() {
  local manifest_path="$1"
  MFP="$manifest_path" node -e "
    try{
      const m=JSON.parse(require('fs').readFileSync(process.env.MFP,'utf8'));
      process.stdout.write(m.generated_at||'');
    }catch(e){process.stdout.write('');}
  "
}

# ── 매니페스트에서 profile 읽기 ──
hs_get_profile() {
  local manifest_path="$1"
  MFP="$manifest_path" node -e "
    try{
      const m=JSON.parse(require('fs').readFileSync(process.env.MFP,'utf8'));
      process.stdout.write(m.profile||'');
    }catch(e){process.stdout.write('');}
  "
}

# ── 매니페스트에서 analysis 객체 읽기 (없으면 문자열 "null") ──
hs_get_analysis() {
  local manifest_path="$1"
  MFP="$manifest_path" node -e "
    try{
      const m=JSON.parse(require('fs').readFileSync(process.env.MFP,'utf8'));
      if (m.analysis == null) {
        process.stdout.write('null');
      } else {
        process.stdout.write(JSON.stringify(m.analysis));
      }
    }catch(e){process.stdout.write('null');}
  "
}
