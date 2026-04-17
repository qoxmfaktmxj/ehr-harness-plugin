# proc_cycle

## 입력
`/impact P_A_CYCLE`

## fixture 구성
매퍼에 P_A_CYCLE → P_B_CYCLE → P_A_CYCLE 호출 체인 + AGENTS.md 의 critical_proc_found 에 P_A_CYCLE 포함

## 기대 출력 핵심 포인트

### 2. 체인 추적 결과
Step 2 출력에 다음 라인 포함:
`⚠ 순환 참조 감지: P_A_CYCLE → P_B_CYCLE → P_A_CYCLE`

### 6. 판정
`⚠ HOLD`
근거: critical_proc_found 매칭 + 순환 참조 감지
