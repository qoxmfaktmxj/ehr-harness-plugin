---
name: ehr-domain-knowledge
description: "EHR5 도메인 지식 레퍼런스. 4축 권한 모델, 법칙 A/B/C/D 판정, 화면 패턴 카탈로그(Family A~F), APPL_STATUS_CD 상태 권한, IBSheet 계약, 재구현 금지 컴포넌트, 배치 저장 규칙. '권한', '법칙', '패턴', '패밀리', 'Family', '신청서 상태', 'APPL_STATUS', '배치', '청크', 'AuthTable', 'F_COM_GET_SQL_AUTH' 등의 키워드에 트리거."
---

# EHR5 도메인 지식 레퍼런스

화면 생성·수정 전에 이 문서의 관련 섹션을 반드시 확인한다.
screen-builder 에이전트는 구현 전 권한 법칙 판정(§2)과 패턴 분류(§3)를 선행한다.

---

## §1. 4축 권한 모델

모든 SELECT/UPDATE/DELETE 쿼리에 회사 격리(`ssnEnterCd`)는 **필수**이다.

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

- `searchEmpType` 파라미터가 있으면 ssnSearchType을 **오버라이드**한다
- 법칙 B 화면에서 `ssnSearchType`은 `F_COM_GET_SQL_AUTH`에 전달되어 동적 WHERE 생성

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
-- 반환값: " AND <조건절>" 또는 빈 문자열
```

실제 호출 (AuthTable-sql-query.xml):
```xml
SELECT '(' || F_COM_GET_SQL_AUTH(
  #{ssnEnterCd}, #{authSqlID}, #{ssnSearchType},
  #{ssnSabun}, NVL(#{searchGrpCd}, #{ssnGrpCd}), ''
) || ')' AS query FROM dual
```

**확인된 authSqlID 값**: `THRM151` (인사 마스터 범위), `TORG101` (조직 범위)

### 4가지 법칙

#### 법칙 A — 전용 Controller + 직접 WHERE

Controller에서 세션 변수를 `paramMap`에 주입하고, 매퍼에서 직접 WHERE 바인딩.

```java
// Controller
paramMap.put("ssnEnterCd", session.getAttribute("ssnEnterCd"));
paramMap.put("ssnSabun", session.getAttribute("ssnSabun"));
```
```xml
<!-- Mapper -->
WHERE A.ENTER_CD = #{ssnEnterCd}
  AND A.SABUN = #{ssnSabun}
```

- AuthTableService 미사용
- `${query}` 미사용
- ssnEnterCd WHERE는 반드시 존재

#### 법칙 B — 공통 Controller + F_COM_GET_SQL_AUTH + ${query}

GetDataListController/SaveDataController가 자동으로 `AuthTableService.getAuthQueryMap()` 호출.
결과가 `${query}`로 매퍼에 주입된다.

```java
// Controller 측 (GetDataListController 내부)
paramMap.put("authSqlID", "THRM151");
Map<?, ?> authMap = authTableService.getAuthQueryMap(paramMap);
paramMap.put("query", authMap.get("query"));
```

매퍼에서 `${query}` 3가지 패턴:
```xml
<!-- 패턴 1: INNER JOIN -->
INNER JOIN (${query}) AUTH ON A.ENTER_CD = AUTH.ENTER_CD AND A.SABUN = AUTH.SABUN

<!-- 패턴 2: IN 서브쿼리 -->
AND (A.ENTER_CD, A.SABUN) IN (${query})

<!-- 패턴 3: FROM 절 -->
FROM (${query}) AUTH, THRM100 A WHERE AUTH.SABUN = A.SABUN
```

- GetDataList.do / SaveData.do URL 사용
- authSqlID 파라미터 필수
- **79개 JSP**가 이 법칙 사용

#### 법칙 C — 하이브리드 (전용 Controller + AuthTableService)

전용 Controller이면서 AuthTableService를 주입받아 `${query}`를 생성하는 패턴.
**41개 컨트롤러**가 이 패턴을 사용한다.

```java
@Controller
@RequestMapping("/SepDcPayMgr.do")
public class SepDcPayMgrController {
    @Inject @Named("AuthTableService")
    private AuthTableService authTableService;

