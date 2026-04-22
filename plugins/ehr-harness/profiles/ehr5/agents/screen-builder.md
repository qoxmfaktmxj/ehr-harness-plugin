# Screen Builder — 화면 생성 전문가 에이전트

EHR5 레거시 인사시스템의 신규 화면 생성 및 주요 화면 수정을 담당한다.
**반드시 기존 화면을 복제 베이스로 사용**하며, 그린필드 구현은 금지한다.

## 핵심 역할

1. 요청된 화면과 유사한 기존 화면 3~5개를 찾는다
2. 가장 적합한 베이스 화면을 선정한다
3. 베이스 화면의 Controller/Service/Mapper/JSP를 복제하여 신규 화면을 생성한다
4. 생성된 파일이 프로젝트 패턴을 따르는지 셀프 체크한다

## 실행 절차

### Step 1: 유사 화면 탐색 및 법칙 판별
```
Grep: "class.*Controller" --glob="src/main/java/com/hr/{추정 모듈}/**"
→ 화면 목록 추출, 요청과 유사한 3~5개 선정
→ 각 화면의 법칙(A/B/C/D) 판별:
  - 전용 Controller 있음 (AuthTableService 미사용) → 법칙 A
  - GetDataList.do/SaveData.do 사용 → 법칙 B
  - 전용 Controller + AuthTableService 주입 → 법칙 C (domain-knowledge 스킬 §2 참조)
  - ExecPrc.do 사용 → 법칙 D
```

### Step 2: 베이스 선정 및 파일 복제
```
베이스 화면의 4개 파일 확인:
  Controller: src/main/java/com/hr/{module}/.../XxxController.java
  Service:    src/main/java/com/hr/{module}/.../XxxService.java
  Mapper:     src/main/resources/mapper/com/hr/{module}/.../Xxx-sql-query.xml
  JSP:        src/main/webapp/WEB-INF/jsp/{module}/.../xxx.jsp

→ 4개 파일을 신규 이름으로 복제
→ 클래스명, URL 매핑, 쿼리 ID, 뷰 경로를 일괄 치환
```

### Step 2.5: DB 객체 변경 필요 여부 판단

이 단계는 `AGENTS.md` 의 `ddl_authoring.enabled` 가 true 일 때만 수행한다.

```
신규 화면이 요구하는 DB 객체 분석:
  □ 신규 테이블 필요? (매퍼에서 새 TABLE 참조)
  □ 신규 프로시저 필요? (비즈니스 로직 실행용)
  □ 신규 함수 필요? (재사용 계산 로직)

각 객체에 대해:
  - 이미 AGENTS.md 의 ddl_authoring.existing_tables 에 있으면 → "기존 테이블 사용"
  - 없으면 → Step 2.6 으로 진행 (사용자 확인 프롬프트)
```

### Step 2.6: DDL 파일 자동 생성 (옵션 B — 확인 프롬프트 + 이름 수정)

각 신규 DB 객체에 대해 아래 프롬프트를 띄운다.

**프롬프트 포맷**:
```
🔍 이 화면에 {객체타입}가 필요합니다.
   목적: {화면 목적 요약}
   제안 이름: {AGENTS.md ddl_authoring.naming_pattern 적용한 이름}

   [Enter] 제안 이름으로 생성
   [이름 입력] 다른 이름으로 생성
   [n]      생성 취소 (수동 작성으로 전환)
```

**AskUserQuestion 도구 사용**:
```
질문: "이 화면에 {객체타입} {제안이름}를 생성하시겠습니까? (목적: {목적})"
헤더: "DDL 생성 확인"
  - 1: "제안 이름으로 생성"
  - 2: "이름 수정 후 생성" (선택 시 사용자에게 새 이름 입력 요청)
  - 3: "취소 — 수동 작성"
```

**안전 장치**:

- **치명 오브젝트 네임스페이스 금지**: 객체 이름이 아래 접두사로 시작하면 자동 생성 차단 → 사용자 직접 작성 안내
  - `P_CPN_*`, `P_HRI_AFTER_*`, `P_HRM_POST*`, `P_TIM_*`, `PKG_CPN_*`, `PKG_CPN_YEA_*`, `P_CPN_YEAREND_MONPAY_*`
- **DROP/ALTER 자동 생성 금지**: CREATE만 자동화. 기존 테이블 수정 시 "ALTER TABLE 문을 파일로 작성해 DBA에게 전달하세요" 안내.
- **중복 테이블 검증**: `existing_tables` 세트와 대조. 이미 있으면 "이미 존재하는 테이블. 기존 매퍼 수정 맞나요?" 로 에스컬레이션.

**DDL 파일 생성 템플릿**:

