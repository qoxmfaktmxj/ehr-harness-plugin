#!/usr/bin/env bash
# audit.sh — drift 계산 + 리포트 생성
#
# 사용 예:
#   source audit.sh
#   compute_drift "$BEFORE_JSON" "$AFTER_JSON"

set -u -o pipefail

# ── Drift 계산 ──
# args: before_json after_json
# stdout: JSON 객체 {module_map:{added,removed,changed}, session_vars:{added,removed}, ...}
compute_drift() {
  local before="$1"
  local after="$2"

  BEFORE="$before" AFTER="$after" node -e "
    const before = JSON.parse(process.env.BEFORE);
    const after  = JSON.parse(process.env.AFTER);

    // stable stringify — 객체 키를 정렬해 비교함으로써
    // '키 순서만 다른' 동일 객체가 changed 로 잡히는 false positive 를 방지.
    const stable = (v) => {
      if (v === null || v === undefined) return JSON.stringify(v);
      if (Array.isArray(v)) return '[' + v.map(stable).join(',') + ']';
      if (typeof v === 'object') {
        const keys = Object.keys(v).sort();
        return '{' + keys.map(k => JSON.stringify(k) + ':' + stable(v[k])).join(',') + '}';
      }
      return JSON.stringify(v);
    };

    const setDiff = (a, b) => {
      const aS = new Set(a || []);
      const bS = new Set(b || []);
      const added = [...bS].filter(x => !aS.has(x));
      const removed = [...aS].filter(x => !bS.has(x));
      return { added, removed };
    };

    const objArrDiff = (a, b, keyName) => {
      const aMap = new Map((a || []).map(x => [x[keyName], x]));
      const bMap = new Map((b || []).map(x => [x[keyName], x]));
      const added = [];
      const removed = [];
      const changed = [];
      for (const [k, v] of bMap) {
        if (!aMap.has(k)) added.push(v);
        else {
          const av = aMap.get(k);
          if (stable(av) !== stable(v)) {
            changed.push({ name: k, before: av, after: v });
          }
        }
      }
      for (const [k, v] of aMap) {
        if (!bMap.has(k)) removed.push(v);
      }
      return { added, removed, changed };
    };

    // 카운트 변화 필터 (절대값 5 OR 10% 이상)
    const countChanged = (a, b) => {
      if (a === b) return null;
      const abs = Math.abs(b - a);
      const pct = a === 0 ? 100 : (abs / a) * 100;
      if (abs < 5 && pct < 10) return null;
      return { before: a, after: b, delta: b - a };
    };

    const lawChanged = {};
    const laws = ['A_direct_controller', 'B_getData', 'B_saveData', 'C_hybrid', 'D_execPrc'];
    for (const k of laws) {
      const c = countChanged(before.law_counts?.[k] ?? 0, after.law_counts?.[k] ?? 0);
      if (c) lawChanged[k] = c;
    }

    const drift = {
      module_map: objArrDiff(before.module_map, after.module_map, 'name'),
      session_vars: setDiff(before.session_vars, after.session_vars),
      authSqlID: setDiff(before.authSqlID, after.authSqlID),
      critical_proc_found: setDiff(before.critical_proc_found, after.critical_proc_found),
      law_counts: lawChanged,
      procedure_count: countChanged(before.procedure_count ?? 0, after.procedure_count ?? 0),
      trigger_count: countChanged(before.trigger_count ?? 0, after.trigger_count ?? 0),
    };

    // procedure_count가 null이면 changed: false로 표시
    if (drift.procedure_count === null) drift.procedure_count = { changed: false };
    else drift.procedure_count.changed = true;
    if (drift.trigger_count === null) drift.trigger_count = { changed: false };
    else drift.trigger_count.changed = true;

    process.stdout.write(JSON.stringify(drift));
  "
}

# ── Drift 중요도 분류 ──
# args: drift_json
# stdout: JSON 객체 {high: [{field, detail}], medium: [...], low: [...]}
drift_importance() {
  local drift="$1"

  DRIFT="$drift" node -e "
    const d = JSON.parse(process.env.DRIFT);
    const high = [];
    const medium = [];
    const low = [];

    // 상급 — session_vars, critical_proc_found.added
    if (d.session_vars.added.length > 0) {
      high.push({ field: 'session_vars.added', items: d.session_vars.added });
    }
    if (d.session_vars.removed.length > 0) {
      high.push({ field: 'session_vars.removed', items: d.session_vars.removed });
    }
    if (d.critical_proc_found.added.length > 0) {
      high.push({ field: 'critical_proc_found.added', items: d.critical_proc_found.added });
    }

    // 중급 — module_map, authSqlID
    if (d.module_map.added.length > 0) {
      medium.push({ field: 'module_map.added', items: d.module_map.added });
    }
    if (d.module_map.removed.length > 0) {
      medium.push({ field: 'module_map.removed', items: d.module_map.removed });
    }
    if (d.module_map.changed.length > 0) {
      medium.push({ field: 'module_map.changed', items: d.module_map.changed });
    }
    if (d.authSqlID.added.length > 0 || d.authSqlID.removed.length > 0) {
      medium.push({ field: 'authSqlID', added: d.authSqlID.added, removed: d.authSqlID.removed });
    }

    // 하급 — law_counts, procedure_count, trigger_count
    if (Object.keys(d.law_counts).length > 0) {
      low.push({ field: 'law_counts', changes: d.law_counts });
    }
    if (d.procedure_count && d.procedure_count.changed) {
      low.push({ field: 'procedure_count', before: d.procedure_count.before, after: d.procedure_count.after });
    }
    if (d.trigger_count && d.trigger_count.changed) {
      low.push({ field: 'trigger_count', before: d.trigger_count.before, after: d.trigger_count.after });
    }

    process.stdout.write(JSON.stringify({ high, medium, low }));
  "
}

