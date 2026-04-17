# proc_critical

## 입력
`/impact P_CPN_CAL_PAY_MAIN`

## 기대 출력 핵심 포인트

### 1. 입력 분류
- 타입: 프로시저/패키지
- 판별 근거: `^(P_|PKG_)` 정규식 매칭
- 실전 가치 순위: 1

### 3. 연관 자원
- 트리거: TRG_CPN_PAY_INS, TRG_CPN_PAY_UPD (CPN 트리거 매칭)
- 치명 레지스트리 매칭: YES

### 6. 판정
`⚠ HOLD`
근거: critical_proc_found 매칭
