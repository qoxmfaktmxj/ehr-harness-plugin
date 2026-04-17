#!/usr/bin/env node
// gen-example-codemap.js — EHR4 예시 병합 CODE_MAP 스냅샷 생성기 (offline 도구)
//
// 용도:
//   EHR4 는 표준 기본 패키지가 없어 reference 스냅샷을 "여러 예시 프로젝트 병합" 으로 구성.
//   이 스크립트는 PROJECTS 배열의 예시 프로젝트들을 스캔해 병합 CODE_MAP 을 생성한다.
//   생성물은 plugins/ehr-harness/profiles/ehr4/reference/CODE_MAP.md 로 저장되어
//   런타임 생성 실패 시 fallback 참조로 사용된다.
//
// 런타임 단일 프로젝트 생성기는 lib/gen-code-map.js 참조 (용도 분리).
//
// 사용법:
//   node scripts/gen-example-codemap.js > plugins/ehr-harness/profiles/ehr4/reference/CODE_MAP.md
//
// 새 예시 프로젝트 추가 시 아래 PROJECTS 배열에 한 줄 추가 후 재실행.

const fs = require('fs');
const path = require('path');

const PROJECTS = [
  { root: 'C:/EHR_PROJECT/EHR_NG', name: 'EHR_NG', initial: 'N' },
  { root: 'C:/EHR_PROJECT/EHR_SY', name: 'EHR_SY', initial: 'S' },
  { root: 'C:/EHR_PROJECT/OPTI_UNID', name: 'OPTI_UNID', initial: 'O' },
];

const MODULE_LABELS = {
  hrm: 'HRM (인사관리)',
  cpn: 'CPN (급여/임금)',
  tim: 'TIM (근태관리)',
  pap: 'PAP (성과/평가)',
  tra: 'TRA (교육훈련)',
  wtm: 'WTM (근무시간관리)',
  ben: 'BEN (복리후생)',
  hri: 'HRI (인사정보/조회)',
  org: 'ORG (조직관리)',
  sys: 'SYS (시스템관리)',
  com: 'COM (공통)',
  common: 'COMMON (공통 유틸)',
  main: 'MAIN (메인)',
  sample: 'SAMPLE (샘플)',
  eis: 'EIS (경영정보)',
  kms: 'KMS (지식관리)',
  stf: 'STF (채용)',
  hrd: 'HRD (CDP/경력관리)',
  mnt: 'MNT (멘토링)',
  est: 'EST (기초설정)',
  ftm: 'FTM (휴일근무/연장근무)',
  template: 'TEMPLATE (템플릿)',
};

function collect(proj) {
  const hrRoot = `${proj.root}/src/com/hr`;
  if (!fs.existsSync(hrRoot)) {
    console.error(`[${proj.name}] src/com/hr 없음 — 스킵 (${hrRoot})`);
    return {};
  }
  const entries = fs.readdirSync(hrRoot, { recursive: true, withFileTypes: true });
  const mods = {};
  let ctrlCount = 0;
  for (const ent of entries) {
    if (!ent.isFile() || !ent.name.endsWith('Controller.java')) continue;
    const parent = ent.parentPath || ent.path;
    const rel = path.relative(hrRoot, parent).replace(/\\/g, '/');
    const parts = rel.split('/').filter(Boolean);
    if (parts.length < 1) continue;
    const mod = parts[0];
    const screen = parts[parts.length - 1];
    const sub = parts.length >= 3 ? parts[1] : '_root';
    mods[mod] = mods[mod] || {};
    mods[mod][sub] = mods[mod][sub] || new Set();
    mods[mod][sub].add(screen);
    ctrlCount++;
  }
  for (const m in mods) for (const s in mods[m]) mods[m][s] = [...mods[m][s]].sort();
  console.error(`[${proj.name}] ${ctrlCount}개 Controller → ${Object.keys(mods).length}개 모듈`);
  return mods;
}

const results = PROJECTS.map(p => ({ ...p, modules: collect(p) }));

// 병합: mod → sub → { screen: Set<initial> }
const merged = {};
for (const r of results) {
  for (const mod in r.modules) {
    merged[mod] = merged[mod] || {};
    for (const sub in r.modules[mod]) {
      merged[mod][sub] = merged[mod][sub] || {};
      for (const scr of r.modules[mod][sub]) {
        merged[mod][sub][scr] = merged[mod][sub][scr] || new Set();
        merged[mod][sub][scr].add(r.initial);
      }
    }
  }
}

// 렌더
const now = new Date().toISOString().slice(0, 10);
const lines = [
  '# EHR4 코드맵 (참조 예시 통합)',
  '',
  `> ${PROJECTS.map(p => p.name).join(', ')} ${PROJECTS.length}개 예시 프로젝트의 \`*Controller.java\` 위치를 병합한 스냅샷. EHR4 는 표준 기본 패키지가 없으므로 이 맵은 **fallback 참조** — 실제 하네스 생성 시 \`lib/gen-code-map.js\` 가 대상 프로젝트의 CODE_MAP 을 런타임 생성하며, 그 단계가 실패할 때만 이 파일이 복사된다.`,
  `> 출처 태그: ${PROJECTS.map(p => `\`[${p.initial}]\` ${p.name}`).join(' · ')}. 여러 글자 결합 = 복수 프로젝트에 존재.`,
  `> 생성일: ${now}`,
  '',
];

const modKeys = Object.keys(merged).sort();
for (const mod of modKeys) {
  const label = MODULE_LABELS[mod] || mod.toUpperCase();
  const subKeys = Object.keys(merged[mod]).sort();
  const totalScreens = subKeys.reduce((sum, sub) => sum + Object.keys(merged[mod][sub]).length, 0);
  lines.push(`## ${label} — \`src/com/hr/${mod}/\` (${totalScreens}화면)`);
  lines.push('');
  for (const sub of subKeys) {
    const screensObj = merged[mod][sub];
    const entries = Object.entries(screensObj).sort((a, b) => a[0].localeCompare(b[0]));
    const count = entries.length;
    const subLabel = sub === '_root' ? '(루트 직속)' : `${sub}/`;
    const preview = entries.slice(0, 3).map(([n, s]) => `${n} [${[...s].sort().join('')}]`).join(', ');
    const extra = count > 3 ? ` 외 ${count - 3}개` : '';
    lines.push(`- **${subLabel}** (${count}화면): ${preview}${extra}`);
  }
  lines.push('');
}

lines.push('---');
lines.push('');
lines.push('## 프로젝트별 수치');
lines.push('');
lines.push('| 프로젝트 | 모듈 수 | Controller 총개수 |');
lines.push('|----------|---------|--------------------|');
for (const r of results) {
  const modCount = Object.keys(r.modules).length;
  const ctrlTotal = Object.values(r.modules).reduce(
    (s, subs) => s + Object.values(subs).reduce((s2, scr) => s2 + scr.length, 0),
    0
  );
  lines.push(`| ${r.name} | ${modCount} | ${ctrlTotal} |`);
}

process.stdout.write(lines.join('\n') + '\n');
