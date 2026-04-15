---
name: ehr-harness
description: "EHR 프로젝트 하네스 자동 생성 + audit 메타 스킬. '하네스 만들어줘', '하네스 생성해줘', '하네스 설계해줘', '하네스 구성해줘', '하네스 구축해줘', '하네스 업데이트', '하네스 재생성', '하네스 수정', '하네스 갱신', '하네스 점검해줘', '하네스 audit', '하네스 drift 체크', '/harness-audit', '이수하네스', 'ehr하네스', 'EHR하네스', 'e-hr하네스', 'E-HR하네스', '인사시스템 하네스', '인사하네스' 등의 키워드에 트리거."
---

# EHR Harness Generator

EHR 프로젝트를 심층 분석하여 맞춤형 AI 코딩 하네스를 자동 생성한다.

---

## Step 0: 플러그인 위치 탐색

```bash
Glob: "**/ehr-harness/profiles/ehr*/skeleton/AGENTS.md.skel"
```

→ 결과에서 `profiles/` 의 상위 디렉토리를 추출하여 `PLUGIN_ROOT`로 설정.
  - marketplace 설치 시: `~/.claude/plugins/cache/ehr-harness/ehr-harness/<version>/`
  - git clone 시: `.../ehr-harness-plugin/plugins/ehr-harness/`
→ 못 찾으면 사용자에게 플러그인 경로를 물어본다.

---

## Step 0.5: Superpowers 의존성 검증

EHR 하네스는 Superpowers의 메타 스킬(brainstorming, writing-plans, tdd-workflow,
verification-before-completion, systematic-debugging)을 활용해 안전한 개발 흐름을
보장한다. 이 의존성이 없으면 **하네스 생성 자체를 중단**한다.

```bash
SETTINGS="$HOME/.claude/settings.json"

if [ ! -f "$SETTINGS" ]; then
  echo "⚠ Claude Code 설정 파일을 찾을 수 없습니다: $SETTINGS"
  exit 1
fi

# enabledPlugins에서 superpowers@* 패턴 매칭 (어떤 마켓이든 인정)
# - superpowers@superpowers-marketplace (obra 본인 운영)
# - superpowers@claude-plugins-official  (Anthropic 미러)
# 주의: SETTINGS를 Node 서브프로세스에 환경변수로 전달해야 함
#       (export 없이는 process.env.SETTINGS가 undefined)
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
  cat <<'EOF'
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
EOF
  exit 0
fi

echo "✓ Superpowers 플러그인 확인됨"
```

→ Superpowers 미설치 시 안내 메시지 출력 후 **즉시 종료**.
→ 설치됨 확인 후 Step 0.7로 진입.

---

## Step 0.7: 기존 하네스 감지

이 단계는 "이미 하네스가 깔려 있는 프로젝트에 다시 실행됐는가" 를 판정한다.
세 가지 진입 모드 중 하나를 결정하고 그 결과를 `HARNESS_MODE` 변수에 저장한다.

- `fresh` — 하네스 흔적이 전혀 없음. 기존 흐름(Step 1 → Step 4)을 그대로 따라감.
- `legacy` — `AGENTS.md` 같은 하네스 산출물은 있는데 `.claude/HARNESS.json` 이 없음.
- `stamped` — `.claude/HARNESS.json` 이 있고 schema_version 이 채워져 있음.

```bash
# lib/harness-state.sh 가져오기
source "$PLUGIN_ROOT/skills/ehr-harness/lib/harness-state.sh"

MANIFEST=".claude/HARNESS.json"

# 하네스 산출물 흔적 — AGENTS.md + .claude/skills/ehr-* 중 하나라도 있으면 "있음"
HAS_HARNESS_TRACE=0
if [ -f "AGENTS.md" ] || ls .claude/skills/ehr-* >/dev/null 2>&1; then
  HAS_HARNESS_TRACE=1
fi

# USER_TRIGGER_IS_AUDIT 는 사용자 입력에서 "점검", "audit", "drift" 키워드가 감지됐을 때 설정된다.
# (아직 SKILL.md 진입부에 판정 로직을 추가하지 않은 경우 기본값 0)
USER_TRIGGER_IS_AUDIT="${USER_TRIGGER_IS_AUDIT:-0}"

if [ ! -f "$MANIFEST" ] && [ "$HAS_HARNESS_TRACE" = "0" ]; then
  HARNESS_MODE="fresh"
elif [ ! -f "$MANIFEST" ] && [ "$HAS_HARNESS_TRACE" = "1" ]; then
  HARNESS_MODE="legacy"
elif hs_is_legacy "$MANIFEST"; then
  # 매니페스트 파일은 있으나 schema_version 없거나 현재 버전(3)과 다름 → legacy 와 동일 취급
  HARNESS_MODE="legacy"
elif [ "$USER_TRIGGER_IS_AUDIT" = "1" ]; then
  HARNESS_MODE="audit"
else
  HARNESS_MODE="stamped"
fi

echo "HARNESS_MODE=$HARNESS_MODE"
```

→ `fresh` 면 Step 1 로 진행한다 (기존 흐름).
→ `legacy` 면 Step 0.7-A (legacy adopt) 로 분기한다.
→ `stamped` 면 Step 0.7-B (업데이트 모드) 로 분기한다.

### Step 0.7-A: legacy adopt 분기

`AskUserQuestion` 으로 다음을 묻는다.

```
질문: "기존 하네스 흔적이 감지됐는데 버전 스탬프(.claude/HARNESS.json)가 없습니다. 어떻게 할까요?"
헤더: "하네스 모드"
  - 1: "현 상태 인정 (adopt)" — 파일은 그대로 두고 스탬프만 새로 부여. 다음 실행부터 정상 업데이트 가능.
  - 2: "전체 재생성" — 기존 동작. 모든 파일을 새로 덮어씀.
  - 3: "취소" — 아무것도 안 함.
```

- 응답이 1이면 → `LEGACY_ADOPT=1` 로 설정하고 Step 1 로 진행하되, **Step 3 의 모든 Write 를 스킵**하고 Step 4-G 에서 매니페스트만 새로 작성한다.
- 응답이 2이면 → 기존 흐름. Step 1 → Step 4 진행 (`HARNESS_MODE=fresh` 와 동일하게 동작).
- 응답이 3이면 → 즉시 종료.

### Step 0.7-B: 업데이트 모드 분기

`stamped` 인 경우, Step 1 ~ Step 2 를 정상적으로 수행한 뒤 (모듈 맵/치명 프로시저 등 분석 결과는 항상 최신화 필요), **Step 3 직전에 diff 를 계산하고 사용자 확인을 받는다**. 자세한 절차는 Step 3-PRE 에서 정의한다.

### Step 0.7-C: audit 모드 분기

사용자 입력에 "점검", "audit", "drift 체크", "/harness-audit" 같은 키워드가 포함된 경우 `HARNESS_MODE=audit`로 설정한다.

- 진입 조건: 매니페스트 존재 + schema_version==3 + 사용자 명시 audit 트리거
- 매니페스트가 없으면 "audit 불가, 먼저 하네스 설치 필요" 안내 후 종료
- audit 모드는 Step 1 ~ Step 2 를 그대로 수행하고, **Step AUDIT-REPORT 에서 drift 계산 + 사용자 확인**을 진행한다
- audit 결과 승인되면 Step 3 로 진입해 승인된 파일만 Write 한다 (stamped 와 동일한 should_write 가드 적용)

자세한 절차는 Step AUDIT-REPORT 에서 정의한다.

---

## Step 1: EHR 버전 감지

아래 순서로 판정한다. 첫 매칭에서 확정.

```bash
# 1-A. Maven + MyBatis → EHR5
ls pom.xml 2>/dev/null && grep -q "mybatis" pom.xml && echo "EHR5"

# 1-B. *-sql-query.xml 존재 → EHR5
find . -name "*-sql-query.xml" -not -path "./.git/*" | head -1

# 1-C. Ant + Anyframe → EHR4
ls build.xml 2>/dev/null && echo "EHR4"

# 1-D. *-mapping-query.xml 존재 → EHR4
find . -name "*-mapping-query.xml" -not -path "./.git/*" | head -1
```

- EHR5 확정 → `PROFILE=ehr5`
- EHR4 확정 → `PROFILE=ehr4`
- 판정 불가 → 사용자에게 질문: "EHR 버전을 선택해주세요 (EHR4 / EHR5)"

**확정 후 출력**: "EHR 버전 감지: {{PROFILE}} (근거: pom.xml + MyBatis)"

---

## Step 2: 프로젝트 심층 분석

### 2-A. Java 경로 확정

```bash
# EHR5
JAVA_ROOT="src/main/java/com/hr"
MAPPER_ROOT="src/main/resources/mapper/com/hr"
JSP_ROOT="src/main/webapp/WEB-INF/jsp"

# EHR4
JAVA_ROOT="src/com/hr"
MAPPER_ROOT="src/com/hr"    # 매퍼가 Java와 같은 경로
JSP_ROOT="WebContent/WEB-INF/jsp"
```

### 2-B. 모듈 맵 수집

```bash
ls $JAVA_ROOT/
# → hrm, cpn, tim, wtm, pap, ben, sys, org, tra, hri, com 등

# 모듈별 Java 파일 수
for mod in $(ls $JAVA_ROOT/); do
  count=$(find $JAVA_ROOT/$mod -name "*.java" 2>/dev/null | wc -l)
  echo "| $mod | | $count 파일 |"
done
```

→ 결과를 마크다운 테이블로 정리. 도메인명은 아래 사전 참조:
- hrm=인사관리, cpn=급여/보상, tim=근태관리, wtm=근무시간관리
- pap=평가, ben=복리후생, sys=시스템관리, org=조직, tra=교육
- hri=신청/결재, com=공통

### 2-C. 법칙별 사용 수

