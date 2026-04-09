---
name: ehr-harness
description: "EHR 프로젝트 하네스 자동 생성 메타 스킬. '하네스 만들어줘', '하네스 생성해줘', '하네스 설계해줘', '하네스 구성해줘', '하네스 구축해줘', '하네스 업데이트', '하네스 재생성', '하네스 수정', '하네스 갱신', '이수하네스', 'ehr하네스', 'EHR하네스', 'e-hr하네스', 'E-HR하네스', '인사시스템 하네스', '인사하네스' 등의 키워드에 트리거."
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
→ 설치됨 확인 후 Step 1로 진입.

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

## Step 3: 파일 생성

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

### 3-B. 문서 (skeleton/ + 실측값 → 프로젝트 루트)

```
Read: $PLUGIN_ROOT/profiles/$PROFILE/skeleton/AGENTS.md.skel
치환:
  {{SYSTEM_NAME}} → 감지된 시스템명 (예: "EHR_HR50")
  {{MODULE_MAP}} → Step 2-B 수집 결과 (마크다운 테이블)
  {{SESSION_VARS}} → Step 2-D 수집 결과
  {{CRITICAL_PROC}} → Step 2-G 확인된 치명 프로시저 (마크다운 테이블)
  {{LAW_C_COUNT}} → Step 2-C AuthTableService 카운트
Write: AGENTS.md
크기 확인: 150줄 초과 시 상세를 스킬로 이동
```

```
Read: $PLUGIN_ROOT/profiles/$PROFILE/skeleton/CLAUDE.md.skel
치환:
  {{SYSTEM_NAME}} → 시스템명
  {{CRITICAL_PROC_NAMES}} → 치명 프로시저 이름 목록 (콤마 구분)
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

# EHR4 전용
if [ "$PROFILE" = "ehr4" ]; then
  Read: $PLUGIN_ROOT/profiles/$PROFILE/agents/release-reviewer.md
  Write: .claude/agents/release-reviewer.md
fi
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

```markdown
## 하네스 생성 완료

| 항목 | 값 |
|------|-----|
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
```

---

## 참고: 수동 실행 가이드

메타 스킬이 아닌 수동으로 하네스를 생성하려면:

1. `$PLUGIN_ROOT/profiles/shared/` 파일을 프로젝트에 복사
2. `$PLUGIN_ROOT/profiles/{ehr4|ehr5}/` 파일을 프로젝트에 복사
3. `.skel` 파일의 `{{변수}}` 를 수동으로 치환
4. `.agents/skills/` 에 `.claude/skills/` 복사
5. `GEMINI.md` 생성
