# EHR Harness — Design Guide Skill, DB Fallback, Superpowers Gate

- **Date**: 2026-04-09
- **Status**: Draft (awaiting user review)
- **Author**: minseok kim (with Claude)
- **Scope**: `plugins/ehr-harness/` (ehr-harness-plugin)

---

## 1. Background

기존 `ehr-harness` 메타 스킬은 EHR 프로젝트(EHR4/EHR5)를 분석하여 화면 생성·코드베이스 탐색·프로시저 추적 등을 위한 5개 스킬을 자동 생성한다. 본 설계는 다음 3가지를 추가한다.

1. **디자인 가이드 스킬 (`ehr-design-guide`)** — 프로젝트의 Storybook 빌드(IDS, ISU Design System)에서 컴포넌트 사용법을 추출하여 화면 생성 시 참조 가능하게 한다.
2. **DB 폴백 인터랙션** — DB 직접 연결이 불가능한 환경에서 사용자가 가진 DDL/프로시저 덤프 폴더를 활용해 하네스를 구성한다.
3. **Superpowers 의존성 게이트** — 하네스 생성 전에 Superpowers 플러그인 설치 여부를 확인하고, 미설치 시 안내 후 중단한다.

세 가지는 상호 독립적이지만 모두 `ehr-harness/SKILL.md`(메타 스킬)에 단계로 추가된다.

---

## 2. Goals & Non-goals

### Goals
- Storybook 빌드 산출물에서 컴포넌트 가이드를 추출하여 `screen-builder`가 참조할 수 있게 한다.
- DB 연결이 불가능한 환경에서도 하네스가 의미 있게 동작하도록 한다.
- Superpowers 미설치 사용자에게 명확한 안내를 제공하고 하네스 생성을 차단한다.
- Storybook 변경 시 stale 캐시 위험을 최소화한다 (freshness 체크 + 점진적 재추출).

### Non-goals
- Storybook **소스 .mdx 파일** 파싱 (소스 파일이 프로젝트에 없음 — 빌드 산출물만 다룸).
- Oracle expdp **바이너리 덤프(.dmp)** 지원 (impdp로 import 후 직접 연결 필요).
- **다중 Storybook** 시나리오 (한 프로젝트 = 한 Storybook 가정).
- Superpowers **자동 설치** (Claude는 보안상 슬래시 명령을 프로그램적으로 실행할 수 없음).

---

## 3. Architecture Overview

### 3.1 변경 면 (변경되는 파일)

```
plugins/ehr-harness/
├── skills/ehr-harness/SKILL.md                          ★ 수정
└── profiles/
    ├── ehr4/skills/
    │   ├── design-guide/SKILL.md.skel                   ★ 신규
    │   ├── screen-builder/SKILL.md.skel                 ★ 수정
    │   ├── procedure-tracer/SKILL.md.skel               ★ 수정
    │   └── db-query/SKILL.md.skel                       ★ 수정
    └── ehr5/skills/
        ├── design-guide/SKILL.md.skel                   ★ 신규
        ├── screen-builder/SKILL.md.skel                 ★ 수정
        ├── procedure-tracer/SKILL.md.skel               ★ 수정
        └── db-query/SKILL.md.skel                       ★ 수정
```

### 3.2 메타 스킬 단계 변화

```
Step 0   플러그인 위치 탐색                                  (기존)
Step 0.5 Superpowers 의존성 검증                              ★ 신규
Step 1   EHR 버전 감지                                       (기존)
Step 2   프로젝트 분석
  ├ 2-A ~ 2-I                                                (기존)
  ├ 2-J  DB 접속 정보 탐지 + 인터랙티브 폴백                  ★ 확장
  └ 2-K  Storybook 디자인 가이드 탐지                         ★ 신규
Step 3   파일 생성
  ├ 3-A ~ 3-E                                                (기존)
  └ 3-F  ehr-design-guide 스킬 생성                           ★ 신규
Step 4   검증 (디자인 가이드 항목 추가)                       (기존+α)
```

### 3.3 프로젝트에 생성되는 산출물