    public ModelAndView getList(HttpServletRequest request, ...) {
        Map<?, ?> authMap = authTableService.getAuthQueryMap(paramMap);
        paramMap.put("query", authMap.get("query"));
        // ...
    }
}
```

- 전용 URL (.do) 사용
- AuthTableService 주입 **있음**
- 매퍼에 `${query}` 사용

#### 법칙 D — 프로시저 직접 호출 (ExecPrc.do)

프론트에서 ExecPrc.do로 직접 프로시저를 호출. 권한은 프로시저 내부에서 처리.

```xml
<!-- Mapper: statementType="CALLABLE" -->
{CALL P_XXX(
  #{sqlCode, mode=OUT, jdbcType=VARCHAR},
  #{sqlErrm, mode=OUT, jdbcType=VARCHAR},
  #{ssnEnterCd}, #{ssnSabun}, ...
)}
```

- **ProDao** 사용 (Dao 아님 — 혼동 주의)
- **7개 JSP**가 이 법칙 사용
- 치명 프로시저(P_CPN_CAL_PAY_MAIN 등)는 이 법칙으로 호출됨

### 법칙 판정 흐름

```
1. JSP URL이 GetDataList.do / SaveData.do인가?
   → YES: 법칙 B
   → NO: 2번으로

2. Controller가 AuthTableService를 @Inject하는가?
   → YES: 법칙 C (하이브리드)
   → NO: 3번으로

3. ExecPrc.do를 사용하는가?
   → YES: 법칙 D
   → NO: 법칙 A (전용 Controller, 직접 WHERE)
```

### 법칙별 체크리스트

| 항목 | A | B | C | D |
|------|---|---|---|---|
| ssnEnterCd WHERE 필수 | O | O (${query} 포함) | O (${query} 포함) | O (프로시저 IN 파라미터) |
| AuthTableService 주입 | X | 공통 Controller 내부 | **O** | X |
| authSqlID 설정 | X | O | O | X |
| ${query} 매퍼 사용 | X | O | O | X |
| ProDao 사용 | X | X | X | **O** |

---

## §3. 화면 패턴 카탈로그 (Family A~F)

### Family 분류표

| Family | 설명 | 클론 베이스 예시 | 규모 |
|--------|------|-----------------|------|
| **A** | 전용 Controller CRUD | timeCdMgr | 대다수 |
| **B** | 공통 Controller (GetDataList.do + SaveData.do) | partMgrApp | 79 JSP |
| **C** | 신청서 3종 세트 (신청/상세/결재) | vacationApp/Det/Apr | hri 모듈 |
| **D** | 프로시저 직접 호출 (ExecPrc.do) | sepDcPayMgr | 7 JSP |
| **E** | Crownix 리포트 (rdPopup → rdLayer 전환 중) | payReport | 250 .mrd 파일 |
| **F** | 하이브리드 (전용 Controller + AuthTableService) | hrmSta | 41 Controller |

### Family별 상세

**Family A** — 가장 일반적인 패턴
- 전용 Controller + Service + Mapper + JSP
- 법칙 A 권한 적용
- 클론 난이도: 하(쉬움)

**Family B** — 공통 Controller 사용
- JSP + Mapper만 생성 (Controller/Service 불필요)
- `DoSearch("${ctx}/GetDataList.do?cmd=getXxxList")`
- `DoSave("${ctx}/SaveData.do?cmd=saveXxx")`
- cmd가 곧 MyBatis 쿼리 ID
- 법칙 B 권한 자동 적용
- 클론 난이도: 하(쉬움)

**Family C** — 신청서 워크플로우
- 3개 JSP 세트: 신청(App) + 상세(Det) + 결재(Apr)
- APPL_STATUS_CD 기반 상태 제어 (→ §4 참조)
- 결재선 테이블: THRI107
- 법칙 A 또는 C 권한
- 클론 난이도: 상(어려움) — 결재 흐름 이해 필요

**Family D** — 프로시저 직접 실행
- statementType="CALLABLE" 매퍼 필수
- ProDao 사용 (Dao 아님)
- OUT 파라미터: sqlCode, sqlErrm
- 법칙 D 권한 (프로시저 내부 처리)
- 클론 난이도: 중 — 프로시저 파라미터 이해 필요

**Family E** — Crownix 리포트
- `.mrd` 리포트 템플릿 (src/main/resources/static/html/report/)
- 이중 구조 전환 중:
  - 레거시: `rdPopup.jsp` → `window.showModalDialog`
  - 현행: `rdLayer.jsp` / `commonRdLayer.jsp` → `LayerModalUtility.open()`
- Crownix m2soft viewer 사용: `new m2soft.crownix.Viewer(...)`
- 클론 난이도: 중 — .mrd 파일 생성은 별도 도구 필요

**Family F** — 하이브리드 (= 법칙 C의 화면 패턴 구현)
- 전용 Controller이면서 AuthTableService 주입
- 법칙 C 권한 적용 (Family 문자가 C가 아닌 이유: Family C는 신청서 워크플로우에 사용)
- Family A와 구조 동일하나 `${query}` 추가
- 클론 난이도: 중 — 권한 주입 패턴 이해 필요

### 클론 베이스 선택 규칙

1. 대상 화면과 **같은 모듈**에서 유사 화면을 먼저 찾는다
2. 같은 모듈에 없으면 **같은 Family**의 다른 모듈 화면을 찾는다
3. Family 판정은 §2 법칙 판정 흐름을 따른다
4. 신청서 화면이면 반드시 Family C 베이스를 사용한다

### 절대 하지 말 것

- 법칙 A 화면에 `${query}` 추가 (→ 법칙 C로 전환해야 함)
- 법칙 B 매퍼에서 `${query}` 제거 (→ 권한 무력화)
- ProDao와 Dao 혼동 (법칙 D는 반드시 ProDao)
- Family A 베이스로 Family C 화면 만들기 (결재 흐름 누락)

---

## §4. APPL_STATUS_CD 신청서 상태 권한

### 상태 코드 체계

| 코드 | 의미 | UI 표시 코드 | UI 의미 |
|------|------|-------------|---------|
| 11 | 임시저장 | 제외 (NOT IN) | 목록에 미표시 |
| 21 | 결재처리중 | 10 | 진행중 |
| 31 | 수신처리중 | 10 | 진행중 |
| 23 | 결재반려 | 30 | 반려 |
| 33 | 수신반려 | 30 | 반려 |
| 99 | 처리완료 | 20 | 완료 |

코드 구조: **첫째 자리**(2=결재, 3=수신), **둘째 자리**(1=처리중, 3=반려, 9=완료). 11은 임시저장 예외.

### 매퍼 변환 패턴

```xml
CASE
  WHEN B.APPL_STATUS_CD = '21' OR B.APPL_STATUS_CD = '31' THEN '10'
  WHEN B.APPL_STATUS_CD = '99' THEN '20'
  WHEN B.APPL_STATUS_CD = '23' OR B.APPL_STATUS_CD = '33' THEN '30'
