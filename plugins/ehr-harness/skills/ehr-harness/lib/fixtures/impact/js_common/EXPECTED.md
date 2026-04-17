# js_common

## 입력
`/impact common.js`

## fixture 구성
- `common.js` 1개
- 이를 참조하는 JSP 25개 (jsp/*.jsp) — grep 매칭 가능한 `<script src=".*common.js"` 포함

## 기대 출력 핵심 포인트

### 1. 입력 분류
- 타입: JS
- 실전 가치 순위: 5

### 4. 영향 화면 (예시 10 + STOP 권고)
- 상위 10개 JSP 표시
- "+ 15개 더 있음 (분석 무의미)" 표기

### 6. 판정
`🛑 HOLD · STOP`
근거: 공용 유틸 JS (참조 ≥ 20)
대안: 신규 유틸 함수를 별도 파일로 추가
