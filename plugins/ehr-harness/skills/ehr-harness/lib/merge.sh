#!/usr/bin/env bash
# merge.sh — HARNESS-MANAGED 섹션 병합 유틸
#
# 기존 사용자 편집 문서를 보존하면서 플러그인이 관리하는 섹션만 교체/추가한다.
# 관리 섹션은 `<!-- HARNESS-MANAGED:ID -->` / `<!-- /HARNESS-MANAGED:ID -->` 쌍으로 감싸고,
# 이 마커 내부만 갱신 대상으로 삼아 사용자 커스텀 섹션은 절대 건드리지 않는다.
#
# 사용 예:
#   source merge.sh
#   merge_managed_section "AGENTS.md" "analysis_snapshot" "## 분석 스냅샷 (자동 감별)" "$NEW_BODY"
#
# 동작 (3분기):
#   (1) 마커 쌍 존재      → 내부만 교체, 헤딩·주변 텍스트 불변
#   (2) 헤딩만 존재       → 헤딩은 유지, 본문 영역을 마커로 래핑하면서 교체
#   (3) 헤딩도 없음       → 파일 끝에 `HEADING\n\n[start]\nBODY\n[end]\n` 로 append

set -u -o pipefail

# ── 헬퍼: 파일에서 마커 쌍 사이 본문 추출 ──
# args: FILE SECTION_ID
# stdout: 마커 사이 본문 (앞/뒤 개행 1개씩 trim). 미발견 시 exit 2.
extract_section_body() {
  local file="$1"
  local section_id="$2"
  FILE="$file" ID="$section_id" node -e '
    const fs=require("fs");
    const src=fs.readFileSync(process.env.FILE,"utf8").replace(/\r\n/g,"\n");
    const id=process.env.ID;
    const start=`<!-- HARNESS-MANAGED:${id} -->`;
    const end=`<!-- /HARNESS-MANAGED:${id} -->`;
    // 모든 start/end 위치 수집 (중첩/교차/orphan 방어)
    const allStarts=[]; { let p=0; while((p=src.indexOf(start,p))!==-1){allStarts.push(p); p+=start.length;} }
    const allEnds=[]; { let p=0; while((p=src.indexOf(end,p))!==-1){allEnds.push(p); p+=end.length;} }
    if(allStarts.length===0 || allEnds.length===0) process.exit(2);
    // orphan: start/end 개수 불일치
    if(allStarts.length !== allEnds.length) process.exit(2);
    // 교차/중첩/역순: 각 쌍의 start<end + 쌍 간 non-overlapping
    for(let i=0;i<allStarts.length;i++){
      if(allStarts[i] >= allEnds[i]) process.exit(2);
      if(i>0 && allStarts[i] < allEnds[i-1]) process.exit(2);
    }
    // 첫 쌍 본문 반환
    const s=allStarts[0]; const e=allEnds[0];
    let body=src.slice(s+start.length, e);
    if(body.startsWith("\n"))body=body.slice(1);
    if(body.endsWith("\n"))body=body.slice(0,-1);
    process.stdout.write(body);
  '
}

