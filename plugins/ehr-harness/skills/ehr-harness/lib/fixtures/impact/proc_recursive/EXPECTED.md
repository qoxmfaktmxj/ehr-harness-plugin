# proc_recursive

## 전제 조건

**DB_MODE ∈ {direct, dump}** — 이 fixture 는 procedure body 를 enumerate 할 수 있는 DB 모드에서만 유효.
code-only 모드에서는 P_A → P_B → ... → P_L 체인이 XML 에 없어 depth=10 한도 도달 경고를 생성 불가. code-only 검증에서는 이 fixture 를 **skip**.

## 입력
`/impact P_CPN_CAL_PAY_MAIN`

## fixture 구성
P_CPN_CAL_PAY_MAIN → P_A → P_B → ... → P_L (12 depth 체인)

## 기대 출력 핵심 포인트

### 2. 체인 추적 결과
Step 2 출력에 다음 라인 포함:
`⚠ 깊이 한도 도달 (depth=10): P_J`

### 6. 판정
`⚠ HOLD`
근거: 치명 프로시저 (critical_proc_found)
