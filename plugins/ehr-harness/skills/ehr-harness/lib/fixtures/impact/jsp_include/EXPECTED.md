# jsp_include

## 입력
`/impact header.jsp`

## fixture 구성
- `src/main/webapp/WEB-INF/jsp/common/header.jsp`
- 이를 `<%@include file="../common/header.jsp"%>` 로 참조하는 JSP 15개

## 기대 출력 핵심 포인트

### 4. 영향 화면 (예시 10 + STOP 권고)
- 상위 10개 JSP 표시
- "+ 5개 더 있음" 표기

### 6. 판정
`🛑 HOLD · STOP`
근거: IS_COMMON_FILE=1, INPUT_TYPE=jsp, AFFECTED_COUNT=15 ≥ 10
