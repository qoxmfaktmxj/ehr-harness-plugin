#!/usr/bin/env bash
# harness-state.test.sh — harness-state.sh 단위 테스트
#
# 실행: bash harness-state.test.sh

set -u

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck disable=SC1091
source "$SCRIPT_DIR/harness-state.sh"

FIXTURES="$SCRIPT_DIR/fixtures"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

fail() { echo "FAIL: $1"; exit 1; }
pass() { echo "PASS: $1"; }

# ── 1. hs_sha256: 파일 → sha256:<hex> ──
echo "hello" > "$TMP/a.txt"
sha=$(hs_sha256 "$TMP/a.txt")
case "$sha" in
  sha256:*) pass "sha256 prefix" ;;
  *) fail "sha256 prefix (got: $sha)" ;;
esac

# 동일 내용 → 동일 sha
echo "hello" > "$TMP/b.txt"
sha2=$(hs_sha256 "$TMP/b.txt")
[ "$sha" = "$sha2" ] && pass "sha256 deterministic" || fail "sha256 deterministic"

# 다른 내용 → 다른 sha
echo "world" > "$TMP/c.txt"
sha3=$(hs_sha256 "$TMP/c.txt")
[ "$sha" != "$sha3" ] && pass "sha256 changes" || fail "sha256 changes"

# 없는 파일 → 빈 문자열
sha_missing=$(hs_sha256 "$TMP/nope.txt")
[ -z "$sha_missing" ] && pass "sha256 missing → empty" || fail "sha256 missing → empty"

# ── 2. hs_is_legacy ──
hs_is_legacy "$TMP/nope.json" && pass "legacy: missing file" || fail "legacy: missing file"
echo "{}" > "$TMP/empty.json"
hs_is_legacy "$TMP/empty.json" && pass "legacy: empty manifest" || fail "legacy: empty manifest"
hs_is_legacy "$FIXTURES/harness-v3.json" && fail "legacy: stamped should NOT be legacy" || pass "legacy: stamped → not legacy"

# ── 3. hs_get_output_sha / hs_get_source_sha ──
out=$(hs_get_output_sha "$FIXTURES/harness-v3.json" ".claude/settings.json")
[ "$out" = "sha256:aaa" ] && pass "get_output_sha" || fail "get_output_sha (got: $out)"
src=$(hs_get_source_sha "$FIXTURES/harness-v3.json" "profiles/shared/settings.json")
[ "$src" = "sha256:111" ] && pass "get_source_sha" || fail "get_source_sha (got: $src)"
miss=$(hs_get_output_sha "$FIXTURES/harness-v3.json" "nope")
[ -z "$miss" ] && pass "get_output_sha missing → empty" || fail "get_output_sha missing → empty"

# ── 4. hs_classify_file ──
# 가짜 매니페스트 템플릿: src.txt 의 sha 와 out.txt 의 sha 를 placeholder 로 두고
# 케이스마다 새로 작성한다.

write_manifest() {
  local src_sha="$1"
  local out_sha="$2"
  cat > "$TMP/manifest.json" <<JSON
{
  "schema_version": 1,
  "plugin_name": "ehr-harness",
  "plugin_version": "1.0.0",
  "profile": "ehr5",
  "sources": { "src.txt": "$src_sha" },
  "outputs": { "out.txt": "$out_sha" }
}
JSON
}

# 케이스 unchanged: 매니페스트 sha 와 현재 sha 가 동일
echo -n "src_v1" > "$TMP/src.txt"
echo -n "out_v1" > "$TMP/out.txt"
SRC_V1=$(hs_sha256 "$TMP/src.txt")
OUT_V1=$(hs_sha256 "$TMP/out.txt")
write_manifest "$SRC_V1" "$OUT_V1"

bucket=$(hs_classify_file "$TMP/manifest.json" "src.txt" "$TMP/src.txt" "out.txt" "$TMP/out.txt")
[ "$bucket" = "unchanged" ] && pass "classify: unchanged" || fail "classify: unchanged (got: $bucket)"

