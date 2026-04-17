# impact-analyzer 회귀 픽스처

이 디렉토리는 `impact-analyzer` 스킬의 수동 검증용 입력 + 기대 출력을 담는다.
각 하위 디렉토리는 하나의 시나리오를 다룬다.

## 픽스처 목록

| 디렉토리 | 입력 | 기대 판정 | 검증 포인트 | 비고 |
|---|---|---|---|---|
| proc_critical | `P_CPN_CAL_PAY_MAIN` | HOLD | critical_proc_found 매칭, 트리거 연관 | - |
| proc_normal | `P_TEST_SAMPLE` | Go | 치명 미매칭 + 참조 ≤ 3 | - |
| proc_recursive | `P_CPN_CAL_PAY_MAIN` (깊이 12) | HOLD | depth 10 한도 도달 경고 | DB 모드 전용 (code-only skip) |
| proc_cycle | `P_A_CYCLE` (A→B→A) | HOLD | 순환 참조 감지 + 분기 중단 | DB 모드 전용 (code-only skip) |
| jsp_family_c | `vacationApp.jsp` | Conditional-Go | THRI107 + P_HRI_AFTER_PROC_EXEC 연관 | - |
| jsp_simple | `timeCdMgr.jsp` | Go | 단일 CRUD, 참조 제한적 | - |
| js_common | `common.js` (참조 25) | HOLD·STOP | 공용 유틸 임계값 초과 | - |
| jsp_include | `header.jsp` (include 15) | HOLD·STOP | 공용 include 임계값 초과 | - |
| mapper_dynamic | `dynamic-sql-query.xml` | Go·CHECK | Unresolved refs (EXECUTE IMMEDIATE) | - |
| controller_lawB | `partMgrAppController.java` | Conditional-Go | 법칙 B 공통 컨트롤러 수정 | - |
| url_direct | `/SepDcPayMgr.do` | Conditional-Go | 법칙 C/D 매퍼 매칭 | - |
| table_entry | `TCPN771` | HOLD | 퇴직정산 마스터 (치명 테이블) | - |

## 사용

1. 각 디렉토리의 `EXPECTED.md` 를 읽어 입력 + 기대 출력 확인
2. impact-analyzer SKILL.md 실행 (각 디렉토리를 프로젝트 루트로 간주)
3. 출력과 EXPECTED.md 비교하여 판정 일치 확인

## 주의

- 이 픽스처들은 **최소 구조** 만 담는다. 실제 EHR 프로젝트 수준의 복잡도는 없음.
- critical_proc_found 목록은 fixture 내 `AGENTS.md` 의 해당 섹션에서 읽는다.
- fixture 내부 Java/JSP/XML 파일은 **grep 매칭용 내용만** 포함. 컴파일 가능한 실제 코드 아님.

## DB 모드 전용 fixture

일부 fixture (proc_cycle, proc_recursive) 는 procedure body 를 enumerate 할 수 있는 DB 모드 (`direct` / `dump`) 에서만 유효하다. code-only 모드에서는 procedure-tracer 가 XML 매퍼만 grep 하므로 procedure 간 호출 체인을 발견할 수 없어 cycle/depth 경고를 생성 불가. 각 fixture 의 `EXPECTED.md` 상단 `## 전제 조건` 섹션 참조.

code-only 검증에서는 이 fixture 들을 **skip** 해야 false failure 를 방지.
