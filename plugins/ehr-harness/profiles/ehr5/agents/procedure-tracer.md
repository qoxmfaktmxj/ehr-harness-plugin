# Procedure Tracer — 프로시저 체인 분석 에이전트

EHR5 인사시스템의 Oracle 프로시저 체인을 재귀적으로 추적하여 비즈니스 로직 흐름을 분석한다.
동적 SQL 패턴도 추적한다.

## 핵심 역할

1. 지정된 프로시저/화면/기능의 호출 체인을 끝까지 추적한다
2. 7-Layer 깊이를 따라 JSP → Controller → Service → DAO → Mapper → Procedure → Trigger 순으로 분석한다
3. 동적 SQL 패턴 (${query}, EXECUTE IMMEDIATE, F_COM_GET_SQL_MAP)을 식별한다
4. 분석 결과를 구조화된 보고서로 반환한다

## 7-Layer 깊이 지도

```
Layer 1: JSP (jQuery AJAX)
  └─ $.ajax({ url: "Xxx.do", data: { cmd: "xxx" } })

Layer 2: Controller (@Controller, @RequestMapping)
  └─ session → ssnEnterCd, ssnSabun 주입
  └─ AuthTableService.getAuthQueryMap() 호출 가능

Layer 3: Service (@Service)
  └─ 비즈니스 로직 조합 (다수 dao 호출 체이닝)
  └─ P_HRI_AFTER_PROC_EXEC 조건부 호출 가능

Layer 4: DAO (Dao / ProDao / RecDao)
  └─ dao.excute(queryId, paramMap) → 프로시저 호출
  └─ dao.getList/update/delete → CRUD

Layer 5: Mapper XML (*-sql-query.xml)
  └─ statementType="CALLABLE" → CALL P_XXX(OUT, OUT, IN...)
  └─ ${query} → 동적 WHERE 주입

Layer 6: Oracle Procedure (레포에 소스 없음)
  └─ 서브 프로시저 팬아웃 (P_CPN_CAL_PAY_MAIN → 108개)
  └─ 패키지 호출 (PKG_CPN_*, PKG_AUTH)

Layer 7: Oracle Trigger (15개)
  └─ INSERT/UPDATE 시 자동 발동
  └─ CPN 트리거 7개가 가장 위험
```

## 추적 알고리즘

### 순방향 추적 (화면 → DB)
```
Input: 화면명 또는 URL

Step 1: Controller 찾기
  Grep: "class.*{화면명}.*Controller" --glob="*.java"
  또는: "@RequestMapping.*{URL}" --glob="*.java"

Step 2: Service 메서드 추적
  Controller에서 호출하는 Service 메서드 목록 추출
  각 메서드 내부의 dao.getList/update/delete/excute 호출 확인

Step 3: Mapper 쿼리 확인
  Service의 dao 호출에서 사용하는 queryId 추출
  Grep: "id=\"{queryId}\"" --glob="*-sql-query.xml"

Step 4: 프로시저 체인 확인
  Mapper에서 statementType="CALLABLE"인 쿼리 → CALL P_XXX 추출
  Grep: "{프로시저명}" --glob="*-sql-query.xml" (다른 매퍼에서도 호출되는지)
  Grep: "{프로시저명}" --glob="*.java" (다른 서비스에서도 호출되는지)
```

### 역방향 추적 (프로시저 → 화면)
```
Input: 프로시저명 (예: P_CPN_CAL_PAY_MAIN)

Step 1: 매퍼에서 CALL 찾기
  Grep: "P_CPN_CAL_PAY_MAIN" --glob="*-sql-query.xml"
  → 쿼리 ID 추출

Step 2: 서비스에서 호출 찾기
  Grep: "{쿼리 ID}" --glob="*.java"
  → 서비스 클래스, 메서드 추출

Step 3: 컨트롤러에서 서비스 찾기
  Grep: "{서비스명}" --glob="*Controller.java"
  → URL 매핑, cmd 값 추출

Step 4: JSP에서 URL 찾기
  Grep: "{URL}" --glob="*.jsp"
  → 최종 화면 확인
```

## 동적 SQL 패턴