```bash
# 법칙 B (GetDataList.do)
grep -rl "GetDataList.do" --include="*.jsp" $JSP_ROOT/ 2>/dev/null | wc -l

# 법칙 B (SaveData.do)
grep -rl "SaveData.do" --include="*.jsp" $JSP_ROOT/ 2>/dev/null | wc -l

# 법칙 C (AuthTableService 주입 컨트롤러)
grep -rl "AuthTableService" --include="*.java" $JAVA_ROOT/ 2>/dev/null | wc -l

# 법칙 D (ExecPrc.do)
grep -rl "ExecPrc.do" --include="*.jsp" $JSP_ROOT/ 2>/dev/null | wc -l
```

### 2-D. 세션 변수 수집

```bash
grep -roh 'session\.getAttribute("[^"]*")' --include="*.java" $JAVA_ROOT/ 2>/dev/null | \
  grep -oP '"[^"]*"' | sort -u
```

→ 결과 목록을 `SESSION_VARS`로 저장.
→ 최소 확인 대상: `ssnEnterCd`, `ssnSabun`, `ssnSearchType`, `ssnGrpCd`

### 2-E. authSqlID 값 수집

```bash
grep -roh '"authSqlID"[^"]*"[A-Za-z0-9]*"' --include="*.java" --include="*.jsp" $JAVA_ROOT/ $JSP_ROOT/ 2>/dev/null | \
  grep -oP '"[A-Z]{4}\d{3}"' | sort -u
```

→ 결과: THRM151, TORG101 등. `AUTH_SQL_IDS`로 저장.

### 2-F. 재구현 금지 컴포넌트 참조 수

```bash
for comp in GetDataListController SaveDataController ExecPrcController \
            AuthTableService ApprovalMgr UploadMgr CommonCodeService; do
  count=$(grep -rl "$comp" --include="*.java" --include="*.jsp" . 2>/dev/null | wc -l)
  echo "| $comp | $count |"
done
```

### 2-G. 치명 프로시저/패키지/함수/트리거 존재 확인

"치명" = 비즈니스 로직이 복잡하게 얽혀 있어, AI가 단독 수정 시 연쇄 장애가 발생할 수 있는 오브젝트.
급여 계산 체인, 인사발령, 연말정산, 결재 경로 등 핵심 업무 프로시저를 포함한다.

```bash
# 매퍼 확장자 결정
if [ "$PROFILE" = "ehr5" ]; then
  MAPPER_EXT="*-sql-query.xml"
else
  MAPPER_EXT="*-mapping-query.xml"
fi

# ── 치명 프로시저 확인 (고정 목록) ──
for proc in P_CPN_CAL_PAY_MAIN P_CPN_SMPPYM_EMP P_CPN_ORIGIN_TAX_INS \
            P_HRM_POST P_HRM_POST_DETAIL \
            P_TIM_WORK_HOUR_CHG P_TIM_VACATION_CLEAN P_TIM_ANNUAL_CREATE \
            P_HRI_AFTER_PROC_EXEC P_HRI_APP_PATH_INS_AUTO_ALL; do
  found=$(grep -rl "$proc" --include="$MAPPER_EXT" . 2>/dev/null | head -1)
  if [ -n "$found" ]; then
    echo "OK $proc → $found"
  else
    echo "NOT_FOUND $proc"
  fi
done

# ── 치명 프로시저 확인 (연도별 확장 패턴) ──
# P_CPN_YEAREND_MONPAY_YYYY (2025~): 연말정산 월급여 연동
for year_proc in $(grep -roh "P_CPN_YEAREND_MONPAY_[0-9]*" --include="$MAPPER_EXT" . 2>/dev/null | sort -u); do
  echo "OK (연도별) $year_proc"
done

# ── 치명 패키지 확인 ──
# PKG_CPN_SEP: 퇴직금/퇴직연금
grep -rl "PKG_CPN_SEP" --include="$MAPPER_EXT" . 2>/dev/null | head -1 && echo "OK PKG_CPN_SEP"

# PKG_CPN_PUMP_API: 급여 펌프
grep -rl "PKG_CPN_PUMP_API" --include="$MAPPER_EXT" . 2>/dev/null | head -1 && echo "OK PKG_CPN_PUMP_API"

# PKG_CPN_YEA_YYYY_* (2025~): 연말정산 패키지 군
# _CODE, _DISK, _EMP, _ERRCHK, _SYNC 등 서브 패키지 포함
for year_pkg in $(grep -roh "PKG_CPN_YEA_[0-9]*[A-Z_]*" --include="$MAPPER_EXT" --include="*.java" --include="*.jsp" . 2>/dev/null | sort -u); do
  year_num=$(echo "$year_pkg" | grep -oP '\d{4}')
  if [ -n "$year_num" ] && [ "$year_num" -ge 2025 ]; then
    echo "OK (연도별 치명패키지) $year_pkg"
  fi
done

# ── 치명 함수 확인 ──
# WORK_INFO_TEMP: 인원의 요일별 근무코드별 근무시간 (P_TIM_WORK_HOUR_CHG 참조)
grep -rl "WORK_INFO_TEMP" --include="$MAPPER_EXT" --include="*.java" . 2>/dev/null | head -1 && echo "OK WORK_INFO_TEMP"

# ── 치명 트리거 확인 ──
for trg in TRG_HRI_103 TRG_TIM_405; do
  found=$(grep -rl "$trg" --include="*.java" --include="*.xml" --include="*.jsp" . 2>/dev/null | head -1)
  if [ -n "$found" ]; then
    echo "OK $trg → $found"
  else
    echo "NOT_FOUND $trg"
  fi
done

# ── P_CPN_CAL_PAY_MAIN 하위 프로시저 탐색 (DB 연결 가능 시) ──
# SELECT DISTINCT REGEXP_SUBSTR(TEXT, '(P_\w+|PKG_\w+)', 1, 1) AS SUB_PROC
# FROM USER_SOURCE
# WHERE NAME = 'P_CPN_CAL_PAY_MAIN' AND TYPE = 'PROCEDURE'
#   AND REGEXP_LIKE(TEXT, '(P_\w+|PKG_\w+)') AND LINE > 1
# ORDER BY 1;
# → 결과를 모두 치명 등급으로 추가 등록
```

→ 존재 확인된 것만 `CRITICAL_PROC` 레지스트리에 등록.
→ NOT_FOUND는 경고 목록에 추가.
→ 연도별 패턴은 `{YYYY} >= 2025` 조건으로 자동 확장.
→ DB 연결 가능 시 P_CPN_CAL_PAY_MAIN의 서브 프로시저를 USER_SOURCE에서 추가 탐색.

### 2-H. 전체 프로시저/트리거 목록

```bash
# 코드 기반 전체 프로시저 목록
grep -roh "CALL P_[A-Z_]*\|CALL PKG_[A-Z_]*" --include="$MAPPER_EXT" . 2>/dev/null | \
  sed 's/CALL //' | sort -u

# DB 연결 가능 시 (db-query 스킬 참조):
# SELECT OBJECT_NAME, OBJECT_TYPE FROM USER_OBJECTS 
# WHERE OBJECT_TYPE IN ('PROCEDURE','TRIGGER','PACKAGE','FUNCTION')
# ORDER BY OBJECT_TYPE, OBJECT_NAME;
```

→ DB 연결 불가 시:
- 코드 grep 기반 목록만 등록
- 경고: "⚠ DB 연결 불가. 코드 기반 프로시저 목록만 등록됨. DB 연결 후 `db-query` 스킬로 전체 목록을 갱신하세요."

### 2-I. 핵심 화면 코드 패턴 분석

**반드시 읽는 화면** (존재 시):

1. **vacationApp** (Family C — 신청서)
   ```bash
   find . -iname "*VacationApp*Controller*" -o -iname "*VacationApp*Service*" | head -4
   find . -iname "*vacationApp*" -name "$MAPPER_EXT" | head -1
   find . -iname "*vacationApp.jsp" | head -1
   ```

2. **vacationAppDet** (Family C — 상세)
   ```bash
   find . -iname "*VacationAppDet*" | head -4
   ```

3. **vacationApr** (Family C — 결재)
   ```bash
   find . -iname "*VacationApr*" | head -4
   ```

4. **orgCdMgr** (Family A — 기본 CRUD)
   ```bash
   find . -iname "*OrgCdMgr*" | head -4
   ```

**모듈별 대표 화면** (각 1개):

```bash
for mod in hrm hri pap tra cpn wtm tim sys org; do
  controller=$(find $JAVA_ROOT/$mod -name "*Controller.java" 2>/dev/null | head -1)
  if [ -n "$controller" ]; then
    echo "$mod: $controller"
  fi
done
```

→ 발견된 화면의 Controller, Service, Mapper, JSP 4개 파일을 읽어 코드 패턴 추출:
- MERGE문 실제 예시
- DELETE문 실제 예시
- JSP에서 DoSearch/DoSave 호출 패턴
- Controller → Service → DAO 호출 체인

→ 추출된 패턴을 `CODE_EXAMPLES`에 저장.
→ 너무 길면 파일 경로 참조 링크로 대체.

### 2-J. DB 접속 정보 탐지 + 인터랙티브 폴백

이 단계가 끝나면 다음 두 값이 결정된다:

- `DB_MODE` ∈ {`direct`, `dump`, `code-only`}
- `DB_CONNECTION` (direct 모드일 때만) 또는 `DUMP_DIR` (dump 모드일 때만)

#### 2-J-1. 접속 정보 자동 탐지

```bash
# EHR5: application.properties / application.yml
grep -r "spring.datasource" --include="*.properties" --include="*.yml" . 2>/dev/null

# EHR4/5: context.xml
find . -name "context*.xml" -exec grep -l "dataSource\|jdbcUrl\|jdbc" {} \; 2>/dev/null

# Spring XML
find . -name "*.xml" -path "*/spring/*" -exec grep -l "dataSource" {} \; 2>/dev/null

# OJDBC 드라이버 위치
find . -name "ojdbc*.jar" -o -name "tibero*.jar" 2>/dev/null
```