# ── 헬퍼: 파일에서 start 마커 바로 앞의 `## ...` 헤딩 라인 추출 ──
# args: FILE SECTION_ID
# stdout: `## 섹션 제목` 문자열. 미발견 시 exit 2/3.
extract_section_heading() {
  local file="$1"
  local section_id="$2"
  FILE="$file" ID="$section_id" node -e '
    const fs=require("fs");
    const lines=fs.readFileSync(process.env.FILE,"utf8").replace(/\r\n/g,"\n").split("\n");
    const id=process.env.ID;
    const marker=`<!-- HARNESS-MANAGED:${id} -->`;
    let mi=-1;
    for(let i=0;i<lines.length;i++){ if(lines[i].trim()===marker){ mi=i; break; } }
    if(mi===-1){process.exit(2);}
    // 마커 위쪽으로 탐색하되 다른 HARNESS-MANAGED 마커나 최상위 H1 은 경계로 본다.
    let found=null;
    for(let j=mi-1;j>=0;j--){
      const L=lines[j];
      if(/<!--\s*\/?HARNESS-MANAGED:/.test(L)) break;
      if(/^#\s/.test(L)) break;
      if(/^##\s/.test(L)){ found=L; break; }
    }
    if(found===null){process.exit(3);}
    process.stdout.write(found);
  '
}

merge_managed_section() {
  local file="$1"
  local section_id="$2"
  local heading="$3"
  local body="$4"

  if [ ! -f "$file" ]; then
    echo "merge_managed_section: 파일 없음 — $file" >&2
    return 1
  fi

  FILE="$file" ID="$section_id" HEADING="$heading" BODY="$body" node -e '
    const fs = require("fs");
    const file = process.env.FILE;
    const id = process.env.ID;
    const heading = process.env.HEADING;
    const body = process.env.BODY;
    const start = `<!-- HARNESS-MANAGED:${id} -->`;
    const end = `<!-- /HARNESS-MANAGED:${id} -->`;
    const block = `${start}\n${body}\n${end}`;

    let src = fs.readFileSync(file, "utf8");
    const eol = src.includes("\r\n") ? "\r\n" : "\n";
    // 작업 중에는 \n 으로 통일했다가 쓰기 직전에 원래 EOL 로 복원
    src = src.replace(/\r\n/g, "\n");

    // ── 마커 구조 방어 검증 ──
    // 가능 시나리오: (a) 0쌍 = 마커 없음 → 헤딩/append 분기로 넘김
    //               (b) N쌍 non-overlapping = 정상 / 중복 → 첫 쌍만 유지
    //               (c) 교차 (start1 < start2 < end1 < end2) → 위험, 에러
    //               (d) 중첩 같은 ID (start1 < start2 < end2 < end1) → 모호, 에러
    //               (e) orphan (start/end 개수 불일치) → 에러
    //               (f) 역순 (end 가 start 보다 앞) → 에러
    const allStarts = [];
    {
      let p = 0;
      while ((p = src.indexOf(start, p)) !== -1) { allStarts.push(p); p += start.length; }
    }
    const allEnds = [];
    {
      let p = 0;
      while ((p = src.indexOf(end, p)) !== -1) { allEnds.push(p); p += end.length; }
    }

    if (allStarts.length > 0 || allEnds.length > 0) {
      if (allStarts.length !== allEnds.length) {
        process.stderr.write(
          `merge_managed_section: orphan 마커 감지 (${id}) — start ${allStarts.length}, end ${allEnds.length}개. 파일을 직접 확인 후 수동 수정하세요.\n  파일: ${file}\n`
        );
        process.exit(2);
      }
      for (let i = 0; i < allStarts.length; i++) {
        if (allStarts[i] >= allEnds[i]) {
          process.stderr.write(
            `merge_managed_section: 역순 마커 감지 (${id}) — 쌍 ${i+1}: start @${allStarts[i]} >= end @${allEnds[i]}. 파일 수동 확인 필요.\n  파일: ${file}\n`
          );
          process.exit(2);
        }
        if (i > 0 && allStarts[i] < allEnds[i-1]) {
          process.stderr.write(
            `merge_managed_section: 교차/중첩 마커 감지 (${id}) — 쌍 ${i+1}의 start(${allStarts[i]}) < 쌍 ${i}의 end(${allEnds[i-1]}). 같은 ID로 중첩됐거나 쌍이 교차된 구조입니다. 파일 수동 확인 필요.\n  파일: ${file}\n`
          );
          process.exit(2);
        }
      }
      // non-overlapping N쌍: 중복이면 첫 쌍만 유지, 나머지 제거
      if (allStarts.length > 1) {
        process.stderr.write(
          `merge_managed_section: 중복 마커 감지 (${id}) — 총 ${allStarts.length}쌍. 첫 쌍만 유지하고 나머지 제거.\n`
        );
        const extras = [];
        for (let i = 1; i < allStarts.length; i++) {
          extras.push({ s: allStarts[i], e: allEnds[i] + end.length });
        }
        extras.sort((a, b) => b.s - a.s);
        for (const ex of extras) {
          src = src.slice(0, ex.s) + src.slice(ex.e);
        }
      }
    }

    const startIdx = src.indexOf(start);
    const endIdx = src.indexOf(end);

    let out;
    if (startIdx !== -1 && endIdx !== -1 && endIdx > startIdx) {
      // (1) 마커 쌍 존재 → 내부 교체
      const before = src.slice(0, startIdx);
      const after = src.slice(endIdx + end.length);
      out = before + block + after;
    } else {
      // heading 라인 단독 매칭 (공백 trim 후 일치)
      const lines = src.split("\n");
      let headingLine = -1;
      for (let i = 0; i < lines.length; i++) {
        if (lines[i].trim() === heading.trim()) {
          headingLine = i;
          break;
        }
      }
      if (headingLine !== -1) {
        // (2) heading 존재, 마커 없음 → 이 heading 의 섹션 범위를 다음 `## ` 또는 EOF 까지로 보고 교체.
        //     heading 자체는 유지하고 그 아래 본문을 [start]...[end] 로 래핑.
        let nextHeadingLine = lines.length;
        for (let j = headingLine + 1; j < lines.length; j++) {
          if (/^##\s/.test(lines[j])) { nextHeadingLine = j; break; }
        }
        const before = lines.slice(0, headingLine + 1).join("\n");
        const after = lines.slice(nextHeadingLine).join("\n");
        const middle = `\n\n${block}\n\n`;
        out = before + middle + after;
      } else {
        // (3) heading 도 없음 → 파일 끝에 append. 기존 문서가 개행으로 안 끝나면 하나 붙여준다.
        const tail = src.endsWith("\n") ? "" : "\n";
        out = `${src}${tail}\n${heading}\n\n${block}\n`;
      }
    }

    // 연속 공백 라인 정규화 (3개 이상 빈 줄 → 2개)
    out = out.replace(/\n{3,}/g, "\n\n");
    // 파일은 반드시 개행으로 끝나도록
    if (!out.endsWith("\n")) out += "\n";

    // 원래 EOL 복원
    if (eol === "\r\n") out = out.replace(/\n/g, "\r\n");

    fs.writeFileSync(file, out);
  '
}

# === apply_staged (Stage 7) ===
# v1.10 self-evolving merge entry. audit 흐름이 EHR_AUDIT_APPROVED=1 + EHR_NONCE 세팅 후 호출.
# Args: $1 = staged file path (PROJECT_DIR 상대 또는 절대)
# Exit codes: 0 ok / 2 no approval / 3 nonce mismatch / 4 plugin-dev cwd 위반 / 5 org-template / 6 unknown scope
apply_staged() {
  local staged="$1"
  local proj="${CLAUDE_PROJECT_DIR:-$(pwd)}"
  case "$staged" in
    /*|[A-Za-z]:[/\\]*) : ;;  # absolute (Unix or Windows)
    *) staged="$proj/$staged" ;;
  esac

  # gate 1: env
  if [ -z "${EHR_AUDIT_APPROVED:-}" ] || [ -z "${EHR_NONCE:-}" ]; then
    echo "FATAL: EHR_AUDIT_APPROVED + EHR_NONCE 필수" >&2
    return 2
  fi

  [ -f "$staged" ] || { echo "FATAL: staged file not found: $staged" >&2; return 2; }

  # gate 2: nonce 형식
  if ! printf '%s' "$EHR_NONCE" | grep -qE '^[a-f0-9]{64}$'; then
    echo "FATAL: EHR_NONCE format invalid (expect ^[a-f0-9]{64}$)" >&2
    return 3
  fi

  # gate 2-b: staged file 의 실제 sha256 과 비교
  local actual_nonce
  actual_nonce=$(sha256sum "$staged" 2>/dev/null | awk '{print $1}')
  if [ -z "$actual_nonce" ]; then
    actual_nonce=$(MFP="$staged" node -e "
      const fs=require('fs'),c=require('crypto');
      const h=c.createHash('sha256').update(fs.readFileSync(process.env.MFP)).digest('hex');
      process.stdout.write(h);
    " 2>/dev/null)
  fi
  if [ "$actual_nonce" != "$EHR_NONCE" ]; then
    echo "FATAL: nonce mismatch (staged 변조 의심)" >&2
    return 3
  fi

  # gate 2-c: HARNESS.json 의 staged_nonces[topic] 과도 비교
  local topic; topic=$(awk '/^topic:/ {print $2; exit}' "$staged")
  local registered
  registered=$(MFP="$proj/.claude/HARNESS.json" TOPIC="$topic" node -e "
    try {
      const m=JSON.parse(require('fs').readFileSync(process.env.MFP,'utf8'));
      const n=m && m.ehr_cycle && m.ehr_cycle.learnings_meta && m.ehr_cycle.learnings_meta.staged_nonces && m.ehr_cycle.learnings_meta.staged_nonces[process.env.TOPIC];
      if (n) process.stdout.write(n);
    } catch(e) {}
  " 2>/dev/null)
  if [ -n "$registered" ] && [ "$registered" != "$actual_nonce" ]; then
    echo "FATAL: HARNESS staged_nonces mismatch" >&2
    return 3
  fi

  # scope 결정
  local scope; scope=$(awk '/^scope:/ {print $2; exit}' "$staged")
  scope="${scope:-project-local}"

  case "$scope" in
    project-local)
      _apply_project_local "$staged" "$proj" || return $?
      ;;
    plugin-dev)
      # cwd 가 플러그인 repo 인지 (plugin.json 의 name == ehr-harness)
      local pjson="$proj/plugins/ehr-harness/.claude-plugin/plugin.json"
      local pname=""
      if [ -f "$pjson" ]; then
        pname=$(MFP="$pjson" node -e "
          try { const m=JSON.parse(require('fs').readFileSync(process.env.MFP,'utf8')); if (m && m.name) process.stdout.write(m.name); }
          catch(e) {}
        " 2>/dev/null)
      fi
      if [ "$pname" != "ehr-harness" ]; then
        echo "FATAL: plugin-dev scope 인데 cwd 가 플러그인 repo 가 아님" >&2
        return 4
      fi
      _apply_plugin_dev "$staged" "$proj" || return $?
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
  mv "$staged" "$proj/.claude/learnings/staged.applied/" 2>/dev/null
  return 0
}

_apply_project_local() {
  local staged="$1" proj="$2"
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
  local staged="$1" proj="$2"
  local target; target=$(awk '/^target:/ {print $2; exit}' "$staged")
  local profile
  profile=$(MFP="$proj/.claude/HARNESS.json" node -e "
    try { const m=JSON.parse(require('fs').readFileSync(process.env.MFP,'utf8')); process.stdout.write(m.profile||'ehr5'); }
    catch(e) { process.stdout.write('ehr5'); }
  " 2>/dev/null)
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

# staged 의 marker 블록만 target 끝에 append
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