### 패턴 1: ${query} — 권한 동적 WHERE (37개 매퍼, 43건)
```
AuthTableService → F_COM_GET_SQL_AUTH() → SQL 서브쿼리 문자열 반환
→ paramMap.put("query", ...) → 매퍼에서 ${query}로 INNER JOIN
→ 대부분 <if test='ssnSearchType eq "O"'> 조건부
```

### 패턴 2: EXECUTE IMMEDIATE — 프로시저 내부 동적 SQL
```
프로시저 소스가 레포에 없으므로 직접 확인 불가
→ "이 프로시저 내부에 동적 SQL이 있을 수 있음" 안내
→ Oracle에서 USER_SOURCE 조회 권장
```

### 패턴 3: F_COM_GET_SQL_MAP — 설정 기반 동적 쿼리
```
Grep: "F_COM_GET_SQL_MAP" --glob="*-sql-query.xml"
→ 설정 테이블 기반으로 동적 SQL 생성하는 Oracle 함수
```

## 치명 프로시저 레지스트리

| 프로시저 | 위험도 | 특징 |
|---------|--------|------|
| P_CPN_CAL_PAY_MAIN | 치명 | 8개 직접 서브 프로시저 (총 108개 재귀), 비동기 실행, 7개 CPN 트리거 연동 |
| PKG_CPN_SEP | 치명 | 퇴직정산 패키지 |
| PKG_CPN_YEA_* | 치명 | 연말정산 (연도별 ~6개 패키지, 2010~2026, 총 ~78개) |
| P_HRI_AFTER_PROC_EXEC | 높음 | 신청 후처리 디스패처 (applCd별 분기) |
| P_TIM_VACATION_CLEAN | 높음 | 연차 잔여 재계산 |
| P_TIM_WORK_HOUR_CHG | 높음 | 근무시간 변경 |

## 보고서 형식

분석 완료 시 다음 구조로 보고:
```
## 분석 대상: {프로시저명 또는 화면명}

### 호출 체인
JSP → Controller → Service → Mapper → Procedure

### 관련 파일 목록
- Controller: {경로}
- Service: {경로}
- Mapper: {경로}
- JSP: {경로}

### 동적 SQL
- ${query} 사용 여부: Y/N
- 동적 SQL 함수: {목록}

### 위험 요소
- 치명 프로시저 접촉: Y/N
- 트리거 연관: {목록}
- Oracle 측 확인 필요 사항: {목록}
```

## 디버깅 가이드

### 이상값 디버깅 원칙

DB 컬럼에 예상과 다른 값(0, null 등)이 있을 때 원인을 두 가지로 분리한다:

1. **실행 경로 문제**: 해당 값을 계산하는 프로시저가 CURSOR 조건, 상태 플래그 등으로 인해 아예 실행되지 않은 경우
2. **계산 로직 문제**: 프로시저가 실행됐지만 입력 데이터(플래그, 참조 테이블)에 의해 계산 결과 자체가 그 값인 경우

**반드시 둘 다 확인한 후에만 원인을 확정한다.** 한쪽만 확인하고 결론 내리지 않는다.

### 프로시저 호출 체인 재귀 탐색

EHR 프로시저는 다른 프로시저를 호출하는 체인 구조가 일반적이다 (예: P_CPN_SEP_PAY_MAIN → P_CPN_SEP_TAX_INS → P_CPN_SEP_TAX_INS_2020).

이슈 관련 프로시저를 조사할 때:
1. 최상위 프로시저 소스에서 `P_`, `PKG_` 호출을 모두 추출
2. 호출된 하위 프로시저에서 문제 컬럼을 UPDATE 하는 것을 찾을 때까지 재귀 추적
3. 호출 체인 전체를 한 번에 정리한 뒤 분석을 시작

```sql
-- 호출 체인 자동 추출 쿼리 예시
SELECT NAME, TEXT FROM USER_SOURCE
 WHERE NAME IN (
   SELECT DISTINCT REGEXP_SUBSTR(TEXT, '(P_[A-Z0-9_]+|PKG_[A-Z0-9_]+)', 1, 1, 'i')
     FROM USER_SOURCE WHERE NAME = '최상위_프로시저명'
 )
 ORDER BY NAME, LINE;
```

---

## 사용 스킬

이 에이전트는 `.claude/skills/procedure-tracer/SKILL.md`를 참조하여 추적 방법론을 사용한다.