→ 발견되면 `DB_CONNECTION` 후보로 저장 (host/port/sid/user/pass).

#### 2-J-2. 분기: 연결 시도 결과에 따라

**Case A: 접속 정보 발견 → 실제 연결 시도**

```bash
if [ -n "$DB_CONNECTION" ]; then
  # sqlplus 또는 jdbc test로 connection 시도
  # (드라이버 jar가 있으면 javac로 간단한 test 클래스 컴파일 후 실행)
  CONNECT_RESULT=$(test_db_connection "$DB_CONNECTION" 2>&1)

  if [ $? -eq 0 ]; then
    DB_MODE="direct"
    echo "✓ DB 연결 성공"
    # 2-J-5로 진행 (direct 모드 저장)
  else
    # 역질문 ① 발동 — 접속 실패 분기
    ASK_REASON="failure"
    ASK_DETAIL="$CONNECT_RESULT"
  fi
else
  # 역질문 ② 발동 — 접속 정보 미발견 분기
  ASK_REASON="missing"
  ASK_DETAIL=""
fi
```

#### 2-J-3. 역질문 (AskUserQuestion 도구 사용)

연결 실패(`failure`) 또는 미발견(`missing`)일 때, 사용자에게 구조화된 선택지를 제공한다.

**역질문 ① (failure)**:
```
질문: "DB 접속 정보를 찾았지만 연결에 실패했습니다. 어떻게 진행할까요?"
헤더: "DB 폴백"
  - 1: "접속 정보 직접 입력" — host/port/sid/user/pass 직접 알려주기
  - 2: "DDL 덤프 폴더 사용" — DB 객체가 파일로 있는 폴더 경로 제공
  - 3: "코드 grep만 진행" — 불완전해도 코드 분석만으로 구성
```

**역질문 ② (missing)**:
```
질문: "DB 접속 정보를 찾지 못했습니다. 어떻게 진행할까요?"
헤더: "DB 폴백"
  - 1: "접속 정보 직접 입력"
  - 2: "DDL 덤프 폴더 사용"
  - 3: "코드 grep만 진행"
```

#### 2-J-4. 사용자 응답 처리

**[1] 접속 정보 직접 입력 (DIRECT 재시도)**

사용자에게 자유 텍스트로 접속 정보 받기:
```
"다음 형식으로 접속 정보를 알려주세요:
  host: <값>
  port: <값>
  sid: <값>
  user: <값>
  password: <값>"
```

→ 응답 파싱 후 `DB_CONNECTION` 재구성 → 2-J-2 재시도.
→ **3회 연속 실패 시 자동으로 [3] CODE-ONLY로 fallback**.

**[2] DDL 덤프 폴더 사용 (DUMP 모드)**

```bash
# 사용자에게 폴더 경로 요청
echo "DDL/프로시저 덤프 폴더의 경로를 알려주세요."
echo "예: ./db/schema/  또는  C:/EHR_DUMP/"
echo "(절대경로·상대경로 모두 OK. 확장자는 무관. 내부는 UTF-8 가정)"

# 경로 정규화 (상대경로 → 절대경로)
DUMP_DIR=$(realpath "$USER_INPUT" 2>/dev/null)
if [ ! -d "$DUMP_DIR" ]; then
  echo "⚠ 유효하지 않은 경로: $USER_INPUT"
  # 재입력 루프 (최대 3회)
fi

# 형태 자동 판정 (F1~F4, F5는 바이너리라 미지원)
FORMAT=$(detect_dump_format "$DUMP_DIR")
# - F1: 단일 SQL 파일
# - F2: 객체 타입별 서브폴더 (tables/, procedures/, packages/, functions/, triggers/)  ★ 대부분
# - F3: 객체별 개별 파일 (한 폴더에 다 섞임)
# - F4: Toad/SQL Developer 카테고리별 익스포트
# - F5: .dmp 바이너리 → 미지원, "impdp로 import 후 직접 연결 필요" 안내 후 CODE-ONLY fallback

# 전체 파일 스캔 (확장자 무시)
TOTAL_FILES=$(find "$DUMP_DIR" -type f 2>/dev/null | wc -l)

# 객체 타입별 카운트 (EHR 컨벤션 접두어 기반)
TABLE_CNT=$(grep -rilE "CREATE\s+(OR\s+REPLACE\s+)?TABLE\s+T_" "$DUMP_DIR" 2>/dev/null | wc -l)
PROC_CNT=$(grep -rilE "CREATE\s+(OR\s+REPLACE\s+)?PROCEDURE\s+P_" "$DUMP_DIR" 2>/dev/null | wc -l)
PKG_CNT=$(grep -rilE "CREATE\s+(OR\s+REPLACE\s+)?PACKAGE(\s+BODY)?\s+PKG_" "$DUMP_DIR" 2>/dev/null | wc -l)
FUNC_CNT=$(grep -rilE "CREATE\s+(OR\s+REPLACE\s+)?FUNCTION\s+F_" "$DUMP_DIR" 2>/dev/null | wc -l)
TRIG_CNT=$(grep -rilE "CREATE\s+(OR\s+REPLACE\s+)?TRIGGER\s+TRG_" "$DUMP_DIR" 2>/dev/null | wc -l)

# 결과 보고
cat <<EOF
═══════════════════════════════════════════════════════════════
  📊 덤프 폴더 스캔 결과
═══════════════════════════════════════════════════════════════
  경로:     $DUMP_DIR
  형태:     $FORMAT
  총 파일:  $TOTAL_FILES개

  객체 타입별:
    • 테이블:    $TABLE_CNT
    • 프로시저:  $PROC_CNT
    • 패키지:    $PKG_CNT
    • 함수:      $FUNC_CNT
    • 트리거:    $TRIG_CNT

  이 정보로 진행할까요?
EOF

# AskUserQuestion으로 y/n 확인 → y면 DUMP_INDEX.json 생성
```

**DUMP_INDEX.json 스키마** (`.claude/skills/ehr-db-query/DUMP_INDEX.json`로 저장):

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

→ `DB_MODE="dump"`, `DUMP_DIR="$DUMP_DIR"`

**[3] 코드 grep만 진행 (CODE-ONLY)**

```bash
DB_MODE="code-only"
echo "⚠ 코드 grep 기반으로만 진행. 프로시저/트리거 정보가 불완전할 수 있습니다."
```

#### 2-J-5. DB_MODE 저장

```bash
# 최종 결정된 DB_MODE를 파일로 저장 (후속 스킬이 읽음)
mkdir -p .claude/skills/ehr-db-query
echo "$DB_MODE" > .claude/skills/ehr-db-query/DB_MODE
```

→ 이 파일은 `ehr-procedure-tracer`와 `ehr-db-query` 스킬이 동작 모드를 분기할 때 참조한다.

### 2-K. 디자인 가이드 (Storybook) 탐지

고정 경로에서 Storybook 빌드 산출물을 찾는다. 광역 탐색·다중 Storybook은 지원하지 않는다.

```bash
SB_PATH="src/main/resources/static/guide/storybook-static"

if [ ! -d "$SB_PATH" ] || [ ! -f "$SB_PATH/project.json" ]; then
  DESIGN_GUIDE=false
  echo "디자인 가이드 미발견 → ehr-design-guide 스킬 스킵"
  # Step 3으로 진행 (디자인 가이드 생성 없음)
else
  DESIGN_GUIDE=true
  echo "✓ 디자인 가이드 발견: $SB_PATH"

  # project.json 메타 추출
  SB_GENERATED_AT=$(node -e "
    console.log(JSON.parse(require('fs').readFileSync('$SB_PATH/project.json','utf8')).generatedAt)
  ")
  SB_VERSION=$(node -e "
    console.log(JSON.parse(require('fs').readFileSync('$SB_PATH/project.json','utf8')).storybookVersion)
  ")

  # index.json 파싱 → 카테고리 트리 + title→JS 매핑
  node -e "
    const idx = JSON.parse(require('fs').readFileSync('$SB_PATH/index.json','utf8'));
    const titles = {};
    for (const [id, e] of Object.entries(idx.entries||{})) {
      if (e.title) titles[e.title] = { id, name: e.name, importPath: e.importPath };
    }
    require('fs').writeFileSync('/tmp/sb_titles.json', JSON.stringify(titles, null, 2));
  "

  # assets/ 폴더에서 컴포넌트별 JS 파일 매핑 구성
  # 파일명 패턴: <ComponentName>-<hash>.js
  # 예: Button-DfetVkf1.js → Button
  # → TITLE_TO_JS 연상배열에 저장
fi
```

**증분 갱신**:
기존 `.claude/skills/ehr-design-guide/MANIFEST.json`이 있으면 `generated_at`을 비교해서
일치하면 Step 2-K 이후 디자인 가이드 관련 생성(Step 3-F) 전체를 스킵한다.

#### 2-J-6. DDL 폴더 감별 (ddl_authoring + db_verification)

repo 내에 DDL 소스 폴더가 있는지 감별하여 `ddl_authoring.enabled` 와 `db_verification.b3_strategy` 를 결정한다.

