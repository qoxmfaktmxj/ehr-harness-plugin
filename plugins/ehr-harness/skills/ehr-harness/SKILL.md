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

### 2-G. 치명 프로시저/트리거 존재 확인

```bash
# 매퍼 확장자 결정
if [ "$PROFILE" = "ehr5" ]; then
  MAPPER_EXT="*-sql-query.xml"
else
  MAPPER_EXT="*-mapping-query.xml"
fi

# 치명 프로시저 확인
for proc in P_CPN_CAL_PAY_MAIN P_HRM_POST P_TIM_WORK_HOUR_CHG \
            P_HRI_AFTER_PROC_EXEC P_TIM_VACATION_CLEAN; do
  found=$(grep -rl "$proc" --include="$MAPPER_EXT" . 2>/dev/null | head -1)
  if [ -n "$found" ]; then
    echo "OK $proc → $found"
  else
    echo "NOT_FOUND $proc"
  fi
done

# 치명 패키지
grep -rl "PKG_CPN_SEP" --include="$MAPPER_EXT" . 2>/dev/null | head -1

# 치명 트리거
for trg in TRG_HRI_103 TRG_TIM_405; do
  found=$(grep -rl "$trg" --include="*.java" --include="*.xml" --include="*.jsp" . 2>/dev/null | head -1)
  if [ -n "$found" ]; then
    echo "OK $trg → $found"
  else
    echo "NOT_FOUND $trg"
  fi
done
```

→ 존재 확인된 것만 `CRITICAL_PROC` 레지스트리에 등록.
→ NOT_FOUND는 경고 목록에 추가.

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

### 2-J. DB 접속 정보 탐지

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

→ 연결 정보 발견 → `DB_CONNECTION`에 저장
→ 미발견 → "⚠ DB 접속 정보 미발견. db-query 스킬의 접속 정보 섹션을 수동 입력하세요."

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
# domain-knowledge — 고정 복사 (프로파일 고유 EHR DNA)
Read: $PLUGIN_ROOT/profiles/$PROFILE/skills/domain-knowledge/SKILL.md
Write: .claude/skills/domain-knowledge/SKILL.md
※ 수치만 업데이트: 법칙별 JSP 수, 컴포넌트 참조 수를 실측값으로 교체
```

```
# screen-builder — 스켈레톤 + 코드 예시
Read: $PLUGIN_ROOT/profiles/$PROFILE/skills/screen-builder/SKILL.md.skel
치환:
  {{CODE_EXAMPLES}} → Step 2-I 추출 패턴
  grep 경로를 프로젝트 실제 경로로 교체
Write: .claude/skills/screen-builder/SKILL.md
```

```
# codebase-navigator — 스켈레톤 + 모듈 맵
Read: $PLUGIN_ROOT/profiles/$PROFILE/skills/codebase-navigator/SKILL.md.skel
치환:
  {{MODULE_MAP}} → Step 2-B 수집 결과 (키워드 포함)
  {{COMPONENT_REFS}} → Step 2-F 참조 수
Write: .claude/skills/codebase-navigator/SKILL.md
```

```
# procedure-tracer — 스켈레톤 + 프로시저/트리거 목록
Read: $PLUGIN_ROOT/profiles/$PROFILE/skills/procedure-tracer/SKILL.md.skel
치환:
  {{PROC_LIST}} → Step 2-H 전체 프로시저 목록
  {{TRIGGER_LIST}} → Step 2-H 전체 트리거 목록 (또는 DB 미연결 경고)
  {{CRITICAL_PROC}} → Step 2-G 치명 레지스트리
Write: .claude/skills/procedure-tracer/SKILL.md
```

```
# db-query — 스켈레톤 + DB 접속 정보
Read: $PLUGIN_ROOT/profiles/$PROFILE/skills/db-query/SKILL.md.skel
치환:
  {{DB_CONNECTION}} → Step 2-J 탐지 결과 (또는 미발견 경고)
Write: .claude/skills/db-query/SKILL.md
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
for skill in screen-builder codebase-navigator procedure-tracer db-query domain-knowledge; do
  Read: .claude/skills/$skill/SKILL.md
  Write: .agents/skills/$skill/SKILL.md
done
```

```
# GEMINI.md 생성 (Heavy: 모든 스킬 @참조)
Write: GEMINI.md
내용:
@./AGENTS.md
@./.agents/skills/domain-knowledge/SKILL.md
@./.agents/skills/codebase-navigator/SKILL.md
@./.agents/skills/screen-builder/SKILL.md
@./.agents/skills/procedure-tracer/SKILL.md
@./.agents/skills/db-query/SKILL.md
```

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

### 4-D. DB 연결 상태

```
DB 연결 성공 시:
  "DB 연결 성공. 총 287개 프로시저, 45개 트리거 등록."

DB 연결 불가 시:
  "⚠ DB 연결 불가. 코드 기반 프로시저 목록만 등록됨.
   DB 연결 후 다음 명령으로 전체 목록을 갱신하세요:
   db-query 스킬 → SELECT OBJECT_NAME, OBJECT_TYPE FROM USER_OBJECTS
   WHERE OBJECT_TYPE IN ('PROCEDURE','TRIGGER','PACKAGE','FUNCTION')"
```

### 4-E. 최종 보고

```markdown
## 하네스 생성 완료

| 항목 | 값 |
|------|-----|
| EHR 버전 | {{PROFILE}} |
| 시스템명 | {{SYSTEM_NAME}} |
| 모듈 수 | X개 |
| 스킬 | 5개 |
| 에이전트 | 2~3개 |
| 프로시저 | X개 등록 |
| 트리거 | X개 등록 |
| 치명 프로시저 | X/6개 확인 |
| DB 연결 | 성공/불가 |

### 사용 시작
- 화면 생성: "휴가 신청 화면 만들어줘"
- 프로시저 분석: "P_CPN_CAL_PAY_MAIN 분석해줘"
- 코드 탐색: "인사 마스터 컨트롤러 어디에 있어?"
- DB 조회: "THRM100 테이블 구조 알려줘"

### 주의사항
- DB 연결 불가 시, 프로시저/트리거 목록이 불완전합니다
- NOT_FOUND 치명 요소는 수동 확인이 필요합니다
```

---

## 참고: 수동 실행 가이드

메타 스킬이 아닌 수동으로 하네스를 생성하려면:

1. `$PLUGIN_ROOT/profiles/shared/` 파일을 프로젝트에 복사
2. `$PLUGIN_ROOT/profiles/{ehr4|ehr5}/` 파일을 프로젝트에 복사
3. `.skel` 파일의 `{{변수}}` 를 수동으로 치환
4. `.agents/skills/` 에 `.claude/skills/` 복사
5. `GEMINI.md` 생성