END AS applStatusCd
```

### 상태별 권한 규칙

| 동작 | 허용 조건 |
|------|-----------|
| 수정/삭제 | `APPL_STATUS_CD = '11'` (임시저장) 일 때만 |
| 결재 요청 | 11 → 21 전환 (본인만) |
| 결재 승인 | THRI107 결재선에 있는 사용자만 |
| 결재 반려 | 21 → 23 전환 (결재자만) |
| 재상신 | 23(반려) → 11(임시저장) 복귀 후 재요청 |

### Family C 화면 구현 시 필수 확인

- [ ] 신청 JSP: 임시저장(11) 상태에서만 수정 UI 표시
- [ ] 상세 JSP: 상태에 따라 버튼 가시성 제어
- [ ] 결재 JSP: THRI107 결재선 사용자만 승인/반려 가능
- [ ] 목록 조회: 기본적으로 `APPL_STATUS_CD NOT IN ('11')` 또는 상태 필터

---

## §5. IBSheet SaveName 계약 (B4 경계)

IBSheet7의 `InitColumns`에서 정의한 `SaveName`은 매퍼 XML의 `#{rm.키}` 와 **정확히 일치**해야 한다.

### 불일치 시 동작

**조용한 실패(Silent Failure)**: 에러 없이 해당 컬럼 값이 `null`로 들어간다.

### 예시

```javascript
// JSP — IBSheet InitColumns
{Header:"사번", SaveName:"sabun", ...},
{Header:"이름", SaveName:"empNm", ...},
{Header:"부서", SaveName:"orgCd", ...}
```

```xml
<!-- Mapper — MERGE문 -->
<foreach item="rm" collection="mergeRows" separator=" UNION ALL ">
  SELECT #{rm.sabun}     AS SABUN,      <!-- SaveName과 일치 -->
         #{rm.empNm}     AS EMP_NM,     <!-- SaveName과 일치 -->
         #{rm.orgCd}     AS ORG_CD      <!-- SaveName과 일치 -->
  FROM DUAL
</foreach>
```

### 체크 규칙

- [ ] IBSheet `SaveName` (camelCase) = 매퍼 `#{rm.xxx}` 의 xxx
- [ ] 시스템 컬럼 포함: `sNo`, `sDelete`, `sStatus` (IBSheet7 내장)
- [ ] 대소문자 정확히 일치 (`Sabun` ≠ `sabun`)