```
.claude/skills/
├── ehr-domain-knowledge/                  (기존)
├── ehr-screen-builder/                    (기존, IDS 참조 섹션 추가)
├── ehr-codebase-navigator/                (기존)
├── ehr-procedure-tracer/                  (기존, DB_MODE 분기 추가)
├── ehr-db-query/                          (기존, DUMP 모드 추가)
│   ├── SKILL.md
│   ├── DB_MODE                            ★ 신규 (1줄: direct/dump/code-only)
│   └── DUMP_INDEX.json                    ★ 조건부 신규 (DUMP 모드 시)
└── ehr-design-guide/                      ★ 조건부 신규 (Storybook 발견 시)
    ├── SKILL.md
    ├── MANIFEST.json
    └── references/
        ├── INDEX.md                       (46개 컴포넌트 카탈로그)
        ├── 00-Introduction.md             (사전 추출)
        ├── 01-Naming-Rules.md             (사전 추출)
        ├── 02-Legacy-JSP-Migration.md     (사전 추출)
        ├── 03-Quick-Reference.md          (사전 추출)
        ├── Button.md                      (사전 추출)
        ├── Chip.md                        (사전 추출)
        ├── FormSelect.md                  (사전 추출)
        ├── FormSelect2.md                 (사전 추출)
        ├── Table.md                       (사전 추출)
        └── Text.md                        (사전 추출)
```

### 3.4 모드 컨벤션 (`DB_MODE`)

Step 2-J 결과로 결정. 후속 스킬 동작에 영향:

| 값 | 의미 | 영향 |
|---|---|---|
| `direct` | DB 직접 연결 가능 | `db-query`는 SQL 실행, `procedure-tracer`는 USER_SOURCE 조회 |
| `dump` | DDL 덤프 폴더 사용 | `db-query`는 폴더 grep, `procedure-tracer`는 DUMP_INDEX 참조 |
| `code-only` | 코드 grep만 | 매퍼 XML grep만 사용 |

---

## 4. Topic 1 — `ehr-design-guide` 스킬

### 4.1 탐지 (Step 2-K)

**고정 경로**: `src/main/resources/static/guide/storybook-static/`

```bash
SB_PATH="src/main/resources/static/guide/storybook-static"
if [ -d "$SB_PATH" ] && [ -f "$SB_PATH/project.json" ]; then
  DESIGN_GUIDE=true
else
  DESIGN_GUIDE=false
fi
```

광역 탐색·다중 Storybook은 지원하지 않는다. 위 경로가 비어있으면 `ehr-design-guide` 스킬 자체를 생성하지 않고 다음 단계로 진행한다.

### 4.2 추출 전략 — B2 (핵심만 사전 추출 + JIT)

**사전 추출 대상 (10개)**:
- `00-guides/` 4개: Introduction, Naming-Rules, Legacy-JSP-Migration, Quick-Reference
- `01-atoms/` 6개: Button, Chip, FormSelect, FormSelect2, Table, Text

**나머지 36개**: 인덱스(`INDEX.md`)와 매핑(`MANIFEST.json:title_to_js`)만 보유. 사용자가 요청 시 JIT 추출.

**근거**:
- 화면 생성에 99% 사용되는 핵심 가이드(`00-guides/*`)와 atoms는 사전 추출하여 토큰 비용 최저화.
- 사용 빈도가 낮은 layouts/utilities/modules/modal는 JIT으로 둬서 캐시 stale 위험을 최소화.
- 풀 추출(B1)은 생성 비용이 너무 크고, Storybook 변경 시 전체 무효화 부담.
- 인덱스만(B3)은 매번 JSX 파싱 토큰을 반복 지불.

### 4.3 추출 방식 — Claude inline

별도 파서 스크립트를 만들지 않는다. 하네스 생성 시 Claude가 직접 빌드된 JS 파일을 읽고 마크다운으로 변환한다.

**근거**:
- JSX 함수 호출의 중첩(`s.p` 안의 `s.strong`), 한글 콘텐츠, 이스케이프 처리는 정규식보다 LLM이 안정적.
- 1회성 비용(약 40K 토큰 추정)이 유지보수 부담 없는 코드보다 가치 있음.
- JIT 추출도 동일한 방식이라 패턴 일관성 확보.