```bash
# detect.sh 로드 (2-M과 공유)
source "$PLUGIN_ROOT/skills/ehr-harness/lib/detect.sh"

# DDL 폴더 감별 실행
DDL_AUTH_JSON=$(detect_ddl_folder "$(pwd)")

# DDL 폴더 enabled 여부에 따라 b3_strategy 결정
DDL_ENABLED=$(echo "$DDL_AUTH_JSON" | node -e "
  const m=JSON.parse(require('fs').readFileSync('/dev/stdin','utf8'));
  process.stdout.write(m.enabled ? 'yes' : 'no');
")

if [ "$DDL_ENABLED" = "yes" ]; then
  if [ "$DB_MODE" = "direct" ]; then
    B3_STRATEGY="ddl-first"
  else
    B3_STRATEGY="ddl-first"  # DDL 파일 있으면 DB 없어도 Tier 1으로 가능
  fi
  DB_ACCESS_STATE=$( [ "$DB_MODE" = "direct" ] && echo "available" || echo "unavailable" )
elif [ "$DB_MODE" = "direct" ]; then
  B3_STRATEGY="db-only"
  DB_ACCESS_STATE="available"
elif [ "$DB_MODE" = "dump" ]; then
  B3_STRATEGY="ddl-first"  # dump도 DDL 소스로 간주
  DB_ACCESS_STATE="dump-only"
else
  B3_STRATEGY="manual-required"
  DB_ACCESS_STATE="unavailable"
fi

DB_VERIFICATION_JSON=$(DDL="$DDL_AUTH_JSON" DBA="$DB_ACCESS_STATE" B3S="$B3_STRATEGY" node -e "
  const ddl=JSON.parse(process.env.DDL);
  const out = {
    ddl_path: ddl.table_path || null,
    db_access: process.env.DBA,
    b3_strategy: process.env.B3S
  };
  process.stdout.write(JSON.stringify(out));
")

echo "=== DDL 폴더 감별 결과 ==="
echo "$DDL_AUTH_JSON" | node -e "
  const m=JSON.parse(require('fs').readFileSync('/dev/stdin','utf8'));
  console.log('enabled:        ' + m.enabled);
  console.log('table_path:     ' + (m.table_path||'(없음)'));
  console.log('procedure_path: ' + (m.procedure_path||'(없음)'));
  console.log('function_path:  ' + (m.function_path||'(없음)'));
  console.log('naming_pattern: ' + (m.naming_pattern||'(없음)'));
  console.log('existing_tables:' + m.existing_tables.length + '개');
"
echo "=== DB 검증 전략 ==="
echo "db_access:    $DB_ACCESS_STATE"
echo "b3_strategy:  $B3_STRATEGY"
```

**사용자 확인 프롬프트 (enabled=true 일 때만)**:

```
질문: "DDL 폴더가 감지됐습니다. screen-builder가 신규 테이블/프로시저/함수를 이 폴더에 자동 생성할 수 있습니다. 활성화할까요?"
헤더: "DDL 자동 작성"
  - 1: "활성화 — 생성 시 매번 이름 확인 프롬프트 제공"
  - 2: "비활성화 — screen-builder는 '사용자가 DBA에 요청하세요' 안내만"
```

**[2] 비활성화**: `DDL_AUTH_JSON` 의 `enabled` 를 `false` 로 강제.

→ `DDL_AUTH_JSON`, `DB_VERIFICATION_JSON` 을 이후 단계에서 사용.

### 2-M. 권한 모델 감별 (auth_model)

프로젝트의 권한 주입 방식을 감별한다. reviewer 에이전트가 조건부 검증에 사용.

```bash
# detect.sh 로드
source "$PLUGIN_ROOT/skills/ehr-harness/lib/detect.sh"

# 권한 모델 감별 실행
AUTH_MODEL_JSON=$(detect_auth_model "$(pwd)" "$PROFILE")

# 사람이 읽기 쉬운 마크다운 테이블 생성 (AGENTS.md 용)
AUTH_MODEL_MD=$(AM="$AUTH_MODEL_JSON" node -e "
  const m=JSON.parse(process.env.AM);
  const row = (k, v) => {
    const val = Array.isArray(v) ? (v.length ? v.join(', ') : '_(없음)_') : (v || '_(없음)_');
    return '| ' + k + ' | ' + val + ' |';
  };
  console.log('| 항목 | 값 |');
  console.log('|------|-----|');
  console.log(row('공통 컨트롤러', m.common_controllers));
  console.log(row('권한 서비스 클래스', m.auth_service_class));
  console.log(row('권한 주입 방식', m.auth_injection_methods));
  console.log(row('권한 테이블', m.auth_tables));
  console.log(row('권한 함수', m.auth_functions));
  console.log(row('세션 변수', m.session_vars));
")

echo "=== 권한 모델 감별 결과 ==="
echo "$AUTH_MODEL_MD"
```

**사용자 확인 프롬프트 (AskUserQuestion 도구 사용)**:

```
질문: "감별된 권한 모델이 맞나요? 틀리면 reviewer가 잘못된 체크를 합니다."
헤더: "권한 모델 확인"
  - 1: "맞음 — 그대로 기록"
  - 2: "수정 필요 — 직접 입력"
  - 3: "감별 건너뛰기 — auth_model 비어있음으로 기록 (reviewer가 해당 체크 생략)"
```

**[2] 수정 필요**: 사용자가 자유 텍스트로 수정한 JSON 블록 제공 → 파싱 후 `AUTH_MODEL_JSON` 재구성.

**[3] 감별 건너뛰기**: `AUTH_MODEL_JSON='{"common_controllers":[],"auth_service_class":null,"auth_injection_methods":[],"auth_tables":[],"auth_functions":[],"session_vars":[]}'`

→ `AUTH_MODEL_JSON` 과 `AUTH_MODEL_MD` 를 이후 단계에서 사용.

### 2-L. 서브패키지 맵 + DB prefix 맵 생성

모듈별 서브패키지 구조와 DB 테이블 prefix 규칙을 경량 맵으로 생성한다.
이 데이터는 `{{SUBPACKAGE_MAP}}`과 `{{DB_PREFIX_MAP}}`으로 CLAUDE.md에 주입되어
AI가 코드/DB 탐색 시 grep 횟수를 줄인다 (~540 tokens 추가).

```bash
# 서브패키지 맵: 모듈별 Java 하위 디렉토리 + Controller 수
SUBPACKAGE_MAP=""
for mod in $(ls $JAVA_ROOT/ 2>/dev/null); do
  if [ -d "$JAVA_ROOT/$mod" ]; then
    pkgs=""
    for subdir in $(ls $JAVA_ROOT/$mod/ 2>/dev/null); do
      if [ -d "$JAVA_ROOT/$mod/$subdir" ]; then
        cnt=$(find "$JAVA_ROOT/$mod/$subdir" -name "*Controller.java" 2>/dev/null | wc -l)
        if [ "$cnt" -gt 0 ]; then
          pkgs="$pkgs $subdir($cnt)"
        fi
      fi
    done
    if [ -n "$pkgs" ]; then
      SUBPACKAGE_MAP="$SUBPACKAGE_MAP
$mod:$pkgs"
    fi
  fi
done
```

```bash
# DB prefix 맵: 고정값 (EHR5 기본 패키지 공통)
DB_PREFIX_MAP="TCP→CPN(급여) THR→HRM(인사) TSY→SYS(시스템) TTI→TIM(근태) TWT→WTM(근무) TBE→BEN(복리) TOR→ORG(조직) TPA→PAP(평가) TYE→YEA(연말정산) TCD→COD(코드) TTR→TRN(교육)"
```

→ `SUBPACKAGE_MAP`과 `DB_PREFIX_MAP`은 CLAUDE.md.skel 치환에 사용된다.

#### 2-L-2. CODE_MAP.md / DB_MAP.md 고정 레퍼런스 복사

플러그인에 포함된 고정 레퍼런스 파일을 프로젝트 루트로 복사한다.
이 파일들은 EHR5 기본 패키지 기준이며, 스킬에서 상세 탐색 시 참조한다.

```bash
REFERENCE_DIR="$PLUGIN_ROOT/profiles/$PROFILE/reference"
if [ -f "$REFERENCE_DIR/CODE_MAP.md" ]; then
  cp "$REFERENCE_DIR/CODE_MAP.md" CODE_MAP.md
fi
if [ -f "$REFERENCE_DIR/DB_MAP.md" ]; then
  cp "$REFERENCE_DIR/DB_MAP.md" DB_MAP.md
fi
```

```bash
MANIFEST=".claude/skills/ehr-design-guide/MANIFEST.json"
if [ -f "$MANIFEST" ]; then
  OLD_GEN=$(node -e "console.log(JSON.parse(require('fs').readFileSync('$MANIFEST','utf8')).generated_at)")
  if [ "$OLD_GEN" = "$SB_GENERATED_AT" ]; then
    SKIP_DESIGN_GUIDE=true
    echo "디자인 가이드 변경 없음 → 재추출 스킵"
  fi
fi
```

---

### 2-N. analysis JSON 조립

프로젝트 분석 결과를 `analysis` 필드로 조립한다. audit 모드가 drift 비교의 기준점으로 사용.

```bash
# analyze.sh 로드
source "$PLUGIN_ROOT/skills/ehr-harness/lib/analyze.sh"

# 프로젝트 분석 결과 집계
ANALYSIS_JSON=$(build_analysis_json "$(pwd)" "$PROFILE")

echo "=== 분석 스냅샷 ==="
echo "$ANALYSIS_JSON" | node -e "
  let s='';process.stdin.on('data',d=>s+=d);
  process.stdin.on('end',()=>{const m=JSON.parse(s);
    console.log('analyzed_at:   ' + m.analyzed_at);
    console.log('modules:       ' + m.module_map.length + '개');
    console.log('session_vars:  ' + m.session_vars.join(', '));
    console.log('critical_proc: ' + m.critical_proc_found.length + ' found / ' + m.critical_proc_missing.length + ' missing');
    console.log('procedures:    ' + m.procedure_count + '건 호출');
    console.log('triggers:      ' + m.trigger_count + '건');
  });
"
```

→ `ANALYSIS_JSON` 을 Step 4-G hs_write_manifest 에 전달.

---

## Step 3-PRE: 소스/출력 매핑과 diff 계산

이 단계의 1번(SOURCE_MAP 빌드)은 모든 모드에서 실행한다 (Step 4-G 가 매니페스트를 쓸 때 필요).
2~6번(bucket 분류 + 사용자 확인) 은 `HARNESS_MODE=stamped` 일 때만 실행한다.

### 3-PRE-1. SOURCE_MAP 빌드

모든 출력 파일을 [source_key | source_abs | output_key | output_abs] 4-튜플로 등록한다.

