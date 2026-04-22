---
name: ehr-domain-knowledge
description: "EHR4 도메인 지식 레퍼런스. 4축 권한 모델, 법칙 A/B/C/D 판정, 화면 패턴 카탈로그(Family A~F), B1~B7 경계 검증, APPL_STATUS_CD 상태 권한, IBSheet 계약, 재구현 금지 컴포넌트, 배치 저장 규칙, Anyframe Velocity 문법."
---

# EHR4 도메인 지식 레퍼런스

화면 생성·수정 전에 이 문서의 관련 섹션을 반드시 확인한다.
screen-builder 에이전트는 구현 전 권한 법칙 판정(§2)과 패턴 분류(§3)를 선행한다.

---

## §1. 4축 권한 모델

모든 SELECT/UPDATE/DELETE 쿼리에 회사 격리(`:ssnEnterCd`)는 **필수**이다.

| 축 | 세션 변수 | 의미 | 필수 여부 |
|----|-----------|------|-----------|
| 회사 | `ssnEnterCd` | 회사(사업장) 코드. 모든 쿼리 WHERE절 필수 | **필수 (예외 없음)** |
| 사원 | `ssnSabun` | 로그인 사번. 본인 데이터 필터 | 화면별 |
| 범위 | `ssnSearchType` | 조회 범위: `O`=조직, `P`=개인, `A`=전체 | 권한 쿼리 사용 시 |
| 역할 | `ssnGrpCd` | 역할 그룹 코드. 부서/직급별 접근 제어 | 권한 쿼리 사용 시 |

### ssnSearchType 분기 규칙

```
O (조직) → 로그인 사용자의 부서 + 하위 부서 데이터만
P (개인) → 본인 데이터만 (ssnSabun 기준)
A (전체) → 회사 전체 (관리자용)
```

- `searchEmpType == "P"` → ssnSearchType을 `P`로 강제 오버라이드
- `searchEmpType == "T"` → ssnSearchType을 `A`로 강제 오버라이드 + `ssnGrpCd = "10"`
- 법칙 B/C 화면에서 `ssnSearchType`은 `F_COM_GET_SQL_AUTH`에 전달되어 동적 WHERE 생성

### Controller 세션 주입 패턴

```java
paramMap.put("ssnEnterCd",    session.getAttribute("ssnEnterCd"));
paramMap.put("ssnSabun",      session.getAttribute("ssnSabun"));
paramMap.put("ssnSearchType", session.getAttribute("ssnSearchType"));
paramMap.put("ssnGrpCd",      session.getAttribute("ssnGrpCd"));
```

---

## §2. 권한 법칙 판정

### F_COM_GET_SQL_AUTH 시그니처

```sql
F_COM_GET_SQL_AUTH(
  enterCd    VARCHAR2,   -- ssnEnterCd
  authSqlID  VARCHAR2,   -- 권한 쿼리 식별자 (예: 'THRM151', 'TORG101')
  searchType VARCHAR2,   -- ssnSearchType (O/P/A)
  sabun      VARCHAR2,   -- ssnSabun
  grpCd      VARCHAR2,   -- NVL(searchGrpCd, ssnGrpCd)
  extra      VARCHAR2    -- 추가 파라미터 (보통 '')
) RETURN VARCHAR2
-- 반환값: "SELECT ... FROM ..." 서브쿼리 문자열
```

실제 호출 (AuthTable-mapping-query.xml):
```xml
<query id="getAuthQuery" isDynamic="true">
  <statement>
    SELECT '(' || F_COM_GET_SQL_AUTH(
      :ssnEnterCd, :authSqlID, :ssnSearchType,
      :ssnSabun, NVL(:searchGrpCd, :ssnGrpCd), ''
    ) || ')' AS query FROM dual
  </statement>
</query>
```

**확인된 authSqlID 값**: `THRM151` (인사 마스터 범위), `TORG101` (조직 범위)

### 4가지 법칙

#### 법칙 A — 전용 Controller + 직접 WHERE

Controller에서 세션 변수를 `paramMap`에 주입하고, 매퍼에서 Anyframe `:key` 바인딩으로 직접 필터링.

```java
// Controller
paramMap.put("ssnEnterCd", session.getAttribute("ssnEnterCd"));
paramMap.put("ssnSabun",   session.getAttribute("ssnSabun"));
```
```xml
<!-- Mapper (Velocity :key 바인딩) -->
WHERE A.ENTER_CD = :ssnEnterCd
  AND A.SABUN    = :ssnSabun
```

