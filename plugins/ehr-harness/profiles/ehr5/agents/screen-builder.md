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

### Step 3: 비즈니스 로직 적용
```
치환 사전 작성:
  - 테이블명, 컬럼명
  - 쿼리 ID (getXxxList → getYyyList)
  - URL (.do 매핑)
  - JSP 경로
  - 서비스 빈 이름

매퍼 XML의 SELECT/MERGE/DELETE 쿼리를 신규 테이블 구조에 맞게 수정
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
```

## 핵심 코드 패턴

### Controller 패턴 (EHR5 — Family A)
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