---

## §6. 재구현 금지 컴포넌트

아래 컴포넌트는 절대 새로 만들지 않는다. 기존 것을 그대로 사용한다.

| 컴포넌트 | 참조 수 | 역할 | 주의 |
|----------|---------|------|------|
| GetDataListController | 79 JSP | 법칙 B 조회 | 직접 수정 금지 |
| GetDataMapController | - | 단건 조회 | 직접 수정 금지 |
| SaveDataController | 53 JSP | 법칙 B 저장 | 직접 수정 금지 |
| ExecPrcController | 7 JSP | 법칙 D 프로시저 | 직접 수정 금지 |
| AuthTableService | 41 Controller | 권한 쿼리 생성 | 빈 이름: `"AuthTableService"` (오타 `atuhTable` 파일명 유지) |
| Dao / ProDao | 전체 | 일반/프로시저 DAO | ProDao=프로시저 전용 |
| ApprovalMgr | 250+ | 결재 관리 | 재구현 시 결재 흐름 붕괴 |
| UploadMgr | 108 파일 | 파일 업로드 | 모듈별 특화 UploadMgr 존재 |
| CommonCodeService | - | TSYS005 공통 코드 | 코드 조회는 이 서비스 사용 |
| LayerModalUtility | - | 모달 팝업 | rdLayer.jsp와 연동 |

**AuthTableService 주의**: 파일명이 `atuhTable` (오타)이지만 **절대 수정하지 않는다**. 전체 코드베이스가 이 이름에 의존한다.

---

## §7. 퇴직 관련 핵심 테이블

| 테이블 | 역할 |
|--------|------|
| TCPN771 | 퇴직정산 마스터 — 세액(T_ITAX_MON, T_RTAX_MON), 확정여부(CLOSE_YN), DB이체여부(DB_FULL_YN) |
| TCPN777 | 과세이연 계좌별 내역 — 연금계좌 이체 금액, 이연세액 |
| TCPN203 | 퇴직 인원 상태(PAY_PEOPLE_STATUS) — 'J'=재계산 대상 |
| TCPN760 | 퇴직금 계산 기초 데이터 |

> **주의**: 퇴직세액 계산 프로시저명과 로직은 고객사별로 다를 수 있다. 특정 계산 흐름을 가정하지 말고, 반드시 프로시저 소스를 직접 추적한다.

---

## §8. 대량 저장 — 배치 청크 규칙

### 문제

- Oracle IN절 제한: **1000개** 요소 초과 시 ORA-01795 에러
- MERGE/DELETE의 foreach UNION ALL: 바인드 변수 과다 시 SQL 길이 초과

### 표준 해결 패턴

Java 서비스에서 `ListUtil.getChunkedList()`로 분할:

```java
// 표준 패턴 — 1000건 단위 분할
import com.hr.common.util.ListUtil;

// IN절 제한 회피용 (DB 조회 시)
paramMap.put("empList", ListUtil.getChunkedList(targetEmpList, 1000));

// DELETE용 분할
convertMap.put("deleteRows", ListUtil.getChunkedList(deleteRows, 1000));
cnt += dao.delete("deleteXxx", convertMap);
```

매퍼 XML에서 이중 foreach로 처리:

```xml
<!-- 청크된 리스트 처리 -->
<foreach collection="empRows" item="chunked" open="(" close=")" separator=" OR ">
  (A.ENTER_CD, A.SABUN) IN
  <foreach collection="chunked" item="item" open="(" close=")" separator=", ">
    (#{item.enterCd}, #{item.sabun})
  </foreach>
</foreach>
```

### 표준 청크 사이즈

| 상수 | 값 | 사용처 |
|------|-----|--------|
| `CHUNK_SIZE` | **1000** | 대부분 서비스 (IN절 제한 회피) |
| `CHUNK_SIZE` | 900 | 일부 서비스 (안전 마진) |

### 배치 모드

`getMapBatchMode()` / `getListBatchMode()`: 대량 조회 시 배치 SQL 세션 사용 (18개 서비스).

```java
if (isBatch) {
    result = dao.getMapBatchMode("getXxxByCode", paramMap);
} else {
    result = dao.getMap("getXxxByCode", paramMap);
}
```

### 체크 규칙

- [ ] 대량 저장(1000건+) 시 `ListUtil.getChunkedList()` 사용 여부
- [ ] DELETE IN절에 1000개 초과 가능성 확인
- [ ] MERGE/foreach UNION ALL에 대량 데이터 유입 가능성 확인