- AuthTableService 미사용
- `$query` / `${query}` 미사용
- `:ssnEnterCd` WHERE는 반드시 존재

#### 법칙 B — 공통 Controller + F_COM_GET_SQL_AUTH + $query

GetDataListController/SaveDataController가 자동으로 `AuthTableService.getAuthQueryMap()` 호출.
결과가 `$query` 또는 `${query}`로 Velocity 매퍼에 주입된다.

```java
// GetDataListController 내부 (재구현 금지)
paramMap.put("authSqlID", "THRM151");
Map<?, ?> authMap = authTableService.getAuthQueryMap(paramMap);
paramMap.put("query", authMap.get("query"));
```

매퍼에서 `$query` 3가지 패턴 (Velocity 문법):
```xml
<!-- 패턴 1: INNER JOIN -->
INNER JOIN ($query) AUTH ON A.ENTER_CD = AUTH.ENTER_CD AND A.SABUN = AUTH.SABUN

<!-- 패턴 2: IN 서브쿼리 -->
AND (A.ENTER_CD, A.SABUN) IN ($query)

<!-- 패턴 3: FROM 절 -->
FROM ($query) AUTH, THRM100 A WHERE AUTH.SABUN = A.SABUN
```

- GetDataList.do / SaveData.do URL 사용
- authSqlID JSP 파라미터 필수
- **152개 JSP**가 이 법칙 사용

#### 법칙 C — 하이브리드 (전용 Controller + AuthTableService)

전용 Controller이면서 AuthTableService를 `@Autowired`로 주입받아 `$query`를 생성하는 패턴.

```java
@Controller
@RequestMapping("/HrmStaMgr.do")
public class HrmStaMgrController {

    @Autowired
    private AuthTableService authTableService;

    @Autowired
    private HrmStaMgrService hrmStaMgrService;

    @RequestMapping(params="cmd=getHrmStaList")
    public ModelAndView getHrmStaList(
            HttpSession session, HttpServletRequest request,
            @RequestParam Map<String, Object> paramMap) throws Exception {

        paramMap.put("ssnEnterCd",    session.getAttribute("ssnEnterCd"));
        paramMap.put("ssnSabun",      session.getAttribute("ssnSabun"));
        paramMap.put("ssnSearchType", session.getAttribute("ssnSearchType"));
        paramMap.put("authSqlID",     "THRM151");

        Map<?, ?> authMap = authTableService.getAuthQueryMap(paramMap);
        paramMap.put("query", authMap.get("query"));

        List<?> list = hrmStaMgrService.getHrmStaList(paramMap);
        // ...
    }
}
```

매퍼에서 `$query` 사용 (Velocity 문법):
```xml
<query id="getHrmStaList" isDynamic="true">
  <statement>
    SELECT A.SABUN, A.EMP_NM
      FROM THRM100 A
     INNER JOIN ($query) AUTH
        ON AUTH.ENTER_CD = A.ENTER_CD AND AUTH.SABUN = A.SABUN
     WHERE A.ENTER_CD = :ssnEnterCd
  </statement>
</query>
```

3-축 판별 기준:
- **(a) JSP URL 타겟**: 전용 `.do` (GetDataList.do/SaveData.do 아님)
- **(b) AuthTableService 주입**: `@Autowired("AuthTableService")` 존재
- **(c) $query 사용**: 매퍼에 `$query` 또는 `${query}` 존재

세 조건 모두 충족 → 법칙 C.

#### 법칙 D — 프로시저 직접 호출 (ExecPrc.do)

프론트에서 ExecPrc.do로 직접 프로시저를 호출. 권한은 프로시저 내부에서 처리.

```xml
<!-- Mapper: statementType="CALLABLE" 에 해당하는 Anyframe 방식 -->
<query id="execSepDcPay" isDynamic="true">
  <statement>
    {CALL P_CPN_SEP_DC_PAY(
      :sqlCode,
      :sqlErrm,
      :ssnEnterCd,
      :ssnSabun,
      :yearMonth
    )}
  </statement>
  <result>
    <result-mapping column="sqlCode"  name="sqlCode"/>
    <result-mapping column="sqlErrm"  name="sqlErrm"/>
  </result>
</query>
```

