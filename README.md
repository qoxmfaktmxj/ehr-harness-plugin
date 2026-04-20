# EHR Harness Plugin

Oracle 프로시저 기반 레거시 인사시스템(EHR)을 위한 AI 코딩 하네스 자동 생성 플러그인.

"하네스 만들어줘" 한 마디로 EHR 프로젝트를 심층 분석하고, 프로젝트에 맞춤화된 하네스를 자동 생성한다.

---

## 목차

1. [하네스란?](#1-하네스란)
2. [플러그인 설치 방법](#2-플러그인-설치-방법)
3. [플러그인 업데이트 방법](#3-플러그인-업데이트-방법)
4. [사용 방법](#4-사용-방법)
5. [생성되는 하네스 구조](#5-생성되는-하네스-구조)
6. [문서 생성 기준](#6-문서-생성-기준)
7. [생성 파이프라인 상세](#7-생성-파이프라인-상세)
8. [프로파일 시스템](#8-프로파일-시스템)
9. [EHR4 vs EHR5 차이점](#9-ehr4-vs-ehr5-차이점)
10. [커스터마이징 범위](#10-커스터마이징-범위)
11. [플러그인 디렉토리 구조](#11-플러그인-디렉토리-구조)
12. [Schema v4 기능](#12-schema-v4-기능-현행)
13. [하네스 Audit (자동 drift 감지)](#13-하네스-audit-자동-drift-감지)
14. [EHR Cycle — 지식 누적 폐곡선 (v1.9.0+)](#14-ehr-cycle--지식-누적-폐곡선-v190)

---

## 1. 하네스란?

**하네스(Harness)** 는 AI 코딩 에이전트가 특정 프로젝트에서 일하기 위한 규칙·지식·도구의 패키지이다.

```
하네스 없이 AI에게 요청:
  "휴가 신청 화면 만들어줘"
  → AI가 React + REST API로 처음부터 만듦 (프로젝트와 완전히 다른 구조)

하네스 있는 AI에게 요청:
  "휴가 신청 화면 만들어줘"
  → AI가 기존 vacationApp을 복제 베이스로 선택
  → 법칙 C(하이브리드) 판정, AuthTableService 주입
  → Anyframe Velocity 매퍼 생성, IBSheet7 JSP 생성
  → 셀프 체크: :ssnEnterCd WHERE 확인, $query 확인, SaveName 일치 확인
```

하네스는 다음으로 구성된다:

| 구성 요소 | 역할 | 파일 |
|-----------|------|------|
| **프로젝트 규칙** | AI가 따라야 할 기술 규칙, 금지 사항 | `AGENTS.md`, `CLAUDE.md` |
| **도메인 지식** | 권한 모델, 법칙 판정, 화면 패턴 등 | `.claude/skills/domain-knowledge/` |
| **전문 스킬** | 화면 생성, 코드 탐색, DB 조회 등 특화 능력 | `.claude/skills/*/SKILL.md` |
| **전문 에이전트** | 복잡한 작업을 자율 수행하는 서브 에이전트 | `.claude/agents/*.md` |
| **안전 장치** | DB 변경 차단 + VCS 커밋 차단 훅 | `.claude/hooks/`, `settings.json` |
| **멀티 플랫폼** | Codex, Gemini CLI 호환 | `.agents/`, `GEMINI.md`, `.codex/` |

### 하네스 구조 예시 (EHR5 프로젝트)

```
your-ehr5-project/
├── AGENTS.md                     ← 범용 프로젝트 규칙 (모든 AI 플랫폼 공통)
├── CLAUDE.md                     ← Claude Code 전용 확장 (스킬 라우팅)
├── GEMINI.md                     ← Gemini CLI 진입점 (Heavy: 스킬 전체 인라인)
├── README.md                     ← 하네스 개요
│
├── .claude/                      ← Claude Code 플랫폼
│   ├── settings.json             ← PreToolUse 훅 등록
│   ├── HARNESS.json              ← 매니페스트 (schema v4, ehr_cycle 이력 포함)
│   ├── hooks/
│   │   ├── db-read-only.sh       ← DB SELECT-only 강제 (15개 DML/DDL 키워드 차단)
│   │   └── vcs-no-commit.sh      ← Git/SVN 커밋·푸시 차단 (AI는 코드 수정까지만)
│   ├── agents/
│   │   ├── screen-builder.md     ← 화면 생성 에이전트
│   │   ├── procedure-tracer.md   ← 프로시저 체인 분석 에이전트
│   │   ├── release-reviewer.md   ← 릴리즈 검증 + 회귀 판정 (EHR4: B1~B6 / EHR5: B1~B10)
│   │   └── db-impact-reviewer.md ← DB 비즈니스 영향 검토 (근태·급여 프로시저 특화, v1.9.0+)
│   ├── commands/ehr/             ← EHR Cycle slash commands (v1.9.0+)
│   │   ├── ideate.md             ← /ehr:ideate — 개선 아이디어 발굴
│   │   ├── plan.md               ← /ehr:plan — 영향도 포함 기술 계획 (writing-plans 래퍼)
│   │   ├── work.md               ← /ehr:work — 플랜 실행 (executing-plans 래퍼)
│   │   ├── review.md             ← /ehr:review — 다중 에이전트 리뷰
│   │   └── compound.md           ← /ehr:compound — L2/L3/선호 지식 회수
│   └── skills/
│       ├── screen-builder/SKILL.md      ← 화면 생성 코드 템플릿
│       ├── codebase-navigator/SKILL.md  ← 코드 경로 탐색
│       ├── procedure-tracer/SKILL.md    ← 프로시저 추적 로직
│       ├── impact-analyzer/SKILL.md     ← 변경 전 영향도 예측 + Go/HOLD/STOP 판정
│       ├── db-query/SKILL.md            ← DB SELECT 조회
│       ├── domain-knowledge/SKILL.md    ← 도메인 지식 레퍼런스 (EHR-COMPOUND 블록 누적)
│       └── design-guide/SKILL.md        ← IDS 컴포넌트 가이드 (프로젝트에 Storybook 존재 시에만 생성)
│
├── .agents/                      ← Codex CLI 호환 (스킬 복사본)
│   └── skills/
│       └── (위 .claude/skills/ 동일 구조)
│
├── .codex/
│   └── config.toml               ← Codex 설정
│
└── .gitignore                    ← 런타임 산출물 제외
```

---

## 2. 플러그인 설치 방법

### 방법 1: Marketplace 설치 (권장)

```bash
# 1. 마켓플레이스 등록
/plugin marketplace add qoxmfaktmxj/ehr-harness-plugin

# 2. 플러그인 설치
/plugin install ehr-harness@ehr-harness

# 3. superpowers 설치 (v1.9.0+ 필수 — /ehr:plan/work/review 가 내부에서 호출)
/plugin install superpowers@claude-plugins-official

# 4. 이후 업데이트
/plugin marketplace update
```

위 4줄을 한 번에 긁어 실행하면 된다. `superpowers` 는 **필수** (옵션 아님) — `/ehr:plan` 이 `superpowers:writing-plans` 를, `/ehr:work` 가 `superpowers:executing-plans` 를, `/ehr:review` 가 `superpowers:receiving-code-review` 를 내부에서 호출하므로 없으면 3개 커맨드가 동작하지 않는다.

설치 후, 어떤 EHR 프로젝트에서든 "하네스 만들어줘"를 사용할 수 있다.

### 방법 2: 로컬 설치 (개발/테스트용)

```bash
# 1. 플러그인 레포 클론
git clone https://github.com/qoxmfaktmxj/ehr-harness-plugin.git ~/Desktop/dev/ehr-harness-plugin

# 2. 로컬 마켓플레이스로 등록
/plugin marketplace add ~/Desktop/dev/ehr-harness-plugin

# 3. 플러그인 설치
/plugin install ehr-harness@ehr-harness

# 4. superpowers 설치 (필수)
/plugin install superpowers@claude-plugins-official
```

### 사전 요구사항

- Claude Code (CLI, Desktop App, 또는 Web App)
- **superpowers 플러그인** (v1.9.0+ 전제 — `/ehr:plan`/`work`/`review` 내부 호출 경로)
- EHR 프로젝트 소스 코드 (로컬에 체크아웃된 상태)
- (선택) Oracle/Tibero DB 접속 가능 상태 (프로시저/트리거 전체 목록 수집용)

---

## 3. 플러그인 업데이트 방법

### 방법 1: Marketplace 명령 (권장)

```bash
# 마켓플레이스 최신화 + 플러그인 업데이트 한번에
/plugin marketplace update
/plugin update ehr-harness@ehr-harness
```

### 방법 2: 수동 업데이트 (명령이 안 될 때)

> **버전 경로 주의**: 아래 경로의 `1.8.0` 은 **현재 릴리즈 버전**이다. 설치된 버전은
> `cat ~/.claude/plugins/cache/ehr-harness/ehr-harness/*/` *(wildcard)* 로 확인하거나,
> `plugin.json::version` 을 따른다. 플러그인이 새 버전으로 올라가면 이 경로도 함께 바뀐다.

```bash
# 0. (사전) 현재 설치된 버전 확인
VERSION=$(ls ~/.claude/plugins/cache/ehr-harness/ehr-harness/ | head -1)
echo "설치된 버전: $VERSION"

# 1. 마켓플레이스 캐시 git pull
cd ~/.claude/plugins/marketplaces/ehr-harness
git pull origin main

# 2. 플러그인 캐시에 동기화 ($VERSION 변수 사용으로 버전 하드코딩 제거)
cp -r ~/.claude/plugins/marketplaces/ehr-harness/plugins/ehr-harness/. \
       ~/.claude/plugins/cache/ehr-harness/ehr-harness/$VERSION/

# 3. installed_plugins.json SHA 갱신
NEW_SHA=$(cd ~/.claude/plugins/marketplaces/ehr-harness && git rev-parse HEAD)
node -e "
const fs=require('fs'),p=require('path');
const f=p.join(process.env.USERPROFILE||process.env.HOME,'.claude/plugins/installed_plugins.json');
const d=JSON.parse(fs.readFileSync(f,'utf8'));
d.plugins['ehr-harness@ehr-harness'][0].gitCommitSha='$NEW_SHA';
d.plugins['ehr-harness@ehr-harness'][0].lastUpdated=new Date().toISOString();
fs.writeFileSync(f,JSON.stringify(d,null,2));
console.log('업데이트 완료. SHA:', '$NEW_SHA');
"
```

> **Windows 주의**: 경로 구분자를 `\`로 바꾸고, `$NEW_SHA` 변수 처리에 PowerShell 대신 Git Bash를 사용한다.

### 방법 3: 로컬 개발 중 업데이트 (git clone으로 설치한 경우)

```bash
# 1. 소스 레포 pull
cd ~/Desktop/dev/ehr-harness-plugin
git pull origin main

# 2. 플러그인 캐시에 덮어쓰기 (버전은 실제 설치 버전으로 자동 탐지)
VERSION=$(ls ~/.claude/plugins/cache/ehr-harness/ehr-harness/ | head -1)
cp -r plugins/ehr-harness/. \
       ~/.claude/plugins/cache/ehr-harness/ehr-harness/$VERSION/
```

### 업데이트 확인

```bash
# 캐시에 새 내용이 반영되었는지 확인 (와일드카드로 버전 무관 매칭)
grep "name:" ~/.claude/plugins/cache/ehr-harness/ehr-harness/*/profiles/ehr5/skills/*/SKILL.md* 2>/dev/null

# 현재 설치된 버전과 plugin.json 버전 일치 여부 확인
cat ~/.claude/plugins/cache/ehr-harness/ehr-harness/*/.claude-plugin/plugin.json | grep version
```

Claude Code를 재시작하지 않아도 다음 대화부터 바로 반영된다.

---

## 4. 사용 방법

### 기본 사용

```
# EHR 프로젝트 디렉토리에서 Claude Code 실행
cd /path/to/ehr-project

# 다음 중 하나를 입력:
"하네스 만들어줘"
"하네스 생성해줘"
"하네스 설계해줘"
"하네스 구성해줘"
```

### 동작 과정

```
사용자: "하네스 만들어줘"
   │
   ▼
[1] 플러그인 위치 자동 탐색 (Glob)
   │
   ▼
[2] EHR 버전 자동 감지
    pom.xml + *-sql-query.xml → EHR5 (MyBatis)
    build.xml + *-mapping-query.xml → EHR4 (Anyframe)
   │
   ▼
[3] 프로젝트 심층 분석 (~15개 분석 명령)
    모듈 맵, 법칙별 사용 수, 세션 변수, 
    프로시저/트리거 목록, DB 접속 정보,
    핵심 화면 코드 패턴 추출
   │
   ▼
[4] 하네스 파일 생성 (~20개 파일)
    프로파일 기본 틀 + 프로젝트 실측값 주입
   │
   ▼
[5] 검증
    생성 파일 교차 확인, 치명 요소 경고
   │
   ▼
[완료] "하네스 생성 완료. 15개 모듈, 
       287개 프로시저, 45개 트리거 등록."
```

---

## 5. 생성되는 하네스 구조

### 파일 목록

| # | 파일 | 크기 목표 | 설명 |
|---|------|-----------|------|
| 1 | `AGENTS.md` | ~150줄 | 범용 프로젝트 규칙. 모든 AI 플랫폼이 읽는 공통 규칙. |
| 2 | `CLAUDE.md` | ~80줄 | Claude Code 전용. 스킬 라우팅 + 금지 사항. |
| 3 | `GEMINI.md` | ~6줄 | Gemini CLI. `@` 참조로 전체 스킬을 Heavy 로드. |
| 4 | `README.md` | ~100줄 | 하네스 개요, 스택, 규모. |
| 5 | `.claude/settings.json` | ~15줄 | PreToolUse 훅 등록. |
| 6 | `.claude/hooks/db-read-only.sh` | ~40줄 | DML/DDL/프로시저호출 차단 Bash 훅 (15개 키워드). |
| 7 | `.claude/hooks/vcs-no-commit.sh` | ~30줄 | Git/SVN 커밋·푸시 차단 훅. AI는 코드 수정까지만 수행. |
| 8 | `.claude/agents/screen-builder.md` | ~80줄 | 화면 생성 에이전트 시스템 프롬프트. |
| 9 | `.claude/agents/procedure-tracer.md` | ~150줄 | 프로시저 분석 에이전트. |
| 10 | `.claude/agents/release-reviewer.md` | EHR4 ~180줄 / EHR5 ~300줄 | 릴리즈 검증 + 회귀 판정 에이전트 (**프로파일별 독립**: EHR4 는 B1~B6, EHR5 는 B1~B10 경계면 매트릭스). 도메인 지식은 유사하되 기술 스택이 다르므로 파일 내용이 다름. 감별된 auth_model/db_verification에 따라 조건부 체크. |
| 11 | `.claude/skills/domain-knowledge/SKILL.md` | ~400-750줄 | 도메인 지식 레퍼런스. |
| 12 | `.claude/skills/screen-builder/SKILL.md` | ~400줄 | 화면 생성 코드 템플릿. |
| 13 | `.claude/skills/codebase-navigator/SKILL.md` | ~200줄 | 코드 경로 탐색. |
| 14 | `.claude/skills/procedure-tracer/SKILL.md` | ~300줄 | 프로시저 추적. |
| 15 | `.claude/skills/db-query/SKILL.md` | ~200줄 | DB 조회 가이드. |
| 16 | `.claude/skills/impact-analyzer/SKILL.md` | ~500줄 | 변경 전 영향도 예측 + HOLD·STOP/HOLD/Conditional-Go/Go 판정 + CHECK 병기. |
| 17 | `.claude/skills/design-guide/SKILL.md` | ~200줄 | IDS 컴포넌트 가이드. **조건부 생성** — 프로젝트에 Storybook(`stories/`·`*.stories.*`)이 감지될 때만 생성. Storybook 없으면 이 파일·카탈로그·MANIFEST 전체 스킵. |
| 18 | `.agents/skills/` | — | 위 스킬들의 Codex 호환 복사본 (생성된 스킬만 복사). |
| 19 | `.codex/config.toml` | ~5줄 | Codex CLI 설정. |
| 20 | `.gitignore` | ~15줄 | 런타임 산출물 제외. |
| 21 | `.claude/agents/db-impact-reviewer.md` | ~110줄 | **v1.9.0+** DB 비즈니스 영향 검토 에이전트. 근태/급여 프로시저 변경 시 리뷰 게이트. `{{CRITICAL_PROCS}}` 치환으로 프로젝트별 프로시저 이름 반영. |
| 22 | `.claude/commands/ehr/ideate.md` | ~60줄 | **v1.9.0+** `/ehr:ideate` — 하네스 축적 데이터에서 고임팩트 개선 아이디어 제안 + adversarial filter. |
| 23 | `.claude/commands/ehr/plan.md` | ~70줄 | **v1.9.0+** `/ehr:plan` — `superpowers:writing-plans` 래퍼 + `impact-analyzer`/`db-impact-reviewer` 결과를 EHR 영향도 섹션으로 자동 주입. |
| 24 | `.claude/commands/ehr/work.md` | ~55줄 | **v1.9.0+** `/ehr:work` — `superpowers:executing-plans` 래퍼 + design-guide/screen-builder/db-query 자동 라우팅. git 없는 환경 지원. |
| 25 | `.claude/commands/ehr/review.md` | ~75줄 | **v1.9.0+** `/ehr:review` — `receiving-code-review` ∥ `release-reviewer` ∥ `db-impact-reviewer` 병렬 오케스트레이션. |
| 26 | `.claude/commands/ehr/compound.md` | ~135줄 | **v1.9.0+** `/ehr:compound` — 세션·커밋에서 새 사실/패턴/선호 추출 → L2/L3 마커 블록 및 `EHR-PREFERENCES` 갱신. 6개 플래그(`--promote-to-skill` 등) 지원. |

**프로파일별 차이**: 현재 v1.9.0 기준으로 EHR4와 EHR5 **스킬/에이전트 구성은 동일**(7개 스킬 + 4개 에이전트 — `db-impact-reviewer` 추가). `/ehr:*` 커맨드 5종은 `profiles/shared/commands/ehr/*.md.skel` **공용 1벌**에서 치환자로 분기. 각 파일의 내용은 기술 스택에 따라 다르게 생성된다 (Velocity vs MyBatis, Ant vs Maven 등). 프로파일 디렉토리(`profiles/ehr4/`, `profiles/ehr5/`)는 독립적이므로 향후 한쪽에만 특화 자산이 추가될 수 있다.

**파일 총합 (design-guide 제외 기준)**: 문서 4 + 설정 2 + 훅 2 + 에이전트 4 + 스킬 6 × 2복사본 + `/ehr:*` 커맨드 5 = **30개**. Storybook 있는 프로젝트는 design-guide 스킬 × 2복사본 + 카탈로그/MANIFEST 포함하여 **+4~5개** 추가 생성.

### 플랫폼별 역할

```
Claude Code:
  CLAUDE.md (진입) → .claude/skills/ (스킬 로드) → .claude/agents/ (에이전트 스폰)
  토큰 경량: 필요한 스킬만 트리거 시 로드

Gemini CLI:
  GEMINI.md (진입) → @참조로 AGENTS.md + 전체 스킬 일괄 로드
  토큰 풍부: Heavy 모드, 전체 컨텍스트 한 번에 로드

Codex CLI:
  AGENTS.md (진입) → .agents/skills/ (스킬 참조)
  토큰 풍부: .agents/에 전체 스킬 복사본 유지
```

---

## 6. 문서 생성 기준

각 파일이 어떤 기준으로, 어떤 데이터를 기반으로 생성되는지 설명한다.

### 5-1. AGENTS.md — 범용 프로젝트 규칙

**생성 기준**: 프로젝트의 기술 스택, 구조, 규칙을 모든 AI 플랫폼이 이해할 수 있도록 작성.

| 섹션 | 데이터 소스 | 고정/실측 |
|------|-----------|----------|
| 기술 스택 테이블 | EHR 버전 감지 결과 | **실측** |
| 디스패처 패턴 (Law A/B/C/D) | EHR 아키텍처 DNA | 고정 |
| 파일 구조 | 감지된 경로 패턴 | **실측** |
| 모듈 맵 | `find` + `wc -l` 실측 | **실측** |
| 필수 기술 규칙 | 프로파일별 고정 | 고정 |
| 치명 프로시저 | `grep CALL P_` 실측 | **실측** |
| 금지 사항 | 프로파일별 고정 | 고정 |

**크기 제한**: ~150줄. 상세 정보는 스킬로 분리하여 토큰 절약.

### 5-2. CLAUDE.md — Claude Code 전용

**생성 기준**: Claude Code에서 어떤 스킬/에이전트를 언제 사용할지 라우팅.

| 섹션 | 내용 | 고정/실측 |
|------|------|----------|
| 프로젝트 개요 | 1줄 요약 | **실측** (감지된 스택) |
| 스킬 라우팅 테이블 | 사용자 요청 → 스킬/에이전트 매핑 | 고정 |
| 에이전트 사용 규칙 | 스폰 조건 | 고정 |
| DB 접근 규칙 | SELECT-only | 고정 |
| 필수 기술 규칙 요약 | AGENTS.md에서 요약 | 고정 |
| 금지 사항 | 프로파일별 | 고정 |
| 우선순위 | 6단계 우선순위 | 고정 |

### 5-3. domain-knowledge SKILL.md — 도메인 지식

**생성 기준**: EHR 아키텍처 규칙 + 프로젝트 실측 수치.

| 섹션 | 내용 | 고정/실측 |
|------|------|----------|
| §1 4축 권한 모델 | 개념 + 세션 변수 목록 | 고정 + **실측** (세션 변수 확인) |
| §2 법칙 판정 | 흐름도 + authSqlID 값 | 고정 + **실측** (authSqlID 수집) |
| §3 Family 카탈로그 | 분류표 + 화면 수 | 고정 + **실측** (JSP 수) |
| §4 APPL_STATUS_CD | 상태 코드 체계 | 고정 |
| §5 IBSheet SaveName | 계약 규칙 | 고정 |
| §6 재구현 금지 컴포넌트 | 목록 + 참조 수 | 고정 + **실측** (참조 카운트) |
| §7 배치 청크 규칙 | 청크 사이즈 | 고정 + **실측** (사이즈 확인) |
| (공통) §N 퇴직 핵심 테이블 | TCPN771/777/203/760 역할·관계 | 고정 |
| (EHR4) §7b Velocity 레퍼런스 | Anyframe 문법 | 고정 |
| (EHR4) §9 50건 배치 | Velocity 분할 규칙 | 고정 |
| (EHR4) §10 릴리즈 리스크 | 5대 위험 요소 | 고정 |

### 5-4. screen-builder SKILL.md — 화면 생성

**생성 기준**: EHR 코드 템플릿 + 프로젝트 실제 코드 패턴.

| 섹션 | 내용 | 고정/실측 |
|------|------|----------|
| 원칙 (3가지) | 그린필드 금지, 법칙 우선, 패턴 충실도 | 고정 |
| Step 1 유사 화면 탐색 | grep 명령 + 프로젝트 경로 | 고정 + **실측** (경로) |
| Step 2~4 법칙별 템플릿 | Controller/Service/Mapper/JSP 코드 | 고정 뼈대 + **실측** (실제 코드 예시) |
| 코드 예시 | 핵심 화면 4개 + 모듈별 1개 읽기 | **실측** |
| MERGE/DELETE 패턴 | 실제 사용 예시 | **실측** |
| JSP DB 호출 체인 | JSP → Controller → Service → XML | **실측** |
| 셀프 체크리스트 | 13개 항목 | 고정 |

### 5-5. codebase-navigator SKILL.md — 코드 탐색

**생성 기준**: 프로젝트 실제 구조 기반.

| 섹션 | 내용 | 고정/실측 |
|------|------|----------|
| 모듈 맵 | 모듈별 키워드, 파일 수 | **실측** |
| 에러 진단 프레임워크 | 3차원 (사용자/코드/DB) | 고정 |
| 공통 컴포넌트 맵 | 컴포넌트별 실제 참조 수 | **실측** |
| DAO 메서드 시그니처 | getList, getMap, excute 등 | 고정 |

### 5-6. procedure-tracer SKILL.md — 프로시저 추적

**생성 기준**: 프로젝트 프로시저/트리거 전수 조사.

| 섹션 | 내용 | 고정/실측 |
|------|------|----------|
| 7-Layer 깊이 맵 | JSP~Trigger 계층 | 고정 |
| 추적 알고리즘 | 순방향/역방향 | 고정 |
| 전체 프로시저 목록 | grep CALL + DB 조회 | **실측** |
| 전체 트리거 목록 | grep + DB 조회 | **실측** (DB 불가 시 빈 목록 + 경고) |
| 치명 프로시저 레지스트리 | 존재 확인 후 등록 | **실측** |
| 동적 SQL 패턴 | $query, EXECUTE IMMEDIATE 등 | 고정 + **실측** |
| 이상값 디버깅 원칙 | 실행경로 vs 계산로직 분리 확인 | 고정 |
| 호출 체인 재귀 탐색 | 프로시저 재귀 호출 추적 + SQL 예시 | 고정 |
| 보고서 템플릿 | 분석 출력 형식 | 고정 |

### 5-7. db-query SKILL.md — DB 조회

**생성 기준**: 프로젝트 DB 접속 정보 자동 탐지.

| 섹션 | 내용 | 고정/실측 |
|------|------|----------|
| SELECT-only 제약 | 조회만 허용 | 고정 |
| DB 접속 정보 | context.xml / application.properties | **실측** (없으면 빈칸 + 경고) |
| OJDBC 드라이버 위치 | 경로 탐색 | **실측** |
| 공통 쿼리 패턴 5개 | 프로시저 소스, 테이블 구조 등 | 고정 |
| UPDATE 안전 템플릿 | 변경 전 SELECT → UPDATE → 변경 후 검증 3단계 | 고정 |

### 5-8. impact-analyzer SKILL.md — 변경 전 영향도 예측

**생성 기준**: procedure-tracer 재사용 + 위험 신호 스코어링 규칙.

| 섹션 | 내용 | 고정/실측 |
|------|------|----------|
| Step 1 입력 판별 | 9가지 정규식 우선순위 | 고정 |
| Step 2 체인 추적 | procedure-tracer SKILL 참조 | 고정 |
| Step 3 위험 신호 | critical_proc_found + 재구현 금지 + 권한 경계 + Family C | 고정 + **실측** (critical_proc_found 주입) |
| Step 4 Unresolved refs | 동적 queryId·AJAX·EXECUTE IMMEDIATE·F_COM_GET_SQL_MAP | 고정 |
| Step 5 영향 화면 수렴 | 종점 JSP, 상한 10 | 고정 |
| Step 6 판정 | HOLD·STOP / HOLD / Conditional-Go / Go + CHECK | 고정 |
| Step 7 리포트 템플릿 | 표준 + 공용 STOP | 고정 |

### 5-9. design-guide SKILL.md — IDS 컴포넌트 가이드 (조건부)

**생성 기준**: 프로젝트에 Storybook이 감지(`stories/`·`*.stories.*`·`.storybook/`)될 때만 생성. 없으면 이 섹션 전체 스킵.

| 섹션 | 내용 | 고정/실측 |
|------|------|----------|
| SKILL.md | IDS 컴포넌트 진입 가이드, 사용 패턴 | 고정 |
| INDEX.md | Storybook story 카탈로그 (46개 기본 그룹: 00-guides/01-atoms/02-modules/03-pages/04-utilities/05-modal) | **실측** (story 파일 스캔) |
| MANIFEST.json | 각 story 의 title/path/props 메타데이터 | **실측** |
| 핵심 10개 inline | 자주 쓰는 컴포넌트 10개는 SKILL.md에 inline 예시로 포함 | **실측** (Storybook story 선정) |

**왜 조건부인가**: EHR 프로젝트 대부분은 JSP/IBSheet 기반이라 Storybook이 없다. Storybook을 운영하는 팀(주로 프론트엔드 모던화 진행 중인 조직)에만 유효하므로 **존재 시에만 생성**하여 컨텍스트 낭비를 막는다.

### 5-10. 에이전트 (.claude/agents/)

**생성 기준**: 에이전트는 스킬을 참조하므로 대부분 고정.

| 에이전트 | 내용 | 고정/실측 |
|----------|------|----------|
| screen-builder.md | 역할, 실행 절차, 코드 패턴, 제약 | 고정 (프로파일별) |
| procedure-tracer.md | 역할, 7-Layer, 추적 알고리즘, 치명 목록 | 고정 + **실측** (치명 목록) |
| release-reviewer.md | 경계면 매트릭스·회귀 패턴·치명 위험·CHECK 판정 (**프로파일별 독립**: EHR4 B1~B6 / EHR5 B1~B10, auth_model 기반 조건부) | 고정 |

---

## 7. 생성 파이프라인 상세

하네스가 생성되기까지의 전체 과정을 단계별로 설명한다.

### Phase 1: 플러그인 위치 탐색

```
Glob: "**/ehr-harness/profiles/ehr*/skeleton/AGENTS.md.skel"
→ 플러그인 루트 디렉토리 확정
→ 프로파일 디렉토리 경로 확보
```

### Phase 2: EHR 버전 감지

```
[판정 트리]

pom.xml 존재?
  ├── YES → grep "mybatis" pom.xml
  │         ├── 매칭 → EHR5 확정
  │         └── 미매칭 → *-sql-query.xml 존재 확인
  │                     ├── 존재 → EHR5 확정
  │                     └── 미존재 → 수동 확인 필요
  └── NO → build.xml 존재?
           ├── YES → *-mapping-query.xml 존재?
           │         ├── 존재 → EHR4 확정
           │         └── 미존재 → 수동 확인 필요
           └── NO → 사용자에게 질문: "EHR 버전을 선택해주세요"
```

### Phase 3: 프로젝트 심층 분석 (~15개 분석 명령)

#### 3-A. 구조 분석
```bash
# 모듈 디렉토리 탐색
ls src/main/java/com/hr/     # EHR5
ls src/com/hr/                # EHR4

# 모듈별 파일 수 (Java 파일)
for mod in hrm cpn tim wtm pap ben sys org tra hri com; do
  count=$(find src/.../com/hr/$mod -name "*.java" 2>/dev/null | wc -l)
  echo "$mod: $count"
done
```

#### 3-B. 법칙 분석
```bash
grep -rl "GetDataList.do" --include="*.jsp" | wc -l    # 법칙 B JSP 수
grep -rl "SaveData.do" --include="*.jsp" | wc -l        # 법칙 B 저장 수
grep -rl "ExecPrc.do" --include="*.jsp" | wc -l         # 법칙 D JSP 수
grep -rl "AuthTableService" --include="*.java" | wc -l  # 법칙 C 컨트롤러 수
```

#### 3-C. 세션 변수 수집
```bash
grep -roh "session.getAttribute(\"[^\"]*\")" --include="*.java" | 
  sort -u
# → ssnEnterCd, ssnSabun, ssnSearchType, ssnGrpCd, ssnLocaleCd 등
```

#### 3-D. authSqlID 값 수집
```bash
grep -roh '"authSqlID"[^"]*"[A-Z0-9]*"' --include="*.java" --include="*.jsp" |
  grep -oP '"[A-Z]{4}\d{3}"' | sort -u
# → THRM151, TORG101 등
```

#### 3-E. 재구현 금지 컴포넌트 참조 수
```bash
for comp in GetDataListController SaveDataController ExecPrcController \
            AuthTableService ApprovalMgr UploadMgr CommonCodeService; do
  count=$(grep -rl "$comp" --include="*.java" --include="*.jsp" | wc -l)
  echo "$comp: $count refs"
done
```

#### 3-F. 치명 프로시저/트리거 존재 확인
```bash
# 치명 프로시저
for proc in P_CPN_CAL_PAY_MAIN P_HRM_POST P_TIM_WORK_HOUR_CHG \
            P_HRI_AFTER_PROC_EXEC P_TIM_VACATION_CLEAN PKG_CPN_SEP; do
  found=$(grep -rl "$proc" --include="*query.xml" 2>/dev/null | head -1)
  echo "$proc: ${found:-NOT FOUND}"
done

# 치명 트리거
for trg in TRG_HRI_103 TRG_TIM_405; do
  found=$(grep -rl "$trg" --include="*.java" --include="*.xml" 2>/dev/null | head -1)
  echo "$trg: ${found:-NOT FOUND}"
done

# 전체 프로시저 목록
grep -roh "CALL P_[A-Z_]*\|CALL PKG_[A-Z_]*" --include="*query.xml" | sort -u

# DB 연결 가능 시: 전체 트리거/프로시저 목록
# SELECT OBJECT_NAME FROM USER_OBJECTS WHERE OBJECT_TYPE IN ('PROCEDURE','TRIGGER','PACKAGE');
```

#### 3-G. 핵심 화면 코드 패턴 분석

**반드시 읽는 화면 (Family C 신청서)**:
- `vacationApp` — 신청 화면
- `vacationAppDet` — 상세 화면
- `vacationApr` — 결재 화면

**반드시 읽는 화면 (Family A 기본 CRUD)**:
- `orgCdMgr` — 조직 코드 관리

**모듈별 대표 화면 (각 1개)**:
- HRM, HRI, PAP, TRA, CPN, WTM, TIM, SYS, ORG에서 각각 Controller 1개 선정
- 해당 화면의 Controller + Service + Mapper + JSP 4개 파일 읽기

→ 실제 코드 패턴 추출:
- MERGE문 실제 예시
- DELETE문 실제 예시
- JSP에서 DB 값 호출 체인
- Controller → Service → Mapper 호출 체인

#### 3-H. DB 접속 정보 탐지
```bash
# EHR5: application.properties 또는 context.xml
grep -r "spring.datasource.url" --include="*.properties" --include="*.yml"
find . -name "context*.xml" -exec grep -l "dataSource\|jdbcUrl" {} \;

# EHR4: context.xml
find . -name "context*.xml" -exec grep -l "jdbc" {} \;

# OJDBC 드라이버 위치
find . -name "ojdbc*.jar" -o -name "tibero*.jar" 2>/dev/null
```

### Phase 4: 파일 생성

수집된 데이터를 프로파일 스켈레톤에 주입하여 최종 파일 생성.

```
[생성 순서]

1. 인프라 (shared/ → 프로젝트 루트)
   .claude/settings.json ← 그대로 복사
   .claude/hooks/db-read-only.sh ← 그대로 복사
   .claude/hooks/vcs-no-commit.sh ← 그대로 복사
   .codex/config.toml ← 그대로 복사
   .gitignore ← 그대로 복사

2. 문서 (skeleton/ + 실측값 → 프로젝트 루트)
   AGENTS.md ← 스켈레톤 + {{MODULE_MAP}}, {{PROC_LIST}} 치환
   CLAUDE.md ← 스켈레톤 + {{TECH_STACK}} 치환
   README.md ← 스켈레톤 + 규모 수치 치환

3. 도메인 스킬 (skills/ → .claude/skills/)
   domain-knowledge ← 고정 뼈대 + 실측 수치 주입
   screen-builder ← 고정 뼈대 + 실제 코드 예시 주입
   codebase-navigator ← 모듈 맵 실측 주입
   procedure-tracer ← 프로시저/트리거 목록 주입
   db-query ← DB 접속 정보 주입

4. 에이전트 (agents/ → .claude/agents/)
   screen-builder.md ← 프로파일별 고정
   procedure-tracer.md ← 고정 + 치명 목록 주입
   release-reviewer.md ← 프로파일별 독립 (EHR4 B1~B6 / EHR5 B1~B10, 조건부 체크 매트릭스)

5. Codex/Gemini 호환
   .agents/skills/ ← .claude/skills/ 전체 복사
   GEMINI.md ← @참조 목록 생성
```

### Phase 5: 검증

```
1. 생성 파일 수 확인
   EHR4/EHR5: 23개 파일 (7 스킬 × 2 복사본 중 design-guide 제외 시 6 × 2 + 3 에이전트 + 6 문서/설정)
   Storybook 존재 프로젝트: +4~5개 (design-guide 스킬 × 2복사본 + INDEX/MANIFEST)

2. AGENTS.md 교차 확인
   모듈 맵의 모듈 목록 vs 실제 디렉토리 목록 비교
   불일치 시 경고

3. 치명 요소 보고
   "치명 프로시저 5/6개 확인, P_TIM_VACATION_CLEAN 미발견 — 확인 필요"
   "치명 트리거 2/2개 확인"

4. DB 연결 상태
   "DB 연결 성공: 287개 프로시저, 45개 트리거 등록"
   또는
   "⚠ DB 연결 불가. 프로시저/트리거 목록은 코드 grep 기반. 
    DB 연결 후 db-query 스킬로 전체 목록을 갱신하세요."
```

---

## 8. 프로파일 시스템

### 프로파일이란?

프로파일은 EHR 버전별 **고정 뼈대**를 제공한다. EHR4와 EHR5는 아키텍처가 다르므로 (Anyframe vs MyBatis, Velocity vs XML 등) 별도 프로파일이 필요하다.

### 프로파일 구성

```
profiles/
├── shared/       ← 버전 무관 공통 파일 (settings.json, 훅, .codex)
├── ehr4/         ← Spring MVC + Anyframe + Velocity + Ant
│   ├── skeleton/ ← 변수 치환용 문서 스켈레톤 (AGENTS/CLAUDE/README)
│   ├── agents/   ← 에이전트 시스템 프롬프트 (3개: screen-builder, procedure-tracer, release-reviewer)
│   ├── skills/   ← 스킬 스켈레톤 (7개: screen-builder, codebase-navigator, procedure-tracer, db-query, impact-analyzer, design-guide, domain-knowledge)
│   └── reference/ ← 고정 참조 (CODE_MAP, DB_MAP)
└── ehr5/         ← Spring Boot + MyBatis + Maven
    ├── skeleton/
    ├── agents/    ← 3개 (내용은 EHR5 기준 — release-reviewer는 B1~B10)
    ├── skills/    ← 7개 (내용은 MyBatis/Spring Boot 기반)
    └── reference/
```

### 스켈레톤 변수

스켈레톤 파일에는 `{{변수명}}` 형태의 플레이스홀더가 있다. 메타 스킬이 프로젝트 분석 결과로 치환한다.

| 변수 | 설명 | 수집 방법 |
|------|------|-----------|
| `{{TECH_STACK}}` | 프레임워크/ORM 버전 | pom.xml / build.xml 파싱 |
| `{{MODULE_MAP}}` | 모듈별 도메인명 + 파일 수 | find + wc -l |
| `{{PROC_LIST}}` | 전체 프로시저 목록 | grep CALL + DB 조회 |
| `{{TRIGGER_LIST}}` | 전체 트리거 목록 | grep + DB 조회 |
| `{{CRITICAL_PROC}}` | 치명 프로시저 (존재 확인된 것만) | grep 존재 확인 |
| `{{AUTH_SQL_IDS}}` | 사용 중인 authSqlID 값들 | grep |
| `{{SESSION_VARS}}` | 세션 변수 목록 | grep session.getAttribute |
| `{{COMPONENT_REFS}}` | 컴포넌트별 참조 수 | grep -c |
| `{{DB_CONNECTION}}` | JDBC URL, 드라이버 경로 | properties/xml 파싱 |
| `{{LAW_B_COUNT}}` | 법칙 B JSP 수 | grep GetDataList.do |
| `{{LAW_C_COUNT}}` | 법칙 C 컨트롤러 수 | grep AuthTableService |
| `{{LAW_D_COUNT}}` | 법칙 D JSP 수 | grep ExecPrc.do |
| `{{CODE_EXAMPLES}}` | 실제 코드 패턴 (MERGE/DELETE/JSP) | 핵심 화면 파일 읽기 |

---

## 9. EHR4 vs EHR5 차이점

두 프로파일의 핵심 차이를 정리한다. 이 차이가 프로파일 분리의 근거이다.

| 항목 | EHR4 | EHR5 |
|------|------|------|
| 시스템명 | EHR_HR40 | EHR_HR50 |
| 프레임워크 | Spring MVC | Spring Boot 2.7.18 |
| ORM/쿼리 | Anyframe Query Mapping + Velocity | MyBatis 3 |
| 빌드 | Ant (`build.xml`) | Maven (`pom.xml`) |
| 매퍼 파일명 | `*-mapping-query.xml` | `*-sql-query.xml` |
| 매퍼 DTD | `anyframe-query-service.dtd` | `mybatis-3-mapper.dtd` |
| 바인드 문법 | `:key` (Velocity 바인드 변수) | `#{param}` (MyBatis 바인드) |
| 직접 치환 | `$var`, `$rm.field` (Velocity) | `${query}` (MyBatis 동적) |
| 조건문 | `#if ($var == "X")` | `<if test='var eq "X"'>` |
| 반복문 | `#foreach ($rm in $list)` | `<foreach item="rm" collection="list">` |
| 구분자 | `$velocityHasNext` | `separator=" UNION ALL "` |
| NULL 처리 | `null` 리터럴 문자열 주의 | MyBatis 자동 null 처리 |
| 결과 타입 | `$result.variable` | `resultType="cMap"` |
| Java 경로 | `src/com/hr/{module}/` | `src/main/java/com/hr/{module}/` |
| 매퍼 경로 | `src/com/hr/{module}/` | `src/main/resources/mapper/com/hr/{module}/` |
| JSP 경로 | `WebContent/WEB-INF/jsp/` | `src/main/webapp/WEB-INF/jsp/` |
| 에이전트 수 | 3개 | 3개 |
| 금지 기술 | MyBatis 금지 | Anyframe 금지 |
| 배치 크기 | 50건 (Velocity 바인드 변수 한계) | 1000건 (Oracle IN절 한계) |
| domain-knowledge | 744줄 (10 섹션) | 411줄 (7 섹션) |
| 추가 섹션 | B1~B10 경계 (CHECK 판정 포함), Velocity 레퍼런스, 릴리즈 리스크 | — |

### 공통 사항 (프로파일 무관)

- `.do` + `cmd=` 디스패치 패턴
- 4축 권한 모델 (ssnEnterCd, ssnSabun, ssnSearchType, ssnGrpCd)
- 법칙 A/B/C/D 판정 체계
- Family A~F 화면 분류
- AuthTableService + $query 권한 주입
- IBSheet7 SaveName 계약
- 재구현 금지 컴포넌트 (GetDataListController, SaveDataController 등)
- 치명 프로시저 (P_CPN_CAL_PAY_MAIN, PKG_CPN_SEP 등)
- 한국어 에러 메시지
- 그린필드 금지 원칙
- DB SELECT-only 정책

---

## 10. 커스터마이징 범위

### 고정 (40%) — EHR 아키텍처 DNA

프로젝트가 달라도 변하지 않는 EHR의 본질적 규칙:

- 4축 권한 모델 개념과 규칙
- 법칙 A/B/C/D 판정 흐름도
- Family A~F 분류 체계
- APPL_STATUS_CD 상태 코드 체계
- IBSheet SaveName 계약
- Velocity 문법 레퍼런스 (EHR4)
- 금지 사항 목록
- 그린필드 금지 원칙
- 경계 검증 매트릭스 + CHECK 판정 (**프로파일별**: EHR4 B1~B6, EHR5 B1~B10)
- 에이전트 역할 정의
- db-read-only 훅 + vcs-no-commit 훅

### 실측 (60%) — 프로젝트 분석 결과

SI 프로젝트마다 달라지는 부분:

- 모듈 맵 (어떤 모듈이 존재하는지, 파일 수)
- 법칙별 사용 수 (법칙 B JSP 79개 vs 152개)
- 세션 변수 목록 (ssnEnterCd 외에 커스텀 변수 있을 수 있음)
- authSqlID 값 목록 (THRM151, TORG101 외에 커스텀 값)
- 재구현 금지 컴포넌트 참조 수
- 프로시저 전체 목록 + 존재 확인
- 트리거 전체 목록 + 존재 확인
- 치명 프로시저 존재 여부
- DB 접속 정보
- 실제 코드 패턴 (MERGE문, DELETE문, JSP 호출 체인)
- 핵심 화면 코드 예시

---

## 11. 플러그인 디렉토리 구조

```
ehr-harness-plugin/
│
├── .claude-plugin/
│   └── marketplace.json          # 마켓플레이스 카탈로그
│
├── plugins/
│   └── ehr-harness/              # 플러그인 본체
│       ├── .claude-plugin/
│       │   └── plugin.json       # 플러그인 매니페스트 (버전 관리)
│       │
│       ├── skills/
│       │   └── ehr-harness/
│       │       ├── SKILL.md      # 메타 스킬 (이 플러그인의 핵심) — Step 4-I 신설 (EHR Cycle 자산 생성)
│       │       └── lib/          # 런타임 helper (SKILL.md 가 Step 실행 중 호출)
│       │           ├── HARNESS_SCHEMA.md      # HARNESS.json v3/v4 스키마 정의 (ehr_cycle 포함)
│       │           ├── detect.sh              # EHR 버전 / auth_model / DDL 폴더 감별
│       │           ├── analyze.sh             # 프로젝트 분석 (모듈·세션변수·프로시저·law count)
│       │           ├── audit.sh               # drift 계산·리포트 렌더 + EHR Cycle 드리프트 4종 (ehr_audit_*)
│       │           ├── merge.sh               # AGENTS.md / CLAUDE.md 섹션 단위 병합 (사용자 편집 보존)
│       │           ├── harness-state.sh       # HARNESS.json v4 매니페스트 관리 (ehr_cycle 보존·승계)
│       │           ├── ehr-compound.sh        # EHR 마커 블록 머지 헬퍼 (v1.9.0+, upsert/remove/list + corruption 탐지)
│       │           ├── gen-code-map.js        # 대상 프로젝트 CODE_MAP 런타임 생성 (Step 2-L-2)
│       │           ├── ddl-authoring.notes.md # DDL 자동 작성 설계 노트 (오프라인 레퍼런스)
│       │           ├── fixtures/              # 테스트 fixture 데이터셋 (merge/ehr_cycle/ 신규)
│       │           └── *.test.sh              # 단위 테스트 (detect/analyze/audit/merge/harness-state/scenarios/ehr-compound)
│       │
│       ├── scripts/              # offline 유지보수 도구 (런타임 미사용)
│       │   └── gen-example-codemap.js    # EHR4 예시 병합 CODE_MAP 스냅샷 생성 (fallback 용)
│       │
│       └── profiles/
│           ├── shared/           # 버전 무관 공통 파일
│           │   ├── settings.json # .claude/settings.json → PreToolUse 훅
│           │   ├── hooks/
│           │   │   ├── db-read-only.sh  # DML/DDL/프로시저호출 차단 (15개 키워드)
│           │   │   └── vcs-no-commit.sh # Git/SVN 커밋·푸시 차단
│           │   ├── commands/ehr/ # /ehr:* 커맨드 스켈레톤 5종 (v1.9.0+, 프로파일 공용)
│           │   │   ├── ideate.md.skel
│           │   │   ├── plan.md.skel
│           │   │   ├── work.md.skel
│           │   │   ├── review.md.skel
│           │   │   └── compound.md.skel
│           │   ├── .codex/
│           │   │   └── config.toml      # Codex CLI 설정
│           │   └── .gitignore
│           │
│           ├── ehr4/             # EHR4 프로파일 (Ant + Anyframe + Spring MVC)
│           │   ├── skeleton/     # 변수 치환용 문서 스켈레톤
│           │   │   ├── AGENTS.md.skel
│           │   │   ├── CLAUDE.md.skel     # EHR-ROUTING + EHR-PREFERENCES 블록 포함 (v1.9.0+)
│           │   │   └── README.md.skel
│           │   ├── agents/       # 에이전트 4개 (v1.9.0+ db-impact-reviewer 추가)
│           │   │   ├── screen-builder.md
│           │   │   ├── procedure-tracer.md
│           │   │   ├── release-reviewer.md    # 릴리즈 검증 (B1~B6 EHR4 기준)
│           │   │   └── db-impact-reviewer.md  # DB 비즈니스 영향 검토 (v1.9.0+)
│           │   ├── skills/       # 스킬 7개 (6개 .skel + domain-knowledge.md 고정 + design-guide는 대상 프로젝트에 Storybook 있을 때만 생성)
│           │   │   ├── screen-builder/SKILL.md.skel
│           │   │   ├── codebase-navigator/SKILL.md.skel
│           │   │   ├── procedure-tracer/SKILL.md.skel
│           │   │   ├── db-query/SKILL.md.skel
│           │   │   ├── impact-analyzer/SKILL.md.skel
│           │   │   ├── design-guide/SKILL.md.skel
│           │   │   └── domain-knowledge/SKILL.md
│           │   └── reference/    # 고정 참조 문서
│           │       ├── CODE_MAP.md   # 예시 3개 프로젝트 병합 (런타임 생성 실패 시 fallback)
│           │       └── DB_MAP.md     # 테이블 스키마 레퍼런스
│           │
│           └── ehr5/             # EHR5 프로파일 (Maven + MyBatis + Spring Boot)
│               ├── skeleton/     # AGENTS/CLAUDE/README.md.skel 3종 (CLAUDE.md.skel 에 EHR-ROUTING 포함)
│               ├── agents/       # 에이전트 4개 (ehr4 와 동일 구조, db-impact-reviewer 는 EHR5 문맥으로 차별화)
│               ├── skills/       # 스킬 7개 (EHR4와 동일 구조, 내용은 MyBatis/Spring Boot 기반)
│               └── reference/    # CODE_MAP.md (기본 패키지 스냅샷, fallback), DB_MAP.md
│
├── README.md                     # 이 파일
└── .gitignore
```

> **프로파일 비대칭 허용**: 현재 v1.9.0 기준 EHR4/EHR5의 스킬·에이전트 **목록**은 동일(스킬 7 + 에이전트 4). 각 프로파일은 독립 디렉토리이므로 향후 한쪽에만 특화 자산이 추가될 수 있다. 예: "EHR5 전용 MyBatis 동적 SQL 가이드", "EHR4 전용 Anyframe Velocity 매퍼" 등. 메타 스킬(SKILL.md)은 감지된 프로파일에 **존재하는 자산만** 생성하므로 비대칭 구성도 그대로 반영된다.
>
> **공용 자산**: `/ehr:*` 커맨드 5종은 `profiles/shared/commands/ehr/*.md.skel` 단일 본에서 치환자(`{{PROFILE}}` 등)로 프로파일 차이를 흡수한다.

---

## 12. Schema v4 기능 (현행)

> **Schema 진화**: v1(초기) → v2(2026-04 자동 감별 파이프라인 + release-reviewer 조건부 검증) → v3(audit 모드 + analysis_snapshot 저장) → **v4 (v1.9.0, EHR Cycle 지식 누적 도입)**. v3/v4 매니페스트 모두 stamped 로 인정 (마이그레이션 유예 — v3 사용자가 v1.9.0 플러그인으로 업데이트했을 때 즉시 legacy 로 재분류되지 않음). 기존 v1/v2 매니페스트는 `hs_is_legacy` 로 분류되어 adopt 프롬프트가 뜬다.

### 자동 감별 파이프라인 (v2 → v3 → v4 공통)

하네스 생성 시점에 프로젝트의 특성을 자동 감별하여 HARNESS.json 에 기록한다:

| 감별 항목 | 수집 방법 | 용도 |
|-----------|----------|------|
| `auth_model` | Java/매퍼 grep 으로 common_controllers, auth_service_class, 권한 주입 방식 검출 | reviewer 조건부 체크 판단 |
| `db_verification` | DDL 폴더 존재 + DB 접속 상태로 b3_strategy 결정 | B3 검증 Tier 1/2/3 폴백 전략 |
| `ddl_authoring` | repo 내 DDL 폴더 감별 (src/main/resources/db, ddl/, sql/ 등) | screen-builder 신규 DDL 파일 자동 생성 |
| `analysis` (v3+) | 모듈 맵·세션 변수·프로시저·law_counts 스냅샷 | audit drift baseline + `/ehr:ideate` 입력 |
| `ehr_cycle` (v4+) | `compounds[]` / `promoted[]` / `preferences_history[]` 이력 | `/ehr:compound` 누적 지식 + audit EHR 드리프트 |

감별 결과는 `AGENTS.md` 에 마크다운 테이블로 주입 + `HARNESS.json` 에 JSON 으로 저장. 사용자 확인 프롬프트로 수정 가능.

### v4 신규 — `ehr_cycle` 섹션

```json
"ehr_cycle": {
  "version": 1,
  "compounds": [         // L2 회수 이력 (reference/*, domain-knowledge 블록)
    { "id": "2026-04-18-paycalc-trigger",
      "ts": "...", "level": "L2", "domain": "code_map",
      "files": ["reference/CODE_MAP.md"], "revision": 1 }
  ],
  "promoted": [          // L3 승급 이력 (agents/*, skills/* 프롬프트 편집)
    { "id": "pay-closing-no-direct-update",
      "target_file": "agents/release-reviewer.md",
      "backup": ".ehr-bak/release-reviewer.md.20260420T091500.bak",
      "retain": false, "backup_cleaned": false }
  ],
  "preferences_history": [  // 협업 선호 변경 로그 (EHR-PREFERENCES 블록 갱신 이력)
    { "ts": "...", "key": "SUGGEST_MODE",
      "from": "ask", "to": "silent", "trigger": "역질문하지마" }
  ]
}
```

- `compounds[].revision` 은 같은 id 갱신 횟수. `AUTO_PROMOTE_AFTER` 도달 시 L3 승급 후보로 자동 제안.
- `promoted[].retain: true` 엔트리는 `BACKUP_RETENTION_DAYS` 만료 자동 정리에서 제외.
- `preferences_history[]` 는 `/ehr:compound --revert-preference <KEY>` 의 롤백 근거.

### release-reviewer — 조건부 검증

- **경계면 매트릭스**: B1~B10 (EHR5 전용 B7~B10 추가: 매퍼 파일명, cMap, NULL 센티넬, 감사 컬럼)
- **조건부 적용**: `auth_model` 에 따라 B5/B6/R-2/R-4/R5 체크 생략 또는 변형
- **판정**: PASS / FIX / REDO / HOLD / **CHECK** (5번째 — 자동 검증 불가 시 수동 확인 요청)
- **DB 검증 폴백**: DDL 파일 → DB 접속 → 수동 (3-tier)

### screen-builder — DDL 자동 작성

`ddl_authoring.enabled = true` 일 때:

1. 신규 화면이 요구하는 DB 객체 분석 (테이블/프로시저/함수)
2. 사용자 확인 프롬프트 (목적 + 제안 이름 + [수정/취소] 옵션)
3. CREATE 문 생성 → DDL 폴더에 파일 저장
4. 치명 네임스페이스 (P_CPN_*, PKG_CPN_*, P_HRM_POST*, P_TIM_*, P_HRI_AFTER_*) 자동 차단
5. 트리거는 연쇄 장애 위험으로 지원 제외

### HARNESS.json 버전 마이그레이션

- v1/v2 매니페스트는 `hs_is_legacy` 가 legacy 로 분류 (adopt 프롬프트)
- v3 매니페스트는 v4 플러그인에서도 **stamped 로 인정** (마이그레이션 유예, `HS_SCHEMA_VERSION_STAMPED="3 4"`)
- v3 → v4 승격은 "재생성" / "업데이트" 시 자동 수행:
  - `ehr_cycle` 섹션 자동 주입 (`{version:1, compounds:[], promoted:[], preferences_history:[]}`)
  - `outputs[]` 에 `/ehr:*` 커맨드 5개 + `db-impact-reviewer.md` 엔트리 + sha256 추가
  - `schema_version: 4`, `plugin_version: 1.9.0` 기록
- 기존 하네스 설치와 하위 호환 유지 — 파일 자체는 덮어쓰지 않고 sha 만 스탬프
- 세부 스키마는 `plugins/ehr-harness/skills/ehr-harness/lib/HARNESS_SCHEMA.md` 참조

### 4대 불변식 (v4 도입)

재생성은 다음 4종을 **절대 덮어쓰지 않는다** — 사용자 축적 지식 유실 방지의 근간:

1. **L2 지식** (`EHR-COMPOUND` 블록) — `reference/CODE_MAP.md` · `DB_MAP.md` · `skills/domain-knowledge/SKILL.md`
2. **L3 승급** (`EHR-PROMOTED` 블록) — `agents/*.md` · `skills/**/SKILL.md`
3. **협업 선호** (`EHR-PREFERENCES` 블록) — `CLAUDE.md` (`FILE_THRESHOLD`, `SUGGEST_MODE` 등)
4. **사용자 작업물** — `.ehr-bak/`, `docs/ehr/*`

구현: `lib/ehr-compound.sh` 의 `ehr_compound_upsert` 는 BEGIN/END 마커 카운트 불일치 시 즉시 abort 하고 파일을 건드리지 않는다 (불변식 1 보호).

---

## 13. 하네스 Audit (자동 drift 감지)

### 개요

하네스를 처음 설치한 이후, 프로젝트가 계속 진화하면서 AGENTS.md 의 내용(모듈 맵, 세션 변수, 치명 프로시저 목록)과 실제 코드 사이에 괴리(drift)가 발생합니다. 또한 플러그인이 업데이트되면서 새 스킬/에이전트/기능이 추가될 수 있습니다.

**"하네스 점검해줘"** 명령 한 번으로:
1. 플러그인 최신 변경분 반영 (stamped 모드 재활용)
2. 프로젝트 drift 감지 → 중요도 분류 → 반자동 반영

### 트리거

다음 문구 중 하나:
- "하네스 점검해줘"
- "하네스 audit 해줘"
- "하네스 drift 체크"
- `/harness-audit`

### 동작 흐름

```
1. Step 1~2: 프로젝트 재분석 (모듈 맵, 세션 변수, 치명 프로시저)
2. Step 2.5 (audit 전용): 저장된 analysis 와 diff
3. Step 3-PRE: 플러그인 파일 bucket 분류 (stamped와 동일)
4. AUDIT-REPORT: 통합 리포트 + 사용자 확인
5. 선택된 항목만 Write
6. 매니페스트 갱신 (analysis 재스탬프)
```

### Drift 중요도 분류

| 중요도 | 필드 | 사용자 흐름 |
|-------|------|-----------|
| **[상]** | auth_model 변경 / session_vars 추가·삭제 / critical_proc_found 추가 | 항목별 개별 확인 |
| **[중]** | module_map 추가·삭제 / authSqlID 변경 | 일괄 승인 |
| **[하]** | law_counts 변화 / procedure_count 증감 | 리포트 표시만 |

### EHR Cycle 드리프트 (v4, 4종 — v1.9.0+)

기존 analysis drift 와는 별도로, `ehr_cycle` 섹션과 실제 파일 상태의 불일치를 감지:

| 유형 | 증상 | 복구 |
|---|---|---|
| **orphan_compound** | `compounds[].id` 가 JSON 에는 있으나 `reference/*` 또는 `domain-knowledge/SKILL.md` 에 블록이 없음 | `/ehr:compound --reindex` |
| **orphan_marker** | 파일에는 `EHR-COMPOUND` 블록이 있으나 `compounds[]` 에 기록 없음 | `/ehr:compound --reindex` |
| **stale_promotion** | `promoted[].backup` 경로가 실존하지 않고 `backup_cleaned: false` | 수동 — 백업 유실, 복원 불가 |
| **preferences_corruption** | `CLAUDE.md` 의 `EHR-PREFERENCES` 블록 파싱 실패 또는 유효 엔트리 0개 | 수동 편집 또는 `/ehr:compound --set KEY=VAL` |

구현: `lib/audit.sh` 의 `ehr_audit_compound_drift` / `ehr_audit_stale_promotion` / `ehr_audit_preferences_parse` / `ehr_audit_report`. JSON 파싱은 node 기반으로 compact·pretty 양쪽 포맷 모두 안정 동작.

### 반자동 UX

```
질문: "어떻게 진행할까요?"
  1) 반자동 적용 (추천) — 안전한 건 자동, 상급 drift 개별 확인
  2) 보고서만 저장 — docs/harness-audit-YYYYMMDD.md 생성, 변경 없음
  3) 전체 재생성 — 일괄 적용 (사용자 편집 보존)
  4) 취소
```

### HARNESS.json v2 → v3 → v4 마이그레이션

기존 v2 사용자가 "하네스 점검해줘" 하면:
1. 매니페스트가 legacy 로 분류됨
2. "adopt / 전체 재생성 / 취소" 선택지 제공
3. adopt 선택 시 → 현재 분석 결과로 analysis 생성 + v4 재스탬프 (ehr_cycle 기본 주입)
4. 다음 audit 부터 정상 drift 계산 작동

v3 사용자는 **legacy 분류되지 않고** 그대로 stamped 상태 유지 (마이그레이션 유예). 다음 재생성 시 자동으로 v4 로 승격된다.

### audit vs stamped 차이

| 항목 | stamped | audit |
|------|---------|-------|
| 트리거 | "업데이트", "재생성" | "점검", "audit", "drift" |
| 플러그인 파일 diff | ✓ | ✓ |
| 프로젝트 drift 검사 | ✗ | ✓ |
| 리포트 생성 | ✗ | ✓ |
| 실행 시간 | ~10~30초 | ~40~90초 (재분석) |

### Deferred (향후 확장)

- CI 통합 (PR 코멘트로 drift 알림)
- audit 결과 history 추적
- 자동 스케줄링 (주 1회 등)
- HTML 리포트 옵션

---

## 14. EHR Cycle — 지식 누적 폐곡선 (v1.9.0+)

CE(Compound Engineering, [EveryInc/compound-engineering-plugin](https://github.com/EveryInc/compound-engineering-plugin)) 철학을 EHR 하네스에 맞게 재구성한 **쓸수록 축적되는 5단계 사이클**. 생성된 각 고객사 프로젝트에 자동 탑재된다.

**핵심 원칙:** 쓸수록 고객사-로컬 자산(reference, domain-knowledge, 프롬프트, 선호)이 두꺼워지고, 다음 사용이 더 쉬워진다. 고객사 간 지식은 프로젝트-로컬 격리로 절대 섞이지 않는다.

### 폐곡선 개념

```
자연어 질의 → 라우팅 판정 → 필요 단계만 제안
  /ehr:ideate    축적 데이터에서 개선 후보
  /ehr:plan      superpowers:writing-plans + 영향도 분석
  /ehr:work      superpowers:executing-plans + 스킬 라우팅
  /ehr:review    receiving-code-review + release-reviewer + db-impact-reviewer
  /ehr:compound  L2(reference·domain-knowledge) / L3(프롬프트) / 선호 회수
                                       │
                                       ▼
                 다음 사이클 진입 시 축적된 지식으로 시작
```

### 커맨드 5종 (타깃 프로젝트에 자동 생성)

| 커맨드 | 역할 | 배선 |
|---|---|---|
| `/ehr:ideate` | 하네스 축적 데이터에서 고임팩트 개선 후보 제안 | `reference/*`, `domain-knowledge`, `HARNESS.json.analysis` |
| `/ehr:plan` | 기술 계획 작성 + EHR 영향도·DB 영향 섹션 | `superpowers:writing-plans` + `impact-analyzer` + `db-impact-reviewer` |
| `/ehr:work` | 플랜 실행 + EHR 스킬 자동 라우팅 | `superpowers:executing-plans` + `design-guide`/`screen-builder`/`db-query` |
| `/ehr:review` | 다중 관점 릴리스 리뷰 | `superpowers:receiving-code-review` ∥ `release-reviewer` ∥ `db-impact-reviewer` |
| `/ehr:compound` | 지식 회수 — 폐곡선의 닫힘점 | L2·L3·Preferences 블록 갱신 + `HARNESS.json` 이력 |

> 브레인스토밍 단계는 `superpowers:brainstorming` 이 담당 (전제: superpowers 설치 필수).

### 4대 불변식 (재생성으로 절대 유실되지 않음)

1. L2 지식 블록 (`EHR-COMPOUND`) — `reference/*`, `domain-knowledge/SKILL.md`
2. L3 승급 블록 (`EHR-PROMOTED`) — `agents/*.md`, `skills/**/SKILL.md`
3. 협업 선호 블록 (`EHR-PREFERENCES`) — `CLAUDE.md`
4. 사용자 작업물 — `.ehr-bak/`, `docs/ehr/*`

### 새 자산 (플러그인 측)

| 자산 | 위치 |
|---|---|
| 커맨드 스켈레톤 5종 | `profiles/shared/commands/ehr/*.md.skel` |
| `db-impact-reviewer` 에이전트 | `profiles/ehr4\|ehr5/agents/db-impact-reviewer.md` |
| 마커 머지 헬퍼 | `skills/ehr-harness/lib/ehr-compound.sh` |
| audit 드리프트 4종 | `skills/ehr-harness/lib/audit.sh` (`ehr_audit_*` 함수군) |
| HARNESS.json v4 | `ehr_cycle` 섹션 신설 (`compounds[]`·`promoted[]`·`preferences_history[]`) |
| CLAUDE.md 블록 | `EHR-ROUTING` (규칙 고정) + `EHR-PREFERENCES` (선호 누적) |

### 기존 하네스(v3) 마이그레이션

각 업체 프로젝트에서 `/ehr-harness 재생성해줘` 한 번 실행하면 자동으로 v3 → v4 로 승격되며 신규 자산 7개가 심어진다. 업체 간 지식은 **프로젝트-로컬 격리**로 절대 섞이지 않는다.

### EHR Cycle 변경 이력

| 버전 | 주요 변경 |
|---|---|
| **1.9.2** (2026-04-20) | 이슈 3건 수정 — ① Windows git-bash 호환성(`#2`): `.gitattributes` 로 fixture·쉘 eol=lf 강제 + SKILL.md 의 `/dev/stdin` node 호출 2곳을 env-var 패턴으로 통일(Windows 에서 `C:\dev\stdin` ENOENT 제거), ② polish(`#3`): dead `{{DB_VENDOR}}` 치환 선언 삭제 + shared/commands sed 의 dead `{{SESSION_VARS}}` 제거 + `ehr-compound.test.sh` corrupt 테스트에 stderr grep 2건 추가, ③ 문서 drift(`#1`): SKILL.md/HARNESS_SCHEMA.md 의 `schema_version == 3` 서술을 `∈ {3, 4}` 로 정정하고 v3 섹션에 이전 사양 표시 |
| **1.9.1** (2026-04-18) | 코드 리뷰 후 Critical 3건 수정 — ① `ehr_compound_upsert` 의 마커 corruption 탐지 (불변식 1 보호), ② `audit.sh` 의 JSON 파싱을 awk → node 기반으로 교체 (pretty/compact 포맷 모두 안정), ③ `harness-state.sh` v4 스키마 bump + Step 4-I 에 실행 가능한 bash 블록 추가 + Step 4-G 이전으로 재배치 |
| **1.9.0** (2026-04-18) | EHR Cycle 최초 도입 — `/ehr:*` 커맨드 5종, `db-impact-reviewer` 에이전트, 마커 스킴 4종, HARNESS.json v4, 4대 불변식 |