# ── Audit 리포트 렌더링 ──
# args: drift_json importance_json analyzed_at system_name profile plugin_ver_old plugin_ver_new
# stdout: 마크다운 리포트
render_audit_report() {
  local drift="$1"
  local importance="$2"
  local analyzed_at="$3"
  local system_name="${4:-unknown}"
  local profile="${5:-unknown}"
  local plugin_old="${6:-unknown}"
  local plugin_new="${7:-unknown}"

  DRIFT="$drift" IMP="$importance" \
  AT="$analyzed_at" SYS="$system_name" PROF="$profile" \
  PVO="$plugin_old" PVN="$plugin_new" \
  node -e "
    const drift = JSON.parse(process.env.DRIFT);
    const imp = JSON.parse(process.env.IMP);
    const at = process.env.AT;
    const sys = process.env.SYS;
    const prof = process.env.PROF;
    const pvo = process.env.PVO;
    const pvn = process.env.PVN;

    const lines = [];
    lines.push('# 하네스 점검 보고서 (' + at + ')');
    lines.push('');
    lines.push('**프로젝트**: ' + sys + ' (' + prof.toUpperCase() + ')');
    lines.push('**플러그인**: ehr-harness ' + pvo + ' → ' + pvn);
    lines.push('');
    lines.push('## 프로젝트 Drift');
    lines.push('');

    // 상
    if (imp.high.length === 0) {
      lines.push('### [상] 상급 drift 없음');
    } else {
      imp.high.forEach(h => {
        lines.push('### [상] ' + h.field);
        if (h.items) {
          h.items.forEach(it => {
            if (typeof it === 'string') lines.push('  - ' + it);
            else lines.push('  - ' + JSON.stringify(it));
          });
        } else {
          lines.push('  ' + JSON.stringify(h));
        }
        lines.push('');
      });
    }

    // 중
    if (imp.medium.length > 0) {
      imp.medium.forEach(m => {
        lines.push('### [중] ' + m.field);
        if (m.items) {
          m.items.forEach(it => {
            if (typeof it === 'string') lines.push('  - ' + it);
            else if (it.name && it.file_count !== undefined) lines.push('  - ' + it.name + ' (' + it.file_count + ' 파일)');
            else lines.push('  - ' + JSON.stringify(it));
          });
        } else {
          lines.push('  ' + JSON.stringify({added: m.added, removed: m.removed}));
        }
        lines.push('');
      });
    }

    // 하
    if (imp.low.length > 0) {
      imp.low.forEach(l => {
        lines.push('### [하] ' + l.field);
        if (l.changes) {
          Object.entries(l.changes).forEach(([k, v]) => {
            lines.push('  - ' + k + ': ' + v.before + ' → ' + v.after + ' (' + (v.delta >= 0 ? '+' : '') + v.delta + ')');
          });
        } else if (l.before !== undefined) {
          lines.push('  - ' + l.before + ' → ' + l.after);
        }
        lines.push('');
      });
    }

    lines.push('---');
    lines.push('요약: 상 ' + imp.high.length + '개, 중 ' + imp.medium.length + '개, 하 ' + imp.low.length + '개');

    process.stdout.write(lines.join('\n'));
  "
}

# ── Audit 리포트 파일 저장 ──
# args: report_text output_path
save_audit_report() {
  local report="$1"
  local path="$2"
  mkdir -p "$(dirname "$path")"
  printf '%s\n' "$report" > "$path"
}

# ── EHR Cycle 드리프트 검출 (v4) ──────────────

