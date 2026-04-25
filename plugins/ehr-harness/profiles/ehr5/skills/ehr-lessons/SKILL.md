---
name: ehr-lessons
description: EHR 작업 누적 지식 (검증 함수 명명 규칙, 회신 템플릿, 향후 harvest promoted 지식). 화면 검증 / 회신 작성 / 신규 표준 적용 시 호출.
---

# ehr-lessons (EHR5)

이 스킬은 **lazy-load** 누적 지식 저장소다. 매 세션 자동 로드 X — 명시 호출 시만.

향후 `/ehr-harvest-learnings` → audit 승인 흐름이 본 SKILL.md 끝에 새 섹션을 append 한다 (가드 4: 15360B 상한).

---

## 1. 검증 함수 명명 규칙

EHR4 화면 검증 로직(`*AppDet.jsp`) 작성 시 다음 패턴 준수:

```
함수명: validate{특수휴가종류}{검증항목}()
       또는 check{축약명}()  (단일 함수가 여러 검증을 통합 처리)

예 (✓):
  validateChildbirthVacationStartDate()
  checkMatLeave(sYmd)
  validateSpecialVacationStartDate()

예 (✗):
  isChildbirthVacation()      # 동사+is 형은 boolean 만
  getChildbirthYmd()          # 검증이 아니라 조회
  여러 함수 분산 (서버 + JSP)  # 단일 책임 원칙 위반
```

**핵심 규약**:
- **단일 함수가 dateCheck() / logicValidation() 양쪽에서 호출**되도록 작성. 변수 추가 최소화.
- **JSP 만 수정**, 서버 Controller/Service 신규 생성 자제 (사용자가 명시 요청한 경우 외).
- 기존 함수명 변경 시 caller 검색하여 일괄 갱신.

---

## 2. 회신 템플릿 (인사담당자/개발자/관리자 분기)

EHR 도메인 분석 결과를 회신할 때 3섹션 구조:

```markdown
## 1. 분석 결과 (기술)
- 근본 원인:
- 영향 테이블/함수:
- 검증 SQL:

## 2. 담당자용 회신 (비기술)
- 현상:
- 처리 방향:
- 1줄 요약:

## 3. 개발자용 수정 제시
- 수정 파일:
- 수정 줄 번호:
- SQL/코드 스니펫 (DBA 검토 후 실행):
```

**숫자로 설명하기 원칙**: 추상 설명 대신 실제 DB 값 + 공식 제시 (예: "법정이자 781,369 - 상환이자 455,890 = 325,479").

---

## 3. (이후 harvest 지식 append 영역)

`/ehr-harvest-learnings` 승인 시 본 섹션 아래에 marker 블록으로 추가됨. 사용자는 자유 편집 가능.

`<!-- EHR-LESSONS:BEGIN ... -->` ~ `<!-- EHR-LESSONS:END ... -->` 마커 보존.