# 케이스 safe-update: src 만 바뀜
echo -n "src_v2" > "$TMP/src.txt"
bucket=$(hs_classify_file "$TMP/manifest.json" "src.txt" "$TMP/src.txt" "out.txt" "$TMP/out.txt")
[ "$bucket" = "safe-update" ] && pass "classify: safe-update" || fail "classify: safe-update (got: $bucket)"

# 케이스 user-only: src 는 원복, out 만 바뀜
echo -n "src_v1" > "$TMP/src.txt"
echo -n "out_v2" > "$TMP/out.txt"
bucket=$(hs_classify_file "$TMP/manifest.json" "src.txt" "$TMP/src.txt" "out.txt" "$TMP/out.txt")
[ "$bucket" = "user-only" ] && pass "classify: user-only" || fail "classify: user-only (got: $bucket)"

# 케이스 conflict: 둘 다 바뀜
echo -n "src_v2" > "$TMP/src.txt"
echo -n "out_v2" > "$TMP/out.txt"
bucket=$(hs_classify_file "$TMP/manifest.json" "src.txt" "$TMP/src.txt" "out.txt" "$TMP/out.txt")
[ "$bucket" = "conflict" ] && pass "classify: conflict" || fail "classify: conflict (got: $bucket)"

# 케이스 new: 매니페스트에 없고 출력도 없음
bucket=$(hs_classify_file "$TMP/manifest.json" "newsrc.txt" "$TMP/missing_src" "newout.txt" "$TMP/missing_out")
[ "$bucket" = "new" ] && pass "classify: new" || fail "classify: new (got: $bucket)"

# ── 5. hs_write_manifest 라운드트립 ──
hs_write_manifest "$TMP/written.json" "1.2.3" "ehr5" '{"a":"sha256:1"}' '{"b":"sha256:2"}'
[ -f "$TMP/written.json" ] && pass "write_manifest creates file" || fail "write_manifest creates file"
sv=$(MFP="$TMP/written.json" node -e "console.log(JSON.parse(require('fs').readFileSync(process.env.MFP,'utf8')).schema_version)")
[ "$sv" = "3" ] && pass "write_manifest schema_version" || fail "write_manifest schema_version (got: $sv)"
pv=$(MFP="$TMP/written.json" node -e "console.log(JSON.parse(require('fs').readFileSync(process.env.MFP,'utf8')).plugin_version)")
[ "$pv" = "1.2.3" ] && pass "write_manifest plugin_version" || fail "write_manifest plugin_version (got: $pv)"
pf=$(MFP="$TMP/written.json" node -e "console.log(JSON.parse(require('fs').readFileSync(process.env.MFP,'utf8')).profile)")
[ "$pf" = "ehr5" ] && pass "write_manifest profile" || fail "write_manifest profile (got: $pf)"

# ── 6. hs_plugin_version ──
mkdir -p "$TMP/fakeplugin/.claude-plugin"
echo '{"name":"x","version":"9.9.9"}' > "$TMP/fakeplugin/.claude-plugin/plugin.json"
v=$(hs_plugin_version "$TMP/fakeplugin")
[ "$v" = "9.9.9" ] && pass "plugin_version read" || fail "plugin_version read (got: $v)"

# 없는 plugin → unknown
v_missing=$(hs_plugin_version "$TMP/no_such_plugin")
[ "$v_missing" = "unknown" ] && pass "plugin_version missing → unknown" || fail "plugin_version missing → unknown (got: $v_missing)"

# ── 7. hs_get_generated_at / hs_get_profile ──
gen=$(hs_get_generated_at "$FIXTURES/harness-v3.json")
[ "$gen" = "2026-04-09T10:00:00+09:00" ] && pass "get_generated_at" || fail "get_generated_at (got: $gen)"
prof=$(hs_get_profile "$FIXTURES/harness-v3.json")
[ "$prof" = "ehr5" ] && pass "get_profile" || fail "get_profile (got: $prof)"