- **ProDao** 사용 (Dao 아님 — 혼동 주의)
  - `proDao.excute("execXxx", paramMap)` 호출
- **13개 JSP**가 이 법칙 사용
- 치명 프로시저(P_CPN_CAL_PAY_MAIN 등)는 이 법칙으로 호출됨
- OUT 파라미터: `sqlCode`, `sqlErrm`

### 법칙 판정 흐름

```
1. JSP URL이 GetDataList.do / SaveData.do인가?
   → YES: 법칙 B
   → NO: 2번으로

2. Controller가 AuthTableService를 @Autowired하는가?
   → YES: 법칙 C (하이브리드)
   → NO: 3번으로

3. ExecPrc.do를 사용하는가?
   → YES: 법칙 D
   → NO: 법칙 A (전용 Controller, 직접 WHERE)
```

### 법칙별 체크리스트

| 항목 | A | B | C | D |
|------|---|---|---|---|
| `:ssnEnterCd` WHERE 필수 | O | O ($query 포함) | O ($query 포함) | O (프로시저 IN 파라미터) |
| AuthTableService 주입 | X | 공통 Controller 내부 | **O** | X |
| authSqlID 설정 | X | O (JSP 파라미터) | O (Controller 내부) | X |
| `$query` 매퍼 사용 | X | O | O | X |
| ProDao 사용 | X | X | X | **O** |
| 매퍼 `:key` 바인딩 | O | O | O | O |

---

## §3. 화면 패턴 카탈로그 (Family A~F)

### Family 분류표

| Family | 설명 | 클론 베이스 예시 | 규모 |
|--------|------|-----------------|------|
| **A** | 전용 Controller CRUD | timeCdMgr | 대다수 |
| **B** | 공통 Controller (GetDataList.do + SaveData.do) | partMgrApp | 152 JSP |
| **C** | 신청서 3종 세트 (신청/상세/결재) | vacationApp/Det/Apr | HRI 모듈 |
| **D** | 프로시저 직접 호출 (ExecPrc.do) | sepDcPayMgr | 13 JSP |
| **E** | Crownix 리포트 (RDPopup, .mrd) | payReport | .mrd 파일 |
| **F** | 하이브리드 (전용 Controller + AuthTableService) | hrmSta | 법칙 C |

### Family별 상세

**Family A** — 가장 일반적인 패턴
- 전용 Controller + Service + Mapper + JSP
- 법칙 A 권한 적용 (`:ssnEnterCd` 직접 WHERE)
- 매퍼: `*-mapping-query.xml`, Anyframe Velocity `:key` 바인딩
- 클론 난이도: 하(쉬움)

**Family B** — 공통 Controller 사용
- JSP + Mapper만 생성 (Controller/Service 불필요)
- `DoSearch("${ctx}/GetDataList.do?cmd=getXxxList")`
- `DoSave("${ctx}/SaveData.do?cmd=saveXxx")`
- cmd가 곧 Anyframe 쿼리 ID
- 법칙 B 권한 자동 적용 (`$query` 주입)
- 클론 난이도: 하(쉬움)

**Family C** — 신청서 워크플로우
- 3개 JSP 세트: 신청(App) + 상세(Det) + 결재(Apr)
- APPL_STATUS_CD 기반 상태 제어 (→ §5 참조)
- 저장 흐름: delete TTIM301 → delete THRI103 → delete THRI107 → insert → trg_tim_405 → approval → P_HRI_AFTER_PROC_EXEC
- 결재선 테이블: THRI107
- 신청서 코드: THRI101 (신규 코드 부여는 **사용자 승인 필수**)
- 법칙 A 또는 C 권한
- 클론 난이도: 상(어려움) — 결재 흐름 이해 필요

**Family D** — 프로시저 직접 실행
- ProDao.excute() 사용 (Dao 아님)
- OUT 파라미터: sqlCode, sqlErrm
- 법칙 D 권한 (프로시저 내부 처리)
- 클론 난이도: 중 — 프로시저 파라미터 이해 필요

**Family E** — Crownix 리포트
- `.mrd` 리포트 템플릿
- `RDPopup.jsp` → `window.showModalDialog` 방식
- `rdViewer_all.js` 로드, m2soft Crownix viewer
- 클론 난이도: 중 — .mrd 파일 생성은 별도 도구 필요