**변환 규칙**:
| JSX 함수 호출 | 마크다운 |
|---|---|
| `n.jsx(s.h1, ..., children: "X")` | `# X` |
| `n.jsx(s.h2, ..., children: "X")` | `## X` |
| `n.jsx(s.p, ..., children: "X")` | 단락 텍스트 |
| `n.jsx(s.ol/ul, ..., children: [...])` | 번호/불릿 리스트 |
| `n.jsx(s.li, ..., children: ...)` | 리스트 항목 |
| `n.jsx(s.strong, ..., children: "X")` | `**X**` |
| `n.jsx(s.code, ..., children: "X")` (인라인) | `` `X` `` |
| `n.jsx(s.pre, ..., children: n.jsx(s.code, ..., className: "language-XXX", children: \`...\`))` | ` ```XXX 펜스 블록 ``` ` |
| `n.jsx(s.hr)` | `---` |

### 4.4 MANIFEST.json 스키마

```json
{
  "schema_version": 1,
  "storybook_path": "src/main/resources/static/guide/storybook-static",
  "generated_at": 1772167285688,
  "storybook_version": "9.1.13",
  "extracted_at": "2026-04-09T13:30:00",
  "pre_extracted": [
    "00-Introduction", "01-Naming-Rules", "02-Legacy-JSP-Migration",
    "03-Quick-Reference", "Button", "Chip", "FormSelect", "FormSelect2",
    "Table", "Text"
  ],
  "title_to_js": {
    "01-atoms/Button": "assets/Button-DfetVkf1.js",
    "03-pages/DoubleSheet": "assets/DoubleSheet-mCpapz3A.js"
  }
}
```

### 4.5 Freshness 체크

`ehr-design-guide` SKILL.md에 다음 워크플로 명시:

1. 스킬 호출 시마다 `$SB_PATH/project.json`의 `generatedAt` 값 조회
2. MANIFEST.json의 `generated_at`과 비교
3. 다르면 사용자에게 경고:
   ```
   ⚠ Storybook이 [날짜] 기준으로 재빌드됐어요.
     /ehr-harness 다시 실행해서 디자인 가이드를 갱신하는 걸 권장합니다.
   ```
4. 같으면 조용히 진행

**`/ehr-harness` 재실행 시 동작**:
- `generated_at` 일치 → 디자인 가이드 Step(2-K, 3-F) 전체 스킵
- `generated_at` 불일치 → 핵심 10개를 모두 재추출하고 MANIFEST 갱신

> 참고: `generated_at`만으로는 어떤 컴포넌트가 변경됐는지 파일별로 알 수 없으므로 "10개 모두 재추출" 방식이다. 파일별 해시 추적은 향후 개선 여지(Section 8 참고).

### 4.6 JIT 추출 절차

1. 사용자가 컴포넌트 X 요청
2. MANIFEST.json 로드, `pre_extracted`에 X 있으면 → `references/X.md` 직접 읽기 (끝)
3. 없으면 `title_to_js[X]`로 JS 파일 경로 획득
4. 해당 JS 파일을 Read로 읽고, 변환 규칙 적용해 인라인 마크다운 생성
5. **JIT 결과는 `references/`에 저장하지 않는다** (캐시 안 함, 항상 최신)

### 4.7 `screen-builder` 크로스 링크

`profiles/<profile>/skills/screen-builder/SKILL.md.skel`에 새 섹션을 추가한다. 정확한 단계 번호는 기존 SKILL.md.skel 구조를 보고 결정하지만, **"화면 코드 작성 직전"** 단계로 배치한다 (사용자가 어떤 컴포넌트를 쓸지 결정한 후, 실제 코드 생성 전).

```markdown
## [화면 코드 작성 직전 단계]: IDS 디자인 가이드 참조

if [ -f .claude/skills/ehr-design-guide/SKILL.md ]; then
  Read: .claude/skills/ehr-design-guide/references/00-Introduction.md
  Read: .claude/skills/ehr-design-guide/references/01-Naming-Rules.md
  # 사용할 컴포넌트별 references 추가 로드
  # 사전 추출 안 된 컴포넌트는 ehr-design-guide의 JIT 절차를 따른다
fi
```

→ 디자인 가이드 스킬이 없으면 이 단계 전체 스킵.