# ── hs_is_legacy: v1 매니페스트는 legacy 로 분류되어야 함 ──
TMP_V1="$(mktemp -d)"
cat > "$TMP_V1/HARNESS.json" <<'EOF'
{"schema_version": 1, "plugin_name": "ehr-harness"}
EOF
if hs_is_legacy "$TMP_V1/HARNESS.json"; then
  pass "hs_is_legacy: schema_version=1 → legacy"
else
  fail "hs_is_legacy: schema_version=1 should be legacy (got stamped)"
fi
rm -rf "$TMP_V1"

# ── hs_is_legacy: v2 매니페스트는 legacy 로 분류되어야 함 (v3 기준) ──
TMP_V2="$(mktemp -d)"
cat > "$TMP_V2/HARNESS.json" <<'EOF'
{"schema_version": 2, "plugin_name": "ehr-harness"}
EOF
if hs_is_legacy "$TMP_V2/HARNESS.json"; then
  pass "hs_is_legacy: schema_version=2 → legacy (below v3)"
else
  fail "hs_is_legacy: schema_version=2 should be legacy when current is v3"
fi
rm -rf "$TMP_V2"

# ── hs_write_manifest: auth_model/db_verification/ddl_authoring 필드 기록 ──
TMP_W="$(mktemp -d)"
hs_write_manifest \
  "$TMP_W/HARNESS.json" \
  "1.1.0" \
  "ehr5" \
  '{}' '{}' \
  "" \
  '{"common_controllers":["GetDataList"],"auth_service_class":"AuthTableService","auth_injection_methods":["query_placeholder"],"auth_tables":["THRM151_AUTH"],"auth_functions":[],"session_vars":["ssnEnterCd","ssnSabun"]}' \
  '{"ddl_path":"src/main/resources/db/tables","db_access":"available","b3_strategy":"ddl-first"}' \
  '{"enabled":true,"table_path":"src/main/resources/db/tables","procedure_path":null,"function_path":null,"naming_pattern":"{OBJECT_NAME}.sql","header_template_path":null,"existing_tables":["THRM101"]}'
WRITTEN=$(cat "$TMP_W/HARNESS.json")
if echo "$WRITTEN" | grep -q '"schema_version": 3' && \
   echo "$WRITTEN" | grep -q '"auth_service_class": "AuthTableService"' && \
   echo "$WRITTEN" | grep -q '"b3_strategy": "ddl-first"' && \
   echo "$WRITTEN" | grep -q '"enabled": true'; then
  pass "hs_write_manifest: v2 fields persisted"
else
  fail "hs_write_manifest: v2 fields missing. Got: $WRITTEN"
fi
rm -rf "$TMP_W"