**Family F** — 하이브리드 (= 법칙 C의 화면 패턴 구현)
- 전용 Controller이면서 AuthTableService `@Autowired` 주입
- 법칙 C 권한 적용 (Family 문자가 C가 아닌 이유: Family C는 신청서 워크플로우 예약)
- Family A와 구조 동일하나 `$query` INNER JOIN 추가
- 클론 난이도: 중 — 권한 주입 패턴 이해 필요

### 클론 베이스 선택 규칙

1. 대상 화면과 **같은 모듈**에서 유사 화면을 먼저 찾는다
2. 같은 모듈에 없으면 **같은 Family**의 다른 모듈 화면을 찾는다
3. Family 판정은 §2 법칙 판정 흐름을 따른다
4. 신청서 화면이면 반드시 Family C 베이스를 사용한다

### 절대 하지 말 것 (Universal Pitfalls)

1. 법칙 A 화면에 `$query` 추가 → 법칙 C로 전환해야 함
2. 법칙 B 매퍼에서 `$query` 제거 → 권한 무력화
3. ProDao와 Dao 혼동 → 법칙 D는 반드시 ProDao
4. Family A 베이스로 Family C 화면 만들기 → 결재 흐름 누락
5. `@Autowired` 권장 (기존 `@Inject @Named` 파일은 해당 패턴 유지)

---

## §4. B1~B7 경계 검증 (EHR4 고유)

EHR4는 7개 경계(Boundary)가 연결 고리를 이룬다. 단 하나라도 불일치하면 Silent Failure 또는 런타임 오류.

### 경계 정의

| 경계 | 연결 포인트 | 불일치 결과 |
|------|------------|------------|
| **B1** | JSP `cmd=X` ↔ Controller `@RequestMapping(params="cmd=X")` | 404 / 빈 응답 |
| **B2** | Controller `paramMap.put("k", v)` ↔ Mapper `:k` 바인딩 | null 주입 |
| **B3** | Mapper 컬럼명 ↔ DB 테이블 DDL 컬럼명 | ORA-00904 |
| **B4** | IBSheet `SaveName:"x"` ↔ Mapper `$rm.x` (Velocity) | Silent null |
| **B5** | (법칙 B/C only) `$query` 또는 `${query}` 존재 여부 | 권한 무력화 → **HOLD** |
| **B6** | (법칙 D only) ExecPrc.do ↔ CALL + ProDao 존재 여부 | 프로시저 미호출 → **HOLD** |
| **B7** | 부등호·`&` 는 `<statement><![CDATA[...]]></statement>` 안에만 (엔티티 이스케이프 금지) | Anyframe 매퍼 파싱 실패 → **HOLD** / `&lt;` 리터럴 Oracle 전달 → **FIX** |

### 법칙별 적용 경계

| 경계 | 법칙 A | 법칙 B | 법칙 C | 법칙 D |
|------|--------|--------|--------|--------|
| B1 | O | O | O | O |
| B2 | O | O | O | O |
| B3 | O | O | O | O |
| B4 | O | O | O | — |
| B5 | — | **O (HOLD)** | **O (HOLD)** | — |
| B6 | — | — | — | **O (HOLD)** |
| B7 | O | O | O | O |

### B4 상세 — Velocity $rm.x vs SaveName

```javascript
// JSP IBSheet InitColumns
{Header:"사번",    SaveName:"sabun",  ...},
{Header:"부서코드", SaveName:"orgCd",  ...},
{Header:"급여",    SaveName:"payAmt", ...}
```

```xml
<!-- Mapper Velocity MERGE (EHR4 고유 문법) -->
#foreach ($rm in $mergeRows)
UNION ALL
SELECT TRIM(:ssnEnterCd) AS ENTER_CD
     , TRIM('$rm.sabun') AS SABUN     <!-- SaveName과 정확히 일치 -->
     , TRIM('$rm.orgCd') AS ORG_CD
     , $rm.payAmt        AS PAY_AMT   <!-- 숫자는 따옴표 없이 -->
  FROM DUAL
#end
```

**주의**: `$rm.field` 가 null이면 Velocity가 리터럴 문자열 `"null"`을 생성한다 (→ §7 NULL 처리 참조).

### B5 — $query 부재 = HOLD

```
법칙 B/C 매퍼에서 $query 또는 ${query} 검색 결과 없음
→ 권한 필터 미적용 → 전 사원 데이터 노출 위험
→ 구현 HOLD, 사용자에게 즉시 보고
```