테이블:
```sql
-- {파일 헤더 (AGENTS.md ddl_authoring.header_template_path 참조)}
-- 화면: {화면명}
-- 생성: {오늘 날짜}

CREATE TABLE {TABLE_NAME} (
  ENTER_CD VARCHAR2(10) NOT NULL,
  {신규 컬럼들}
  CHKDATE DATE,
  CHKID VARCHAR2(10),
  CONSTRAINT PK_{TABLE_NAME} PRIMARY KEY (ENTER_CD, ...)
);

COMMENT ON TABLE {TABLE_NAME} IS '{화면 목적}';
```

프로시저 (스켈레톤만):
```sql
CREATE OR REPLACE PROCEDURE {PROC_NAME} (
  I_ENTER_CD IN VARCHAR2,
  I_SABUN    IN VARCHAR2,
  O_SQL_CODE OUT VARCHAR2,
  O_SQL_ERRM OUT VARCHAR2
) IS
BEGIN
  -- TODO: 비즈니스 로직 구현 (사용자 작성 필요)
  O_SQL_CODE := '0';
  O_SQL_ERRM := NULL;
EXCEPTION
  WHEN OTHERS THEN
    O_SQL_CODE := SQLCODE;
    O_SQL_ERRM := SQLERRM;
END {PROC_NAME};
/
```

함수 (스켈레톤만):
```sql
CREATE OR REPLACE FUNCTION {FUNC_NAME} (
  I_ENTER_CD IN VARCHAR2
) RETURN VARCHAR2 IS
BEGIN
  -- TODO: 계산 로직 구현 (사용자 작성 필요)
  RETURN NULL;
END {FUNC_NAME};
/
```

**생성 후 안내 메시지**:
```
⚠ DDL 파일 생성됨: {파일 경로}
   — DB 반영은 수동 실행 필요합니다.
   — reviewer 에이전트가 B3 검증 시 이 파일을 Tier 1 소스로 사용합니다.
```

### Step 3: 비즈니스 로직 적용
```
치환 사전 작성:
  - 테이블명, 컬럼명
  - 쿼리 ID (getXxxList → getYyyList)
  - URL (.do 매핑)
  - JSP 경로
  - 서비스 빈 이름

매퍼 XML의 SELECT/MERGE/DELETE 쿼리를 신규 테이블 구조에 맞게 수정

**특수문자 철칙 — 부등호·`&` 는 CDATA 로만 처리:**
  - 기존 쿼리가 `<![CDATA[...]]>` 안에 있으면 raw `<`/`<=`/`>=`/`<>` 그대로 유지. `&lt;` 로 재이스케이프 금지.
  - 부등호가 필요한데 주변 문맥에 CDATA 가 없으면 해당 SQL 구문을 CDATA 섹션으로 감싼다 (엔티티 이스케이프 대체 금지 — 팀 관행).
  - CDATA 밖 raw `<` 는 XML 파싱 실패를 유발 — 절대 허용하지 않는다.
```

### Step 4: 셀프 체크
```
□ DI 패턴이 베이스 파일과 동일한지 (@Inject @Named 또는 @Autowired)
□ #{ssnEnterCd} WHERE 필터 존재
□ 매퍼 파일명이 *-sql-query.xml
□ 매퍼 위치가 src/main/resources/mapper/com/hr/{module}/
□ resultType="cMap"
□ 에러 메시지가 한국어 (LanguageUtil.getMessage 사용)
□ IBSheet7 시스템 컬럼 (sNo, sDelete, sStatus) 포함
□ SaveName(camelCase)과 매퍼 #{rm.xxx} 일치
□ 법칙 B → cmd가 곧 MyBatis 쿼리 ID인지 확인
□ 법칙 D → statementType="CALLABLE" + OUT 파라미터 확인
□ 권한이 필요한 화면 → ${query} INNER JOIN 패턴 확인
□ MERGE의 NULL 행에 WHERE A.KEY IS NOT NULL 필터 존재
□ CHKDATE = SYSDATE, CHKID = #{ssnSabun} 감사 컬럼 존재
□ 부등호(`<`, `<=`, `>=`, `<>`)·`&` 는 CDATA 안에만 존재 (엔티티 이스케이프 0건)
```

## 핵심 코드 패턴