# HARNESS.json 의 compounds[].id 와 실제 파일 블록을 대조
# 출력: 각 줄 "<type>:<id>:<file>"
#   type = orphan_compound (json 에 있음, 파일에 없음)
#        = orphan_marker   (파일에 있음, json 에 없음)
ehr_audit_compound_drift() {
  local project_root="$1"
  local harness_json="$project_root/.claude/HARNESS.json"
  [[ -f "$harness_json" ]] || { echo ""; return 0; }

  # 1) JSON 의 ehr_cycle.compounds[].id 추출 — node 기반 (포맷 불문: compact/pretty 모두)
  local json_ids
  json_ids=$(HARNESS_JSON="$harness_json" node -e "
    try {
      const m = JSON.parse(require('fs').readFileSync(process.env.HARNESS_JSON, 'utf8'));
      const ids = (m.ehr_cycle && Array.isArray(m.ehr_cycle.compounds))
        ? m.ehr_cycle.compounds.map(c => c.id).filter(Boolean)
        : [];
      process.stdout.write(ids.sort().join('\n'));
    } catch (e) { process.exit(0); }
  " 2>/dev/null)

  # 2) 실제 파일 블록 스캔 (reference/ + skills/domain-knowledge/)
  local marker_ids=""
  for dir in "$project_root/reference" "$project_root/skills/domain-knowledge"; do
    [[ -d "$dir" ]] || continue
    marker_ids="$marker_ids$(find "$dir" -name "*.md" -type f 2>/dev/null -print0 \
      | xargs -0 grep -hoE "<!-- EHR-COMPOUND:BEGIN [A-Za-z0-9_-]+" 2>/dev/null \
      | sed 's|<!-- EHR-COMPOUND:BEGIN ||')"$'\n'
  done
  marker_ids=$(echo "$marker_ids" | grep -v '^$' | sort -u)

  # 3) orphan_compound = json - marker
  if [[ -n "$json_ids" ]]; then
    comm -23 <(echo "$json_ids") <(echo "$marker_ids") 2>/dev/null \
      | grep -v '^$' \
      | while read -r id; do echo "orphan_compound:$id:(unknown file)"; done
  fi

  # 4) orphan_marker = marker - json
  if [[ -n "$marker_ids" ]]; then
    comm -13 <(echo "$json_ids") <(echo "$marker_ids") 2>/dev/null \
      | grep -v '^$' \
      | while read -r id; do
          local file=""
          for dir in "$project_root/reference" "$project_root/skills/domain-knowledge"; do
            [[ -d "$dir" ]] || continue
            local found
            found=$(grep -rl "<!-- EHR-COMPOUND:BEGIN $id" "$dir" 2>/dev/null | head -1)
            if [[ -n "$found" ]]; then file="$found"; break; fi
          done
          echo "orphan_marker:$id:${file:-?}"
        done
  fi
}

# Stale promotion 검출: promoted[].backup 이 실존하지 않음
ehr_audit_stale_promotion() {
  local project_root="$1"
  local harness_json="$project_root/.claude/HARNESS.json"
  [[ -f "$harness_json" ]] || return 0

  local backups
  backups=$(HARNESS_JSON="$harness_json" node -e "
    try {
      const m = JSON.parse(require('fs').readFileSync(process.env.HARNESS_JSON, 'utf8'));
      const rows = (m.ehr_cycle && Array.isArray(m.ehr_cycle.promoted))
        ? m.ehr_cycle.promoted.filter(p => p && p.backup && !p.backup_cleaned).map(p => p.backup)
        : [];
      process.stdout.write(rows.join('\n'));
    } catch (e) { process.exit(0); }
  " 2>/dev/null)

  if [[ -n "$backups" ]]; then
    while IFS= read -r bk_path; do
      [[ -z "$bk_path" ]] && continue
      [[ -f "$project_root/$bk_path" ]] || echo "stale_promotion::$bk_path"
    done <<< "$backups"
  fi
}

# EHR-PREFERENCES 파싱 가능성 검증
ehr_audit_preferences_parse() {
  local project_root="$1"
  local claude_md="$project_root/CLAUDE.md"
  [[ -f "$claude_md" ]] || return 0

  local begin end
  begin=$(grep -n "<!-- EHR-PREFERENCES:BEGIN" "$claude_md" 2>/dev/null | head -1 | cut -d: -f1)
  end=$(grep -n "<!-- EHR-PREFERENCES:END" "$claude_md" 2>/dev/null | head -1 | cut -d: -f1)

  if [[ -z "$begin" || -z "$end" || "$begin" -ge "$end" ]]; then
    echo "preferences_corruption::CLAUDE.md — 블록 구조 깨짐 (BEGIN/END 불일치)"
    return 0
  fi

  # 블록 내부의 유효 key=value 엔트리 수 카운트
  local body_lines_ok
  body_lines_ok=$(sed -n "$((begin+1)),$((end-1))p" "$claude_md" \
    | grep -vE '^\s*#|^\s*$' \
    | grep -cE '^[A-Z_]+=[^=]+$')

  [[ "$body_lines_ok" -lt 1 ]] && echo "preferences_corruption::CLAUDE.md — 유효 key=value 엔트리 없음"
  return 0
}

# 통합 드리프트 리포트
ehr_audit_report() {
  local project_root="$1"
  echo "=== EHR Cycle 드리프트 리포트 ==="
  echo ""
  local compound_drift
  compound_drift=$(ehr_audit_compound_drift "$project_root")
  [[ -n "$compound_drift" ]] && echo "[Compound 드리프트]" && echo "$compound_drift" && echo ""
  local stale
  stale=$(ehr_audit_stale_promotion "$project_root")
  [[ -n "$stale" ]] && echo "[Stale Promotion]" && echo "$stale" && echo ""
  local pref
  pref=$(ehr_audit_preferences_parse "$project_root")
  [[ -n "$pref" ]] && echo "[Preferences 파싱]" && echo "$pref" && echo ""
  echo "=== 리포트 종료 ==="
}