### B6 — ExecPrc 정합성 = HOLD

```
ExecPrc.do 호출 JSP에서 proDao.excute() 호출 없음
→ 프로시저 실행 안 됨
→ 구현 HOLD, 사용자에게 즉시 보고
```

---

## §5. APPL_STATUS_CD / AGREE_STATUS_CD 신청서 상태 권한

EHR4는 두 상태 코드를 병행 사용한다.

### AGREE_STATUS_CD (결재 진행 상태)

| 코드 | 의미 |
|------|------|
| 10 | 진행중 |
| 20 | 완료 |
| 30 | 반려 |
| 50 | 취소 |

### APPL_STATUS_CD (신청서 처리 상태)

| 코드 | 의미 | 편집/삭제 가능 |
|------|------|----------------|
| 11 | 임시저장 | **가능** |
| 31 | 수신처리중 | 불가 |
| 99 | 처리완료 | 불가 |

### 상태별 권한 규칙

| 동작 | 허용 조건 |
|------|-----------|
| 수정/삭제 | `APPL_STATUS_CD = '11'` (임시저장)일 때만 |
| 결재 요청 | 11 → 결재 요청 → AGREE_STATUS_CD=10 전환 |
| 결재 승인 | THRI107 결재선에 있는 사용자만 |
| 결재 반려 | AGREE_STATUS_CD=30 → 재상신 가능 |
| 재상신 | 반려 상태 → 임시저장(11) 복귀 후 재요청 |

### 매퍼 상태 필터 패턴

```xml
<!-- 목록 조회: 임시저장 제외 기본 -->
AND B.APPL_STATUS_CD NOT IN ('11')

<!-- 수정 가능 여부 확인 -->
AND B.APPL_STATUS_CD = '11'
```

### Family C 화면 구현 시 필수 확인

- [ ] 신청 JSP: 임시저장(11) 상태에서만 수정 UI 표시
- [ ] 상세 JSP: AGREE_STATUS_CD 기반 버튼 가시성 제어
- [ ] 결재 JSP: THRI107 결재선 사용자만 승인/반려 가능
- [ ] 목록 조회: 기본적으로 `APPL_STATUS_CD NOT IN ('11')` 또는 상태 필터
- [ ] 저장 시: delete TTIM301 → delete THRI103 → delete THRI107 → insert 순서
- [ ] 트리거: `trg_tim_405` 발화 후 `P_HRI_AFTER_PROC_EXEC` 연계

---

## §6. IBSheet SaveName 계약 (B4 경계)

IBSheet7의 `InitColumns`에서 정의한 `SaveName`은 Velocity 매퍼의 `$rm.키`와 **정확히 일치**해야 한다.

### 불일치 시 동작

**조용한 실패(Silent Failure)**: 에러 없이 해당 컬럼 값이 `null` 리터럴 문자열로 들어간다.

### EHR4 예시 (Velocity 문법)

```javascript
// JSP — IBSheet InitColumns
{Header:"사번",    SaveName:"sabun",  Width:80, ...},
{Header:"이름",    SaveName:"empNm",  Width:100, ...},
{Header:"급여코드", SaveName:"payCd", Width:80, ...}
```

```xml
<!-- Mapper — MERGE (Anyframe Velocity) -->
<query id="savePayData" isDynamic="true">
  <statement>
    MERGE INTO TCPN100 T
    USING (
      SELECT NULL AS ENTER_CD, NULL AS SABUN FROM DUAL
      #foreach ($rm in $mergeRows)
      UNION ALL
      SELECT TRIM(:ssnEnterCd) AS ENTER_CD
           , TRIM('$rm.sabun') AS SABUN      <!-- SaveName 일치 -->
           , TRIM('$rm.payCd') AS PAY_CD     <!-- SaveName 일치 -->
        FROM DUAL
      #end
    ) S
    ON (T.ENTER_CD = S.ENTER_CD AND T.SABUN = S.SABUN)
    WHEN MATCHED THEN
        UPDATE SET T.PAY_CD   = S.PAY_CD
                 , T.CHKDATE  = SYSDATE
                 , T.CHKID    = :ssnSabun
    WHEN NOT MATCHED THEN
        INSERT (ENTER_CD, SABUN, PAY_CD, CHKDATE, CHKID)
        VALUES (S.ENTER_CD, S.SABUN, S.PAY_CD, SYSDATE, :ssnSabun)
  </statement>
</query>
```