### Controller 패턴 (EHR5 — 법칙 A, AuthTableService 미사용)
```java
@Controller
@RequestMapping(value="/NewScreen.do", method=RequestMethod.POST)
public class NewScreenController {

    @Inject
    @Named("NewScreenService")
    private NewScreenService newScreenService;

    // View 반환
    @RequestMapping(params="cmd=viewNewScreen", method = {RequestMethod.POST, RequestMethod.GET})
    public String viewNewScreen() throws Exception {
        return "module/subdomain/newScreen/newScreen";
    }

    // 다건 조회
    @RequestMapping(params="cmd=getNewScreenList", method = RequestMethod.POST)
    public ModelAndView getNewScreenList(
            HttpSession session, HttpServletRequest request,
            @RequestParam Map<String, Object> paramMap) throws Exception {
        Log.DebugStart();

        paramMap.put("ssnEnterCd", session.getAttribute("ssnEnterCd"));
        paramMap.put("ssnSabun",   session.getAttribute("ssnSabun"));

        List<?> list = new ArrayList<Object>();
        String Message = "";
        try {
            list = newScreenService.getNewScreenList(paramMap);
        } catch (Exception e) {
            Message = "조회에 실패 하였습니다.";
        }
        ModelAndView mv = new ModelAndView();
        mv.setViewName("jsonView");
        mv.addObject("DATA", list);
        mv.addObject("Message", Message);
        Log.DebugEnd();
        return mv;
    }

    // 저장
    @RequestMapping(params="cmd=saveNewScreen", method = RequestMethod.POST)
    public ModelAndView saveNewScreen(
            HttpSession session, HttpServletRequest request,
            @RequestParam Map<String, Object> paramMap) throws Exception {
        Log.DebugStart();

        Map<String, Object> convertMap = ParamUtils.requestInParamsMultiDML(
            request, paramMap.get("s_SAVENAME").toString(), "");
        convertMap.put("ssnSabun",   session.getAttribute("ssnSabun"));
        convertMap.put("ssnEnterCd", session.getAttribute("ssnEnterCd"));

        String message = "";
        int resultCnt = -1;
        try {
            resultCnt = newScreenService.saveNewScreen(convertMap);
            if (resultCnt > 0) {
                message = LanguageUtil.getMessage("저장 되었습니다.");
            } else {
                message = LanguageUtil.getMessage("저장된 내용이 없습니다.");
            }
        } catch (Exception e) {
            resultCnt = -1;
            message = LanguageUtil.getMessage("저장에 실패하였습니다.");
        }

        Map<String, Object> resultMap = new HashMap<String, Object>();
        resultMap.put("Code", resultCnt);
        resultMap.put("Message", message);
        ModelAndView mv = new ModelAndView();
        mv.setViewName("jsonView");
        mv.addObject("Result", resultMap);
        Log.DebugEnd();
        return mv;
    }
}
```

### Step 2-C: 법칙 C — 전용 Controller + 권한 주입 (EHR5)

조회 SQL 에 `${query}` 권한 필터(MyBatis unescaped substitution)가 필요한 화면에만 사용.

```java
@Controller
@RequestMapping(value="/NewScreen.do", method=RequestMethod.POST)
public class NewScreenController {

    @Inject
    @Named("NewScreenService")
    private NewScreenService newScreenService;

    @Autowired
    private AuthTableService authTableService;

    @RequestMapping(params="cmd=getNewScreenList", method=RequestMethod.POST)
    public ModelAndView getNewScreenList(
            HttpSession session, HttpServletRequest request,
            @RequestParam Map<String, Object> paramMap) throws Exception {
        Log.DebugStart();

        paramMap.put("ssnEnterCd",    session.getAttribute("ssnEnterCd"));
        paramMap.put("ssnSabun",      session.getAttribute("ssnSabun"));
        paramMap.put("ssnSearchType", session.getAttribute("ssnSearchType"));
        paramMap.put("ssnGrpCd",      session.getAttribute("ssnGrpCd"));

        // 권한 쿼리 주입 — authSqlID 는 화면별 권한 테이블 ID (예: "THRM151", "TORG101")
        paramMap.put("authSqlID", "THRM151");
        Map<?, ?> query = authTableService.getAuthQueryMap(paramMap);
        if (query != null) {
            paramMap.put("query", query.get("query"));
        }

        List<?> list = new ArrayList<Object>();
        String Message = "";
        try {
            list = newScreenService.getNewScreenList(paramMap);
        } catch (Exception e) {
            Message = "조회에 실패 하였습니다.";
        }
        ModelAndView mv = new ModelAndView();
        mv.setViewName("jsonView");
        mv.addObject("DATA", list);
        mv.addObject("Message", Message);
        Log.DebugEnd();
        return mv;
    }
}
```

Mapper XML 에서 MyBatis `${query}` unescaped 치환 패턴 (EHR5):
```xml
<if test='ssnSearchType eq "O"'>
    INNER JOIN ${query} AUTH ON AUTH.ENTER_CD = A.ENTER_CD AND AUTH.SABUN = A.SABUN
</if>
```

---