---

## 5. Topic 2 — DB 폴백 (Step 2-J 확장)

### 5.1 결정 트리

```
[1] 접속 정보 grep
[2] 발견됨?
  YES → [3] sqlplus/jdbc 연결 시도
    OK   → DB_MODE=direct, 끝
    FAIL → 역질문 ① (접속 실패)
  NO  → 역질문 ② (접속 정보 미발견)
[4] 사용자 선택:
  (1) DIRECT 재시도 — 접속 정보 직접 입력 (3회 실패 시 자동 code-only)
  (2) DUMP 모드 — 폴더 경로 입력
  (3) CODE-ONLY — 코드 grep만 진행
```

### 5.2 인터랙션 방식

분기 선택은 `AskUserQuestion` 도구 사용 (멀티초이스 UI). 자유 텍스트 입력(폴더 경로, 접속 정보)은 후속 메시지에서 받음.

### 5.3 폴더 처리 가정

| 항목 | 결정 |
|---|---|
| 폴더 위치 | 매번 다름 → 항상 사용자 입력 |
| 확장자 | 무시 (.sql, .pkb, .pks, .prc, .fnc, .trg, .txt, 등 어떤 것도 허용) |
| 인코딩 | UTF-8 고정 |
| 형태 | 대부분 F2 (서브폴더별: tables/, procedures/, packages/, functions/, triggers/) |

### 5.4 형태 자동 판정 (F1~F5)

| 코드 | 형태 |
|---|---|
| F1 | 단일 거대 SQL 파일 |
| F2 | 객체 타입별 서브폴더 (tables/, procedures/, ...) |
| F3 | 객체별 개별 파일 (한 폴더에 다 섞임) |
| F4 | Toad/SQL Developer 카테고리별 익스포트 (`*DDL*`, `*Procedures*`) |
| F5 | Oracle expdp 바이너리 (`.dmp`) — 미지원, 안내 후 종료 |

### 5.5 객체 검출 패턴

EHR 컨벤션 가정 (접두어 기반):

```bash
TABLE   : CREATE\s+(OR\s+REPLACE\s+)?TABLE\s+T_
PROC    : CREATE\s+(OR\s+REPLACE\s+)?PROCEDURE\s+P_
PACKAGE : CREATE\s+(OR\s+REPLACE\s+)?PACKAGE(\s+BODY)?\s+PKG_
FUNC    : CREATE\s+(OR\s+REPLACE\s+)?FUNCTION\s+F_
TRIGGER : CREATE\s+(OR\s+REPLACE\s+)?TRIGGER\s+TRG_
```

→ 컨벤션을 벗어난 객체(예: `MY_TABLE_NAME`)는 인덱싱에서 누락될 수 있음. 향후 보완 여지.

### 5.6 DUMP_INDEX.json 스키마

```json
{
  "schema_version": 1,
  "dump_dir": "C:/EHR_PROJECT/db_dump/",
  "format": "F2",
  "scanned_at": "2026-04-09T13:45:00",
  "encoding": "utf-8",
  "stats": {
    "total_files": 487,
    "tables": 234,
    "procedures": 156,
    "packages": 12,
    "functions": 45,
    "triggers": 40
  },
  "objects": {
    "P_CPN_CAL_PAY_MAIN": {
      "type": "PROCEDURE",
      "file": "C:/EHR_PROJECT/db_dump/procedures/P_CPN_CAL_PAY_MAIN.sql",
      "line": 1
    },
    "PKG_CPN_SEP": {
      "type": "PACKAGE",
      "file": "C:/EHR_PROJECT/db_dump/packages/PKG_CPN_SEP.pkb",
      "line": 1
    }
  }
}
```

### 5.7 후속 스킬 분기

`procedure-tracer`와 `db-query`의 SKILL.md에 진입부에서 `DB_MODE` 읽고 분기:

```bash
DB_MODE=$(cat .claude/skills/ehr-db-query/DB_MODE 2>/dev/null || echo "code-only")
case "$DB_MODE" in
  direct)    # USER_OBJECTS / USER_SOURCE 직접 쿼리 ;;
  dump)      # DUMP_INDEX.json 참조 → 객체명 → 파일경로 → grep/read ;;
  code-only) # 매퍼 XML grep만 ;;
esac
```