```bash
build_source_map() {
  SOURCE_MAP=""
  add() {
    SOURCE_MAP="$SOURCE_MAP
$1|$2|$3|$4"
  }

  # 인프라 (shared/)
  add "profiles/shared/settings.json"         "$PLUGIN_ROOT/profiles/shared/settings.json"         ".claude/settings.json"        ".claude/settings.json"
  add "profiles/shared/hooks/db-read-only.sh" "$PLUGIN_ROOT/profiles/shared/hooks/db-read-only.sh" ".claude/hooks/db-read-only.sh" ".claude/hooks/db-read-only.sh"
  add "profiles/shared/.codex/config.toml"    "$PLUGIN_ROOT/profiles/shared/.codex/config.toml"    ".codex/config.toml"           ".codex/config.toml"

  # 문서 (skel 기반)
  add "profiles/$PROFILE/skeleton/AGENTS.md.skel" "$PLUGIN_ROOT/profiles/$PROFILE/skeleton/AGENTS.md.skel" "AGENTS.md" "AGENTS.md"
  add "profiles/$PROFILE/skeleton/CLAUDE.md.skel" "$PLUGIN_ROOT/profiles/$PROFILE/skeleton/CLAUDE.md.skel" "CLAUDE.md" "CLAUDE.md"
  add "profiles/$PROFILE/skeleton/README.md.skel" "$PLUGIN_ROOT/profiles/$PROFILE/skeleton/README.md.skel" "README.md" "README.md"

  # 스킬 (5개 + 디자인 가이드)
  for s in domain-knowledge screen-builder codebase-navigator procedure-tracer db-query; do
    src_dir="$PLUGIN_ROOT/profiles/$PROFILE/skills/$s"
    if [ -f "$src_dir/SKILL.md.skel" ]; then
      src_file="$src_dir/SKILL.md.skel"
      src_key="profiles/$PROFILE/skills/$s/SKILL.md.skel"
    else
      src_file="$src_dir/SKILL.md"
      src_key="profiles/$PROFILE/skills/$s/SKILL.md"
    fi
    add "$src_key" "$src_file" ".claude/skills/ehr-$s/SKILL.md" ".claude/skills/ehr-$s/SKILL.md"
  done

  if [ "$DESIGN_GUIDE" = "true" ]; then
    add "profiles/$PROFILE/skills/design-guide/SKILL.md.skel" \
        "$PLUGIN_ROOT/profiles/$PROFILE/skills/design-guide/SKILL.md.skel" \
        ".claude/skills/ehr-design-guide/SKILL.md" \
        ".claude/skills/ehr-design-guide/SKILL.md"
  fi

  # 에이전트
  add "profiles/$PROFILE/agents/screen-builder.md"    "$PLUGIN_ROOT/profiles/$PROFILE/agents/screen-builder.md"    ".claude/agents/screen-builder.md"    ".claude/agents/screen-builder.md"
  add "profiles/$PROFILE/agents/procedure-tracer.md"  "$PLUGIN_ROOT/profiles/$PROFILE/agents/procedure-tracer.md"  ".claude/agents/procedure-tracer.md"  ".claude/agents/procedure-tracer.md"
  add "profiles/$PROFILE/agents/release-reviewer.md"  "$PLUGIN_ROOT/profiles/$PROFILE/agents/release-reviewer.md"  ".claude/agents/release-reviewer.md"  ".claude/agents/release-reviewer.md"
}

build_source_map
```

### 3-PRE-2. 프로파일 변경 감지 (stamped 모드)

```bash
if [ "$HARNESS_MODE" = "stamped" ]; then
  STORED_PROFILE=$(hs_get_profile "$MANIFEST")
  if [ -n "$STORED_PROFILE" ] && [ "$STORED_PROFILE" != "$PROFILE" ]; then
    echo "⚠ 프로파일 변경 감지: $STORED_PROFILE → $PROFILE"
    echo "프로파일이 바뀌면 거의 모든 파일이 충돌합니다. 전체 재생성을 권장합니다."
    # AskUserQuestion 으로 [전체 재생성 / 취소] 만 제시
    # 응답이 전체 재생성이면 HARNESS_MODE=fresh 로 강등하고 Step 3 진입
  fi
fi
```

### 3-PRE-3. bucket 분류 (stamped 모드)

```bash
if [ "$HARNESS_MODE" = "stamped" ]; then
  UNCHANGED=""
  SAFE_UPDATES=""
  USER_ONLY=""
  CONFLICTS=""
  NEW_FILES=""

  while IFS='|' read -r skey sabs okey oabs; do
    [ -z "$skey" ] && continue
    bucket=$(hs_classify_file "$MANIFEST" "$skey" "$sabs" "$okey" "$oabs")
    case "$bucket" in
      unchanged)   UNCHANGED="$UNCHANGED $okey" ;;
      safe-update) SAFE_UPDATES="$SAFE_UPDATES $okey" ;;
      user-only)   USER_ONLY="$USER_ONLY $okey" ;;
      conflict)    CONFLICTS="$CONFLICTS $okey" ;;
      new)         NEW_FILES="$NEW_FILES $okey" ;;
    esac
  done <<< "$SOURCE_MAP"
fi
```

이 단계가 끝나면 5개 리스트(`UNCHANGED`, `SAFE_UPDATES`, `USER_ONLY`, `CONFLICTS`, `NEW_FILES`)가 채워진다.
다음 단계(3-PRE-4)에서 사용자에게 요약을 보여주고 진행 여부를 묻는다.

### 3-PRE-4. 사용자 확인 1차 (stamped 모드)

요약을 출력하고 `AskUserQuestion` 을 1회 호출한다.

```
=== 하네스 업데이트 미리보기 ===
플러그인:    ehr-harness {{STORED_VERSION}} → {{PLUGIN_VERSION}}
프로파일:    {{PROFILE}}
변경 없음:   {{N_UNCHANGED}} 개
안전 업데이트: {{N_SAFE}} 개
사용자 편집(유지): {{N_USER}} 개
충돌:        {{N_CONFLICT}} 개
새 파일:     {{N_NEW}} 개
================================

[안전 업데이트 목록]
{{SAFE_UPDATES_LIST}}

[충돌 목록]
{{CONFLICTS_LIST}}

[사용자 편집(유지)]
{{USER_ONLY_LIST}}
```

```
질문: "어떻게 진행할까요?"
헤더: "업데이트 모드"
  - 1: "안전 업데이트만 적용 (충돌은 그대로)" — 안전 + 새 파일만 쓴다. 사용자 편집/충돌은 손대지 않음.
  - 2: "안전 업데이트 + 충돌 개별 결정" — 충돌 항목마다 따로 묻는다 (3-PRE-5).
  - 3: "전체 재생성 (모든 파일 덮어쓰기)" — 사용자 편집까지 다 날아감. 위험.
  - 4: "취소" — 아무것도 안 함.
```

선택 결과를 `UPDATE_STRATEGY` 에 저장한다.

### 3-PRE-5. 충돌 항목 개별 결정 (UPDATE_STRATEGY=2 일 때만)

`CONFLICTS` 의 각 파일에 대해 `AskUserQuestion` 을 호출한다.

```
질문: "{{path}} 가 플러그인에서도 바뀌었고 사용자도 편집했습니다. 어떻게 할까요?"
헤더: "충돌 해결"
  - 1: "백업 후 덮어쓰기" — 현재 파일을 <path>.bak.YYYYMMDD-HHMMSS 로 저장한 뒤 새 버전을 쓴다.
  - 2: "그대로 둠" — 사용자 편집을 보존한다. 매니페스트에는 현재 파일의 sha 를 기록.
  - 3: "강제 덮어쓰기 (백업 없음)" — 사용자 편집을 버린다.
```

각 파일의 결정을 `CONFLICT_DECISION[<path>]` 연상배열에 저장한다.

값 종류: `backup` | `keep` | `force`

### 3-PRE-6. 실행 계획 확정

| UPDATE_STRATEGY | 동작 |
|---|---|
| 1 | `safe-update` + `new` 만 Write. `conflict` 는 모두 "그대로 둠" 처리 (`CONFLICT_DECISION` 모두 `keep`). |
| 2 | `safe-update` + `new` 는 Write. `conflict` 는 `CONFLICT_DECISION` 에 따라 분기. |
| 3 | 모든 파일 Write (= fresh 모드와 동일). `HARNESS_MODE=fresh` 로 강등. |
| 4 | 즉시 종료. Step 4 도 4-G 도 실행하지 않음. |

이 단계가 끝나면 `WRITE_LIST` (Write 할 파일들의 output_key 목록, 공백 구분) 와
`SKIP_LIST` (Write 하지 않을 파일들의 목록) 가 확정된다. Step 3 은 이 두 리스트를 기준으로 동작한다.

```bash
# WRITE_LIST 빌드 예시 (UPDATE_STRATEGY=2)
WRITE_LIST=""
for f in $SAFE_UPDATES $NEW_FILES; do
  WRITE_LIST="$WRITE_LIST $f"
done
# UNCHANGED 와 USER_ONLY 는 항상 SKIP
# CONFLICTS 는 CONFLICT_DECISION 으로 분기
for f in $CONFLICTS; do
  case "${CONFLICT_DECISION[$f]:-keep}" in
    backup|force) WRITE_LIST="$WRITE_LIST $f" ;;
    keep) ;;  # SKIP
  esac
done
```

---

## Step AUDIT-REPORT: Drift 계산 + 리포트 (audit 모드 전용)

이 단계는 `HARNESS_MODE=audit` 일 때만 실행한다.

### AUDIT-1. 분석 스냅샷 diff

