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