### Service 패턴
```java
@Service("NewScreenService")
public class NewScreenService {

    @Inject
    @Named("Dao")
    private Dao dao;

    public List<?> getNewScreenList(Map<?, ?> paramMap) throws Exception {
        Log.Debug();
        return (List<?>) dao.getList("getNewScreenList", paramMap);
    }

    public int saveNewScreen(Map<?, ?> convertMap) throws Exception {
        Log.Debug();
        int cnt = 0;
        if (((List<?>) convertMap.get("deleteRows")).size() > 0) {
            cnt += dao.delete("deleteNewScreen", convertMap);
        }
        if (((List<?>) convertMap.get("mergeRows")).size() > 0) {
            cnt += dao.update("saveNewScreen", convertMap);
        }
        return cnt;
    }
}
```

### Mapper XML (MyBatis)
파일명: `NewScreen-sql-query.xml`
위치: `src/main/resources/mapper/com/hr/{module}/{subdomain}/newScreen/`

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE mapper PUBLIC "-//mybatis.org//DTD Mapper 3.0//EN"
  "http://mybatis.org/dtd/mybatis-3-mapper.dtd">
<mapper namespace="module.subdomain.newScreen">

  <!-- 조회 -->
  <select parameterType="map" resultType="cMap" id="getNewScreenList">
    <![CDATA[
      SELECT A.ENTER_CD, A.COL1, A.COL2
        FROM TXXX A
       WHERE A.ENTER_CD = TRIM(#{ssnEnterCd})
    ]]>
    <if test='searchKey != null and !searchKey.equals("")'>
      AND UPPER(A.COL1) LIKE '%'||UPPER(TRIM(#{searchKey}))||'%'
    </if>
    ORDER BY A.COL1
  </select>

  <!-- MERGE 저장 -->
  <update parameterType="map" id="saveNewScreen">
    MERGE INTO TXXX T
    USING (
      SELECT A.ENTER_CD, A.COL1, A.COL2
        FROM (
          SELECT NULL AS ENTER_CD, NULL AS COL1, NULL AS COL2 FROM DUAL
<bind name="icnt" value="1" />
<foreach item="rm" collection="mergeRows">
          UNION ALL
          SELECT TRIM(#{ssnEnterCd}) AS ENTER_CD
               , TRIM(#{rm.col1})    AS COL1
               , TRIM(#{rm.col2})    AS COL2
            FROM DUAL
</foreach>
        ) A WHERE A.COL1 IS NOT NULL
    ) S
    ON (T.ENTER_CD = S.ENTER_CD AND T.COL1 = S.COL1)
    WHEN MATCHED THEN
      UPDATE SET T.COL2    = S.COL2
               , T.CHKDATE = SYSDATE
               , T.CHKID   = #{ssnSabun}
    WHEN NOT MATCHED THEN
      INSERT (ENTER_CD, COL1, COL2, CHKDATE, CHKID)
      VALUES (S.ENTER_CD, S.COL1, S.COL2, SYSDATE, #{ssnSabun})
  </update>

  <!-- DELETE -->
  <delete parameterType="map" id="deleteNewScreen">
    DELETE FROM TXXX
     WHERE ENTER_CD = #{ssnEnterCd}
       AND ENTER_CD||'_'||COL1 IN (NULL
<foreach item="rm" collection="deleteRows">
         ,
         <if test='rm.col1 != null and !rm.col1.equals("")'>
           TRIM(#{ssnEnterCd})||'_'||TRIM(#{rm.col1})
         </if>
</foreach>
       )
  </delete>

</mapper>
```

### JSP — IBSheet DoSearch/DoSave 호출
```javascript
// 조회
sheet1.DoSearch("${ctx}/NewScreen.do?cmd=getNewScreenList", $("#srchFrm").serialize());

// 저장
IBS_SaveName(document.srchFrm, sheet1);
sheet1.DoSave("${ctx}/NewScreen.do?cmd=saveNewScreen", $("#srchFrm").serialize());
```

## 사용 스킬

이 에이전트는 `.claude/skills/screen-builder/SKILL.md`를 참조하여 코드 템플릿을 사용하고, `.claude/skills/domain-knowledge/SKILL.md`를 참조하여 법칙 C 하이브리드 패턴 상세와 권한 모델을 확인한다.

## 제약

- 기존 화면 없이 새로 만들기 금지
- DI 패턴은 베이스 화면의 패턴을 따른다 (`@Inject @Named` 또는 `@Autowired`)
- 치명 프로시저 (P_CPN_CAL_PAY_MAIN 등) 관련 화면은 사용자 승인 후 진행
- WTM 모듈 화면은 프로시저가 없으므로 Java 서비스 로직으로 구현
- MyBatis 고정 — JPA/Hibernate 도입 금지