# ── hs_write_manifest: 옵셔널 인자 미제공 시 v2 필드가 null 이어야 함 ──
TMP_D="$(mktemp -d)"
hs_write_manifest "$TMP_D/m.json" "1.0.0" "ehr5" '{}' '{}'
HAVE_NULL=$(MFP="$TMP_D/m.json" node -e "
  const m=JSON.parse(require('fs').readFileSync(process.env.MFP,'utf8'));
  console.log([m.auth_model, m.db_verification, m.ddl_authoring].every(x => x === null));
")
if [ "$HAVE_NULL" = "true" ]; then
  pass "write_manifest: defaults to null when v2 args omitted"
else
  fail "write_manifest: defaults should be null (got: $HAVE_NULL)"
fi
rm -rf "$TMP_D"

# ── hs_is_legacy: v2 매니페스트는 legacy 로 분류되어야 함 (v3 bump 후) ──
TMP_V2="$(mktemp -d)"
cat > "$TMP_V2/HARNESS.json" <<'EOF'
{"schema_version": 2, "plugin_name": "ehr-harness"}
EOF
if hs_is_legacy "$TMP_V2/HARNESS.json"; then
  pass "hs_is_legacy: schema_version=2 → legacy (v3 bump)"
else
  fail "hs_is_legacy: schema_version=2 should be legacy after v3 bump"
fi
rm -rf "$TMP_V2"

# ── hs_is_legacy: v3 매니페스트는 stamped 로 분류되어야 함 ──
TMP_V3="$(mktemp -d)"
cat > "$TMP_V3/HARNESS.json" <<'EOF'
{"schema_version": 3, "plugin_name": "ehr-harness"}
EOF
if hs_is_legacy "$TMP_V3/HARNESS.json"; then
  fail "hs_is_legacy: schema_version=3 should be stamped"
else
  pass "hs_is_legacy: schema_version=3 → stamped"
fi
rm -rf "$TMP_V3"

# ── hs_write_manifest: analysis 필드 기록 (10-arg 버전) ──
TMP_W3="$(mktemp -d)"
hs_write_manifest \
  "$TMP_W3/HARNESS.json" \
  "1.3.0" \
  "ehr5" \
  '{}' '{}' \
  "" \
  '{"common_controllers":[],"auth_service_class":null,"auth_injection_methods":[],"auth_tables":[],"auth_functions":[],"session_vars":[]}' \
  '{"ddl_path":null,"db_access":"unavailable","b3_strategy":"manual-required"}' \
  '{"enabled":false,"table_path":null,"procedure_path":null,"function_path":null,"naming_pattern":null,"header_template_path":null,"existing_tables":[]}' \
  '{"analyzed_at":"2026-04-15T14:23:01+09:00","module_map":[{"name":"hrm","file_count":120}],"session_vars":["ssnEnterCd"],"authSqlID":[],"law_counts":{"A_direct_controller":45,"B_getData":79,"B_saveData":68,"C_hybrid":12,"D_execPrc":15},"critical_proc_found":["P_CPN_CAL_PAY_MAIN"],"critical_proc_missing":[],"procedure_count":234,"procedure_sample":["P_CPN_CAL_PAY_MAIN"],"trigger_count":18}'
WRITTEN=$(cat "$TMP_W3/HARNESS.json")
if echo "$WRITTEN" | grep -q '"schema_version": 3' && \
   echo "$WRITTEN" | grep -q '"analyzed_at":' && \
   echo "$WRITTEN" | grep -q '"procedure_count": 234' && \
   echo "$WRITTEN" | grep -q '"module_map":'; then
  pass "hs_write_manifest: v3 analysis 필드 persisted"
else
  fail "hs_write_manifest: v3 analysis 필드 missing. Got: $WRITTEN"
fi
rm -rf "$TMP_W3"

# ── hs_write_manifest: 9-arg 호출 시 analysis null (후방 호환) ──
TMP_W9="$(mktemp -d)"
hs_write_manifest \
  "$TMP_W9/HARNESS.json" \
  "1.3.0" \
  "ehr5" \
  '{}' '{}' \
  "" \
  'null' 'null' 'null'
BACKCOMPAT=$(MFP="$TMP_W9/HARNESS.json" node -e "
  const m=JSON.parse(require('fs').readFileSync(process.env.MFP,'utf8'));
  console.log(m.analysis === null ? 'ok' : 'BAD');
")
if [ "$BACKCOMPAT" = "ok" ]; then
  pass "hs_write_manifest: 9-arg 호출 시 analysis null (후방호환)"
else
  fail "hs_write_manifest: 9-arg backcompat broken (got: $BACKCOMPAT)"
fi
rm -rf "$TMP_W9"

# ── hs_get_analysis: 매니페스트에서 analysis 조회 ──
TMP_A="$(mktemp -d)"
cat > "$TMP_A/HARNESS.json" <<'EOF'
{"schema_version": 3, "analysis": {"module_map": [{"name":"hrm","file_count":120}], "session_vars": ["ssnEnterCd"]}}
EOF
RESULT=$(hs_get_analysis "$TMP_A/HARNESS.json")
if echo "$RESULT" | grep -q '"name":"hrm"' && echo "$RESULT" | grep -q '"ssnEnterCd"'; then
  pass "hs_get_analysis: JSON 객체 반환"
else
  fail "hs_get_analysis: unexpected output ($RESULT)"
fi

# ── hs_get_analysis: analysis 없을 때 null 반환 ──
cat > "$TMP_A/NO_ANALYSIS.json" <<'EOF'
{"schema_version": 3}
EOF
RESULT=$(hs_get_analysis "$TMP_A/NO_ANALYSIS.json")
if [ "$RESULT" = "null" ]; then
  pass "hs_get_analysis: 없을 때 null"
else
  fail "hs_get_analysis: should return null when missing (got: $RESULT)"
fi
rm -rf "$TMP_A"

# ══════════════════════════════════════════════════════
# Windows 경로 엣지 케이스 (공백/한글)
# 실제 symlink/junction 은 Git Bash 관리자 권한 필요 →
#   파일 복사로 대체. 실제 symlink 는 별도 환경 검증 필요
# ══════════════════════════════════════════════════════

# ── WP-1: 공백 포함 경로에서 hs_sha256 동작 ──
# 시뮬레이션 경로: C:/Program Files (x86)/
SPACE_DIR="$TMP/dir with space"
mkdir -p "$SPACE_DIR"
echo "hello" > "$SPACE_DIR/sample.txt"
sha_sp=$(hs_sha256 "$SPACE_DIR/sample.txt")
case "$sha_sp" in
  sha256:*) pass "WP-1 공백경로: hs_sha256 prefix 정상" ;;
  *)        fail "WP-1 공백경로: hs_sha256 실패 — 경로 quoting 문제 의심 (got: $sha_sp)" ;;