### 체크 규칙

- [ ] IBSheet `SaveName` (camelCase) = 매퍼 `$rm.xxx` 의 xxx
- [ ] 시스템 컬럼 포함: `sNo`, `sDelete`, `sStatus` (IBSheet7 내장)
- [ ] 대소문자 정확히 일치 (`Sabun` ≠ `sabun`)
- [ ] 숫자형 컬럼은 따옴표 없이: `$rm.payAmt` (문자형은 `TRIM('$rm.payCd')`)

---

## §7. Anyframe Velocity 문법 레퍼런스 (EHR4 고유)

EHR4는 MyBatis `#{}` 가 아닌 **Anyframe Query Mapping + Velocity** 엔진을 사용한다.

### 바인드 방식 비교

| 방식 | 문법 | 특성 | 사용처 |
|------|------|------|--------|
| **바인드 변수** | `:key` | SQL-safe PreparedStatement | WHERE 조건, 안전한 값 바인딩 |
| **Velocity 변수** | `$var` | 문자열 직접 치환 (위험) | $query, $mergeRows 루프 등 |
| **중괄호 Velocity** | `${var}` | 경계 명확 치환 | `${query}`, 문자열 연결 시 |

### 조건문

```xml
#if ($searchKey && !$searchKey.equals(""))
  AND A.COL1 LIKE '%' || :searchKey || '%'
#end

#if ($ssnSearchType == "O")
  INNER JOIN ($query) AUTH ON AUTH.ENTER_CD = A.ENTER_CD AND AUTH.SABUN = A.SABUN
#end

#if ($flag == "Y")
  AND A.USE_YN = 'Y'
#else
  AND A.USE_YN = 'N'
#end
```

### 루프 (MERGE/DELETE 생성)

```xml
MERGE INTO TXXX T
USING (
  SELECT NULL AS ENTER_CD, NULL AS COL1 FROM DUAL
  #foreach ($rm in $mergeRows)
  UNION ALL
  SELECT TRIM(:ssnEnterCd) AS ENTER_CD
       , TRIM('$rm.col1')  AS COL1
       , $rm.amount        AS AMOUNT
    FROM DUAL
  #end
) S
ON (T.ENTER_CD = S.ENTER_CD AND T.COL1 = S.COL1)
WHEN MATCHED THEN
    UPDATE SET T.AMOUNT = S.AMOUNT, T.CHKDATE = SYSDATE, T.CHKID = :ssnSabun
WHEN NOT MATCHED THEN
    INSERT (ENTER_CD, COL1, AMOUNT, CHKDATE, CHKID)
    VALUES (S.ENTER_CD, S.COL1, S.AMOUNT, SYSDATE, :ssnSabun)
```

**$velocityHasNext** 패턴 (UNION ALL 마지막 줄 제어):
```xml
#foreach ($rm in $mergeRows)
  SELECT '$rm.col1' AS COL1 FROM DUAL
  #if ($velocityHasNext) UNION ALL #end
#end
```

### 문자열 래핑

```xml
TRIM('$rm.gntCd')      -- 문자열: 따옴표로 감싸기
$rm.payAmt             -- 숫자: 따옴표 없이
NVL('$rm.remark', '')  -- NULL 대비 NVL 래핑
```

### NULL 처리 주의

Velocity에서 `$rm.field` 값이 Java `null`이면 리터럴 문자열 `"null"`이 SQL에 삽입된다.

```xml
<!-- 위험 패턴 -->
TRIM('$rm.optionalField')   -- null → TRIM('null') → 문자열 'null' 저장

<!-- 안전 패턴 -->
#if ($rm.optionalField && !$rm.optionalField.equals(""))
  TRIM('$rm.optionalField')
#else
  NULL
#end
```

### 권한 WHERE 주입

```xml
<!-- $query: F_COM_GET_SQL_AUTH 반환값 (서브쿼리 문자열) -->
INNER JOIN ($query) AUTH ON AUTH.ENTER_CD = A.ENTER_CD AND AUTH.SABUN = A.SABUN

<!-- ${query}: 경계 명확 버전 (변수명 뒤에 다른 문자가 오는 경우) -->
FROM (${query}) AUTH WHERE AUTH.SABUN = A.SABUN
```