---

## 6. Topic 3 — Superpowers Gate (Step 0.5)

### 6.1 검증 로직

```bash
SETTINGS="$HOME/.claude/settings.json"

if [ ! -f "$SETTINGS" ]; then
  echo "⚠ Claude Code 설정 파일을 찾을 수 없습니다: $SETTINGS"
  exit 1
fi

# 주의: SETTINGS를 Node 서브프로세스에 환경변수로 전달해야 함
# (export 없이는 process.env.SETTINGS가 undefined)
HAS_SP=$(SETTINGS="$SETTINGS" node -e "
  try {
    const fs = require('fs');
    const s = JSON.parse(fs.readFileSync(process.env.SETTINGS, 'utf8'));
    const ep = s.enabledPlugins || {};
    const found = Object.keys(ep).some(k =>
      k.startsWith('superpowers@') && ep[k] === true
    );
    console.log(found ? 'yes' : 'no');
  } catch(e) { console.log('error'); }
" 2>/dev/null)

if [ "$HAS_SP" != "yes" ]; then
  print_install_guide
  exit 0
fi
```

**핵심**: `superpowers@*` 와일드카드 매칭. `superpowers@superpowers-marketplace`(obra 본인) / `superpowers@claude-plugins-official`(Anthropic 미러) 둘 다 인정.

### 6.2 미설치 시 안내 메시지

```
═══════════════════════════════════════════════════════════════
  ⚠ Superpowers 플러그인이 필요합니다.
═══════════════════════════════════════════════════════════════

  EHR 하네스는 Superpowers의 메타 스킬을 활용합니다:
    • brainstorming           — 코드 작성 전 설계 합의
    • writing-plans           — 변경 전 단계별 계획서
    • test-driven-development — 테스트 우선 개발
    • verification-before-completion — 완료 검증
    • systematic-debugging    — 가설 기반 디버깅

  이게 없으면 화면 생성/프로시저 분석이 반쪽이 됩니다.

  ┌─────────────────────────────────────────────────────────┐
  │ 설치 방법                                                │
  │                                                          │
  │ 1) Claude Code에서 다음 두 명령을 차례로 실행:           │
  │                                                          │
  │   /plugin marketplace add obra/superpowers-marketplace   │
  │   /plugin install superpowers@superpowers-marketplace    │
  │                                                          │
  │ 2) 설치 후 다시 실행 (둘 중 하나):                       │
  │                                                          │
  │   • 슬래시 명령: /ehr-harness                             │
  │   • 자연어:      "이수하네스 만들어줘"                    │
  │                                                          │
  └─────────────────────────────────────────────────────────┘

  GitHub: https://github.com/obra/superpowers
  Maintainer: Jesse Vincent

  (참고: Claude는 보안상 사용자 동의 없이 플러그인을 자동
   설치할 수 없습니다. /plugin 명령은 직접 실행이 필요합니다.)

═══════════════════════════════════════════════════════════════
```

### 6.3 강제 설치 불가 사유

Claude Code 스킬은 도구(Read/Write/Bash 등)만 사용 가능하다. `/plugin install` 같은 슬래시 명령을 프로그램적으로 호출할 권한이 없으며, 이는 사용자 동의 없이 플러그인이 설치되는 것을 막기 위한 보안 설계다. 따라서 "강제"의 현실적 의미는 **하네스 생성을 중단하고 명확한 안내 후 재실행 요청**이다.

---

## 7. Files to Create / Modify

### 7.1 신규

| 경로 | 설명 |
|---|---|
| `plugins/ehr-harness/profiles/ehr4/skills/design-guide/SKILL.md.skel` | EHR4 디자인 가이드 스킬 템플릿 |
| `plugins/ehr-harness/profiles/ehr5/skills/design-guide/SKILL.md.skel` | EHR5 디자인 가이드 스킬 템플릿 |
| `docs/superpowers/specs/2026-04-09-ehr-harness-design-guide-and-db-fallback-design.md` | 본 설계 문서 |

### 7.2 수정

