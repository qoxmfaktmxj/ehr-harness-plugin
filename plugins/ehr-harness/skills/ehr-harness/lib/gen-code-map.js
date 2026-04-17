#!/usr/bin/env node
// gen-code-map.js — 하네스 생성 시 대상 프로젝트의 CODE_MAP.md 를 런타임 생성
//
// 사용법:
//   node gen-code-map.js <PROJECT_ROOT> <ehr4|ehr5>
//
// 출력: stdout 에 CODE_MAP.md 마크다운
// 에러: stderr 에 사유 + exit code (2=usage, 3=path, 4=no-controller)
//
// 원칙:
//   - 대상 프로젝트의 *Controller.java 위치를 스캔해 서브패키지 → 화면 매핑 추출
//   - EHR4: src/com/hr (Ant 표준)
//   - EHR5: src/main/java/com/hr (Maven 표준), 레거시 fallback src/com/hr
//   - 출력 포맷은 EHR5 기본 패키지 CODE_MAP 과 시각적으로 일관
//
// 호출처: plugins/ehr-harness/skills/ehr-harness/SKILL.md Step 2-L-2
// 오프라인 예시 병합 버전은 scripts/gen-example-codemap.js 참조

const fs = require('fs');
const path = require('path');

function die(msg, code = 2) {
  process.stderr.write('[gen-code-map] ' + msg + '\n');
  process.exit(code);
}

const [projectRoot, profile] = process.argv.slice(2);
if (!projectRoot || !['ehr4', 'ehr5'].includes(profile)) {
  die('usage: node gen-code-map.js <PROJECT_ROOT> <ehr4|ehr5>', 2);
}

const PROFILE_ROOTS = {
  ehr4: ['src/com/hr'],
  ehr5: ['src/main/java/com/hr', 'src/com/hr'],
};

const rootCandidates = PROFILE_ROOTS[profile].map(rel => ({
  rel,
  abs: path.join(projectRoot, rel),
}));
const hit = rootCandidates.find(c => fs.existsSync(c.abs));
if (!hit) {
  die(
    `Java root 를 찾을 수 없음. 확인한 경로: ${rootCandidates.map(c => c.abs).join(', ')}`,
    3
  );
}
const hrRoot = hit.abs;
const javaRootRel = hit.rel;

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

// 스캔
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

if (ctrlCount === 0) {
  die(`${hrRoot} 아래 *Controller.java 0건 — 이 프로젝트는 EHR 구조가 아닐 수 있음`, 4);
}

// 렌더
const projectName = path.basename(path.resolve(projectRoot));
const now = new Date().toISOString().slice(0, 10);
const modCount = Object.keys(mods).length;
const lines = [
  `# 코드맵 — ${projectName}`,
  '',
  '> 이 프로젝트의 `*Controller.java` 위치를 자동 수집한 스냅샷. 에이전트(codebase-navigator, screen-builder)가 유사 화면 탐색 및 네이밍 규약 참조에 사용한다.',
  `> 프로파일: ${profile.toUpperCase()} · Java 루트: \`${javaRootRel}\` · 생성일: ${now} · Controller ${ctrlCount}건 / ${modCount}개 모듈`,
  '',
];

const modKeys = Object.keys(mods).sort();
for (const mod of modKeys) {
  const label = MODULE_LABELS[mod] || mod.toUpperCase();
  const subKeys = Object.keys(mods[mod]).sort();
  const totalScreens = subKeys.reduce((s, sub) => s + mods[mod][sub].length, 0);
  lines.push(`## ${label} — \`${javaRootRel}/${mod}/\` (${totalScreens}화면)`);
  lines.push('');
  for (const sub of subKeys) {
    const screens = mods[mod][sub];
    const count = screens.length;
    const subLabel = sub === '_root' ? '(루트 직속)' : `${sub}/`;
    const preview = screens.slice(0, 3).join(', ');
    const extra = count > 3 ? ` 외 ${count - 3}개` : '';
    lines.push(`- **${subLabel}** (${count}화면): ${preview}${extra}`);
  }
  lines.push('');
}

process.stdout.write(lines.join('\n') + '\n');
