#!/usr/bin/env bash
# Harvest helper library — pending → staged 변환의 결정적 단위 함수.
# 클러스터링 / candidate_rule 추출은 slash command 본문(Claude) 이 수행.
# 본 lib 은 scoring / counting / nonce 등 결정적 부분만.

# === 공개 함수 ===

# ehr_harvest_score: success_count + correction_count → 점수
# 정책 기본값: success_weight=2, correction_weight=1 (HARNESS.json 의 promotion_policy 가 SoT)
ehr_harvest_score() {
  local s=${1:-0} c=${2:-0}
  echo $((s * 2 + c * 1))
}

# ehr_harvest_distinct_sessions: pending.jsonl 의 unique session_hash 수
# 입력: jsonl 파일 path
# 출력: 정수 (파일 부재 / node 부재 / 빈 파일 → 0)
ehr_harvest_distinct_sessions() {
  local p="$1"
  [ -f "$p" ] || { echo 0; return; }
  command -v node >/dev/null 2>&1 || { echo 0; return; }
  MFP="$p" node -e "
    const fs=require('fs');
    let lines;
    try { lines=fs.readFileSync(process.env.MFP,'utf8').split('\n').filter(Boolean); }
    catch(e) { console.log(0); process.exit(0); }
    const seen=new Set();
    for (const ln of lines) {
      try { const j=JSON.parse(ln); if (j.session_hash) seen.add(j.session_hash); }
      catch(e) {}
    }
    console.log(seen.size);
  " 2>/dev/null
}

# ehr_harvest_count_valid: 유효 JSON 라인 수 (corrupt skip)
ehr_harvest_count_valid() {
  local p="$1"
  [ -f "$p" ] || { echo 0; return; }
  command -v node >/dev/null 2>&1 || { echo 0; return; }
  MFP="$p" node -e "
    const fs=require('fs');
    let lines;
    try { lines=fs.readFileSync(process.env.MFP,'utf8').split('\n').filter(Boolean); }
    catch(e) { console.log(0); process.exit(0); }
    let n=0;
    for (const ln of lines) {
      try { JSON.parse(ln); n++; } catch(e) {}
    }
    console.log(n);
  " 2>/dev/null
}

# ehr_harvest_take_first: 처음 N 라인만 (LLM cap)
ehr_harvest_take_first() {
  local p="$1" n="${2:-100}"
  head -n "$n" "$p"
}

# ehr_harvest_nonce: staged file 의 sha256 (lowercase hex 64)
ehr_harvest_nonce() {
  local f="$1"
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum "$f" 2>/dev/null | awk '{print $1}'
  elif command -v shasum >/dev/null 2>&1; then
    shasum -a 256 "$f" 2>/dev/null | awk '{print $1}'
  else
    MFP="$f" node -e "
      const fs=require('fs'),c=require('crypto');
      const h=c.createHash('sha256').update(fs.readFileSync(process.env.MFP)).digest('hex');
      process.stdout.write(h);
    " 2>/dev/null
  fi
}