| 경로 | 변경 |
|---|---|
| `plugins/ehr-harness/skills/ehr-harness/SKILL.md` | Step 0.5 추가, Step 2-J 확장, Step 2-K 신규, Step 3-F 신규, Step 4 보고에 디자인 가이드 항목 추가 |
| `plugins/ehr-harness/profiles/ehr4/skills/screen-builder/SKILL.md.skel` | IDS 가이드 참조 섹션 추가 |
| `plugins/ehr-harness/profiles/ehr5/skills/screen-builder/SKILL.md.skel` | IDS 가이드 참조 섹션 추가 |
| `plugins/ehr-harness/profiles/ehr4/skills/procedure-tracer/SKILL.md.skel` | DB_MODE 분기 추가 |
| `plugins/ehr-harness/profiles/ehr5/skills/procedure-tracer/SKILL.md.skel` | DB_MODE 분기 추가 |
| `plugins/ehr-harness/profiles/ehr4/skills/db-query/SKILL.md.skel` | DUMP 모드 섹션 추가 |
| `plugins/ehr-harness/profiles/ehr5/skills/db-query/SKILL.md.skel` | DUMP 모드 섹션 추가 |

### 7.3 산출물 (사용자 프로젝트에 생성됨)

조건부로 생성:
- `.claude/skills/ehr-db-query/DB_MODE` (항상)
- `.claude/skills/ehr-db-query/DUMP_INDEX.json` (DUMP 모드 시)
- `.claude/skills/ehr-design-guide/` 디렉토리 트리 (Storybook 발견 시)

---

## 8. Open Questions / Future Work

- **연결 테스트 명령**: `sqlplus`/`jdbc test` 중 어느 걸 1차로 쓸지는 사용자 환경에 따라 다름. 첫 구현에서는 두 가지를 순차 시도하고, 실패 시 사용자에게 보고만 한다.
- **객체 컨벤션 벗어난 케이스**: `T_/P_/PKG_/F_/TRG_` 외의 명명을 쓰는 객체는 DUMP_INDEX 인덱싱에서 누락될 수 있음. 이번 범위에서는 스코프 외.
- **추출 토큰 비용**: 1회성 ~40K 토큰 추정이지만 실측 후 조정 여지.
- **JIT 추출 캐시**: 현재는 캐시하지 않음. 사용 빈도가 높은 layout이 있다면 다음 `/ehr-harness` 재실행 시 사전 추출 목록에 추가하는 것을 고려.
- **파일별 해시 추적**: 현재는 `generated_at` 단일 값만 비교하므로 Storybook 일부만 변경돼도 핵심 10개를 모두 재추출한다. 각 JS 파일의 SHA를 MANIFEST에 저장하면 변경된 파일만 선별 재추출 가능. 첫 구현에서는 단순함을 우선해 스코프 외로 둔다.

---

## 9. Acceptance Criteria

본 설계가 구현되면 다음이 모두 동작한다:

1. Superpowers 미설치 사용자가 `/ehr-harness` 실행 시 안내 메시지를 보고 하네스가 생성되지 않는다.
2. Superpowers 설치 후 재실행 시 정상적으로 Step 1으로 진입한다.
3. DB 직접 연결 가능한 환경에서 기존과 동일하게 동작한다 (`DB_MODE=direct`).
4. DB 연결 정보를 못 찾거나 연결 실패 시 사용자에게 분기 선택지를 제시한다.
5. 사용자가 DUMP 모드 선택 후 폴더 경로를 입력하면 DUMP_INDEX.json이 생성된다.
6. Storybook이 있는 EHR_HR50 프로젝트에서 `ehr-design-guide` 스킬이 생성되고, 사전 추출된 10개 references 마크다운이 만들어진다.
7. Storybook이 없는 프로젝트에서는 `ehr-design-guide` 스킬이 생성되지 않는다.
8. `screen-builder` 스킬은 디자인 가이드 스킬 존재 여부에 따라 분기 동작한다.
9. Storybook 재빌드 후 `/ehr-harness` 재실행 시 `generated_at` 비교로 핵심 10개만 재추출한다 (변동 없으면 스킵).
10. `ehr-design-guide` 호출 시 `generated_at` 불일치하면 stale 경고를 출력한다.