### Anyframe 쿼리 파일 구조

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE queryservice PUBLIC "-//ANYFRAME//DTD Query Service//EN"
  "http://www.anyframejava.org/dtd/anyframe-query-service.dtd">
<queryservice>

  <query id="getXxxList" isDynamic="true">
    <statement>
      SELECT ...
      FROM TXXX A
      WHERE A.ENTER_CD = :ssnEnterCd
      #if ($searchKey && !$searchKey.equals(""))
        AND A.KEY_COL = :searchKey
      #end
    </statement>
  </query>

</queryservice>
```

---

## §8. 재구현 금지 컴포넌트

아래 컴포넌트는 절대 새로 만들지 않는다. 기존 것을 그대로 사용한다.

| 컴포넌트 | 참조 수 | 역할 | 주의 |
|----------|---------|------|------|
| GetDataListController | 152 JSP | 법칙 B 조회 | 직접 수정 금지 |
| GetDataMapController | — | 단건 조회 | 직접 수정 금지 |
| SaveDataController | — | 법칙 B 저장 | 직접 수정 금지 |
| ExecPrcController | 13 JSP | 법칙 D 프로시저 | 직접 수정 금지 |
| AuthTableService | — | 권한 쿼리 생성 | 빈 이름: `"AuthTableService"` (파일명 `atuhTable` 오타 — **절대 수정 금지**) |
| Dao | 전체 | 일반 DAO | `getList` · `getMap` · `create` · `update` · `delete` · `excute` |
| ProDao | 법칙 D | 프로시저 DAO | `excute` 메서드만 사용 (오타 `excute` 유지) |
| recQueryService | — | 레코드 쿼리 서비스 | 재구현 금지 |
| ApprovalMgr | 181 refs | 결재 관리 | 재구현 시 결재 흐름 붕괴 |
| UploadMgr | 24 refs | 파일 업로드 | 모듈별 특화 UploadMgr 존재 |
| RDPopup | 50 refs | Crownix 리포트 팝업 | window.showModalDialog 사용 |
| CommonCodeService | — | TSYS005 공통 코드 | 코드 조회는 이 서비스 사용 |
| Language.getMessage | — | i18n 메시지 | 158개 위치 사용 — 키 변경 금지 |

**AuthTableService 오타 주의**: 파일 경로에 `atuhTable` (오타)이지만 **절대 수정하지 않는다**.
전체 코드베이스가 이 이름에 의존하며, 빈 이름 `"AuthTableService"`는 정상 문자열.

**DAO 메서드 오타 주의**: `dao.excute()` (`execute`가 아님) — EHR4 전체 일관된 오타. 수정 금지.

---

## §9. 배치 저장 — 50건 분할 규칙 (EHR4 고유)

EHR4는 Anyframe Velocity 특성상 **50건 단위** 분할이 기준이다 (ehr5의 1000건 청크와 다름).

### 이유

- Velocity `#foreach` 루프는 컬럼별로 바인드 변수를 생성 → 컬럼 10개 × 50행 = 500 바인드
- Oracle 바인드 변수 한계: ~1000개/쿼리
- Velocity 생성 SQL 텍스트 한계: 64KB
- 50행이 안전 임계값 (컬럼 수에 따라 더 낮게 설정 가능)

### 표준 해결 패턴

```java
// Service 레이어에서 50건 단위 분할
public int saveLargeData(Map<?, ?> convertMap) throws Exception {
    int cnt = 0;
    List<?> mergeRows = (List<?>) convertMap.get("mergeRows");

    // 50건 단위 청크 분할
    int chunkSize = 50;
    for (int i = 0; i < mergeRows.size(); i += chunkSize) {
        int end = Math.min(i + chunkSize, mergeRows.size());
        List<?> chunk = mergeRows.subList(i, end);

        Map<String, Object> chunkMap = new HashMap<>(convertMap);
        chunkMap.put("mergeRows", chunk);
        cnt += dao.update("saveXxxData", chunkMap);
    }
    return cnt;
}
```

### DELETE sentinel 패턴 (EHR4 고유)