esac

# hs_write_manifest + hs_is_legacy 공백 경로 검증
hs_write_manifest "$SPACE_DIR/HARNESS.json" "1.0.0" "ehr5" '{}' '{}'
if hs_is_legacy "$SPACE_DIR/HARNESS.json"; then
  fail "WP-1 공백경로: hs_is_legacy — v3 매니페스트가 legacy 로 분류됨"
else
  pass "WP-1 공백경로: hs_write_manifest + hs_is_legacy (공백 경로)"
fi

# ── WP-2: 한글 포함 경로에서 hs_sha256 동작 ──
# 시뮬레이션 경로: C:/사용자/홍길동/
HANGUL_DIR="$TMP/한글폴더/홍길동"
mkdir -p "$HANGUL_DIR"
echo "hello" > "$HANGUL_DIR/sample.txt"
sha_hg=$(hs_sha256 "$HANGUL_DIR/sample.txt")
case "$sha_hg" in
  sha256:*) pass "WP-2 한글경로: hs_sha256 prefix 정상" ;;
  *)        fail "WP-2 한글경로: hs_sha256 실패 — multibyte 경로 처리 의심 (got: $sha_hg)" ;;
esac

# 동일 내용 → sha 일치 (공백 경로 기준 sha 와 동일해야 함)
[ "$sha_sp" = "$sha_hg" ] \
  && pass "WP-2 한글경로: sha256 동일 내용 결과 일치" \
  || fail "WP-2 한글경로: sha256 결과 불일치 ($sha_sp vs $sha_hg)"

# hs_write_manifest + hs_get_profile 한글 경로 검증
hs_write_manifest "$HANGUL_DIR/HARNESS.json" "1.0.0" "ehr5" '{}' '{}'
prof_hg=$(hs_get_profile "$HANGUL_DIR/HARNESS.json")
[ "$prof_hg" = "ehr5" ] \
  && pass "WP-2 한글경로: hs_get_profile 정상" \
  || fail "WP-2 한글경로: hs_get_profile 실패 (got: $prof_hg)"

# ── WP-3 (심볼릭링크 mock): 복사된 매니페스트에서 동작 확인 ──
# 실제 symlink 는 별도 환경 검증 필요 (mklink /J 는 관리자 권한 필요)
MOCK_DIR="$TMP/symlink_mock_hs"
mkdir -p "$MOCK_DIR"
cp "$FIXTURES/harness-v3.json" "$MOCK_DIR/harness-v3.json"
out_mock=$(hs_get_output_sha "$MOCK_DIR/harness-v3.json" ".claude/settings.json")
[ "$out_mock" = "sha256:aaa" ] \
  && pass "WP-3 심볼릭링크(mock): hs_get_output_sha 정상 (복사 대체 픽스처)" \
  || fail "WP-3 심볼릭링크(mock): hs_get_output_sha 실패 (got: $out_mock)"

echo "ALL TESTS PASSED"
