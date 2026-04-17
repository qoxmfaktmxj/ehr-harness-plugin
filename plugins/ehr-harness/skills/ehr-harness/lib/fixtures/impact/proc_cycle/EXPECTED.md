# proc_cycle

## 전제 조건

**DB_MODE ∈ {direct, dump}** — 이 fixture 는 procedure body 를 enumerate 할 수 있는 DB 모드에서만 유효.
code-only 모드(기본값)에서는 procedure-tracer 가 XML 매퍼만 grep 하므로 P_A_CYCLE → P_B_CYCLE 체인 자체를 발견할 수 없어 cycle 경고 생성 불가. code-only 검증에서는 이 fixture 를 **skip**.

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