```bash
# analyze.sh + audit.sh 로드
source "$PLUGIN_ROOT/skills/ehr-harness/lib/analyze.sh"
source "$PLUGIN_ROOT/skills/ehr-harness/lib/audit.sh"

# 저장된 analysis 조회
STORED_ANALYSIS=$(hs_get_analysis "$MANIFEST")
if [ "$STORED_ANALYSIS" = "null" ]; then
  echo "⚠ 저장된 analysis 없음 — baseline 기록 모드로 진행"
  BASELINE_MODE=1
else
  BASELINE_MODE=0
fi

# 새 분석 결과 조립
NEW_ANALYSIS=$(build_analysis_json "$(pwd)" "$PROFILE")

# Drift 계산 (baseline 모드면 빈 drift 반환)
if [ "$BASELINE_MODE" = "1" ]; then
  DRIFT='{"module_map":{"added":[],"removed":[],"changed":[]},"session_vars":{"added":[],"removed":[]},"authSqlID":{"added":[],"removed":[]},"critical_proc_found":{"added":[],"removed":[]},"law_counts":{},"procedure_count":{"changed":false},"trigger_count":{"changed":false}}'
else
  DRIFT=$(compute_drift "$STORED_ANALYSIS" "$NEW_ANALYSIS")
fi

IMPORTANCE=$(drift_importance "$DRIFT")
```

### AUDIT-2. 플러그인 업데이트 bucket (stamped 와 동일)

Step 3-PRE-1~3 을 호출하여 `UNCHANGED`, `SAFE_UPDATES`, `USER_ONLY`, `CONFLICTS`, `NEW_FILES` 를 계산한다.

### AUDIT-3. 통합 리포트 렌더링

```bash
STORED_PV=$(hs_plugin_version "$MANIFEST") # 또는 매니페스트에서 읽기
CURRENT_PV=$(hs_plugin_version "$PLUGIN_ROOT")
SYSTEM_NAME="{{감지된 시스템명}}"  # Step 2-A 등에서 이미 결정됨

REPORT=$(render_audit_report "$DRIFT" "$IMPORTANCE" "$(date -Iseconds)" "$SYSTEM_NAME" "$PROFILE" "$STORED_PV" "$CURRENT_PV")

# 플러그인 bucket 요약을 리포트 앞에 삽입
PLUGIN_SECTION=$(cat <<EOF

## 플러그인 업데이트

- 새 파일: $(echo "$NEW_FILES" | wc -w) 개
- 안전 업데이트: $(echo "$SAFE_UPDATES" | wc -w) 개
- 사용자 편집(유지): $(echo "$USER_ONLY" | wc -w) 개
- 충돌: $(echo "$CONFLICTS" | wc -w) 개
EOF
)
REPORT_FULL="${REPORT}${PLUGIN_SECTION}"

echo "$REPORT_FULL"
```

### AUDIT-4. 사용자 확인 프롬프트

`AskUserQuestion` 도구 사용:

```
질문: "어떻게 진행할까요?"
헤더: "audit 적용"
  - 1: "반자동 적용 (추천)" — safe-update/new 자동, 상급 drift 개별 확인, 충돌은 bucket diff UX
  - 2: "보고서만 저장" — docs/harness-audit-YYYYMMDD.md 저장, 변경 없음
  - 3: "전체 재생성" — 모든 drift/업데이트 일괄 적용 (사용자 편집은 보존)
  - 4: "취소"
```

응답을 `AUDIT_STRATEGY` 에 저장.

### AUDIT-5. 전략별 분기

| AUDIT_STRATEGY | 동작 |
|---|---|
| 1 (반자동) | AUDIT-6 (상급 drift 개별 확인) → 그 후 Step 3 Write + 매니페스트 갱신 |
| 2 (보고서만) | `save_audit_report "$REPORT_FULL" "docs/harness-audit-$(date +%Y%m%d).md"` 후 Step 4 로 바로 이동 (매니페스트의 analyzed_at 만 갱신, 다른 필드 변화 없음) |
| 3 (전체 재생성) | `UPDATE_STRATEGY=3` (stamped 와 동일: 모든 파일 Write) → Step 3 + 매니페스트 갱신 (새 analysis 저장) |
| 4 (취소) | 즉시 종료 |

### AUDIT-6. 상급 drift 개별 확인 (AUDIT_STRATEGY=1 일 때)

`IMPORTANCE.high` 의 각 항목에 대해 `AskUserQuestion`:

```
질문: "{item 설명}을 AGENTS.md 에 반영할까요?"
헤더: "drift 적용"
  - 1: "반영"
  - 2: "건너뜀"
```

각 항목 결정을 `HIGH_DECISIONS[<field>]` 연상배열에 저장한다 (`apply` | `skip`).

**중급/하급은 반자동 적용 (사용자 확인 없음)**.

### AUDIT-7. 최종 확인

```
질문: "다음 변경 적용: new=X개 safe=Y개 drift-applied=Z개 conflict=C개. 진행?"
헤더: "최종 확정"
  - 1: "적용"
  - 2: "취소"
```

---

## Step 3: 파일 생성

> **legacy adopt 가드:** `LEGACY_ADOPT=1` 이면 이 Step 3 전체를 스킵한다.
> 이유: 현재 파일을 그대로 인정하는 모드이므로 Write 작업이 일어나면 안 된다.
> Step 4-G 에서 현재 파일들의 sha 만 매니페스트에 기록한다.
>
> ```bash
> if [ "${LEGACY_ADOPT:-0}" = "1" ]; then
>   echo "· legacy adopt 모드 — Step 3 전체 스킵"
>   # build_source_map 은 Step 3-PRE-1 에서 이미 호출됨
>   # Step 4 로 넘어감
> fi
> ```
>
> **Selective Write 가드 (stamped 모드 전용):**
>
> `HARNESS_MODE=stamped` 일 때, Step 3 의 모든 Write 는 다음 헬퍼를 통과해야 한다.
>
> ```bash
> should_write() {
>   local output_key="$1"
>   # fresh 모드면 무조건 씀
>   if [ "$HARNESS_MODE" = "fresh" ]; then
>     return 0
>   fi
>   # legacy adopt 모드면 안 씀 (Step 3 자체가 스킵되지만 안전망)
>   if [ "${LEGACY_ADOPT:-0}" = "1" ]; then
>     return 1
>   fi
>   # stamped 모드면 WRITE_LIST 검사
>   case " $WRITE_LIST " in
>     *" $output_key "*) return 0 ;;
>     *) return 1 ;;
>   esac
> }
>
> backup_if_needed() {
>   local path="$1"
>   local decision="${CONFLICT_DECISION[$path]:-}"
>   if [ "$decision" = "backup" ] && [ -f "$path" ]; then
>     local stamp
>     stamp=$(date +%Y%m%d-%H%M%S)
>     cp "$path" "$path.bak.$stamp"
>     echo "  · 백업: $path → $path.bak.$stamp"
>   fi
> }
> ```
>
> Step 3 의 모든 Write 블록은 다음 패턴을 따른다:
>
> ```bash
> if should_write ".claude/settings.json"; then
>   backup_if_needed ".claude/settings.json"
>   # Read + Write 본문
> fi
> ```
>
> `should_write` 가 false 를 반환하면 해당 Write 는 통째로 스킵된다.
> 분석 단계(Step 2) 는 항상 수행되며, Write 만 선택적으로 일어난다.
>
> 아래 3-A ~ 3-F 의 모든 Write 는 위 가드 패턴을 적용한다고 가정한다.
> (마크다운 가독성을 위해 각 블록에 일일이 if 문을 풀어 쓰지 않는다.)

### 3-A. 인프라 파일 (shared/ → 프로젝트 루트)

```
Read: $PLUGIN_ROOT/profiles/shared/settings.json
Write: .claude/settings.json

Read: $PLUGIN_ROOT/profiles/shared/hooks/db-read-only.sh
Write: .claude/hooks/db-read-only.sh

Read: $PLUGIN_ROOT/profiles/shared/.codex/config.toml
Write: .codex/config.toml

Read: $PLUGIN_ROOT/profiles/shared/.gitignore
Write: .gitignore (프로젝트에 .gitignore가 이미 있으면 내용 병합)
```

#### 3-B-pre. AGENTS.md 치환값 준비

```bash
# AUTH_MODEL_MD 는 Step 2-M 에서 이미 생성됨.
# DB_VERIFICATION_MD 는 여기서 생성한다.

DB_VERIFICATION_MD=$(DBV="$DB_VERIFICATION_JSON" node -e "
  const m=JSON.parse(process.env.DBV);
  console.log('| 항목 | 값 |');
  console.log('|------|-----|');
  console.log('| DDL 경로 | ' + (m.ddl_path || '_(없음)_') + ' |');
  console.log('| DB 접속 | ' + m.db_access + ' |');
  console.log('| B3 전략 | ' + m.b3_strategy + ' |');
")

DDL_AUTHORING_MD=$(DDL="$DDL_AUTH_JSON" node -e "
  const m=JSON.parse(process.env.DDL);
  console.log('| 항목 | 값 |');
  console.log('|------|-----|');
  console.log('| 활성화 | ' + (m.enabled ? 'true (자동 작성 가능)' : 'false (수동 요청 필요)') + ' |');
  console.log('| 테이블 경로 | ' + (m.table_path || '_(없음)_') + ' |');
  console.log('| 프로시저 경로 | ' + (m.procedure_path || '_(없음)_') + ' |');
  console.log('| 함수 경로 | ' + (m.function_path || '_(없음)_') + ' |');
  console.log('| 명명 규칙 | ' + (m.naming_pattern || '_(없음)_') + ' |');
  console.log('| 헤더 템플릿 | ' + (m.header_template_path || '_(없음)_') + ' |');
  console.log('| 기존 테이블 수 | ' + m.existing_tables.length + '개 |');
")
```

### 3-B. 문서 (skeleton/ + 실측값 → 프로젝트 루트)