```xml
<!-- sentinel 레코드로 IN절 빈 값 방지 -->
<query id="deleteXxxData" isDynamic="true">
  <statement>
    DELETE FROM TXXX
     WHERE (ENTER_CD, KEY_COL) IN ( (NULL, NULL)
    #foreach ($rm in $deleteRows)
      #if ($rm.keyCd != "")
      , (TRIM(:ssnEnterCd), TRIM('$rm.keyCd'))
      #end
    #end
    )
  </statement>
</query>
```

`(NULL, NULL)` sentinel: 삭제 행이 0건이어도 IN절이 유효한 SQL을 유지.

### 체크 규칙

- [ ] 50건 이상 일괄 저장 가능성 있으면 분할 로직 포함
- [ ] Velocity `#foreach` MERGE: 컬럼 수 × 행 수 < 1000 검증
- [ ] SQL 생성 텍스트가 64KB를 넘지 않는지 확인
- [ ] DELETE IN절에 sentinel `(NULL, NULL)` 포함 여부

---

## §10. 퇴직 관련 핵심 테이블

| 테이블 | 역할 |
|--------|------|
| TCPN771 | 퇴직정산 마스터 — 세액(T_ITAX_MON, T_RTAX_MON), 확정여부(CLOSE_YN), DB이체여부(DB_FULL_YN) |
| TCPN777 | 과세이연 계좌별 내역 — 연금계좌 이체 금액, 이연세액 |
| TCPN203 | 퇴직 인원 상태(PAY_PEOPLE_STATUS) — 'J'=재계산 대상 |
| TCPN760 | 퇴직금 계산 기초 데이터 |

> **주의**: 퇴직세액 계산 프로시저명과 로직은 고객사별로 다를 수 있다. 특정 계산 흐름을 가정하지 말고, 반드시 프로시저 소스를 직접 추적한다.

---

## §11. 5대 릴리즈 리스크 (EHR4 고유)

릴리즈 전 release-safety-reviewer가 이 5개 리스크를 반드시 평가한다.

### R1 — CPN 급여 체인

| 항목 | 내용 |
|------|------|
| 핵심 프로시저 | `P_CPN_CAL_PAY_MAIN` (직접 8개, 재귀 합계 108개) |
| 연계 트리거 | 급여 계산 트리거 7개 |
| 위험 수준 | 치명 (Blocker) |
| 판정 기준 | 이 체인에 영향 없으면 Go / 간접 영향이면 Conditional-Go / 직접 수정이면 HOLD |

### R2 — HRI 후처리

| 항목 | 내용 |
|------|------|
| 핵심 프로시저 | `P_HRI_AFTER_PROC_EXEC` |
| 연계 테이블 | `THRI101` (신청서 코드 마스터) |
| 위험 수준 | 높음 |
| 판정 기준 | THRI101 코드 변경 없으면 Go / 신규 코드 추가이면 Conditional-Go (사용자 승인) / 기존 코드 삭제·수정이면 HOLD |

### R3 — 권한 경계

| 항목 | 내용 |
|------|------|
| 핵심 요소 | `:ssnEnterCd` WHERE, `$query`, `F_COM_GET_SQL_AUTH` |
| 위험 수준 | 높음 (데이터 노출) |
| 판정 기준 | 모든 쿼리에 `:ssnEnterCd` 존재 + 법칙 B/C에 `$query` 존재 → Go / 하나라도 누락 → HOLD |

### R4 — i18n 파손

| 항목 | 내용 |
|------|------|
| 핵심 함수 | `F_COM_GET_LANGUAGE_MAPPING` |
| 사용 위치 | 158개 위치 |
| 위험 수준 | 중간 |
| 판정 기준 | Language 키 변경 없으면 Go / 키 추가이면 Conditional-Go / 기존 키 삭제·수정이면 HOLD |

### R5 — ExecPrc 정합성

| 항목 | 내용 |
|------|------|
| 핵심 요소 | 13개 JSP, ExecPrc.do, ProDao |
| 위험 수준 | 중간 |
| 판정 기준 | ExecPrc.do 미변경이면 Go / ProDao 체인 완전하면 Conditional-Go / B6 경계 누락이면 HOLD |

### 종합 판정 기준

| 판정 | 조건 |
|------|------|
| **Go** | 모든 R1~R5에서 직접 영향 없음 |
| **Conditional-Go** | 1개 이상 간접 영향 + 사용자 확인 완료 |
| **HOLD** | R1 직접 수정 / R3 권한 누락 / B5·B6 경계 미충족 / 사용자 미승인 신청서 코드 변경 |
