#!/usr/bin/env bash
# audit.sh — drift 계산 + 리포트 생성
#
# 사용 예:
#   source audit.sh
#   compute_drift "$BEFORE_JSON" "$AFTER_JSON"

set -u

# ── Drift 계산 ──
# args: before_json after_json
# stdout: JSON 객체 {module_map:{added,removed,changed}, session_vars:{added,removed}, ...}
compute_drift() {
  local before="$1"
  local after="$2"

  BEFORE="$before" AFTER="$after" node -e "
    const before = JSON.parse(process.env.BEFORE);
    const after  = JSON.parse(process.env.AFTER);

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
          if (JSON.stringify(av) !== JSON.stringify(v)) {
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