```
Read: $PLUGIN_ROOT/profiles/$PROFILE/skeleton/AGENTS.md.skel
치환:
  {{SYSTEM_NAME}} → 감지된 시스템명 (예: "EHR_HR50")
  {{MODULE_MAP}} → Step 2-B 수집 결과 (마크다운 테이블)
  {{SESSION_VARS}} → Step 2-D 수집 결과
  {{CRITICAL_PROC}} → Step 2-G 확인된 치명 프로시저 (마크다운 테이블)
  {{LAW_C_COUNT}} → Step 2-C AuthTableService 카운트
  {{AUTH_MODEL}} → Step 2-M 생성한 AUTH_MODEL_MD (마크다운 테이블)
  {{DB_VERIFICATION}} → Step 2-J-6 결과 + Step 3-B-pre 생성한 DB_VERIFICATION_MD (마크다운 블록)
  {{DDL_AUTHORING}} → Step 3-B-pre 생성한 DDL_AUTHORING_MD (마크다운 테이블)
Write: AGENTS.md
크기 확인: 200줄 초과 시 상세를 스킬로 이동 (권한 모델/DB 검증 섹션이 추가돼 기존보다 길어짐)
```

```
Read: $PLUGIN_ROOT/profiles/$PROFILE/skeleton/CLAUDE.md.skel
치환:
  {{SYSTEM_NAME}} → 시스템명
  {{CRITICAL_PROC_NAMES}} → 치명 프로시저 이름 목록 (콤마 구분)
  {{SUBPACKAGE_MAP}} → Step 2-L 서브패키지 맵 (모듈별 하위 디렉토리+화면수)
  {{DB_PREFIX_MAP}} → Step 2-L DB prefix 맵 (고정값)
Write: CLAUDE.md
```

```
Read: $PLUGIN_ROOT/profiles/$PROFILE/skeleton/README.md.skel
치환:
  {{SYSTEM_NAME}} → 시스템명
  {{MODULE_MAP}} → 모듈 맵
  {{GENERATED_DATE}} → 오늘 날짜
Write: README.md
```

### 3-C. 스킬 (skills/ + 실측값 → .claude/skills/)

```
# ehr-domain-knowledge — 고정 복사 (프로파일 고유 EHR DNA)
Read: $PLUGIN_ROOT/profiles/$PROFILE/skills/domain-knowledge/SKILL.md
Write: .claude/skills/ehr-domain-knowledge/SKILL.md
※ 수치만 업데이트: 법칙별 JSP 수, 컴포넌트 참조 수를 실측값으로 교체
```

```
# ehr-screen-builder — 스켈레톤 + 코드 예시
Read: $PLUGIN_ROOT/profiles/$PROFILE/skills/screen-builder/SKILL.md.skel
치환:
  {{CODE_EXAMPLES}} → Step 2-I 추출 패턴
  grep 경로를 프로젝트 실제 경로로 교체
Write: .claude/skills/ehr-screen-builder/SKILL.md
```

```
# ehr-codebase-navigator — 스켈레톤 + 모듈 맵
Read: $PLUGIN_ROOT/profiles/$PROFILE/skills/codebase-navigator/SKILL.md.skel
치환:
  {{MODULE_MAP}} → Step 2-B 수집 결과 (키워드 포함)
  {{COMPONENT_REFS}} → Step 2-F 참조 수
Write: .claude/skills/ehr-codebase-navigator/SKILL.md
```

```
# ehr-procedure-tracer — 스켈레톤 + 프로시저/트리거 목록
Read: $PLUGIN_ROOT/profiles/$PROFILE/skills/procedure-tracer/SKILL.md.skel
치환:
  {{PROC_LIST}} → Step 2-H 전체 프로시저 목록
  {{TRIGGER_LIST}} → Step 2-H 전체 트리거 목록 (또는 DB 미연결 경고)
  {{CRITICAL_PROC}} → Step 2-G 치명 레지스트리
Write: .claude/skills/ehr-procedure-tracer/SKILL.md
```

```
# ehr-db-query — 스켈레톤 + DB 접속 정보
Read: $PLUGIN_ROOT/profiles/$PROFILE/skills/db-query/SKILL.md.skel
치환:
  {{DB_CONNECTION}} → Step 2-J 탐지 결과 (또는 미발견 경고)
Write: .claude/skills/ehr-db-query/SKILL.md
```

### 3-D. 에이전트 (agents/ → .claude/agents/)

```
# 에이전트는 대부분 고정. 치명 목록만 주입.
Read: $PLUGIN_ROOT/profiles/$PROFILE/agents/screen-builder.md
Write: .claude/agents/screen-builder.md

Read: $PLUGIN_ROOT/profiles/$PROFILE/agents/procedure-tracer.md
Write: .claude/agents/procedure-tracer.md

# EHR4/EHR5 공통 — release-reviewer (EHR5도 신규 추가됨, 조건 분기 제거)
Read: $PLUGIN_ROOT/profiles/$PROFILE/agents/release-reviewer.md
Write: .claude/agents/release-reviewer.md
```

### 3-E. Codex/Gemini 호환

```
# .agents/skills/ ← .claude/skills/ 전체 복사
SKILLS_TO_COPY="ehr-screen-builder ehr-codebase-navigator ehr-procedure-tracer ehr-db-query ehr-domain-knowledge"
# 디자인 가이드 스킬이 생성됐다면 함께 복사
if [ "$DESIGN_GUIDE" = "true" ]; then
  SKILLS_TO_COPY="$SKILLS_TO_COPY ehr-design-guide"
fi
for skill in $SKILLS_TO_COPY; do
  Read: .claude/skills/$skill/SKILL.md
  Write: .agents/skills/$skill/SKILL.md
done
```

```
# GEMINI.md 생성 (Heavy: 모든 스킬 @참조)
Write: GEMINI.md
내용:
@./AGENTS.md
@./.agents/skills/ehr-domain-knowledge/SKILL.md
@./.agents/skills/ehr-codebase-navigator/SKILL.md
@./.agents/skills/ehr-screen-builder/SKILL.md
@./.agents/skills/ehr-procedure-tracer/SKILL.md
@./.agents/skills/ehr-db-query/SKILL.md
# 디자인 가이드 있으면 추가
if [ "$DESIGN_GUIDE" = "true" ]; then
  추가 라인: @./.agents/skills/ehr-design-guide/SKILL.md
fi
```

### 3-F. 디자인 가이드 스킬 생성 (조건부)

`DESIGN_GUIDE=false`면 이 단계 전체 스킵.
`SKIP_DESIGN_GUIDE=true`(증분 갱신, Step 2-K 참고)면 이 단계 스킵.

#### 3-F-1. SKILL.md 생성 (skel 치환)

```
Read: $PLUGIN_ROOT/profiles/$PROFILE/skills/design-guide/SKILL.md.skel
치환:
  {{STORYBOOK_PATH}}     → $SB_PATH
  {{STORYBOOK_VERSION}}  → $SB_VERSION
  {{TOTAL_TITLES}}       → 46 (또는 실측)
  {{PRE_EXTRACT_LIST}}   → "00-Introduction, 01-Naming-Rules, 02-Legacy-JSP-Migration, 03-Quick-Reference, Button, Chip, FormSelect, FormSelect2, Table, Text"
Write: .claude/skills/ehr-design-guide/SKILL.md
```

#### 3-F-2. INDEX.md 생성 (46개 카탈로그)

`/tmp/sb_titles.json`을 카테고리별로 정리한 마크다운 테이블로 출력.

```markdown
# IDS Design System — 컴포넌트 카탈로그

## 00-guides/ (디자인 시스템 가이드)

| 이름 | ID | JS 파일 |
|---|---|---|
| Introduction | 00-guides-00-introduction--docs | assets/00-Introduction-*.js |
| Naming-Rules | 00-guides-01-naming-rules--docs | assets/01-Naming-Rules-*.js |
| ... | | |

## 01-atoms/

...

## 02-modules/

...

## 03-pages/

...

## 04-utilities/

...

## 05-modal/

...
```

```
Write: .claude/skills/ehr-design-guide/references/INDEX.md
```

#### 3-F-3. MANIFEST.json 생성

```bash
node -e "
  const manifest = {
    schema_version: 1,
    storybook_path: '$SB_PATH',
    generated_at: $SB_GENERATED_AT,
    storybook_version: '$SB_VERSION',
    extracted_at: new Date().toISOString(),
    pre_extracted: [
      '00-Introduction', '01-Naming-Rules', '02-Legacy-JSP-Migration',
      '03-Quick-Reference', 'Button', 'Chip', 'FormSelect',
      'FormSelect2', 'Table', 'Text'
    ],
    title_to_js: <TITLE_TO_JS 매핑 객체>
  };
  require('fs').writeFileSync(
    '.claude/skills/ehr-design-guide/MANIFEST.json',
    JSON.stringify(manifest, null, 2)
  );
"
```

#### 3-F-4. 핵심 10개 사전 추출 (Claude inline)

각 컴포넌트마다 다음을 수행:

```
Read: $SB_PATH/<JS 파일 경로>
→ JSX 함수 호출 패턴(n.jsx/n.jsxs)을 마크다운으로 변환
  (변환 규칙은 design-guide SKILL.md의 "JSX → Markdown 변환 규칙" 섹션 참고)
Write: .claude/skills/ehr-design-guide/references/<name>.md
```

추출 대상:

| 대상 | JS 파일 (예시) |
|---|---|
| 00-Introduction | assets/00-Introduction-*.js |
| 01-Naming-Rules | assets/01-Naming-Rules-*.js |
| 02-Legacy-JSP-Migration | assets/02-Legacy-JSP-Migration-*.js |
| 03-Quick-Reference | assets/03-Quick Reference-*.js |
| Button | assets/Button-*.js |
| Chip | assets/Chip-*.js |
| FormSelect | assets/FormSelect-*.js (또는 Select 계열) |
| FormSelect2 | assets/Select2-*.js |
| Table | assets/Table-*.js |
| Text | assets/Text-*.js |

> **주의**: 빌드 해시(`-BYnc9ous` 등)는 빌드마다 바뀌므로 `assets/Button-*.js`
> 같은 glob 패턴으로 파일을 찾는다. 같은 이름의 JS가 여러 개면 가장 최신
> mtime의 파일을 선택한다.

> **추출 방식**: 별도 파서 스크립트를 만들지 **않는다**. Claude가 직접
> JS 파일을 Read 도구로 읽고, 패턴 인식으로 마크다운 변환을 수행한다.
> 이유: 정규식은 중첩/한글/이스케이프 처리가 불안정하고, LLM이 패턴
> 인식만으로 더 안정적으로 처리한다.

---

## Step 4: 검증

### 4-A. 파일 수 확인

```bash
echo "=== 생성 파일 목록 ==="
ls -la AGENTS.md CLAUDE.md GEMINI.md README.md .gitignore
ls -la .claude/settings.json
ls -la .claude/hooks/db-read-only.sh
ls -la .claude/agents/*.md
ls -la .claude/skills/*/SKILL.md
ls -la .agents/skills/*/SKILL.md
ls -la .codex/config.toml
echo "=== 총 파일 수 ==="
find .claude .agents .codex -type f | wc -l
```

### 4-B. 모듈 맵 교차 확인

```
AGENTS.md의 모듈 목록 vs 실제 디렉토리 목록 비교.
불일치 시 경고 출력.
```

### 4-C. 치명 요소 보고

```
치명 프로시저: X/6개 확인
  OK: P_CPN_CAL_PAY_MAIN, P_HRI_AFTER_PROC_EXEC, ...
  NOT_FOUND: P_TIM_VACATION_CLEAN — 확인 필요

치명 트리거: X/2개 확인
  OK: TRG_HRI_103
  NOT_FOUND: TRG_TIM_405 — 확인 필요
```

### 4-D. DB 모드 상태

Step 2-J 결과에 따라 다르게 보고:

```
DB_MODE=direct (DB 연결 성공):
  "✓ DB 연결 성공. 총 287개 프로시저, 45개 트리거 등록."

DB_MODE=dump (덤프 폴더 사용):
  "✓ DUMP 모드 활성화
   덤프 폴더: C:/EHR_PROJECT/db_dump/
   형태: F2 (서브폴더별)
   총 파일: 487개 (테이블 234, 프로시저 156, 패키지 12, 함수 45, 트리거 40)
   procedure-tracer / db-query 스킬이 이 폴더를 참조합니다."

DB_MODE=code-only:
  "⚠ 코드 grep 모드
   프로시저/트리거 내부 로직은 확인할 수 없습니다.
   DB 연결 또는 DDL 덤프 폴더가 확보되면 /ehr-harness 다시 실행하여 갱신하세요."
```

### 4-E. 디자인 가이드 상태

```
DESIGN_GUIDE=true (새로 생성):
  "✓ ehr-design-guide 스킬 생성 완료
   Storybook: {{SB_PATH}}
   버전: {{SB_VERSION}}
   사전 추출: 10개 (00-guides 4 + atoms 6)
   JIT 대상: 36개 (modules/layouts/utilities/modal)
   screen-builder가 화면 생성 시 자동 참조합니다."

DESIGN_GUIDE=true + SKIP_DESIGN_GUIDE=true (재실행 시 변경 없음):
  "· 디자인 가이드 변경 없음 (generated_at 일치) → 재추출 스킵"

DESIGN_GUIDE=false:
  "· Storybook 미발견 (src/main/resources/static/guide/storybook-static/ 없음)
   → ehr-design-guide 스킬은 생성되지 않았습니다."
```

### 4-F. 최종 보고

**모드 표시:** 아래 보고의 첫 줄에 다음을 출력한다.

```
HARNESS_MODE: {{HARNESS_MODE}}
```

- `fresh` → "신규 생성"
- `legacy` (adopt 선택) → "기존 하네스 인정 (스탬프만 부여)"
- `stamped` → "업데이트"

**stamped 모드의 변경 요약:** `HARNESS_MODE=stamped` 일 때만 Step 3 결과를 추가로 보고한다.

```
적용 결과:
  안전 업데이트: {{N_SAFE_APPLIED}} 개
  새 파일:       {{N_NEW_APPLIED}} 개
  충돌 해결:
    - 백업 후 덮어쓰기: {{N_CONF_BACKUP}} 개
    - 그대로 둠:        {{N_CONF_KEEP}} 개
    - 강제 덮어쓰기:    {{N_CONF_FORCE}} 개
  사용자 편집(유지): {{N_USER_ONLY}} 개
  변경 없음:        {{N_UNCHANGED}} 개
```

각 카운터는 Step 3-PRE-4/5/6 에서 결정된 후 Step 3 실행 중에 누적해서 갱신한다.

```markdown
## 하네스 생성 완료

| 항목 | 값 |
|------|-----|
| 모드 | {{HARNESS_MODE}} |
| EHR 버전 | {{PROFILE}} |
| 시스템명 | {{SYSTEM_NAME}} |
| 모듈 수 | X개 |
| 스킬 | 5~6개 (디자인 가이드 존재 시 6) |
| 에이전트 | 2~3개 |
| 프로시저 | X개 등록 |
| 트리거 | X개 등록 |
| 치명 프로시저 | X/6개 확인 |
| DB 모드 | direct/dump/code-only |
| 디자인 가이드 | 생성됨 / 변경 없음 / 미발견 |
| 플러그인 버전 | {{PLUGIN_VERSION}} |

### 사용 시작
- 화면 생성: "휴가 신청 화면 만들어줘"
- 프로시저 분석: "P_CPN_CAL_PAY_MAIN 분석해줘"
- 코드 탐색: "인사 마스터 컨트롤러 어디에 있어?"
- DB 조회: "THRM100 테이블 구조 알려줘"
- IDS 컴포넌트: "Button 어떻게 써?" (디자인 가이드 있을 때만)

### 주의사항
- DB_MODE=code-only 시, 프로시저/트리거 내부 로직은 확인 불가
- DB_MODE=dump 시, 덤프 버전과 운영 DB가 다를 수 있음
- NOT_FOUND 치명 요소는 수동 확인이 필요
- Storybook이 재빌드되면 `/ehr-harness` 다시 실행해서 디자인 가이드 갱신 권장
- 플러그인이 갱신되면 `/ehr-harness` 다시 실행해서 변경분 반영 (3-bucket diff 가 자동으로 안전한 항목만 덮어씀)
```

### 4-G. HARNESS.json 갱신 (모든 모드에서 마지막으로 수행)

```bash
source "$PLUGIN_ROOT/skills/ehr-harness/lib/harness-state.sh"

# (a) 소스 매니페스트 — Step 3-PRE-1 에서 채운 SOURCE_MAP 을 그대로 사용
# SOURCE_MAP 은 "source_key|source_abs|output_key|output_abs" 한 줄/항목
SOURCES_JSON='{'
OUTPUTS_JSON='{'
first_s=1; first_o=1
while IFS='|' read -r skey sabs okey oabs; do
  [ -z "$skey" ] && continue
  src_sha=$(hs_sha256 "$sabs")
  out_sha=$(hs_sha256 "$oabs")
  if [ -n "$src_sha" ]; then
    if [ $first_s -eq 0 ]; then SOURCES_JSON="$SOURCES_JSON,"; fi
    SOURCES_JSON="$SOURCES_JSON\"$skey\":\"$src_sha\""
    first_s=0
  fi
  if [ -n "$out_sha" ]; then
    if [ $first_o -eq 0 ]; then OUTPUTS_JSON="$OUTPUTS_JSON,"; fi
    OUTPUTS_JSON="$OUTPUTS_JSON\"$okey\":\"$out_sha\""
    first_o=0
  fi
done <<< "$SOURCE_MAP"
SOURCES_JSON="$SOURCES_JSON}"
OUTPUTS_JSON="$OUTPUTS_JSON}"

PLUGIN_VERSION=$(hs_plugin_version "$PLUGIN_ROOT")

# legacy adopt 모드면 generated_at 을 지금 시각으로 새로 부여
# fresh 모드면 generated_at 도 지금 시각
# stamped 모드면 기존 generated_at 을 보존
GEN_AT=""
if [ "$HARNESS_MODE" = "stamped" ] && [ -f "$MANIFEST" ]; then
  GEN_AT=$(hs_get_generated_at "$MANIFEST")
fi
if [ -z "$GEN_AT" ]; then
  GEN_AT=$(date -Iseconds 2>/dev/null || date +%Y-%m-%dT%H:%M:%S%z)
fi

hs_write_manifest "$MANIFEST" "$PLUGIN_VERSION" "$PROFILE" "$SOURCES_JSON" "$OUTPUTS_JSON" "$GEN_AT" "$AUTH_MODEL_JSON" "$DB_VERIFICATION_JSON" "$DDL_AUTH_JSON" "$ANALYSIS_JSON"

echo "✓ HARNESS.json 갱신: plugin_version=$PLUGIN_VERSION, profile=$PROFILE"
```

→ 이 단계는 모든 모드(fresh / legacy adopt / stamped 업데이트)의 마지막에 무조건 한 번 실행된다.
→ legacy adopt 모드의 경우, Step 3 의 Write 를 모두 스킵했지만, 현재 디스크의 파일 sha 를 기준으로 outputs 를 채우므로 "현 상태 인정" 이 정확히 표현된다.
→ `UPDATE_STRATEGY=4` (취소) 일 때는 Step 4 자체가 실행되지 않으므로 매니페스트도 변하지 않는다.

---

## 참고: 수동 실행 가이드

메타 스킬이 아닌 수동으로 하네스를 생성하려면:

1. `$PLUGIN_ROOT/profiles/shared/` 파일을 프로젝트에 복사
2. `$PLUGIN_ROOT/profiles/{ehr4|ehr5}/` 파일을 프로젝트에 복사
3. `.skel` 파일의 `{{변수}}` 를 수동으로 치환
4. `.agents/skills/` 에 `.claude/skills/` 복사
5. `GEMINI.md` 생성
